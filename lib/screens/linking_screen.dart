import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:telpo_m8/telpo_m8.dart';
import 'package:screenshot/screenshot.dart';
import '../services/api_services.dart';

class LinkingScreen extends StatefulWidget {
  const LinkingScreen({super.key});

  @override
  State<LinkingScreen> createState() => _LinkingScreenState();
}

class _LinkingScreenState extends State<LinkingScreen> {
  final _admController = TextEditingController();
  final _screenshotController = ScreenshotController();
  final _telpo = TelpoM8();

  bool _isScanning = false;
  String _status = "READY TO LINK";
  Color _statusColor = Colors.grey.shade700;

  void _startLinking() {
    final adm = _admController.text.trim();
    if (adm.isEmpty) {
      setState(() {
        _status = "ENTER ADMISSION # FIRST!";
        _statusColor = Colors.red;
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _status = "TAP CARD FOR ID: $adm";
      _statusColor = Colors.blue.shade700;
    });

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        var id =
            tag.data['nfca']?['identifier'] ??
            tag.data['mifare']?['identifier'];
        if (id != null) {
          String uid = List<int>.from(id)
              .map((e) => e.toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();

          // 🚀 SEND TO VERCEL
          final msg = await ApiService.linkCard(adm, uid);

          if (!mounted) return;

          setState(() {
            _isScanning = false;
            _status = msg;
            _statusColor = msg.contains("Success")
                ? Colors.green.shade700
                : Colors.red;
            if (msg.contains("Success")) _admController.clear();
          });

          // 📺 UPDATE SUB-LCD (SCREENSHOT HACK)
          _updateLcdLink(adm, uid, msg.contains("Success"));
        }
        NfcManager.instance.stopSession();
      },
    );
  }

  Future<void> _updateLcdLink(String adm, String uid, bool success) async {
    try {
      final bytes = await _screenshotController.captureFromWidget(
        Container(
          width: 240,
          height: 120,
          color: success ? Colors.green.shade900 : Colors.red.shade900,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                success ? "LINK SUCCESS ✅" : "LINK FAILED ❌",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.white24),
              Text(
                "ADM: $adm",
                style: const TextStyle(color: Colors.yellow, fontSize: 20),
              ),
              Text(
                uid,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      );
      await _telpo.displayImageOnLCD(bytes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "SMART CARD LINKING",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Icon(Icons.vignette_outlined, size: 80, color: Colors.blue),
            const SizedBox(height: 30),
            TextField(
              controller: _admController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                labelText: "STUDENT ADMISSION NUMBER",
                hintText: "e.g. 1024",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                prefixIcon: const Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? null : _startLinking,
                icon: Icon(_isScanning ? Icons.sync : Icons.nfc),
                label: Text(
                  _isScanning ? "WAITING FOR TAP..." : "INITIATE LINK",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _statusColor, width: 2),
              ),
              child: Text(
                _status.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
