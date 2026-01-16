import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gate_response.dart';
import 'offline_service.dart';

class ApiService {
  static const String _domain = "https://njelele.ac.zw/api/gateapi";
  static String gateUrl = "$_domain/gate";
  static String syncUrl = "$_domain/sync";

  // ==================================================
  // ⚙️ AUTOMATION ENGINE (The Heavy Lifter)
  // ==================================================
  static Timer? _uploadTimer;
  static Timer? _downloadTimer;

  static void startBackgroundServices() {
    print("🤖 AUTO: Starting Background Engines...");

    // 1. Run immediately on start
    _pushQueueToServer();
    downloadDatabase();

    // 2. ⚡ FAST SYNC: Upload Queue every 30 Seconds
    _uploadTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _pushQueueToServer();
    });

    // 3. 🐢 SLOW SYNC: Download Students every 60 Minutes
    _downloadTimer = Timer.periodic(const Duration(minutes: 60), (timer) {
      downloadDatabase();
    });
  }

  // The Silent Uploader
  static Future<void> _pushQueueToServer() async {
    List<Map<String, dynamic>> queue = await OfflineService.getQueue();
    if (queue.isEmpty) return;

    print("☁️ UPLOAD: Found ${queue.length} logs to sync...");

    try {
      List<Map<String, dynamic>> successItems = [];

      for (var item in queue) {
        final response = await http
            .post(
              Uri.parse(gateUrl),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                "action": "TAP",
                "nfcUid": item['nfcUid'],
                "mode": item['mode'],
                "timestamp": item['time'], // Ensure timestamp is sent
              }),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          successItems.add(item);
        }
      }

      if (successItems.isNotEmpty) {
        await OfflineService.removeFromQueue(successItems);
        print("✅ UPLOAD: Synced ${successItems.length} logs successfully.");
      }
    } catch (e) {
      print("☁️ UPLOAD PAUSED: No connection.");
    }
  }

  // The Silent Downloader
  static Future<void> downloadDatabase() async {
    try {
      print("🔄 DOWNLOAD: Fetching student list...");
      final response = await http.get(Uri.parse(syncUrl));

      if (response.statusCode == 200) {
        // Pass the raw string to OfflineService.
        // It will use a separate thread (Isolate) to parse it.
        await OfflineService.saveStudents(response.body);
        print("✅ DOWNLOAD: List updated successfully.");
      }
    } catch (e) {
      print("❌ DOWNLOAD FAILED: $e");
    }
  }

  // ==================================================
  // ⚡ SPEED MODE TAP (100% Local)
  // ==================================================
  static Future<GateResponse> handleTap(String nfcUid, String mode) async {
    // 1. 🔍 INSTANT LOOKUP (0.01s)
    GateResponse? student = await OfflineService.findStudent(nfcUid);

    if (student == null) {
      return GateResponse(error: "Unknown Card (Wait for Sync)");
    }

    // 2. 🧠 CHECK 13-HOUR RULE (Locally)
    bool isAllowed = await OfflineService.isCoolToTap(nfcUid);

    if (!isAllowed) {
      // 🛑 RETURN "ALREADY LOGGED" BUT INCLUDE BALANCE!
      return GateResponse(
        name: student.name,
        status: "ALREADY LOGGED",
        error: "Entered Recently",
        isOffline: true,
        img: student.img,
        className: student.className,
        sex: student.sex,

        // 👇 CRITICAL UPDATE: Pass financial data even if blocked
        balance: student.balance,
        warning: student.warning,
      );
    }

    // 3. 💾 SAVE TO QUEUE (Background Thread will handle upload)
    await OfflineService.addToQueue(nfcUid, mode);

    // 4. ✅ RETURN SUCCESS INSTANTLY
    return GateResponse(
      name: student.name,
      status: "CHECK_IN", // We assume Check-In for speed
      balance: student.balance,
      warning: student.warning,
      img: student.img,
      className: student.className,
      sex: student.sex,
      isOffline: true,
    );
  }

  static Future<GateResponse> whoAmI(String nfcUid) async {
    try {
      final response = await http
          .post(
            Uri.parse(gateUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"action": "WHOAMI", "nfcUid": nfcUid}),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        return GateResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      GateResponse? local = await OfflineService.findStudent(nfcUid);
      if (local != null) return local;
      return GateResponse(error: "Scan Failed");
    }
  }

  static Future<String> linkCard(String adm, String nfcUid) async {
    try {
      final response = await http.post(
        Uri.parse(gateUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "LINK",
          "admissionNumber": adm,
          "nfcUid": nfcUid,
        }),
      );
      final data = jsonDecode(response.body);
      return data['error'] ?? data['message'] ?? "Unknown response";
    } catch (e) {
      return "Linking Failed: Connection Error";
    }
  }
}
