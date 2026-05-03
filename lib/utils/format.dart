String formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  int hours = d.inHours;
  int minutes = d.inMinutes.remainder(60);
  int seconds = d.inSeconds.remainder(60);

  if (hours > 0) {
    return "$hours:${two(minutes)}:${two(seconds)}";
  }
  return "${two(minutes)}:${two(seconds)}";
}
