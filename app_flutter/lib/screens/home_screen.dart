import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../session/user_session.dart';
import '../widgets/home_header.dart';
import '../widgets/search_section.dart';
import '../widgets/live_reports_section.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/login_required_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color primaryBlue = const Color(0xFF2F89B8);
  final Color goldColor = const Color(0xFFD4AF37);
  String _selectedFilter = 'MISSING';
  String _searchQuery = '';
  int _refreshSignal = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// Top Header
            const HomeHeader(),

            /// Fixed Search Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchSection(
                    primaryBlue: primaryBlue,
                    goldColor: goldColor,
                    onReportSubmitted: () {
                      setState(() {
                        _refreshSignal++;
                      });
                    },
                    onSearchChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            /// Live Reports Section (scrollable list only)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LiveReportsSection(
                  selectedFilter: _selectedFilter,
                  searchQuery: _searchQuery,
                  refreshSignal: _refreshSignal,
                  onFilterChanged: (filter) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  },
                ),
              ),
            ),

            /// Bottom Navigation Bar
            BottomNavBar(
              onProfileTap: () {
                if (!UserSession.isLoggedIn) {
                  showLoginRequiredDialog(context).then((shouldLogin) {
                    if (shouldLogin && context.mounted) {
                      Navigator.of(context).pushNamed(AppRoutes.login);
                    }
                  });
                  return;
                }
                Navigator.of(context).pushNamed(AppRoutes.profile);
              },
              onAdminTap: () {
                Navigator.of(context).pushNamed(AppRoutes.admin);
              },
            ),
          ],
        ),
      ),
    );
  }
}
