import 'package:libsql_dart/libsql_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DatabaseService {
  LibsqlClient? _client;

  LibsqlClient get client {
    if (_client == null) {
      final url = dotenv.env['TURSO_DATABASE_URL'] ?? '';
      final token = dotenv.env['TURSO_AUTH_TOKEN'] ?? '';

      if (url.isEmpty) throw StateError('TURSO_DATABASE_URL is not set. Check your .env file.');
      if (token.isEmpty) throw StateError('TURSO_AUTH_TOKEN is not set. Check your .env file.');

      _client = LibsqlClient(url)..authToken = token;
    }
    return _client!;
  }

  Future<void> testConnection() async {
    try {
      print("Attempting to connect to: ${dotenv.env['TURSO_DATABASE_URL']}");
      await client.connect();
      final result = await client.query("SELECT * FROM user_identity");
      print("Remote connection result: $result");
    } catch (e) {
      print("Connection failed: $e");
    }
  }

  Future<bool> loginUser(String email, String password) async {
    try {
      await client.connect();
      final result = await client.query(
      'SELECT * FROM user_identity WHERE user_email = ? AND password = ?',
      positional: [email, password],
      );
      return result.isNotEmpty;
    } catch (e) {
      print("Login error: $e");
      return false;
    }
  }
}