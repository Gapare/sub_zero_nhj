import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const String _pinKey = 'admin_pin';

  static Future<String> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) ?? "1234"; // Default PIN
  }

  static Future<void> setPin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, newPin);
  }
}