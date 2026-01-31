import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import 'tournament_bracket_screen.dart';
import 'chat_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _tournaments = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchTournaments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _fetchTournaments() async {
    try {
      final response = await _apiService.dio.get('tournaments');
      setState(() {
        _tournaments = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> _filterByStatus(List<int> statuses) {
    return _tournaments.where((t) => statuses.contains(t['status'])).toList();
  }

  void _joinTournament(dynamic tournament) async {
    final teamNameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tham gia ${tournament['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Phí tham gia: ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(tournament['entryFee'])}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: teamNameController,
              decoration: const InputDecoration(
                labelText: 'Tên đội (Tùy chọn)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _processJoin(tournament['id'], teamNameController.text);
            },
            child: const Text('Thanh toán & Tham gia'),
          ),
        ],
      ),
    );
  }

  void _generateSchedule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xếp lịch tự động'),
        content: const Text('Bạn có chắc chắn muốn hệ thống tự động chia bảng và sắp xếp lịch thi đấu không? Dữ liệu cũ (nếu có) sẽ bị xóa.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đồng ý')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.dio.post('tournaments/$id/generate-schedule');
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xếp lịch thi đấu thành công!'), backgroundColor: Colors.green),
        );
        _fetchTournaments(); // Refresh
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Lỗi xếp lịch: Cần ít nhất 2 VĐV'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _processJoin(int id, String teamName) async {
    try {
      await _apiService.dio.post(
        'tournaments/$id/join',
        data: {'teamName': teamName},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tham gia thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchTournaments(); // Refresh list
      }
    } on DioException catch (e) {
      if (mounted) {
        String errorMessage = 'Lỗi không xác định';
        if (e.response != null) {
          // Try to get error message from response
          final data = e.response!.data;
          if (data is String) {
            errorMessage = data;
          } else if (data is Map && data.containsKey('message')) {
            errorMessage = data['message'];
          } else {
            errorMessage = 'Lỗi: ${e.response!.statusCode}';
          }
        } else {
          errorMessage = e.message ?? 'Lỗi kết nối';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we are in a standalone route or embedded
    final isEmbedded = Scaffold.maybeOf(context) != null;
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user != null && user.roles.contains('Admin');

    final content = Column(
      children: [
        // Tab Bar
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: 'Đang mở'),
              Tab(text: 'Đang diễn ra'),
              Tab(text: 'Đã kết thúc'),
            ],
          ),
        ),
        // Tab Views
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTournamentList(_filterByStatus([0, 1]), isAdmin), // Open + Registering
                    _buildTournamentList(_filterByStatus([2, 3]), isAdmin), // DrawCompleted + Ongoing
                    _buildTournamentList(_filterByStatus([4]), isAdmin), // Finished
                  ],
                ),
        ),
      ],
    );

    if (isEmbedded) {
      return content;
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('Giải đấu')),
        body: content,
      );
    }
  }

  Widget _buildTournamentList(List<dynamic> tournaments, bool isAdmin) {
    if (tournaments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Không có giải đấu', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _fetchTournaments(),
      child: ListView.builder(
        itemCount: tournaments.length,
        padding: const EdgeInsets.all(12),
        itemBuilder: (context, index) {
          final t = tournaments[index];
          return _buildTournamentCard(t, isAdmin);
        },
      ),
    );
  }

  Widget _buildTournamentCard(dynamic tournament, bool isAdmin) {
    final format = tournament['format'] == 0 ? 'Knockout' : 'Round Robin';
    final entryFee = tournament['entryFee'] ?? 0;
    final prizePool = tournament['prizePool'] ?? 0;
    final status = tournament['status'] ?? 0;
    final isOpen = status == 0 || status == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TournamentBracketScreen(
              tournamentId: tournament['id'],
              tournamentName: tournament['name'] ?? 'Tournament',
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tournament['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatus(status),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Info Row
              Row(
                children: [
                  _buildInfoChip(Icons.sports_tennis, format),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.monetization_on,
                    'Phí: ${(entryFee / 1000).toStringAsFixed(0)}K',
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.emoji_events,
                    'Thưởng: ${(prizePool / 1000).toStringAsFixed(0)}K',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Actions
              Row(
                children: [
                   // Generate Schedule Button (Admin Only)
                   if (isAdmin && (status == 1)) // Only when Registering
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _generateSchedule(tournament['id']),
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Xếp lịch'),
                        style: TextButton.styleFrom(foregroundColor: Colors.orange),
                      ),
                    ),
                    if(isAdmin && status == 1) const SizedBox(width: 8),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TournamentBracketScreen(
                            tournamentId: tournament['id'],
                            tournamentName: tournament['name'] ?? 'Tournament',
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.account_tree),
                      label: const Text('Bracket'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chat Button
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TournamentChatScreen(
                          tournamentId: tournament['id'],
                          tournamentName: tournament['name'] ?? 'Tournament',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: 'Chat giải đấu',
                    color: Colors.blue,
                  ),
                  if (isOpen) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _joinTournament(tournament),
                        icon: const Icon(Icons.add),
                        label: const Text('Tham gia'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  String _getStatus(int status) {
    const statuses = ['Mở đăng ký', 'Đang đăng ký', 'Đã bốc thăm', 'Đang diễn ra', 'Đã kết thúc'];
    if (status >= 0 && status < statuses.length) return statuses[status];
    return 'Unknown';
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
      case 1:
        return Colors.green;
      case 2:
      case 3:
        return Colors.orange;
      case 4:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
