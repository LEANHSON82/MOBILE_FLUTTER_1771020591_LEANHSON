import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _members = [];
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers({String? search}) async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.dio.get(
        'members',
        queryParameters: {
          'page': _currentPage,
          'pageSize': 20,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );
      setState(() {
        _members = response.data['data'] ?? [];
        _totalPages = response.data['totalPages'] ?? 1;
      });
    } catch (e) {
      print('Error loading members: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải danh sách thành viên')),
      );
    }
    setState(() => _isLoading = false);
  }

  void _onSearch() {
    _currentPage = 1;
    _loadMembers(search: _searchController.text);
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'diamond':
        return Colors.purple;
      case 'gold':
        return Colors.amber;
      case 'silver':
        return Colors.grey;
      default:
        return Colors.brown;
    }
  }

  String _getTierIcon(String tier) {
    switch (tier.toLowerCase()) {
      case 'diamond':
        return '💎';
      case 'gold':
        return '🥇';
      case 'silver':
        return '🥈';
      default:
        return '🥉';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách thành viên'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm thành viên...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _onSearch,
                  icon: const Icon(Icons.search),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          // Members List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Không tìm thấy thành viên'),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadMembers(search: _searchController.text),
                        child: ListView.builder(
                          itemCount: _members.length,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final tier = member['tier']?.toString() ?? 'Standard';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getTierColor(tier).withOpacity(0.2),
                                  child: member['avatarUrl'] != null
                                      ? ClipOval(
                                          child: Image.network(
                                            member['avatarUrl'],
                                            fit: BoxFit.cover,
                                            width: 40,
                                            height: 40,
                                            errorBuilder: (_, __, ___) => Text(
                                              (member['fullName'] ?? 'U')[0].toUpperCase(),
                                              style: TextStyle(
                                                color: _getTierColor(tier),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          (member['fullName'] ?? 'U')[0].toUpperCase(),
                                          style: TextStyle(
                                            color: _getTierColor(tier),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                title: Text(
                                  member['fullName'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Row(
                                  children: [
                                    Text('${_getTierIcon(tier)} $tier'),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.trending_up, size: 14, color: Colors.orange),
                                    Text(
                                      ' ${(member['rankLevel'] ?? 0).toStringAsFixed(1)}',
                                      style: const TextStyle(color: Colors.orange),
                                    ),
                                  ],
                                ),
                                trailing: member['isActive'] == true
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Active',
                                          style: TextStyle(color: Colors.green, fontSize: 12),
                                        ),
                                      )
                                    : null,
                                onTap: () => _showMemberProfile(member['id']),
                              ),
                            );
                          },
                        ),
                      ),
          ),
          
          // Pagination
          if (_totalPages > 1)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _currentPage > 1
                        ? () {
                            _currentPage--;
                            _loadMembers(search: _searchController.text);
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Trang $_currentPage / $_totalPages'),
                  IconButton(
                    onPressed: _currentPage < _totalPages
                        ? () {
                            _currentPage++;
                            _loadMembers(search: _searchController.text);
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showMemberProfile(int memberId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => MemberProfileSheet(memberId: memberId),
    );
  }
}

class MemberProfileSheet extends StatefulWidget {
  final int memberId;

  const MemberProfileSheet({super.key, required this.memberId});

  @override
  State<MemberProfileSheet> createState() => _MemberProfileSheetState();
}

class _MemberProfileSheetState extends State<MemberProfileSheet> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await _apiService.dio.get('members/${widget.memberId}/profile');
      setState(() {
        _profile = response.data;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profile: $e');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final member = _profile?['member'];
    final matches = _profile?['recentMatches'] as List? ?? [];
    final bookings = _profile?['recentBookings'] as List? ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                (member?['fullName'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontSize: 40, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 12),
            
            // Name
            Text(
              member?['fullName'] ?? 'Unknown',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip('Rank', '${(member?['rankLevel'] ?? 0).toStringAsFixed(1)}', Colors.orange),
                const SizedBox(width: 12),
                _buildStatChip('Tier', member?['tier'] ?? 'Standard', Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            
            // Recent Matches
            if (matches.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Trận đấu gần đây', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              ...matches.take(3).map((m) => Card(
                child: ListTile(
                  leading: const Icon(Icons.sports_tennis),
                  title: Text(m['roundName'] ?? 'Match'),
                  subtitle: Text('${m['score1']} - ${m['score2']}'),
                ),
              )),
            ],
            
            // Recent Bookings
            if (bookings.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Lịch đặt sân gần đây', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              ...bookings.take(3).map((b) => Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(b['courtName'] ?? 'Court'),
                  subtitle: Text(b['status'] ?? ''),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }
}
