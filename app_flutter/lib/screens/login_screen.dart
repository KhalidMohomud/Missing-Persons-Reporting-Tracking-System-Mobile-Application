import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api/api.dart';
import '../routes/app_routes.dart';
import '../session/user_session.dart';

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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                /// Logo
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/iconsapp.png',
                        height: 72,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.person, size: 80),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to continue',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                /// Email
                const Text(
                  'Email',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
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

                const SizedBox(height: 12),

                /// Password
                const Text(
                  'Password',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
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
                            setState(() => _showPassword = !_showPassword);
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

                const SizedBox(height: 8),

                /// Remember + forgot
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (v) {
                        setState(() => _rememberMe = v ?? false);
                      },
                    ),
                    const Text('Remember me'),
                    const Spacer(),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(color: primaryBlue),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                /// Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                /// Sign In
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: (_isLoading || _isSocialLoading)
                      ? null
                      : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),

                const SizedBox(height: 16),

                /// Divider
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 12),

                /// Google
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
                    googleLoading ? 'Signing in...' : 'Continue with Google',
                  ),
                  style: _socialButtonStyle(),
                ),

                const SizedBox(height: 8),

                /// Facebook
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
                  ),
                  style: _socialButtonStyle(),
                ),

                const SizedBox(height: 12),

                const Spacer(),

                /// Register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.register);
                      },
                      child: Text(
                        'Sign up',
                        style: TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF2F3F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade600) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  ButtonStyle _socialButtonStyle() {
    return OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
