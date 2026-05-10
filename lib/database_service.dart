import 'package:libsql_dart/libsql_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:bcrypt/bcrypt.dart';

class DatabaseService {
  
  String _hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

 
  bool _verifyPassword(String password, String hashed) {
    return BCrypt.checkpw(password, hashed);
  }

  
  Future<Map<String, dynamic>?> getUserLimits(String email) async {
    return await getUserByEmail(email);
  }
 
  Future<bool> saveResetOTP(String email, String otp) async {
    try {
      await client.connect();
      
      final result = await client.query(
        'SELECT user_email FROM user_identity WHERE user_email = ?',
        positional: [email],
      );
      if (result.isEmpty) return false;

      final expiry = DateTime.now()
          .add(const Duration(minutes: 10))
          .millisecondsSinceEpoch;

      await client.query(
        'UPDATE user_identity SET otp = ?, otp_expiry = ? WHERE user_email = ?',
        positional: [otp, expiry, email],
      );
      return true;
    } catch (e) {
      print("saveResetOTP error: $e");
      return false;
    }
  }

  
  Future<bool> verifyResetOTPAndUpdatePassword(String email, String otp, String newPassword) async {
    try {
      await client.connect();
      final result = await client.query(
        'SELECT otp, otp_expiry FROM user_identity WHERE user_email = ?',
        positional: [email],
      );

      if (result.isEmpty) return false;

      final storedOtp = result.first['otp'];
      final expiry = result.first['otp_expiry'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (storedOtp != otp || now >= expiry) return false;

    
      final hashedPassword = _hashPassword(newPassword);

      await client.query(
        'UPDATE user_identity SET password = ?, otp = NULL, otp_expiry = NULL WHERE user_email = ?',
        positional: [hashedPassword, email],
      );
      return true;
    } catch (e) {
      print("verifyResetOTP error: $e");
      return false;
    }
  }

  Future<bool> updateLimits(String email, double maxMonth, double maxDay) async {
    try {
      await client.connect();
      print("updateLimits called → email: $email, maxMonth: $maxMonth, maxDay: $maxDay"); // ← add

      await client.query(
        'UPDATE user_identity SET monthly_max_spending = ?, daily_max_spending = ?, daily_balance = ? WHERE user_email = ?',
        positional: [maxMonth, maxDay, maxDay,email],
      );
      print("Limit diperbarui: Bulan RM $maxMonth, Hari RM $maxDay");
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

  Future<double> getTodaySpending(String email) async {
    try {
      await client.connect();
      final startOfDay = DateTime.now()
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
          .millisecondsSinceEpoch;

      final result = await client.query(
        '''
        SELECT COALESCE(SUM(transaction_amount), 0) as total
        FROM users_transactions
        WHERE user_email = ?
        AND time_record >= ?
        ''',
        positional: [email, startOfDay],
      );
      return (result.first['total'] as num).toDouble();
    } catch (e) {
      print("getTodaySpending error: $e");
      return 0.0;
    }
  }

  Future<Map<String, double>> getDailyBudgetStatus(String email) async {
    try {
      final userData = await getUserByEmail(email);
      final dailyMax = (userData?['daily_max_spending'] as num?)?.toDouble() ?? 0.0;
      final todaySpent = await getTodaySpending(email);
      final remaining = (dailyMax - todaySpent).clamp(0.0, dailyMax);

      return {
        'daily_max': dailyMax,
        'today_spent': todaySpent,
        'remaining': remaining,
      };
    } catch (e) {
      print("getDailyBudgetStatus error: $e");
      return {'daily_max': 0.0, 'today_spent': 0.0, 'remaining': 0.0};
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
        'SELECT * FROM user_identity WHERE user_email = ?',
        positional: [email],
      );

      if (result.isEmpty) return false;

      final storedHash = result.first['password'] as String?;
      if (storedHash == null) return false;

      return _verifyPassword(password, storedHash);
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

  Future<void> saveOTP(String email, String otp) async {
    final expiry = DateTime.now().add(const Duration(minutes: 10))
        .millisecondsSinceEpoch;
    await client.connect();
    await client.query(
      'UPDATE user_identity SET otp = ?, otp_expiry = ? WHERE user_email = ?',
      positional: [otp, expiry, email],
    );
  }

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
    final hashedPassword = _hashPassword(password); 
    await client.query(
      '''INSERT INTO user_identity (
        user_name, 
        user_email, 
        password, 
        balance, 
        monthly_max_spending, 
        daily_max_spending,
        daily_balance
        ) VALUES (?, ?, ?, 0, 0, 0, 0)
      ''',
      positional: [username, email, hashedPassword], 
    );
  }

  Future<String> transfer(String senderEmail, String receiverEmail, double amount, String note) async {
    try {
      await client.connect();

      final sender = await client.query(
        'SELECT balance FROM user_identity WHERE user_email = ?',
        positional: [senderEmail],
      );
      if (sender.isEmpty) return 'Sender not found.';

      final balance = (sender.first['balance'] as num).toDouble();
      if (balance < amount) return 'Insufficient balance.';

      final userData = await client.query(
        'SELECT daily_max_spending FROM user_identity WHERE user_email = ?',
        positional: [senderEmail],
      );
      final dailyMax = (userData.first['daily_max_spending'] as num?)?.toDouble() ?? 0.0;

      if (dailyMax > 0) {
        final todaySpent = await getTodaySpending(senderEmail);
        final remaining = dailyMax - todaySpent;
        if (amount > remaining) {
          return 'Daily limit exceeded. Remaining: RM ${remaining.toStringAsFixed(2)} of RM ${dailyMax.toStringAsFixed(2)}';
        }
      }

      final receiver = await client.query(
        'SELECT user_email FROM user_identity WHERE user_email = ?',
        positional: [receiverEmail],
      );
      if (receiver.isEmpty) return 'Receiver email not found.';

      await client.query(
        'UPDATE user_identity SET balance = balance - ? WHERE user_email = ?',
        positional: [amount, senderEmail],
      );

      await client.query(
        'UPDATE user_identity SET balance = balance + ? WHERE user_email = ?',
        positional: [amount, receiverEmail],
      );

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