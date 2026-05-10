import 'package:libsql_dart/libsql_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DatabaseService {
  Future<Map<String, dynamic>?> getUserLimits(String email) async {
    return await getUserByEmail(email); 
  }
  Future<bool> updateLimits(String email, double maxMonth, double maxDay) async {
  try {
    final user = await getUserByEmail(email);
    if (user == null) return false;
    // monthly_max_spending
    // daily_max_spending
    print("Limit updated: Monthly RM $maxMonth, Daily RM $maxDay");
    return true;
    } catch (e) {
      print("Error update limits: $e");
    return false;
  }
  }
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

  Future<bool> topUpBalance(String email, double amount) async {
    try {
      // print("Berhasil top up RM $amount untuk $email");
      
      await client.query(
        'UPDATE user_identity SET balance = balance + ? WHERE user_email = ?',
        positional: [amount, email],
      );

      await client.query(
        'INSERT INTO users_transactions (user_email, transaction_amount, time_record, category) VALUES (?, ?, ?, ?)',
        positional: [email, amount, DateTime.now().millisecondsSinceEpoch, 'topped up $amount'],
      );
      return true; 
    } catch (e) {
      print("Error top up: $e");
      return false;
    }
  }

  Future<bool> subtractBalance(String email, double amount) async {
    try {
      await client.query(
        'UPDATE user_identity SET balance = balance - ?, last_automated_date = ? WHERE user_email = ?',
        positional: [amount, DateTime.now().toIso8601String().split('T')[0], email],
      );

      await client.query(
        'INSERT INTO users_transactions (user_email, transaction_amount, time_record, category) VALUES (?, ?, ?, ?)',
        positional: [email, amount, DateTime.now().millisecondsSinceEpoch, 'daily automated spending'],
      );
      return true;
    } catch (e) {
      print("Error subtract balance: $e");
      return false;
    }
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

// Transfer to another user
  Future<String> transfer(String senderEmail, String receiverEmail, double amount, String note) async {
    try {
      await client.connect();

      // Check sender exists and has enough balance
      final sender = await client.query(
        'SELECT balance FROM user_identity WHERE user_email = ?',
        positional: [senderEmail],
      );
      if (sender.isEmpty) return 'Sender not found.';

      final balance = (sender.first['balance'] as num).toDouble();
      if (balance < amount) return 'Insufficient balance.';

      // Check receiver exists
      final receiver = await client.query(
        'SELECT user_email FROM user_identity WHERE user_email = ?',
        positional: [receiverEmail],
      );
      if (receiver.isEmpty) return 'Receiver email not found.';

      // Deduct from sender
      await client.query(
        'UPDATE user_identity SET balance = balance - ? WHERE user_email = ?',
        positional: [amount, senderEmail],
      );

      // Add to receiver
      await client.query(
        'UPDATE user_identity SET balance = balance + ? WHERE user_email = ?',
        positional: [amount, receiverEmail],
      );

      // Record transaction
      await client.query(
        'INSERT INTO users_transactions (user_email, transaction_amount, time_record, category) VALUES (?, ?, ?, ?)',
        positional: [senderEmail, amount, DateTime.now().millisecondsSinceEpoch, 'transfer to $receiverEmail'],
      );

      await client.query(
        'INSERT INTO users_transactions (user_email, transaction_amount, time_record, category) VALUES (?, ?, ?, ?)',
        positional: [receiverEmail, amount, DateTime.now().millisecondsSinceEpoch, 'received from $senderEmail'],
      );

      return 'success';
    } catch (e) {
      print("Transfer error: $e");
      return 'Error: $e';
    }
  }

  Future<List<Map<String, dynamic>>> getTransactionHistory(String email) async {
    await client.connect();
    final result = await client.query(
      '''
      SELECT * FROM users_transactions 
      WHERE user_email = ?
      ORDER BY time_record DESC
      ''',
      positional: [email],
    );
    return result;
  }
}
