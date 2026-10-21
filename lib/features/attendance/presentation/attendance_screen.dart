import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../../../core/widgets/artech_pull_to_refresh.dart';
import '../../../core/widgets/live_clock_widget.dart';
import '../data/attendance_service.dart';
import '../data/models/attendance_models.dart';
import 'attendance_history_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/data/notifications_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Future<Map<String, dynamic>?> _todayFuture;
  late Future<AttendanceHistoryResponse?> _historyResponseFuture;

  List<AttendanceEmployee> _availableEmployees = [];
  int? _selectedEmployeeId;
  String? _selectedEmployeeName;

  DateTime _selectedCalendarMonth = DateTime.now();
  int? _selectedCalendarDay = DateTime.now().day;

  static String _extractTimeStr(dynamic val, {String fallback = '--:--'}) {
    if (val == null) return fallback;
    if (val is String) {
      final s = val.trim();
      return s.isEmpty ? fallback : s;
    }
    if (val is Map) {
      if (val['recorded'] == false) return fallback;
      final possible = val['time'] ?? val['check_in'] ?? val['check_out'] ?? val['jam'] ?? val['formatted_time'];
      if (possible != null) {
        final s = possible.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return fallback;
    }
    final s = val.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted) setState(() {});
    });
    _loadEmployees();
    _refreshData();
    NotificationsService.refreshUnreadCount();
  }

  Future<void> _loadEmployees() async {
    try {
      final emps = await AttendanceService.getEmployees();
      if (mounted && emps.isNotEmpty) {
        setState(() => _availableEmployees = emps);
      }
    } catch (_) {}
  }

  Future<void> _refreshData() async {
    setState(() {
      _todayFuture = AttendanceService.getToday(employeeId: _selectedEmployeeId);
      _historyResponseFuture = AttendanceService.getHistory(
        month: _selectedCalendarMonth.month,
        year: _selectedCalendarMonth.year,
        employeeId: _selectedEmployeeId,
        perPage: 35,
      );
    });
    try {
      await Future.wait([
        _todayFuture,
        _historyResponseFuture,
      ]);
    } catch (_) {}
  }

  void _prevCalendarMonth() {
    setState(() {
      _selectedCalendarMonth = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month - 1, 1);
      _selectedCalendarDay = null;
      _historyResponseFuture = AttendanceService.getHistory(
        month: _selectedCalendarMonth.month,
        year: _selectedCalendarMonth.year,
        employeeId: _selectedEmployeeId,
        perPage: 35,
      );
    });
  }

  void _nextCalendarMonth() {
    setState(() {
      _selectedCalendarMonth = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month + 1, 1);
      _selectedCalendarDay = null;
      _historyResponseFuture = AttendanceService.getHistory(
        month: _selectedCalendarMonth.month,
        year: _selectedCalendarMonth.year,
        employeeId: _selectedEmployeeId,
        perPage: 35,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ArtechPullToRefresh(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMiniHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInteractiveAttendanceCard(context),
                    const SizedBox(height: 20),
                    _buildStatisticsSummary(context),
                    const SizedBox(height: 20),
                    _buildAttendanceCalendarSection(context),
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
                    Row(
                      children: [
                        const Text(
                          'Kehadiran',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                                        backgroundColor: Color(0xFFEF4444),
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
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Pantau jam kerja dan riwayat kehadiran',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                // Employee Filter (Khusus Direksi / HCGA / Superadmin - SCOPE_READ_ALL / SCOPE_MANAGE)
                if (_availableEmployees.length > 1) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        dropdownColor: const Color(0xFF0F2D67),
                        value: _availableEmployees.any((e) => e.id == _selectedEmployeeId) ? _selectedEmployeeId : null,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        hint: const Row(
                          children: [
                            Icon(Icons.person_outline, size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('Presensi Saya Sendiri', style: TextStyle(fontSize: 12, color: Colors.white), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(Icons.person_pin_rounded, size: 16, color: Colors.white),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text('Presensi Saya Sendiri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                          ..._availableEmployees.map((emp) {
                            return DropdownMenuItem<int?>(
                              value: emp.id,
                              child: Text(
                                '${emp.name} (${emp.position})',
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (newId) {
                          setState(() {
                            _selectedEmployeeId = newId;
                            if (newId != null) {
                              _selectedEmployeeName = _availableEmployees.firstWhere((e) => e.id == newId).name;
                            } else {
                              _selectedEmployeeName = null;
                            }
                          });
                          _refreshData();
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tampilan utama: satu status, satu instruksi, dan dua jam presensi.
  Widget _buildInteractiveAttendanceCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF091E47).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _todayFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 46),
              child: Center(child: ArtechLoadingWidget(size: 48, showHalo: false)),
            );
          }
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text('Data presensi belum dapat dimuat. Tarik untuk mencoba lagi.')),
            );
          }

          final data = snapshot.data;
          final checkIn = _formatAttendanceTime(data?['check_in']);
          final checkOut = _formatAttendanceTime(data?['check_out']);
          final hasIn = checkIn != '--:--';
          final hasOut = checkOut != '--:--';
          final rawRequest = data?['approved_request'];
          final request = rawRequest is Map
              ? AttendanceApprovedRequest.fromJson(rawRequest)
              : null;
          final isApproved = request != null ||
              data?['status_source']?.toString().toLowerCase() == 'approved_request';
          final rawStatus = data?['status']?.toString().trim() ?? '';
          final rawBadge = data?['status_badge']?.toString().toLowerCase() ?? '';
          final status = _cleanStatus(
            isApproved
                ? (request?.displayTitle ?? rawStatus)
                : (rawStatus.isEmpty || rawStatus.toLowerCase() == 'belum presensi'
                    ? (hasOut ? 'Presensi Lengkap' : hasIn ? 'Sudah Masuk' : 'Belum Presensi')
                    : rawStatus),
          );
          final statusColor = _getStatusColor(status, rawBadge);
          final statusBg = statusColor.withValues(alpha: 0.1);
          final source = '${data?['source'] ?? ''} ${data?['source_label'] ?? ''}'.toLowerCase();
          final isFingerSpot = source.contains('finger') || source.contains('mesin');
          final schedule = data?['schedule'];
          final target = schedule is Map ? _extractTimeStr(schedule['check_in_target'], fallback: '') : '';
          final targetTime = target.length >= 5 ? target.substring(0, 5) : '';

          final now = DateTime.now();
          final dateText = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);
          final normalizedStatus = isApproved && status.toLowerCase().contains('cuti')
              ? 'Cuti'
              : status;
          final statusIcon = status.toLowerCase().contains('cuti')
              ? Icons.beach_access_rounded
              : status.toLowerCase().contains('izin')
                  ? Icons.event_note_rounded
                  : status.toLowerCase().contains('sakit')
                      ? Icons.medical_services_outlined
                      : status.toLowerCase().contains('dinas')
                          ? Icons.flight_takeoff_rounded
                          : status.toLowerCase().contains('lembur')
                              ? Icons.more_time_rounded
                              : Icons.verified_outlined;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 15, color: statusColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          normalizedStatus,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: LiveClockWidget(
                  timeStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF12346F),
                    letterSpacing: -0.7,
                  ),
                  amPmStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: Color(0xFF64748B), size: 12),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      dateText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isApproved && targetTime.isNotEmpty) ...[
                const SizedBox(height: 7),
                Center(
                  child: Text(
                    'Batas masuk $targetTime WIB',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (isApproved)
                _buildApprovedSummary(request, statusColor)
              else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildAttendanceTime('Masuk', checkIn, hasIn, Icons.login_rounded)),
                          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildAttendanceTime('Pulang', checkOut, hasOut, Icons.logout_rounded)),
                        ],
                      ),
                      if (hasIn && hasOut && _calculateDuration(checkIn, checkOut).isNotEmpty) ...[
                        const Divider(height: 22, color: Color(0xFFE2E8F0)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.timer_outlined, size: 15, color: Color(0xFF64748B)),
                            const SizedBox(width: 7),
                            Flexible(child: Text('Durasi kerja: ${_calculateDuration(checkIn, checkOut)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              if (!isApproved && isFingerSpot && (hasIn || hasOut)) ...[
                const SizedBox(height: 11),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fingerprint, size: 14, color: Color(0xFF64748B)),
                    SizedBox(width: 5),
                    Text('Tercatat melalui FingerSpot', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _formatAttendanceTime(dynamic value) {
    final valueText = _extractTimeStr(value);
    if (valueText == '--:--') return valueText;
    return valueText.length >= 5 ? valueText.substring(0, 5) : valueText;
  }

  String _cleanStatus(String raw) {
    var value = raw.trim()
        .replaceFirst(RegExp(r'^pengajuan\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\(ACC\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(disetujui)(?:\s+disetujui)+\b', caseSensitive: false), 'Disetujui')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (value.isEmpty) value = 'Belum Presensi';
    return value;
  }

  // Tampilan jam masuk/pulang mengikuti kartu pada HomeScreen.
  Widget _buildAttendanceTime(
    String label,
    String time,
    bool recorded,
    IconData icon,
  ) {
    final accent = label == 'Masuk'
        ? const Color(0xFF16A34A)
        : const Color(0xFF4F46E5);
    const muted = Color(0xFF64748B);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: recorded
                ? accent.withValues(alpha: 0.10)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 17,
            color: recorded ? accent : muted,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: recorded ? const Color(0xFF0F172A) : muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Panel pengajuan disetujui mengikuti referensi kartu HomeScreen.
  Widget _buildApprovedSummary(AttendanceApprovedRequest? request, Color color) {
    final number = request?.requestNumber?.trim() ?? '';
    final description = request?.description?.trim() ?? '';
    final period = request?.formattedPeriod?.trim() ?? '';
    const blue = Color(0xFF0037B0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBED0EF), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (number.isNotEmpty) ...[
            _approvedInfo(Icons.receipt_long_rounded, 'No. $number', blue),
            const SizedBox(height: 10),
          ],
          if (period.isNotEmpty) ...[
            _approvedInfo(Icons.calendar_month_outlined, 'Periode: $period', blue),
            const SizedBox(height: 10),
          ],
          if (description.isNotEmpty) ...[
            _approvedInfo(Icons.notes_rounded, description, blue,
                textColor: const Color(0xFF64748B)),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: _approvedInfo(
              Icons.check_circle_outline_rounded,
              'Tidak perlu scan presensi',
              blue,
              bold: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvedInfo(
    IconData icon,
    String value,
    Color accent, {
    bool bold = false,
    Color textColor = const Color(0xFF0F172A),
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            softWrap: true,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              height: 1.35,
              color: textColor,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle, {
    VoidCallback? onTapAction,
    String? actionLabel,
    IconData? actionIcon,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTapAction,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionIcon != null) ...[
                      Icon(actionIcon, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      actionLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatisticsSummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'Ringkasan Presensi',
          DateFormat('MMMM yyyy', 'id_ID').format(_selectedCalendarMonth),
          actionLabel: 'Unduh Rekap',
          actionIcon: Icons.file_download_outlined,
          onTapAction: () => _handleExportCSV(context),
        ),
        const SizedBox(height: 16),
        FutureBuilder<AttendanceHistoryResponse?>(
          future: _historyResponseFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: ArtechLoadingWidget(size: 54, showHalo: false)),
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Ringkasan belum dapat dimuat. Tarik layar untuk mencoba lagi.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              );
            }
            final stats = snapshot.data!.statistics ?? AttendanceStatistics();
            return LayoutBuilder(
              builder: (context, constraints) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: constraints.maxWidth < 350 ? 2 : 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: constraints.maxWidth < 350 ? 1.65 : 1.15,
              children: [
                _buildStatCard(context, 'Hadir', '${stats.hadir}', Icons.check_circle, AppColors.secondary, AppColors.secondaryContainer.withOpacity(0.4)),
                _buildStatCard(context, 'Terlambat', '${stats.terlambat}', Icons.schedule, Colors.orange[700]!, Colors.orange[100]!),
                _buildStatCard(context, 'Cuti / Izin', '${stats.cuti + stats.izin}', Icons.beach_access, AppColors.primary, AppColors.primaryContainer.withOpacity(0.5)),
                _buildStatCard(context, 'Sakit', '${stats.sakit}', Icons.medication, AppColors.onSurfaceVariant, AppColors.surfaceContainerHigh),
                _buildStatCard(context, 'Dinas', '${stats.perjalananDinas}', Icons.flight_takeoff, AppColors.tertiary, AppColors.tertiaryContainer.withOpacity(0.5)),
                _buildStatCard(context, 'Alpha', '${stats.tidakHadir}', Icons.cancel, AppColors.onSurfaceVariant, AppColors.surfaceContainerHigh),
              ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color iconColor, Color iconBg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ],
          ),
          Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: iconColor, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildAttendanceCalendarSection(BuildContext context) {
    return FutureBuilder<AttendanceHistoryResponse?>(
      future: _historyResponseFuture,
      builder: (context, snapshot) {
        final historyList = snapshot.data?.history ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              context,
              'Kalender & Riwayat Presensi',
              'Rincian harian',
              actionLabel: 'Lihat Semua',
              actionIcon: Icons.arrow_forward_rounded,
              onTapAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceHistoryScreen(
                      initialEmployeeId: _selectedEmployeeId,
                      initialEmployeeName: _selectedEmployeeName,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            if (isLoading)
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Center(
                  child: ArtechLoadingWidget(size: 48, message: 'Memuat kalender presensi...'),
                ),
              )
            else ...[
              // 1. Kartu Kalender Bulanan
              _buildMonthlyCalendarCard(historyList),
              const SizedBox(height: 12),

              // 2. Keterangan Titik Presensi (Legend)
              _buildCalendarLegend(),
              const SizedBox(height: 10),

            ],
          ],
        );
      },
    );
  }

  AttendanceHistoryItem? _getItemForDay(List<AttendanceHistoryItem> history, int day) {
    final dayStr = day.toString().padLeft(2, '0');
    final monthStr = _selectedCalendarMonth.month.toString().padLeft(2, '0');
    final targetDate = '${_selectedCalendarMonth.year}-$monthStr-$dayStr';

    for (final item in history) {
      if (item.date == targetDate) return item;
      
    }
    return null;
  }

  bool _isDayToday(int day) {
    final now = DateTime.now();
    return now.year == _selectedCalendarMonth.year &&
        now.month == _selectedCalendarMonth.month &&
        now.day == day;
  }

  Color? _getDotColorForDay(AttendanceHistoryItem? item, int day) {
    final dt = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month, day);
    final now = DateTime.now();

    // Jika hari masa depan dan belum ada catatan presensi
    if (item == null && dt.isAfter(DateTime(now.year, now.month, now.day))) {
      return null;
    }

    if (item == null) {
      if (dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday) {
        return const Color(0xFF94A3B8); // Slate libur
      }
      return null;
    }

    final s = item.status.toLowerCase();
    final cat = (item.lateCategory ?? '').toLowerCase();

    // 1. Libur
    if (item.isWeekend || item.isHoliday || s.contains('libur')) {
      final hasScan = item.checkInTime != null &&
          item.checkInTime!.isNotEmpty &&
          item.checkInTime != '--:--';
      if (!hasScan) return const Color(0xFF94A3B8); // Slate
    }

    // 2. Cuti
    if (s.contains('cuti') || item.approvedRequest?.requestType?.contains('cuti') == true) {
      return AppColors.primary; // Blue
    }

    // 3. Izin
    if (s.contains('izin') || item.approvedRequest?.requestType?.contains('izin') == true) {
      return Colors.orange.shade800; // Brown-orange
    }

    // 4. Sakit
    if (s.contains('sakit') || item.approvedRequest?.requestType?.contains('sakit') == true) {
      return AppColors.error; // Red
    }

    // 5. Perjalanan Dinas
    if (s.contains('dinas') || item.approvedRequest?.requestType?.contains('dinas') == true) {
      return const Color(0xFF7C3AED); // Purple
    }

    // 6. Lembur
    if (s.contains('lembur') || item.approvedRequest?.requestType?.contains('lembur') == true) {
      return const Color(0xFF4F46E5); // Indigo
    }

    // 7. Tidak Hadir / Alpha
    if (s.contains('tidak') || s.contains('alpa') || s.contains('alpha') || cat == 'alpha_candidate') {
      return const Color(0xFFDC2626); // Red
    }

    // 8. Belum Absen Pulang
    if (s.contains('belum')) {
      return const Color(0xFFEA580C); // Orange
    }

    // 9. Terlambat
    if (s.contains('lambat') || item.lateMinutes > 0 || cat == 'late' || cat == 'terlambat' || cat == 'very_late') {
      return const Color(0xFFD97706); // Amber
    }

    // 10. Hadir / Tepat Waktu
    return const Color(0xFF16A34A); // Green
  }

  Color _getStatusColor(String status, String? badge) {
    final s = status.toLowerCase();
    final b = (badge ?? '').toLowerCase();

    if (s.contains('tepat') || (s.contains('hadir') && !s.contains('lambat') && !s.contains('tidak'))) {
      return const Color(0xFF16A34A);
    }
    if (s.contains('lambat') || b.contains('warning')) {
      return const Color(0xFFD97706);
    }
    if (s.contains('belum')) {
      return const Color(0xFFEA580C);
    }
    if (s.contains('cuti') || b.contains('info') || b.contains('primary')) {
      return AppColors.primary;
    }
    if (s.contains('izin')) {
      return Colors.orange.shade800;
    }
    if (s.contains('dinas')) {
      return const Color(0xFF7C3AED);
    }
    if (s.contains('lembur')) {
      return const Color(0xFF4F46E5);
    }
    if (s.contains('tidak') || s.contains('sakit') || s.contains('alpa') || s.contains('alpha') || b.contains('danger') || b.contains('error')) {
      return const Color(0xFFDC2626);
    }
    if (s.contains('libur')) {
      return const Color(0xFF64748B);
    }
    return AppColors.primary;
  }

  Widget _buildMonthlyCalendarCard(List<AttendanceHistoryItem> historyList) {
    final daysInMonth = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month + 1, 0).day;
    final firstDayWeekday = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month, 1).weekday;
    final startOffset = (firstDayWeekday - 1) % 7;
    final totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;
    const weekDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bulan & Navigasi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
                onPressed: _prevCalendarMonth,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(_selectedCalendarMonth),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
                onPressed: _nextCalendarMonth,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Header Hari (Senin - Minggu)
          Row(
            children: List.generate(7, (i) {
              final isWeekend = i >= 5;
              return Expanded(
                child: Center(
                  child: Text(
                    weekDays[i],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isWeekend ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // Grid Tanggal 7 Kolom
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - startOffset + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final item = _getItemForDay(historyList, dayNumber);
              final dotColor = _getDotColorForDay(item, dayNumber);
              final isSelected = _selectedCalendarDay == dayNumber;
              final isToday = _isDayToday(dayNumber);

              return InkWell(
                onTap: () {
                  setState(() => _selectedCalendarDay = dayNumber);
                  final dayDate = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month, dayNumber);
                  _showDayDetailModal(context, item, dayDate);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isToday ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isToday ? AppColors.primary.withValues(alpha: 0.6) : Colors.transparent),
                      width: isToday || isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (index % 7 >= 5 ? const Color(0xFFEF4444) : const Color(0xFF1E293B)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Titik Warna-Warni Status
                        if (dotColor != null)
                          Container(
                            width: 5.5,
                            height: 5.5,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : dotColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 2,
                                  ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(height: 5.5),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.palette_outlined, size: 15, color: AppColors.primary),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Arti Warna Kalender',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendDot(const Color(0xFF16A34A), 'Hadir'),
              _buildLegendDot(const Color(0xFFD97706), 'Terlambat'),
              _buildLegendDot(const Color(0xFFEA580C), 'Belum Pulang'),
              _buildLegendDot(AppColors.primary, 'Cuti'),
              _buildLegendDot(Colors.orange.shade800, 'Izin'),
              _buildLegendDot(const Color(0xFFDC2626), 'Sakit / Alpha'),
              _buildLegendDot(const Color(0xFF7C3AED), 'Dinas'),
              _buildLegendDot(const Color(0xFF4F46E5), 'Lembur'),
              _buildLegendDot(const Color(0xFF94A3B8), 'Hari Libur'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _calculateDuration(String? checkIn, String? checkOut) {
    if (checkIn == null || checkOut == null || checkIn.isEmpty || checkOut.isEmpty || checkIn == '--:--' || checkOut == '--:--') {
      return '';
    }
    try {
      final inParts = checkIn.split(':');
      final outParts = checkOut.split(':');
      if (inParts.length >= 2 && outParts.length >= 2) {
        final inMinutes = int.parse(inParts[0]) * 60 + int.parse(inParts[1]);
        final outMinutes = int.parse(outParts[0]) * 60 + int.parse(outParts[1]);
        final diff = outMinutes - inMinutes;
        if (diff > 0) {
          final hours = diff ~/ 60;
          final mins = diff % 60;
          if (mins == 0) return '$hours jam';
          return '$hours jam $mins mnt';
        }
      }
    } catch (_) {}
    return '';
  }

  void _showDayDetailModal(
    BuildContext context,
    AttendanceHistoryItem? item,
    DateTime dayDate,
  ) {
    final statusColor = item != null
        ? _getStatusColor(item.status, item.statusBadge)
        : (dayDate.weekday >= 6 ? const Color(0xFF94A3B8) : AppColors.primary);
    final isLate = item != null &&
        (item.status.toLowerCase().contains('lambat') || item.lateMinutes > 0);
    final bool hasScan = item != null &&
        ((item.checkInTime != null &&
                item.checkInTime!.isNotEmpty &&
                item.checkInTime != '--:--') ||
            (item.checkOutTime != null &&
                item.checkOutTime!.isNotEmpty &&
                item.checkOutTime != '--:--'));
    final String duration = item != null
        ? _calculateDuration(item.formattedCheckIn, item.formattedCheckOut)
        : '';
    final dateFormatted =
        DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dayDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 12,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header Tanggal & Tombol Tutup
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateFormatted,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 14),

                if (item != null) ...[
                  // Status Badge & Sumber
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _cleanStatus(item.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isFingerSpot)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fingerprint,
                                size: 12,
                                color: Color(0xFF1D4ED8),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'FingerSpot',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (!item.isApprovedRequest && item.sourceLabel != null &&
                          item.sourceLabel!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.sourceLabel!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Pengajuan ACC detail jika ada
                  if (item.isApprovedRequest &&
                      item.approvedRequest?.description?.trim().isNotEmpty == true) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.approvedRequest?.description != null &&
                              item.approvedRequest!.description!.isNotEmpty) ...[
                            Text(
                              item.approvedRequest!.description!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Scan Masuk & Pulang
                  if (hasScan) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          // Masuk
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.login_rounded,
                                      size: 14,
                                      color: Color(0xFF16A34A),
                                    ),
                                    SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Jam Masuk',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    item.checkInTime != null &&
                                            item.checkInTime!.isNotEmpty &&
                                            item.checkInTime != '--:--'
                                        ? '${item.formattedCheckIn} WIB'
                                        : '--:--',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isLate
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: const Color(0xFFE2E8F0),
                          ),
                          // Pulang
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.logout_rounded,
                                        size: 14,
                                        color: Color(0xFFDC2626),
                                      ),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Jam Pulang',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      item.checkOutTime != null &&
                                              item.checkOutTime!.isNotEmpty &&
                                              item.checkOutTime != '--:--'
                                          ? '${item.formattedCheckOut} WIB'
                                          : '--:--',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Durasi
                          if (duration.isNotEmpty) ...[
                            Container(
                              width: 1,
                              height: 36,
                              color: const Color(0xFFE2E8F0),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Durasi',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        duration,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Warning Terlambat
                  if (isLate) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.lateMinutes > 0
                                  ? 'Terlambat ${item.lateMinutes} menit dari jadwal masuk'
                                  : (item.lateLabel ?? 'Terlambat Masuk'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Catatan
                  if (item.notes != null &&
                      item.notes!.trim().isNotEmpty &&
                      item.notes!.trim().toLowerCase() !=
                          (item.approvedRequest?.description ?? '').trim().toLowerCase()) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.notes!.trim().replaceFirst(RegExp(r'^catatan:\s*', caseSensitive: false), ''),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  // Tanggal tanpa catatan
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          dayDate.weekday >= 6
                              ? Icons.weekend_rounded
                              : Icons.event_busy_rounded,
                          size: 38,
                          color: const Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          dayDate.weekday >= 6
                              ? 'Hari Libur Akhir Pekan'
                              : (dayDate.isAfter(DateTime.now())
                                  ? 'Tanggal Mendatang'
                                  : 'Tidak Ada Catatan Presensi'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayDate.weekday >= 6
                              ? 'Tidak ada jadwal presensi wajib pada hari libur.'
                              : (dayDate.isAfter(DateTime.now())
                                  ? 'Presensi belum dibuka untuk tanggal ini.'
                                  : 'Tidak ditemukan rekaman presensi masuk atau pulang.'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Tombol Tutup
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleExportCSV(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Menyiapkan file laporan absensi...')),
    );
    
    final targetMonth = _selectedCalendarMonth.month;
    final targetYear = _selectedCalendarMonth.year;
    final monthName = DateFormat('MMMM yyyy', 'id_ID').format(_selectedCalendarMonth);
    
    String? csvString;
    try {
      csvString = await AttendanceService.exportAttendanceCSV(
        targetMonth,
        targetYear,
        employeeId: _selectedEmployeeId,
      );
    } catch (_) {
      csvString = null;
    }

    if (csvString == null || !context.mounted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunduh laporan. Coba lagi nanti.'), backgroundColor: AppColors.error),
        );
      }
      return;
    }
    
    try {
      final tempDir = await getTemporaryDirectory();
      final empSuffix = _selectedEmployeeName != null ? '_${_selectedEmployeeName!.replaceAll(' ', '_')}' : '';
      final file = File('${tempDir.path}/Rekapan_Absensi_${targetMonth}_$targetYear$empSuffix.csv');
      await file.writeAsString(csvString);
      
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Laporan Absensi Periode $monthName');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan atau membagikan file: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
