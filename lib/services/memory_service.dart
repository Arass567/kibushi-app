import 'package:shared_preferences/shared_preferences.dart';

class MemoryService {
  static const String _keySessionCount = 'session_count';
  static const String _keyLastSession = 'last_session_timestamp';

  Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_keySessionCount) ?? 0;
    await prefs.setInt(_keySessionCount, count + 1);
    await prefs.setInt(_keyLastSession, DateTime.now().millisecondsSinceEpoch);
  }

  Future<int> getSessionCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySessionCount) ?? 0;
  }
}
