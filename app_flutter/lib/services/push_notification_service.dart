import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../api/api.dart';
import '../firebase_options.dart';
import '../routes/app_routes.dart';
import '../session/user_session.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;
  String? _currentToken;

  bool get isConfigured =>
      !DefaultFirebaseOptions.android.apiKey.startsWith('REPLACE_');

  Future<void> initialize({GlobalKey<NavigatorState>? navigatorKey}) async {
    _navigatorKey = navigatorKey;
    if (_initialized) return;

    if (!isConfigured) {
      debugPrint('[push] Firebase options not configured yet.');
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      if (!kIsWeb && Platform.isAndroid) {
        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);
        await _localNotifications.initialize(
          settings: initSettings,
          onDidReceiveNotificationResponse: _onLocalNotificationTap,
        );

        const channel = AndroidNotificationChannel(
          'mpts_alerts',
          'MPTS Alerts',
          description: 'Missing person alerts and report updates',
          importance: Importance.high,
        );
        await _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      await _requestPermission();

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageNavigation(initialMessage);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _currentToken = token;
        _registerTokenWithBackend(token);
      });

      _initialized = true;
    } catch (e) {
      debugPrint('[push] Initialization failed: $e');
    }
  }

  Future<void> _requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> syncForLoggedInUser() async {
    if (!_initialized || !UserSession.isLoggedIn) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _currentToken = token;
        await _registerTokenWithBackend(token);
      }
      await updateDeviceLocation();
    } catch (e) {
      debugPrint('[push] Failed to sync token/location: $e');
    }
  }

  Future<void> clearForLogout() async {
    if (_currentToken == null || _currentToken!.isEmpty) return;
    try {
      await http
          .delete(
            Uri.parse(FCM_TOKEN_URL),
            headers: _buildHeaders(),
            body: jsonEncode({'token': _currentToken}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[push] Failed to remove token on logout: $e');
    }
  }

  Future<void> updateDeviceLocation() async {
    if (!_initialized || !UserSession.isLoggedIn) return;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      await http
          .post(
            Uri.parse(USER_LOCATION_URL),
            headers: _buildHeaders(),
            body: jsonEncode({
              'lat': position.latitude,
              'lng': position.longitude,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[push] Failed to update location: $e');
    }
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

  Future<void> _registerTokenWithBackend(String token) async {
    if (!UserSession.isLoggedIn) return;
    try {
      await http
          .post(
            Uri.parse(FCM_TOKEN_URL),
            headers: _buildHeaders(),
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[push] Failed to register token: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    if (!kIsWeb && Platform.isAndroid) {
      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'mpts_alerts',
            'MPTS Alerts',
            channelDescription: 'Missing person alerts and report updates',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map) {
        _navigateForData(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
  }

  void _handleMessageNavigation(RemoteMessage message) {
    _navigateForData(message.data);
  }

  void _navigateForData(Map<String, dynamic> data) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    final type = (data['type'] ?? '').toString();
    switch (type) {
      case 'nearby_alert':
        navigator.pushNamed(AppRoutes.alertsCenter);
        break;
      case 'new_tip':
      case 'verification_message':
      case 'verification_evidence':
      case 'verification_verified':
      case 'verification_rejected':
      case 'report_status_changed':
        navigator.pushNamed(AppRoutes.myReports);
        break;
      default:
        navigator.pushNamed(AppRoutes.alertsCenter);
    }
  }
}
