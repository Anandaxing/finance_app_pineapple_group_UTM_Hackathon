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

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      await client.connect();
      final result = await client.query(
        'SELECT * FROM user_identity WHERE user_email = ?',
        positional: [email],
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print("Fetch user error: $e");
      return null;
    }
  }

  // Save OTP to DB
  Future<void> saveOTP(String email, String otp) async {
    final expiry = DateTime.now().add(const Duration(minutes: 10))
        .millisecondsSinceEpoch;
    await client.connect();
    await client.query(
      'UPDATE user_identity SET otp = ?, otp_expiry = ? WHERE user_email = ?',
      positional: [otp, expiry, email],
    );
  }

// Verify OTP
  Future<bool> verifyOTP(String email, String otp) async {
    await client.connect();
    final result = await client.query(
      'SELECT otp, otp_expiry FROM user_identity WHERE user_email = ?',
      positional: [email],
    );

    if (result.isEmpty) return false;

    final storedOtp = result.first['otp'];
    final expiry = result.first['otp_expiry'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (storedOtp == otp && now < expiry) {
      // Mark as verified
      await client.query(
        'UPDATE user_identity SET is_verified = 1, otp = NULL WHERE user_email = ?',
        positional: [email],
      );
      return true;
    }
    return false;
  }

  Future<void> registerUser(String username, String email, String password) async {
    await client.connect();
    await client.query(
      'INSERT INTO user_identity (user_name, user_email, password) VALUES (?, ?, ?)',
      positional: [username, email, password],
    );
  }
}
