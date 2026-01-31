import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  Future<void> _downloadReport(String type, String title) async {
    setState(() => _isLoading = true);

    try {
      String endpoint;
      String fileName;
      
      switch (type) {
        case 'revenue':
          endpoint = 'reports/revenue?from=${_fromDate.toIso8601String()}&to=${_toDate.toIso8601String()}';
          fileName = 'BaoCaoDoanhThu_${DateFormat('yyyyMMdd').format(_fromDate)}_${DateFormat('yyyyMMdd').format(_toDate)}.xlsx';
          break;
        case 'members':
          endpoint = 'reports/members';
          fileName = 'DanhSachThanhVien_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
          break;
        case 'bookings':
          endpoint = 'reports/bookings?from=${_fromDate.toIso8601String()}&to=${_toDate.toIso8601String()}';
          fileName = 'BaoCaoDatSan_${DateFormat('yyyyMMdd').format(_fromDate)}_${DateFormat('yyyyMMdd').format(_toDate)}.xlsx';
          break;
        default:
          throw Exception('Unknown report type');
      }

      final response = await _apiService.dio.get<List<int>>(
        endpoint,
        options: Options(responseType: ResponseType.bytes),
      );

      // Lưu file
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.data!);

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tải $title thành công!\nLưu tại: ${file.path}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải báo cáo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xuất báo cáo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Selector
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Khoảng thời gian',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _selectDateRange,
                                  icon: const Icon(Icons.date_range),
                                  label: Text(
                                    '${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Chọn báo cáo',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),

                  // Revenue Report
                  _buildReportCard(
                    icon: Icons.attach_money,
                    color: Colors.green,
                    title: 'Báo cáo Doanh thu',
                    description: 'Tổng hợp giao dịch, nạp tiền, thanh toán',
                    onTap: () => _downloadReport('revenue', 'Báo cáo Doanh thu'),
                  ),

                  // Members Report
                  _buildReportCard(
                    icon: Icons.people,
                    color: Colors.blue,
                    title: 'Danh sách Thành viên',
                    description: 'Thông tin, rank, số dư, tổng chi tiêu',
                    onTap: () => _downloadReport('members', 'Danh sách Thành viên'),
                  ),

                  // Bookings Report
                  _buildReportCard(
                    icon: Icons.calendar_today,
                    color: Colors.orange,
                    title: 'Báo cáo Đặt sân',
                    description: 'Lịch sử đặt sân, doanh thu theo thời gian',
                    onTap: () => _downloadReport('bookings', 'Báo cáo Đặt sân'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildReportCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: IconButton(
          icon: const Icon(Icons.download),
          onPressed: onTap,
          color: color,
        ),
        onTap: onTap,
      ),
    );
  }
}

