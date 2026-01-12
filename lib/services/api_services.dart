import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gate_response.dart';
import 'offline_service.dart';

class ApiService {
  // ⚠️ CHANGE THIS IP TO YOUR SERVER IF DEPLOYED
  static const String _domain = "https://njelele.ac.zw/api/gateapi";
  
  static String gateUrl = "$_domain/gate";
  static String syncUrl = "$_domain/sync";

  // ==================================================
  // 🤖 AUTOMATION ENGINE
  // ==================================================
  static Timer? _uploadTimer;
  static Timer? _downloadTimer;

  static void startBackgroundServices() {
    print("🤖 AUTO: Starting Background Services...");

    // 1. Run immediately on app start
    _pushQueueToServer();
    downloadDatabase();

    // 2. Upload Queue every 2 minutes (Fast Sync)
    _uploadTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _pushQueueToServer();
    });

    // 3. Download Student List every 60 minutes (Slow Sync)
    _downloadTimer = Timer.periodic(const Duration(minutes: 60), (timer) {
      downloadDatabase();
    });
  }

  // The hidden function that uploads the queue
  static Future<void> _pushQueueToServer() async {
    List<Map<String, dynamic>> queue = await OfflineService.getQueue();
    if (queue.isEmpty) return;

    print("☁️ AUTO-UPLOAD: Attempting to send ${queue.length} logs...");

    try {
      List<Map<String, dynamic>> successItems = [];

      for (var item in queue) {
        final response = await http.post(
          Uri.parse(gateUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "action": "TAP",
            "nfcUid": item['nfcUid'],
            "mode": item['mode'],
          }),
        ).timeout(const Duration(seconds: 5));

        // Accept 200 (OK)
        if (response.statusCode == 200) {
          successItems.add(item);
        }
      }

      // Remove successful uploads from phone memory
      if (successItems.isNotEmpty) {
        await OfflineService.removeFromQueue(successItems);
        print("✅ AUTO-UPLOAD: Successfully sent ${successItems.length} logs.");
      }

    } catch (e) {
      print("☁️ AUTO-UPLOAD PAUSED: Network Error");
    }
  }

  // ==================================================
  // 📡 TAP HANDLER (Smart Hybrid)
  // ==================================================

  static Future<GateResponse> handleTap(String nfcUid, String mode) async {
    // 🧠 1. CHECK LOCAL RULES FIRST (The 13-Hour Rule)
    bool isAllowed = await OfflineService.isCoolToTap(nfcUid);
    
    if (!isAllowed) {
       GateResponse? local = await OfflineService.findStudent(nfcUid);
       return GateResponse(
         name: local?.name ?? "Student",
         status: "ALREADY LOGGED", // Matches backend logic
         error: "Already clocked in (13h Rule)",
         isOffline: true,
         img: local?.img
       );
    }

    // 📡 2. TRY ONLINE
    try {
      final response = await http.post(
        Uri.parse(gateUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "action": "TAP",
          "nfcUid": nfcUid,
          "mode": mode, 
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        // Record it locally so we don't double tap offline later
        await OfflineService.recordTapLocally(nfcUid);
        return GateResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      // 🔌 3. OFFLINE FALLBACK
      print("⚠️ OFFLINE MODE: Switching to local data.");
      
      GateResponse? localStudent = await OfflineService.findStudent(nfcUid);
      
      if (localStudent != null) {
         await OfflineService.addToQueue(nfcUid, mode);
         
         return GateResponse(
           name: localStudent.name,
           status: "OFFLINE_LOG",
           balance: localStudent.balance,
           warning: localStudent.warning,
           img: localStudent.img,
           isOffline: true,
           className: localStudent.className,
         );
      }

      return GateResponse(error: "Connection Failed & Not Found");
    }
  }

  // ==================================================
  // 🛠️ UTILS (Sync, WhoAmI, Link)
  // ==================================================

  static Future<String> downloadDatabase() async {
    try {
      print("🔄 AUTO-SYNC: Connecting to $syncUrl...");
      final response = await http.get(Uri.parse(syncUrl));

      if (response.statusCode == 200) {
        List<dynamic> list = jsonDecode(response.body);
        List<GateResponse> students = list.map((json) => GateResponse.fromJson(json)).toList();
        await OfflineService.saveStudents(students);
        print("✅ AUTO-SYNC: Updated ${students.length} students.");
        return "Success";
      }
      return "Error";
    } catch (e) {
      print("❌ AUTO-SYNC FAILED: $e");
      return "Failed";
    }
  }

  static Future<GateResponse> whoAmI(String nfcUid) async {
     try {
      final response = await http.post(
        Uri.parse(gateUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"action": "WHOAMI", "nfcUid": nfcUid}),
      ).timeout(const Duration(seconds: 4));
      
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
        body: jsonEncode({"action": "LINK", "admissionNumber": adm, "nfcUid": nfcUid}),
      );
      final data = jsonDecode(response.body);
      return data['error'] ?? data['message'] ?? "Unknown response";
    } catch (e) {
      return "Linking Failed: Connection Error";
    }
  }
}