import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'services/signalr_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';
import 'screens/booking_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/tournament_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_wallet_screen.dart';
import 'screens/members_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkAuth()),
        ChangeNotifierProvider(create: (_) => SignalRService()),
      ],
      child: MaterialApp(
        title: 'PCM - Vợt Thủ Phố Núi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const MainLayout(),
          '/main': (context) => const MainLayout(),
          '/booking': (context) => const BookingScreen(),
          '/wallet': (context) => const WalletScreen(),
          '/tournaments': (context) => const TournamentScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/admin/wallet': (context) => const AdminWalletScreen(),
          '/members': (context) => const MembersScreen(),
        },
      ),
    );
  }
}
