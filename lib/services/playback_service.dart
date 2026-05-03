import 'package:shared_preferences/shared_preferences.dart';

class PlaybackService {
  static Future<void> savePosition(String path, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("pos_$path", seconds);
  }

  static Future<int> getPosition(String path) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("pos_$path") ?? 0;
  }
}