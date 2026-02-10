import 'dart:async'; // 🔥 Added for Timer
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/gate_response.dart';
import 'api_services.dart';

class OfflineService {
  static const String _studentKey = "local_students";
  static const String _pendingKey = "pending_taps";
  static const String _lastSyncKey = "last_sync_date";

  static Timer? _syncTimer; // 🔥 The Heartbeat

  // 🚀 START THE 13-SECOND HEARTBEAT
  // Call this in your main.dart or DailyGateScreen initState
  static void startSyncTimer() {
    if (_syncTimer?.isActive ?? false) return;

    print("⏲️ [Offline] 13-Second Heartbeat Started");
    _syncTimer = Timer.periodic(const Duration(seconds: 13), (timer) {
      syncPendingTaps();
    });
  }

  static void stopSyncTimer() {
    _syncTimer?.cancel();
  }

  static Future<void> autoSync() async {
    final prefs = await SharedPreferences.getInstance();
    String today = DateTime.now().toIso8601String().split('T')[0];
    String? lastSync = prefs.getString(_lastSyncKey);

    if (lastSync != today || DateTime.now().hour == 6) {
      try {
        final response = await http.get(
          Uri.parse("https://njelele.ac.zw/api/gateapi/sync"),
        );
        if (response.statusCode == 200) {
          await prefs.setString(_studentKey, response.body);
          await prefs.setString(_lastSyncKey, today);
          print("✅ [Offline] Auto-Sync Success");
        }
      } catch (e) {
        print("❌ [Offline] Auto-Sync Failed: $e");
      }
    }
    syncPendingTaps();
  }

  static Future<GateResponse> handleLocalTap(String uid, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString(_studentKey);
    if (data == null) return GateResponse(error: "Please Sync Database");

    List<dynamic> students = jsonDecode(data);
    final student = students.firstWhere(
      (s) => s['rfidUid'] == uid,
      orElse: () => null,
    );

    if (student == null) return GateResponse(error: "Card Not Registered");

    List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    String tapJson = jsonEncode({
      "nfcUid": uid,
      "mode": mode,
      "timestamp": DateTime.now().toIso8601String(),
    });

    pending.add(tapJson);
    await prefs.setStringList(_pendingKey, pending);

    // 🔥 Don't wait! Try a priority sync for THIS tap immediately
    _syncSingleTap(tapJson);

    return GateResponse(
      name: student['name'],
      balance: (student['balance'] as num?)?.toDouble(),
      warning: student['warning'],
      status: "CHECK_IN",
    );
  }

  // ☁️ PARALLEL BACKGROUND SYNC
  static Future<void> syncPendingTaps() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    if (pending.isEmpty) return;

    print("🚀 [TurboSync] Pushing ${pending.length} taps to Vercel...");

    // Map all pending taps to Future tasks and run them in parallel
    await Future.wait(pending.map((tapJson) => _syncSingleTap(tapJson)));
  }

  static Future<void> _syncSingleTap(String tapJson) async {
    var tap = jsonDecode(tapJson);
    try {
      final res = await ApiService.handleTap(tap['nfcUid'], tap['mode']);

      // If server accepts it (Success or Already In), remove from local list
      if (res.error == null || res.status == "ALREADY LOGGED") {
        await _removeTapFromPending(tapJson);
      }
    } catch (e) {
      // Keep it in pending if internet fails
    }
  }

  static Future<void> _removeTapFromPending(String tapJson) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    pending.remove(tapJson);
    await prefs.setStringList(_pendingKey, pending);
  }
}
