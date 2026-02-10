// import 'package:flutter/material.dart';

// class ReportFoundScreen extends StatefulWidget {
//   const ReportFoundScreen({super.key});

//   @override
//   State<ReportFoundScreen> createState() => _ReportFoundScreenState();
// }

// class _ReportFoundScreenState extends State<ReportFoundScreen> {
//   final _ageController = TextEditingController();
//   final _locationController = TextEditingController();
//   final _conditionController = TextEditingController();

//   String? _selectedGender;

//   final Color accentGold = const Color(0xFFCE9E4F);
//   final Color surface = const Color(0xFFF7F8FB);

//   @override
//   void dispose() {
//     _ageController.dispose();
//     _locationController.dispose();
//     _conditionController.dispose();
//     super.dispose();
//   }

//   InputDecoration _inputDecoration({
//     required String hint,
//     required IconData icon,
//     Widget? suffixIcon,
//   }) {
//     return InputDecoration(
//       hintText: hint,
//       filled: true,
//       fillColor: Colors.white,
//       contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
//       prefixIcon: Icon(icon, color: accentGold),
//       suffixIcon: suffixIcon,
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(16),
//         borderSide: BorderSide.none,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: surface,
//       appBar: AppBar(
//         backgroundColor: surface,
//         elevation: 0,
//         centerTitle: true,
//         leading: IconButton(
//           onPressed: () => Navigator.of(context).pop(),
//           icon: Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.08),
//                   blurRadius: 10,
//                   offset: const Offset(0, 4),
//                 ),
//               ],
//             ),
//             padding: const EdgeInsets.all(8),
//             child: Icon(Icons.arrow_back, color: accentGold),
//           ),
//         ),
//         title: const Text(
//           'Found Someone',
//           style: TextStyle(fontWeight: FontWeight.w700),
//         ),
//       ),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(18),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFF5F1E8),
//                   borderRadius: BorderRadius.circular(22),
//                   border: Border.all(color: accentGold.withOpacity(0.25)),
//                 ),
//                 child: Column(
//                   children: [
//                     Container(
//                       width: 64,
//                       height: 64,
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         shape: BoxShape.circle,
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.08),
//                             blurRadius: 10,
//                             offset: const Offset(0, 4),
//                           ),
//                         ],
//                       ),
//                       child:
//                           Icon(Icons.upload, color: accentGold, size: 30),
//                     ),
//                     const SizedBox(height: 12),
//                     Text(
//                       'Upload Current Photo',
//                       style: TextStyle(
//                         color: Colors.grey.shade800,
//                         fontWeight: FontWeight.w600,
//                         letterSpacing: 0.3,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Row(
//                 children: [
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Estimated Age',
//                           style: TextStyle(fontWeight: FontWeight.w600),
//                         ),
//                         const SizedBox(height: 8),
//                         TextField(
//                           controller: _ageController,
//                           keyboardType: TextInputType.number,
//                           decoration: _inputDecoration(
//                             hint: 'Years',
//                             icon: Icons.cake_outlined,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Gender',
//                           style: TextStyle(fontWeight: FontWeight.w600),
//                         ),
//                         const SizedBox(height: 8),
//                         DropdownButtonFormField<String>(
//                           value: _selectedGender,
//                           decoration: _inputDecoration(
//                             hint: 'Select',
//                             icon: Icons.person_outline,
//                           ),
//                           items: const [
//                             DropdownMenuItem(
//                               value: 'Male',
//                               child: Text('Male'),
//                             ),
//                             DropdownMenuItem(
//                               value: 'Female',
//                               child: Text('Female'),
//                             ),
//                             DropdownMenuItem(
//                               value: 'Other',
//                               child: Text('Other'),
//                             ),
//                           ],
//                           onChanged: (value) {
//                             setState(() => _selectedGender = value);
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               const Text(
//                 'Location Found',
//                 style: TextStyle(fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 8),
//               TextField(
//                 controller: _locationController,
//                 decoration: _inputDecoration(
//                   hint: 'Street, city, or landmark',
//                   icon: Icons.place_outlined,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               const Text(
//                 'Physical Condition',
//                 style: TextStyle(fontWeight: FontWeight.w600),
//               ),
//               const SizedBox(height: 8),
//               TextField(
//                 controller: _conditionController,
//                 maxLines: 3,
//                 decoration: _inputDecoration(
//                   hint: 'Describe their status (injured, confused, safe?)',
//                   icon: Icons.health_and_safety_outlined,
//                 ),
//               ),
//               const SizedBox(height: 24),
//               ElevatedButton(
//                 onPressed: () {},
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: accentGold,
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(18),
//                   ),
//                   elevation: 2,
//                 ),
//                 child: const Text(
//                   'Submit Found',
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../api/api.dart';
import '../session/user_session.dart';

class ReportFoundScreen extends StatefulWidget {
  const ReportFoundScreen({super.key});

  @override
  State<ReportFoundScreen> createState() => _ReportFoundScreenState();
}

class _ReportFoundScreenState extends State<ReportFoundScreen> {
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _conditionController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  String? _selectedGender;

  final Color accentGold = const Color(0xFFCE9E4F);
  final Color surface = const Color(0xFFF7F8FB);

  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _photoBytes;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _ageController.dispose();
    _locationController.dispose();
    _conditionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _photoBytes = bytes);
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      prefixIcon: Icon(icon, color: accentGold),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _submitFoundReport() async {
    if (_isSubmitting) return;

    final ageText = _ageController.text.trim();
    final locationFound = _locationController.text.trim();
    final description = _conditionController.text.trim();
    final gender = _selectedGender?.trim();
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();

    if (ageText.isEmpty ||
        locationFound.isEmpty ||
        gender == null ||
        latText.isEmpty ||
        lngText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    if (_photoBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please upload a photo.')));
      return;
    }

    final parsedAge = int.tryParse(ageText);
    final parsedLat = double.tryParse(latText);
    final parsedLng = double.tryParse(lngText);

    if (parsedAge == null || parsedAge <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid age.')),
      );
      return;
    }

    if (parsedLat == null || parsedLat < -90 || parsedLat > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid latitude.')),
      );
      return;
    }

    if (parsedLng == null || parsedLng < -180 || parsedLng > 180) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid longitude.')),
      );
      return;
    }

    final photoBase64 = base64Encode(_photoBytes!);
    final photoDataUrl = 'data:image/jpeg;base64,$photoBase64';

    final reporterId =
        UserSession.current.value?.email ??
        UserSession.current.value?.name ??
        'anonymous';

    final payload = {
      'description': description,
      'estimatedAge': parsedAge,
      'foundLat': parsedLat,
      'foundLng': parsedLng,
      'gender': gender.toLowerCase(),
      'locationFound': locationFound,
      'photo': photoDataUrl,
      'reportedBy': reporterId,
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
          const SnackBar(content: Text('Found report submitted successfully')),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: ${response.statusCode}')),
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
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.arrow_back, color: accentGold),
          ),
        ),
        title: const Text(
          'Found Someone',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Upload card
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F1E8),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: accentGold.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(Icons.upload, color: accentGold, size: 30),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _photoBytes == null
                            ? 'Upload Current Photo'
                            : 'Photo selected',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Existing UI (age + gender)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimated Age',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            hint: 'Years',
                            icon: Icons.cake_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gender',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: _inputDecoration(
                            hint: 'Select',
                            icon: Icons.person_outline,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text('Female'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedGender = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Location Found',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locationController,
                decoration: _inputDecoration(
                  hint: 'Street, city, or landmark',
                  icon: Icons.place_outlined,
                ),
              ),
              const SizedBox(height: 16),

              // Lat / Lng inputs (backend requires them)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Latitude',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _latController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: _inputDecoration(
                            hint: 'e.g. 2.0469',
                            icon: Icons.explore_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Longitude',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lngController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: _inputDecoration(
                            hint: 'e.g. 45.3182',
                            icon: Icons.explore,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'Physical Condition',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _conditionController,
                maxLines: 3,
                decoration: _inputDecoration(
                  hint: 'Describe their status (injured, confused, safe?)',
                  icon: Icons.health_and_safety_outlined,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFoundReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentGold,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
