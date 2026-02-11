import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../report_details_models.dart';
import '../report_details_theme.dart';

class ReportDetailsActions extends StatelessWidget {
  final ReportDetailsData data;
  final VoidCallback onTipPressed;

  const ReportDetailsActions({
    super.key,
    required this.data,
    required this.onTipPressed,
  });

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
              onPressed: onTipPressed,
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

  void _showCallMessage(BuildContext context) {
    final phone = data.contactPhone.trim();
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
