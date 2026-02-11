import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api.dart';
import '../session/user_session.dart';
import 'report_details/report_details_utils.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _missingReports = [];
  List<Map<String, dynamic>> _foundReports = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
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

  Future<List<Map<String, dynamic>>> _getReports(String url) async {
    final response = await http
        .get(Uri.parse(url), headers: _buildHeaders())
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
    return [];
  }

  bool _matchesOwner(Map<String, dynamic> report) {
    final user = UserSession.current.value;
    if (user == null) return false;
    final reportedBy = (report['reportedBy'] ?? '').toString().toLowerCase();
    if (reportedBy.isEmpty) return false;
    final userId = (user.id ?? '').toLowerCase();
    final email = user.email.toLowerCase();
    return reportedBy == userId || reportedBy == email;
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _getReports(MISSING_REPORTS_URL),
        _getReports(FOUND_REPORTS_URL),
      ]);
      if (!mounted) return;
      setState(() {
        _missingReports = results[0].where(_matchesOwner).toList();
        _foundReports = results[1].where(_matchesOwner).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load reports: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Reports'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchReports,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_error != null)
                    _ErrorBanner(message: _error!)
                  else ...[
                    _Section(
                      title: 'Missing Reports',
                      reports: _missingReports,
                      dateKey: 'lastSeenDate',
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Found Reports',
                      reports: _foundReports,
                      dateKey: 'createdAt',
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> reports;
  final String dateKey;

  const _Section({
    required this.title,
    required this.reports,
    required this.dateKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (reports.isEmpty)
            Text(
              'No reports yet.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            )
          else
            Column(
              children: reports
                  .map((report) => _DateRow(
                        dateText:
                            ReportDetailsUtils.formatDate(report[dateKey]),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String dateText;

  const _DateRow({required this.dateText});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 16, color: Colors.blueGrey.shade600),
          const SizedBox(width: 8),
          Text(
            dateText.isNotEmpty ? dateText : 'Date not provided',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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
