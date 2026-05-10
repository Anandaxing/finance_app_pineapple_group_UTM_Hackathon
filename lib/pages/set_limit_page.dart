import 'package:flutter/material.dart';
import '../database_service.dart';

class SetLimitPage extends StatefulWidget {
  const SetLimitPage({super.key});

  @override
  State<SetLimitPage> createState() => _SetLimitPageState();
}

class _SetLimitPageState extends State<SetLimitPage> {
  final DatabaseService _db = DatabaseService();
  final _monthController = TextEditingController();
  final _dayController = TextEditingController();
  String? _email;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _email = ModalRoute.of(context)?.settings.arguments as String?;
  }

  void _saveLimits() async {
    double month = double.tryParse(_monthController.text) ?? 0;
    double day = double.tryParse(_dayController.text) ?? 0;

    if (_email != null && month > 0 && day > 0) {
      bool success = await _db.updateLimits(_email!, month, day);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Limit Berhasil Disimpan!")),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Set Spending Limit"), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildInput("Max Monthly Limit (RM)", _monthController),
            const SizedBox(height: 20),
            _buildInput("Daily Automated Spending (RM)", _dayController),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveLimits,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text("Save Limits", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
      ),
    );
  }
}