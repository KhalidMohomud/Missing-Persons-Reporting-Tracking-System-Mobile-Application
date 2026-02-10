import 'package:flutter/material.dart';

import 'report_details_models.dart';
import 'report_details_utils.dart';
import 'widgets/report_details_actions.dart';
import 'widgets/report_details_header.dart';
import 'widgets/report_details_section.dart';

class ReportDetailsScreen extends StatelessWidget {
  final ReportDetailsData data;

  const ReportDetailsScreen({super.key, required this.data});

  static ReportDetailsData fromReport({
    required Map<String, dynamic> report,
    required bool isMissing,
  }) {
    final name = ReportDetailsUtils.safeString(report['fullName']);
    final age = isMissing
        ? ReportDetailsUtils.formatAge(report['age'])
        : ReportDetailsUtils.formatAge(report['estimatedAge']);
    final gender =
        ReportDetailsUtils.safeString(report['gender'], 'Unknown').toLowerCase();
    final location = ReportDetailsUtils.safeString(
      isMissing ? report['lastSeenLocation'] : report['locationFound'],
      'Unknown location',
    );
    final date = ReportDetailsUtils.formatDate(
      isMissing ? report['lastSeenDate'] : report['createdAt'],
    );
    final description = ReportDetailsUtils.safeString(report['description']);
    final imageUrl = ReportDetailsUtils.safeString(report['photo']);
    final contactName = ReportDetailsUtils.safeString(report['contactName']);
    final contactPhone = ReportDetailsUtils.safeString(report['contactPhone']);

    final displayName = name.isNotEmpty
        ? name
        : (isMissing ? 'Unknown Person' : 'Found Person');
    final subtitle = '$age Years - $gender';

    return ReportDetailsData(
      isMissing: isMissing,
      title: displayName,
      subtitle: subtitle,
      statusLabel: isMissing ? 'MISSING' : 'FOUND',
      imageUrl: imageUrl.isNotEmpty ? imageUrl : 'assets/aamina.png',
      locationLabel: location,
      dateLabel: date.isNotEmpty ? date : 'Date not provided',
      description: description,
      contactName: contactName,
      contactPhone: contactPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReportDetailsHeader(data: data),
              const SizedBox(height: 56),
              ReportDetailsSection(data: data),
              const SizedBox(height: 24),
              ReportDetailsActions(data: data),
            ],
          ),
        ),
      ),
    );
  }
}
