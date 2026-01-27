import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'admin_wallet_screen.dart';
import 'tournament_screen.dart';
import 'members_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A2980), Color(0xFF26D0CE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatsGrid(),
                const SizedBox(height: 24),
                _buildSectionTitle('Quản lý hệ thống'),
                const SizedBox(height: 12),
                _buildMenuGrid(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 30,
          backgroundImage: NetworkImage('https://ui-avatars.com/api/?name=Admin&background=random'),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Xin chào, Admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Chúc bạn một ngày làm việc hiệu quả!',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          title: 'Doanh thu',
          value: '15.0M',
          icon: Icons.attach_money,
          color1: Colors.orange.shade400,
          color2: Colors.orange.shade700,
        ),
        _buildStatCard(
          title: 'Thành viên',
          value: '50',
          icon: Icons.people,
          color1: Colors.blue.shade400,
          color2: Colors.blue.shade700,
        ),
        _buildStatCard(
          title: 'Sân trống',
          value: '2/7',
          icon: Icons.sports_tennis,
          color1: Colors.green.shade400,
          color2: Colors.green.shade700,
        ),
        _buildStatCard(
          title: 'Giải đấu',
          value: '4',
          icon: Icons.emoji_events,
          color1: Colors.purple.shade400,
          color2: Colors.purple.shade700,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color1,
    required Color color2,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color1, color2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color2.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.8), size: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildMenuGrid(BuildContext context) {
    return Column(
      children: [
        _buildMenuItem(
          context,
          title: 'Duyệt nạp tiền',
          subtitle: 'Xử lý yêu cầu nạp tiền',
          icon: Icons.account_balance_wallet,
          color: Colors.teal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminWalletScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          context,
          title: 'Quản lý giải đấu',
          subtitle: 'Thiết lập & bốc thăm',
          icon: Icons.emoji_events,
          color: Colors.indigo,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TournamentScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          context,
          title: 'Quản lý thành viên',
          subtitle: 'Danh sách & hạng thành viên',
          icon: Icons.people_alt,
          color: Colors.cyan,
          onTap: () {
             // Navigate to Members Management screen
             Navigator.push(
               context,
               MaterialPageRoute(builder: (_) => const MembersScreen()),
             );
          },
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
