import 'package:shared_preferences/shared_preferences.dart';

class UnreadTracker {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Set<String> _getReadIds(String category) {
    final list = _prefs?.getStringList('read_${category}_ids') ?? [];
    return list.toSet();
  }

  static Future<void> markAsRead(String category, String id) async {
    if (_prefs == null) return;
    final ids = _getReadIds(category);
    if (ids.add(id)) {
      await _prefs!.setStringList('read_${category}_ids', ids.toList());
    }
  }

  static bool isRead(String category, String id) {
    final ids = _getReadIds(category);
    return ids.contains(id);
  }
}
