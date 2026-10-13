import 'package:flutter/material.dart';
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

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  int _selectedMainTab = 0; // 0: Pengajuan Saya, 1: Perlu Persetujuan (Inbox Atasan)
  String _selectedStatusFilter = 'Semua';

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

  @override
  void initState() {
    super.initState();
    _fetchData();
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Pengajuan?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin membatalkan pengajuan "${item.title}" (${item.requestNumber})?'),
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
      final res = await RequestsService.cancelRequest(item.id);
      if (!mounted) return;
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
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.gpp_bad_outlined, color: AppColors.error, size: 24),
              SizedBox(width: 8),
              Text('Akses Ditolak', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            res.message,
            style: const TextStyle(fontSize: 13),
          ),
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
          backgroundColor: res.statusCode == 422 ? Colors.orange.shade800 : AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleApprove(RequestItem item) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            const Text('Setujui Pengajuan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Setujui pengajuan ${item.typeLabel} dari ${item.employee?.name ?? "karyawan"}?'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Catatan persetujuan (opsional)...',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      final res = await RequestsService.approveRequest(item.id, note: noteController.text.trim());
      if (!mounted) return;
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            const Text('Tolak Pengajuan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tolak pengajuan ${item.typeLabel} dari ${item.employee?.name ?? "karyawan"}?'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Alasan penolakan (wajib diisi)...',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  const SnackBar(content: Text('Alasan penolakan wajib diisi')),
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
      final res = await RequestsService.rejectRequest(item.id, note: noteController.text.trim());
      if (!mounted) return;
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message), backgroundColor: Colors.orange.shade800),
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
      builder: (ctx) => Container(
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
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.group_outlined, color: Colors.blue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.requestType == 'lembur' ? 'Lembur Tim / Kelompok' : 'Perjalanan Dinas Kelompok',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Anda terdaftar sebagai peserta oleh pembuat pengajuan (${item.employee?.name ?? "-"}). Pembatalan hanya dapat dilakukan oleh pembuat pengajuan.',
                              style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
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
                    child: Icon(item.typeIcon, color: item.typeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.typeLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          item.requestNumber,
                          style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              const Text('Keterangan / Alasan:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.outline)),
              const SizedBox(height: 4),
              Text(item.description, style: const TextStyle(fontSize: 13, height: 1.4)),
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
                      const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        item.endDate != null && item.endDate != item.startDate
                            ? '${item.startDate} s/d ${item.endDate}'
                            : item.startDate,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (item.startTime != null && item.endTime != null)
                    Text(
                      '(${item.startTime} - ${item.endTime})',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                ],
              ),

              if (item.location != null && item.location!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.tertiary),
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
              if (item.parsedDetails?.tipeWaktu != null || item.parsedDetails?.tipePeserta != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (item.parsedDetails?.tipeWaktu != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 12, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              item.parsedDetails!.tipeWaktu == 'menginap' ? 'Menginap' : 'Harian (PP)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    if (item.parsedDetails?.tipePeserta != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_outline, size: 12, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              item.parsedDetails!.tipePeserta == 'kelompok' ? 'Kelompok' : 'Individu',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.outline),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: item.parsedDetails!.peserta.map((p) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.primaryContainer,
                            child: Text(
                              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Text(
                                  '${p.position.isNotEmpty ? p.position : "-"} • ${p.division.isNotEmpty ? p.division : "-"}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ],

              // Lampiran
              if (item.attachmentUrl != null && item.attachmentUrl!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lampiran: ${item.attachmentUrl!.split("/").last}',
                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
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
                        icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                        label: const Text('Edit Pengajuan', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                        label: const Text('Batalkan', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          SnackBar(content: Text('Tipe pengajuan ${item.requestType} tidak dikenali')),
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
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMiniHeader(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildQuickCategories(context),
                    const SizedBox(height: 20),
                    _buildMainTabSelector(),
                    const SizedBox(height: 16),
                    if (_selectedMainTab == 0) ...[
                      _buildStatusFilters(context),
                      const SizedBox(height: 14),
                      _buildMyRequestsList(),
                    ] else ...[
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
                  children: [
                    const Expanded(
                      child: Text(
                        'Pengajuan & Izin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_outlined, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'Persetujuan Berjenjang',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Kelola cuti, izin, sakit, lembur, dan dinas luar',
                  style: TextStyle(
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMainTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedMainTab == 0 ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedMainTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: _selectedMainTab == 0 ? AppColors.primary : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Pengajuan Saya',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _selectedMainTab == 0 ? FontWeight.bold : FontWeight.w500,
                          color: _selectedMainTab == 0 ? AppColors.primary : AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMainTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedMainTab == 1 ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedMainTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 16,
                      color: _selectedMainTab == 1 ? AppColors.primary : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Perlu Persetujuan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _selectedMainTab == 1 ? FontWeight.bold : FontWeight.w500,
                          color: _selectedMainTab == 1 ? AppColors.primary : AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_pendingApprovals.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_pendingApprovals.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

  Widget _buildQuickCategories(BuildContext context) {
    final canElevated = _meta?.canUseElevatedTypes ?? false;
    final role = _meta?.userRole;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Buat Pengajuan Baru',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (role != null && role.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: canElevated ? Colors.purple.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Akses: ${role.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: canElevated ? Colors.purple : Colors.blue,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Row 1: Pengajuan Umum (Cuti, Izin, Sakit)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildCategoryButton(
                  context,
                  'Libur Cuti',
                  Icons.beach_access_rounded,
                  AppColors.primaryContainer.withValues(alpha: 0.4),
                  AppColors.primary,
                  onTap: () => _openForm(const CutiTahunanScreen()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCategoryButton(
                  context,
                  'Izin',
                  Icons.event_note_rounded,
                  AppColors.secondaryContainer.withValues(alpha: 0.4),
                  AppColors.secondary,
                  onTap: () => _openForm(const IzinScreen()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCategoryButton(
                  context,
                  'Sakit',
                  Icons.medical_services_rounded,
                  AppColors.errorContainer.withValues(alpha: 0.4),
                  AppColors.error,
                  onTap: () => _openForm(const SakitScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Row 2: Pengajuan Khusus / Operasional (Dinas Luar, Lembur)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildCategoryButton(
                  context,
                  'Perjalanan Dinas',
                  Icons.flight_takeoff_rounded,
                  canElevated ? AppColors.tertiaryContainer.withValues(alpha: 0.4) : Colors.grey.shade100,
                  canElevated ? AppColors.tertiary : Colors.grey.shade400,
                  isLocked: !canElevated,
                  onTap: canElevated
                      ? () => _openForm(const DinasLuarScreen())
                      : () => _showElevatedRoleWarning('Perjalanan Dinas'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCategoryButton(
                  context,
                  'Kerja Lembur',
                  Icons.access_time_filled_rounded,
                  canElevated ? Colors.indigo.withValues(alpha: 0.12) : Colors.grey.shade100,
                  canElevated ? Colors.indigo : Colors.grey.shade400,
                  isLocked: !canElevated,
                  onTap: canElevated
                      ? () => _openForm(const KerjaLemburScreen())
                      : () => _showElevatedRoleWarning('Kerja Lembur'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showElevatedRoleWarning(String formName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Akses Khusus (403)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Pengajuan $formName hanya dapat diajukan oleh akun minimal level Head (Head, Lead, Manager, Direktur).\n\nAkun Anda (${_meta?.userRole ?? "staff"}) hanya diizinkan mengajukan Cuti, Izin, dan Sakit.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
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
  }

  Widget _buildCategoryButton(
    BuildContext context,
    String label,
    IconData icon,
    Color bgColor,
    Color iconColor, {
    VoidCallback? onTap,
    bool isLocked = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                        child: Icon(icon, color: iconColor, size: 18),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: isLocked ? AppColors.outline : null,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (isLocked)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded, size: 10, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusFilters.map((filter) {
          final isActive = _selectedStatusFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedStatusFilter = filter);
                _fetchData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? Colors.white : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMyRequestsList() {
    if (_isLoading) {
      return ArtechLoadingWidget.page(
        message: 'Memuat daftar pengajuan...',
      );
    }

    if (_errorMessage != null && _myRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
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
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            const Icon(Icons.folder_open_rounded, size: 44, color: AppColors.outline),
            const SizedBox(height: 10),
            const Text('Belum Ada Pengajuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              _selectedStatusFilter == 'Semua'
                  ? 'Anda belum pernah membuat permohonan ketidakhadiran atau tugas khusus.'
                  : 'Tidak ada pengajuan dengan status "$_selectedStatusFilter".',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _myRequests.map((item) => _buildMyRequestCard(item)).toList(),
    );
  }

  Widget _buildMyRequestCard(RequestItem item) {
    return GestureDetector(
      onTap: () => _showDetailBottomSheet(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
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
                      borderRadius: BorderRadius.circular(10),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          item.requestNumber,
                          style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                        ),
                        if (item.isParticipant && !item.isOwner) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Peserta Kelompok (${item.employee?.name ?? "Koordinator"})',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              const SizedBox(height: 12),

              // Date & Detail Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
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
                            const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              item.endDate != null && item.endDate != item.startDate
                                  ? '${item.startDate} s/d ${item.endDate}'
                                  : item.startDate,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (item.startTime != null && item.endTime != null)
                          Text(
                            '(${item.startTime} - ${item.endTime})',
                            style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                          ),
                      ],
                    ),
                    if (item.location != null && item.location!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: AppColors.tertiary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.location!,
                              style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (item.parsedDetails?.tipePeserta != null || item.parsedDetails?.tipeWaktu != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.parsedDetails?.tipeWaktu != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.parsedDetails!.tipeWaktu == 'menginap' ? 'Menginap' : 'Harian (PP)',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                              ),
                            ),
                          if (item.parsedDetails?.tipePeserta != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.parsedDetails!.tipePeserta == 'kelompok'
                                    ? 'Kelompok (${item.parsedDetails!.peserta.length} Orang)'
                                    : 'Individu',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Approval Flow Steps
              _buildApprovalTimeline(item),

              // Actions: Edit & Cancel
              if (item.canCancel && item.isOwner) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _handleEditRequest(item),
                      icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                      label: const Text('Edit', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: () => _handleCancelRequest(item),
                      icon: const Icon(Icons.cancel_outlined, size: 14, color: AppColors.error),
                      label: const Text('Batalkan', style: TextStyle(fontSize: 11, color: AppColors.error)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified, size: 18, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Disetujui Otomatis',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  Text(
                    'Level Manager HCGA / Direktur (Persetujuan instan tanpa verifikasi berjenjang)',
                    style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isHcgaOnly = item.approvalFlow == 'hcga_only';
    final managerStatus = isHcgaOnly ? 'Dilewati' : (item.managerApproval?.status ?? 'Menunggu');
    final hcgaStatus = item.hcgaApproval?.status ?? 'Menunggu';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ALUR PERSETUJUAN BERJENJANG',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: AppColors.outline),
              ),
              if (isHcgaOnly)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Direct HCGA',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTimelineRow(
            '1. Atasan Langsung / Manager',
            managerStatus,
            isHcgaOnly ? 'Dilewati (Langsung di bawah HCGA/Direksi)' : item.managerApproval?.note,
            item.managerApproval?.approvedBy,
          ),
          const Divider(height: 12, thickness: 0.5),
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

  Widget _buildTimelineRow(String role, String status, String? note, String? approver) {
    Color color;
    IconData icon;
    final lower = status.toLowerCase();
    if (lower.contains('setuju')) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (lower.contains('tolak')) {
      color = AppColors.error;
      icon = Icons.cancel;
    } else if (lower.contains('lewat')) {
      color = AppColors.secondary;
      icon = Icons.fast_forward_rounded;
    } else {
      color = AppColors.outline;
      icon = Icons.schedule;
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
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
              if (approver != null && approver.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('Oleh: $approver', style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant)),
              ],
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('"$note"', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppColors.onSurfaceVariant)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalsList() {
    if (_isLoading) {
      return ArtechLoadingWidget.page(
        message: 'Memuat daftar persetujuan...',
      );
    }

    if (_pendingApprovals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: const Column(
          children: [
            Icon(Icons.inbox_outlined, size: 44, color: AppColors.outline),
            SizedBox(height: 10),
            Text('Semua Pengajuan Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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

    return Column(
      children: _pendingApprovals.map((item) => _buildApprovalCard(item)).toList(),
    );
  }

  Widget _buildApprovalCard(RequestItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
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
                  radius: 18,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    (item.employee?.name.isNotEmpty == true) ? item.employee!.name[0].toUpperCase() : 'E',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.employee?.name ?? 'Nama Karyawan',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        '${item.employee?.position ?? "-"} • ${item.employee?.division ?? "-"}',
                        style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.typeLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item.typeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date & Reason Details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month, size: 13, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        item.endDate != null && item.endDate != item.startDate
                            ? '${item.startDate} s/d ${item.endDate}'
                            : item.startDate,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
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
                    icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                    label: const Text('Tolak', style: TextStyle(color: AppColors.error, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleApprove(item),
                    icon: const Icon(Icons.check, size: 16, color: Colors.white),
                    label: const Text('Setujui', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
