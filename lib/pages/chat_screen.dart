import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../ai_action_service.dart';
import '../database_service.dart';

class ChatScreen extends StatefulWidget {
  final String userEmail;
  final VoidCallback? onActionExecuted;  // ← add this
  const ChatScreen({super.key, required this.userEmail, this.onActionExecuted});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiActionService _actionService = AiActionService();
  final DatabaseService _db = DatabaseService();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  Future<String> _buildSystemPrompt() async {
    final analytics = await _db.getSpendingAnalytics(widget.userEmail);
    final userData = await _db.getUserByEmail(widget.userEmail);

    return '''
  You are a smart, empathetic financial advisor for a digital wallet app.
  Today is ${DateTime.now().toLocal().toString().split(' ')[0]} (${_getDayName()}).
  The user's email is ${widget.userEmail}.
  The user's name is ${userData?['user_name'] ?? 'User'}.

  === CURRENT FINANCIAL SNAPSHOT ===
  Balance: RM ${(analytics['balance'] as double?)?.toStringAsFixed(2) ?? '0.00'}
  Daily spending limit: RM ${(analytics['daily_max'] as double?)?.toStringAsFixed(2) ?? '0.00'}
  Monthly spending limit: RM ${(analytics['monthly_max'] as double?)?.toStringAsFixed(2) ?? '0.00'}
  Spent this month: RM ${(analytics['monthly_spent'] as double?)?.toStringAsFixed(2) ?? '0.00'}
  Spent last 7 days: RM ${(analytics['weekly_spent'] as double?)?.toStringAsFixed(2) ?? '0.00'}
  Average daily spending: RM ${(analytics['avg_daily_spending'] as double?)?.toStringAsFixed(2) ?? '0.00'}

  === SPENDING BREAKDOWN ===
    Top categories (last 30 days):
    ${_formatCategories(analytics['top_categories'] as List? ?? [])}

    Daily breakdown (last 7 days):
    ${_formatDailyBreakdown(analytics['daily_breakdown'] as List? ?? [])}

    Largest transactions (last 30 days):
    ${_formatLargest(analytics['largest_transactions'] as List? ?? [])}

    === YOUR ROLE ===
    - Analyse the user's real spending data above and give SPECIFIC, personalised advice
    - Detect patterns: overspending days, high-cost categories, approaching limits
    - Proactively warn if monthly limit is close to being exceeded
    - Suggest realistic daily/monthly limit adjustments based on actual behaviour
    - Be conversational, warm, and concise — not robotic
    - When you want to perform an action, include JSON in your response:

    {"action": "set_daily_limit", "params": {"amount": 50}}
    {"action": "set_monthly_limit", "params": {"amount": 500}}
    {"action": "add_note", "params": {"title": "Budget Plan", "content": "Details here"}}
    {"action": "check_balance", "params": {}}
    {"action": "get_spending_summary", "params": {}}

    - Always confirm before executing any action
    - After the user agrees, include the JSON action in your response
    - Use precise word counts, "no fluff" directives, or formatting constraints to force the AI into high-density, minimalist responses.
    ''';
    }

    String _formatCategories(List cats) {
      if (cats.isEmpty) return '  No data yet';
      return cats.map((c) =>
        '  - ${c['category']}: RM ${(c['total'] as num).toStringAsFixed(2)} (${c['count']}x)'
      ).join('\n');
    }

    String _formatDailyBreakdown(List days) {
      if (days.isEmpty) return '  No data yet';
      return days.map((d) => '  - ${d['day']}: RM ${(d['total'] as num).toStringAsFixed(2)}').join('\n');
    }

    String _formatLargest(List txs) {
      if (txs.isEmpty) return '  No data yet';
      return txs.map((t) {
        final dt = DateTime.fromMillisecondsSinceEpoch(t['time_record'] as int);
        return '  - RM ${(t['transaction_amount'] as num).toStringAsFixed(2)} — ${t['category']} (${dt.day}/${dt.month})';
      }).join('\n');
    }

  String _getDayName() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[DateTime.now().weekday - 1];
  }

  Future<void> _sendMessage() async {
  final text = _controller.text.trim();
  if (text.isEmpty) return;

  setState(() {
    _messages.add({'role': 'user', 'content': text});
    _isLoading = true;
  });
  _controller.clear();
  _scrollToBottom();

  try {
    final systemPrompt = await _buildSystemPrompt(); // ← async now

    final history = _messages.map((m) => {
      'role': m['role'] == 'user' ? 'user' : 'model',
      'parts': [{'text': m['content']}],
    }).toList();

    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent'
        '?key=${dotenv.env['GEMINI_API_KEY']}',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'system_instruction': {'parts': [{'text': systemPrompt}]},
        'contents': history,
        'generationConfig': {'temperature': 0.7},
      }),
    );

    if (response.statusCode == 429) {
      await Future.delayed(const Duration(seconds: 15));
      _sendMessage();
      return;
    }

    final data = jsonDecode(response.body);
    print("Gemini response: ${response.statusCode}");

    if (response.statusCode != 200 || data['candidates'] == null) {
      final errorMsg = data['error']?['message'] ?? 'Unknown API error';
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'API Error: $errorMsg'});
        _isLoading = false;
      });
      return;
    }

    final aiText = data['candidates'][0]['content']['parts'][0]['text'] as String;
    String displayText = aiText;

    final jsonMatch = RegExp(r'\{[^{}]*"action"[^{}]*\{[^{}]*\}[^{}]*\}', dotAll: true).firstMatch(aiText);
    if (jsonMatch != null) {
      try {
        final jsonStr = jsonMatch.group(0)!;
        print("Extracted JSON: $jsonStr");
        final parsed = jsonDecode(jsonStr);
        final action = parsed['action'] as String;
        final params = Map<String, dynamic>.from(parsed['params'] as Map? ?? {});
        final result = await _actionService.executeAction(action, params, widget.userEmail);
        widget.onActionExecuted?.call();
        displayText = aiText.replaceAll(jsonStr, '').trim();
        displayText += '\n\n✅ $result';
      } catch (e) {
        print("Action parse error: $e");
      }
    }

    setState(() {
      _messages.add({'role': 'assistant', 'content': displayText});
      _isLoading = false;
    });
    _scrollToBottom();

  } catch (e) {
    setState(() {
      _messages.add({'role': 'assistant', 'content': 'Error: $e'});
      _isLoading = false;
    });
  }
}

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("AI Assistant", style: TextStyle(color: Colors.white, fontSize: 16)),
            Text("Can manage your finances", style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ── Suggestion chips ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _chip("Check my balance"),
                _chip("Set daily limit to RM 100"),
                _chip("How much did I spend today?"),
                _chip("Add a savings note"),
                _chip("Analyse my spending"),
                _chip("Am I overspending?"),
                _chip("Suggest a better daily limit"),
                _chip("Where does my money go?"),
              ],
            ),
          ),

          // ── Messages ──
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, size: 48, color: const Color(0xFFD4AF37).withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text("Ask me to manage your finances",
                            style: TextStyle(color: Colors.white38, fontSize: 15)),
                        const SizedBox(height: 4),
                        const Text("I can set limits, add notes, check balance",
                            style: TextStyle(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFFD4AF37) : const Color(0xFF1A2235),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 16),
                            ),
                          ),
                          child: Text(
                            msg['content'] ?? '',
                            style: TextStyle(
                              color: isUser ? Colors.black : Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ── Loading ──
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37))),
                  SizedBox(width: 8),
                  Text("Thinking...", style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),

          // ── Input ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Ask your AI assistant...",
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isLoading ? null : _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4AF37),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.black, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return GestureDetector(
      onTap: () {
        _controller.text = label;
        _sendMessage();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2235),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
        ),
        child: Text(label, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12)),
      ),
    );
  }
}