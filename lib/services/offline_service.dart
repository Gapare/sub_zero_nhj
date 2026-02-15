import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/gate_response.dart';
import 'api_services.dart';

class OfflineService {
  static const String _studentKey = "local_students";
  static const String _pendingKey = "pending_taps";
  static const String _historyKey = "taps_history";
  static const String _auditLogKey = "admin_audit_logs";
  static const String _lastAbsentSweepKey = "last_absent_sweep";
  static const String _lastAutoCheckoutKey = "last_checkout_sweep";

  // 🛡️ PRODUCTION CONFIGURATION
  static const int lockGapMinutes = 120; // 2 Hours security gap
  static const int passOpeningHour = 10; // 10:00 AM Pass Policy

  static Timer? _syncTimer;

  // 🚀 START THE KERNEL ENGINE
  static void startSyncTimer() {
    if (_syncTimer?.isActive ?? false) return;
    print(
      "⏲️ [KERNEL] Production Engine Live | Policy: 10AM Check-Out | Lock: 120m",
    );
    _syncTimer = Timer.periodic(const Duration(seconds: 13), (timer) {
      _runScheduledTasks();
      syncPendingTaps();
    });
  }

  static void stopSyncTimer() => _syncTimer?.cancel();

  // ==================================================
  // ⚡ THE JACKAL LOGIC (IN/OUT/LOCKDOWN)
  // ==================================================
  static Future<GateResponse> handleLocalTap(String uid, String mode) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Database Lookup
    String? data = prefs.getString(_studentKey);
    if (data == null) return GateResponse(error: "Sync Database First");
    List<dynamic> students = jsonDecode(data);
    final student = students.firstWhere(
      (s) => s['rfidUid'] == uid,
      orElse: () => null,
    );
    if (student == null) return GateResponse(error: "Card Not Registered");

    // 2. Memory Analysis
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    final now = DateTime.now();
    final today = now.toIso8601String().split('T')[0];

    bool isCheckOut = false;

    try {
      final lastTapJson = history.lastWhere(
        (t) =>
            jsonDecode(t)['nfcUid'] == uid &&
            jsonDecode(t)['timestamp'].startsWith(today),
        orElse: () => "",
      );

      if (lastTapJson.isNotEmpty) {
        var lastTap = jsonDecode(lastTapJson);
        DateTime lastTime = DateTime.parse(lastTap['timestamp']);
        int diff = now.difference(lastTime).inMinutes;

        // 🛑 RULE 1: ANTI-RETURN LOCKDOWN
        if (lastTap['status'] == "CHECK_OUT") {
          await logDecision(
            "Access Denied",
            "${student['name']} already left today.",
            "RE-ENTRY BLOCKED",
          );
          return GateResponse(
            name: student['name'],
            status: "LOCKED",
            error: "Already Left for Today",
          );
        }

        // 🛡️ RULE 2: PASS POLICY (10 AM & 2-Hour Gap)
        bool isPastTen = now.hour >= passOpeningHour;
        bool isSafetyGapMet = diff >= lockGapMinutes;

        if (isPastTen && isSafetyGapMet) {
          isCheckOut = lastTap['status'] == "CHECK_IN";
          await logDecision(
            "Tap Logic",
            "Check-out window open.",
            "Toggle to OUT",
          );
        } else {
          String reason = !isPastTen
              ? "Passes only issued after 10:00 AM"
              : "Security Lock: Wait for 10am to checkout, ${lockGapMinutes - diff}m remaining";

          await logDecision("Tap Locked", reason, "GATE REJECTED");
          return GateResponse(
            name: student['name'],
            status: "LOCKED",
            error: reason,
          );
        }
      } else {
        await logDecision("Tap Logic", "First arrival of the day.", "CHECK_IN");
      }
    } catch (e) {
      print("⚠️ Logic Error: $e");
    }

    String finalStatus = isCheckOut ? "CHECK_OUT" : "CHECK_IN";
    String tapJson = jsonEncode({
      "action": "TAP",
      "nfcUid": uid,
      "mode": mode,
      "status": finalStatus,
      "timestamp": now.toIso8601String(),
    });

    // 3. Persistent Storage
    List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    pending.add(tapJson);
    history.add(tapJson);

    await prefs.setStringList(_pendingKey, pending);
    await prefs.setStringList(_historyKey, history);

    _syncSingleTap(tapJson);

    return GateResponse(
      name: student['name'],
      balance: (student['balance'] as num?)?.toDouble(),
      status: finalStatus,
    );
  }

  // ==================================================
  // 📜 AUDIT SYSTEM (The Memory Logbook)
  // ==================================================
  static Future<void> logDecision(
    String title,
    String decision,
    String action,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> logs = prefs.getStringList(_auditLogKey) ?? [];

    logs.insert(
      0,
      jsonEncode({
        "time": DateTime.now().toIso8601String(),
        "title": title,
        "decision": decision,
        "action": action,
      }),
    );

    if (logs.length > 50) logs.removeLast();
    await prefs.setStringList(_auditLogKey, logs);
  }

  // ==================================================
  // 🛰️ SYNC & SCHEDULED TASKS
  // ==================================================
  static Future<void> _runScheduledTasks() async {
    final now = DateTime.now();
    if (now.weekday > 5) return; // Sabbath Rule (No sweeps on weekends)

    final today = now.toIso8601String().split('T')[0];
    final prefs = await SharedPreferences.getInstance();

    // 📵 08:10 AM ABSENT SWEEP
    if ((now.hour > 8 || (now.hour == 8 && now.minute >= 10)) &&
        prefs.getString(_lastAbsentSweepKey) != today) {
      await _performAbsentSweep(today);
      await prefs.setString(_lastAbsentSweepKey, today);
      await logDecision(
        "Auto Sweep",
        "8:10 Cutoff reached.",
        "Students marked ABSENT",
      );
    }

    // 🌙 21:00 PM AUTO-CHECKOUT
    if (now.hour >= 21 && prefs.getString(_lastAutoCheckoutKey) != today) {
      await _performAutoCheckout(today);
      await prefs.setString(_lastAutoCheckoutKey, today);
      await logDecision("Daily Reset", "21:00 Cleanup.", "Closed all sessions");
    }
  }

  static Future<void> syncPendingTaps() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    if (pending.isEmpty) return;
    await Future.wait(pending.map((tapJson) => _syncSingleTap(tapJson)));
  }

  static Future<void> _syncSingleTap(String tapJson) async {
    var tap = jsonDecode(tapJson);
    try {
      final res = await ApiService.handleTap(
        tap['nfcUid'],
        tap['mode'],
        status: tap['status'],
      );
      if (res.error == null || res.status == "ALREADY_LOGGED") {
        final prefs = await SharedPreferences.getInstance();
        List<String> p = prefs.getStringList(_pendingKey) ?? [];
        if (p.remove(tapJson)) await prefs.setStringList(_pendingKey, p);
      }
    } catch (_) {}
  }

  static Future<void> autoSync() async {
    try {
      final response = await http.get(
        Uri.parse("https://njelele.ac.zw/api/gateapi/sync"),
      );
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_studentKey, response.body);
        print("✅ Database Synchronized.");
      }
    } catch (_) {}
  }

  // ==================================================
  // 🧹 SYSTEM CLEANUP (Pending Queue Only)
  // ==================================================
  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
    // Note: We NO LONGER clear history or audit logs here!
    print("🧹 [System] Pending Sync Queue Purged.");
  }

  // Helper methods for Sweeps...
  static Future<void> _performAbsentSweep(String today) async {
    final prefs = await SharedPreferences.getInstance();
    String? studentData = prefs.getString(_studentKey);
    if (studentData == null) return;
    List<dynamic> allStudents = jsonDecode(studentData);
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    for (var student in allStudents) {
      String uid = student['rfidUid'] ?? "";
      if (uid.isEmpty) continue;
      bool hasTapped = history.any(
        (t) =>
            jsonDecode(t)['nfcUid'] == uid &&
            jsonDecode(t)['timestamp'].startsWith(today),
      );
      if (!hasTapped) {
        pending.add(
          jsonEncode({
            "action": "TAP",
            "nfcUid": uid,
            "mode": "ATTENDANCE",
            "status": "ABSENT",
            "timestamp": DateTime.now().toIso8601String(),
          }),
        );
      }
    }
    await prefs.setStringList(_pendingKey, pending);
  }

  static Future<void> _performAutoCheckout(String today) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_historyKey) ?? [];
    List<String> pending = prefs.getStringList(_pendingKey) ?? [];
    Map<String, String> states = {};
    for (var t in history) {
      var tap = jsonDecode(t);
      if (tap['timestamp'].startsWith(today))
        states[tap['nfcUid']] = tap['status'];
    }
    states.forEach((uid, status) {
      if (status == "CHECK_IN") {
        pending.add(
          jsonEncode({
            "action": "TAP",
            "nfcUid": uid,
            "mode": "ATTENDANCE",
            "status": "CHECK_OUT",
            "timestamp": DateTime.now().toIso8601String(),
            "notes": "AUTO_EXIT",
          }),
        );
      }
    });
    await prefs.setStringList(_pendingKey, pending);
  }
}
