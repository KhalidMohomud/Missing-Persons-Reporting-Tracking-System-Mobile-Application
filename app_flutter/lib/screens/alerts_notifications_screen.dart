import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api.dart';
import '../routes/app_routes.dart';
import '../session/user_session.dart';
import '../widgets/login_required_dialog.dart';

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
    final message = _safeString(alert['alertMessage']);
    final lat = _safeString(alert['alertLat']);
    final lng = _safeString(alert['alertLng']);
    final reportType = _safeString(alert['reportType']);
    final sentAt = _formatDate(alert['sentAt']);

    return Container(
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  reportType.isNotEmpty
                      ? reportType.toUpperCase()
                      : 'ALERT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                sentAt.isNotEmpty ? sentAt : 'Just now',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.isNotEmpty ? message : 'Alert sent.',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (lat.isNotEmpty && lng.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Coords: $lat, $lng',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
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
              'No items to show.',
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
