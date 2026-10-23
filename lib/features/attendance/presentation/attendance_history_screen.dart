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
import '../data/attendance_service.dart';
import '../data/models/attendance_models.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/data/notifications_service.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final int? initialEmployeeId;
  final String? initialEmployeeName;

  const AttendanceHistoryScreen({
    super.key,
    this.initialEmployeeId,
    this.initialEmployeeName,
  });

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;
  AttendanceHistoryResponse? _historyData;
  AttendanceStatistics? _overallStatistics;
  List<AttendanceHistoryItem> _allHistory = [];
  String? _errorMessage;
  int? _selectedCalendarDay;

  // Filters
  String _selectedStatus = 'Semua';
  final List<String> _statusFilters = [
    'Semua',
    'Hadir',
    'Tepat Waktu',
    'Terlambat',
    'Belum Absen Pulang',
    'Izin',
    'Sakit',
    'Cuti',
    'Perjalanan Dinas',
    'Lembur',
    'Tidak Hadir',
    'Hari Libur',
  ];

  // Atasan / HCGA team member selector
  List<AttendanceEmployee> _availableEmployees = [];
  int? _selectedEmployeeId;
  String? _selectedEmployeeName;

  @override
  void initState() {
    super.initState();
    _selectedEmployeeId = widget.initialEmployeeId;
    _selectedEmployeeName = widget.initialEmployeeName;

    final now = DateTime.now();
    if (now.year == _selectedMonth.year && now.month == _selectedMonth.month) {
      _selectedCalendarDay = now.day;
    } else {
      _selectedCalendarDay = 1;
    }

    initializeDateFormatting('id_ID', null).then((_) {
      _loadEmployees();
      _fetchData();
    });
  }

  Future<void> _loadEmployees() async {
    try {
      final employees = await AttendanceService.getEmployees();
      if (mounted) {
        setState(() {
          _availableEmployees = employees;
          // Only maintain selected employee if there are multiple employees to choose from
          if (employees.length > 1 &&
              _selectedEmployeeId != null &&
              _selectedEmployeeName == null) {
            final match = employees.firstWhere(
              (e) => e.id == _selectedEmployeeId,
              orElse: () => employees.first,
            );
            _selectedEmployeeName = match.name;
          } else if (employees.length <= 1) {
            _selectedEmployeeId = null;
            _selectedEmployeeName = null;
          }
        });
      }
    } catch (_) {}
  }

  /// Selalu ambil keseluruhan data sebulan penuh tanpa filter status ke API,
  /// sehingga statistik bulanan yang dihitung server selalu akurat & lengkap (Semua).
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AttendanceService.getHistory(
        month: _selectedMonth.month,
        year: _selectedMonth.year,
        employeeId: _selectedEmployeeId,
        status: null, // Tanpa filter status agar statistik utuh 1 bulan
        perPage: 35,
      );

      if (mounted) {
        setState(() {
          _historyData = res;
          _overallStatistics = res?.statistics;
          _allHistory = res?.history ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyData = null;
          _overallStatistics = null;
          _allHistory = [];
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  /// Memfilter data riwayat presensi harian secara lokal berdasarkan chip yang dipilih,
  /// tanpa merusak atau mereset kartu statistik bulanan utama.
  bool _matchesStatus(AttendanceHistoryItem item, String filter) {
    if (filter == 'Semua') return true;
    final f = filter.toLowerCase().trim();
    final s = item.status.toLowerCase().trim();
    final b = item.statusBadge.toLowerCase().trim();
    final cat = (item.lateCategory ?? '').toLowerCase().trim();
    final reqType =
        item.approvedRequest?.requestType?.toLowerCase().trim() ?? '';
    final reqLabel =
        item.approvedRequest?.typeLabel?.toLowerCase().trim() ?? '';

    final bool isLate =
        s.contains('lambat') ||
        item.lateMinutes > 0 ||
        cat == 'late' ||
        cat == 'terlambat' ||
        cat == 'very_late' ||
        cat == 'alpha_candidate';

    final bool isPendingCheckOut = s.contains('belum');

    final bool isAbsent =
        s.contains('tidak') || s.contains('alpa') || s.contains('alpha');

    final bool isLeave =
        item.isApprovedRequest ||
        s.contains('cuti') ||
        s.contains('izin') ||
        s.contains('sakit') ||
        s.contains('dinas') ||
        s.contains('lembur');

    final bool isHoliday =
        item.isWeekend || item.isHoliday || s.contains('libur');

    final bool hasCheckIn =
        item.checkInTime != null &&
        item.checkInTime!.isNotEmpty &&
        item.checkInTime != '--:--';

    // 1. HADIR (Semua kehadiran kerja: Tepat Waktu, Terlambat, maupun Belum Absen Pulang)
    // Terlambat tetap termasuk hadir karena karyawan masuk kerja
    if (f == 'hadir') {
      if (isAbsent) return false;
      if (isLeave) return false;
      if (isHoliday && !hasCheckIn) return false;

      return s == 'hadir' ||
          s.contains('hadir') ||
          s.contains('tepat') ||
          isLate ||
          isPendingCheckOut ||
          hasCheckIn ||
          b == 'success';
    }

    // 2. TEPAT WAKTU (Khusus yang hadir tepat waktu murni)
    if (f == 'tepat waktu') {
      if (isAbsent || isLeave || isHoliday || isLate || isPendingCheckOut) {
        return false;
      }
      return s == 'hadir' || s.contains('tepat') || b == 'success';
    }

    // 3. TERLAMBAT (Khusus yang datang terlambat)
    if (f == 'terlambat') {
      if (isAbsent || isHoliday) return false;
      if (item.isApprovedRequest && !isLate) return false;
      return isLate;
    }

    // 4. BELUM ABSEN PULANG (Khusus yang belum scan pulang)
    if (f.contains('belum')) {
      return isPendingCheckOut;
    }

    // 5. IZIN
    if (f == 'izin') {
      return (s.contains('izin') ||
              reqType.contains('izin') ||
              reqLabel.contains('izin')) &&
          !s.contains('sakit');
    }

    // 6. SAKIT
    if (f == 'sakit') {
      return s.contains('sakit') ||
          reqType.contains('sakit') ||
          reqLabel.contains('sakit');
    }

    // 7. CUTI
    if (f == 'cuti') {
      return s.contains('cuti') ||
          reqType.contains('cuti') ||
          reqLabel.contains('cuti');
    }

    // 8. PERJALANAN DINAS
    if (f.contains('dinas')) {
      return s.contains('dinas') ||
          reqType.contains('dinas') ||
          reqLabel.contains('dinas');
    }

    // 9. LEMBUR
    if (f == 'lembur') {
      return s.contains('lembur') ||
          reqType.contains('lembur') ||
          reqLabel.contains('lembur');
    }

    // 10. TIDAK HADIR / ALPHA
    if (f.contains('tidak') || f.contains('alpha') || f.contains('alpa')) {
      return isAbsent || cat == 'alpha_candidate';
    }

    // 11. HARI LIBUR
    if (f.contains('libur')) {
      return isHoliday;
    }

    return s.contains(f) || reqLabel.contains(f);
  }

  List<AttendanceHistoryItem> get _filteredHistory {
    if (_selectedStatus == 'Semua') return _allHistory;
    return _allHistory
        .where((item) => _matchesStatus(item, _selectedStatus))
        .toList();
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      final now = DateTime.now();
      if (now.year == _selectedMonth.year &&
          now.month == _selectedMonth.month) {
        _selectedCalendarDay = now.day;
      } else {
        _selectedCalendarDay = 1;
      }
    });
    _fetchData();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      final now = DateTime.now();
      if (now.year == _selectedMonth.year &&
          now.month == _selectedMonth.month) {
        _selectedCalendarDay = now.day;
      } else {
        _selectedCalendarDay = 1;
      }
    });
    _fetchData();
  }

  Future<void> _exportCSV() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => const Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: ArtechLoadingWidget(
              size: 64,
              message: 'Mengunduh rekapan CSV...',
            ),
          ),
    );

    try {
      final csvContent = await AttendanceService.exportAttendanceCSV(
        _selectedMonth.month,
        _selectedMonth.year,
        employeeId: _selectedEmployeeId,
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (csvContent != null && csvContent.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final fileName =
            'absensi_${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}.csv';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsString(csvContent);

        if (mounted) {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path)],
              text:
                  'Rekap Presensi Periode ${DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth)}',
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal mengunduh berkas CSV dari server.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Color _getStatusColor(String status, String badge) {
    final s = status.toLowerCase();
    final b = badge.toLowerCase();
    if (b == 'success' || s == 'hadir' || s.contains('tepat')) {
      return const Color(0xFF16A34A);
    }
    if (s.contains('belum absen pulang')) return const Color(0xFFEA580C);
    if (b == 'warning' || s.contains('lambat') || s.contains('candidate')) {
      return const Color(0xFFD97706);
    }
    if (s.contains('cuti')) return AppColors.primary;
    if (s.contains('izin')) return Colors.orange.shade800;
    if (s.contains('sakit')) return AppColors.error;
    if (s.contains('lembur')) return const Color(0xFF4F46E5);
    if (s.contains('dinas')) return const Color(0xFF7C3AED);
    if (b == 'error' ||
        s.contains('tidak') ||
        s.contains('alpa') ||
        s.contains('alpha')) {
      return AppColors.error;
    }
    if (s.contains('libur')) return const Color(0xFF64748B);
    return AppColors.onSurfaceVariant;
  }

  IconData _getFilterIcon(String status) {
    final s = status.toLowerCase();
    if (s == 'semua') return Icons.view_list_rounded;
    if (s == 'hadir') return Icons.check_circle_rounded;
    if (s.contains('tepat')) return Icons.verified_rounded;
    if (s.contains('lambat')) return Icons.schedule_rounded;
    if (s.contains('belum')) return Icons.pending_actions_rounded;
    if (s == 'cuti') return Icons.beach_access_rounded;
    if (s == 'izin') return Icons.assignment_rounded;
    if (s == 'sakit') return Icons.medical_services_rounded;
    if (s.contains('dinas')) return Icons.flight_takeoff_rounded;
    if (s == 'lembur') return Icons.more_time_rounded;
    if (s.contains('tidak') || s.contains('alpha')) return Icons.cancel_rounded;
    if (s.contains('libur')) return Icons.wb_sunny_rounded;
    return Icons.label_rounded;
  }

  Color _getFilterColor(String status) {
    final s = status.toLowerCase();
    if (s == 'semua') return AppColors.primary;
    if (s == 'hadir' || s.contains('tepat')) return const Color(0xFF16A34A);
    if (s.contains('belum')) return const Color(0xFFEA580C);
    if (s.contains('lambat')) return const Color(0xFFD97706);
    if (s == 'cuti') return AppColors.primary;
    if (s == 'izin') return Colors.orange.shade800;
    if (s == 'sakit') return AppColors.error;
    if (s == 'lembur') return const Color(0xFF4F46E5);
    if (s.contains('dinas')) return const Color(0xFF7C3AED);
    if (s.contains('tidak') || s.contains('alpha')) return AppColors.error;
    if (s.contains('libur')) return const Color(0xFF64748B);
    return const Color(0xFF475569);
  }

  /// Menampilkan modal bottom sheet untuk memilih kategori filter presensi
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header modal
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pilih Kategori Presensi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedStatus != 'Semua')
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedStatus = 'Semua');
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset Filter'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              // Daftar opsi kategori filter
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _statusFilters.length,
                  separatorBuilder:
                      (_, __) => const Divider(
                        height: 1,
                        indent: 64,
                        color: Color(0xFFF1F5F9),
                      ),
                  itemBuilder: (context, index) {
                    final status = _statusFilters[index];
                    final isSelected = _selectedStatus == status;
                    final count =
                        _allHistory
                            .where((item) => _matchesStatus(item, status))
                            .length;

                    final icon = _getFilterIcon(status);
                    final color = _getFilterColor(status);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      title: Text(
                        status,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color:
                              isSelected
                                  ? AppColors.primary
                                  : const Color(0xFF1E293B),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppColors.primary
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$count hari',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color:
                                isSelected
                                    ? AppColors.primary
                                    : const Color(0xFFCBD5E1),
                            size: 20,
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() => _selectedStatus = status);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String monthDisplay =
        _historyData?.period?['month_name']?.toString() ??
        DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Riwayat Kehadiran',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (_selectedEmployeeName != null)
              Text(
                _selectedEmployeeName!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Filter Kategori',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_list_rounded),
                if (_selectedStatus != 'Semua')
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterBottomSheet,
          ),
          IconButton(
            tooltip: 'Unduh CSV',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportCSV,
          ),
          ValueListenableBuilder<int>(
            valueListenable: NotificationsService.unreadCountNotifier,
            builder: (context, unreadCount, _) {
              const iconWidget = Icon(
                Icons.notifications_none_rounded,
                size: 22,
              );

              return IconButton(
                tooltip: 'Notifikasi',
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
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // 1. Month Navigator & Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      onPressed: _previousMonth,
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
                              monthDisplay,
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      onPressed: _nextMonth,
                    ),
                  ],
                ),

                // Employee Filter (Khusus Direksi / HCGA / Superadmin - SCOPE_READ_ALL / SCOPE_MANAGE)
                if (_availableEmployees.length > 1) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value:
                            _availableEmployees.any(
                                  (e) => e.id == _selectedEmployeeId,
                                )
                                ? _selectedEmployeeId
                                : null,
                        hint: const Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: Color(0xFF475569),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Presensi Saya Sendiri',
                                style: TextStyle(fontSize: 12.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_pin_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Presensi Saya Sendiri',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ..._availableEmployees.map((emp) {
                            return DropdownMenuItem<int?>(
                              value: emp.id,
                              child: Text(
                                '${emp.name} (${emp.position})',
                                style: const TextStyle(fontSize: 12.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (newId) {
                          setState(() {
                            _selectedEmployeeId = newId;
                            if (newId != null) {
                              _selectedEmployeeName =
                                  _availableEmployees
                                      .firstWhere((e) => e.id == newId)
                                      .name;
                            } else {
                              _selectedEmployeeName = null;
                            }
                          });
                          _fetchData();
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 2. Category Filter Bar (Tombol Garis Tiga Bertumpuk)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                // Tombol Filter Garis Tiga Bertumpuk (Expanded agar tidak overflow)
                Expanded(
                  child: InkWell(
                    onTap: _showFilterBottomSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _selectedStatus == 'Semua'
                                ? const Color(0xFFF1F5F9)
                                : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              _selectedStatus == 'Semua'
                                  ? const Color(0xFFCBD5E1)
                                  : AppColors.primary,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_list_rounded,
                            size: 16,
                            color:
                                _selectedStatus == 'Semua'
                                    ? const Color(0xFF475569)
                                    : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _selectedStatus == 'Semua'
                                  ? 'Filter Kategori'
                                  : 'Kategori: $_selectedStatus',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    _selectedStatus == 'Semua'
                                        ? const Color(0xFF334155)
                                        : AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color:
                                _selectedStatus == 'Semua'
                                    ? const Color(0xFF64748B)
                                    : AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_selectedStatus != 'Semua') ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => _selectedStatus = 'Semua'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.close_rounded,
                            size: 13,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                Text(
                  '${_filteredHistory.length} Hari',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // 3. Main Content
          Expanded(
            child:
                _isLoading
                    ? ArtechLoadingWidget.page(
                      message: 'Memuat riwayat kehadiran...',
                    )
                    : _historyData == null
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 48,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _errorMessage ?? 'Gagal memuat riwayat presensi.',
                              style: const TextStyle(color: Color(0xFF475569)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _fetchData,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ArtechPullToRefresh(
                      onRefresh: _fetchData,
                      child: _buildContent(context),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Selalu gunakan statistik bulanan keseluruhan (Semua) agar data statistik tidak ngawur/0 saat filter aktif
    final stats = _overallStatistics ?? _historyData!.statistics;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A. Integrated Monthly Statistics Cards (Tetap 1 statistik utuh sebulan)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.45,
              children: [
                _buildMiniStat(
                  'Hadir',
                  '${stats.hadir}',
                  Icons.check_circle_rounded,
                  const Color(0xFF16A34A),
                  const Color(0xFFDCFCE7),
                ),
                _buildMiniStat(
                  'Terlambat',
                  '${stats.terlambat}',
                  Icons.schedule_rounded,
                  const Color(0xFFD97706),
                  const Color(0xFFFEF3C7),
                ),
                _buildMiniStat(
                  'Belum Pulang',
                  '${stats.belumAbsenPulang}',
                  Icons.pending_actions_rounded,
                  const Color(0xFFEA580C),
                  const Color(0xFFFFEDD5),
                ),
                _buildMiniStat(
                  'Cuti',
                  '${stats.cuti}',
                  Icons.beach_access_rounded,
                  AppColors.primary,
                  const Color(0xFFDBEAFE),
                ),
                _buildMiniStat(
                  'Izin / Sakit',
                  '${stats.izin + stats.sakit}',
                  Icons.medical_services_rounded,
                  AppColors.error,
                  const Color(0xFFFEE2E2),
                ),
                _buildMiniStat(
                  'Dinas / Lembur',
                  '${stats.perjalananDinas + stats.lembur}',
                  Icons.flight_takeoff_rounded,
                  const Color(0xFF7C3AED),
                  const Color(0xFFF5F3FF),
                ),
                _buildMiniStat(
                  'Alpha',
                  '${stats.tidakHadir}',
                  Icons.cancel_rounded,
                  const Color(0xFFDC2626),
                  const Color(0xFFFEE2E2),
                ),
                _buildMiniStat(
                  'Hari Libur',
                  '${stats.hariLibur}',
                  Icons.wb_sunny_rounded,
                  const Color(0xFF64748B),
                  const Color(0xFFF1F5F9),
                ),
                _buildMiniStat(
                  'Kehadiran',
                  '${stats.persentaseKehadiran.toStringAsFixed(0)}%',
                  Icons.pie_chart_rounded,
                  const Color(0xFF0D9488),
                  const Color(0xFFCCFBF1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // B. Kalender Bulanan Riwayat Presensi (Titik Warna-Warni)
          _buildMonthlyCalendarCard(),
          const SizedBox(height: 14),

          // C. Keterangan Titik Presensi (Legend)
          _buildCalendarLegend(),
          const SizedBox(height: 12),

          // Hint Ketuk Tanggal
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Ketuk tanggal pada kalender untuk melihat rincian kehadiran',
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  AttendanceHistoryItem? _getItemForDay(int day) {
    final dayStr = day.toString().padLeft(2, '0');
    final monthStr = _selectedMonth.month.toString().padLeft(2, '0');
    final targetDate = '${_selectedMonth.year}-$monthStr-$dayStr';

    for (final item in _allHistory) {
      if (item.date == targetDate) return item;
      if (item.date.endsWith('-$dayStr') &&
          item.date.startsWith('${_selectedMonth.year}-')) {
        return item;
      }
    }
    return null;
  }

  bool _isDayToday(int day) {
    final now = DateTime.now();
    return now.year == _selectedMonth.year &&
        now.month == _selectedMonth.month &&
        now.day == day;
  }

  Color? _getDotColorForDay(int day) {
    final item = _getItemForDay(day);
    final dt = DateTime(_selectedMonth.year, _selectedMonth.month, day);
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
      final hasScan =
          item.checkInTime != null &&
          item.checkInTime!.isNotEmpty &&
          item.checkInTime != '--:--';
      if (!hasScan) return const Color(0xFF94A3B8); // Slate
    }

    // 2. Cuti
    if (s.contains('cuti') ||
        item.approvedRequest?.requestType?.contains('cuti') == true) {
      return AppColors.primary; // Blue
    }

    // 3. Izin
    if (s.contains('izin') ||
        item.approvedRequest?.requestType?.contains('izin') == true) {
      return Colors.orange.shade800; // Brown-orange
    }

    // 4. Sakit
    if (s.contains('sakit') ||
        item.approvedRequest?.requestType?.contains('sakit') == true) {
      return AppColors.error; // Red
    }

    // 5. Perjalanan Dinas
    if (s.contains('dinas') ||
        item.approvedRequest?.requestType?.contains('dinas') == true) {
      return const Color(0xFF7C3AED); // Purple
    }

    // 6. Lembur
    if (s.contains('lembur') ||
        item.approvedRequest?.requestType?.contains('lembur') == true) {
      return const Color(0xFF4F46E5); // Indigo
    }

    // 7. Tidak Hadir / Alpha
    if (s.contains('tidak') ||
        s.contains('alpa') ||
        s.contains('alpha') ||
        cat == 'alpha_candidate') {
      return const Color(0xFFDC2626); // Red
    }

    // 8. Belum Absen Pulang
    if (s.contains('belum')) {
      return const Color(0xFFEA580C); // Orange
    }

    // 9. Terlambat
    if (s.contains('lambat') ||
        item.lateMinutes > 0 ||
        cat == 'late' ||
        cat == 'terlambat' ||
        cat == 'very_late') {
      return const Color(0xFFD97706); // Amber
    }

    // 10. Hadir / Tepat Waktu
    return const Color(0xFF16A34A); // Green
  }

  Widget _buildMonthlyCalendarCard() {
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final firstDayWeekday =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday;
    final startOffset = (firstDayWeekday - 1) % 7;
    final totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;
    const weekDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Kalender
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedStatus != 'Semua') ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getFilterColor(
                        _selectedStatus,
                      ).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _selectedStatus,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: _getFilterColor(_selectedStatus),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Baris Header Hari (Senin - Minggu)
          Row(
            children: List.generate(7, (i) {
              final isWeekend = i >= 5;
              return Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      weekDays[i],
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color:
                            isWeekend
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF64748B),
                      ),
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
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - startOffset + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final item = _getItemForDay(dayNumber);
              final dotColor = _getDotColorForDay(dayNumber);
              final isSelected = _selectedCalendarDay == dayNumber;
              final isToday = _isDayToday(dayNumber);
              final matchesFilter =
                  _selectedStatus == 'Semua' ||
                  (item != null && _matchesStatus(item, _selectedStatus));
              final dayDate = DateTime(
                _selectedMonth.year,
                _selectedMonth.month,
                dayNumber,
              );

              return InkWell(
                onTap: () {
                  setState(() => _selectedCalendarDay = dayNumber);
                  _showDayDetailModal(context, item, dayNumber, dayDate);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? AppColors.primary
                            : (isToday
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppColors.primary
                              : (isToday
                                  ? AppColors.primary.withValues(alpha: 0.6)
                                  : (_selectedStatus != 'Semua' && matchesFilter
                                      ? _getFilterColor(_selectedStatus)
                                      : Colors.transparent)),
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
                              fontWeight:
                                  isSelected || isToday
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : (matchesFilter
                                          ? (index % 7 >= 5
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF1E293B))
                                          : const Color(0xFFCBD5E1)),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.palette_outlined, size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'Keterangan Titik Presensi',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: [
              _buildLegendItem(const Color(0xFF16A34A), 'Hadir (Tepat Waktu)'),
              _buildLegendItem(const Color(0xFFD97706), 'Terlambat'),
              _buildLegendItem(const Color(0xFFEA580C), 'Belum Absen Pulang'),
              _buildLegendItem(AppColors.primary, 'Cuti'),
              _buildLegendItem(Colors.orange.shade800, 'Izin'),
              _buildLegendItem(const Color(0xFFDC2626), 'Sakit / Alpha'),
              _buildLegendItem(const Color(0xFF7C3AED), 'Dinas / Lembur'),
              _buildLegendItem(const Color(0xFF94A3B8), 'Hari Libur'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
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

  Widget _buildMiniStat(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bg,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 12, color: color),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateDuration(String? checkIn, String? checkOut) {
    if (checkIn == null ||
        checkOut == null ||
        checkIn.isEmpty ||
        checkOut.isEmpty ||
        checkIn == '--:--' ||
        checkOut == '--:--') {
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
    final statusColor =
        item != null
            ? _getStatusColor(item.status, item.statusBadge)
            : (dayDate.weekday >= 6
                ? const Color(0xFF94A3B8)
                : AppColors.primary);
    final isLate =
        item != null &&
        (item.status.toLowerCase().contains('lambat') || item.lateMinutes > 0);
    final bool hasScan =
        item != null &&
        ((item.checkInTime != null &&
                item.checkInTime!.isNotEmpty &&
                item.checkInTime != '--:--') ||
            (item.checkOutTime != null &&
                item.checkOutTime!.isNotEmpty &&
                item.checkOutTime != '--:--'));
    final String duration =
        item != null
            ? _calculateDuration(item.formattedCheckIn, item.formattedCheckOut)
            : '';
    final dateFormatted = DateFormat(
      'EEEE, d MMMM yyyy',
      'id_ID',
    ).format(dayDate);

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
                                  item.approvedRequest?.typeLabel ??
                                      item.status,
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
                              item
                                  .approvedRequest!
                                  .description!
                                  .isNotEmpty) ...[
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
                                      color:
                                          isLate
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
}
