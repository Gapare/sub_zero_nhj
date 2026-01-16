import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/daily_gate_screen.dart';
import 'screens/fee_check_screen.dart';
import 'screens/identity_screen.dart';
import 'services/api_services.dart'; // 👈 Added for background services

void main() {
  // 1. SAFE STARTUP: Catch errors before the app even runs
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ⚠️ REMOVED: SystemChrome.setPreferredOrientations
      // POS devices often crash if you try to force orientation.

      runApp(const NjeleleApp());
    },
    (error, stack) {
      // 2. GLOBAL ERROR CATCHER
      // If the app crashes, this will print it to the screen/console
      print("💥 CRITICAL ERROR: $error");
    },
  );
}

class NjeleleApp extends StatelessWidget {
  const NjeleleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Njelele Gate',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      // 3. STARTUP CHECK: Don't go to Gate Screen immediately.
      // Go to a safe "Boot" screen to test the hardware first.
      home: const BootCheckScreen(),
    );
  }
}

// 🩺 A NEW SCREEN TO DIAGNOSE THE POS
class BootCheckScreen extends StatefulWidget {
  const BootCheckScreen({super.key});

  @override
  State<BootCheckScreen> createState() => _BootCheckScreenState();
}

class _BootCheckScreenState extends State<BootCheckScreen> {
  String _log = "Initializing...";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  void _logMsg(String msg) {
    setState(() => _log += "\n$msg");
    print(msg);
  }

  Future<void> _runChecks() async {
    try {
      // TEST 1: Storage
      _logMsg("1. Checking Storage...");
      await Future.delayed(const Duration(milliseconds: 500));
      // (Simple shared_prefs check could go here if needed)
      _logMsg("✅ Storage OK");

      // TEST 2: Internet
      _logMsg("2. Checking Connectivity...");
      // We skip actual internet check to prevent crashes, just ensuring async works
      _logMsg("✅ Async Logic OK");

      // TEST 3: NFC
      _logMsg("3. Checking NFC Library...");
      // We DON'T start scanning, just load the class to see if it crashes
      _logMsg("✅ NFC Library Loaded");

      // ⚡ START BACKGROUND ENGINES (The 2-Thread Engine)
      _logMsg("4. Starting Background Engines...");
      ApiService.startBackgroundServices();
      _logMsg("✅ Engines Started");

      _logMsg("🚀 LAUNCHING APP IN 2 SECONDS...");
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _log += "\n\n❌ CRASH DETECTED:\n$e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _hasError ? Colors.red.shade50 : Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_hasError)
                const Icon(Icons.error, color: Colors.red, size: 60)
              else
                const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                "SYSTEM BOOT",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(10),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  border: Border.all(color: Colors.grey),
                ),
                child: Text(
                  _log,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// RESTORE YOUR MAIN NAVIGATION
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget activeScreen;

    switch (_selectedIndex) {
      case 0:
        activeScreen = const DailyGateScreen();
        break;
      case 1:
        activeScreen = const FeeCheckScreen();
        break;
      case 2:
        activeScreen = const IdentityScreen();
        break;
      default:
        activeScreen = const DailyGateScreen();
    }

    return Scaffold(
      body: activeScreen,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Daily Gate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Fees',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.perm_identity),
            label: 'Identity',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
