import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminWalletScreen extends StatefulWidget {
  const AdminWalletScreen({super.key});

  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingTransactions();
  }

  void _fetchPendingTransactions() async {
    try {
      // ignore: unused_local_variable
      final response = await _apiService.dio.get('wallet/admin/pending');
      
      if (mounted) {
        setState(() {
          _transactions = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error fetching pending transactions: $e');
    }
  }

  void _approveTransaction(int id) async {
    try {
      await _apiService.dio.put('wallet/approve/$id'); // Correct endpoint
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã duyệt nạp tiền thành công!')),
        );
        _fetchPendingTransactions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin - Duyệt Nạp Tiền')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _transactions.isEmpty
              ? const Center(child: Text('Không có yêu cầu nạp tiền nào'))
              : ListView.builder(
                  itemCount: _transactions.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final t = _transactions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.attach_money, color: Colors.white),
                        ),
                        title: Text(
                          t['memberName'] ?? 'Member #${t['memberId']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Số tiền: ${t['amount']} đ',
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Nội dung: ${t['description']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Thời gian: ${t['createdDate']}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _approveTransaction(t['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Duyệt'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
