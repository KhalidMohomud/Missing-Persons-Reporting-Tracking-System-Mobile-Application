import 'package:flutter/material.dart';
import '../session/user_session.dart';

class BottomNavBar extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onAdminTap;
  final VoidCallback? onAlertTap;

  const BottomNavBar({
    super.key,
    this.onProfileTap,
    this.onAdminTap,
    this.onAlertTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserInfo?>(
      valueListenable: UserSession.current,
      builder: (context, user, _) {
        final bool isAdmin = (user?.role.toLowerCase() == 'admin');

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.search,
                label: 'BROWSE',
                isActive: true,
                onTap: () {},
              ),
              if (isAdmin)
                _NavItem(
                  icon: Icons.person_add,
                  label: 'Admin',
                  isActive: false,
                  onTap: onAdminTap ?? () {},
                ),
              _NavItem(
                icon: Icons.notifications,
                label: 'Alert',
                isActive: false,
                onTap: onAlertTap ?? () {},
              ),
              _NavItem(
                icon: Icons.person,
                label: 'Profile',
                isActive: false,
                onTap: onProfileTap ?? () {},
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF2F89B8);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? primaryBlue : Colors.grey.shade600,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? primaryBlue : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
