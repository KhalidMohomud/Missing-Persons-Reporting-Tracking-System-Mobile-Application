import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/register_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/admin/admin_screen.dart';
import '../screens/report_missing_screen.dart';
import '../screens/report_found_screen.dart';
import '../screens/add_found_report_screen.dart';
import '../screens/add_alert_screen.dart';
import '../screens/alerts_notifications_screen.dart';

class AppRoutes {
  static const String login = '/';
  static const String home = '/home';
  static const String register = '/register';
  static const String profile = '/profile';
  static const String splash = '/splash';
  static const String reportMissing = '/report-missing';
  static const String reportFound = '/report-found';
  static const String addAlert = '/add-alert';
  static const String alertsCenter = '/alerts-center';
  static const String admin = '/admin';
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case reportMissing:
        return MaterialPageRoute(builder: (_) => const ReportMissingScreen());
      case reportFound:
        return MaterialPageRoute(builder: (_) => const AddFoundReportScreen());
      case addAlert:
        return MaterialPageRoute(builder: (_) => const AddAlertScreen());
      case alertsCenter:
        return MaterialPageRoute(
          builder: (_) => const AlertsNotificationsScreen(),
        );
      case admin:
        return MaterialPageRoute(builder: (_) => const AdminScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
