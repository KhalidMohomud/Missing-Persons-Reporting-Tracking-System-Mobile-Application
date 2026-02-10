import 'package:flutter/material.dart';

import '../report_details_models.dart';
import '../report_details_theme.dart';

class ReportDetailsSection extends StatelessWidget {
  final ReportDetailsData data;

  const ReportDetailsSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.isMissing ? 'Last Seen Details' : 'Found Details',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.location_on,
            label: data.locationLabel,
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.calendar_today,
            label: data.dateLabel,
          ),
          const SizedBox(height: 20),
          const Text(
            'Case Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.description.isNotEmpty
                ? data.description
                : 'No description provided.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: ReportDetailsTheme.primaryBlue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: ReportDetailsTheme.primaryBlue, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label.isNotEmpty ? label : 'Not specified',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
