import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../api/api.dart';
import '../routes/app_routes.dart';
import '../session/user_session.dart';
import '../widgets/login_required_dialog.dart';
import '../widgets/map_picker_widget.dart';

class AddAlertScreen extends StatefulWidget {
  const AddAlertScreen({super.key});

  @override
  State<AddAlertScreen> createState() => _AddAlertScreenState();
}

class _AddAlertScreenState extends State<AddAlertScreen> {
  final _messageController = TextEditingController();

  String _reportType = 'missing';
  String? _selectedReportId;
  bool _loadingReports = false;
  String? _reportError;
  List<Map<String, dynamic>> _missingReports = [];
  List<Map<String, dynamic>> _foundReports = [];

  LatLng? _selectedLocation;
  bool _hasPickedLocation = false;
  double _radiusKm = 5;

  bool _isSubmitting = false;

  final Color primaryBlue = const Color(0xFF2F89B8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!UserSession.isLoggedIn) {
        showLoginRequiredDialog(context).then((shouldLogin) {
          if (!mounted) return;
          if (shouldLogin) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
          } else {
            Navigator.of(context).pop();
          }
        });
        return;
      }

      final role = UserSession.current.value?.role.toLowerCase() ?? 'public';
      if (role != 'admin') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Admin kaliya.')));
        Navigator.of(context).pop();
      }
    });

    _fetchReports();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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

  Future<void> _fetchReports() async {
    setState(() {
      _loadingReports = true;
      _reportError = null;
    });
    try {
      final results = await Future.wait([
        _getReports(MISSING_REPORTS_URL),
        _getReports(FOUND_REPORTS_URL),
      ]);
      if (!mounted) return;
      setState(() {
        _missingReports = results[0];
        _foundReports = results[1];
        _selectedReportId = _firstReportIdForType(_reportType);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reportError = 'Kuma guulaysan in la soo dejiyo warbixinada: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingReports = false);
      }
    }
  }

  String? _firstReportIdForType(String type) {
    final list = type == 'found' ? _foundReports : _missingReports;
    if (list.isEmpty) return null;
    return _safeString(list.first['id']);
  }

  String _safeString(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  String _labelForReport(Map<String, dynamic> report, bool isMissing) {
    if (isMissing) {
      final name = _safeString(report['fullName'], 'Unknown');
      final location = _safeString(report['lastSeenLocation']);
      final date = _safeString(report['lastSeenDate']);
      final parts = [name, location, date].where((v) => v.isNotEmpty).toList();
      return parts.isEmpty ? 'Warbixin Maqan' : parts.join(' • ');
    }
    final location = _safeString(report['locationFound'], 'Warbixin La Helay');
    final gender = _safeString(report['gender']);
    final age = _safeString(report['estimatedAge']);
    final parts = [location];
    if (age.isNotEmpty) parts.add('Age $age');
    if (gender.isNotEmpty) parts.add(gender);
    return parts.join(' • ');
  }

  Future<void> _submitAlert() async {
    if (_isSubmitting) return;

    final reportId = _selectedReportId?.trim() ?? '';
    final message = _messageController.text.trim();

    if (reportId.isEmpty || message.isEmpty || !_hasPickedLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fadlan buuxi dhammaan xogta.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final headers = _buildHeaders();

      final payload = {
        'reportId': reportId,
        'reportType': _reportType,
        'alertMessage': message,
        'alertLat': _selectedLocation!.latitude,
        'alertLng': _selectedLocation!.longitude,
        'radiusKm': _radiusKm,
        'audience': 'public',
        'source': 'manual',
      };

      final response = await http
          .post(
            Uri.parse(ALERTS_URL),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
        final dataMap = data is Map ? Map<String, dynamic>.from(data) : null;
        final pushDelivery = dataMap?['pushDelivery'];
        final pushMap = pushDelivery is Map
            ? Map<String, dynamic>.from(pushDelivery)
            : null;
        final successCount = _toInt(pushMap?['successCount']);
        final targetCount = _toInt(pushMap?['targetCount']);
        final deliveryText = targetCount > 0
            ? ' Push: $successCount/$targetCount devices.'
            : ' Push: no registered devices yet.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Digniinta waa la diray.$deliveryText')),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Khalad: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Khalad shabakad: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: primaryBlue),
        title: const Text('Samee Digniin'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nooca Warbixinta',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _reportType,
              items: const [
                DropdownMenuItem(
                  value: 'missing',
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Warbixin Maqan',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'found',
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Warbixin La Helay',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _reportType = value;
                  _selectedReportId = _firstReportIdForType(value);
                });
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Dooro Warbixin',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_loadingReports)
              const Center(child: CircularProgressIndicator())
            else if (_reportError != null)
              Text(
                _reportError!,
                style: TextStyle(color: Colors.red.shade400, fontSize: 12),
              )
            else
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedReportId,
                items:
                    (_reportType == 'found' ? _foundReports : _missingReports)
                        .map(
                          (report) => DropdownMenuItem(
                            value: _safeString(report['id']),
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                _labelForReport(
                                  report,
                                  _reportType == 'missing',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  setState(() => _selectedReportId = value);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Fariinta Digniinta',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Digniin: qof maqan oo Bakara ku dhow!',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Dooro Goobta Digniinta',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            MapPickerWidget(
              onLocationPicked: (latLng) {
                setState(() {
                  _selectedLocation = latLng;
                  _hasPickedLocation = true;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Raadiyaha (km): ${_radiusKm.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _radiusKm,
              min: 1,
              max: 20,
              divisions: 19,
              label: '${_radiusKm.toStringAsFixed(0)} km',
              onChanged: (value) {
                setState(() => _radiusKm = value);
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAlert,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Dir Digniin',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
