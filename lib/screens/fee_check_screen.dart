import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../models/gate_response.dart';
import '../services/api_services.dart';

class FeeCheckScreen extends StatefulWidget {
  const FeeCheckScreen({super.key});

  @override
  State<FeeCheckScreen> createState() => _FeeCheckScreenState();
}

class _FeeCheckScreenState extends State<FeeCheckScreen> {
  String _status = "WAITING...";
  String _name = "Tap to Check Balance";
  String? _balanceMsg;
  String? _warning;

  Color _bgColor = Colors.orange.shade50;
  Color _cardColor = Colors.white;
  bool _isProcessing = false;
  String? _lastScannedUid;

  @override
  void initState() {
    super.initState();
    print("💰 [FeeCheck] Screen Initialized");
    _startNFC();
  }

  void _startNFC() async {
    if (!(await NfcManager.instance.isAvailable())) {
      print("❌ [FeeCheck] NFC Not Available");
      return;
    }
    
    print("📡 [FeeCheck] NFC Session Started");

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        print("✅ [FeeCheck] Tag Discovered");

        // 🛠️ OLD STYLE (3.5.0 Compatible)
        var id = tag.data['nfca']?['identifier'] ?? 
                 tag.data['mifare']?['identifier'] ??
                 tag.data['isodep']?['identifier'];

        if (id == null) return;
        String uid = List<int>.from(id)
            .map((e) => e.toRadixString(16).padLeft(2, '0'))
            .join(':');

        print("👉 [FeeCheck] Scanned UID: $uid");

        if (uid == _lastScannedUid) return;
        if (_isProcessing) return;
        _isProcessing = true;

        try {
          print("🚀 [FeeCheck] Requesting Fee Status...");
          final res = await ApiService.handleTap(uid, "FEES");
          
          print("📩 [FeeCheck] Balance Received: ${res.balance}");
          
          if (!mounted) return;
          _lastScannedUid = uid;
          _updateUI(res);
        } catch (e) {
          print("❌ [FeeCheck] Error: $e");
        } finally {
          _isProcessing = false;
        }
      },
    );
  }

  void _updateUI(GateResponse res) {
    print("🎨 [FeeCheck] Updating UI -> Balance: ${res.balance}, Warning: ${res.warning}");

    setState(() {
      if (res.error != null) {
          _bgColor = Colors.grey.shade300;
          _status = "ERROR";
          _name = res.error!;
          _balanceMsg = null;
          _warning = null;
      } else {
        _name = res.name ?? "Student";
        if (res.warning != null || (res.balance != null && res.balance! > 0)) {
          _bgColor = Colors.red.shade100;
          _cardColor = Colors.red.shade50;
          _status = "OWING";
          _balanceMsg = "Balance: \$${res.balance?.toStringAsFixed(2)}";
          _warning = "PLEASE CLEAR FEES";
          print("⚠️ [FeeCheck] Student is OWING!");
        } else {
          _bgColor = Colors.blue.shade50;
          _cardColor = Colors.white;
          _status = "CLEARED";
          _balanceMsg = "Fees: Paid";
          _warning = null;
          print("✅ [FeeCheck] Student is CLEARED");
        }
      }
    });

    // Reset UI after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _status != "WAITING...") {
        print("🔄 [FeeCheck] Auto-resetting screen");
        setState(() {
          _status = "WAITING...";
          _name = "Tap to Check Balance";
          _balanceMsg = null;
          _warning = null;
          _bgColor = Colors.orange.shade50;
          _cardColor = Colors.white;
          _lastScannedUid = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          "FEE CHECKPOINT",
          style: TextStyle(
            color: Colors.deepOrange,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.90,
          height: MediaQuery.of(context).size.height * 0.60,
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
            border: _warning != null
                ? Border.all(color: Colors.red, width: 6)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _warning != null
                      ? Colors.red
                      : (_status == "ERROR" ? Colors.grey : Colors.blue),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  _name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_balanceMsg != null)
                Text(
                  _balanceMsg!,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              if (_warning != null)
                Padding(
                  padding: const EdgeInsets.only(top: 25),
                  child: Text(
                    _warning!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.red,
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