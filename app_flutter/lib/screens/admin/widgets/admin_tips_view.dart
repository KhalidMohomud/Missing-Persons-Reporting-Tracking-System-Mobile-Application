import 'package:flutter/material.dart';

import '../admin_theme.dart';
import '../admin_utils.dart';

class AdminTipsView extends StatelessWidget {
  final List<Map<String, dynamic>> tips;
  final String? error;
  final Future<void> Function()? onRefresh;

  const AdminTipsView({
    super.key,
    required this.tips,
    required this.error,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];

    if (error != null) {
      widgets.add(_ErrorBanner(message: error!));
      widgets.add(const SizedBox(height: 12));
    }

    if (tips.isEmpty) {
      widgets.add(
        const _EmptyState(text: 'No tips available.'),
      );
    } else {
      widgets.addAll(
        tips.map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TipCard(tip: tip),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: widgets,
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final Map<String, dynamic> tip;

  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final reportId = AdminUtils.safeString(tip['reportId']);
    final reportType = AdminUtils.safeString(tip['reportType'], 'unknown');
    final message = AdminUtils.safeString(tip['message']);
    final location = AdminUtils.safeString(tip['location']);
    final createdAt = AdminUtils.formatDate(tip['createdAt']);
    final anonymous = tip['anonymous'] == true;
    final senderId = AdminUtils.safeString(tip['senderId']);
    final alertId = AdminUtils.safeString(tip['alertId']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: anonymous
                      ? Colors.grey.shade200
                      : AdminTheme.primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  anonymous ? 'Anonymous' : 'Identified',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: anonymous
                        ? Colors.grey.shade700
                        : AdminTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (alertId.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Alert sent',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade600,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                createdAt.isNotEmpty ? createdAt : 'Just now',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.isNotEmpty ? message : 'No message provided.',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: AdminTheme.primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetaChip(label: 'Report: $reportType', icon: Icons.flag_outlined),
              if (reportId.isNotEmpty)
                _MetaChip(label: 'ID: $reportId', icon: Icons.tag),
              if (!anonymous && senderId.isNotEmpty)
                _MetaChip(label: 'Sender: $senderId', icon: Icons.person_outline),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MetaChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;

  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
