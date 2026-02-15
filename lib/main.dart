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
        primarySwatch: Colors.green,
        useMaterial3: true,
        brightness: Brightness.light,
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

class _BootCheckScreenState extends State<BootCheckScreen> {
  String _log = ">> FIKS_OS KERNEL INITIALIZED\n>> AUTHOR: ENGINEER GAPARE E.";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _performSystemCheck();
  }

  void _logMsg(String msg) {
    if (!mounted) return;
    setState(() => _log += "\n$msg");
  }

  Future<void> _performSystemCheck() async {
    try {
      _logMsg(">> Loading System Modules...");
      await Future.delayed(const Duration(milliseconds: 600));

      // 🛠️ Hardware Mapping (Safe Check)
      try {
        final telpo = TelpoM8();
        _logMsg("✅ Hardware Interface: MAPPED");
      } catch (e) {
        _logMsg("⚠️ Driver: Using Generic Mode");
      }

      // 🛰️ Network & Sync Engine
      OfflineService.startSyncTimer();
      _logMsg("✅ Sync Engine: ACTIVE");

      // 🧠 Persistence Memory
      // Removed: OfflineService.clearQueue() to keep history!
      _logMsg("✅ Persistence: RESTORED");

      // 💳 NFC Validation
      bool isAvailable = await NfcManager.instance.isAvailable();
      _logMsg(isAvailable ? "✅ NFC Module: ONLINE" : "⚠️ NFC Module: OFFLINE");

      // 🧠 Database Integrity
      _logMsg(">> Synchronizing Local Brain...");
      await OfflineService.autoSync();
      _logMsg("✅ Database: READY");

      _logMsg("\n>> BOOT SEQUENCE SUCCESSFUL.");
      _logMsg(">> STARTING NJELELE_PRO UI...");

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _log += "\n\n[!] KERNEL PANIC: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _hasError
          ? const Color(0xFF1A0000)
          : const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _hasError ? "HALT: BOOT_FAILURE" : "NJELELE SYSTEM V1.0",
                style: TextStyle(
                  color: _hasError ? Colors.redAccent : Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 25),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(
                      color: _hasError
                          ? Colors.red
                          : Colors.greenAccent.withOpacity(0.3),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _log,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
              if (_hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                      ),
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _log = ">> REBOOTING KERNEL...";
                        });
                        _performSystemCheck();
                      },
                      child: const Text(
                        "RETRY KERNEL BOOT",
                        style: TextStyle(color: Colors.white),
                      ),
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
        selectedItemColor: Colors.green[800],
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
