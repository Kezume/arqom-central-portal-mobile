import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_pull_to_refresh.dart';
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
  bool _isLoadingAttendance = false;
  Future<Map<String, dynamic>?>? _todayFuture;

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Layanan lokasi dinonaktifkan. Harap nyalakan GPS.'), backgroundColor: AppColors.error));
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak.'), backgroundColor: AppColors.error));
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak secara permanen.'), backgroundColor: AppColors.error));
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mendapatkan lokasi (Timeout). Pastikan GPS menyala dan sinyal stabil.'), backgroundColor: AppColors.error));
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Belum waktunya pulang. Anda baru bisa absen pulang setelah jam 17:00.'), backgroundColor: AppColors.error));
        return;
      }
    }

    setState(() { _isLoadingAttendance = true; });

    try {
      final position = await _getCurrentLocation();
      if (position == null) {
        setState(() { _isLoadingAttendance = false; });
        return;
      }

      final todayData = await AttendanceService.getToday();
      if (isCheckIn && todayData != null && todayData['check_in'] != null && todayData['check_in'] != '--:--') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Anda sudah absen masuk hari ini.'), backgroundColor: AppColors.primary),
          );
        }
        setState(() { _isLoadingAttendance = false; });
        return;
      }

      File? photo = await _takePhoto();
      if (photo == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto wajib diambil untuk absensi.'), backgroundColor: AppColors.error));
        setState(() { _isLoadingAttendance = false; });
        return;
      }

      final result = isCheckIn 
          ? await AttendanceService.checkIn(position.latitude.toString(), position.longitude.toString(), photo)
          : await AttendanceService.checkOut(position.latitude.toString(), position.longitude.toString(), photo);

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: AppColors.primary));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: AppColors.error));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Terjadi kesalahan. Coba lagi.'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) {
        setState(() { _isLoadingAttendance = false; });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _todayFuture = AttendanceService.getToday();
    _loadUserData();
    _loadDashboardData();
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
      backgroundColor: AppColors.surfaceContainerLowest,
      body: ArtechPullToRefresh(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAttendanceCard(context),
                    const SizedBox(height: 20),
                    _buildQuickAccess(context),
                    const SizedBox(height: 20),
                    _buildPerformanceRow(context),
                    const SizedBox(height: 20),
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

  // ─── HEADER ──────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final name = _userData?['name'] ?? 'Pengguna';
    final firstName = name.split(' ').first;
    final role = _userData?['position'] ?? _userData?['role'] ?? 'Staff';
    final photoUrl = _userData?['profile_photo_url'] ??
        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0037b0&color=fff';

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // Top bar: logo + notifications
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'logo/artech_symbol.png',
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.business, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ARQOM ONE',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              IconButton(
                icon: const Badge(
                  backgroundColor: AppColors.error,
                  smallSize: 8,
                  child: Icon(Icons.notifications_none, color: Colors.white, size: 22),
                ),
                onPressed: () {},
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Profile row
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage(photoUrl),
                  backgroundColor: Colors.white24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()}, $firstName',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text('WFO', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── ATTENDANCE CARD ─────────────────────────────────────────────────
  Widget _buildAttendanceCard(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _todayFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final bool isCheckedIn = data != null && data['check_in'] != null && data['check_in'] != '--:--';
        
        final String statusText = isCheckedIn ? 'Sudah Presensi Masuk' : 'Belum Presensi';
        final Color statusColor = isCheckedIn ? AppColors.secondary : AppColors.error;
        final Color statusBgColor = isCheckedIn ? AppColors.secondaryContainer.withOpacity(0.5) : AppColors.errorContainer.withOpacity(0.5);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              // Status row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(statusText, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              const Spacer(),
              Text('Batas: 08:15 WIB', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          // Clock
          LiveClockWidget(
            timeStyle: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
            amPmStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          // Buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isLoadingAttendance && true // just to show loading indicator if we want, but usually better to disable
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.login, size: 18),
                  label: const Text('Masuk Kerja'),
                  onPressed: _isLoadingAttendance ? null : () => _handleAttendance(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.surfaceContainerHigh,
                    foregroundColor: AppColors.onSurfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Pulang'),
                  onPressed: (_isLoadingAttendance || DateTime.now().hour < 17) ? null : () => _handleAttendance(false),
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

  // ─── QUICK ACCESS ────────────────────────────────────────────────────
  Widget _buildQuickAccess(BuildContext context) {
    final items = [
      _QuickItem(Icons.history_toggle_off, 'Kehadiran', () { widget.onNavigateTab?.call(1); }),
      _QuickItem(Icons.event_available, 'Pengajuan', () { widget.onNavigateTab?.call(3); }),
      _QuickItem(Icons.beach_access, 'Cuti', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CutiTahunanScreen()));
      }),
      _QuickItem(Icons.assignment_turned_in, 'Izin', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IzinScreen()));
      }),
      _QuickItem(Icons.sick, 'Sakit', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SakitScreen()));
      }),
      _QuickItem(Icons.flight_takeoff, 'Dinas Luar', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DinasLuarScreen()));
      }),
      _QuickItem(Icons.more_time, 'Lembur', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KerjaLemburScreen()));
      }),
      _QuickItem(Icons.auto_stories, 'Al-Ma\'tsurat', () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlmatsuratScreen()));
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Akses Cepat', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 4,
            mainAxisExtent: 76,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500, fontSize: 10),
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

  // ─── PERFORMANCE ROW ─────────────────────────────────────────────────
  Widget _buildPerformanceRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context, 'Kinerja', 'Q4 2024', actionLabel: 'Detail', onTapAction: () {}),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildMetricTile(context, 'KPI', '87.5', 'Sangat Baik', AppColors.secondary)),
              const SizedBox(width: 10),
              Expanded(child: _buildMetricTile(context, 'OKR', '76%', 'Target: 80%', AppColors.primary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(BuildContext context, String label, String value, String subtext, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(subtext, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w600, fontSize: 10)),
          ),
        ],
      ),
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
        _buildSectionHeader(context, 'Agenda Mendatang', '${_activities.length} kegiatan'),
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
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${activity.location} · ${activity.pic}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10),
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
                color: AppColors.primaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                activity.activityDate.length >= 10 ? activity.activityDate.substring(5, 10).replaceAll('-', '/') : activity.activityDate,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10),
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

  Widget _buildAnnouncementItem(BuildContext context, Announcement announcement) {
    final isUrgent = announcement.priority.toLowerCase() == 'urgent';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isUrgent ? AppColors.error.withOpacity(0.3) : AppColors.outlineVariant.withOpacity(0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isUrgent ? AppColors.errorContainer.withOpacity(0.5) : AppColors.primaryContainer.withOpacity(0.3),
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
                  Text(announcement.title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    announcement.description,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10),
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
    {'text': 'Maka sesungguhnya bersama kesulitan ada kemudahan.', 'source': 'QS. Al-Insyirah: 5'},
    {'text': 'Dan bersabarlah, karena sesungguhnya Allah tidak menyia-nyiakan pahala orang yang berbuat kebaikan.', 'source': 'QS. Hud: 115'},
    {'text': 'Allah tidak membebani seseorang melainkan sesuai dengan kesanggupannya.', 'source': 'QS. Al-Baqarah: 286'},
    {'text': 'Boleh jadi kamu membenci sesuatu, padahal ia amat baik bagimu.', 'source': 'QS. Al-Baqarah: 216'},
    {'text': 'Sesungguhnya Allah beserta orang-orang yang sabar.', 'source': 'QS. Al-Baqarah: 153'},
    {'text': 'Maka nikmat Tuhan kamu yang manakah yang kamu dustakan?', 'source': 'QS. Ar-Rahman: 13'},
    {'text': 'Barangsiapa bertakwa kepada Allah niscaya Dia akan membukakan jalan keluar baginya.', 'source': 'QS. At-Talaq: 2'},
  ];

  Widget _buildDailyQuote(BuildContext context) {
    final int dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
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
          Icon(Icons.format_quote, color: AppColors.primary.withOpacity(0.3), size: 28),
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
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.outline, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SHARED HELPERS ──────────────────────────────────────────────────
  Widget _buildSectionHeader(BuildContext context, String title, String subtitle, {VoidCallback? onTapAction, String? actionLabel}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(subtitle, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10)),
            ],
          ),
        ),
        if (onTapAction != null && actionLabel != null)
          GestureDetector(
            onTap: onTapAction,
            child: Text(actionLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
        child: Text('Memuat $label...', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant)),
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
