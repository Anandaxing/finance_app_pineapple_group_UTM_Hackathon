import 'package:flutter/material.dart';
import '../database_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _email;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _email = ModalRoute.of(context)?.settings.arguments as String?;
    if (_email != null) _loadHistory(_email!);
  }

  Future<void> _loadHistory(String email) async {
    final data = await _db.getTransactionHistory(email);
    setState(() {
      _transactions = data;
      _isLoading = false;
    });
  }

  String _formatDate(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Text("Transaction History", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _transactions.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, color: Colors.white24, size: 64),
                      SizedBox(height: 16),
                      Text("No transactions yet", style: TextStyle(color: Colors.white38, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _transactions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];

                    
                    final String transactionType = tx['transaction_type']?.toString() ?? '';
                    final String category = tx['category']?.toString() ?? '';
                    final double amount = (tx['transaction_amount'] as num?)?.toDouble() ?? 0.0;
                    final int timeRecord = (tx['time_record'] as num?)?.toInt() ?? 0;

                    
                    final bool isIn = transactionType == 'IN';
                    final bool isOut = transactionType == 'OUT';

                    
                    final Color amountColor = isIn ? Colors.greenAccent : Colors.redAccent;
                    final String amountPrefix = isIn ? '+' : '-';

                    IconData icon;
                    Color iconColor;
                    String title;

                    if (category.startsWith('topped up')) {
                      icon = Icons.add_circle_outline;
                      iconColor = Colors.greenAccent;
                      title = 'Top Up';
                    } else if (category.startsWith('received from')) {
                      icon = Icons.arrow_downward_rounded;
                      iconColor = Colors.greenAccent;
                      title = category; // 'received from xxx@email.com'
                    } else if (category.startsWith('transfer to')) {
                      icon = Icons.arrow_upward_rounded;
                      iconColor = Colors.redAccent;
                      title = category; // 'transfer to xxx@email.com'
                    } else if (category == 'daily automated spending') {
                      icon = Icons.autorenew_rounded;
                      iconColor = Colors.orangeAccent;
                      title = 'Daily Automated';
                    } else {
                      icon = isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
                      iconColor = isIn ? Colors.greenAccent : Colors.redAccent;
                      title = category.isNotEmpty ? category : (isIn ? 'Incoming' : 'Outgoing');
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: iconColor, size: 22),
                          ),
                          const SizedBox(width: 16),

                          
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(timeRecord),
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                          
                          Text(
                            "$amountPrefix RM ${amount.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: amountColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}