import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../models/gate_response.dart';
import '../services/api_services.dart';
import '../services/pin_service.dart';
import 'debug_screen.dart';
import 'linking_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // 🔥 START THE AUTOMATIC ENGINES
    ApiService.startBackgroundServices();
    _startNFC();
  }
  
  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  void _startNFC() async {
    if (!(await NfcManager.instance.isAvailable())) {
      if(mounted) setState(() => _message = "NFC OFF");
      return;
    }

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        // 🛠️ 3.5.0 Compatible Logic
        var id = tag.data['nfca']?['identifier'] ?? tag.data['mifare']?['identifier'];
        if (id == null) return;

        String uid = List<int>.from(id)
            .map((e) => e.toRadixString(16).padLeft(2, '0'))
            .join(':');

        if (uid == _lastScannedUid) return;
        if (_isProcessing) return;
        _isProcessing = true;

        try {
          // ⚡ LOCAL TAP (No Internet Wait)
          final res = await ApiService.handleTap(uid, "PRIVACY");
          if (!mounted) return;
          _lastScannedUid = uid;
          _updateUI(res);
        } catch (_) {
        } finally {
          _isProcessing = false;
        }
      },
    );
  }

  void _updateUI(GateResponse res) {
    setState(() {
      if (res.error != null && res.status != "ALREADY LOGGED") {
          _bgColor = Colors.red.shade100;
          _message = "ERROR";
          _subMessage = res.error!;
          _icon = Icons.error_outline;
      } else {
        // ✅ CHECK IN (Local or Online)
        if (res.status == "CHECK_IN" || res.status == "OFFLINE_LOG") {
          _bgColor = Colors.green.shade100;
          _message = "WELCOME IN";
          _subMessage = "${res.name}\nChecked In";
          _icon = Icons.login;
        } 
        // 🕒 ALREADY LOGGED (13-Hour Rule)
        else if (res.status == "ALREADY LOGGED") {
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
      }
    });
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
             // 📊 STATS BUTTON
             TextButton.icon(
               icon: const Icon(Icons.bar_chart, color: Colors.blue),
               label: const Text("STATS"),
               onPressed: () {
                 if (pinController.text == correctPin) {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
                 }
               },
             ),
             ElevatedButton(
              onPressed: () {
                if (pinController.text == correctPin) {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkingScreen()));
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
          child: const Text("NJELELE DAILY", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_icon, size: 90, color: Colors.green.shade700),
            const SizedBox(height: 20),
            Text(_message, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(_subMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}