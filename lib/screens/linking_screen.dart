import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../services/api_services.dart';

class LinkingScreen extends StatefulWidget {
  const LinkingScreen({super.key});

  @override
  State<LinkingScreen> createState() => _LinkingScreenState();
}

class _LinkingScreenState extends State<LinkingScreen> {
  final _admController = TextEditingController();
  bool _isScanning = false;
  String _status = "Enter Admission Number";

  void _startLinking() {
    if (_admController.text.isEmpty) {
      setState(() => _status = "Enter Admission # first!");
      return;
    }
    setState(() {
      _isScanning = true;
      _status = "TAP CARD NOW...";
    });

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        var id = tag.data['nfca']?['identifier'] ?? tag.data['mifare']?['identifier'];
        if (id != null) {
          String uid = List<int>.from(id)
              .map((e) => e.toRadixString(16).padLeft(2, '0'))
              .join(':');
              
          final msg = await ApiService.linkCard(_admController.text, uid);
          if (!mounted) return;
          
          setState(() {
            _isScanning = false;
            _status = msg;
            if (msg.contains("Success") || msg.contains("linked")) _admController.clear();
          });
        }
        NfcManager.instance.stopSession();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Link Cards")),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            TextField(
              controller: _admController,
              decoration: const InputDecoration(labelText: "Admission Number"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isScanning ? null : _startLinking,
              child: Text(_isScanning ? "TAP NOW..." : "START LINKING"),
            ),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}