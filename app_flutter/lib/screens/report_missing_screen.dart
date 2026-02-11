import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../api/api.dart';
import '../session/user_session.dart';
import '../routes/app_routes.dart';
import '../widgets/login_required_dialog.dart';

class ReportMissingScreen extends StatefulWidget {
  const ReportMissingScreen({super.key});

  @override
  State<ReportMissingScreen> createState() => _ReportMissingScreenState();
}

class _ReportMissingScreenState extends State<ReportMissingScreen> {
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _photoBytes;

  String? _selectedGender;
  DateTime? _selectedDate;
  bool _isSubmitting = false;

  final Color primaryBlue = const Color(0xFF2F89B8);
  final Color surface = const Color(0xFFF7F8FB);

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: ColorScheme.light(primary: primaryBlue)),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
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
      prefixIcon: Icon(icon, color: primaryBlue),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _formatDateForBackend(String dateStr) {
    // Convert from dd/mm/yyyy to yyyy-mm-dd
    final parts = dateStr.split('/');
    if (parts.length == 3) {
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[2];
      return '$year-$month-$day';
    }
    return dateStr; // Return as-is if format is unexpected
  }

  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    // If it doesn't start with +, try to add country code
    // Assuming Somalia country code +252 if not present
    if (digits.isNotEmpty) {
      if (digits.startsWith('252')) {
        return '+$digits';
      } else if (digits.length >= 8) {
        // Assume local number, add +252
        return '+252$digits';
      }
    }

    return phone; // Return original if can't format
  }

  Future<void> _submitReport() async {
    if (!UserSession.isLoggedIn) {
      final shouldLogin = await showLoginRequiredDialog(context);
      if (shouldLogin && mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
      return;
    }
    if (_isSubmitting) return;

    final fullName = _fullNameController.text.trim();
    final ageText = _ageController.text.trim();
    final gender = _selectedGender?.trim();
    final lastSeenLocation = _locationController.text.trim();
    final lastSeenDate = _dateController.text.trim();
    final contactName = _contactNameController.text.trim();
    final contactPhone = _contactPhoneController.text.trim();
    final description = _notesController.text.trim();

    if (fullName.isEmpty ||
        ageText.isEmpty ||
        gender == null ||
        lastSeenLocation.isEmpty ||
        lastSeenDate.isEmpty ||
        contactName.isEmpty ||
        contactPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fadlan buuxi dhammaan xogta muhiimka ah.')),
      );
      return;
    }

    if (_photoBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fadlan soo geli sawir.')));
      return;
    }

    final parsedAge = int.tryParse(ageText);
    if (parsedAge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fadlan geli da\' sax ah.')),
      );
      return;
    }

    // Convert photo to base64 data URL
    final photoBase64 = base64Encode(_photoBytes!);
    final photoDataUrl = 'data:image/jpeg;base64,$photoBase64';

    // Format date for backend (YYYY-MM-DD)
    final formattedDate = _formatDateForBackend(lastSeenDate);

    // Format phone number (E.164 format)
    final formattedPhone = _formatPhoneNumber(contactPhone);

    final reporterId =
        UserSession.current.value?.id ??
        UserSession.current.value?.email ??
        UserSession.current.value?.name ??
        'anonymous';

    final reportPayload = {
      'fullName': fullName,
      'age': parsedAge,
      'gender': gender.toLowerCase(),
      'photo': photoDataUrl,
      'lastSeenLocation': lastSeenLocation,
      'lastSeenDate': formattedDate,
      'contactName': contactName,
      'contactPhone': formattedPhone,
      'description': description,
      'status': 'pending',
      'reportedBy': reporterId,
    };

    setState(() => _isSubmitting = true);

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};

      // Add auth token if available
      final token = UserSession.current.value?.token;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http
          .post(
            Uri.parse(MISSING_REPORTS_URL),
            headers: headers,
            body: jsonEncode(reportPayload),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Warbixinta si guul leh ayaa loo diray.')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          final errorBody = response.body;
          final errorMessage = errorBody.isNotEmpty
              ? 'Gudbintu way fashilantay: ${response.statusCode}'
              : 'Gudbintu way fashilantay. Mar kale isku day.';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Khalad shabakad: ${e.toString()}')),
        );
      }
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
            child: Icon(Icons.arrow_back, color: primaryBlue),
          ),
        ),
        title: const Text(
          'Warbixin Maqan',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF3FF),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: primaryBlue.withOpacity(0.2)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: _showImagePickerSheet,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_photoBytes != null)
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.memory(
                                  _photoBytes!,
                                  fit: BoxFit.cover,
                                ),
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
                                  color: primaryBlue,
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
                                      ? 'Soo geli sawir cad'
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
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Magaca oo buuxa',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _fullNameController,
                decoration: _inputDecoration(
                  hint: 'Geli magaca oo buuxa',
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Da\'da hadda',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration(
                            hint: 'Sano',
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
                          'Jinsiga',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          decoration: _inputDecoration(
                            hint: 'Dooro',
                            icon: Icons.person_outline,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text('Lab'),
                            ),
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text('Dhedig'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Kale'),
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
                'Goobtii ugu dambaysay',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locationController,
                decoration: _inputDecoration(
                  hint: 'Waddo, magaalo, ama astaan',
                  icon: Icons.place_outlined,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Taariikhda maqnaanshaha',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: _inputDecoration(
                  hint: 'dd/mm/yyyy',
                  icon: Icons.calendar_today_outlined,
                  suffixIcon: IconButton(
                    onPressed: _pickDate,
                    icon: Icon(Icons.date_range, color: primaryBlue),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Macluumaadka xiriirka',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contactNameController,
                decoration: _inputDecoration(
                  hint: 'Magacaaga (xiriir)',
                  icon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contactPhoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  hint: 'Lambarka taleefankaaga',
                  icon: Icons.phone_outlined,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Faahfaahin dheeraad ah',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: _inputDecoration(
                  hint: 'Dhar, waqtigii ugu dambaysay la arkay, iwm.',
                  icon: Icons.notes_outlined,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Gudbi warbixin rasmi ah',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Markaad gudbiso, waxaad xaqiijinaysaa in xogtu sax tahay intaad ogtahay.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
