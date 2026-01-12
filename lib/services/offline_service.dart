import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gate_response.dart';

class OfflineService {
  static const String _studentsKey = 'offline_students';
  static const String _queueKey = 'offline_queue';
  static const String _lastTapKey = 'last_tap_timestamps';

  // 1. Save Student Database
  static Future<void> saveStudents(List<GateResponse> students) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(students.map((e) => e.toJson()).toList());
    await prefs.setString(_studentsKey, data);
    print("💾 OFFLINE: Saved ${students.length} students.");
  }

  // 2. Find Student Locally
  static Future<GateResponse?> findStudent(String nfcUid) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_studentsKey);
    if (data == null) return null;
    final List<dynamic> jsonList = jsonDecode(data);
    try {
      final studentJson = jsonList.firstWhere((s) => s['rfidUid'] == nfcUid, orElse: () => null);
      if (studentJson != null) return GateResponse.fromJson(studentJson);
    } catch (e) {}
    return null;
  }
  
  // 3. Get All (For Debug)
  static Future<List<GateResponse>> getAllStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_studentsKey);
    if (data == null) return [];
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => GateResponse.fromJson(json)).toList();
  }

  // ==================================================
  // 🧠 INTELLIGENT LOGIC (The 13-Hour Rule Locally)
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

  // Record a tap locally (so we remember for next time)
  static Future<void> recordTapLocally(String nfcUid) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_lastTapKey);
    Map<String, dynamic> lastTaps = jsonStr != null ? jsonDecode(jsonStr) : {};
    
    lastTaps[nfcUid] = DateTime.now().toIso8601String(); // Save Current Time
    
    await prefs.setString(_lastTapKey, jsonEncode(lastTaps));
  }

  // ==================================================
  // 📤 QUEUE MANAGEMENT
  // ==================================================
  
  static Future<void> addToQueue(String nfcUid, String mode) async {
    // Double check locally before queueing
    bool allowed = await isCoolToTap(nfcUid);
    if (!allowed) {
      print("🚫 OFFLINE: Duplicate tap blocked for $nfcUid");
      return; 
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];
    
    final scanData = jsonEncode({
      "nfcUid": nfcUid,
      "mode": mode,
      "time": DateTime.now().toIso8601String()
    });
    
    queue.add(scanData);
    await prefs.setStringList(_queueKey, queue);
    
    // Mark them as tapped locally
    await recordTapLocally(nfcUid);
    
    print("📝 QUEUE: Added $nfcUid to offline queue.");
  }

  static Future<List<Map<String, dynamic>>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];
    return queue.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  // Remove specific items from queue (after successful upload)
  static Future<void> removeFromQueue(List<Map<String, dynamic>> uploadedItems) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> currentQueue = prefs.getStringList(_queueKey) ?? [];
    
    // Create a set of "signatures" to match items to remove
    Set<String> itemsToRemove = uploadedItems.map((e) => jsonEncode(e)).toSet();

    currentQueue.removeWhere((itemStr) => itemsToRemove.contains(itemStr));
    
    await prefs.setStringList(_queueKey, currentQueue);
    print("🧹 QUEUE: Cleaned ${uploadedItems.length} uploaded items.");
  }
}