import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_pull_to_refresh.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/data/notifications_service.dart';
import 'widgets/monthly_target_tab.dart';
import 'widgets/weekly_plan_tab.dart';
import 'widgets/daily_task_tab.dart';
import 'widgets/weekly_review_tab.dart';

class PerformanceScreen extends StatefulWidget {
  final int initialTabIndex;

  const PerformanceScreen({super.key, this.initialTabIndex = 0});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  late int _selectedTabIndex;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex.clamp(0, 3);
    NotificationsService.refreshUnreadCount();
  }

  Future<void> _refreshData() async {
    setState(() {
      _refreshKey++;
    });
    await Future.wait([
      NotificationsService.refreshUnreadCount(),
      Future.delayed(const Duration(milliseconds: 600)),
    ]);
  }

  void _onDataChanged() {
    setState(() {
      _refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ArtechPullToRefresh(
        onRefresh: _refreshData,
        refreshingText: 'Memperbarui performa...',
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMiniHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTabNavigation(context),
                    const SizedBox(height: 18),
                    _buildActiveTabContent(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF091E47), Color(0xFF0037B0), Color(0xFF155DFC)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Ambient glow circle 1 (top-right)
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          // Ambient glow circle 2 (bottom-left)
          Positioned(
            bottom: -15,
            left: -15,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFE961D).withValues(alpha: 0.08),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Kinerja',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Frosted Notification Icon Button (Consistent with Home, Attendance, Requests)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: ValueListenableBuilder<int>(
                        valueListenable:
                            NotificationsService.unreadCountNotifier,
                        builder: (context, unreadCount, _) {
                          const iconWidget = Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white,
                            size: 21,
                          );

                          return IconButton(
                            padding: EdgeInsets.zero,
                            icon:
                                unreadCount > 0
                                    ? const Badge(
                                      backgroundColor: Color(0xFFEF4444),
                                      smallSize: 8,
                                      child: iconWidget,
                                    )
                                    : iconWidget,
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              );
                              NotificationsService.refreshUnreadCount();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Rencana dan progres kerja Anda',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabNavigation(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabItem(0, 'Bulanan', Icons.flag_rounded)),
          Expanded(
            child: _buildTabItem(1, 'Mingguan', Icons.date_range_rounded),
          ),
          Expanded(child: _buildTabItem(2, 'Harian', Icons.today_rounded)),
          Expanded(
            child: _buildTabItem(3, 'Evaluasi', Icons.fact_check_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon) {
    final isActive = _selectedTabIndex == index;

    return Semantics(
      button: true,
      selected: isActive,
      label: 'Buka $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _selectedTabIndex = index;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? AppColors.primary : const Color(0xFFD8DEEA),
              ),
              boxShadow:
                  isActive
                      ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                      : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? Colors.white : AppColors.primary,
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return MonthlyTargetTab(
          key: ValueKey('monthly_target_$_refreshKey'),
          onDataChanged: _onDataChanged,
        );
      case 1:
        return WeeklyPlanTab(
          key: ValueKey('weekly_plan_$_refreshKey'),
          onDataChanged: _onDataChanged,
        );
      case 2:
        return DailyTaskTab(
          key: ValueKey('daily_task_$_refreshKey'),
          onDataChanged: _onDataChanged,
        );
      case 3:
        return WeeklyReviewTab(
          key: ValueKey('weekly_review_$_refreshKey'),
          onDataChanged: _onDataChanged,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
