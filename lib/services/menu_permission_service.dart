import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MenuPermissionService {
  static Future<bool> canSee(
      String userId, String menu, String sub) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("menu_perm_$userId");
    if (raw == null) return false;

    final data = jsonDecode(raw) as Map<String, dynamic>;
    return data[menu]?.contains(sub) ?? false;
  }
}
