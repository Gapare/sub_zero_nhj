import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
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
  Future<void> _updateSubLCD(GateResponse res) async {
    try {
      final bytes = await _screenshotController.captureFromWidget(
        Container(
          width: 320, // Telpo M8 standard
          height: 240, // Adjusted for typical sub-LCD aspect ratio
          color: res.error != null ? Colors.red : Colors.green.shade900,
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                res.error != null ? "ACCESS DENIED" : "WELCOME",
                style: const TextStyle(
                  color: Colors.yellow,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.white, thickness: 2),
              Text(
                (res.name ?? "UNKNOWN").toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (res.status != null)
                Text(
                  res.status!,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
      );

      await _telpo.displayImageOnLCD(bytes);
    } catch (e) {
      debugPrint("LCD Error: $e");
    }
  }

  void _updateUI(GateResponse res) {
    setState(() {
      if (res.error != null && res.status != "ALREADY LOGGED") {
        _bgColor = Colors.red.shade100;
        _message = "ERROR";
        _subMessage = res.error!;
        _icon = Icons.error_outline;
      } else {
        if (res.status == "CHECK_IN" || res.status == "OFFLINE_LOG") {
          _bgColor = Colors.green.shade100;
          _message = "WELCOME IN";
          _subMessage = "${res.name}\nChecked In";
          _icon = Icons.login;
        } else if (res.status == "ALREADY LOGGED") {
          _bgColor = Colors.grey.shade400;
          _message = "ALREADY IN";
          _subMessage = "${res.name}\nEntered recently.";
          _icon = Icons.history;
        }
      }
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _message != "READY TO SCAN") {
        setState(() {
          _message = "READY TO SCAN";
          _subMessage = "Next student, please tap.";
          _bgColor = Colors.green.shade50;
          _icon = Icons.wifi_tethering;
          _lastScannedUid = null;
        });

        // Clear LCD back to Ready state
        _clearSubLCD();
      }
    });
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
