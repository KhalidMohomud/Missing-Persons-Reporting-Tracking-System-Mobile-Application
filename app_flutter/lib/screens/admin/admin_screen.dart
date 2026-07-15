import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../api/api.dart';
import '../../routes/app_routes.dart';
import '../../session/user_session.dart';
import 'admin_models.dart';
import 'admin_theme.dart';
import 'admin_utils.dart';
import 'widgets/admin_dashboard_view.dart';
import 'widgets/admin_nav_bar.dart';
import 'widgets/admin_report_table_view.dart';
import 'widgets/admin_reports_view.dart';
import 'widgets/admin_tips_view.dart';
import 'widgets/admin_user_management_view.dart';

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
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _tips = [];
  Map<String, String> _userLookup = {};
  MonthlyData _monthly = MonthlyData.empty();
  YearlyData _yearly = YearlyData.empty();

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

  List<Map<String, dynamic>> _parseList(dynamic payload) {
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
      return _parseList(decoded);
    }
    if (response.statusCode == 404) {
      return [];
    }
    throw Exception('Failed to load reports (${response.statusCode})');
  }

  Future<List<Map<String, dynamic>>> _getUsers() async {
    final response = await http
        .get(Uri.parse(USERS_URL), headers: _buildHeaders())
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return _parseList(decoded);
    }
    if (response.statusCode == 404) {
      return [];
    }
    throw Exception('Failed to load users (${response.statusCode})');
  }

  Future<List<Map<String, dynamic>>> _getTips() async {
    final response = await http
        .get(Uri.parse(TIPS_URL), headers: _buildHeaders())
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return _parseList(decoded);
    }
    if (response.statusCode == 404) {
      return [];
    }
    throw Exception('Failed to load tips (${response.statusCode})');
  }

  Future<MonthlyData> _getMonthlyReports() async {
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
      return MonthlyData.empty();
    }

    final range = decoded['range'] as Map<String, dynamic>? ?? {};
    final count = decoded['count'] as Map<String, dynamic>? ?? {};
    final data = decoded['data'] as Map<String, dynamic>? ?? {};

    final missingList = _parseList(data['missing']);
    final foundList = _parseList(data['found']);

    return MonthlyData(
      label: AdminUtils.safeString(range['label'], 'This Month'),
      rangeText: AdminUtils.buildRangeText(range['start'], range['end']),
      missingCount: _toInt(count['missing']),
      foundCount: _toInt(count['found']),
      totalCount: _toInt(count['total']),
      missing: missingList,
      found: foundList,
    );
  }

  Future<YearlyData> _getYearlyReports() async {
    final response = await http
        .get(Uri.parse(YEARLY_REPORTS_URL), headers: _buildHeaders())
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('Failed to load yearly reports (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return YearlyData.empty();
    }

    final range = decoded['range'] as Map<String, dynamic>? ?? {};
    final count = decoded['count'] as Map<String, dynamic>? ?? {};
    final data = decoded['data'] as Map<String, dynamic>? ?? {};

    final missingList = _parseList(data['missing']);
    final foundList = _parseList(data['found']);

    return YearlyData(
      label: AdminUtils.safeString(range['label'], 'This Year'),
      rangeText: AdminUtils.buildRangeText(range['start'], range['end']),
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
    var yearly = _yearly;
    var users = _users;
    var tips = _tips;

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

    try {
      yearly = await _getYearlyReports();
    } catch (e) {
      error = _appendError(error, 'Yearly reports: $e');
    }

    try {
      users = await _getUsers();
    } catch (e) {
      error = _appendError(error, 'Users: $e');
    }

    try {
      tips = await _getTips();
    } catch (e) {
      error = _appendError(error, 'Tips: $e');
    }

    if (!mounted) return;
    setState(() {
      _missingReports = missing;
      _foundReports = found;
      _monthly = monthly;
      _yearly = yearly;
      _users = users;
      _tips = tips;
      _userLookup = _buildUserLookup(users);
      _error = error;
      _isLoading = false;
    });
  }

  Future<void> _refreshMissingAndMonthly() async {
    try {
      final missing = await _getReports(MISSING_REPORTS_URL);
      final monthly = await _getMonthlyReports();
      final yearly = await _getYearlyReports();
      if (!mounted) return;
      setState(() {
        _missingReports = missing;
        _monthly = monthly;
        _yearly = yearly;
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
      final yearly = await _getYearlyReports();
      if (!mounted) return;
      setState(() {
        _foundReports = found;
        _monthly = monthly;
        _yearly = yearly;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh found reports: $e')),
      );
    }
  }

  Future<void> _refreshUsers() async {
    try {
      final users = await _getUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _userLookup = _buildUserLookup(users);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to refresh users: $e')));
    }
  }

  Future<void> _refreshTips() async {
    try {
      final tips = await _getTips();
      if (!mounted) return;
      setState(() {
        _tips = tips;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to refresh tips: $e')));
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

  Future<void> _updateUserRole(String id, String role) async {
    try {
      final uri = Uri.parse('$USERS_URL/$id');
      final response = await http.patch(
        uri,
        headers: _buildHeaders(),
        body: jsonEncode({'role': role}),
      );

      if (response.statusCode == 200) {
        await _refreshUsers();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update role (${response.statusCode})'),
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

  Future<void> _deleteUser(String id) async {
    try {
      final uri = Uri.parse('$USERS_URL/$id');
      final response = await http.delete(uri, headers: _buildHeaders());

      if (response.statusCode == 200) {
        await _refreshUsers();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete user (${response.statusCode})'),
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

  String _reporterNameFor(Map<String, dynamic> report) {
    final directName = _reporterNameFromReport(report);
    if (directName.isNotEmpty) return directName;

    final raw = AdminUtils.safeString(report['reportedBy']);
    if (raw.isEmpty) return 'Unknown reporter';

    final lookupName = _userLookup[raw] ?? _userLookup[raw.toLowerCase()];
    if (lookupName != null && lookupName.trim().isNotEmpty) {
      return lookupName;
    }

    return _looksLikeTechnicalUserId(raw) ? 'Unknown reporter' : raw;
  }

  String _reporterNameFromReport(Map<String, dynamic> report) {
    const fields = [
      'reportedByName',
      'reporterName',
      'reporterFullName',
      'reportedByFullName',
    ];
    final owner = AdminUtils.safeString(report['reportedBy']);

    for (final field in fields) {
      final value = AdminUtils.safeString(report[field]);
      if (value.isNotEmpty &&
          value != owner &&
          !_looksLikeTechnicalUserId(value)) {
        return value;
      }
    }

    final reporter = report['reporter'];
    if (reporter is Map) {
      final reporterMap = Map<String, dynamic>.from(reporter);
      for (final field in ['fullName', 'name', 'username', 'email']) {
        final value = AdminUtils.safeString(reporterMap[field]);
        if (value.isNotEmpty && !_looksLikeTechnicalUserId(value)) {
          return value;
        }
      }
    }

    return '';
  }

  bool _looksLikeTechnicalUserId(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    if (RegExp(r'^user_[a-zA-Z0-9]+$').hasMatch(text)) return true;
    return !text.contains('@') && RegExp(r'^[a-zA-Z0-9]{20,}$').hasMatch(text);
  }

  Map<String, String> _buildUserLookup(List<Map<String, dynamic>> users) {
    final lookup = <String, String>{};
    for (final user in users) {
      final id = AdminUtils.safeString(user['id']);
      final userId = AdminUtils.safeString(user['userId']);
      final uid = AdminUtils.safeString(user['uid']);
      final email = AdminUtils.safeString(user['email']);
      final fullName = AdminUtils.safeString(user['fullName']);
      final name = AdminUtils.safeString(user['name']);
      final username = AdminUtils.safeString(user['username']);
      final firstName = AdminUtils.safeString(user['firstName']);
      final lastName = AdminUtils.safeString(user['lastName']);

      var displayName = fullName;
      if (displayName.isEmpty) {
        displayName = name.isNotEmpty ? name : username;
      }
      if (displayName.isEmpty) {
        displayName = [
          firstName,
          lastName,
        ].where((value) => value.isNotEmpty).join(' ');
      }
      if (displayName.isEmpty) {
        displayName = email.isNotEmpty ? email : id;
      }

      void addLookup(String key) {
        final cleanKey = key.trim();
        if (cleanKey.isEmpty) return;
        lookup[cleanKey] = displayName;
        lookup[cleanKey.toLowerCase()] = displayName;
      }

      for (final key in [id, userId, uid, email, fullName, name, username]) {
        addLookup(key);
      }
    }
    return lookup;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.surface,
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
              'Manage missing, found, and users',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AdminTheme.primaryBlue),
            onPressed: _fetchAll,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(
              Icons.notifications_active_outlined,
              color: AdminTheme.primaryBlue,
            ),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.addAlert);
            },
            tooltip: 'Create alert',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed(AppRoutes.addAlert);
        },
        backgroundColor: AdminTheme.primaryBlue,
        icon: const Icon(Icons.campaign_outlined),
        label: const Text(
          'Create Alert',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          AdminNavBar(
            activeTab: _tab,
            onTabChanged: (tab) {
              setState(() {
                _tab = tab;
              });
            },
          ),
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

  Widget _buildContent() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    switch (_tab) {
      case AdminTab.dashboard:
        return AdminDashboardView(
          monthly: _monthly,
          yearly: _yearly,
          error: _error,
          onViewAllMissing: () => setState(() => _tab = AdminTab.missing),
          onViewAllFound: () => setState(() => _tab = AdminTab.found),
          onSendAlert: () {
            Navigator.of(context).pushNamed(AppRoutes.addAlert);
          },
          reporterNameFor: _reporterNameFor,
        );
      case AdminTab.reports:
        return AdminReportTableView(
          missingReports: _missingReports,
          foundReports: _foundReports,
          error: _error,
          reporterNameFor: _reporterNameFor,
        );
      case AdminTab.missing:
        return AdminReportsView(
          isMissing: true,
          reports: _missingReports,
          error: _error,
          reporterNameFor: _reporterNameFor,
          onRefresh: _refreshMissingAndMonthly,
          onDelete: _deleteMissingReport,
        );
      case AdminTab.found:
        return AdminReportsView(
          isMissing: false,
          reports: _foundReports,
          error: _error,
          reporterNameFor: _reporterNameFor,
          onRefresh: null,
          onDelete: _deleteFoundReport,
        );
      case AdminTab.tips:
        return AdminTipsView(
          tips: _tips,
          error: _error,
          onRefresh: _refreshTips,
        );
      case AdminTab.users:
        return AdminUserManagementView(
          users: _users,
          error: _error,
          onRoleChanged: _updateUserRole,
          onDelete: _deleteUser,
        );
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _appendError(String? current, String next) {
    if (current == null || current.isEmpty) return next;
    return '$current\n$next';
  }
}
