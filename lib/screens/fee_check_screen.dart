import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:telpo_m8/telpo_m8.dart';
import 'package:screenshot/screenshot.dart';
import '../models/gate_response.dart';
import '../services/offline_service.dart';

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
  String? _subStatus;

  Color _bgColor = Colors.orange.shade50;
  Color _cardColor = Colors.white;
  bool _isProcessing = false;
  String? _lastScannedUid;

  final TelpoM8 _telpo = TelpoM8();
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _startNFC();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  void _startNFC() async {
    if (!(await NfcManager.instance.isAvailable())) return;

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        var id =
            tag.data['nfca']?['identifier'] ??
            tag.data['mifare']?['identifier'] ??
            tag.data['isodep']?['identifier'];
        if (id == null) return;

        String uid = List<int>.from(id)
            .map((e) => e.toRadixString(16).padLeft(2, '0'))
            .join(':')
            .toLowerCase();

        if (uid == _lastScannedUid || _isProcessing) return;
        _isProcessing = true;

        try {
          // 🚀 RUNS ALL GATE RULES (120m Lock, 10AM, etc.)
          final res = await OfflineService.handleLocalTap(uid, "FEES");

          if (!mounted) return;
          _lastScannedUid = uid;

          // Even if status is 'LOCKED', the 'res' object now contains
          // the student's name and balance because our OfflineService
          // pulls that data before checking the time locks.

          _updateUI(res); // Shows status AND fees on phone
          _updateSubLCD(res); // Shows status AND fees on Sub-LCD

          OfflineService.syncPendingTaps();
        } catch (e) {
          debugPrint("Fee Check Error: $e");
        } finally {
          if (mounted) setState(() => _isProcessing = false);
        }
      },
    );
  }

  Future<void> _updateSubLCD(GateResponse res) async {
    try {
      bool isOwing =
          res.warning != null || (res.balance != null && res.balance! > 0);

      final bytes = await _screenshotController.captureFromWidget(
        Container(
          width: 240,
          height: 120,
          color: isOwing ? Colors.red.shade900 : Colors.blue.shade900,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                (res.name ?? "STUDENT").toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const Divider(color: Colors.white54),
              Text(
                isOwing
                    ? "OWING: \$${res.balance?.toStringAsFixed(2)}"
                    : "FEES: CLEARED",
                style: TextStyle(
                  color: isOwing ? Colors.yellow : Colors.greenAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isOwing)
                const Text(
                  "PLEASE VISIT FINANCE",
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
            ],
          ),
        ),
      );

      await _telpo.displayImageOnLCD(bytes);
    } catch (_) {}
  }

  void _updateUI(GateResponse res) {
    setState(() {
      if (res.error != null && res.status != "ALREADY LOGGED") {
        _bgColor = Colors.grey.shade300;
        _status = "ERROR";
        _name = res.error!;
        _balanceMsg = null;
        _warning = null;
        _subStatus = null;
      } else {
        _name = res.name ?? "Student";
        _subStatus = (res.status == "ALREADY LOGGED")
            ? "(Already Checked In)"
            : null;

        if (res.warning != null || (res.balance != null && res.balance! > 0)) {
          _bgColor = Colors.red.shade100;
          _cardColor = Colors.red.shade50;
          _status = "OWING";
          _balanceMsg = "Balance: \$${res.balance?.toStringAsFixed(2)}";
          _warning = "PLEASE CLEAR FEES";
        } else {
          _bgColor = Colors.blue.shade50;
          _cardColor = Colors.white;
          _status = "CLEARED";
          _balanceMsg = "Fees: Paid";
          _warning = null;
        }
      }
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _status != "WAITING...") {
        setState(() {
          _status = "WAITING...";
          _name = "Tap to Check Balance";
          _balanceMsg = null;
          _warning = null;
          _subStatus = null;
          _bgColor = Colors.orange.shade50;
          _cardColor = Colors.white;
          _lastScannedUid = null;
        });
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
              "NJELELE FINANCE",
              style: TextStyle(
                color: Colors.orange,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
      await _telpo.displayImageOnLCD(bytes);
    } catch (_) {}
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
              const SizedBox(height: 10),
              if (_subStatus != null)
                Text(
                  _subStatus!,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 30),
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
