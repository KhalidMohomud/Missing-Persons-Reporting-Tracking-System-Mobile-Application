import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../api/api.dart';
import '../routes/app_routes.dart';
import '../session/user_session.dart';
import '../services/push_notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _isLoading = false;
  bool _isSocialLoading = false;
  String? _socialProviderLoading;
  String? _errorMessage;
  bool _showPassword = false;

  final Color primaryBlue = const Color(0xFF2F89B8);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(LOGIN_URL),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          data = null;
        }
        final tokenFromHeaders = _extractTokenFromHeaders(response.headers);
        final tokenFromBody = _extractTokenFromBody(response.body, data);
        print(response.body);
        print(data);
        UserSession.updateFromLoginResponse(
          emailInput: _emailController.text.trim(),
          data: data,
          tokenOverride: tokenFromHeaders ?? tokenFromBody,
        );
        await PushNotificationService.instance.syncForLoggedInUser();
        // Handle successful login
        if (mounted) {
          // Show success alert and navigate after dismissal
          await _showSuccessAlert(context);
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid email or password';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
        print("error test checking: $e");
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSocialLogin(String provider) async {
    if (_isLoading || _isSocialLoading) return;

    setState(() {
      _isSocialLoading = true;
      _socialProviderLoading = provider;
      _errorMessage = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(socialLOGIN_URL),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'provider': provider,
              if (_emailController.text.trim().isNotEmpty)
                'email': _emailController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          data = null;
        }
        final tokenFromHeaders = _extractTokenFromHeaders(response.headers);
        final tokenFromBody = _extractTokenFromBody(response.body, data);
        UserSession.updateFromLoginResponse(
          emailInput: _emailController.text.trim(),
          data: data,
          tokenOverride: tokenFromHeaders ?? tokenFromBody,
        );
        await PushNotificationService.instance.syncForLoggedInUser();
        if (mounted) {
          await _showSuccessAlert(context);
        }
      } else {
        setState(() {
          _errorMessage = 'Social login failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
          _socialProviderLoading = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool googleLoading = _socialProviderLoading == 'google';
    final bool facebookLoading = _socialProviderLoading == 'facebook';
    final Color surface = const Color(0xFFF6F8FB);
    final Color deepBlue = const Color(0xFF1D5C7A);
    final Color softBlue = const Color(0xFF3F8FB7);

    final titleStyle = GoogleFonts.manrope(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      color: Colors.black87,
    );
    final subtitleStyle = GoogleFonts.manrope(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Colors.blueGrey.shade500,
    );
    final labelStyle = GoogleFonts.manrope(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Colors.blueGrey.shade700,
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: surface,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: softBlue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Image.asset(
                            'assets/iconsapp.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person, size: 56),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('Welcome Back', style: titleStyle),
                        const SizedBox(height: 4),
                        Text('Sign in to continue', style: subtitleStyle),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Email', style: labelStyle),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(
                              'example@gmail.com',
                              icon: Icons.email_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Email is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          Text('Password', style: labelStyle),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_showPassword,
                            decoration:
                                _inputDecoration(
                                  '••••••••',
                                  icon: Icons.lock_outline,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(
                                        () => _showPassword = !_showPassword,
                                      );
                                    },
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                            validator: (value) {
                              if (value == null || value.length < 6) {
                                return 'Minimum 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                activeColor: primaryBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                onChanged: (v) {
                                  setState(() => _rememberMe = v ?? false);
                                },
                              ),
                              Text(
                                'Remember me',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: Colors.blueGrey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {},
                                child: Text(
                                  'Forgot password?',
                                  style: GoogleFonts.manrope(
                                    color: primaryBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.manrope(
                                  color: Colors.red.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          _GradientButton(
                            isLoading: _isLoading,
                            text: 'Sign In',
                            onPressed: (_isLoading || _isSocialLoading)
                                ? null
                                : _handleLogin,
                            colors: [primaryBlue, deepBlue],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.grey.shade300,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR',
                                  style: GoogleFonts.manrope(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blueGrey.shade400,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.grey.shade300,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: (_isLoading || _isSocialLoading)
                                ? null
                                : () => _handleSocialLogin('google'),
                            icon: googleLoading
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: primaryBlue,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/google.png',
                                    height: 22,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.g_mobiledata),
                                  ),
                            label: Text(
                              googleLoading
                                  ? 'Signing in...'
                                  : 'Continue with Google',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: _socialButtonStyle(),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: (_isLoading || _isSocialLoading)
                                ? null
                                : () => _handleSocialLogin('facebook'),
                            icon: facebookLoading
                                ? SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: primaryBlue,
                                    ),
                                  )
                                : const Icon(Icons.facebook, color: Colors.blue),
                            label: Text(
                              facebookLoading
                                  ? 'Signing in...'
                                  : 'Continue with Facebook',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: _socialButtonStyle(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: Colors.blueGrey.shade600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.register);
                        },
                        child: Text(
                          'Sign up',
                          style: GoogleFonts.manrope(
                            color: primaryBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(color: Colors.blueGrey.shade400),
      filled: true,
      fillColor: const Color(0xFFF2F4F8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIcon: icon != null
          ? Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.blueGrey.shade600, size: 18),
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  ButtonStyle _socialButtonStyle() {
    return OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.blueGrey.shade100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  String? _extractTokenFromHeaders(Map<String, String> headers) {
    String? raw =
        headers['authorization'] ??
        headers['Authorization'] ??
        headers['x-access-token'] ??
        headers['x-auth-token'] ??
        headers['token'];
    raw ??= _extractTokenFromSetCookie(headers['set-cookie']);
    if (raw == null || raw.trim().isEmpty) return null;
    raw = raw.trim();
    if (raw.toLowerCase().startsWith('bearer ')) {
      return raw.substring(7).trim();
    }
    return raw;
  }

  String? _extractTokenFromSetCookie(String? cookie) {
    if (cookie == null || cookie.trim().isEmpty) return null;
    final candidates = ['token', 'accessToken', 'access_token', 'jwt'];
    for (final key in candidates) {
      final match = RegExp('$key=([^;]+)').firstMatch(cookie);
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
    }
    return null;
  }

  String? _extractTokenFromBody(String body, dynamic data) {
    final trimmed = body.trim();
    if (_looksLikeJwt(trimmed)) return trimmed;
    if (data is Map<String, dynamic>) {
      for (final key in ['token', 'accessToken', 'access_token', 'jwt']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      final nested = data['data'];
      if (nested is Map<String, dynamic>) {
        for (final key in ['token', 'accessToken', 'access_token', 'jwt']) {
          final value = nested[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
    }
    return null;
  }

  bool _looksLikeJwt(String value) {
    return RegExp(
      r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$',
    ).hasMatch(value);
  }

  Future<void> _showSuccessAlert(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Success!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'You have successfully logged in.',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Navigate to home after dialog is dismissed
                      Navigator.of(context).pushReplacementNamed('/home');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'OK',
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
      },
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback? onPressed;
  final List<Color> colors;

  const _GradientButton({
    required this.text,
    required this.isLoading,
    required this.onPressed,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    text,
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
