import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:sub_zero/screens/admin_audit_screen.dart';
import 'package:telpo_m8/telpo_m8.dart';
import 'package:screenshot/screenshot.dart'; // 🔥 THE MAGIC ENGINE
import '../models/gate_response.dart';
import '../services/offline_service.dart';
import '../services/pin_service.dart';
import 'stats_screen.dart';
import 'linking_screen.dart';
import 'students_list.dart';

class DailyGateScreen extends StatefulWidget {
  const DailyGateScreen({super.key});

  @override
  State<DailyGateScreen> createState() => _DailyGateScreenState();
}

class _DailyGateScreenState extends State<DailyGateScreen> {
  String _message = "READY TO SCAN";
  String _subMessage = "Next student, please tap.";
  Color _bgColor = Colors.green.shade50;
  IconData _icon = Icons.wifi_tethering;

  String? _lastScannedUid;
  bool _isProcessing = false;

  final TelpoM8 _telpo = TelpoM8();
  final ScreenshotController _screenshotController =
      ScreenshotController(); // 🔥 Controller

  @override
  void initState() {
    super.initState();
    OfflineService.autoSync();
    _startNFC();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  void _startNFC() async {
    if (!(await NfcManager.instance.isAvailable())) {
      if (mounted) setState(() => _message = "NFC OFF");
      return;
    }

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        var id =
            tag.data['nfca']?['identifier'] ??
            tag.data['mifare']?['identifier'];
        if (id == null) return;

        String uid = List<int>.from(
          id,
        ).map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');

        if (uid == _lastScannedUid || _isProcessing) return;
        _isProcessing = true;

        try {
          final res = await OfflineService.handleLocalTap(uid, "PRIVACY");

          if (!mounted) return;
          _lastScannedUid = uid;

          // 1. Update Main Screen
          _updateUI(res);

          // 2. 🔥 Update Sub-LCD via Screenshot
          _updateSubLCD(res);

          OfflineService.syncPendingTaps();
        } catch (_) {
        } finally {
          _isProcessing = false;
        }
      },
    );
  }

  // 🔥 THE "FIKS" LCD ENGINE

  void _updateUI(GateResponse res) {
    setState(() {
      if (res.error != null && res.status != "ALREADY LOGGED") {
        // ❌ ACCESS DENIED / ERROR
        _bgColor = Colors.red.shade100;
        _message = "DENIED";
        _subMessage = res.error!;
        _icon = Icons.block;
      } else if (res.status == "CHECK_OUT") {
        // 🟠 STUDENT EXITING (Evening)
        _bgColor = Colors.orange.shade100;
        _message = "GOODBYE";
        _subMessage = "${res.name}\nSafe travels home!";
        _icon = Icons.logout;
      } else if (res.status == "ALREADY LOGGED") {
        // ⏳ COOLDOWN / LOCK
        _bgColor = Colors.blueGrey.shade100;
        _message = "STAY IN SCHOOL";
        _subMessage = "${res.name}\nAlready Checked In";
        _icon = Icons.timer_off;
      } else {
        // 🟢 STUDENT ARRIVING (Morning)
        _bgColor = Colors.green.shade100;
        _message = "WELCOME IN";
        _subMessage = "${res.name}\nHave a great day!";
        _icon = Icons.login;
      }
    });

    // Auto-reset to "READY TO SCAN" after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _message != "READY TO SCAN") {
        setState(() {
          _message = "READY TO SCAN";
          _subMessage = "Next student, please tap.";
          _bgColor = Colors.green.shade50;
          _icon = Icons.wifi_tethering;
          _lastScannedUid = null;
        });
        _clearSubLCD();
      }
    });
  }

  Future<void> _updateSubLCD(GateResponse res) async {
    try {
      // 🎨 Determine Theme based on direction
      Color lcdBgColor = Colors.green.shade900;
      String lcdTitle = "WELCOME";
      IconData lcdIcon = Icons.login;

      if (res.status == "CHECK_OUT") {
        lcdBgColor = Colors.orange.shade900;
        lcdTitle = "GOODBYE";
        lcdIcon = Icons.logout;
      } else if (res.status == "LOCKED_IN" || res.error != null) {
        lcdBgColor = const Color(0xFF440000); // Deep Red
        lcdTitle = "DENIED";
        lcdIcon = Icons.error_outline;
      }

      final bytes = await _screenshotController.captureFromWidget(
        Container(
          width: 320, // Calibrated for 3.2" Display
          height: 240,
          color: lcdBgColor,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(lcdIcon, color: Colors.white, size: 60),
              const SizedBox(height: 10),
              Text(
                lcdTitle,
                style: const TextStyle(
                  color: Colors.yellow,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const Divider(color: Colors.white24, thickness: 2),
              const SizedBox(height: 10),
              Text(
                (res.name ?? "STUDENT").toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

      await _telpo.displayImageOnLCD(bytes);
    } catch (e) {
      // Fail silently in production to keep the gate moving
    }
  }

  Future<void> _clearSubLCD() async {
    try {
      final bytes = await _screenshotController.captureFromWidget(
        Container(
          width: 240,
          height: 120,
          color: Colors.black,
          child: const Center(
            child: Text(
              "READY TO SCAN",
              style: TextStyle(color: Colors.greenAccent, fontSize: 20),
            ),
          ),
        ),
      );
      await _telpo.displayImageOnLCD(bytes);
    } catch (_) {}
  }

  void _openAdminPanel() async {
    String correctPin = await PinService.getPin();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        TextEditingController pinController = TextEditingController();
        return AlertDialog(
          title: const Text("Admin Access"),
          content: TextField(
            controller: pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofocus: true,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(hintText: "PIN"),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.bar_chart, color: Colors.blue),
              label: const Text("STATS"),
              onPressed: () {
                if (pinController.text == correctPin) {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StatsScreen()),
                  );
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.storage, color: Colors.orange),
              label: const Text("DATABASE"),
              onPressed: () {
                if (pinController.text == correctPin) {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentListScreen(),
                    ),
                  );
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.history_edu, color: Colors.greenAccent),
              label: const Text("AUDIT LOGS"),
              onPressed: () {
                if (pinController.text == correctPin) {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminAuditScreen()),
                  );
                }
              },
            ),
            ElevatedButton(
              onPressed: () {
                if (pinController.text == correctPin) {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LinkingScreen()),
                  );
                }
              },
              child: const Text("LINK CARDS"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: GestureDetector(
          onLongPress: _openAdminPanel,
          child: const Text(
            "NJELELE DAILY",
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, size: 90, color: Colors.green.shade700),
            const SizedBox(height: 20),
            Text(
              _message,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _subMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
