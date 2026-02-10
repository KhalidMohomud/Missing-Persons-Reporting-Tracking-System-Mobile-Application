import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../api/api.dart';
import '../../../session/user_session.dart';
import '../report_details_theme.dart';
import '../report_details_utils.dart';

class ReportTipsSection extends StatefulWidget {
  final String reportId;
  final bool isMissing;
  final String reportOwnerId;

  const ReportTipsSection({
    super.key,
    required this.reportId,
    required this.isMissing,
    required this.reportOwnerId,
  });

  @override
  State<ReportTipsSection> createState() => _ReportTipsSectionState();
}

class _ReportTipsSectionState extends State<ReportTipsSection> {
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _tips = [];
  String? _lastUserId;

  bool _canView(UserInfo? user) {
    if (user == null) return false;
    if (user.role.toLowerCase() == 'admin') return true;
    final ownerId = widget.reportOwnerId.trim();
    if (ownerId.isEmpty) return false;
    if (ownerId == (user.id ?? '')) return true;
    return ownerId.toLowerCase() == user.email.toLowerCase();
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

  Future<void> _fetchTips() async {
    final user = UserSession.current.value;
    if (!_canView(user)) return;
    if (widget.reportId.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        '$TIPS_URL?reportId=${widget.reportId}&reportType=${widget.isMissing ? 'missing' : 'found'}',
      );
      final response = await http
          .get(uri, headers: _buildHeaders())
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
        setState(() {
          _tips = list;
        });
      } else if (response.statusCode == 403) {
        setState(() {
          _error = 'Tips are available to the report owner or admins only.';
        });
      } else {
        setState(() {
          _error = 'Failed to load tips (${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserInfo?>(
      valueListenable: UserSession.current,
      builder: (context, user, _) {
        final canView = _canView(user);
        final userId = user?.id ?? '';

        if (canView && userId != _lastUserId) {
          _lastUserId = userId;
          WidgetsBinding.instance.addPostFrameCallback((_) => _fetchTips());
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Information Tips',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: canView ? _fetchTips : null,
                    icon: const Icon(Icons.refresh, size: 18),
                    color: ReportDetailsTheme.primaryBlue,
                    tooltip: 'Refresh tips',
                  ),
                ],
              ),
              if (!canView)
                _LockedCard(isLoggedIn: user != null)
              else if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorCard(message: _error!)
              else if (_tips.isEmpty)
                const _EmptyCard()
              else
                Column(
                  children: _tips.map((tip) => _TipCard(tip: tip)).toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TipCard extends StatelessWidget {
  final Map<String, dynamic> tip;

  const _TipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    final message = ReportDetailsUtils.safeString(tip['message']);
    final location = ReportDetailsUtils.safeString(tip['location']);
    final createdAt = ReportDetailsUtils.formatDate(tip['createdAt']);
    final anonymous = tip['anonymous'] == true;
    final tipLat = tip['tipLat'];
    final tipLng = tip['tipLng'];
    final hasCoords = tipLat != null && tipLng != null;
    final hasAlert = ReportDetailsUtils.safeString(tip['alertId']).isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
                  color: anonymous
                      ? Colors.grey.shade200
                      : ReportDetailsTheme.lightGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  anonymous ? 'Anonymous' : 'Identified',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: anonymous ? Colors.grey.shade700 : Colors.brown,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (hasAlert)
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
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade600,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                createdAt.isNotEmpty ? createdAt : 'Just now',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.isNotEmpty ? message : 'No details provided.',
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
                Icon(Icons.location_on,
                    size: 16, color: ReportDetailsTheme.primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    location,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ],
          if (hasCoords) ...[
            const SizedBox(height: 6),
            Text(
              'Pinned location: ${tipLat.toString()}, ${tipLng.toString()}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No tips submitted yet.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedCard extends StatelessWidget {
  final bool isLoggedIn;

  const _LockedCard({required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isLoggedIn
                  ? 'Tips are visible to the report owner and admins only.'
                  : 'Log in to view report tips.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
          const SizedBox(width: 10),
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
