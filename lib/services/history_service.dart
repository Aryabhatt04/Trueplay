import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static Future<void> addToHistory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList("history") ?? [];

    history.remove(path);
    history.insert(0, path);

    await prefs.setStringList("history", history);
  }

  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList("history") ?? [];
  }
}