import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  List<dynamic> _openDuels = [];
  List<dynamic> _myDuels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDuels();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDuels() async {
    setState(() => _isLoading = true);
    try {
      final openRes = await _apiService.dio.get('duels');
      final myRes = await _apiService.dio.get('duels/my');
      
      setState(() {
        _openDuels = openRes.data ?? [];
        _myDuels = myRes.data ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  void _showCreateDuelDialog() {
    final amountController = TextEditingController(text: '50000');
    final messageController = TextEditingController();
    int selectedType = 0; // 0 = 1v1, 1 = 2v2

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tạo kèo thách đấu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số tiền cược (VNĐ)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('1 vs 1')),
                    ButtonSegment(value: 1, label: Text('2 vs 2')),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (Set<int> newSelection) {
                    setDialogState(() => selectedType = newSelection.first);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Lời nhắn (tùy chọn)',
                    prefixIcon: Icon(Icons.message),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => _createDuel(
                double.tryParse(amountController.text) ?? 0,
                selectedType,
                messageController.text,
              ),
              child: const Text('Tạo kèo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDuel(double amount, int type, String message) async {
    if (amount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số tiền cược tối thiểu 10,000đ')),
      );
      return;
    }

    Navigator.pop(context);

    try {
      final res = await _apiService.dio.post('duels', data: {
        'betAmount': amount,
        'type': type,
        'message': message.isNotEmpty ? message : null,
      });

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tạo kèo thành công! Số dư mới: ${res.data['newBalance']}')),
        );
        _fetchDuels();
        // Refresh wallet balance
        context.read<AuthProvider>().checkAuth();
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data?.toString() ?? 'Lỗi tạo kèo')),
      );
    }
  }

  Future<void> _acceptDuel(int id) async {
    try {
      final res = await _apiService.dio.post('duels/$id/accept');

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã chấp nhận kèo!')),
        );
        _fetchDuels();
        context.read<AuthProvider>().checkAuth();
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data?.toString() ?? 'Lỗi chấp nhận kèo')),
      );
    }
  }

  Future<void> _cancelDuel(int id) async {
    try {
      final res = await _apiService.dio.post('duels/$id/cancel');

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy kèo và hoàn tiền!')),
        );
        _fetchDuels();
        context.read<AuthProvider>().checkAuth();
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data?.toString() ?? 'Lỗi hủy kèo')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Kèo đang mở'),
              Tab(text: 'Kèo của tôi'),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDuelList(_openDuels, isOpenList: true, userId: user?.id),
                      _buildDuelList(_myDuels, isOpenList: false, userId: user?.id),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDuelDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tạo kèo'),
      ),
    );
  }

  Widget _buildDuelList(List<dynamic> duels, {required bool isOpenList, int? userId}) {
    if (duels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_mma, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isOpenList ? 'Chưa có kèo nào đang mở' : 'Bạn chưa có kèo nào',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDuels,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: duels.length,
        itemBuilder: (ctx, i) => _buildDuelCard(duels[i], isOpenList: isOpenList, userId: userId),
      ),
    );
  }

  Widget _buildDuelCard(dynamic duel, {required bool isOpenList, int? userId}) {
    final isChallenger = duel['challengerId'] == userId;
    final status = duel['status'] as int? ?? 0;
    final type = duel['type'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: duel['challengerAvatar'] != null
                      ? NetworkImage(duel['challengerAvatar'])
                      : null,
                  child: duel['challengerAvatar'] == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        duel['challengerName'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (duel['challengerRank'] != null)
                        Text(
                          'Rank: ${(duel['challengerRank'] as num).toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const Divider(height: 24),
            
            // Bet Amount & Type
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on, size: 18, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        NumberFormat('#,###').format(duel['betAmount']),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const Text('đ', style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(type == 0 ? '1 vs 1' : '2 vs 2'),
                  backgroundColor: Colors.blue.shade50,
                ),
              ],
            ),
            
            // Message
            if (duel['message'] != null && duel['message'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.format_quote, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(duel['message'])),
                  ],
                ),
              ),
            ],
            
            // Opponent (if accepted)
            if (duel['opponentName'] != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('VS ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: duel['opponentAvatar'] != null
                        ? NetworkImage(duel['opponentAvatar'])
                        : null,
                    child: duel['opponentAvatar'] == null
                        ? const Icon(Icons.person, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(duel['opponentName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            
            // Result
            if (status == 3 && duel['winningSide'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Người thắng: ${duel['winningSide'] == 1 ? duel['challengerName'] : duel['opponentName']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
            
            // Actions
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Accept button (only for open duels, not own duel)
                if (isOpenList && status == 0 && !isChallenger)
                  FilledButton.icon(
                    onPressed: () => _acceptDuel(duel['id']),
                    icon: const Icon(Icons.check),
                    label: const Text('Chấp nhận'),
                  ),
                
                // Cancel button (only for own open duel)
                if (isChallenger && status == 0)
                  OutlinedButton.icon(
                    onPressed: () => _cancelDuel(duel['id']),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Hủy kèo'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(int status) {
    String text;
    Color color;
    
    switch (status) {
      case 0:
        text = 'Đang mở';
        color = Colors.green;
        break;
      case 1:
        text = 'Đã chấp nhận';
        color = Colors.blue;
        break;
      case 2:
        text = 'Đang diễn ra';
        color = Colors.orange;
        break;
      case 3:
        text = 'Đã kết thúc';
        color = Colors.grey;
        break;
      case 4:
        text = 'Đã hủy';
        color = Colors.red;
        break;
      default:
        text = 'Unknown';
        color = Colors.grey;
    }

    return Chip(
      label: Text(text, style: TextStyle(color: color, fontSize: 12)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
