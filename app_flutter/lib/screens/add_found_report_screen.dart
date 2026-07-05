import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../api/api.dart';
import '../routes/app_routes.dart';
import '../session/user_session.dart';
import '../widgets/login_required_dialog.dart';
import '../widgets/map_picker_widget.dart';

class AddFoundReportScreen extends StatefulWidget {
  const AddFoundReportScreen({super.key});

  @override
  State<AddFoundReportScreen> createState() => _AddFoundReportScreenState();
}

class _AddFoundReportScreenState extends State<AddFoundReportScreen> {
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedGender;
  LatLng? _selectedLocation;

  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _photoBytes;

  bool _isSubmitting = false;

  final Color accentGold = const Color(0xFFD6A653);
  final Color surface = const Color(0xFFF7F8FB);

  @override
  void dispose() {
    _ageController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
    });
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Kaamirada'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Sawirada'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitFoundReport() async {
    if (!UserSession.isLoggedIn) {
      final shouldLogin = await showLoginRequiredDialog(context);
      if (shouldLogin && mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
      return;
    }
    if (_isSubmitting) return;

    final ageText = _ageController.text.trim();
    final locationFound = _locationController.text.trim();
    final description = _descriptionController.text.trim();
    final gender = _selectedGender?.trim();

    if (ageText.isEmpty ||
        locationFound.isEmpty ||
        gender == null ||
        _selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fadlan buuxi dhammaan xogta.')),
      );
      return;
    }

    if (_photoBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fadlan sawir soo geli.')));
      return;
    }

    final parsedAge = int.tryParse(ageText);
    if (parsedAge == null || parsedAge <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Da\'da ma saxna.')));
      return;
    }

    final photoBase64 = base64Encode(_photoBytes!);
    final photoDataUrl = 'data:image/jpeg;base64,$photoBase64';

    final currentUser = UserSession.current.value;
    final reporterId =
        currentUser?.id ??
        currentUser?.email ??
        currentUser?.name ??
        'anonymous';
    final reporterName = currentUser?.name.trim() ?? '';
    final reporterEmail = currentUser?.email.trim() ?? '';

    final payload = {
      'estimatedAge': parsedAge,
      'gender': gender.toLowerCase(),
      'locationFound': locationFound,
      'foundLat': _selectedLocation!.latitude,
      'foundLng': _selectedLocation!.longitude,
      'description': description,
      'photo': photoDataUrl,
      'reportedBy': reporterId,
      if (reporterName.isNotEmpty) 'reportedByName': reporterName,
      if (reporterEmail.isNotEmpty) 'reportedByEmail': reporterEmail,
    };

    setState(() => _isSubmitting = true);

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      final token = UserSession.current.value?.token;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(FOUND_REPORTS_URL),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warbixinta waa la diray.')),
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
      ).showSnackBar(SnackBar(content: Text('Network error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
        ),
        title: const Text(
          'Helay Qof',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _showImagePickerSheet,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F1E8),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: accentGold.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_photoBytes != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.memory(
                                _photoBytes!,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(
                                    _photoBytes == null ? 1 : 0.85,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _photoBytes == null
                                      ? Icons.upload
                                      : Icons.edit_outlined,
                                  color: accentGold,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(
                                    _photoBytes == null ? 1 : 0.85,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _photoBytes == null
                                      ? 'Soo geli sawir'
                                      : 'Taabo si aad u beddesho',
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _LabeledField(
                      label: 'Da\'da la qiyaasay',
                      child: TextField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          hint: 'Sano',
                          icon: Icons.cake_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LabeledField(
                      label: 'Jinsiga',
                      child: DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: _inputDecoration(
                          hint: 'Dooro',
                          icon: Icons.person_outline,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Dhedig'),
                          ),
                          DropdownMenuItem(value: 'Male', child: Text('Lab')),
                          DropdownMenuItem(value: 'Other', child: Text('Kale')),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedGender = value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: 'Goobta Laga Helay',
                child: TextField(
                  controller: _locationController,
                  decoration: _inputDecoration(
                    hint: 'Degmada, magaalada, ama astaanta',
                    icon: Icons.place_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: 'Sharaxaad',
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: _inputDecoration(
                    hint: 'Faahfaahin ku saabsan xaaladda',
                    icon: Icons.notes_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Xulo Goobta Khariidada',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              MapPickerWidget(
                onLocationPicked: (latLng) {
                  setState(() {
                    _selectedLocation = latLng;
                  });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitFoundReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGold,
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
                          'Gudbi Warbixin',
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
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      prefixIcon: Icon(icon, color: accentGold),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}
