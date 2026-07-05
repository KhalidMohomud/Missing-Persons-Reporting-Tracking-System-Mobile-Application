import 'package:flutter/material.dart';

class AdminUtils {
  static String safeString(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  static String formatDate(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) {
      return _formatDatePart(value.toLocal());
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return _formatDatePart(parsed.toLocal());
      }
      return value;
    }
    if (value is Map<String, dynamic> && value['_seconds'] != null) {
      final seconds = value['_seconds'];
      if (seconds is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
          isUtc: true,
        ).toLocal();
        return _formatDatePart(date);
      }
    }
    return '';
  }

  static String _formatDatePart(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String buildRangeText(dynamic start, dynamic end) {
    final startText = safeString(start);
    final endText = safeString(end);
    if (startText.isEmpty && endText.isEmpty) return '';
    if (startText.isNotEmpty && endText.isNotEmpty) {
      return '$startText -> $endText';
    }
    return startText.isNotEmpty ? startText : endText;
  }

  static String formatAge(dynamic value) {
    if (value == null) return 'N/A';
    if (value is int) return value.toString();
    if (value is double) return value.round().toString();
    if (value is String && value.isNotEmpty) return value;
    return 'N/A';
  }

  static String formatCoords(dynamic lat, dynamic lng) {
    final latStr = safeString(lat);
    final lngStr = safeString(lng);
    if (latStr.isEmpty || lngStr.isEmpty) return '';
    return 'Coords: $latStr, $lngStr';
  }

  static String normalizedStatus(dynamic value) {
    final status = safeString(value, 'pending').toLowerCase();
    if (status == 'resolved' || status == 'closed') {
      return status;
    }
    return 'pending';
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.green.shade700;
      case 'closed':
        return Colors.grey.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return 'Open';
    }
  }

  static String normalizedVerificationStatus(dynamic value) {
    final status = safeString(value, 'pending').toLowerCase();
    if (status == 'verified' ||
        status == 'rejected' ||
        status == 'under_review') {
      return status;
    }
    return 'pending';
  }

  static Color verificationStatusColor(String status) {
    switch (status) {
      case 'verified':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      case 'under_review':
        return Colors.blue.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  static String verificationStatusLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'under_review':
        return 'Under Review';
      default:
        return 'Unverified';
    }
  }

  static bool shouldShowVerificationStatus(
    String reportStatus,
    String verificationStatus,
  ) {
    if (reportStatus == 'pending') return true;
    return verificationStatus == 'verified' || verificationStatus == 'rejected';
  }
}
