import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/signalr_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'members_screen.dart';
import 'admin_dashboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Connect SignalR when dashboard loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final signalR = context.read<SignalRService>();
      if (!signalR.isConnected) {
        signalR.initSignalR();
      }

      // Listen for notifications
      signalR.on('UpdateCalendar', (args) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cập nhật lịch đặt sân mới!')),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Text(
            'Xin chào, ${user?.fullName ?? 'Khách'}!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chào mừng đến với CLB Pickleball "Vợt Thủ Phố Núi"',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Admin Access
          if (user != null && user.roles.contains('Admin'))
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                ),
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Truy cập trang Quản trị (Admin)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),

          // Wallet Card - Nổi bật
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Số dư ví',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  currencyFormat.format(user?.walletBalance ?? 0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getTierName(user?.walletBalance ?? 0),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Rank Chart Section
          const Text(
            'Biến động Rank DUPR',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const months = ['T1', 'T2', 'T3', 'T4', 'T5', 'T6'];
                        if (value.toInt() < months.length) {
                          return Text(months[value.toInt()], style: const TextStyle(fontSize: 12));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 0.5,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 5,
                minY: 2.5,
                maxY: 4.5,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3.0),
                      FlSpot(1, 3.2),
                      FlSpot(2, 3.1),
                      FlSpot(3, 3.4),
                      FlSpot(4, 3.3),
                      FlSpot(5, 3.5),
                    ],
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.orange,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.sports_tennis,
                  label: 'Rank DUPR',
                  value: '3.5',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.calendar_today,
                  label: 'Lịch đặt',
                  value: '2',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.emoji_events,
                  label: 'Trận thắng',
                  value: '5',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Actions
          const Text(
            'Truy cập nhanh',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickAction(
                  icon: Icons.people,
                  label: 'Thành viên',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MembersScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickAction(
                  icon: Icons.leaderboard,
                  label: 'Bảng xếp hạng',
                  color: Colors.amber,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tính năng đang phát triển')),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Upcoming Events Section
          const Text(
            'Sự kiện sắp tới',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildEventCard(
            title: 'Giải Winter Cup 2026',
            subtitle: 'Đang mở đăng ký',
            icon: Icons.emoji_events,
            color: Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildEventCard(
            title: 'Lịch đánh đôi tuần này',
            subtitle: 'Thứ 3 & Thứ 5, 18:00',
            icon: Icons.people,
            color: Colors.green,
          ),
          const SizedBox(height: 24),

          // News Section
          const Text(
            'Tin tức mới nhất',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.campaign, color: Colors.red),
              title: const Text('CLB thông báo lịch nghỉ Tết'),
              subtitle: const Text('Từ 28/01 - 05/02/2026'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: const Text('Vinh danh Top 3 tháng 01'),
              subtitle: const Text('Chúc mừng các thành viên xuất sắc'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }

  String _getTierName(double balance) {
    if (balance >= 10000000) return '💎 Kim Cương';
    if (balance >= 5000000) return '🥇 Vàng';
    if (balance >= 2000000) return '🥈 Bạc';
    return '🥉 Đồng';
  }
}
