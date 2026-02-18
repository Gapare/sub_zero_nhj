import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../models/gate_response.dart';
import '../services/api_services.dart';
import '../services/offline_service.dart';

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

  double? _feeBalance;

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
        var id =
            tag.data['nfca']?['identifier'] ??
            tag.data['mifare']?['identifier'];
        if (id == null) return;

        String uid = List<int>.from(id)
            .map((e) => e.toRadixString(16).padLeft(2, '0'))
            .join(':')
            .toLowerCase();

        if (uid == _lastScannedUid) return;
        if (_isProcessing) return;

        setState(() {
          _isProcessing = true;
          _status = "IDENTIFYING...";
        });

        try {
          final res = await OfflineService.whoAmIOffline(uid);

          if (!mounted) return;
          _lastScannedUid = uid;
          _updateUI(res);
        } catch (e) {
          _updateUI(GateResponse(error: "Server Timeout"));
        } finally {
          setState(() => _isProcessing = false);
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
        _feeBalance = null;
      } else {
        _bgColor = Colors.white;
        _status = "IDENTIFIED";
        _name = res.name ?? "Student";
        _imgUrl = res.img;

        List<String> info = [];
        if (res.className != null) info.add("Class: ${res.className}");
        if (res.parentName != null) info.add("Parent: ${res.parentName}");
        if (res.parentPhone != null) info.add("Phone: ${res.parentPhone}");

        if (res.balance != null && res.balance! > 0) {
          _bgColor = Colors.orange.shade50;
          _feeBalance = res.balance;
        } else {
          _feeBalance = 0.0;
        }

        _details = info.join("\n");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Identity Verification",
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 55,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _imgUrl != null
                    ? NetworkImage(_imgUrl!)
                    : null,
                child: _imgUrl == null
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _status == "IDENTIFIED"
                      ? Colors.green.shade50
                      : _status == "UNKNOWN CARD"
                      ? Colors.red.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _status == "IDENTIFIED"
                        ? Colors.green
                        : _status == "UNKNOWN CARD"
                        ? Colors.red
                        : Colors.blue,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                _name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 18),

              if (_details.isNotEmpty || _feeBalance != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_details.isNotEmpty)
                        Text(
                          _details,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                        ),

                      if (_feeBalance != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              _feeBalance! > 0
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              color: _feeBalance! > 0
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _feeBalance! > 0
                                  ? "OWING: \$${_feeBalance!.toStringAsFixed(2)}"
                                  : "FEES CLEARED",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _feeBalance! > 0
                                    ? Colors.orange.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
