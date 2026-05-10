import 'package:flutter/material.dart';
import '../database_service.dart';

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});
  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final TextEditingController _receiverController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  bool _isLoading = false;

  Future<void> _transfer() async {
    final senderEmail = ModalRoute.of(context)?.settings.arguments as String?;
    final receiverEmail = _receiverController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final note = _noteController.text.trim();

    if (senderEmail == null) return;

    if (receiverEmail.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill in all fields correctly."), backgroundColor: Colors.red),
      );
      return;
    }

    if (receiverEmail == senderEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot transfer to yourself."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await _db.transfer(senderEmail, receiverEmail, amount, note);
    setState(() => _isLoading = false);

    if (!mounted) return;
    if (result == 'success') {
      Navigator.pop(context, true); // return true = refresh balance
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("RM ${amount.toStringAsFixed(2)} sent to $receiverEmail"), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Text("Transfer", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Receiver Email", style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            TextField(
              controller: _receiverController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "example@email.com",
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.person_outline, color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF111827),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            const Text("Amount", style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: "RM  ",
                prefixStyle: const TextStyle(color: Colors.white54, fontSize: 28),
                filled: true,
                fillColor: const Color(0xFF111827),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            const Text("Note (optional)", style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "e.g. Lunch money",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF111827),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _transfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text("Send Money", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}