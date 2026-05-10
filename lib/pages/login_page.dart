import 'package:flutter/material.dart';
import 'register_page.dart';
import 'home_page.dart';
import '../database_service.dart';

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  final DatabaseService databaseService = DatabaseService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Login"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            TextField(
              controller: emailController,

              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: passwordController,
              obscureText: true,

              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
              String email = emailController.text.trim();
              String password = passwordController.text.trim();
              bool isValid =
                  await databaseService.loginUser(
                    email,
                    password,
                  );

              if (!context.mounted) return;

              if (isValid) {

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HomePage(),
                    settings: RouteSettings(arguments: email), // ← move it here
                  ),
                );

              } else {

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Colors.red,
                    content: Text(
                      "Invalid email or password",
                    ),
                  ),
                );

              }

},

              child: const Text("Login"),
            ),

            const SizedBox(height: 10),

            TextButton(
              onPressed: () {

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterPage(),
                  ),
                );

              },

              child: const Text("Create Account"),
            ),
          ],
        ),
      ),
    );
  }
}