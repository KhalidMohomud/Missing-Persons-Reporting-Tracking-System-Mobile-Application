// import 'package:flutter/material.dart';
// import 'filter_button.dart';
// import 'report_card.dart';

// class LiveReportsSection extends StatelessWidget {
//   final String selectedFilter;
//   final Function(String) onFilterChanged;

//   const LiveReportsSection({
//     super.key,
//     required this.selectedFilter,
//     required this.onFilterChanged,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         /// Section Header
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             const Text(
//               'Live Reports',
//               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//             ),
//             Row(
//               children: [
//                 FilterButton(
//                   label: 'MISSING',
//                   isActive: selectedFilter == 'MISSING',
//                   onTap: () => onFilterChanged('MISSING'),
//                 ),
//                 const SizedBox(width: 8),
//                 FilterButton(
//                   label: 'FOUND',
//                   isActive: selectedFilter == 'FOUND',
//                   onTap: () => onFilterChanged('FOUND'),
//                 ),
//               ],
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),

//         /// Report Cards
//         ReportCard(
//           name: 'Amina Abdi',
//           age: 21,
//           gender: 'female',
//           location: 'Mogodisho, hdn',
//           date: 'Mar 12, 2026',
//           imagePath: 'assets/aamina.png',
//         ),
//         const SizedBox(height: 12),
//         ReportCard(
//           name: 'abdi hasan',
//           age: 22,
//           gender: 'Male',
//           location: 'Xudur, sooqa ,xoolaha',
//           date: 'Feb 11, 2026',
//           imagePath: 'assets/abdi.png',
//         ),
//         const SizedBox(height: 12),
//         ReportCard(
//           name: 'ahmed moho',
//           age: 13,
//           gender: 'Male',
//           location: 'Guriceel, MO',
//           date: 'Oct 12, 2025',
//           imagePath: 'assets/ahmed.png',
//         ),
//         const SizedBox(height: 20),
//       ],
//     );
//   }
// }
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api.dart';
import 'filter_button.dart';
import 'report_card.dart';

class LiveReportsSection extends StatefulWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;
  final String searchQuery;

  const LiveReportsSection({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
    this.searchQuery = '',
  });

  @override
  State<LiveReportsSection> createState() => _LiveReportsSectionState();
}

class _LiveReportsSectionState extends State<LiveReportsSection> {
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _missing = [];
  List<Map<String, dynamic>> _found = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final missingRes = await http
          .get(Uri.parse(MISSING_REPORTS_URL))
          .timeout(const Duration(seconds: 12));
      final foundRes = await http
          .get(Uri.parse(FOUND_REPORTS_URL))
          .timeout(const Duration(seconds: 12));

      if (missingRes.statusCode != 200 && missingRes.statusCode != 404) {
        throw Exception('Missing reports ${missingRes.statusCode}');
      }
      if (foundRes.statusCode != 200 && foundRes.statusCode != 404) {
        throw Exception('Found reports ${foundRes.statusCode}');
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

      setState(() {
        _missing = parseList(missingRes);
        _found = parseList(foundRes);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load reports: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFilter = widget.selectedFilter;
    List<Map<String, dynamic>> list = selectedFilter == 'FOUND'
        ? _found
        : _missing;

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
        // Header + filter buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Live Reports',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                FilterButton(
                  label: 'MISSING',
                  isActive: selectedFilter == 'MISSING',
                  onTap: () => widget.onFilterChanged('MISSING'),
                ),
                const SizedBox(width: 8),
                FilterButton(
                  label: 'FOUND',
                  isActive: selectedFilter == 'FOUND',
                  onTap: () => widget.onFilterChanged('FOUND'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          )
        else if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text('No reports yet.'),
          )
        else
          Column(
            children: list.map((report) {
              final name =
                  (report['fullName'] ?? report['description'] ?? 'Unknown')
                      .toString();
              final age =
                  int.tryParse(
                    (report['age'] ?? report['estimatedAge'] ?? '0').toString(),
                  ) ??
                  0;
              final gender = (report['gender'] ?? 'Unknown').toString();
              final location =
                  (report['lastSeenLocation'] ?? report['locationFound'] ?? '')
                      .toString();
              final date = (report['lastSeenDate'] ?? '').toString();
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
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
