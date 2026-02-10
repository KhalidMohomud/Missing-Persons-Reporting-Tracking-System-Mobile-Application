import 'package:flutter/material.dart';

import '../admin_models.dart';
import '../admin_theme.dart';
import '../admin_utils.dart';

class AdminDashboardView extends StatelessWidget {
  final MonthlyData monthly;
  final String? error;
  final VoidCallback onViewAllMissing;
  final VoidCallback onViewAllFound;
  final String Function(Map<String, dynamic>) reporterNameFor;

  const AdminDashboardView({
    super.key,
    required this.monthly,
    required this.error,
    required this.onViewAllMissing,
    required this.onViewAllFound,
    required this.reporterNameFor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('dashboard'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (error != null) ...[
          _ErrorBanner(message: error!),
          const SizedBox(height: 12),
        ],
        _MonthlyHeader(monthly: monthly),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(
              title: 'Missing Reports',
              value: monthly.missingCount.toString(),
              icon: Icons.person_search_outlined,
              color: AdminTheme.primaryBlue,
            ),
            _SummaryCard(
              title: 'Found Reports',
              value: monthly.foundCount.toString(),
              icon: Icons.location_on_outlined,
              color: Colors.green.shade600,
            ),
            _SummaryCard(
              title: 'Total Reports',
              value: monthly.totalCount.toString(),
              icon: Icons.check_circle_outline,
              color: AdminTheme.accentGold,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _MonthlySection(
          title: 'Missing Reports (Last Month)',
          items: monthly.missing,
          isMissing: true,
          emptyText: 'No missing reports last month.',
          reporterNameFor: reporterNameFor,
          onViewAll: onViewAllMissing,
        ),
        const SizedBox(height: 12),
        _MonthlySection(
          title: 'Found Reports (Last Month)',
          items: monthly.found,
          isMissing: false,
          emptyText: 'No found reports last month.',
          reporterNameFor: reporterNameFor,
          onViewAll: onViewAllFound,
        ),
      ],
    );
  }
}

class _MonthlyHeader extends StatelessWidget {
  final MonthlyData monthly;

  const _MonthlyHeader({required this.monthly});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminTheme.primaryBlue, AdminTheme.deepBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.primaryBlue.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Overview',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  monthly.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (monthly.rangeText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    monthly.rangeText,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${monthly.totalCount} total',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AdminTheme.deepBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 56) / 2,
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _MonthlySection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final bool isMissing;
  final String emptyText;
  final VoidCallback onViewAll;
  final String Function(Map<String, dynamic>) reporterNameFor;

  const _MonthlySection({
    required this.title,
    required this.items,
    required this.isMissing,
    required this.emptyText,
    required this.onViewAll,
    required this.reporterNameFor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('View all'),
              ),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                emptyText,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            )
          else
            ...items.take(3).map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MiniReportRow(
                      report: report,
                      isMissing: isMissing,
                      reporterNameFor: reporterNameFor,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _MiniReportRow extends StatelessWidget {
  final Map<String, dynamic> report;
  final bool isMissing;
  final String Function(Map<String, dynamic>) reporterNameFor;

  const _MiniReportRow({
    required this.report,
    required this.isMissing,
    required this.reporterNameFor,
  });

  @override
  Widget build(BuildContext context) {
    final title = isMissing
        ? AdminUtils.safeString(report['fullName'], 'Unknown person')
        : AdminUtils.safeString(report['locationFound'], 'Unknown location');
    final subtitle = isMissing
        ? AdminUtils.safeString(report['lastSeenLocation'], 'Unknown location')
        : 'Age ${AdminUtils.formatAge(report['estimatedAge'])} - '
            '${AdminUtils.safeString(report['gender'], 'Unknown')}';
    final meta = isMissing
        ? AdminUtils.safeString(report['lastSeenDate'])
        : AdminUtils.formatDate(report['createdAt']);
    final status = isMissing
        ? AdminUtils.normalizedStatus(report['status'])
        : '';
    final reporter = reporterNameFor(report);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(url: AdminUtils.safeString(report['photo'])),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
              if (reporter.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Reported by $reporter',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
        if (isMissing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AdminUtils.statusColor(status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AdminUtils.statusColor(status),
              ),
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;

  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final hasImage = url.isNotEmpty && url.startsWith('http');
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blueGrey.shade50,
      ),
      child: hasImage
          ? ClipOval(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_outline,
                  color: Colors.grey.shade500,
                ),
              ),
            )
          : Icon(Icons.person_outline, color: Colors.grey.shade500, size: 20),
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
