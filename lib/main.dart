import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:telpo_m8/telpo_m8.dart';
import 'screens/daily_gate_screen.dart';
import 'screens/fee_check_screen.dart';
import 'screens/identity_screen.dart';
import 'services/offline_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.delayed(const Duration(milliseconds: 500));
  runApp(const NjeleleApp());
}

class NjeleleApp extends StatelessWidget {
  const NjeleleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Njelele Gate Pro',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E5E3A),
          primary: const Color(0xFF0E5E3A),
          surface: const Color(0xFFF5F7F6), // ✅ Fixed deprecation
        ),
      ),
      home: const BootCheckScreen(),
    );
  }
}

class BootCheckScreen extends StatefulWidget {
  const BootCheckScreen({super.key});

  @override
  State<BootCheckScreen> createState() => _BootCheckScreenState();
}

class _BootCheckScreenState extends State<BootCheckScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeIn;

  String _statusMessage = "Initializing secure services...";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _fadeController.forward();
    _performSystemCheck();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _performSystemCheck() async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));

      // ✅ Removed unnecessary 'await' on TelpoM8 constructor
      try {
        TelpoM8();
      } catch (_) {}

      OfflineService.startSyncTimer();

      if (mounted) setState(() => _statusMessage = "Syncing local database...");
      await OfflineService.autoSync();

      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _statusMessage = "Access control ready.");

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainNavigation(), // ✅ Fixed underscores
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0E5E3A);
    const softText = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.05,
                      ), // ✅ Fixed deprecation
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance,
                  size: 50,
                  color: primaryGreen,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "NJELELE HIGH SCHOOL",
                style: TextStyle(
                  color: Color(0xFF1C1C1C),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Text(
                "Access Control System",
                style: TextStyle(
                  color: softText,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 60),
              if (_hasError)
                Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 30,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "System Halt: Driver Conflict",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    TextButton(
                      onPressed: () => _performSystemCheck(),
                      child: const Text(
                        "RETRY INITIALIZATION",
                        style: TextStyle(color: primaryGreen),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: softText,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 100),
              const Opacity(
                opacity: 0.5,
                child: Text(
                  "POWERED BY THE JACKAL SYSTEMS",
                  style: TextStyle(
                    color: primaryGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ✅ RESTORED MainNavigation Class
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const DailyGateScreen(),
    const FeeCheckScreen(),
    const IdentityScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF0E5E3A),
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
        elevation: 20,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            label: 'Daily Gate',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: 'Fees'),
          BottomNavigationBarItem(icon: Icon(Icons.badge), label: 'Identity'),
        ],
      ),
    );
  }
}
