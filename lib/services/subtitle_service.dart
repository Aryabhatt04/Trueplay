import '../models/subtitle_model.dart';

class SubtitleService {
  /// Parse SRT or WebVTT content into a list of [Subtitle] entries.
  /// Handles both \r\n and \n line endings.
  static List<Subtitle> parseSRT(String content) {
    // Normalize all line endings
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Strip WebVTT header if present
    String body = normalized;
    if (body.startsWith('WEBVTT')) {
      final headerEnd = body.indexOf('\n\n');
      if (headerEnd != -1) {
        body = body.substring(headerEnd + 2);
      }
    }

    final List<Subtitle> subtitles = [];
    // Split on one or more blank lines
    final blocks = body.trim().split(RegExp(r'\n{2,}'));

    for (var block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;

      // Skip the index line if it's a plain number (SRT)
      int timeLineIndex = 0;
      if (RegExp(r'^\d+$').hasMatch(lines[0].trim())) {
        timeLineIndex = 1;
      }

      if (timeLineIndex >= lines.length) continue;

      final timeLine = lines[timeLineIndex].trim();
      // Match both SRT (,) and VTT (.) millisecond separators
      final timeMatch = RegExp(
        r'(\d{1,2}:\d{2}:\d{2}[,\.]\d{1,3})\s*-->\s*(\d{1,2}:\d{2}:\d{2}[,\.]\d{1,3})',
      ).firstMatch(timeLine);

      if (timeMatch == null) continue;

      final start = _parseTime(timeMatch.group(1)!);
      final end = _parseTime(timeMatch.group(2)!);

      // Everything after the time line is text
      final textLines = lines.sublist(timeLineIndex + 1);
      // Strip basic HTML/VTT tags like <i>, <b>, <c.white>, etc.
      final text = textLines
          .map((l) => l.replaceAll(RegExp(r'<[^>]+>'), '').trim())
          .where((l) => l.isNotEmpty)
          .join('\n');

      if (text.isNotEmpty) {
        subtitles.add(Subtitle(start, end, text));
      }
    }

    return subtitles;
  }

  static Duration _parseTime(String t) {
    // Normalize comma to dot
    final normalized = t.trim().replaceAll(',', '.');
    final parts = normalized.split(':');
    if (parts.length < 3) return Duration.zero;

    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split('.');
    final seconds = int.tryParse(secParts[0]) ?? 0;
    int millis = 0;
    if (secParts.length > 1) {
      // Pad/truncate to 3 digits
      String ms = secParts[1].padRight(3, '0').substring(0, 3);
      millis = int.tryParse(ms) ?? 0;
    }

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
  }
}
