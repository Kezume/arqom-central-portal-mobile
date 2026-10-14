import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_pull_to_refresh.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../../../core/widgets/live_clock_widget.dart';
import '../../auth/data/auth_service.dart';
import '../../attendance/data/attendance_service.dart';
import '../data/dashboard_service.dart';
import '../data/models/activity.dart';
import '../data/models/announcement.dart';
import '../../worship/presentation/almatsurat_screen.dart';
import '../../requests/presentation/dinas_luar_screen.dart';
import '../../requests/presentation/cuti_tahunan_screen.dart';
import '../../requests/presentation/izin_screen.dart';
import '../../requests/presentation/sakit_screen.dart';
import '../../requests/presentation/kerja_lembur_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/data/notifications_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _userData;
  List<Announcement> _announcements = [];
  List<Activity> _activities = [];
  bool _isLoadingDashboard = true;
  bool _isCheckingIn = false;
  bool _isCheckingOut = false;
  Future<Map<String, dynamic>?>? _todayFuture;

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Layanan lokasi dinonaktifkan. Harap nyalakan GPS.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin lokasi ditolak.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin lokasi ditolak secara permanen.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal mendapatkan lokasi (Timeout). Pastikan GPS menyala dan sinyal stabil.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return null;
    }
  }

  Future<File?> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 50,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  Future<void> _handleAttendance(bool isCheckIn) async {
    if (!isCheckIn) {
      final hour = DateTime.now().hour;
      if (hour < 17) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Belum waktunya pulang. Anda baru bisa absen pulang setelah jam 17:00.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      if (isCheckIn) {
        _isCheckingIn = true;
      } else {
        _isCheckingOut = true;
      }
    });

    try {
      final position = await _getCurrentLocation();
      if (position == null) {
        setState(() {
          _isCheckingIn = false;
          _isCheckingOut = false;
        });
        return;
      }

      final todayData = await AttendanceService.getToday();
      if (isCheckIn &&
          todayData != null &&
          todayData['check_in'] != null &&
          todayData['check_in'] != '--:--') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda sudah absen masuk hari ini.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
        setState(() {
          _isCheckingIn = false;
          _isCheckingOut = false;
        });
        return;
      }

      File? photo = await _takePhoto();
      if (photo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto wajib diambil untuk absensi.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() {
          _isCheckingIn = false;
          _isCheckingOut = false;
        });
        return;
      }

      final result = isCheckIn
          ? await AttendanceService.checkIn(
              position.latitude.toString(),
              position.longitude.toString(),
              photo,
            )
          : await AttendanceService.checkOut(
              position.latitude.toString(),
              position.longitude.toString(),
              photo,
            );

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: AppColors.primary,
            ),
          );
          // Refresh today's attendance data immediately
          setState(() {
            _todayFuture = AttendanceService.getToday();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan. Coba lagi.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
          _isCheckingOut = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _todayFuture = AttendanceService.getToday();
    _loadUserData();
    _loadDashboardData();
    NotificationsService.refreshUnreadCount();
  }

  Future<void> _loadDashboardData() async {
    final response = await DashboardService.getDashboardData();
    if (mounted) {
      setState(() {
        if (response['success'] == true) {
          _announcements = response['announcements'] as List<Announcement>;
          _activities = response['activities'] as List<Activity>;
        }
        _isLoadingDashboard = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    final data = await AuthService.getUserData();
    if (mounted) {
      setState(() {
        _userData = data;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoadingDashboard = true;
      _todayFuture = AttendanceService.getToday();
    });
    await Future.wait([
      _loadUserData(),
      _loadDashboardData(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ArtechPullToRefresh(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── HERO HEADER & OVERLAPPING ATTENDANCE CARD ───
              Stack(
                children: [
                  // Gradient Header Backdrop (anchors top half of attendance card)
                  Positioned.fill(
                    bottom: 84,
                    child: _buildHeaderBackdrop(context),
                  ),

                  // Header Foreground Content + Floating Attendance Card
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopBar(context),
                          const SizedBox(height: 16),
                          _buildProfileRow(context),
                          const SizedBox(height: 20),
                          _buildAttendanceCard(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ─── DASHBOARD BODY CONTENT ───
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildQuickAccess(context),
                    const SizedBox(height: 24),
                    _buildAgendaSection(context),
                    const SizedBox(height: 20),
                    _buildAnnouncementSection(context),
                    const SizedBox(height: 20),
                    _buildDailyQuote(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER BACKDROP WITH SMOOTH GRADIENT & AMBIENT DEPTH ─────────────
  Widget _buildHeaderBackdrop(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF091E47),
            Color(0xFF0037B0),
            Color(0xFF155DFC),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Soft ambient circular glow 1 (top right)
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          // Subtle warm accent glow (echoing the ARTECH orange branding)
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFE961D).withValues(alpha: 0.09),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── TOP BAR (BRANDING & NOTIFICATIONS) ────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Frosted Glass Brand Capsule
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'logo/artech_symbol.png',
                height: 20,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.business, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                'ARQOM ONE',
                style: TextStyle(
                  color: Colors.white,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Frosted Notification Icon Button
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
            valueListenable: NotificationsService.unreadCountNotifier,
            builder: (context, unreadCount, _) {
              const iconWidget = Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
                size: 21,
              );

              return IconButton(
                padding: EdgeInsets.zero,
                icon: unreadCount > 0
                    ? const Badge(
                        backgroundColor: Color(0xFFFF4848),
                        smallSize: 8,
                        child: iconWidget,
                      )
                    : iconWidget,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  );
                  NotificationsService.refreshUnreadCount();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── PROFILE ROW (USER, ROLE & WORK STATUS) ───────────────────────────
  Widget _buildProfileRow(BuildContext context) {
    final name = _userData?['name'] ?? 'Pengguna';
    final firstName = name.split(' ').first;
    final role = _userData?['position'] ?? _userData?['role'] ?? 'Staff';
    final photoUrl = _userData?['profile_photo_url'] ??
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0037b0&color=fff';

    return Row(
      children: [
        // Avatar with polished double border
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 23,
            backgroundImage: NetworkImage(photoUrl),
            backgroundColor: Colors.white24,
          ),
        ),
        const SizedBox(width: 12),

        // Greeting & Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getGreeting()},',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                firstName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                role,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Work Location Pill (WFO)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF00E676),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF00E676),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'WFO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── FLOATING ATTENDANCE CARD (GLASSMORPHIC & TACTILE) ────────────────
  Widget _buildAttendanceCard(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _todayFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final bool isCheckedIn = data != null &&
            data['check_in'] != null &&
            data['check_in'] != '--:--';
        final bool isCheckedOut = data != null &&
            data['check_out'] != null &&
            data['check_out'] != '--:--';
        final String checkInTime = data?['check_in'] ?? '--:--';
        final String checkOutTime = data?['check_out'] ?? '--:--';

        final String statusText;
        final Color statusColor;
        final Color statusBg;
        final IconData statusIcon;

        if (isCheckedOut) {
          statusText = 'Presensi Lengkap';
          statusColor = const Color(0xFF0D9488);
          statusBg = const Color(0xFFCCFBF1);
          statusIcon = Icons.verified_rounded;
        } else if (isCheckedIn) {
          statusText = 'Sudah Presensi Masuk';
          statusColor = const Color(0xFF16A34A);
          statusBg = const Color(0xFFDCFCE7);
          statusIcon = Icons.check_circle_rounded;
        } else {
          statusText = 'Belum Presensi';
          statusColor = const Color(0xFFD97706);
          statusBg = const Color(0xFFFEF3C7);
          statusIcon = Icons.pending_actions_rounded;
        }

        final bool canCheckOut = DateTime.now().hour >= 17;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F2D67).withValues(alpha: 0.09),
                blurRadius: 30,
                offset: const Offset(0, 12),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Status row & Limit badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Limit Chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Batas 08:15 WIB',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 2. Live Clock Display
              LiveClockWidget(
                timeStyle: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F2D67),
                  letterSpacing: -0.5,
                ),
                amPmStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 4),

              // Full Current Indonesian Date
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _getFormattedDate(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 3. Check-in & Check-out Preview Strip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Check in
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isCheckedIn
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.login_rounded,
                              size: 14,
                              color: isCheckedIn
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Masuk',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                checkInTime,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isCheckedIn
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Container(
                      width: 1,
                      height: 26,
                      color: const Color(0xFFE2E8F0),
                    ),

                    // Check out
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isCheckedOut
                                    ? const Color(0xFFE0E7FF)
                                    : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.logout_rounded,
                                size: 14,
                                color: isCheckedOut
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pulang',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  checkOutTime,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isCheckedOut
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Interactive Action Buttons (Masuk Kerja & Pulang)
              Row(
                children: [
                  // Tombol Masuk Kerja
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: isCheckedIn
                          ? Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: const Color(0xFFBBF7D0),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 17,
                                    color: Color(0xFF16A34A),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Sudah Masuk',
                                    style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0037B0),
                                    Color(0xFF1D4ED8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(13),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0037B0)
                                        .withValues(alpha: 0.28),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(13),
                                  onTap: _isCheckingIn
                                      ? null
                                      : () => _handleAttendance(true),
                                  child: Center(
                                    child: _isCheckingIn
                                        ? ArtechLoadingWidget.button(size: 18)
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.login_rounded,
                                                color: Colors.white,
                                                size: 17,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Masuk Kerja',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Tombol Pulang Kerja
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: isCheckedOut
                          ? Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: const Color(0xFFC7D2FE),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 17,
                                    color: Color(0xFF4F46E5),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Sudah Pulang',
                                    style: TextStyle(
                                      color: Color(0xFF4F46E5),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : canCheckOut
                              ? Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFE11D48),
                                        Color(0xFFF43F5E),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE11D48)
                                            .withValues(alpha: 0.28),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(13),
                                      onTap: _isCheckingOut
                                          ? null
                                          : () => _handleAttendance(false),
                                      child: Center(
                                        child: _isCheckingOut
                                            ? ArtechLoadingWidget.button(
                                                size: 18)
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.logout_rounded,
                                                    color: Colors.white,
                                                    size: 17,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Pulang Kerja',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.lock_clock_rounded,
                                        size: 16,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Pulang (17:00)',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── QUICK ACCESS (AKSES CEPAT) ──────────────────────────────────────
  Widget _buildQuickAccess(BuildContext context) {
    final items = [
      _QuickItem(Icons.history_toggle_off, 'Kehadiran', () {
        widget.onNavigateTab?.call(1);
      }),
      _QuickItem(Icons.event_available, 'Pengajuan', () {
        widget.onNavigateTab?.call(3);
      }),
      _QuickItem(Icons.beach_access, 'Cuti', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CutiTahunanScreen()),
        );
      }),
      _QuickItem(Icons.assignment_turned_in, 'Izin', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const IzinScreen()),
        );
      }),
      _QuickItem(Icons.sick, 'Sakit', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SakitScreen()),
        );
      }),
      _QuickItem(Icons.flight_takeoff, 'Dinas Luar', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DinasLuarScreen()),
        );
      }),
      _QuickItem(Icons.more_time, 'Lembur', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const KerjaLemburScreen()),
        );
      }),
      _QuickItem(Icons.auto_stories, 'Al-Ma\'tsurat', () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AlmatsuratScreen()),
        );
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Akses Cepat',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '8 Layanan',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 8,
            mainAxisExtent: 78,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item.icon, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─── AGENDA SECTION ──────────────────────────────────────────────────
  Widget _buildAgendaSection(BuildContext context) {
    if (_isLoadingDashboard) {
      return _buildShimmerPlaceholder(context, 'Agenda');
    }
    if (_activities.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'Agenda Mendatang',
          '${_activities.length} kegiatan terdaftar',
        ),
        const SizedBox(height: 10),
        ..._activities.take(3).map((a) => _buildAgendaItem(context, a)),
      ],
    );
  }

  Widget _buildAgendaItem(BuildContext context, Activity activity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${activity.location} · ${activity.pic}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                activity.activityDate.length >= 10
                    ? activity.activityDate.substring(5, 10).replaceAll('-', '/')
                    : activity.activityDate,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ANNOUNCEMENT SECTION ────────────────────────────────────────────
  Widget _buildAnnouncementSection(BuildContext context) {
    if (_isLoadingDashboard) return const SizedBox.shrink();
    if (_announcements.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Pengumuman', 'Informasi Internal'),
        const SizedBox(height: 10),
        ..._announcements.take(3).map((a) => _buildAnnouncementItem(context, a)),
      ],
    );
  }

  Widget _buildAnnouncementItem(
      BuildContext context, Announcement announcement) {
    final isUrgent = announcement.priority.toLowerCase() == 'urgent';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUrgent
                ? AppColors.error.withValues(alpha: 0.3)
                : AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isUrgent
                    ? AppColors.errorContainer.withValues(alpha: 0.5)
                    : AppColors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isUrgent ? Icons.warning_amber_rounded : Icons.campaign_outlined,
                size: 18,
                color: isUrgent ? AppColors.error : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    announcement.title,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    announcement.description,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DAILY QUOTE ─────────────────────────────────────────────────────
  static const List<Map<String, String>> _dailyQuotes = [
    {
      'text': 'Maka sesungguhnya bersama kesulitan ada kemudahan.',
      'source': 'QS. Al-Insyirah: 5'
    },
    {
      'text':
          'Dan bersabarlah, karena sesungguhnya Allah tidak menyia-nyiakan pahala orang yang berbuat kebaikan.',
      'source': 'QS. Hud: 115'
    },
    {
      'text':
          'Allah tidak membebani seseorang melainkan sesuai dengan kesanggupannya.',
      'source': 'QS. Al-Baqarah: 286'
    },
    {
      'text': 'Boleh jadi kamu membenci sesuatu, padahal ia amat baik bagimu.',
      'source': 'QS. Al-Baqarah: 216'
    },
    {
      'text': 'Sesungguhnya Allah beserta orang-orang yang sabar.',
      'source': 'QS. Al-Baqarah: 153'
    },
    {
      'text': 'Maka nikmat Tuhan kamu yang manakah yang kamu dustakan?',
      'source': 'QS. Ar-Rahman: 13'
    },
    {
      'text':
          'Barangsiapa bertakwa kepada Allah niscaya Dia akan membukakan jalan keluar baginya.',
      'source': 'QS. At-Talaq: 2'
    },
  ];

  Widget _buildDailyQuote(BuildContext context) {
    final int dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final quote = _dailyQuotes[dayOfYear % _dailyQuotes.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote,
            color: AppColors.primary.withValues(alpha: 0.3),
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote['text']!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '— ${quote['source']}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.outline,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SHARED HELPERS ──────────────────────────────────────────────────
  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle, {
    VoidCallback? onTapAction,
    String? actionLabel,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ),
        if (onTapAction != null && actionLabel != null)
          GestureDetector(
            onTap: onTapAction,
            child: Text(
              actionLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
      ],
    );
  }

  Widget _buildShimmerPlaceholder(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'Memuat $label...',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ),
    );
  }
}

// Simple data class for quick access items
class _QuickItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickItem(this.icon, this.label, this.onTap);
}
