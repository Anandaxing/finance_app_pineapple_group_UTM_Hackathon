import 'database_service.dart';

class AiActionService {
  final DatabaseService _db = DatabaseService();

  Future<String> executeAction(String action, Map<String, dynamic> params, String email) async {
    switch (action) {
      case 'set_daily_limit':
        final amount = (params['amount'] as num).toDouble();
        final user = await _db.getUserByEmail(email);
        final success = await _db.updateLimits(
          email,
          (user?['monthly_max_spending'] as num?)?.toDouble() ?? 0,
          amount,
        );
        return success ? 'Daily limit set to RM ${amount.toStringAsFixed(2)}.' : 'Failed to set limit.';

      case 'set_monthly_limit':
        final amount = (params['amount'] as num).toDouble();
        final user = await _db.getUserByEmail(email);
        final success = await _db.updateLimits(
          email,
          amount,
          (user?['daily_max_spending'] as num?)?.toDouble() ?? 0,
        );
        return success ? 'Monthly limit set to RM ${amount.toStringAsFixed(2)}.' : 'Failed to set limit.';

      case 'add_note':
        final title = params['title'] as String;
        final content = params['content'] as String;
        final success = await _db.addNote(email, title, content);
        return success ? 'Note "$title" saved.' : 'Failed to save note.';

      case 'check_balance':
        final user = await _db.getUserByEmail(email);
        final balance = (user?['balance'] as num?)?.toDouble() ?? 0;
        final dailyLeft = (user?['daily_balance'] as num?)?.toDouble() ?? 0;
        return 'Balance: RM ${balance.toStringAsFixed(2)}. Daily budget left: RM ${dailyLeft.toStringAsFixed(2)}.';

      case 'get_spending_summary':
        final analytics = await _db.getSpendingAnalytics(email);
        final weekly = (analytics['weekly_spent'] as double).toStringAsFixed(2);
        final monthly = (analytics['monthly_spent'] as double).toStringAsFixed(2);
        final avg = (analytics['avg_daily_spending'] as double).toStringAsFixed(2);
        return 'Last 7 days: RM $weekly. This month: RM $monthly. Daily average: RM $avg.';

      case 'get_full_analysis':
        final analytics = await _db.getSpendingAnalytics(email);
        return _formatAnalytics(analytics);

      default:
        return 'Unknown action: $action';
    }
  }

  String _formatAnalytics(Map<String, dynamic> a) {
    final buffer = StringBuffer();
    buffer.writeln('Balance: RM ${(a['balance'] as double).toStringAsFixed(2)}');
    buffer.writeln('Daily limit: RM ${(a['daily_max'] as double).toStringAsFixed(2)}');
    buffer.writeln('Monthly limit: RM ${(a['monthly_max'] as double).toStringAsFixed(2)}');
    buffer.writeln('Spent this month: RM ${(a['monthly_spent'] as double).toStringAsFixed(2)}');
    buffer.writeln('Spent last 7 days: RM ${(a['weekly_spent'] as double).toStringAsFixed(2)}');
    buffer.writeln('Avg daily spending: RM ${(a['avg_daily_spending'] as double).toStringAsFixed(2)}');

    final cats = a['top_categories'] as List;
    if (cats.isNotEmpty) {
      buffer.writeln('Top spending categories:');
      for (final c in cats) {
        buffer.writeln('  - ${c['category']}: RM ${(c['total'] as num).toStringAsFixed(2)} (${c['count']}x)');
      }
    }

    final largest = a['largest_transactions'] as List;
    if (largest.isNotEmpty) {
      buffer.writeln('Largest transactions:');
      for (final t in largest) {
        final dt = DateTime.fromMillisecondsSinceEpoch(t['time_record'] as int);
        buffer.writeln('  - RM ${(t['transaction_amount'] as num).toStringAsFixed(2)} — ${t['category']} (${dt.day}/${dt.month})');
      }
    }

    return buffer.toString();
  }
}