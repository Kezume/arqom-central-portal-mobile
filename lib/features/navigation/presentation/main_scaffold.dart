import 'package:flutter/material.dart';
import '../../home/presentation/home_screen.dart';
import '../../attendance/presentation/attendance_screen.dart';
import '../../performance/presentation/performance_screen.dart';
import '../../requests/presentation/requests_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../../core/theme/app_colors.dart';

import 'package:google_fonts/google_fonts.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  List<Widget> get _pages => [
    HomeScreen(onNavigateTab: _onItemTapped),
    const AttendanceScreen(),
    const PerformanceScreen(),
    const RequestsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(
            color: Color(0xFFF1F5F9),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                label: 'Beranda',
                outlineIcon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
              ),
              _buildNavItem(
                index: 1,
                label: 'Kehadiran',
                outlineIcon: Icons.history_toggle_off_outlined,
                activeIcon: Icons.history_toggle_off_rounded,
              ),
              _buildNavItem(
                index: 2,
                label: 'Kinerja',
                outlineIcon: Icons.insights_outlined,
                activeIcon: Icons.insights_rounded,
              ),
              _buildNavItem(
                index: 3,
                label: 'Pengajuan',
                outlineIcon: Icons.assignment_outlined,
                activeIcon: Icons.assignment_rounded,
              ),
              _buildNavItem(
                index: 4,
                label: 'Profil',
                outlineIcon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData outlineIcon,
    required IconData activeIcon,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          splashColor: AppColors.primary.withValues(alpha: 0.05),
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sharp Icon
              Icon(
                isSelected ? activeIcon : outlineIcon,
                size: 24,
                color: isSelected ? AppColors.primary : const Color(0xFF64748B),
              ),

              const SizedBox(height: 4),

              // Crisp Plus Jakarta Sans Label
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
