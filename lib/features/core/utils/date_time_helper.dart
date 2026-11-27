class DateTimeHelper {
  const DateTimeHelper._();

  /// Calculates Egypt Time (UTC+3 / local) and returns localized greeting
  static String getEgyptGreeting() {
    // Current UTC time + 3 hours for Egypt
    final nowUtc = DateTime.now().toUtc();
    final egyptHour = (nowUtc.hour + 3) % 24;

    if (egyptHour >= 5 && egyptHour < 12) {
      return 'صباح الخير يا';
    } else if (egyptHour >= 12 && egyptHour < 17) {
      return 'مساء الخير يا';
    } else if (egyptHour >= 17 && egyptHour < 24) {
      return 'مساء الخير يا';
    } else {
      return 'صباح الخير يا';
    }
  }

  /// Format seconds into mm:ss
  static String formatSeconds(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Format duration for video / audio
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
