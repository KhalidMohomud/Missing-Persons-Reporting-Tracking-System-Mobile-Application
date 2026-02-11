import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../api/api.dart';
import '../routes/app_routes.dart';
import '../session/user_session.dart';
import '../widgets/login_required_dialog.dart';
import '../widgets/map_picker_widget.dart';

class AddTipScreen extends StatefulWidget {
  final String reportId;
  final String targetName;
  final String imageUrl;
  final bool isMissing;

  const AddTipScreen({
    super.key,
    required this.reportId,
    required this.targetName,
    required this.imageUrl,
    required this.isMissing,
  });

  @override
  State<AddTipScreen> createState() => _AddTipScreenState();
}

class _AddTipScreenState extends State<AddTipScreen> {
  final _messageController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isSubmitting = false;
  bool _anonymous = true;
  bool _includeMap = false;
  LatLng? _selectedLocation;
  bool _hasPickedLocation = false;

  final Color primaryBlue = const Color(0xFF2F89B8);
  final Color accentGold = const Color(0xFFD6A653);

  @override
  void dispose() {
    _messageController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submitTip() async {
    if (_isSubmitting) return;

    if (widget.reportId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aqoonsiga warbixinta wuu maqan yahay.')),
      );
      return;
    }

    if (!_anonymous && !UserSession.isLoggedIn) {
      final shouldLogin = await showLoginRequiredDialog(context);
      if (shouldLogin && mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
      return;
    }

    final message = _messageController.text.trim();
    final location = _locationController.text.trim();

    if (message.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fadlan buuxi dhammaan xogta.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
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

      final payload = <String, dynamic>{
        'reportId': widget.reportId,
        'reportType': widget.isMissing ? 'missing' : 'found',
        'message': message,
        'location': location,
        'anonymous': _anonymous,
      };

      if (_includeMap && _hasPickedLocation && _selectedLocation != null) {
        payload['tipLat'] = _selectedLocation!.latitude;
        payload['tipLng'] = _selectedLocation!.longitude;
      }

      final response = await http
          .post(
            Uri.parse(TIPS_URL),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Talo waa la diray.')),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Khalad: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Khalad shabakad: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: primaryBlue),
        title: const Text('Gudbi Talo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TargetCard(name: widget.targetName, imageUrl: widget.imageUrl),
            const SizedBox(height: 20),
            const Text(
              'Faahfaahinta Aragtida',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Halkee ayaad ku aragtay? Sidee u labisnaa?',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Goobtaada Hadda',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Magaalo, degmo, ama astaan',
                filled: true,
                fillColor: Colors.grey.shade100,
                prefixIcon: Icon(Icons.location_on, color: primaryBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _anonymous,
              onChanged: (value) {
                setState(() => _anonymous = value);
              },
              title: const Text('Talo qarsoodi ah'),
            ),
            SwitchListTile(
              value: _includeMap,
              onChanged: (value) {
                setState(() => _includeMap = value);
              },
              title: const Text('Ku dar goobta khariidada (ikhtiyaari)'),
            ),
            if (_includeMap) ...[
              const SizedBox(height: 8),
              MapPickerWidget(
                onLocationPicked: (latLng) {
                  setState(() {
                    _selectedLocation = latLng;
                    _hasPickedLocation = true;
                  });
                },
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitTip,
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: Text(
                  _isSubmitting ? 'Gudbinayaa...' : 'Gudbi Talo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
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

class _TargetCard extends StatelessWidget {
  final String name;
  final String imageUrl;

  const _TargetCard({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty && imageUrl.startsWith('http');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: hasImage
                ? Image.network(
                    imageUrl,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackAvatar(),
                  )
                : _fallbackAvatar(),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qofka la raadinayo',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                name.isNotEmpty ? name : 'Lama yaqaan',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.person, color: Colors.grey.shade500),
    );
  }
}
