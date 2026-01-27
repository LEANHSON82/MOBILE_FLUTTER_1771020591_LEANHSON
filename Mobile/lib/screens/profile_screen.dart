import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar Section
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.blue.shade100,
            child: user?.avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      user!.avatarUrl!,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.blue,
                      ),
                    ),
                  )
                : const Icon(Icons.person, size: 60, color: Colors.blue),
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            user?.fullName ?? 'Chưa đăng nhập',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Tier Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _getTierColor(user?.walletBalance ?? 0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _getTierName(user?.walletBalance ?? 0),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Số dư ví',
                  '${_formatMoney(user?.walletBalance ?? 0)}đ',
                  Icons.account_balance_wallet,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Rank DUPR',
                  '3.5',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Menu Items
          _buildMenuItem(
            icon: Icons.edit,
            title: 'Chỉnh sửa thông tin',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng đang phát triển')),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.history,
            title: 'Lịch sử giao dịch',
            onTap: () {
              // Navigate to wallet transactions
            },
          ),
          _buildMenuItem(
            icon: Icons.sports_tennis,
            title: 'Lịch sử trận đấu',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng đang phát triển')),
              );
            },
          ),
          _buildMenuItem(
            icon: Icons.settings,
            title: 'Cài đặt',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng đang phát triển')),
              );
            },
          ),
          const Divider(height: 32),
          _buildMenuItem(
            icon: Icons.logout,
            title: 'Đăng xuất',
            color: Colors.red,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Đăng xuất'),
                  content: const Text('Bạn có chắc muốn đăng xuất?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Hủy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await authProvider.logout();
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.grey.shade700),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  String _formatMoney(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Color _getTierColor(double balance) {
    if (balance >= 10000000) return Colors.purple; // Diamond
    if (balance >= 5000000) return Colors.amber; // Gold
    if (balance >= 2000000) return Colors.grey.shade400; // Silver
    return Colors.brown; // Standard
  }

  String _getTierName(double balance) {
    if (balance >= 10000000) return '💎 Kim Cương';
    if (balance >= 5000000) return '🥇 Vàng';
    if (balance >= 2000000) return '🥈 Bạc';
    return '🥉 Đồng';
  }
}
