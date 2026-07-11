import 'package:shared_preferences/shared_preferences.dart';

class UserPrefsService {
  static const _displayNameKey = 'display_name';

  Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey);
  }

  Future<void> setDisplayName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayNameKey, name.trim());
  }

  Future<bool> hasDisplayName() async {
    final name = await getDisplayName();
    return name != null && name.trim().isNotEmpty;
  }
}