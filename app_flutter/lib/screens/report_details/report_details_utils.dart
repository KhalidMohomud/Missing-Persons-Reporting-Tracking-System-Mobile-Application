class ReportDetailsUtils {
  static String safeString(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    if (value is Map<String, dynamic> && value['_seconds'] != null) {
      final seconds = value['_seconds'];
      if (seconds is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
          isUtc: true,
        ).toLocal();
      }
    }
    return null;
  }

  static String formatDate(dynamic value) {
    final parsed = parseDate(value);
    if (parsed == null) return safeString(value);
    return formatReadableDate(parsed);
  }

  static String formatReadableDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[date.month - 1];
    return '$month ${date.day}, ${date.year}';
  }

  static String formatAge(dynamic value) {
    if (value == null) return 'N/A';
    if (value is int) return value.toString();
    if (value is double) return value.round().toString();
    if (value is String && value.isNotEmpty) return value;
    return 'N/A';
  }
}
