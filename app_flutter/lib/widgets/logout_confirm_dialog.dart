import 'package:flutter/material.dart';
import '../session/user_session.dart';
import '../routes/app_routes.dart';

Future<void> showLogoutConfirmDialog(BuildContext context) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Logout'),
        content: const Text('Do you want to logout or close?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              UserSession.clear();
              Navigator.of(context).pushReplacementNamed(AppRoutes.login);
            },
            child: Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );
}
