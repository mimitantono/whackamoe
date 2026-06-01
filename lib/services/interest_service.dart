import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class InterestService {
  static const _deviceIdKey = 'device_id';
  static const _registeredKey = 'multiplayer_interest_registered';

  static Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  static Future<bool> hasRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_registeredKey) ?? false;
  }

  static Future<void> register() async {
    try {
      final id = await _deviceId();
      await Supabase.instance.client
          .from('interest_clicks')
          .upsert({'device_id': id}, onConflict: 'device_id');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_registeredKey, true);
    } catch (_) {}
  }
}
