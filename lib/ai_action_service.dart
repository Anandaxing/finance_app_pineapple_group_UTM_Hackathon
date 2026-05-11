import 'database_service.dart';

class AiActionService {
  final DatabaseService _db = DatabaseService();

  // All actions the AI can trigger
  Future<String> executeAction(String action, Map<String, dynamic> params, String email) async {
    switch (action) {
      case 'set_daily_limit':
        final amount = (params['amount'] as num).toDouble();
        final success = await _db.updateLimits(email,
          (await _db.getUserByEmail(email))?['monthly_max_spending']?.toDouble() ?? 0,
          amount,
        );
        return success ? 'Daily limit set to RM ${amount.toStringAsFixed(2)}.' : 'Failed to set limit.';

      case 'set_monthly_limit':
        final amount = (params['amount'] as num).toDouble();
        final success = await _db.updateLimits(email, amount,
          (await _db.getUserByEmail(email))?['daily_max_spending']?.toDouble() ?? 0,
        );
        return success ? 'Monthly limit set to RM ${amount.toStringAsFixed(2)}.' : 'Failed to set limit.';

      case 'add_note':
        final title = params['title'] as String;
        final content = params['content'] as String;
        final success = await _db.addNote(email, title, content);
        return success ? 'Note "$title" saved.' : 'Failed to save note.';

      case 'check_balance':
        final user = await _db.getUserByEmail(email);
        final balance = user?['balance'] ?? 0;
        final dailyLeft = user?['daily_balance'] ?? 0;
        return 'Your balance is RM $balance. Daily budget remaining: RM $dailyLeft.';

      case 'get_spending_summary':
        final spent = await _db.getTodaySpending(email);
        final user = await _db.getUserByEmail(email);
        final dailyMax = user?['daily_max_spending'] ?? 0;
        return 'Today you spent RM ${spent.toStringAsFixed(2)} out of your RM $dailyMax daily limit.';

      default:
        return 'Unknown action: $action';
    }
  }
}