import 'package:flutter/material.dart';

import '../admin_theme.dart';
import '../admin_utils.dart';

class AdminReportsView extends StatelessWidget {
  final bool isMissing;
  final List<Map<String, dynamic>> reports;
  final String? error;
  final String Function(Map<String, dynamic>) reporterNameFor;
  final Future<void> Function(String id, String status)? onUpdateStatus;
  final Future<void> Function(String id) onDelete;

  const AdminReportsView({
    super.key,
    required this.isMissing,
    required this.reports,
    required this.error,
    required this.reporterNameFor,
    required this.onUpdateStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];

    if (error != null) {
      widgets.add(_ErrorBanner(message: error!));
      widgets.add(const SizedBox(height: 12));
    }

    if (reports.isEmpty) {
      widgets.add(
        _EmptyState(
          text: isMissing
              ? 'No missing reports available.'
              : 'No found reports available.',
        ),
      );
    } else {
      widgets.addAll(
        reports.map(
          (report) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: isMissing
                ? _MissingReportCard(
                    report: report,
                    reporterName: reporterNameFor(report),
                    onUpdateStatus: onUpdateStatus,
                    onDelete: onDelete,
                  )
                : _FoundReportCard(
                    report: report,
                    reporterName: reporterNameFor(report),
                    onDelete: onDelete,
                  ),
          ),
        ),
      );
    }

    return ListView(
      key: ValueKey(isMissing ? 'missing' : 'found'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: widgets,
    );
  }
}

class _MissingReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final String reporterName;
  final Future<void> Function(String id, String status)? onUpdateStatus;
  final Future<void> Function(String id) onDelete;

  const _MissingReportCard({
    required this.report,
    required this.reporterName,
    required this.onUpdateStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final id = AdminUtils.safeString(report['id']);
    final name = AdminUtils.safeString(report['fullName'], 'Unknown');
    final status = AdminUtils.normalizedStatus(report['status']);
    final location =
        AdminUtils.safeString(report['lastSeenLocation'], 'Unknown location');
    final date = AdminUtils.safeString(report['lastSeenDate']);
    final contactName = AdminUtils.safeString(report['contactName']);
    final contactPhone = AdminUtils.safeString(report['contactPhone']);
    final photo = AdminUtils.safeString(report['photo']);

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
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(url: photo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        date,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                    if (reporterName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Reported by $reporterName',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusPill(status: status),
            ],
          ),
          const SizedBox(height: 12),
          if (contactName.isNotEmpty || contactPhone.isNotEmpty)
            Row(
              children: [
                Icon(Icons.phone_outlined,
                    size: 16, color: AdminTheme.primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [contactName, contactPhone]
                        .where((value) => value.isNotEmpty)
                        .join(' - '),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: id.isEmpty
                      ? null
                      : (value) {
                          if (value != null && onUpdateStatus != null) {
                            onUpdateStatus!(id, value);
                          }
                        },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: id.isEmpty ? null : () => onDelete(id),
                tooltip: 'Delete report',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FoundReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final String reporterName;
  final Future<void> Function(String id) onDelete;

  const _FoundReportCard({
    required this.report,
    required this.reporterName,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final id = AdminUtils.safeString(report['id']);
    final location =
        AdminUtils.safeString(report['locationFound'], 'Unknown location');
    final gender = AdminUtils.safeString(report['gender'], 'Unknown');
    final age = AdminUtils.formatAge(report['estimatedAge']);
    final coords = AdminUtils.formatCoords(report['foundLat'], report['foundLng']);
    final date = AdminUtils.formatDate(report['createdAt']);
    final photo = AdminUtils.safeString(report['photo']);

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
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(url: photo),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Age $age - $gender',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (coords.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        coords,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        date,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                    if (reporterName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Reported by $reporterName',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'FOUND',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: id.isEmpty ? null : () => onDelete(id),
                tooltip: 'Delete report',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final double size;

  const _Avatar({required this.url, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final hasImage = url.isNotEmpty && url.startsWith('http');
    return Container(
      width: size,
      height: size,
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
          : Icon(Icons.person_outline, color: Colors.grey.shade500),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AdminUtils.statusColor(status).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AdminUtils.statusColor(status),
        ),
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
