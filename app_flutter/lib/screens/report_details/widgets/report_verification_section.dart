import 'package:flutter/material.dart';

import '../../../session/user_session.dart';
import '../../verification/verification_chat_screen.dart';
import '../report_details_models.dart';
import '../report_details_theme.dart';

class ReportVerificationSection extends StatelessWidget {
  final ReportDetailsData data;

  const ReportVerificationSection({super.key, required this.data});

  bool _isOwner() {
    if (!UserSession.isLoggedIn) return false;
    final user = UserSession.current.value;
    if (user == null) return false;
    final ownerId = data.reportOwnerId.trim().toLowerCase();
    if (ownerId.isEmpty || ownerId == 'anonymous') return false;
    final userId = (user.id ?? '').trim().toLowerCase();
    final email = user.email.trim().toLowerCase();
    return ownerId == userId || ownerId == email;
  }

  Color _statusColor(String status) {
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

  String _statusLabel(String status) {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      case 'under_review':
        return 'Under Review';
      default:
        return 'Pending Verification';
    }
  }

  String _statusHint(String status) {
    switch (status) {
      case 'verified':
        return 'Your report has been verified by admin.';
      case 'rejected':
        return 'Admin rejected the evidence. Open chat and send new documents.';
      case 'under_review':
        return 'Admin is reviewing your evidence. You can still reply in chat.';
      default:
        return 'Send ID, photos, and documents so admin can verify your report.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!data.isMissing || !_isOwner()) {
      return const SizedBox.shrink();
    }

    final status = data.verificationStatus.isNotEmpty
        ? data.verificationStatus
        : 'pending';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    color: ReportDetailsTheme.primaryBlue, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Report Verification',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(status).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _statusHint(status),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VerificationChatScreen(
                        reportId: data.reportId,
                        reportName: data.title,
                        isAdmin: false,
                        initialVerificationStatus: status,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                label: const Text(
                  'Chat with Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ReportDetailsTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
