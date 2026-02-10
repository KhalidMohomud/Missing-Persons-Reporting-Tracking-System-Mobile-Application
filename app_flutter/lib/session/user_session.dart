import 'package:flutter/material.dart';

class UserInfo {
  final String name;
  final String email;
  final String? token;
  final String role;

  const UserInfo({
    required this.name,
    required this.email,
    this.token,
    this.role = 'public',
  });
}

class UserSession {
  static final ValueNotifier<UserInfo?> current = ValueNotifier<UserInfo?>(
    null,
  );

  static void setUser(UserInfo user) {
    current.value = user;
  }

  static void clear() {
    current.value = null;
  }

  static void updateFromLoginResponse({
    required String emailInput,
    dynamic data,
    String? tokenOverride,
  }) {
    final userMap = _extractUserMap(data);
    final fallbackEmail = emailInput.trim().isNotEmpty
        ? emailInput.trim()
        : 'guest@gmail.com';
    final email = _firstString(userMap, ['email', 'mail']) ?? fallbackEmail;
    final name =
        _firstString(userMap, ['fullName', 'name', 'username']) ??
        _nameFromEmail(email);
    final role = (data is Map<String, dynamic> && data['role'] is String)
        ? (data['role'] as String).trim()
        : _firstString(userMap, ['role']) ?? 'public';
    final token =
        tokenOverride ??
        _extractToken(data) ??
        _firstString(userMap, ['token', 'accessToken', 'access_token', 'jwt']);

    setUser(
      UserInfo(
        name: name.isEmpty ? 'User' : name,
        email: email.isEmpty ? fallbackEmail : email,
        token: token,
        role: role.isEmpty ? 'public' : role,
      ),
    );
  }

  static Map<String, dynamic>? _extractUserMap(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final directUser = data['user'];
    if (directUser is Map<String, dynamic>) return directUser;
    final directData = data['data'];
    if (directData is Map<String, dynamic>) {
      final nestedUser = directData['user'];
      if (nestedUser is Map<String, dynamic>) return nestedUser;
      return directData;
    }
    return data;
  }

  static String? _extractToken(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final direct = _firstString(data, [
      'token',
      'accessToken',
      'access_token',
      'jwt',
    ]);
    if (direct != null) return direct;
    final nested = data['data'];
    if (nested is Map<String, dynamic>) {
      return _firstString(nested, [
        'token',
        'accessToken',
        'access_token',
        'jwt',
      ]);
    }
    return null;
  }

  static String? _firstString(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String _nameFromEmail(String email) {
    final clean = email.split('@').first.replaceAll(RegExp(r'[_\.-]+'), ' ');
    final parts = clean
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim())
        .toList();
    if (parts.isEmpty) return 'User';
    return parts
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join(' ');
  }
}
