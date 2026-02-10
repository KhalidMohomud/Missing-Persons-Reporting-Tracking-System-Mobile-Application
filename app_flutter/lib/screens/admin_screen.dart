import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api.dart';
import '../session/user_session.dart';

enum AdminTab { dashboard, missing, found }

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isLoading = false;
  String? _error;
  AdminTab _tab = AdminTab.dashboard;

  List<Map<String, dynamic>> _missingReports = [];
  List<Map<String, dynamic>> _foundReports = [];
  _MonthlyData _monthly = _MonthlyData.empty();

  final Color primaryBlue = const Color(0xFF2F89B8);
  final Color deepBlue = const Color(0xFF1E4E6D);
  final Color accentGold = const Color(0xFFF2C94C);
  final Color surface = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = UserSession.current.value?.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  List<Map<String, dynamic>> _parseReportList(dynamic payload) {
    dynamic data = payload;
    if (payload is Map<String, dynamic>) {
      data = payload['data'];
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> _getReports(String url) async {
    final response = await http
        .get(Uri.parse(url), headers: _buildHeaders())
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return _parseReportList(decoded);
    }
    if (response.statusCode == 404) {
      return [];
    }
    throw Exception('Failed to load reports (${response.statusCode})');
  }

  Future<_MonthlyData> _getMonthlyReports() async {
    final response = await http
        .get(Uri.parse(MONTHLY_REPORTS_URL), headers: _buildHeaders())
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load monthly reports (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return _MonthlyData.empty();
    }

    final range = decoded['range'] as Map<String, dynamic>? ?? {};
    final count = decoded['count'] as Map<String, dynamic>? ?? {};
    final data = decoded['data'] as Map<String, dynamic>? ?? {};

    final missingList = _parseReportList(data['missing']);
    final foundList = _parseReportList(data['found']);

    return _MonthlyData(
      label: _safeString(range['label'], 'Last Month'),
      rangeText: _buildRangeText(range['start'], range['end']),
      missingCount: _toInt(count['missing']),
      foundCount: _toInt(count['found']),
      totalCount: _toInt(count['total']),
      missing: missingList,
      found: foundList,
    );
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    String? error;
    var missing = _missingReports;
    var found = _foundReports;
    var monthly = _monthly;

    try {
      missing = await _getReports(MISSING_REPORTS_URL);
    } catch (e) {
      error = _appendError(error, 'Missing reports: $e');
    }

    try {
      found = await _getReports(FOUND_REPORTS_URL);
    } catch (e) {
      error = _appendError(error, 'Found reports: $e');
    }

    try {
      monthly = await _getMonthlyReports();
    } catch (e) {
      error = _appendError(error, 'Monthly reports: $e');
    }

    if (!mounted) return;
    setState(() {
      _missingReports = missing;
      _foundReports = found;
      _monthly = monthly;
      _error = error;
      _isLoading = false;
    });
  }

  Future<void> _refreshMissingAndMonthly() async {
    try {
      final missing = await _getReports(MISSING_REPORTS_URL);
      final monthly = await _getMonthlyReports();
      if (!mounted) return;
      setState(() {
        _missingReports = missing;
        _monthly = monthly;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh missing reports: $e')),
      );
    }
  }

  Future<void> _refreshFoundAndMonthly() async {
    try {
      final found = await _getReports(FOUND_REPORTS_URL);
      final monthly = await _getMonthlyReports();
      if (!mounted) return;
      setState(() {
        _foundReports = found;
        _monthly = monthly;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh found reports: $e')),
      );
    }
  }

  Future<void> _updateMissingStatus(String id, String newStatus) async {
    try {
      final uri = Uri.parse('$MISSING_REPORTS_URL/$id');
      final response = await http.patch(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        await _refreshMissingAndMonthly();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status (${response.statusCode})'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  Future<void> _deleteMissingReport(String id) async {
    try {
      final uri = Uri.parse('$MISSING_REPORTS_URL/$id');
      final response = await http.delete(uri, headers: _buildHeaders());

      if (response.statusCode == 200) {
        await _refreshMissingAndMonthly();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete report (${response.statusCode})'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  Future<void> _deleteFoundReport(String id) async {
    try {
      final uri = Uri.parse('$FOUND_REPORTS_URL/$id');
      final response = await http.delete(uri, headers: _buildHeaders());

      if (response.statusCode == 200) {
        await _refreshFoundAndMonthly();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete report (${response.statusCode})'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Manage missing and found reports',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryBlue),
            onPressed: _fetchAll,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildNavBar(),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchAll,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildNavItem(
              AdminTab.dashboard,
              'Dashboard',
              Icons.dashboard_outlined,
            ),
          ),
          Expanded(
            child: _buildNavItem(
              AdminTab.missing,
              'Missing',
              Icons.person_search_outlined,
            ),
          ),
          Expanded(
            child: _buildNavItem(
              AdminTab.found,
              'Found',
              Icons.location_on_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(AdminTab tab, String label, IconData icon) {
    final isActive = _tab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tab = tab;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [primaryBlue, deepBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingList();
    }

    switch (_tab) {
      case AdminTab.dashboard:
        return _buildDashboard();
      case AdminTab.missing:
        return _buildMissingList();
      case AdminTab.found:
        return _buildFoundList();
    }
  }

  Widget _buildLoadingList() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 140),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
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

  Widget _buildDashboard() {
    return ListView(
      key: const ValueKey('dashboard'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (_error != null) ...[
          _buildErrorBanner(_error!),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryBlue, deepBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.25),
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
                child: Icon(
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
                      _monthly.label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (_monthly.rangeText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _monthly.rangeText,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_monthly.totalCount} total',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: deepBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildSummaryCard(
              title: 'Missing Reports',
              value: _monthly.missingCount.toString(),
              icon: Icons.person_search_outlined,
              color: primaryBlue,
            ),
            _buildSummaryCard(
              title: 'Found Reports',
              value: _monthly.foundCount.toString(),
              icon: Icons.location_on_outlined,
              color: Colors.green.shade600,
            ),
            _buildSummaryCard(
              title: 'Total Reports',
              value: _monthly.totalCount.toString(),
              icon: Icons.check_circle_outline,
              color: accentGold,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _buildMonthlySection(
          title: 'Missing Reports (Last Month)',
          items: _monthly.missing,
          isMissing: true,
          emptyText: 'No missing reports last month.',
          onViewAll: () => setState(() => _tab = AdminTab.missing),
        ),
        const SizedBox(height: 12),
        _buildMonthlySection(
          title: 'Found Reports (Last Month)',
          items: _monthly.found,
          isMissing: false,
          emptyText: 'No found reports last month.',
          onViewAll: () => setState(() => _tab = AdminTab.found),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
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

  Widget _buildMonthlySection({
    required String title,
    required List<Map<String, dynamic>> items,
    required bool isMissing,
    required String emptyText,
    required VoidCallback onViewAll,
  }) {
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
              TextButton(onPressed: onViewAll, child: const Text('View all')),
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
            ...items
                .take(3)
                .map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildMiniReportRow(report, isMissing: isMissing),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildMiniReportRow(
    Map<String, dynamic> report, {
    required bool isMissing,
  }) {
    final title = isMissing
        ? _safeString(report['fullName'], 'Unknown person')
        : _safeString(report['locationFound'], 'Unknown location');
    final subtitle = isMissing
        ? _safeString(report['lastSeenLocation'], 'Unknown location')
        : 'Age ${_formatAge(report['estimatedAge'])} • '
              '${_safeString(report['gender'], 'Unknown')}';
    final meta = isMissing
        ? _safeString(report['lastSeenDate'])
        : _formatDate(report['createdAt']);
    final status = isMissing ? _safeString(report['status'], 'pending') : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(_safeString(report['photo'])),
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
            ],
          ),
        ),
        if (isMissing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _statusColor(status),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMissingList() {
    final widgets = <Widget>[];
    if (_error != null) {
      widgets.add(_buildErrorBanner(_error!));
      widgets.add(const SizedBox(height: 12));
    }

    if (_missingReports.isEmpty) {
      widgets.add(_buildEmptyState('No missing reports available.'));
    } else {
      widgets.addAll(
        _missingReports.map(
          (report) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildMissingCard(report),
          ),
        ),
      );
    }

    return ListView(
      key: const ValueKey('missing'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: widgets,
    );
  }

  Widget _buildFoundList() {
    final widgets = <Widget>[];
    if (_error != null) {
      widgets.add(_buildErrorBanner(_error!));
      widgets.add(const SizedBox(height: 12));
    }

    if (_foundReports.isEmpty) {
      widgets.add(_buildEmptyState('No found reports available.'));
    } else {
      widgets.addAll(
        _foundReports.map(
          (report) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFoundCard(report),
          ),
        ),
      );
    }

    return ListView(
      key: const ValueKey('found'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: widgets,
    );
  }

  Widget _buildEmptyState(String text) {
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

  Widget _buildMissingCard(Map<String, dynamic> report) {
    final id = _safeString(report['id']);
    final name = _safeString(report['fullName'], 'Unknown');
    final status = _normalizedStatus(report['status']);
    final location = _safeString(
      report['lastSeenLocation'],
      'Unknown location',
    );
    final date = _safeString(report['lastSeenDate']);
    final contactName = _safeString(report['contactName']);
    final contactPhone = _safeString(report['contactPhone']);

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
              _buildAvatar(_safeString(report['photo'])),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _buildStatusPill(status),
            ],
          ),
          const SizedBox(height: 12),
          if (contactName.isNotEmpty || contactPhone.isNotEmpty)
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      contactName,
                      contactPhone,
                    ].where((value) => value.isNotEmpty).join(' • '),
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
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text('Resolved'),
                    ),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: id.isEmpty
                      ? null
                      : (value) {
                          if (value != null) {
                            _updateMissingStatus(id, value);
                          }
                        },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: id.isEmpty ? null : () => _deleteMissingReport(id),
                tooltip: 'Delete report',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFoundCard(Map<String, dynamic> report) {
    final id = _safeString(report['id']);
    final location = _safeString(report['locationFound'], 'Unknown location');
    final gender = _safeString(report['gender'], 'Unknown');
    final age = _formatAge(report['estimatedAge']);
    final coords = _formatCoords(report['foundLat'], report['foundLng']);
    final date = _formatDate(report['createdAt']);

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
              _buildAvatar(_safeString(report['photo'])),
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
                      'Age $age • $gender',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (coords.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        coords,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
                onPressed: id.isEmpty ? null : () => _deleteFoundReport(id),
                tooltip: 'Delete report',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url, {double size = 44}) {
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
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.person_outline, color: Colors.grey.shade500),
              ),
            )
          : Icon(Icons.person_outline, color: Colors.grey.shade500),
    );
  }

  Widget _buildStatusPill(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _statusColor(status),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.green.shade700;
      case 'closed':
        return Colors.grey.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  String _normalizedStatus(dynamic value) {
    final status = _safeString(value, 'pending').toLowerCase();
    if (status == 'resolved' || status == 'closed') {
      return status;
    }
    return 'pending';
  }

  String _safeString(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  String _appendError(String? current, String next) {
    if (current == null || current.isEmpty) return next;
    return '$current\n$next';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _formatAge(dynamic value) {
    if (value == null) return 'N/A';
    if (value is int) return value.toString();
    if (value is double) return value.round().toString();
    if (value is String && value.isNotEmpty) return value;
    return 'N/A';
  }

  String _buildRangeText(dynamic start, dynamic end) {
    final startText = _safeString(start);
    final endText = _safeString(end);
    if (startText.isEmpty && endText.isEmpty) return '';
    if (startText.isNotEmpty && endText.isNotEmpty) {
      return '$startText → $endText';
    }
    return startText.isNotEmpty ? startText : endText;
  }

  String _formatCoords(dynamic lat, dynamic lng) {
    if (lat == null || lng == null) return '';
    final latStr = _safeString(lat);
    final lngStr = _safeString(lng);
    if (latStr.isEmpty || lngStr.isEmpty) return '';
    return 'Coords: $latStr, $lngStr';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map<String, dynamic> && value['_seconds'] != null) {
      final seconds = value['_seconds'];
      if (seconds is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
          isUtc: true,
        ).toLocal();
        final month = date.month.toString().padLeft(2, '0');
        final day = date.day.toString().padLeft(2, '0');
        return '${date.year}-$month-$day';
      }
    }
    return '';
  }
}

class _MonthlyData {
  final String label;
  final String rangeText;
  final int missingCount;
  final int foundCount;
  final int totalCount;
  final List<Map<String, dynamic>> missing;
  final List<Map<String, dynamic>> found;

  const _MonthlyData({
    required this.label,
    required this.rangeText,
    required this.missingCount,
    required this.foundCount,
    required this.totalCount,
    required this.missing,
    required this.found,
  });

  factory _MonthlyData.empty() {
    return const _MonthlyData(
      label: 'Last Month',
      rangeText: '',
      missingCount: 0,
      foundCount: 0,
      totalCount: 0,
      missing: [],
      found: [],
    );
  }
}
