import 'dart:convert';
import 'package:flutter/foundation.dart'; // For compute()
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gate_response.dart';

// 🧵 BACKGROUND WORKER: Parses JSON on a separate thread (The "2nd Thread")
List<GateResponse> parseStudentsInIsolate(String responseBody) {
  final List<dynamic> parsed = jsonDecode(responseBody);
  return parsed
      .map<GateResponse>((json) => GateResponse.fromJson(json))
      .toList();
}

class OfflineService {
  static const String _studentsKey = 'offline_students';
  static const String _queueKey = 'offline_queue';
  static const String _lastTapKey = 'last_tap_timestamps';

  // ==================================================
  // 📥 PART 1: STORAGE & PARSING
  // ==================================================

  // Save Students (Using Isolate to prevent UI Freeze)
  static Future<void> saveStudents(String jsonString) async {
    // 🧵 Run parsing in a background thread
    List<GateResponse> students = await compute(
      parseStudentsInIsolate,
      jsonString,
    );

    final prefs = await SharedPreferences.getInstance();
    // We save the raw string to save time
    await prefs.setString(_studentsKey, jsonString);
    print("💾 STORAGE: Saved ${students.length} students to local DB.");
  }

  // Find Student (Instant Lookup)
  static Future<GateResponse?> findStudent(String nfcUid) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_studentsKey);
    if (data == null) return null;

    // We decode on the fly for single lookups (fast enough)
    final List<dynamic> jsonList = jsonDecode(data);
    try {
      final studentJson = jsonList.firstWhere(
        (s) => s['rfidUid'] == nfcUid,
        orElse: () => null,
      );
      if (studentJson != null) return GateResponse.fromJson(studentJson);
    } catch (e) {}
    return null;
  }

  // ==================================================
  // 🧠 PART 2: THE 13-HOUR RULE (LOCAL)
  // ==================================================

  // Returns TRUE if allowed to tap (passed 13 hours since last tap)
  static Future<bool> isCoolToTap(String nfcUid) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_lastTapKey);
    Map<String, dynamic> lastTaps = jsonStr != null ? jsonDecode(jsonStr) : {};

    if (lastTaps.containsKey(nfcUid)) {
      DateTime lastTime = DateTime.parse(lastTaps[nfcUid]);
      Duration diff = DateTime.now().difference(lastTime);

      // If less than 13 hours, BLOCK THEM
      if (diff.inHours < 13) {
        return false;
      }
    }
    return true;
  }

  // Record a tap locally
  static Future<void> recordTapLocally(String nfcUid) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_lastTapKey);
    Map<String, dynamic> lastTaps = jsonStr != null ? jsonDecode(jsonStr) : {};

    lastTaps[nfcUid] = DateTime.now().toIso8601String();

    await prefs.setString(_lastTapKey, jsonEncode(lastTaps));
  }

  // ==================================================
  // 📤 PART 3: THE QUEUE (BUFFER)
  // ==================================================

  static Future<void> addToQueue(String nfcUid, String mode) async {
    // Double check locally before queueing
    bool allowed = await isCoolToTap(nfcUid);
    if (!allowed) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];

    final scanData = jsonEncode({
      "nfcUid": nfcUid,
      "mode": mode,
      "time": DateTime.now().toIso8601String(),
    });

    queue.add(scanData);
    await prefs.setStringList(_queueKey, queue);

    // Mark as present locally immediately
    await recordTapLocally(nfcUid);

    print("📝 QUEUE: Added $nfcUid. Queue size: ${queue.length}");
  }

  static Future<List<Map<String, dynamic>>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];
    return queue.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<void> removeFromQueue(
    List<Map<String, dynamic>> uploadedItems,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> currentQueue = prefs.getStringList(_queueKey) ?? [];
    Set<String> itemsToRemove = uploadedItems.map((e) => jsonEncode(e)).toSet();
    currentQueue.removeWhere((itemStr) => itemsToRemove.contains(itemStr));
    await prefs.setStringList(_queueKey, currentQueue);
  }

  // ==================================================
  // 📊 PART 4: REAL-TIME STATS CALCULATOR
  // ==================================================
  static Future<Map<String, dynamic>> getLiveStats() async {
    final prefs = await SharedPreferences.getInstance();

    final String? data = prefs.getString(_studentsKey);
    if (data == null) return {};
    List<dynamic> allStudents = jsonDecode(data);

    final String? jsonStr = prefs.getString(_lastTapKey);
    Map<String, dynamic> lastTaps = jsonStr != null ? jsonDecode(jsonStr) : {};

    int malesPresent = 0;
    int femalesPresent = 0;
    Map<String, int> classCounts = {};
    int totalPresent = 0;

    // Iterate through all students to check who is present
    for (var s in allStudents) {
      String uid = s['rfidUid'] ?? "";
      String gender = s['sex'] ?? "Unknown";
      String className = s['class'] ?? "Unknown";

      if (lastTaps.containsKey(uid)) {
        DateTime lastTime = DateTime.parse(lastTaps[uid]);
        Duration diff = DateTime.now().difference(lastTime);

        // PRESENT if tapped < 13 hours ago
        if (diff.inHours < 13) {
          totalPresent++;
          if (gender.toLowerCase().startsWith('m')) malesPresent++;
          if (gender.toLowerCase().startsWith('f')) femalesPresent++;
          classCounts[className] = (classCounts[className] ?? 0) + 1;
        }
      }
    }

    return {
      "total_students": allStudents.length,
      "total_present": totalPresent,
      "males_present": malesPresent,
      "females_present": femalesPresent,
      "class_breakdown": classCounts,
    };
  }
}
