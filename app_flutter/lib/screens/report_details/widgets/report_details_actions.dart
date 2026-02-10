import 'package:flutter/material.dart';

import '../report_details_models.dart';
import '../report_details_theme.dart';

class ReportDetailsActions extends StatelessWidget {
  final ReportDetailsData data;

  const ReportDetailsActions({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final hasPhone = data.contactPhone.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showTipMessage(context),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                data.isMissing ? 'Send Anonymous Tip' : 'Share Helpful Info',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ReportDetailsTheme.accentGold,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: hasPhone ? () => _showCallMessage(context) : null,
              icon: const Icon(Icons.call, color: ReportDetailsTheme.primaryBlue),
              label: Text(
                hasPhone ? 'Call Number' : 'No Contact Number',
                style: const TextStyle(
                  color: ReportDetailsTheme.primaryBlue,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                  color: ReportDetailsTheme.primaryBlue.withOpacity(0.8),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTipMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thank you. Tip feature coming soon.')),
    );
  }

  void _showCallMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Call ${data.contactPhone}')),
    );
  }
}
