import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class TournamentBracketScreen extends StatefulWidget {
  final int tournamentId;
  final String tournamentName;

  const TournamentBracketScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<TournamentBracketScreen> createState() => _TournamentBracketScreenState();
}

class _TournamentBracketScreenState extends State<TournamentBracketScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _tournamentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTournamentData();
  }

  Future<void> _loadTournamentData() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.dio.get('tournaments/${widget.tournamentId}');
      setState(() {
        _tournamentData = response.data;
      });
    } catch (e) {
      print('Error loading tournament: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải thông tin giải đấu')),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tournamentName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tournamentData == null
              ? const Center(child: Text('Không có dữ liệu'))
              : _buildBracket(),
    );
  }

  Widget _buildBracket() {
    final matches = (_tournamentData?['matches'] as List?) ?? [];
    final participants = (_tournamentData?['participants'] as List?) ?? [];
    
    // Check permission
    final user = context.watch<AuthProvider>().user;
    final canEdit = user != null && (user.roles.contains('Admin') || user.roles.contains('Referee'));

    if (matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_tennis, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Chưa có lịch thi đấu'),
            const SizedBox(height: 8),
            Text('${participants.length} người tham gia'),
          ],
        ),
      );
    }

    // Group matches by round
    final matchesByRound = <String, List<dynamic>>{};
    for (var match in matches) {
      final round = match['roundName'] ?? 'Unknown';
      matchesByRound[round] ??= [];
      matchesByRound[round]!.add(match);
    }

    // Create participant name map
    final participantNames = <int, String>{};
    for (var p in participants) {
      participantNames[p['memberId']] = p['memberName'] ?? 'Unknown';
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: matchesByRound.entries.map((entry) {
            return _buildRound(entry.key, entry.value, participantNames, canEdit);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRound(String roundName, List<dynamic> matches, Map<int, String> names, bool canEdit) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 24),
      child: Column(
        children: [
          // Round Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Text(
              roundName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          // Matches
          ...matches.map((match) => _buildMatchCard(match, names, canEdit)),
        ],
      ),
    );
  }

  Widget _buildMatchCard(dynamic match, Map<int, String> names, bool canEdit) {
    final team1Player = match['team1_Player1Id'];
    final team2Player = match['team2_Player1Id'];
    final score1 = match['score1'] ?? 0;
    final score2 = match['score2'] ?? 0;
    final status = match['status'];
    final winningSide = match['winningSide'];

    final team1Name = team1Player != null ? (names[team1Player] ?? 'TBD') : 'TBD';
    final team2Name = team2Player != null ? (names[team2Player] ?? 'TBD') : 'TBD';

    final isFinished = status == 2; // MatchStatus.Finished
    final team1Wins = winningSide == 0; // Team1
    final team2Wins = winningSide == 1; // Team2

    // Only allow editing if Scheduled or InProgress
    final isEditable = canEdit && (status == 0 || status == 1); 

    return InkWell(
      onTap: isEditable ? () => _showUpdateScoreDialog(match, team1Name, team2Name) : null,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: isEditable ? Border.all(color: Colors.orange, width: 1) : null,
        ),
        child: Column(
          children: [
            // Team 1
            _buildTeamRow(
              name: team1Name,
              score: score1,
              isWinner: isFinished && team1Wins,
              isTop: true,
            ),
            const Divider(height: 1),
            // Team 2
            _buildTeamRow(
              name: team2Name,
              score: score2,
              isWinner: isFinished && team2Wins,
              isTop: false,
            ),
            // Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Text(
                _getStatusText(status),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: _getStatusColor(status),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateScoreDialog(dynamic match, String team1, String team2) {
    final s1Controller = TextEditingController(text: match['score1'].toString());
    final s2Controller = TextEditingController(text: match['score2'].toString());
    final detailsController = TextEditingController(text: match['details'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cập nhật tỉ số'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$team1 vs $team2', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: s1Controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Điểm $team1'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: s2Controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Điểm $team2'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: detailsController,
              decoration: const InputDecoration(labelText: 'Chi tiết (Set 1, Set 2...)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateScore(
                match['id'], 
                int.tryParse(s1Controller.text) ?? 0, 
                int.tryParse(s2Controller.text) ?? 0,
                detailsController.text
              );
            },
            child: const Text('Lưu kết quả'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateScore(int id, int s1, int s2, String details) async {
    try {
      await _apiService.dio.post('matches/$id/result', data: {
        'score1': s1,
        'score2': s2,
        'details': details
      });
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật tỉ số thành công!'), backgroundColor: Colors.green),
        );
        _loadTournamentData(); // Refresh
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi cập nhật: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildTeamRow({
    required String name,
    required int score,
    required bool isWinner,
    required bool isTop,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWinner ? Colors.green.shade50 : null,
        borderRadius: isTop
            ? const BorderRadius.vertical(top: Radius.circular(8))
            : null,
      ),
      child: Row(
        children: [
          if (isWinner) ...[
            const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isWinner ? Colors.green : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$score',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isWinner ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(int? status) {
    switch (status) {
      case 0:
        return 'Chờ thi đấu';
      case 1:
        return 'Đang diễn ra';
      case 2:
        return 'Đã kết thúc';
      default:
        return 'Chưa xác định';
    }
  }

  Color _getStatusColor(int? status) {
    switch (status) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
