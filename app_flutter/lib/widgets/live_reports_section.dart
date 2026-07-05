import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api.dart';
import '../screens/report_details/report_details_screen.dart';
import '../screens/report_details/report_details_utils.dart';
import 'report_card.dart';

class LiveReportsSection extends StatefulWidget {
  final String searchQuery;
  final int refreshSignal;

  const LiveReportsSection({
    super.key,
    this.searchQuery = '',
    this.refreshSignal = 0,
  });

  @override
  State<LiveReportsSection> createState() => _LiveReportsSectionState();
}

class _LiveReportsSectionState extends State<LiveReportsSection> {
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _missing = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchReports();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchReports(showLoading: false),
    );
  }

  @override
  void didUpdateWidget(covariant LiveReportsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) {
      _fetchReports();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchReports({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final missingRes = await http
          .get(Uri.parse(MISSING_REPORTS_URL))
          .timeout(const Duration(seconds: 12));

      if (missingRes.statusCode != 200 && missingRes.statusCode != 404) {
        throw Exception('Missing reports ${missingRes.statusCode}');
      }

      List<Map<String, dynamic>> parseList(http.Response res) {
        if (res.statusCode == 404) return [];
        final decoded = jsonDecode(res.body);
        final data = decoded is Map<String, dynamic>
            ? decoded['data']
            : decoded;
        return (data as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];
      }

      if (!mounted) return;
      setState(() {
        _missing = parseList(missingRes);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load reports: $e';
      });
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> list = _missing;

    // Local search by name or city/location
    final query = widget.searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((report) {
        final name = (report['fullName'] ?? report['description'] ?? '')
            .toString()
            .toLowerCase();
        final location =
            (report['lastSeenLocation'] ?? report['locationFound'] ?? '')
                .toString()
                .toLowerCase();
        return name.contains(query) || location.contains(query);
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Reports',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Scrollable list only
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchReports,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _buildItemCount(list),
              itemBuilder: (context, index) {
                if (_isLoading) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (_error != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text('No reports yet.'),
                  );
                }

                final report = list[index];
                final name =
                    (report['fullName'] ?? report['description'] ?? 'Unknown')
                        .toString();
                final age = ReportDetailsUtils.formatAge(
                  report['age'] ?? report['estimatedAge'],
                );
                final gender = (report['gender'] ?? 'Unknown').toString();
                final location =
                    (report['lastSeenLocation'] ??
                            report['locationFound'] ??
                            '')
                        .toString();
                final date = ReportDetailsUtils.formatDate(
                  report['lastSeenDate'] ?? report['createdAt'],
                );
                final imagePath = (report['photo'] ?? '')
                    .toString(); // Cloudinary URL

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ReportCard(
                    name: name,
                    age: age,
                    gender: gender,
                    location: location,
                    date: date,
                    imagePath: imagePath.isEmpty
                        ? 'assets/aamina.png'
                        : imagePath,
                    onTap: () {
                      final details = ReportDetailsScreen.fromReport(
                        report: report,
                        isMissing: true,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReportDetailsScreen(data: details),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  int _buildItemCount(List<Map<String, dynamic>> list) {
    if (_isLoading || _error != null || list.isEmpty) return 1;
    return list.length;
  }
}
