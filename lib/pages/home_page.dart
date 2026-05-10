import 'package:flutter/material.dart';
import 'chat_screen.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text("Digital Hizkia"), backgroundColor: Colors.transparent),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.all(20),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(15)
            ),
            child: Column(
              children: [
                Text("RM 1,000", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(onPressed: () {}, child: Text("Add")),
                    ElevatedButton(onPressed: () {}, child: Text("Transfer")),
                  ],
                )
              ],
            ),
          ),
          
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: EdgeInsets.all(20),
              children: [
                _menuItem(context, Icons.settings_input_component, "Set Limit", Colors.blue),
                _menuItem(context, Icons.event_note, "Set Planning", Colors.green),
                _menuItem(context, Icons.history, "History", Colors.orange),
                _menuItem(context, Icons.category, "Conditions", Colors.red),
              ],
            ),
          ),
        ],
      ),
      // Floating Action Button untuk Chat Bot
      floatingActionButton: FloatingActionButton(
       onPressed: () {
        // print("BUTTON INFORMATION: The button is clicked!");
        final String userEmail = ModalRoute.of(context)!.settings.arguments as String;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(userEmail: userEmail), // Kirim parameternya di sini
          ),
        );
      },
        child: Icon(Icons.chat),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label, Color color) {
    return Card(
      color: Colors.white10,
      child: InkWell(
        onTap: () {
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            SizedBox(height: 10),
            Text(label, style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}