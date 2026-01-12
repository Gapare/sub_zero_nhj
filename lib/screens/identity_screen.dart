import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../models/gate_response.dart';
import '../services/api_services.dart';

class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key});

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  String _status = "TAP TO IDENTIFY";
  String _name = "...";
  String _details = "";
  String? _imgUrl;
  
  Color _bgColor = Colors.blue.shade50;
  bool _isProcessing = false;
  String? _lastScannedUid;

  @override
  void initState() {
    super.initState();
    _startNFC();
  }

  void _startNFC() async {
    if (!(await NfcManager.instance.isAvailable())) return;

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        // 3.5.0 Logic
        var id = tag.data['nfca']?['identifier'] ?? tag.data['mifare']?['identifier'];
        if (id == null) return;

        String uid = List<int>.from(id)
            .map((e) => e.toRadixString(16).padLeft(2, '0'))
            .join(':');

        if (uid == _lastScannedUid) return;
        if (_isProcessing) return;
        _isProcessing = true;

        try {
          // Use the WHOAMI action
          final res = await ApiService.whoAmI(uid);
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
      if (res.error != null) {
        _bgColor = Colors.red.shade100;
        _status = "UNKNOWN CARD";
        _name = "Not Registered";
        _details = "";
        _imgUrl = null;
      } else {
        _bgColor = Colors.white;
        _status = "IDENTIFIED";
        _name = res.name ?? "Student";
        _imgUrl = res.img;
        
        // Build the rich details string
        List<String> info = [];
        if (res.className != null) info.add("Class: ${res.className}");
        if (res.parentName != null) info.add("Parent: ${res.parentName}");
        if (res.parentPhone != null) info.add("Phone: ${res.parentPhone}");
        
        // Add Fee Warning if owing
        if (res.balance != null && res.balance! > 0) {
           _bgColor = Colors.orange.shade50; // Warn color
           info.add("\n⚠️ OWING: \$${res.balance?.toStringAsFixed(2)}");
        } else {
           info.add("\n✅ Fees Cleared");
        }

        _details = info.join("\n");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text("IDENTITY CHECK", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
            border: _bgColor == Colors.orange.shade50 
                ? Border.all(color: Colors.orange, width: 2) 
                : null
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.blue.shade50,
                backgroundImage: _imgUrl != null ? NetworkImage(_imgUrl!) : null,
                child: _imgUrl == null ? const Icon(Icons.person, size: 60, color: Colors.blue) : null,
              ),
              const SizedBox(height: 20),
              Text(_status, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 10),
              Text(_name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              if (_details.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(15),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(_details, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.5)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}