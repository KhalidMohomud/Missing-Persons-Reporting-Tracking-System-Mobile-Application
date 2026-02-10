import 'package:flutter/material.dart';

import '../admin_models.dart';
import '../admin_theme.dart';

class AdminNavBar extends StatelessWidget {
  final AdminTab activeTab;
  final ValueChanged<AdminTab> onTabChanged;

  const AdminNavBar({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              tab: AdminTab.dashboard,
              label: 'Dashboard',
              icon: Icons.dashboard_outlined,
              isActive: activeTab == AdminTab.dashboard,
              onTap: onTabChanged,
            ),
          ),
          Expanded(
            child: _NavItem(
              tab: AdminTab.missing,
              label: 'Missing',
              icon: Icons.person_search_outlined,
              isActive: activeTab == AdminTab.missing,
              onTap: onTabChanged,
            ),
          ),
          Expanded(
            child: _NavItem(
              tab: AdminTab.found,
              label: 'Found',
              icon: Icons.location_on_outlined,
              isActive: activeTab == AdminTab.found,
              onTap: onTabChanged,
            ),
          ),
          Expanded(
            child: _NavItem(
              tab: AdminTab.tips,
              label: 'Tips',
              icon: Icons.tips_and_updates_outlined,
              isActive: activeTab == AdminTab.tips,
              onTap: onTabChanged,
            ),
          ),
          Expanded(
            child: _NavItem(
              tab: AdminTab.users,
              label: 'Users',
              icon: Icons.manage_accounts_outlined,
              isActive: activeTab == AdminTab.users,
              onTap: onTabChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final AdminTab tab;
  final String label;
  final IconData icon;
  final bool isActive;
  final ValueChanged<AdminTab> onTap;

  const _NavItem({
    required this.tab,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [AdminTheme.primaryBlue, AdminTheme.deepBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
