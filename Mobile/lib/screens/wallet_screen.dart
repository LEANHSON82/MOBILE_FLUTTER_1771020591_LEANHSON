import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  void _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.dio.get('wallet/transactions');
      setState(() {
        _transactions = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải lịch sử giao dịch')),
        );
      }
    }
  }

  void _showDepositDialog() {
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nạp tiền vào ví'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số tiền (VND)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chuyển khoản đến:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Ngân hàng: Vietcombank'),
                  Text('STK: 1234567890'),
                  Text('Tên: CLB Pickleball'),
                ],
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
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
                );
                return;
              }
              Navigator.pop(context);
              _processDeposit(amount);
            },
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
    );
  }

  void _processDeposit(double amount) async {
    try {
      await _apiService.dio.post(
        'wallet/deposit',
        data: {'amount': amount},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yêu cầu nạp tiền đã được gửi! Vui lòng chờ Admin duyệt.'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchTransactions();
      }
    } on DioException catch (e) {
      if (mounted) {
        String errorMessage = 'Lỗi không xác định';
        if (e.response?.data is String) {
          errorMessage = e.response!.data;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _fetchTransactions(),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _transactions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Chưa có giao dịch nào'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final t = _transactions[index];
                      final amount = (t['amount'] as num).toDouble();
                      final isPositive = amount > 0;
                      final status = t['status'] ?? 0;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPositive ? Colors.green.shade100 : Colors.red.shade100,
                            child: Icon(
                              isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isPositive ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(t['description'] ?? 'Giao dịch'),
                          subtitle: Row(
                            children: [
                              Text(_formatDate(t['createdDate'])),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(status),
                                  style: TextStyle(fontSize: 10, color: _getStatusColor(status)),
                                ),
                              ),
                            ],
                          ),
                          trailing: Text(
                            currencyFormat.format(amount),
                            style: TextStyle(
                              color: isPositive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showDepositDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nạp tiền'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _getStatusText(int status) {
    switch (status) {
      case 0:
        return 'Chờ duyệt';
      case 1:
        return 'Hoàn thành';
      case 2:
        return 'Từ chối';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.green;
      case 2:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
