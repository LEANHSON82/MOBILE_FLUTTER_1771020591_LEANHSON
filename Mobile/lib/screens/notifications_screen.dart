import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    
    // Listen to real-time notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final signalR = context.read<SignalRService>();
      signalR.on('ReceiveNotification', (args) {
        if (mounted && args != null && args.isNotEmpty) {
           // We might receive just a message string or object.
           // Backend sends: .SendAsync("ReceiveNotification", noti.Message);
           // So args[0] is String message.
           // But we need the full object to display nicely.
           // Ideally backend sends object.
           // For now, reload list to get fresh data including the new one.
           _loadNotifications(silent: true);
        }
      });
    });
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final response = await _apiService.dio.get('notifications');
      if (mounted) {
        setState(() {
          _notifications = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error loading notifications: $e');
    }
  }

  Future<void> _markAsRead(int id) async {
    try {
      await _apiService.dio.put('notifications/$id/read');
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == id);
        if (index != -1) {
          _notifications[index]['isRead'] = true;
        }
      });
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _apiService.dio.put('notifications/read-all');
      setState(() {
        for (var n in _notifications) {
          n['isRead'] = true;
        }
      });
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'Success': return Colors.green;
      case 'Warning': return Colors.orange;
      case 'Error': return Colors.red;
      default: return Colors.blue;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case 'Success': return Icons.check_circle;
      case 'Warning': return Icons.warning;
      case 'Error': return Icons.error;
      default: return Icons.info;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Đọc tất cả'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadNotifications(),
              child: _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Không có thông báo', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        final isRead = notification['isRead'] == true;
                        final type = notification['type'] as String?;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: isRead ? null : Colors.blue.shade50,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getTypeColor(type).withOpacity(0.2),
                              child: Icon(
                                _getTypeIcon(type),
                                color: _getTypeColor(type),
                              ),
                            ),
                            title: Text(
                              notification['message'] ?? '',
                              style: TextStyle(
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(_formatDate(notification['createdDate'])),
                            trailing: !isRead
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                            onTap: () {
                              if (!isRead) {
                                _markAsRead(notification['id']);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
