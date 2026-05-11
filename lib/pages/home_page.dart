import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'set_limit_page.dart';
import 'history_page.dart';
import 'notes_page.dart';
import '../database_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();}

class _HomePageState extends State<HomePage> {
  final DatabaseService _db = DatabaseService();
  Map<String, dynamic>? _userData;
  Map<String, double> _budgetStatus = {
    'daily_max': 0,
    'today_spent': 0,
    'remaining': 0,
  };
  bool _isLoading = true;
  String? _email;

  String _formatRM(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '0') ?? 0.0;
    return parsed.toStringAsFixed(2);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _email = ModalRoute.of(context)?.settings.arguments as String?;
    if (_email != null && _userData == null) _loadUser(_email!);
  }

  Future<void> _loadUser(String email) async {
    final data = await _db.getUserByEmail(email);

    if (data != null) {
      double dailyLimit = (data['daily_max_spending'] ?? 0).toDouble();
      String today = DateTime.now().toIso8601String().split('T')[0];

      if (dailyLimit > 0 && data['last_automated_date'] != today) {
        await _db.subtractBalance(email, dailyLimit);
      }
    }

    final freshData = await _db.getUserByEmail(email);
    final budget = await _db.getDailyBudgetStatus(email); // ✅ kira dari transactions

    setState(() {
      _userData = freshData;
      _budgetStatus = budget;
      _isLoading = false;
    });
  }

  void _showTopUpDialog() {
    final TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("Top Up Saldo", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Enter amount (RM)",
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                double? amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0 && _email != null) {
                  bool success = await _db.topUpBalance(_email!, amount);
                  if (success) {
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _loadUser(_email!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Successfully added balance")),
                    );
                  }
                }
              },
              child: const Text("Top Up"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Welcome back, ${_userData?['user_name'] ?? 'User'}"),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.white10,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Total Balance",
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                        Text(
                          "RM ${_formatRM(_userData?['balance'])}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () => _showTopUpDialog(),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800]),
                              child: const Text("Add"),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final result = await Navigator.pushNamed(context, '/transfer', arguments: _email);
                                if (result == true) _loadUser(_email!);
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800]),
                              child: const Text("Transfer"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("DAILY BUDGET", style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 2)),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _budgetStatus['daily_max']! > 0
                                ? (_budgetStatus['today_spent']! / _budgetStatus['daily_max']!).clamp(0.0, 1.0)
                                : 0.0,
                            minHeight: 8,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _budgetStatus['remaining']! <= 0
                                  ? Colors.red
                                  : _budgetStatus['today_spent']! / (_budgetStatus['daily_max']! + 0.001) >= 0.75
                                      ? Colors.orange
                                      : Colors.greenAccent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Spent: RM ${_budgetStatus['today_spent']!.toStringAsFixed(2)}",
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                            Text("Left: RM ${_budgetStatus['remaining']!.toStringAsFixed(2)}",
                                style: TextStyle(
                                  color: _budgetStatus['remaining']! <= 0 ? Colors.red : Colors.greenAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                )),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Monthly Limit Status", style: TextStyle(color: Colors.white70)),
                            Text(
                              "RM ${_formatRM(_userData?['monthly_max_spending'])}",
                              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Daily Automated", style: TextStyle(color: Colors.white70)),
                            Text(
                              "RM ${_formatRM(_userData?['daily_max_spending'])}/day",
                              style: const TextStyle(color: Colors.greenAccent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(20),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _menuItem(
                        context,
                        Icons.settings_input_component,
                        "Set Limit",
                        Colors.blue,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SetLimitPage(),
                              settings: RouteSettings(arguments: _email),
                            ),
                          );
                          if (result == true) _loadUser(_email!);
                        },
                      ),
                      _menuItem(
                        context,
                        Icons.event_note,
                        "Self Planning",
                        Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotesPage(),
                              settings: RouteSettings(arguments: _email),
                            ),
                          );
                        },
                      ),
                      // ✅ History button dengan navigation
                      _menuItem(
                        context,
                        Icons.history,
                        "History",
                        Colors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HistoryPage(),
                              settings: RouteSettings(arguments: _email),
                            ),
                          );
                        },
                      ),
                      _menuItem(context, Icons.category, "Conditions", Colors.red),
                    ],
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(userEmail: _email ?? ''),
            ),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return Card(
      color: Colors.white10,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}