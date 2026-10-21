import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../../../core/widgets/artech_pull_to_refresh.dart';
import '../data/models/request_models.dart';
import '../data/requests_service.dart';
import 'cuti_tahunan_screen.dart';
import 'izin_screen.dart';
import 'sakit_screen.dart';
import 'dinas_luar_screen.dart';
import 'kerja_lembur_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../notifications/data/notifications_service.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  int _selectedMainTab =
      0; // 0: Pengajuan Saya, 1: Perlu Persetujuan (Inbox Atasan)
  String _selectedStatusFilter = 'Semua';

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _myRequestsLimit = 5;
  int _approvalsLimit = 5;

  bool _isLoading = true;
  String? _errorMessage;

  List<RequestItem> _myRequests = [];
  List<RequestItem> _pendingApprovals = [];
  RequestMeta? _meta;

  final List<String> _statusFilters = [
    'Semua',
    'Menunggu Manager',
    'Menunggu HCGA',
    'Disetujui',
    'Ditolak',
    'Dibatalkan',
  ];

  String _selectedApprovalTypeFilter = 'Semua';
  final List<String> _approvalTypeFilters = [
    'Semua',
    'Cuti',
    'Izin',
    'Sakit',
    'Lembur',
    'Dinas',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
    NotificationsService.refreshUnreadCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final myReqRes = await RequestsService.getRequests(
        status: _selectedStatusFilter == 'Semua' ? null : _selectedStatusFilter,
      );
      final approvalsRes = await RequestsService.getApprovals();
      final metaRes = await RequestsService.getRequestMeta();

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (myReqRes.success && myReqRes.data != null) {
            _myRequests = myReqRes.data!;
          } else {
            _errorMessage = myReqRes.message;
          }

          if (approvalsRes.success && approvalsRes.data != null) {
            _pendingApprovals = approvalsRes.data!;
          }

          if (metaRes.success && metaRes.data != null) {
            _meta = metaRes.data!;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data: $e';
        });
      }
    }
  }

  Future<void> _handleCancelRequest(RequestItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Batalkan Pengajuan?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Apakah Anda yakin ingin membatalkan pengajuan "${item.title}" (${item.requestNumber})?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Tidak'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ya, Batalkan'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      if (mounted)
        ArtechLoadingWidget.showLoadingDialog(
          context,
          message: 'Membatalkan pengajuan...',
        );
      final res = await RequestsService.cancelRequest(item.id);
      if (!mounted) return;
      ArtechLoadingWidget.hideLoadingDialog(context);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: Colors.green),
        );
        _fetchData(silent: true);
      } else {
        _handleActionError(res);
      }
    }
  }

  void _handleActionError(RequestApiResponse res) {
    if (res.statusCode == 403) {
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.gpp_bad_outlined,
                    color: AppColors.error,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Akses Ditolak',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Text(res.message, style: const TextStyle(fontSize: 13)),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Mengerti'),
                ),
              ],
            ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor:
              res.statusCode == 422 ? Colors.orange.shade800 : AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleApprove(RequestItem item) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Setujui Pengajuan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Setujui pengajuan ${item.typeLabel} dari ${item.employee?.name ?? "karyawan"}?',
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Color(0xFF0037B0),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.approvalFlow == 'hcga_only' ||
                                  item.approvalFlow == 'auto_approved'
                              ? 'Persetujuan ini adalah tahap final. Dampak kehadiran otomatis langsung aktif pada presensi karyawan.'
                              : 'Persetujuan Manager akan meneruskan pengajuan ke HCGA (status: Menunggu HCGA). Dampak absensi aktif setelah persetujuan final HCGA.',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF334155),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Catatan persetujuan (opsional)...',
                    hintStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Setujui'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      if (mounted)
        ArtechLoadingWidget.showLoadingDialog(
          context,
          message: 'Menyetujui pengajuan...',
        );
      final res = await RequestsService.approveRequest(
        item.id,
        note: noteController.text.trim(),
      );
      if (!mounted) return;
      ArtechLoadingWidget.hideLoadingDialog(context);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: Colors.green),
        );
        _fetchData(silent: true);
      } else {
        _handleActionError(res);
      }
    }
  }

  Future<void> _handleReject(RequestItem item) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.cancel_outlined,
                  color: AppColors.error,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Tolak Pengajuan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tolak pengajuan ${item.typeLabel} dari ${item.employee?.name ?? "karyawan"}?',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Alasan penolakan (wajib diisi)...',
                    hintStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (noteController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Alasan penolakan wajib diisi'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Tolak'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      if (mounted)
        ArtechLoadingWidget.showLoadingDialog(
          context,
          message: 'Menolak pengajuan...',
        );
      final res = await RequestsService.rejectRequest(
        item.id,
        note: noteController.text.trim(),
      );
      if (!mounted) return;
      ArtechLoadingWidget.hideLoadingDialog(context);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        _fetchData(silent: true);
      } else {
        _handleActionError(res);
      }
    }
  }

  void _showDetailBottomSheet(RequestItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (item.isParticipant && !item.isOwner) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.group_outlined,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.requestType == 'lembur'
                                      ? 'Lembur Tim / Kelompok'
                                      : 'Perjalanan Dinas Kelompok',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Anda terdaftar sebagai peserta oleh pembuat pengajuan (${item.employee?.name ?? "-"}). Pembatalan hanya dapat dilakukan oleh pembuat pengajuan.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: item.typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.typeIcon,
                          color: item.typeColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.typeLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              item.requestNumber,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.effectiveDisplayStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item.statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Detail Section
                  const Text(
                    'Keterangan / Alasan:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 14),

                  // Waktu & Tanggal
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.endDate != null &&
                                    item.endDate != item.startDate
                                ? '${item.startDate} s/d ${item.endDate}'
                                : item.startDate,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (item.startTime != null && item.endTime != null)
                        Text(
                          '(${item.startTime} - ${item.endTime})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),

                  if (item.location != null && item.location!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.tertiary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.location!,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Tipe Waktu & Peserta Chips
                  if (item.parsedDetails?.tipeWaktu != null ||
                      item.parsedDetails?.tipePeserta != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (item.parsedDetails?.tipeWaktu != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.parsedDetails!.tipeWaktu == 'menginap'
                                      ? 'Menginap'
                                      : 'Harian (PP)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (item.parsedDetails?.tipePeserta != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  size: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.parsedDetails!.tipePeserta == 'kelompok'
                                      ? 'Kelompok'
                                      : 'Individu',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],

                  // Daftar Peserta Dinas
                  if (item.parsedDetails?.peserta.isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Daftar Peserta (${item.parsedDetails!.peserta.length} Pegawai):',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Column(
                        children:
                            item.parsedDetails!.peserta
                                .map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor:
                                              AppColors.primaryContainer,
                                          child: Text(
                                            p.name.isNotEmpty
                                                ? p.name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                p.name,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                '${p.position.isNotEmpty ? p.position : "-"} • ${p.division.isNotEmpty ? p.division : "-"}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      AppColors
                                                          .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ],

                  // Lampiran
                  if (item.attachmentUrl != null &&
                      item.attachmentUrl!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.attach_file_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lampiran: ${item.attachmentUrl!.split("/").last}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Dampak pada Modul Absensi & Presensi
                  if (item.attendanceImpact != null &&
                      item.attendanceImpact!.affectsAttendance) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            item.attendanceImpact!.isEffective
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              item.attendanceImpact!.isEffective
                                  ? const Color(0xFFBBF7D0)
                                  : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                item.attendanceImpact!.isEffective
                                    ? Icons.verified_rounded
                                    : Icons.info_outline_rounded,
                                size: 16,
                                color:
                                    item.attendanceImpact!.isEffective
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'INTEGRASI ABSENSI & PRESENSI',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color:
                                      item.attendanceImpact!.isEffective
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.attendanceImpact!.isEffective
                                ? 'Pengajuan telah disetujui. Kehadiran Anda pada periode ${item.attendanceImpact!.startDate ?? item.startDate} hingga ${item.attendanceImpact!.endDate ?? item.endDate ?? item.startDate} akan tercatat otomatis sebagai "${item.attendanceImpact!.effectiveStatus ?? item.typeLabel}".'
                                : 'Pengajuan masih menunggu persetujuan. Status kehadiran akan diperbarui secara otomatis setelah disetujui oleh HCGA.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color:
                                  item.attendanceImpact!.isEffective
                                      ? const Color(0xFF14532D)
                                      : const Color(0xFF78350F),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Alur Persetujuan
                  _buildApprovalTimeline(item),

                  if (item.canCancel && item.isOwner) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleEditRequest(item);
                            },
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: const Text(
                              'Edit Pengajuan',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _handleCancelRequest(item);
                            },
                            icon: const Icon(
                              Icons.cancel_outlined,
                              size: 16,
                              color: AppColors.error,
                            ),
                            label: const Text(
                              'Batalkan',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _openForm(Widget screen) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (created == true) {
      _fetchData(silent: true);
    }
  }

  void _handleEditRequest(RequestItem item) {
    switch (item.requestType.toLowerCase()) {
      case 'cuti':
        _openForm(CutiTahunanScreen(existingItem: item));
        break;
      case 'izin':
        _openForm(IzinScreen(existingItem: item));
        break;
      case 'sakit':
        _openForm(SakitScreen(existingItem: item));
        break;
      case 'lembur':
        _openForm(KerjaLemburScreen(existingItem: item));
        break;
      case 'perjalanan_dinas':
      case 'dinas':
        _openForm(DinasLuarScreen(existingItem: item));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tipe pengajuan ${item.requestType} tidak dikenali'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: ArtechPullToRefresh(
        onRefresh: () => _fetchData(silent: true),
        refreshingText: 'Memperbarui pengajuan...',
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMiniHeader(context),
              if (_isLoading &&
                  _myRequests.isEmpty &&
                  _pendingApprovals.isEmpty)
                Container(
                  height: MediaQuery.of(context).size.height * 0.55,
                  alignment: Alignment.center,
                  child: ArtechLoadingWidget.page(
                    message: 'Memuat data pengajuan...',
                    size: 72,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMainTabSelector(),
                      const SizedBox(height: 16),
                      if (_selectedMainTab == 0) ...[
                        _buildQuickCategories(context),
                        const SizedBox(height: 18),
                        _buildSearchBar(),
                        const SizedBox(height: 12),
                        _buildStatusFilters(context),
                        const SizedBox(height: 14),
                        _buildMyRequestsList(),
                      ] else ...[
                        _buildApprovalsHeaderBanner(),
                        const SizedBox(height: 14),
                        _buildSearchBar(),
                        const SizedBox(height: 12),
                        _buildApprovalTypeFilters(context),
                        const SizedBox(height: 14),
                        _buildApprovalsList(),
                      ],
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
                    Row(
                      children: [
                        Text(
                          'Pengajuan & Izin',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
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
                              const Icon(
                                Icons.verified_user_outlined,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Berjenjang',
                                style: GoogleFonts.plusJakartaSans(
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
                  'Kelola cuti, izin, sakit, lembur, dan dinas luar',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabSelector() {
    final pendingCount = _pendingApprovals.length;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Tab 0: Pengajuan Saya
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_selectedMainTab != 0) {
                  setState(() {
                    _selectedMainTab = 0;
                    _myRequestsLimit = 5;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  gradient:
                      _selectedMainTab == 0
                          ? const LinearGradient(
                            colors: [Color(0xFF0037B0), Color(0xFF155DFC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                          : null,
                  color: _selectedMainTab == 0 ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow:
                      _selectedMainTab == 0
                          ? [
                            BoxShadow(
                              color: const Color(
                                0xFF0037B0,
                              ).withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                          : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 18,
                      color:
                          _selectedMainTab == 0
                              ? Colors.white
                              : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Pengajuan Saya',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color:
                                _selectedMainTab == 0
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Tab 1: Perlu Persetujuan
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_selectedMainTab != 1) {
                  setState(() {
                    _selectedMainTab = 1;
                    _approvalsLimit = 5;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  gradient:
                      _selectedMainTab == 1
                          ? const LinearGradient(
                            colors: [Color(0xFF0037B0), Color(0xFF155DFC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                          : null,
                  color: _selectedMainTab == 1 ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow:
                      _selectedMainTab == 1
                          ? [
                            BoxShadow(
                              color: const Color(
                                0xFF0037B0,
                              ).withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                          : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 18,
                      color:
                          _selectedMainTab == 1
                              ? Colors.white
                              : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Perlu Persetujuan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color:
                                _selectedMainTab == 1
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _selectedMainTab == 1
                                  ? Colors.white
                                  : const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: GoogleFonts.plusJakartaSans(
                            color:
                                _selectedMainTab == 1
                                    ? const Color(0xFF0037B0)
                                    : Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalsHeaderBanner() {
    final count = _pendingApprovals.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF091E47).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  count > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              count > 0
                  ? Icons.pending_actions_rounded
                  : Icons.check_circle_outline_rounded,
              color:
                  count > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inbox Persetujuan Staf',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count > 0
                      ? '$count permohonan staf menunggu tindakan persetujuan'
                      : 'Semua permohonan staf telah selesai diproses',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color:
                        count > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalTypeFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            _approvalTypeFilters.map((filter) {
              final isActive = _selectedApprovalTypeFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedApprovalTypeFilter = filter;
                      _approvalsLimit = 5;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          isActive
                              ? const LinearGradient(
                                colors: [Color(0xFF0037B0), Color(0xFF155DFC)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      color: isActive ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isActive
                                ? Colors.transparent
                                : const Color(0xFFE2E8F0),
                      ),
                      boxShadow:
                          isActive
                              ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0037B0,
                                  ).withValues(alpha: 0.22),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Text(
                      filter,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isActive ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              _searchQuery.isNotEmpty
                  ? const Color(0xFF0037B0)
                  : const Color(0xFFE2E8F0),
          width: _searchQuery.isNotEmpty ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
            _myRequestsLimit = 5;
            _approvalsLimit = 5;
          });
        },
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText:
              _selectedMainTab == 0
                  ? 'Cari no. pengajuan, jenis, alasan...'
                  : 'Cari nama staf, jenis permohonan...',
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF64748B),
          ),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _myRequestsLimit = 5;
                        _approvalsLimit = 5;
                      });
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationFooter({
    required int totalCount,
    required int currentLimit,
    required VoidCallback onLoadMore,
    required VoidCallback onShowAll,
    required VoidCallback onCollapse,
  }) {
    final isCapped = totalCount > currentLimit;
    final showingCount = isCapped ? currentLimit : totalCount;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.list_alt_rounded,
                  size: 14,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Menampilkan $showingCount dari $totalCount pengajuan',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isCapped) ...[
                ElevatedButton.icon(
                  onPressed: onLoadMore,
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  label: Text(
                    'Muat 5 Lagi (${totalCount - currentLimit} tersisa)',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onShowAll,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: const Text('Semua'),
                ),
              ] else if (totalCount > 5) ...[
                OutlinedButton.icon(
                  onPressed: onCollapse,
                  icon: const Icon(Icons.expand_less_rounded, size: 18),
                  label: const Text('Ciutkan Kembali (Tampilkan 5)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.onSurfaceVariant,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCategories(BuildContext context) {
    final canElevated = _meta?.canUseElevatedTypes ?? false;
    final role = _meta?.userRole;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Buat Pengajuan Baru',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (role != null && role.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        canElevated
                            ? const Color(0xFFF3E8FF)
                            : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Akses: ${role.toUpperCase()}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color:
                          canElevated
                              ? const Color(0xFF7E22CE)
                              : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuickCategoryItem(
                label: 'Cuti',
                icon: Icons.beach_access_rounded,
                bgColor: const Color(0xFFEFF6FF),
                iconColor: const Color(0xFF1D4ED8),
                onTap: () => _openForm(const CutiTahunanScreen()),
              ),
              const SizedBox(width: 6),
              _buildQuickCategoryItem(
                label: 'Izin',
                icon: Icons.event_note_rounded,
                bgColor: const Color(0xFFF0FDF4),
                iconColor: const Color(0xFF15803D),
                onTap: () => _openForm(const IzinScreen()),
              ),
              const SizedBox(width: 6),
              _buildQuickCategoryItem(
                label: 'Sakit',
                icon: Icons.medical_services_rounded,
                bgColor: const Color(0xFFFEF2F2),
                iconColor: const Color(0xFFDC2626),
                onTap: () => _openForm(const SakitScreen()),
              ),
              const SizedBox(width: 6),
              _buildQuickCategoryItem(
                label: 'Dinas Luar',
                icon: Icons.flight_takeoff_rounded,
                bgColor:
                    canElevated
                        ? const Color(0xFFF5F3FF)
                        : const Color(0xFFF1F5F9),
                iconColor:
                    canElevated
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF94A3B8),
                isLocked: !canElevated,
                onTap:
                    canElevated
                        ? () => _openForm(const DinasLuarScreen())
                        : () => _showElevatedRoleWarning('Perjalanan Dinas'),
              ),
              const SizedBox(width: 6),
              _buildQuickCategoryItem(
                label: 'Lembur',
                icon: Icons.access_time_filled_rounded,
                bgColor:
                    canElevated
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFF1F5F9),
                iconColor:
                    canElevated
                        ? const Color(0xFFEA580C)
                        : const Color(0xFF94A3B8),
                isLocked: !canElevated,
                onTap:
                    canElevated
                        ? () => _openForm(const KerjaLemburScreen())
                        : () => _showElevatedRoleWarning('Kerja Lembur'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCategoryItem({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                if (isLocked)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color:
                    isLocked
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showElevatedRoleWarning(String formName) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: AppColors.error,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Akses Khusus (403)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'Pengajuan $formName hanya dapat diajukan oleh akun minimal level Head (Head, Lead, Manager, Direktur).\n\nAkun Anda (${_meta?.userRole ?? "staff"}) hanya diizinkan mengajukan Cuti, Izin, dan Sakit.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0037B0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Mengerti',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildStatusFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            _statusFilters.map((filter) {
              final isActive = _selectedStatusFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStatusFilter = filter;
                      _myRequestsLimit = 5;
                    });
                    _fetchData();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          isActive
                              ? const LinearGradient(
                                colors: [Color(0xFF0037B0), Color(0xFF155DFC)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                      color: isActive ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isActive
                                ? Colors.transparent
                                : const Color(0xFFE2E8F0),
                      ),
                      boxShadow:
                          isActive
                              ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0037B0,
                                  ).withValues(alpha: 0.22),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Text(
                      filter,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isActive ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  List<RequestItem> _getFilteredMyRequests() {
    if (_searchQuery.trim().isEmpty) return _myRequests;
    final query = _searchQuery.trim().toLowerCase();
    return _myRequests.where((item) {
      final matchesNum = item.requestNumber.toLowerCase().contains(query);
      final matchesType = item.typeLabel.toLowerCase().contains(query);
      final matchesTitle = item.title.toLowerCase().contains(query);
      final matchesDesc = item.description.toLowerCase().contains(query);
      final matchesStatus = item.effectiveDisplayStatus.toLowerCase().contains(
        query,
      );
      final matchesEmployee = (item.employee?.name ?? '')
          .toLowerCase()
          .contains(query);
      return matchesNum ||
          matchesType ||
          matchesTitle ||
          matchesDesc ||
          matchesStatus ||
          matchesEmployee;
    }).toList();
  }

  Widget _buildMyRequestsList() {
    if (_isLoading) {
      return ArtechLoadingWidget.page(message: 'Memuat daftar pengajuan...');
    }

    if (_errorMessage != null && _myRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppColors.error),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _fetchData(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_myRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.folder_open_rounded,
              size: 44,
              color: AppColors.outline,
            ),
            const SizedBox(height: 10),
            const Text(
              'Belum Ada Pengajuan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedStatusFilter == 'Semua'
                  ? 'Anda belum pernah membuat permohonan ketidakhadiran atau tugas khusus.'
                  : 'Tidak ada pengajuan dengan status "$_selectedStatusFilter".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _getFilteredMyRequests();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 44,
              color: AppColors.outline,
            ),
            const SizedBox(height: 10),
            const Text(
              'Pengajuan Tidak Ditemukan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Tidak ada pengajuan yang cocok dengan pencarian "$_searchQuery".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('Reset Pencarian'),
            ),
          ],
        ),
      );
    }

    final displayItems = filtered.take(_myRequestsLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...displayItems.map((item) => _buildMyRequestCard(item)),
        _buildPaginationFooter(
          totalCount: filtered.length,
          currentLimit: _myRequestsLimit,
          onLoadMore: () {
            setState(() {
              _myRequestsLimit += 5;
            });
          },
          onShowAll: () {
            setState(() {
              _myRequestsLimit = filtered.length;
            });
          },
          onCollapse: () {
            setState(() {
              _myRequestsLimit = 5;
            });
          },
        ),
      ],
    );
  }

  Widget _buildMyRequestCard(RequestItem item) {
    return GestureDetector(
      onTap: () => _showDetailBottomSheet(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: Icon, Title & Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: item.typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(item.typeIcon, color: item.typeColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.typeLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          item.requestNumber,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (item.isParticipant && !item.isOwner) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Peserta Kelompok (${item.employee?.name ?? "Koordinator"})',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: item.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: item.statusColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      item.effectiveDisplayStatus,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: item.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Date & Detail Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: Color(0xFF0037B0),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              item.endDate != null &&
                                      item.endDate != item.startDate
                                  ? '${item.startDate} s/d ${item.endDate}'
                                  : item.startDate,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        if (item.startTime != null && item.endTime != null)
                          Text(
                            '(${item.startTime} - ${item.endTime})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                    if (item.location != null && item.location!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.location!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF475569),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (item.parsedDetails?.tipePeserta != null ||
                        item.parsedDetails?.tipeWaktu != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.parsedDetails?.tipeWaktu != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.parsedDetails!.tipeWaktu == 'menginap'
                                    ? 'Menginap'
                                    : 'Harian (PP)',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                          if (item.parsedDetails?.tipePeserta != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.parsedDetails!.tipePeserta == 'kelompok'
                                    ? 'Kelompok (${item.parsedDetails!.peserta.length} Orang)'
                                    : 'Individu',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: const Color(0xFF334155),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              // Attendance Impact Badge
              if (item.attendanceImpact != null &&
                  item.attendanceImpact!.affectsAttendance) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        item.attendanceImpact!.isEffective
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          item.attendanceImpact!.isEffective
                              ? const Color(0xFFBBF7D0)
                              : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.attendanceImpact!.isEffective
                            ? Icons.event_available_rounded
                            : Icons.schedule_rounded,
                        size: 13,
                        color:
                            item.attendanceImpact!.isEffective
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFD97706),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.attendanceImpact!.isEffective
                              ? 'Absensi Aktif: ${item.attendanceImpact!.effectiveStatus ?? item.typeLabel}'
                              : 'Absensi: Otomatis aktif setelah Disetujui (${item.attendanceImpact!.effectiveStatus ?? item.typeLabel})',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color:
                                item.attendanceImpact!.isEffective
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB45309),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Approval Flow Steps
              _buildApprovalTimeline(item),

              // Actions: Edit & Cancel
              if (item.canCancel && item.isOwner) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _handleEditRequest(item),
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: Color(0xFF0037B0),
                      ),
                      label: Text(
                        'Edit',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF0037B0),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        backgroundColor: const Color(0xFFEFF6FF),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: () => _handleCancelRequest(item),
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 13,
                        color: Color(0xFFDC2626),
                      ),
                      label: Text(
                        'Batalkan',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFFDC2626),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        backgroundColor: const Color(0xFFFEF2F2),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalTimeline(RequestItem item) {
    if (item.approvalFlow == 'auto_approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.verified_rounded,
              size: 18,
              color: Color(0xFF16A34A),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disetujui Otomatis',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                  Text(
                    'Level Manager HCGA / Direktur (Persetujuan instan)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isHcgaOnly = item.approvalFlow == 'hcga_only';
    final managerStatus =
        isHcgaOnly ? 'Dilewati' : (item.managerApproval?.status ?? 'Menunggu');
    final hcgaStatus = item.hcgaApproval?.status ?? 'Menunggu';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ALUR PERSETUJUAN BERJENJANG',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: const Color(0xFF64748B),
                ),
              ),
              if (isHcgaOnly)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Direct HCGA',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0037B0),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTimelineRow(
            '1. Atasan Langsung / Manager',
            managerStatus,
            isHcgaOnly
                ? 'Dilewati (Langsung di bawah HCGA/Direksi)'
                : item.managerApproval?.note,
            item.managerApproval?.approvedBy,
          ),
          const Divider(height: 12, thickness: 0.5, color: Color(0xFFE2E8F0)),
          _buildTimelineRow(
            '2. HCGA / HR Operations',
            hcgaStatus,
            item.hcgaApproval?.note,
            item.hcgaApproval?.approvedBy,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(
    String role,
    String status,
    String? note,
    String? approver,
  ) {
    Color color;
    IconData icon;
    final lower = status.toLowerCase();
    if (lower.contains('setuju')) {
      color = const Color(0xFF16A34A);
      icon = Icons.check_circle_rounded;
    } else if (lower.contains('tolak')) {
      color = const Color(0xFFDC2626);
      icon = Icons.cancel_rounded;
    } else if (lower.contains('lewat')) {
      color = const Color(0xFF0284C7);
      icon = Icons.fast_forward_rounded;
    } else {
      color = const Color(0xFF64748B);
      icon = Icons.schedule_rounded;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      role,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              if (approver != null && approver.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Oleh: $approver',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '"$note"',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<RequestItem> _getFilteredPendingApprovals() {
    var list = _pendingApprovals;
    if (_selectedApprovalTypeFilter != 'Semua') {
      final filter = _selectedApprovalTypeFilter.toLowerCase();
      list =
          list.where((item) {
            final type = item.requestType.toLowerCase();
            final label = item.typeLabel.toLowerCase();
            if (filter == 'cuti')
              return type.contains('cuti') || label.contains('cuti');
            if (filter == 'izin')
              return type.contains('izin') || label.contains('izin');
            if (filter == 'sakit')
              return type.contains('sakit') || label.contains('sakit');
            if (filter == 'lembur')
              return type.contains('lembur') || label.contains('lembur');
            if (filter == 'dinas')
              return type.contains('dinas') || label.contains('dinas');
            return type.contains(filter) || label.contains(filter);
          }).toList();
    }
    if (_searchQuery.trim().isEmpty) return list;
    final query = _searchQuery.trim().toLowerCase();
    return list.where((item) {
      final matchesNum = item.requestNumber.toLowerCase().contains(query);
      final matchesType = item.typeLabel.toLowerCase().contains(query);
      final matchesEmployee = (item.employee?.name ?? '')
          .toLowerCase()
          .contains(query);
      final matchesTitle = item.title.toLowerCase().contains(query);
      final matchesDesc = item.description.toLowerCase().contains(query);
      return matchesNum ||
          matchesType ||
          matchesEmployee ||
          matchesTitle ||
          matchesDesc;
    }).toList();
  }

  Widget _buildApprovalsList() {
    if (_isLoading) {
      return ArtechLoadingWidget.page(message: 'Memuat daftar persetujuan...');
    }

    if (_pendingApprovals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_outlined, size: 44, color: AppColors.outline),
            SizedBox(height: 10),
            Text(
              'Semua Pengajuan Selesai',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Tidak ada permohonan staf yang memerlukan persetujuan Anda saat ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final filtered = _getFilteredPendingApprovals();

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 44,
              color: AppColors.outline,
            ),
            const SizedBox(height: 10),
            const Text(
              'Persetujuan Tidak Ditemukan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Tidak ada permohonan yang cocok dengan pencarian "$_searchQuery".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('Reset Pencarian'),
            ),
          ],
        ),
      );
    }

    final displayItems = filtered.take(_approvalsLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...displayItems.map((item) => _buildApprovalCard(item)),
        _buildPaginationFooter(
          totalCount: filtered.length,
          currentLimit: _approvalsLimit,
          onLoadMore: () {
            setState(() {
              _approvalsLimit += 5;
            });
          },
          onShowAll: () {
            setState(() {
              _approvalsLimit = filtered.length;
            });
          },
          onCollapse: () {
            setState(() {
              _approvalsLimit = 5;
            });
          },
        ),
      ],
    );
  }

  Widget _buildApprovalCard(RequestItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee Info Header
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    (item.employee?.name.isNotEmpty == true)
                        ? item.employee!.name[0].toUpperCase()
                        : 'E',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0037B0),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.employee?.name ?? 'Nama Karyawan',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${item.employee?.position ?? "-"} • ${item.employee?.division ?? "-"}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: item.typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: item.typeColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    item.typeLabel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: item.typeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date & Reason Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 14,
                        color: Color(0xFF0037B0),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.endDate != null && item.endDate != item.startDate
                            ? '${item.startDate} s/d ${item.endDate}'
                            : item.startDate,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: const Color(0xFF334155),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Approve & Reject Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleReject(item),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                    label: Text(
                      'Tolak',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      backgroundColor: const Color(0xFFFEF2F2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApprove(item),
                    icon: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Setujui',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
