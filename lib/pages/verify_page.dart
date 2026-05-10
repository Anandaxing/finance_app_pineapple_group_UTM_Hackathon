import 'package:flutter/material.dart';
import '../database_service.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});
  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final _otpController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  bool _isLoading = false;

  Future<void> _verify() async {
    final email = ModalRoute.of(context)?.settings.arguments as String?;
    if (email == null) return;

    setState(() => _isLoading = true);
    final success = await _db.verifyOTP(email, _otpController.text.trim());
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account verified! Please log in."),
            backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid or expired code."),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Text("Verify Account", style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Enter the 6-digit code sent to your email",
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 8),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF111827),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text("Verify", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}