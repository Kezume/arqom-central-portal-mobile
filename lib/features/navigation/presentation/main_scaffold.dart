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
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.85),
            width: 1,
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
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Indicator Line (YouTube / Twitter / LinkedIn style)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: isSelected ? 32 : 0,
                height: 3,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF0037B0), Color(0xFF155DFC)],
                        )
                      : null,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0037B0).withValues(alpha: 0.45),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),

              const Spacer(),

              // Icon with subtle animated scale
              AnimatedScale(
                scale: isSelected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Icon(
                  isSelected ? activeIcon : outlineIcon,
                  size: 23,
                  color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 3),

              // Text Label
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
