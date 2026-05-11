import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_screen.dart';
// import 'dart:async';
import 'history_page.dart';
import 'notes_page.dart';
import '../database_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // Timer? _refreshTimer;
  final DatabaseService _db = DatabaseService();
  Map<String, dynamic>? _userData;
  Map<String, double> _budgetStatus = {
    'daily_max': 0,
    'today_spent': 0,
    'remaining': 0,
  };
  bool _isLoading = true;
  String? _email;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    // ← no timer here anymore
  }

  // @override
  // void initState() {
  //   super.initState();
  //   _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  //   _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  //   _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
  //     if (_email != null && mounted) _loadUser(_email!);
  //   });
  // }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _email = ModalRoute.of(context)?.settings.arguments as String?;
    if (_email != null && _userData == null) _loadUser(_email!);
  }

  // @override
  // void dispose() {
  //   _refreshTimer?.cancel();
  //   _fadeController.dispose();
  //   super.dispose();
  // }

  String _formatRM(dynamic value) {
    final parsed = double.tryParse(value?.toString() ?? '0') ?? 0.0;
    return parsed.toStringAsFixed(2);
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _loadUser(String email) async {
    final claimed = await _db.claimDailyLogin(email);
    if (claimed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text("🎉 Daily login bonus! ", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("+10 points"),
            ],
          ),
          backgroundColor: const Color(0xFF1A3A2A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    final data = await _db.getUserByEmail(email);
    if (data != null) {
      final dailyLimit = (data['daily_max_spending'] ?? 0).toDouble();
      final today = DateTime.now().toIso8601String().split('T')[0];
      if (dailyLimit > 0 && data['last_automated_date'] != today) {
        await _db.subtractBalance(email, dailyLimit);
      }
    }

    final freshData = await _db.getUserByEmail(email);
    final budget = await _db.getDailyBudgetStatus(email);

    if (mounted) {
      setState(() {
        _userData = freshData;
        _budgetStatus = budget;
        _isLoading = false;
      });
      _fadeController.forward(from: 0);
    }
  }

  void _showTopUpDialog() {
    final amountController = TextEditingController();
    final quickAmounts = [10.0, 20.0, 50.0, 100.0, 200.0, 500.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Top Up", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text("Add funds to your wallet", style: TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 24),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: "RM  ",
                prefixStyle: const TextStyle(color: Colors.white38, fontSize: 28),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: quickAmounts.map((amt) => GestureDetector(
                onTap: () => amountController.text = amt.toStringAsFixed(0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.3)),
                  ),
                  child: Text("RM ${amt.toStringAsFixed(0)}",
                      style: const TextStyle(color: Color(0xFF4FC3F7), fontSize: 13)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount != null && amount > 0 && _email != null) {
                    final success = await _db.topUpBalance(_email!, amount);
                    if (success && ctx.mounted) {
                      Navigator.pop(ctx);
                      _loadUser(_email!);
                      HapticFeedback.lightImpact();
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Confirm Top Up", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double spentRatio = _budgetStatus['daily_max']! > 0
        ? (_budgetStatus['today_spent']! / _budgetStatus['daily_max']!).clamp(0.0, 1.0)
        : 0.0;
    final Color budgetColor = _budgetStatus['remaining']! <= 0
        ? const Color(0xFFFF5252)
        : spentRatio >= 0.75
            ? const Color(0xFFFFB300)
            : const Color(0xFF69F0AE);

    return Scaffold(
      backgroundColor: const Color(0xFF080D16),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4FC3F7)))
          : FadeTransition(
              opacity: _fadeAnim,
              child: CustomScrollView(
                slivers: [

                  // ── Header ──
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0D1B2A), Color(0xFF080D16)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 20,
                        left: 24, right: 24, bottom: 32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_getGreeting(),
                                      style: const TextStyle(color: Colors.white38, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _userData?['user_name'] ?? 'User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  // Points badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFB300).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text("⭐", style: TextStyle(fontSize: 13)),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${_userData?['points'] ?? 0} pts",
                                          style: const TextStyle(
                                            color: Color(0xFFFFB300),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF4FC3F7).withOpacity(0.15),
                                    child: Text(
                                      (_userData?['user_name'] as String? ?? 'U')[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF4FC3F7),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // ── Balance Card ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0D2137), Color(0xFF091929)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFF4FC3F7).withOpacity(0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4FC3F7).withOpacity(0.08),
                                  blurRadius: 32,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("AVAILABLE BALANCE",
                                        style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF69F0AE).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text("● ACTIVE",
                                          style: TextStyle(color: Color(0xFF69F0AE), fontSize: 10, letterSpacing: 1)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "RM ${_formatRM(_userData?['balance'])}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userData?['user_email'] ?? '',
                                  style: const TextStyle(color: Colors.white24, fontSize: 12),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    _actionChip(Icons.add_rounded, "Top Up", const Color(0xFF4FC3F7), _showTopUpDialog),
                                    const SizedBox(width: 12),
                                    _actionChip(Icons.send_rounded, "Transfer", const Color(0xFF69F0AE), () async {
                                      final result = await Navigator.pushNamed(context, '/transfer', arguments: _email);
                                      if (result == true && mounted) _loadUser(_email!);
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Budget Section ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("DAILY BUDGET",
                              style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1520),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _budgetStat("Spent", "RM ${_budgetStatus['today_spent']!.toStringAsFixed(2)}", const Color(0xFFFF5252)),
                                    _budgetStat("Remaining", "RM ${_budgetStatus['remaining']!.toStringAsFixed(2)}", budgetColor),
                                    _budgetStat("Limit", "RM ${_budgetStatus['daily_max']!.toStringAsFixed(2)}", Colors.white38),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Stack(
                                  children: [
                                    Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: spentRatio,
                                      child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: budgetColor,
                                          borderRadius: BorderRadius.circular(3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: budgetColor.withOpacity(0.4),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_budgetStatus['remaining']! <= 0) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF5252).withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 16),
                                        SizedBox(width: 8),
                                        Text("Daily spending limit reached",
                                            style: TextStyle(color: Color(0xFFFF5252), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Monthly + Daily Info ──
                          Row(
                            children: [
                              Expanded(
                                child: _infoCard(
                                  "Monthly Limit",
                                  "RM ${_formatRM(_userData?['monthly_max_spending'])}",
                                  Icons.calendar_month_rounded,
                                  const Color(0xFF7C4DFF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _infoCard(
                                  "Daily Auto",
                                  "RM ${_formatRM(_userData?['daily_max_spending'])}/day",
                                  Icons.autorenew_rounded,
                                  const Color(0xFF4FC3F7),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          const Text("SERVICES",
                              style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  // ── Menu Grid ──
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.3,
                      ),
                      delegate: SliverChildListDelegate([
                        _menuItem(context, Icons.tune_rounded, "Set Limit", const Color(0xFF4FC3F7), () {
                          Navigator.pushNamed(context, '/setlimit', arguments: _email);
                        }),
                        _menuItem(context, Icons.edit_note_rounded, "Planning", const Color(0xFF69F0AE), () {
                          Navigator.pushNamed(context, '/notes', arguments: _email);
                        }),
                        _menuItem(context, Icons.receipt_long_rounded, "History", const Color(0xFFFFB300), () async {
                          await Navigator.pushNamed(context, '/history', arguments: _email);
                          if (mounted) _loadUser(_email!);
                        }),
                        _menuItem(context, Icons.leaderboard_rounded, "Leaderboard", const Color(0xFFFF80AB), () {
                          Navigator.pushNamed(context, '/leaderboard', arguments: _email);
                        }),
                      ]),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),

      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4FC3F7).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  userEmail: _email ?? '',
                  onActionExecuted: () {
                    if (mounted) _loadUser(_email!);
                  },
                ),
              ),
            );
            if (mounted) _loadUser(_email!);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          label: const Text("AI Assistant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _budgetStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _infoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1520),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F1520),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}