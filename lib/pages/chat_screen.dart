import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.userEmail});
  final String? userEmail;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  
  // Ganti dengan API Key di  (aistudio.google.com)
  final String _apiKey = "AIzaSyAQHo2Ydjw8s9Pjf7OpsMLPtJ9LNq8cd5s"; 
  late GenerativeModel _model;
  late ChatSession _chatSession;

    @override
    void initState() {
      super.initState();
    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: _apiKey,
    );
    _chatSession = _model.startChat();
  }

  
void _sendMessage() async {
  if (_controller.text.isEmpty) return;

  String userText = _controller.text;
  
  setState(() {
    _messages.add({"role": "user", "text": userText});
    _controller.clear();
  });

    try {
      var response = await _chatSession.sendMessage(Content.text(userText));
      setState(() {
        _messages.add({"role": "bot", "text": response.text ?? "Bot tidak merespon."});
      });
    } catch (e) {
     print("Error Asli: $e");
    setState(() {
      _messages.add({
        "role": "bot", 
        "text": "Error Detail: $e"
      });
    });
  } 
  // try {
  //   var response = await _chatSession.sendMessage(Content.text(userText));
    
  //   setState(() {
  //     _messages.add({
  //       "role": "bot", 
  //       "text": response.text ?? "Bot tidak merespon."
  //     });
  //   });
  // } catch (e) {
  //   print("Error Gemini: $e");
  //   setState(() {
  //     _messages.add({
  //       "role": "bot", 
  //       "text": "Maaf, terjadi kesalahan teknis. Silakan coba lagi."
  //     });
  //   });
  // }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("AI Financial Assistant"),
        backgroundColor: Colors.grey[900],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isUser = _messages[index]["role"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 5),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueAccent : Colors.grey[800],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      _messages[index]["text"]!,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(8),
      color: Colors.grey[900],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Tanya soal pengeluaran...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Colors.blueAccent),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}