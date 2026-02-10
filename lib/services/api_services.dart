import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gate_response.dart';

class ApiService {
  static const String _domain = "https://njelele.ac.zw/api/gateapi";
  static String gateUrl = "$_domain/gate";

  // ==================================================
  // ⚡ ONLINE MODE TAP (Direct to Server)
  // ==================================================
  static Future<GateResponse> handleTap(String nfcUid, String mode) async {
    print("☁️ ONLINE TAP: Sending $nfcUid to server...");

    try {
      // 1. Send Request Directly
      final response = await http
          .post(
            Uri.parse(gateUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "action": "TAP",
              "nfcUid": nfcUid,
              "mode": mode,
              "timestamp": DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 8)); // 8s Timeout for slow POS Net

      // 2. Handle Server Response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Convert JSON to our Model
        return GateResponse.fromJson(data);
      } else {
        // Server Error (500, 404, etc)
        return GateResponse(error: "Server Error: ${response.statusCode}");
      }
    } on TimeoutException {
      return GateResponse(error: "Connection Timed Out");
    } catch (e) {
      return GateResponse(error: "Connection Failed");
    }
  }

  // ==================================================
  // 🆔 UTILITIES
  // ==================================================

  static Future<GateResponse> whoAmI(String nfcUid) async {
    try {
      final response = await http
          .post(
            Uri.parse(gateUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"action": "WHOAMI", "nfcUid": nfcUid}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return GateResponse.fromJson(jsonDecode(response.body));
      } else {
        return GateResponse(error: "Server Error");
      }
    } catch (e) {
      return GateResponse(error: "Check Internet Connection");
    }
  }

  static Future<String> linkCard(String adm, String nfcUid) async {
    try {
      final response = await http
          .post(
            Uri.parse(gateUrl),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "action": "LINK",
              "admissionNumber": adm,
              "nfcUid": nfcUid,
            }),
          )
          .timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      return data['error'] ?? data['message'] ?? "Unknown response";
    } catch (e) {
      return "Linking Failed: No Internet";
    }
  }

  // 🗑️ DUMMY METHOD (To prevent breaking Stats Screen)
  // Since we deleted OfflineService, the Stats screen will cry.
  // We return empty stats for now.
  static Future<Map<String, dynamic>> getLiveStats() async {
    // Optional: You could fetch these from the server if you have an endpoint
    return {
      "total_students": 0,
      "total_present": 0,
      "males_present": 0,
      "females_present": 0,
      "class_breakdown": {},
    };
  }
}
