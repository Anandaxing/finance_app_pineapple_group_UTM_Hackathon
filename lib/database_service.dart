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
        'INSERT INTO users_transactions (user_email, transaction_amount, time_record, category, transaction_type) VALUES (?, ?, ?, ?, ?)',
        positional: [email, amount, DateTime.now().millisecondsSinceEpoch, 'topped up $amount', 'IN'],
      );
      await checkSavingsMilestone(email); // ← add this
      return true; 
    } catch (e) {
      print("Error top up: $e");
      return false;
    }
  }

  Future<void> _recalculateDailyBalance(String email) async {
    // Get today's total OUT spending
    final startOfDay = DateTime.now()
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .millisecondsSinceEpoch;

    final spentResult = await client.query(
      '''
      SELECT COALESCE(SUM(transaction_amount), 0) as total
      FROM users_transactions
      WHERE user_email = ? AND time_record >= ? AND transaction_type = 'OUT'
      ''',
      positional: [email, startOfDay],
    );
    final todaySpent = (spentResult.first['total'] as num).toDouble();

    // Get daily max
    final userResult = await client.query(
      'SELECT daily_max_spending FROM user_identity WHERE user_email = ?',
      positional: [email],
    );
    final dailyMax = (userResult.first['daily_max_spending'] as num?)?.toDouble() ?? 0.0;

    // Update daily_balance
    final remaining = (dailyMax - todaySpent).clamp(0.0, dailyMax);
    await client.query(
      'UPDATE user_identity SET daily_balance = ? WHERE user_email = ?',
      positional: [remaining, email],
    );
  }

  Future<double> getTodaySpending(String email) async {
    try {
      await client.connect();
      final startOfDay = DateTime.now()
          .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
          .millisecondsSinceEpoch;

      print("getTodaySpending → startOfDay: $startOfDay, email: $email"); // ← add

      final result = await client.query(
        '''
        SELECT COALESCE(SUM(transaction_amount), 0) as total
        FROM users_transactions
        WHERE user_email = ? AND time_record >= ? AND transaction_type = 'OUT'
        ''',
        positional: [email, startOfDay],
      );

      print("getTodaySpending → result: ${result.first}"); // ← add
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
        'INSERT INTO users_transactions (user_email, transaction_amount, time_record, category, transaction_type) VALUES (?, ?, ?, ?, ?)',
        positional: [email, amount, DateTime.now().millisecondsSinceEpoch, 'daily automated spending', 'OUT'],
      );
      await _recalculateDailyBalance(email); // ← add
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
        'INSERT INTO users_transactions (user_email, transaction_amount, time_record, category, transaction_type) VALUES (?, ?, ?, ?, ?)',
        positional: [senderEmail, amount, DateTime.now().millisecondsSinceEpoch, 'transfer to $receiverEmail', 'OUT'],
      );

      await client.query(
        'INSERT INTO users_transactions (user_email, transaction_amount, time_record, category, transaction_type) VALUES (?, ?, ?, ?, ?)',
        positional: [receiverEmail, amount, DateTime.now().millisecondsSinceEpoch, 'received from $senderEmail', 'IN'],
      );
      // After both inserts
      await _recalculateDailyBalance(senderEmail); // ← add
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

  Future<List<Map<String, dynamic>>> getNotes(String email) async {
    await client.connect();
    final result = await client.query(
      'SELECT * FROM user_notes WHERE user_email = ? ORDER BY updated_at DESC',
      positional: [email],
    );
    return result;
  }

  Future<bool> addNote(String email, String title, String content) async {
    try {
      await client.connect();
      final now = DateTime.now().millisecondsSinceEpoch;
      await client.query(
        'INSERT INTO user_notes (user_email, title, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        positional: [email, title, content, now, now],
      );
      return true;
    } catch (e) {
      print("addNote error: $e");
      return false;
    }
  }

  Future<bool> updateLimits(String email, double maxMonth, double maxDay) async {
    try {
      await client.connect();

      // Get today's spending first
      final todaySpent = await getTodaySpending(email);
      
      // daily_balance = new limit minus what's already spent today
      final remaining = (maxDay - todaySpent).clamp(0.0, maxDay);

      await client.query(
        'UPDATE user_identity SET monthly_max_spending = ?, daily_max_spending = ?, daily_balance = ? WHERE user_email = ?',
        positional: [maxMonth, maxDay, remaining, email],
      );
      return true;
    } catch (e) {
      print("Error update limits: $e");
      return false;
    }
  }

  Future<bool> updateNote(int noteId, String title, String content) async {
    try {
      await client.connect();
      final now = DateTime.now().millisecondsSinceEpoch;
      await client.query(
        'UPDATE user_notes SET title = ?, content = ?, updated_at = ? WHERE note_id = ?',
        positional: [title, content, now, noteId],
      );
      return true;
    } catch (e) {
      print("updateNote error: $e");
      return false;
    }
  }

  Future<bool> deleteNote(int noteId) async {
    try {
      await client.connect();
      await client.query(
        'DELETE FROM user_notes WHERE note_id = ?',
        positional: [noteId],
      );
      return true;
    } catch (e) {
      print("deleteNote error: $e");
      return false;
    }
  }

  // Award points
Future<void> awardPoints(String email, int points, String reason) async {
  try {
    await client.connect();
    await client.query(
      'UPDATE user_identity SET points = COALESCE(points, 0) + ? WHERE user_email = ?',
      positional: [points, email],
    );
    print("Awarded $points points to $email for $reason");
  } catch (e) {
    print("awardPoints error: $e");
  }
}

// Daily login reward
Future<bool> claimDailyLogin(String email) async {
  try {
    await client.connect();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final result = await client.query(
      'SELECT last_login_date FROM user_identity WHERE user_email = ?',
      positional: [email],
    );
    if (result.isEmpty) return false;

    final lastLogin = result.first['last_login_date'] as String?;
    if (lastLogin == today) return false; // already claimed today

    await client.query(
      'UPDATE user_identity SET last_login_date = ? WHERE user_email = ?',
      positional: [today, email],
    );
    await awardPoints(email, 10, 'daily login');
    return true;
  } catch (e) {
    print("claimDailyLogin error: $e");
    return false;
  }
}

// Check and award savings milestone (every RM10 saved)
  Future<void> checkSavingsMilestone(String email) async {
    try {
      await client.connect();

      // Get total IN transactions (top ups + received)
      final result = await client.query(
        '''
        SELECT COALESCE(SUM(transaction_amount), 0) as total
        FROM users_transactions
        WHERE user_email = ? AND transaction_type = 'IN'
        ''',
        positional: [email],
      );
      final totalSaved = (result.first['total'] as num).toDouble();

      // Get previously recorded savings
      final prev = await client.query(
        'SELECT saved_amount FROM user_savings WHERE user_email = ?',
        positional: [email],
      );

      double prevSaved = 0;
      if (prev.isEmpty) {
        await client.query(
          'INSERT INTO user_savings (user_email, saved_amount, last_updated) VALUES (?, 0, ?)',
          positional: [email, DateTime.now().millisecondsSinceEpoch],
        );
      } else {
        prevSaved = (prev.first['saved_amount'] as num).toDouble();
      }

      // Award 100 points for every new RM10 saved
      final prevMilestones = (prevSaved / 10).floor();
      final newMilestones = (totalSaved / 10).floor();
      final milestonesEarned = newMilestones - prevMilestones;

      if (milestonesEarned > 0) {
        final pointsToAward = milestonesEarned * 100;
        await awardPoints(email, pointsToAward, 'saved RM${milestonesEarned * 10}');
        await client.query(
          'UPDATE user_savings SET saved_amount = ?, last_updated = ? WHERE user_email = ?',
          positional: [totalSaved, DateTime.now().millisecondsSinceEpoch, email],
        );
      }
    } catch (e) {
      print("checkSavingsMilestone error: $e");
    }
  }

  // Get leaderboard
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      await client.connect();
      final result = await client.query(
        '''
        SELECT user_name, user_email, COALESCE(points, 0) as points
        FROM user_identity
        ORDER BY points DESC
        LIMIT 20
        ''',
      );
      return result;
    } catch (e) {
      print("getLeaderboard error: $e");
      return [];
    }
  }

  // Get spending analytics for AI
  Future<Map<String, dynamic>> getSpendingAnalytics(String email) async {
    try {
      await client.connect();

      final startOfMonth = DateTime.now()
          .copyWith(day: 1, hour: 0, minute: 0, second: 0, millisecond: 0)
          .millisecondsSinceEpoch;

      final start7Days = DateTime.now()
          .subtract(const Duration(days: 7))
          .millisecondsSinceEpoch;

      final start30Days = DateTime.now()
          .subtract(const Duration(days: 30))
          .millisecondsSinceEpoch;

      // Total spent this month
      final monthlySpent = await client.query('''
        SELECT COALESCE(SUM(transaction_amount), 0) as total
        FROM users_transactions
        WHERE user_email = ? AND transaction_type = 'OUT' AND time_record >= ?
      ''', positional: [email, startOfMonth]);

      // Total spent last 7 days
      final weeklySpent = await client.query('''
        SELECT COALESCE(SUM(transaction_amount), 0) as total
        FROM users_transactions
        WHERE user_email = ? AND transaction_type = 'OUT' AND time_record >= ?
      ''', positional: [email, start7Days]);

      // Daily breakdown last 7 days
      final dailyBreakdown = await client.query('''
        SELECT 
          date(time_record/1000, 'unixepoch') as day,
          COALESCE(SUM(transaction_amount), 0) as total
        FROM users_transactions
        WHERE user_email = ? AND transaction_type = 'OUT' AND time_record >= ?
        GROUP BY day
        ORDER BY day DESC
      ''', positional: [email, start7Days]);

      // Top spending categories last 30 days
      final categories = await client.query('''
        SELECT 
          category,
          COALESCE(SUM(transaction_amount), 0) as total,
          COUNT(*) as count
        FROM users_transactions
        WHERE user_email = ? AND transaction_type = 'OUT' AND time_record >= ?
        GROUP BY category
        ORDER BY total DESC
        LIMIT 5
      ''', positional: [email, start30Days]);

      // Largest single transactions
      final largestTx = await client.query('''
        SELECT transaction_amount, category, time_record
        FROM users_transactions
        WHERE user_email = ? AND transaction_type = 'OUT' AND time_record >= ?
        ORDER BY transaction_amount DESC
        LIMIT 3
      ''', positional: [email, start30Days]);

      // Average daily spending last 30 days
      final avgDaily = await client.query('''
        SELECT COALESCE(AVG(daily_total), 0) as avg
        FROM (
          SELECT date(time_record/1000, 'unixepoch') as day,
                SUM(transaction_amount) as daily_total
          FROM users_transactions
          WHERE user_email = ? AND transaction_type = 'OUT' AND time_record >= ?
          GROUP BY day
        )
      ''', positional: [email, start30Days]);

      // Days limit was exceeded (spent > daily_max_spending)
      final userData = await getUserByEmail(email);
      final dailyMax = (userData?['daily_max_spending'] as num?)?.toDouble() ?? 0.0;
      final monthlyMax = (userData?['monthly_max_spending'] as num?)?.toDouble() ?? 0.0;
      final balance = (userData?['balance'] as num?)?.toDouble() ?? 0.0;

      return {
        'balance': balance,
        'daily_max': dailyMax,
        'monthly_max': monthlyMax,
        'monthly_spent': (monthlySpent.first['total'] as num).toDouble(),
        'weekly_spent': (weeklySpent.first['total'] as num).toDouble(),
        'avg_daily_spending': (avgDaily.first['avg'] as num).toDouble(),
        'daily_breakdown': dailyBreakdown,
        'top_categories': categories,
        'largest_transactions': largestTx,
      };
    } catch (e) {
      print("getSpendingAnalytics error: $e");
      return {};
    }
  }
}