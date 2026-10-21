import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_pull_to_refresh.dart';
import '../../../core/widgets/live_clock_widget.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../../auth/data/auth_service.dart';
import '../../attendance/data/attendance_service.dart';
import '../../attendance/data/models/attendance_models.dart';
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
import '../../sop/presentation/sop_list_screen.dart';
import '../../agenda/data/agenda_service.dart';
import '../../agenda/data/models/agenda_models.dart';
import '../../agenda/presentation/agenda_list_screen.dart';
import '../../agenda/presentation/agenda_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const primary = Color(0xFF0037B0);
  static const navy = Color(0xFF0F2D67);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const background = Color(0xFFF8FAFC);

  Map<String, dynamic>? _userData;
  List<Announcement> _announcements = [];
  List<Activity> _activities = [];
  List<AgendaItem> _companyAgendas = [];

  bool _loading = true;
  Future<Map<String, dynamic>?>? _todayFuture;

  @override
  void initState() {
    super.initState();
    _todayFuture = AttendanceService.getToday();
    _loadAll();
    NotificationsService.refreshUnreadCount();
  }

  String _str(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is Map) {
      if (value['recorded'] == false) return fallback;
      value =
          value['time'] ??
          value['jam'] ??
          value['name'] ??
          value['title'] ??
          value['label'] ??
          value['check_in'] ??
          value['check_out'] ??
          value['formatted_time'] ??
          value['created_at'];
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return fallback;
    final match = RegExp(r'^(\d{2}:\d{2}):\d{2}$').firstMatch(text);
    return match?.group(1) ?? text;
  }

  TextStyle _font(
    double size, {
    Color color = ink,
    FontWeight weight = FontWeight.w500,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.35,
    );
  }

  BoxDecoration _decoration({
    Color color = Colors.white,
    double radius = 16,
    bool shadow = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow:
          shadow
              ? [
                BoxShadow(
                  color: navy.withValues(alpha: 0.08),
                  blurRadius: 25,
                  offset: const Offset(0, 8),
                ),
              ]
              : null,
    );
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadUser(), _loadDashboard(), _loadAgenda()]);
  }

  Future<void> _loadUser() async {
    try {
      final result = await AuthService.getUserData();
      if (mounted) {
        setState(() => _userData = result);
      }
    } catch (_) {}
  }

  Future<void> _loadDashboard() async {
    try {
      final result = await DashboardService.getDashboardData();

      if (!mounted) return;

      setState(() {
        if (result['success'] == true) {
          final announcements = result['announcements'];
          final activities = result['activities'];
          final agendas = result['agendas'];

          if (announcements is List<Announcement>) {
            _announcements = announcements;
          }

          if (activities is List<Activity>) {
            _activities = activities;
          }

          if (agendas is List && agendas.isNotEmpty) {
            _companyAgendas =
                agendas
                    .whereType<Map<String, dynamic>>()
                    .map(AgendaItem.fromJson)
                    .toList();
          }
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadAgenda() async {
    try {
      final result = await AgendaService.getAgendas(perPage: 5);
      if (mounted && result.success) {
        setState(() => _companyAgendas = result.items);
      }
    } catch (_) {}
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _todayFuture = AttendanceService.getToday();
    });
    await _loadAll();
    NotificationsService.refreshUnreadCount();
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String _date() {
    final date = DateTime.now();
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
    return '${days[date.weekday - 1]}, '
        '${date.day} ${months[date.month - 1]} '
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: ArtechPullToRefresh(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickAccess(),
                    const SizedBox(height: 26),
                    _buildAgendaSection(),
                    const SizedBox(height: 22),
                    _buildAnnouncements(),
                    const SizedBox(height: 22),
                    _buildQuote(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================
  // HEADER
  // ================================================

  Widget _buildHeader() {
    return Stack(
      children: [
        Positioned.fill(
          bottom: 75,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF091E47), primary, Color(0xFF155DFC)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 22),
                _buildProfile(),
                const SizedBox(height: 22),
                _buildAttendanceCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Image.asset(
                'logo/artech_symbol.png',
                height: 20,
                errorBuilder:
                    (_, __, ___) => const Icon(
                      Icons.business,
                      color: Colors.white,
                      size: 20,
                    ),
              ),
              const SizedBox(width: 9),
              Text(
                'ARQOM ONE',
                style: _font(12, color: Colors.white, weight: FontWeight.w800),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: NotificationsService.unreadCountNotifier,
          builder: (_, count, __) {
            return IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
                NotificationsService.refreshUnreadCount();
              },
              icon: Badge(
                isLabelVisible: count > 0,
                smallSize: 8,
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfile() {
    final employee = _userData?['employee'];

    final name = _str(employee?['name'] ?? _userData?['name'], 'Pengguna');

    final role = _str(
      employee?['position'] ?? _userData?['position'] ?? _userData?['role'],
      'Staff',
    );

    final photo = _str(
      _userData?['profile_photo_url'] ?? employee?['profile_photo_url'],
    );

    final photoUrl =
        photo.isNotEmpty
            ? photo
            : 'https://ui-avatars.com/api/'
                '?name=${Uri.encodeComponent(name)}'
                '&background=0037b0&color=fff';

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.white24,
          backgroundImage: NetworkImage(photoUrl),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_greeting()},', style: _font(12, color: Colors.white70)),
              Text(
                name.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _font(19, color: Colors.white, weight: FontWeight.w800),
              ),
              Text(
                role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _font(11, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================================================
  // PRESENSI - TANPA KETERANGAN DUPLIKAT
  // ================================================

  Widget _buildAttendanceCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _todayFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return Container(
            width: double.infinity,
            height: 180,
            decoration: _decoration(radius: 23, shadow: true),
            child: const Center(
              child: ArtechLoadingWidget(size: 48, showHalo: false),
            ),
          );
        }

        final checkIn = _str(data?['check_in'], '--:--');
        final checkOut = _str(data?['check_out'], '--:--');

        final hasIn = checkIn != '--:--';
        final hasOut = checkOut != '--:--';

        final requestRaw = data?['approved_request'];
        final AttendanceApprovedRequest? request =
            requestRaw is Map
                ? AttendanceApprovedRequest.fromJson(requestRaw)
                : null;

        final isApproved =
            request != null ||
            data?['status_source']?.toString().toLowerCase() ==
                'approved_request';

        final rawStatus = _str(data?['status']);
        final rawBadge = _str(data?['status_badge']).toLowerCase();

        String status;

        if (isApproved) {
          status = request?.displayTitle ?? rawStatus;
          status = status.trim().isEmpty ? 'Pengajuan Disetujui' : status;
        } else if (rawStatus.isNotEmpty &&
            rawStatus.toLowerCase() != 'belum presensi') {
          status = rawStatus;
        } else if (hasOut) {
          status = 'Presensi Lengkap';
        } else if (hasIn) {
          status = 'Sudah Presensi Masuk';
        } else {
          status = 'Belum Presensi';
        }

        // Hapus awalan berulang dan ACC di judul.
        status =
            status
                .replaceAll(RegExp(r'^pengajuan\s+', caseSensitive: false), '')
                .replaceAll(RegExp(r'\s*\(ACC\)', caseSensitive: false), '')
                .trim();

        final lower = status.toLowerCase();

        Color statusColor;
        Color statusBg;
        IconData statusIcon;

        if (lower.contains('cuti')) {
          statusColor = primary;
          statusBg = const Color(0xFFEFF6FF);
          statusIcon = Icons.beach_access_rounded;
        } else if (lower.contains('izin')) {
          statusColor = const Color(0xFFD97706);
          statusBg = const Color(0xFFFFF7ED);
          statusIcon = Icons.event_busy_rounded;
        } else if (lower.contains('sakit')) {
          statusColor = const Color(0xFFDC2626);
          statusBg = const Color(0xFFFEF2F2);
          statusIcon = Icons.medical_services_rounded;
        } else if (lower.contains('dinas')) {
          statusColor = const Color(0xFF7C3AED);
          statusBg = const Color(0xFFF5F3FF);
          statusIcon = Icons.flight_takeoff_rounded;
        } else if (lower.contains('lembur')) {
          statusColor = const Color(0xFF4F46E5);
          statusBg = const Color(0xFFEEF2FF);
          statusIcon = Icons.more_time_rounded;
        } else if (hasOut ||
            lower.contains('lengkap') ||
            rawBadge == 'success' ||
            lower.contains('hadir')) {
          statusColor = const Color(0xFF16A34A);
          statusBg = const Color(0xFFDCFCE7);
          statusIcon = Icons.check_circle_rounded;
        } else if (hasIn) {
          statusColor = const Color(0xFF16A34A);
          statusBg = const Color(0xFFDCFCE7);
          statusIcon = Icons.check_circle_outline_rounded;
        } else if (rawBadge == 'error' || lower.contains('tidak hadir')) {
          statusColor = const Color(0xFFDC2626);
          statusBg = const Color(0xFFFEF2F2);
          statusIcon = Icons.cancel_rounded;
        } else {
          statusColor = const Color(0xFFD97706);
          statusBg = const Color(0xFFFEF3C7);
          statusIcon = Icons.pending_actions_rounded;
        }

        final source = _str(data?['source']).toLowerCase();
        final sourceLabel = _str(data?['source_label']).toLowerCase();

        final isFingerSpot =
            source.contains('finger') ||
            sourceLabel.contains('finger') ||
            sourceLabel.contains('mesin');

        final schedule = data?['schedule'];
        final target = schedule is Map ? _str(schedule['check_in_target']) : '';

        final targetText =
            target.length >= 5 ? 'Batas ${target.substring(0, 5)}' : null;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: _decoration(radius: 24, shadow: true),
          child: Column(
            children: [
              // Status ditampilkan hanya satu kali.
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 15),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _font(
                                11,
                                color: statusColor,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isApproved && targetText != null) ...[
                    const SizedBox(width: 8),
                    const Spacer(),
                    Text(
                      targetText,
                      style: _font(10, color: muted, weight: FontWeight.w600),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 18),

              LiveClockWidget(
                timeStyle: _font(34, color: navy, weight: FontWeight.w800),
                amPmStyle: _font(12, color: muted, weight: FontWeight.w600),
              ),

              const SizedBox(height: 5),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: muted,
                  ),
                  const SizedBox(width: 6),
                  Text(_date(), style: _font(11, color: muted)),
                ],
              ),

              const SizedBox(height: 18),

              if (isApproved)
                _buildApprovedDetail(request, statusColor, statusBg)
              else
                _buildAttendanceTimes(checkIn, checkOut, hasIn, hasOut),

              if (!isApproved && isFingerSpot) ...[
                const SizedBox(height: 11),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.fingerprint_rounded,
                      size: 14,
                      color: muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Tercatat melalui FingerSpot',
                      style: _font(10, color: muted),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ================================================
  // INFORMASI PENGAJUAN ACC
  // ================================================

  Widget _buildApprovedDetail(
    AttendanceApprovedRequest? request,
    Color color,
    Color bg,
  ) {
    final number = request?.requestNumber?.trim() ?? '';
    final description = request?.description?.trim() ?? '';
    final period = request?.formattedPeriod ?? '';

    final startDate = request?.startDate;
    final endDate = request?.endDate;

    final periodText =
        period.isEmpty
            ? ''
            : startDate == endDate
            ? 'Tanggal: $startDate'
            : 'Periode: $period';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (number.isNotEmpty)
            _infoRow(Icons.receipt_long_rounded, 'No. $number', color),

          if (periodText.isNotEmpty) ...[
            if (number.isNotEmpty) const SizedBox(height: 10),
            _infoRow(Icons.date_range_rounded, periodText, color),
          ],

          if (description.isNotEmpty) ...[
            if (number.isNotEmpty || periodText.isNotEmpty)
              const SizedBox(height: 10),
            _infoRow(Icons.notes_rounded, description, color, textColor: muted),
          ],

          if (number.isNotEmpty ||
              periodText.isNotEmpty ||
              description.isNotEmpty)
            const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _infoRow(
              Icons.check_circle_outline_rounded,
              'Tidak perlu scan presensi',
              color,
              bold: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String text,
    Color accent, {
    Color textColor = ink,
    bool bold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: _font(
              11,
              color: textColor,
              weight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ================================================
  // JAM MASUK DAN PULANG
  // ================================================

  Widget _buildAttendanceTimes(
    String checkIn,
    String checkOut,
    bool hasIn,
    bool hasOut,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _timeItem(
              Icons.login_rounded,
              'Masuk',
              checkIn,
              hasIn,
              const Color(0xFF16A34A),
            ),
          ),
          Container(height: 32, width: 1, color: border),
          const SizedBox(width: 12),
          Expanded(
            child: _timeItem(
              Icons.logout_rounded,
              'Pulang',
              checkOut,
              hasOut,
              const Color(0xFF4F46E5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeItem(
    IconData icon,
    String label,
    String time,
    bool recorded,
    Color accent,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color:
                recorded
                    ? accent.withValues(alpha: 0.1)
                    : border.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: recorded ? accent : muted),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _font(10, color: muted)),
              const SizedBox(height: 2),
              Text(
                time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _font(
                  13.5,
                  color: recorded ? ink : muted,
                  weight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================================================
  // AKSES CEPAT
  // ================================================

  Widget _buildQuickAccess() {
    final items = <_QuickItem>[
      _QuickItem(
        Icons.history_toggle_off_rounded,
        'Kehadiran',
        () => widget.onNavigateTab?.call(1),
      ),
      _QuickItem(
        Icons.event_available_rounded,
        'Pengajuan',
        () => widget.onNavigateTab?.call(3),
      ),
      _QuickItem(
        Icons.beach_access_rounded,
        'Cuti',
        () => _open(const CutiTahunanScreen()),
      ),
      _QuickItem(
        Icons.assignment_turned_in_rounded,
        'Izin',
        () => _open(const IzinScreen()),
      ),
      _QuickItem(
        Icons.medical_services_outlined,
        'Sakit',
        () => _open(const SakitScreen()),
      ),
      _QuickItem(
        Icons.flight_takeoff_rounded,
        'Dinas Luar',
        () => _open(const DinasLuarScreen()),
      ),
      _QuickItem(
        Icons.more_time_rounded,
        'Lembur',
        () => _open(const KerjaLemburScreen()),
      ),
      _QuickItem(
        Icons.auto_stories_rounded,
        "Al-Ma'tsurat",
        () => _open(const AlmatsuratScreen()),
      ),
      _QuickItem(
        Icons.menu_book_rounded,
        'SOP',
        () => _open(const SopListScreen()),
      ),
      _QuickItem(
        Icons.event_note_rounded,
        'Agenda',
        () => _open(const AgendaListScreen()),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Akses Cepat'),
        const SizedBox(height: 13),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            mainAxisExtent: 83,
          ),
          itemBuilder: (_, index) {
            final item = items[index];
            return InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item.icon, color: primary, size: 21),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: _font(10, weight: FontWeight.w600),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ================================================
  // AGENDA
  // ================================================

  Widget _buildAgendaSection() {
    if (_loading && _companyAgendas.isEmpty && _activities.isEmpty) {
      return _loadingCard('Agenda');
    }

    if (_companyAgendas.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Agenda Perusahaan',
            action: 'Lihat Semua',
            onTap: () => _open(const AgendaListScreen()),
          ),
          const SizedBox(height: 12),
          ..._companyAgendas.take(3).map(_companyAgendaItem),
        ],
      );
    }

    if (_activities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Agenda Mendatang',
          action: 'Lihat Semua',
          onTap: () => _open(const AgendaListScreen()),
        ),
        const SizedBox(height: 12),
        ..._activities.take(3).map(_activityItem),
      ],
    );
  }

  Widget _companyAgendaItem(AgendaItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap:
            () =>
                _open(AgendaDetailScreen(agendaId: item.id, initialItem: item)),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _decoration(),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: item.typeColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(item.typeIcon, size: 12, color: item.typeColor),
                        const SizedBox(width: 5),
                        Text(
                          item.type,
                          style: _font(
                            10,
                            color: item.typeColor,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _font(12.5, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.formattedDateRange} · '
                      '${item.formattedTimeRange}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _font(10, color: muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityItem(Activity activity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _decoration(),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 37,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _font(12.5, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${activity.location} · ${activity.pic}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _font(10, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              activity.activityDate.length >= 10
                  ? activity.activityDate.substring(5, 10).replaceAll('-', '/')
                  : activity.activityDate,
              style: _font(10, color: primary, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // PENGUMUMAN
  // ================================================

  Widget _buildAnnouncements() {
    if (_loading || _announcements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Pengumuman'),
        const SizedBox(height: 12),
        ..._announcements.take(3).map(_announcementItem),
      ],
    );
  }

  Widget _announcementItem(Announcement announcement) {
    final urgent = announcement.priority.toLowerCase() == 'urgent';
    final accent = urgent ? const Color(0xFFDC2626) : primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _decoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                urgent ? Icons.warning_amber_rounded : Icons.campaign_outlined,
                color: accent,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    announcement.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _font(12.5, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    announcement.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _font(10.5, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================
  // KUTIPAN HARIAN
  // ================================================

  static const _quotes = [
    [
      'Maka sesungguhnya bersama kesulitan ada kemudahan.',
      'QS. Al-Insyirah: 5',
    ],
    [
      'Dan bersabarlah, karena sesungguhnya Allah tidak menyia-nyiakan pahala orang yang berbuat kebaikan.',
      'QS. Hud: 115',
    ],
    [
      'Allah tidak membebani seseorang melainkan sesuai dengan kesanggupannya.',
      'QS. Al-Baqarah: 286',
    ],
    [
      'Boleh jadi kamu membenci sesuatu, padahal ia amat baik bagimu.',
      'QS. Al-Baqarah: 216',
    ],
    [
      'Sesungguhnya Allah beserta orang-orang yang sabar.',
      'QS. Al-Baqarah: 153',
    ],
    [
      'Maka nikmat Tuhan kamu yang manakah yang kamu dustakan?',
      'QS. Ar-Rahman: 13',
    ],
    [
      'Barangsiapa bertakwa kepada Allah niscaya Dia akan membukakan jalan keluar baginya.',
      'QS. At-Talaq: 2',
    ],
  ];

  Widget _buildQuote() {
    final now = DateTime.now();
    final day = now.difference(DateTime(now.year, 1, 1)).inDays;
    final quote = _quotes[day % _quotes.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, color: primary, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote[0],
                  style: _font(
                    11,
                    color: muted,
                  ).copyWith(fontStyle: FontStyle.italic, height: 1.6),
                ),
                const SizedBox(height: 7),
                Text(
                  '— ${quote[1]}',
                  style: _font(10, color: primary, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================
  // KOMPONEN UMUM
  // ================================================

  Widget _sectionTitle(String title, {String? action, VoidCallback? onTap}) {
    return Row(
      children: [
        Expanded(child: Text(title, style: _font(15, weight: FontWeight.w800))),
        if (action != null && onTap != null)
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  Text(
                    action,
                    style: _font(11, color: primary, weight: FontWeight.w700),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: primary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _loadingCard(String label) {
    return Container(
      height: 75,
      decoration: _decoration(),
      child: Center(
        child: Text('Memuat $label...', style: _font(11, color: muted)),
      ),
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickItem(this.icon, this.label, this.onTap);
}
