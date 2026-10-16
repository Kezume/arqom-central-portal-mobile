import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
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
  late Future<Position> _positionFuture;
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

  Future<void> _refreshData() async {
    setState(() {
      _todayFuture = AttendanceService.getToday(employeeId: _selectedEmployeeId);
      if (AttendanceService.isMapVisible) {
        _positionFuture = Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      } else {
        _positionFuture = Future.value(Position(
          longitude: 110.373963,
          latitude: -7.832365,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ));
      }
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
      final daysInMonth = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month + 1, 0).day;
      _selectedCalendarDay = (_selectedCalendarDay ?? 1).clamp(1, daysInMonth);
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
      final daysInMonth = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month + 1, 0).day;
      _selectedCalendarDay = (_selectedCalendarDay ?? 1).clamp(1, daysInMonth);
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
                    const SizedBox(height: 16),
                    _buildAttendanceActions(context),
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Live Presensi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
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
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            tooltip: 'Unduh Rekap Presensi',
                            icon: const Icon(
                              Icons.file_download_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => _handleExportCSV(context),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                  'Kelola presensi, riwayat kehadiran, dan jadwal kerja',
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

  Widget _buildInteractiveAttendanceCard(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          FutureBuilder<Map<String, dynamic>?>(
        future: _todayFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final String checkIn = _extractTimeStr(data?['check_in']);
          final String checkOut = _extractTimeStr(data?['check_out']);
          
          final String checkInTime = checkIn != '--:--' && checkIn.length >= 5 ? checkIn.substring(0, 5) : checkIn;
          final String checkOutTime = checkOut != '--:--' && checkOut.length >= 5 ? checkOut.substring(0, 5) : checkOut;
          final bool isCheckedIn = checkInTime != '--:--';
          final bool isCheckedOut = checkOutTime != '--:--';

          final rawStatus = data?['status']?.toString();
          final rawBadge = data?['status_badge']?.toString().toLowerCase();
          final approvedRequest = data?['approved_request'] is Map
              ? AttendanceApprovedRequest.fromJson(data!['approved_request'])
              : null;
          final bool isApprovedRequest =
              (data?['status_source']?.toString().toLowerCase() == 'approved_request') ||
                  approvedRequest != null;

          final String statusText;
          final Color statusColor;
          final Color statusBg;

          if (rawStatus != null && rawStatus.isNotEmpty && rawStatus.toLowerCase() != 'belum presensi') {
            statusText = rawStatus;
            final sLower = rawStatus.toLowerCase();
            if (sLower.contains('cuti')) {
              statusColor = AppColors.primary;
              statusBg = const Color(0xFFEFF6FF);
            } else if (sLower.contains('izin')) {
              statusColor = Colors.orange.shade800;
              statusBg = const Color(0xFFFFF7ED);
            } else if (sLower.contains('sakit')) {
              statusColor = AppColors.error;
              statusBg = const Color(0xFFFEF2F2);
            } else if (sLower.contains('lembur')) {
              statusColor = const Color(0xFF4F46E5);
              statusBg = const Color(0xFFEEF2FF);
            } else if (sLower.contains('dinas')) {
              statusColor = const Color(0xFF7C3AED);
              statusBg = const Color(0xFFF5F3FF);
            } else if (rawBadge == 'success' || sLower.contains('hadir') || sLower.contains('lengkap')) {
              statusColor = const Color(0xFF16A34A);
              statusBg = const Color(0xFFDCFCE7);
            } else if (rawBadge == 'warning' || sLower.contains('lambat')) {
              statusColor = const Color(0xFFD97706);
              statusBg = const Color(0xFFFEF3C7);
            } else if (rawBadge == 'error' || sLower.contains('tidak') || sLower.contains('alpa')) {
              statusColor = const Color(0xFFDC2626);
              statusBg = const Color(0xFFFEE2E2);
            } else {
              statusColor = const Color(0xFF0D9488);
              statusBg = const Color(0xFFCCFBF1);
            }
          } else if (isCheckedOut) {
            statusText = 'Presensi Lengkap';
            statusColor = const Color(0xFF0D9488);
            statusBg = const Color(0xFFCCFBF1);
          } else if (isCheckedIn) {
            statusText = 'Sudah Presensi Masuk';
            statusColor = const Color(0xFF16A34A);
            statusBg = const Color(0xFFDCFCE7);
          } else {
            statusText = 'Belum Presensi';
            statusColor = const Color(0xFFD97706);
            statusBg = const Color(0xFFFEF3C7);
          }

          final sourceLabel = data?['source_label']?.toString();
          final isFingerSpot = (data?['source'] ?? '').toString().toLowerCase().contains('finger') ||
              (sourceLabel ?? '').toLowerCase().contains('mesin');

          final rawTarget = data?['schedule']?['check_in_target']?.toString();
          final shiftText = (rawTarget != null && rawTarget.length >= 5)
              ? 'Batas Masuk: ${rawTarget.substring(0, 5)} WIB • Pulang: 17:00 WIB'
              : 'Shift Normal: 08:00 - 17:00 WIB';

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              statusText,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isApprovedRequest) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.assignment_turned_in_rounded, size: 10, color: statusColor),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Pengajuan ACC',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (isFingerSpot) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fingerprint, size: 10, color: statusColor),
                                  const SizedBox(width: 2),
                                  Text(
                                    'FingerSpot',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 13, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        DateFormat('d MMM yyyy', 'id_ID').format(DateTime.now()),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LiveClockWidget(
                timeStyle: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                amPmStyle: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Flexible(child: Text(shiftText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildAttendanceMetric(context, 'Jam Masuk', checkInTime, checkInTime != '--:--' ? 'Tercatat' : 'Belum Masuk', AppColors.primary, AppColors.secondary)),
                    Container(width: 1, height: 40, color: AppColors.outlineVariant.withOpacity(0.5)),
                    Expanded(child: _buildAttendanceMetric(context, 'Jam Pulang', checkOutTime, checkOutTime != '--:--' ? 'Selesai' : 'Belum Checkout', AppColors.onSurfaceVariant, AppColors.outline)),
                    Container(width: 1, height: 40, color: AppColors.outlineVariant.withOpacity(0.5)),
                    Expanded(child: _buildAttendanceMetric(context, 'Status', statusText, isFingerSpot ? 'FingerSpot' : 'Mobile', AppColors.onSurface, statusColor, showUnit: false)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
          if (AttendanceService.isMapVisible) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mesin Indonesia(PT Arqom Technology Innovation)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('Yogyakarta, Indonesia', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.secondaryContainer.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.radar, size: 12, color: AppColors.secondary),
                            const SizedBox(width: 4),
                            Text('Valid', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.secondary, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 150,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                    ),
                    child: Stack(
                      children: [
                        FutureBuilder<Position>(
                          future: _positionFuture,
                          builder: (context, snapshot) {
                            final LatLng officeLocation = const LatLng(-7.832365, 110.373963);
                            List<Marker> markers = [
                              Marker(
                                point: officeLocation,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.business, color: AppColors.primary, size: 40),
                              ),
                            ];

                            if (snapshot.hasData) {
                              markers.add(
                                Marker(
                                  point: LatLng(snapshot.data!.latitude, snapshot.data!.longitude),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.person_pin_circle, color: AppColors.error, size: 40),
                                ),
                              );
                            }

                            return FlutterMap(
                              options: MapOptions(
                                initialCenter: officeLocation,
                                initialZoom: 16.5,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.arqom.mobile',
                                ),
                                CircleLayer(
                                  circles: [
                                    CircleMarker(
                                      point: officeLocation,
                                      radius: 100, // Radius absensi 100 meter
                                      useRadiusInMeter: true,
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderColor: AppColors.primary,
                                      borderStrokeWidth: 2,
                                    ),
                                  ],
                                ),
                                MarkerLayer(markers: markers),
                              ],
                            );
                          }
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              children: [
                                const Icon(Icons.my_location, size: 12, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text('Radius Absensi: 100 meter', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: AppColors.onSurface)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceMetric(BuildContext context, String label, String value, String status, Color valueColor, Color statusColor, {bool isDuration = false, bool showUnit = true}) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value, 
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: valueColor, 
                  fontWeight: FontWeight.bold,
                  fontSize: showUnit ? null : 13,
                ), 
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (!isDuration && showUnit) ...[
              const SizedBox(width: 2),
              Text('WIB', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, fontWeight: FontWeight.normal, color: valueColor)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(status, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10, color: statusColor), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Future<void> _handlePresensiAction(bool isCheckIn) async {
    if (!AttendanceService.isSelfieAttendanceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Presensi kamera selfie sementara dinonaktifkan karena sudah terhubung ke mesin absensi (FingerSpot).',
            ),
            backgroundColor: Color(0xFF0037B0),
          ),
        );
      }
      return;
    }

    File? photo = await _takePhoto();
    if (photo == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto selfie wajib diambil untuk absen ${isCheckIn ? "masuk" : "pulang"}.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Memproses presensi ${isCheckIn ? "masuk" : "pulang"}...')),
      );
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Presensi diproses'),
            backgroundColor: result['success'] == true ? const Color(0xFF16A34A) : AppColors.error,
          ),
        );
        if (result['success'] == true) {
          _refreshData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mendapatkan lokasi GPS. Pastikan GPS menyala dan izin diberikan.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildAttendanceActions(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _todayFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final String checkIn = _extractTimeStr(data?['check_in']);
        final String checkOut = _extractTimeStr(data?['check_out']);
        final bool isCheckedIn = checkIn != '--:--';
        final bool isCheckedOut = checkOut != '--:--';

        final rawStatus = data?['status']?.toString();
        final approvedRequest = data?['approved_request'] is Map
            ? AttendanceApprovedRequest.fromJson(data!['approved_request'])
            : null;
        final bool isApprovedRequest =
            (data?['status_source']?.toString().toLowerCase() == 'approved_request') ||
                approvedRequest != null;

        if (isApprovedRequest) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status Hari Ini: ${rawStatus ?? "Pengajuan Disetujui"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Pengajuan resmi telah disetujui. Bebas dari kewajiban presensi hari ini.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (isCheckedIn && isCheckedOut) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
                SizedBox(width: 8),
                Text(
                  'Presensi Hari Ini Selesai',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF166534),
                  ),
                ),
              ],
            ),
          );
        }

        if (!AttendanceService.isSelfieAttendanceEnabled) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0037B0).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: Color(0xFF0037B0),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Presensi Mesin FingerSpot',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Aktif',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isCheckedIn
                            ? 'Jam masuk sudah tercatat ($checkIn WIB). Silakan scan pada mesin saat jam pulang kerja.'
                            : 'Perekaman presensi masuk dan pulang otomatis terhubung ke mesin absensi kantor.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (!isCheckedIn) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0037B0), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0037B0).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _handlePresensiAction(true),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Presensi Masuk Kerja',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ketuk tombol di atas untuk absen masuk (Selfie & GPS)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          );
        }

        // isCheckedIn && !isCheckedOut
        final bool isCheckoutTime = DateTime.now().hour >= 17;
        return Column(
          children: [
            Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCheckoutTime
                      ? [const Color(0xFFE11D48), const Color(0xFFF43F5E)]
                      : [const Color(0xFFCBD5E1), const Color(0xFF94A3B8)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isCheckoutTime
                    ? [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: isCheckoutTime
                      ? () => _handlePresensiAction(false)
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Belum waktunya pulang. Presensi pulang dapat dilakukan mulai pukul 17:00 WIB.'),
                            ),
                          );
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCheckoutTime ? Icons.logout_rounded : Icons.lock_clock_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isCheckoutTime ? 'Presensi Pulang Kerja' : 'Presensi Pulang (17:00 WIB)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isCheckoutTime
                  ? 'Ketuk tombol di atas untuk presensi pulang'
                  : 'Presensi pulang dibuka setelah pukul 17:00 WIB',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
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
          'Bulan Ini',
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
            final stats = snapshot.data?.statistics ?? AttendanceStatistics();
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildStatCard(context, 'Tepat Waktu', '${stats.hadir}', Icons.check_circle, AppColors.secondary, AppColors.secondaryContainer.withOpacity(0.4)),
                _buildStatCard(context, 'Terlambat', '${stats.terlambat}', Icons.schedule, Colors.orange[700]!, Colors.orange[100]!),
                _buildStatCard(context, 'Cuti / Izin', '${stats.cuti + stats.izin}', Icons.beach_access, AppColors.primary, AppColors.primaryContainer.withOpacity(0.5)),
                _buildStatCard(context, 'Sakit', '${stats.sakit}', Icons.medication, AppColors.onSurfaceVariant, AppColors.surfaceContainerHigh),
                _buildStatCard(context, 'Dinas', '${stats.perjalananDinas}', Icons.flight_takeoff, AppColors.tertiary, AppColors.tertiaryContainer.withOpacity(0.5)),
                _buildStatCard(context, 'Alpha', '${stats.tidakHadir}', Icons.cancel, AppColors.onSurfaceVariant, AppColors.surfaceContainerHigh),
              ],
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: iconColor, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text('Hari', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10)),
            ],
          ),
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
              DateFormat('MMMM yyyy', 'id_ID').format(_selectedCalendarMonth),
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

              // 3. Info Hint Ketuk Tanggal
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Ketuk tanggal untuk melihat rincian kehadiran',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF94A3B8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
      if (item.date.endsWith('-$dayStr') && item.date.startsWith('${_selectedCalendarMonth.year}-')) {
        return item;
      }
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
    if (item == null && dt.isAfter(now)) {
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
                  _showDayDetailModal(context, item, dayNumber, dayDate);
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
                  'Keterangan Titik Presensi',
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
              _buildLegendDot(const Color(0xFF7C3AED), 'Dinas / Lembur'),
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
    int dayNumber,
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
                          const SizedBox(height: 2),
                          Text(
                            'Tanggal $dayNumber',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
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
                          item.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isApprovedRequest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 12,
                                color: Color(0xFF15803D),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Pengajuan ACC',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (item.isFingerSpot)
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
                      else if (item.sourceLabel != null &&
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
                  if (item.isApprovedRequest) ...[
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
                          Row(
                            children: [
                              const Icon(
                                Icons.assignment_turned_in_rounded,
                                size: 15,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.approvedRequest?.typeLabel ?? item.status,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF166534),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (item.approvedRequest?.description != null &&
                              item.approvedRequest!.description!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Alasan: ${item.approvedRequest!.description}',
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
                  if (item.notes != null && item.notes!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Catatan: ${item.notes}',
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
    
    final csvString = await AttendanceService.exportAttendanceCSV(
      targetMonth,
      targetYear,
      employeeId: _selectedEmployeeId,
    );
    
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
