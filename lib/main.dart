import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // ← add this

import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';

Future<void> main() async {                              // ← async
  WidgetsFlutterBinding.ensureInitialized();             // ← add this
  await dotenv.load(fileName: ".env");                   // ← add this
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // First page when app starts
      initialRoute: '/login',

      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}