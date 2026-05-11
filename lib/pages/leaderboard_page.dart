import 'package:flutter/material.dart';
import '../database_service.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final DatabaseService _db = DatabaseService();
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;
  String? _currentEmail;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentEmail = ModalRoute.of(context)?.settings.arguments as String?;
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final data = await _db.getLeaderboard();
    setState(() {
      _leaderboard = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Text("🏆 Leaderboard", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : Column(
              children: [
                // ── Top 3 podium ──
                if (_leaderboard.length >= 3)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _podiumItem(_leaderboard[1], 2, 80),  // 2nd
                        _podiumItem(_leaderboard[0], 1, 110), // 1st
                        _podiumItem(_leaderboard[2], 3, 60),  // 3rd
                      ],
                    ),
                  ),

                const Divider(color: Colors.white12),

                // ── Full list ──
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _leaderboard.length,
                    itemBuilder: (context, index) {
                      final user = _leaderboard[index];
                      final isMe = user['user_email'] == _currentEmail;
                      final rank = index + 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFFD4AF37).withOpacity(0.15)
                              : const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isMe
                                ? const Color(0xFFD4AF37).withOpacity(0.5)
                                : Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Rank
                            SizedBox(
                              width: 36,
                              child: Text(
                                rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '#$rank',
                                style: TextStyle(
                                  color: rank <= 3 ? Colors.white : Colors.white38,
                                  fontSize: rank <= 3 ? 20 : 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Avatar
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF1A2235),
                              child: Text(
                                (user['user_name'] as String? ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Name + email
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        user['user_name'] ?? 'Unknown',
                                        style: TextStyle(
                                          color: isMe ? const Color(0xFFD4AF37) : Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD4AF37).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text("You",
                                              style: TextStyle(color: Color(0xFFD4AF37), fontSize: 10)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Points
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${user['points']}',
                                  style: const TextStyle(
                                    color: Color(0xFFD4AF37),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const Text("pts", style: TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // ── Points guide ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _pointsGuide("🌅", "Daily Login", "+10 pts"),
                      Container(width: 1, height: 30, color: Colors.white12),
                      _pointsGuide("💰", "Save RM10", "+100 pts"),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _podiumItem(Map<String, dynamic> user, int rank, double height) {
    final colors = [const Color(0xFFD4AF37), Colors.grey, const Color(0xFFCD7F32)];
    final medals = ['🥇', '🥈', '🥉'];
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(medals[rank - 1], style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          CircleAvatar(
            radius: 22,
            backgroundColor: colors[rank - 1].withOpacity(0.2),
            child: Text(
              (user['user_name'] as String? ?? 'U')[0].toUpperCase(),
              style: TextStyle(color: colors[rank - 1], fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user['user_name'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${user['points']} pts',
            style: TextStyle(color: colors[rank - 1], fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: colors[rank - 1].withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: colors[rank - 1].withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pointsGuide(String emoji, String label, String points) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            Text(points, style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ],
    );
  }

}