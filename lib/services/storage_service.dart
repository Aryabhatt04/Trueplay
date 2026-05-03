import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static Future<List<String>> loadVideos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList("manual_videos") ?? [];
  }

  static Future<void> saveVideos(List<String> videos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("manual_videos", videos);
  }
}