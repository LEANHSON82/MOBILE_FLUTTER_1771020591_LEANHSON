import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/signalr_service.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class TournamentChatScreen extends StatefulWidget {
  final int tournamentId;
  final String tournamentName;

  const TournamentChatScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  State<TournamentChatScreen> createState() => _TournamentChatScreenState();
}

class _TournamentChatScreenState extends State<TournamentChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  SignalRService? _signalRService;
  ApiService? _apiService;
  bool _isConnected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize services synchronously first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _signalRService = Provider.of<SignalRService>(context, listen: false);
      _apiService = Provider.of<ApiService>(context, listen: false);
      _initChat();
    });
  }

  Future<void> _initChat() async {
    if (_apiService == null || _signalRService == null) return;
    
    // Load tin nhắn cũ từ API
    await _loadPreviousMessages();

    // Đợi kết nối SignalR
    if (!_signalRService!.isConnected) {
      await _signalRService!.initSignalR();
    }

    // Listen for new messages (real-time)
    _signalRService!.on('ReceiveChatMessage', (args) {
      if (args != null && args.isNotEmpty) {
        final data = args[0] as Map<String, dynamic>;
        if (data['tournamentId'] == widget.tournamentId || data['TournamentId'] == widget.tournamentId) {
          final username = data['username'] ?? data['Username'] ?? 'Unknown';
          final currentUser = context.read<AuthProvider>().user?.fullName;
          
          // Không thêm nếu tin nhắn của chính mình (đã add khi gửi)
          if (username != currentUser) {
            setState(() {
              _messages.add(ChatMessage(
                username: username,
                message: data['message'] ?? data['Message'] ?? '',
                timestamp: data['timestamp'] ?? data['Timestamp'] ?? '',
                isMe: false,
              ));
            });
            _scrollToBottom();
          }
        }
      }
    });

    _signalRService!.on('UserJoined', (args) {
      if (args != null && args.length >= 2) {
        _addSystemMessage('${args[0]} ${args[1]}');
      }
    });

    _signalRService!.on('UserLeft', (args) {
      if (args != null && args.length >= 2) {
        _addSystemMessage('${args[0]} ${args[1]}');
      }
    });

    setState(() => _isConnected = true);
  }

  Future<void> _loadPreviousMessages() async {
    if (_apiService == null) return;
    try {
      final response = await _apiService!.dio.get('chat/tournament/${widget.tournamentId}');
      
      if (response.statusCode == 200) {
        final List data = response.data as List;
        final currentUser = context.read<AuthProvider>().user?.fullName;
        
        setState(() {
          _messages.clear();
          for (var msg in data) {
            _messages.add(ChatMessage(
              username: msg['senderName'] ?? msg['SenderName'] ?? 'Unknown',
              message: msg['message'] ?? msg['Message'] ?? '',
              timestamp: msg['timestamp'] ?? msg['Timestamp'] ?? '',
              isMe: (msg['senderName'] ?? msg['SenderName']) == currentUser,
            ));
          }
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      setState(() => _isLoading = false);
    }
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        username: 'System',
        message: text,
        timestamp: TimeOfDay.now().format(context),
        isSystem: true,
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    
    // Add immediately to UI
    final currentUser = context.read<AuthProvider>().user?.fullName ?? 'Me';
    setState(() {
      _messages.add(ChatMessage(
        username: currentUser,
        message: text,
        timestamp: TimeOfDay.now().format(context),
        isMe: true,
      ));
    });
    _scrollToBottom();

    // Send to API (which will save to DB and broadcast via SignalR)
    if (_apiService == null) return;
    try {
      await _apiService!.dio.post(
        'chat/tournament/${widget.tournamentId}',
        data: {'message': text},
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi gửi tin nhắn: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.tournamentName, style: const TextStyle(fontSize: 16)),
            Text(
              _isConnected ? 'Đang kết nối' : 'Đang kết nối...',
              style: TextStyle(
                fontSize: 12,
                color: _isConnected ? Colors.green.shade100 : Colors.orange.shade100,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadPreviousMessages();
            },
            tooltip: 'Tải lại tin nhắn',
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Xem danh sách người tham gia')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có tin nhắn nào',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Hãy bắt đầu cuộc trò chuyện!',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
                      ),
          ),
          
          // Input area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    if (msg.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            msg.message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
      );
    }

    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!msg.isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  msg.username,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: msg.isMe ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
                  bottomRight: Radius.circular(msg.isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    msg.message,
                    style: TextStyle(
                      color: msg.isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg.timestamp,
                    style: TextStyle(
                      fontSize: 10,
                      color: msg.isMe ? Colors.white70 : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String username;
  final String message;
  final String timestamp;
  final bool isMe;
  final bool isSystem;

  ChatMessage({
    required this.username,
    required this.message,
    required this.timestamp,
    this.isMe = false,
    this.isSystem = false,
  });
}
