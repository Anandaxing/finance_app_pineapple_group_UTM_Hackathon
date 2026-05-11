import 'package:flutter/material.dart';
import '../database_service.dart';

class SetLimitPage extends StatefulWidget {
  const SetLimitPage({super.key});

  @override
  State<SetLimitPage> createState() => _SetLimitPageState();
}

class _SetLimitPageState extends State<SetLimitPage> {
  final DatabaseService _db = DatabaseService();
  final _dailyController = TextEditingController();
  String? _email;
  bool _isLoading = true;
  bool _isSaving = false;

  double _balance = 0;
  double _currentMonthlyLimit = 0;
  double _currentDailyLimit = 0;

  // Calculated values from daily input
  double _calculatedDaily = 0;
  double _calculatedMonthly = 0;
  int _daysInCurrentMonth = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_email == null) {
      _email = ModalRoute.of(context)?.settings.arguments as String?;
      if (_email != null) _loadCurrentLimits();
    }
  }

  int _getDaysInCurrentMonth() {
    final now = DateTime.now();
    // Last day of current month = day 0 of next month
    return DateTime(now.year, now.month + 1, 0).day;
  }

  Future<void> _loadCurrentLimits() async {
    setState(() => _isLoading = true);
    final data = await _db.getUserLimits(_email!);
    if (data != null && mounted) {
      setState(() {
        _balance = (data['balance'] ?? 0).toDouble();
        _currentMonthlyLimit = (data['monthly_max_spending'] ?? 0).toDouble();
        _currentDailyLimit = (data['daily_max_spending'] ?? 0).toDouble();
        _daysInCurrentMonth = _getDaysInCurrentMonth();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _onDailyChanged(String value) {
    double daily = double.tryParse(value) ?? 0;
    setState(() {
      _calculatedDaily = daily;
      // Auto-calculate monthly = daily × jumlah hari di bulan ini
      _calculatedMonthly = daily * _daysInCurrentMonth;
    });
  }

  void _saveLimits() async {
    if (_isSaving) return;

    double daily = double.tryParse(_dailyController.text) ?? 0;

    if (daily <= 0) {
      _showErrorSnackBar("Insert valid daily limit (larger than 0).");
      return;
    }

    double monthly = daily * _daysInCurrentMonth;

    // Validasi: limit bulanan tidak boleh melebihi saldo
    if (monthly > _balance) {
      _showErrorSnackBar(
        "Monthly limit (RM ${monthly.toStringAsFixed(2)}) exceeded your balance (RM ${_balance.toStringAsFixed(2)}).\n"
        "Daily limit: RM ${(_balance / _daysInCurrentMonth).toStringAsFixed(2)}",
      );
      return;
    }

    // Validasi: daily tidak boleh melebihi saldo
    if (daily > _balance) {
      _showErrorSnackBar("Daily limit cannot exceed your balance.");
      return;
    }

    setState(() => _isSaving = true);

    bool success = await _db.updateLimits(_email!, monthly, daily);

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ Saved Successfully!\n Limit Daily: RM ${daily.toStringAsFixed(2)} | Monthly: RM ${monthly.toStringAsFixed(2)}",
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      _showErrorSnackBar("Failed to save. Please try again");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _dailyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text("Set Spending Limit"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === BALANCE INFO CARD ===
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blueAccent.withOpacity(0.3), Colors.blue.withOpacity(0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("💰 Your balance", style: TextStyle(color: Colors.white60, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          "RM ${_balance.toStringAsFixed(2)}",
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _infoChip("📅 This month: $_daysInCurrentMonth days"),
                            const SizedBox(width: 8),
                            _infoChip("📊 Daily limit: RM ${(_balance / _daysInCurrentMonth).toStringAsFixed(2)}"),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // === CURRENT LIMITS ===
                  if (_currentMonthlyLimit > 0 || _currentDailyLimit > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("⚙️ Current limit", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          _limitRow("Daily", _currentDailyLimit, Colors.greenAccent),
                          const SizedBox(height: 8),
                          _limitRow("Monthly", _currentMonthlyLimit, Colors.blueAccent),
                        ],
                      ),
                    ),

                  // === INPUT DAILY LIMIT ===
                  const Text(
                    "SET YOUR DAILY LIMIT",
                    style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Insert your daily limit. Monthly limit will be automatically calculated based on the total days in this month.",
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _dailyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    onChanged: _onDailyChanged,
                    decoration: InputDecoration(
                      labelText: "Daily Limit (RM)",
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixText: "RM  ",
                      prefixStyle: const TextStyle(color: Colors.white54, fontSize: 22),
                      filled: true,
                      fillColor: const Color(0xFF111827),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // === CALCULATION PREVIEW ===
                  if (_calculatedDaily > 0)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _calculatedMonthly > _balance
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _calculatedMonthly > _balance
                              ? Colors.red.withOpacity(0.5)
                              : Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _calculatedMonthly > _balance ? "⚠️ AUTOMATED CALCULATION" : "✅ AUTOMATED CALCULATION",
                            style: TextStyle(
                              color: _calculatedMonthly > _balance ? Colors.red[300] : Colors.green[300],
                              fontSize: 12,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _calcRow("Daily limit", "RM ${_calculatedDaily.toStringAsFixed(2)}"),
                          const Divider(color: Colors.white12, height: 20),
                          _calcRow("× Days in this month", "$_daysInCurrentMonth days"),
                          const Divider(color: Colors.white12, height: 20),
                          _calcRow(
                            "= Monthly limit",
                            "RM ${_calculatedMonthly.toStringAsFixed(2)}",
                            isBold: true,
                            valueColor: _calculatedMonthly > _balance ? Colors.red[300]! : Colors.greenAccent,
                          ),
                          if (_calculatedMonthly > _balance) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber, color: Colors.red, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Exceeding balance! Max: RM ${(_balance / _daysInCurrentMonth).toStringAsFixed(2)}/day",
                                      style: TextStyle(color: Colors.red[300], fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_calculatedMonthly <= _balance && _calculatedMonthly > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Remaining balance after limit: RM ${(_balance - _calculatedMonthly).toStringAsFixed(2)}",
                                      style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),

                  // === SAVE BUTTON ===
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveLimits,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              "💾  Save",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _infoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    );
  }

  Widget _limitRow(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        Text(
          "RM ${value.toStringAsFixed(2)}",
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _calcRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}