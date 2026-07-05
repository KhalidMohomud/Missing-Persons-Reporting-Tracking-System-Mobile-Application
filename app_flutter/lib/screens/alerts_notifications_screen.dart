import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api.dart';
import '../routes/app_routes.dart';
import '../session/user_session.dart';
import '../widgets/alert_map_preview.dart';
import '../widgets/login_required_dialog.dart';
import 'report_details/report_details_screen.dart';

class AlertsNotificationsScreen extends StatefulWidget {
  const AlertsNotificationsScreen({super.key});

  @override
  State<AlertsNotificationsScreen> createState() =>
      _AlertsNotificationsScreenState();
}

class _AlertsNotificationsScreenState
    extends State<AlertsNotificationsScreen> {
  bool _loadingAlerts = false;
  String? _alertError;
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final user = UserSession.current.value;
    final token = user?.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final userId = user?.id;
    if (userId != null && userId.isNotEmpty) {
      headers['X-User-Id'] = userId;
    }
    final email = user?.email ?? '';
    if (email.isNotEmpty) {
      headers['X-User-Email'] = email;
    }
    final role = user?.role ?? '';
    if (role.isNotEmpty) {
      headers['X-User-Role'] = role;
    }
    return headers;
  }

  Future<void> _fetchAll() async {
    if (!UserSession.isLoggedIn) return;
    await _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() {
      _loadingAlerts = true;
      _alertError = null;
    });
    try {
      final response = await http
          .get(Uri.parse(ALERTS_URL), headers: _buildHeaders())
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
        final list = data is List
            ? data
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
            : <Map<String, dynamic>>[];
        setState(() => _alerts = list);
      } else {
        setState(() {
          _alertError = 'Failed to load alerts (${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() => _alertError = 'Network error: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingAlerts = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = UserSession.isLoggedIn;
    if (!isLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Alerts & Notifications'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 42, color: Colors.grey.shade500),
                const SizedBox(height: 12),
                Text(
                  'Log in to view alerts.',
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final shouldLogin = await showLoginRequiredDialog(context);
                    if (shouldLogin && context.mounted) {
                      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                    }
                  },
                  child: const Text('Log In'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Alerts'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _AlertsTab(
        isLoading: _loadingAlerts,
        error: _alertError,
        alerts: _alerts,
        onRefresh: _fetchAlerts,
      ),
    );
  }
}

class _AlertsTab extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> alerts;
  final Future<void> Function() onRefresh;

  const _AlertsTab({
    required this.isLoading,
    required this.error,
    required this.alerts,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (error != null) _ErrorBanner(message: error!),
          if (alerts.isEmpty && error == null) const _EmptyState(),
          ...alerts.map((alert) => _AlertCard(alert: alert)),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;

  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final summary = alert['reportSummary'];
    final summaryMap =
        summary is Map ? Map<String, dynamic>.from(summary) : null;

    final reportType = _safeString(
      summaryMap?['type'] ?? alert['reportType'],
    ).toLowerCase();
    final isMissing = reportType != 'found';

    final title = _resolveTitle(summaryMap, alert, isMissing);
    final message = _resolveMessage(summaryMap, alert, isMissing);
    final locationLabel = _safeString(summaryMap?['locationLabel']);
    final age = summaryMap?['age'];
    final gender = _safeString(summaryMap?['gender']);
    final photo = _safeString(summaryMap?['photo']);
    final sentAt = _formatDate(alert['sentAt']);
    final radiusKm = alert['radiusKm'];
    final source = _safeString(alert['source']).toLowerCase();

    final lat = _toDouble(alert['alertLat']);
    final lng = _toDouble(alert['alertLng']);
    final hasMap = lat != null && lng != null;

    final badgeColor =
        isMissing ? Colors.orange.shade700 : Colors.green.shade700;
    final badgeBg =
        isMissing ? Colors.orange.shade50 : Colors.green.shade50;

    return InkWell(
      onTap: () => _openReportDetails(context, summaryMap, isMissing),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AlertAvatar(url: photo, isMissing: isMissing),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isMissing ? 'MISSING' : 'FOUND',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          if (source == 'tip') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'TIP',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            sentAt.isNotEmpty ? sentAt : 'Just now',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (age != null || gender.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (age != null) 'Age $age',
                            if (gender.isNotEmpty) gender,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
                height: 1.35,
              ),
            ),
            if (locationLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      locationLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (radiusKm != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.radar_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Alert radius: ${_formatRadius(radiusKm)} km',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
            if (hasMap) ...[
              const SizedBox(height: 12),
              AlertMapPreview(
                lat: lat,
                lng: lng,
                isMissing: isMissing,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openReportDetails(
    BuildContext context,
    Map<String, dynamic>? summaryMap,
    bool isMissing,
  ) {
    final report = summaryMap?['report'];
    if (report is! Map) return;

    final reportMap = Map<String, dynamic>.from(report);
    if (!reportMap.containsKey('id') && alert['reportId'] != null) {
      reportMap['id'] = alert['reportId'];
    }

    final details = ReportDetailsScreen.fromReport(
      report: reportMap,
      isMissing: isMissing,
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportDetailsScreen(data: details)),
    );
  }

  String _resolveTitle(
    Map<String, dynamic>? summary,
    Map<String, dynamic> alert,
    bool isMissing,
  ) {
    final fromSummary = _safeString(summary?['title']);
    if (fromSummary.isNotEmpty) return fromSummary;

    if (isMissing) return 'Missing person alert';
    return 'Found person alert';
  }

  String _resolveMessage(
    Map<String, dynamic>? summary,
    Map<String, dynamic> alert,
    bool isMissing,
  ) {
    final rawMessage = _safeString(alert['alertMessage']);
    final source = _safeString(alert['source']).toLowerCase();
    final location = _safeString(summary?['locationLabel']);

    if (source == 'tip') {
      return rawMessage.isNotEmpty
          ? rawMessage
          : 'New tip received for this ${isMissing ? 'missing' : 'found'} report.';
    }

    if (rawMessage.length >= 8 &&
        !RegExp(r'^[a-zA-Z]{1,6}$').hasMatch(rawMessage)) {
      return rawMessage;
    }

    if (isMissing) {
      return location.isNotEmpty
          ? 'Missing person alert near $location.'
          : 'Missing person alert in your area.';
    }

    return location.isNotEmpty
        ? 'Found person reported near $location.'
        : 'Found person alert in your area.';
  }

  String _formatRadius(dynamic value) {
    final parsed = _toDouble(value);
    if (parsed == null) return '5';
    if (parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }
    return parsed.toStringAsFixed(1);
  }
}

class _AlertAvatar extends StatelessWidget {
  final String url;
  final bool isMissing;

  const _AlertAvatar({required this.url, required this.isMissing});

  @override
  Widget build(BuildContext context) {
    final hasImage = url.isNotEmpty && url.startsWith('http');
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMissing ? Colors.orange.shade50 : Colors.green.shade50,
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
          : Icon(
              isMissing ? Icons.person_search : Icons.person_pin_circle_outlined,
              color: isMissing ? Colors.orange.shade700 : Colors.green.shade700,
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No alerts yet.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
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
      margin: const EdgeInsets.only(bottom: 12),
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

String _safeString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return '';
  return text;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String _formatDate(dynamic value) {
  if (value == null) return '';
  if (value is DateTime) {
    return _formatReadable(value);
  }
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) return _formatReadable(parsed);
    return value.trim();
  }
  if (value is Map<String, dynamic> && value['_seconds'] != null) {
    final seconds = value['_seconds'];
    if (seconds is int) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      ).toLocal();
      return _formatReadable(date);
    }
  }
  return '';
}

String _formatReadable(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
