import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../session/user_session.dart';
import '../widgets/logout_confirm_dialog.dart';
import '../widgets/login_required_dialog.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!UserSession.isLoggedIn) {
        showLoginRequiredDialog(context).then((shouldLogin) {
          if (!mounted) return;
          if (shouldLogin) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
          } else {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed(AppRoutes.home);
            }
          }
        });
      }
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showLogoutConfirmDialog(context);
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF2F89B8);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: primaryBlue),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.arrow_forward_ios, color: primaryBlue, size: 20),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            /// Header with Profile Picture
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [primaryBlue, primaryBlue.withOpacity(0.8)],
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  /// Profile Picture
                  ValueListenableBuilder<UserInfo?>(
                    valueListenable: UserSession.current,
                    builder: (context, user, _) {
                      final name = user?.name ?? 'Guest';
                      final email = user?.email ?? 'guest@example.com';
                      final photoUrl = user?.photoUrl ?? '';
                      final hasPhoto =
                          photoUrl.isNotEmpty && photoUrl.startsWith('http');

                      return Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 55,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage: hasPhoto
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: hasPhoto
                                      ? null
                                      : const Icon(Icons.person, size: 60),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const EditProfileScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.camera_alt,
                                      size: 20,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            /// Profile Options
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ProfileMenuItem(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information',
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ProfileMenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Manage your notification settings',
                    onTap: () {
                      Navigator.of(context).pushNamed(AppRoutes.alertsCenter);
                    },
                  ),
                  // const SizedBox(height: 12),
                  // _ProfileMenuItem(
                  //   icon: Icons.lock_outline,
                  //   title: 'Privacy & Security',
                  //   subtitle: 'Manage your privacy settings',
                  //   onTap: () {},
                  // ),
                  // const SizedBox(height: 12),
                  // _ProfileMenuItem(
                  //   icon: Icons.help_outline,
                  //   title: 'Help & Support',
                  //   subtitle: 'Get help and contact support',
                  //   onTap: () {},
                  // ),
                  // const SizedBox(height: 12),
                  // _ProfileMenuItem(
                  //   icon: Icons.info_outline,
                  //   title: 'About',
                  //   subtitle: 'App version and information',
                  //   onTap: () {},
                  // ),
                  const SizedBox(height: 24),

                  /// Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showLogoutDialog(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.red.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.red.shade300),
                          const SizedBox(width: 8),
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF2F89B8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
