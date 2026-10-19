import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';
import '../../../core/widgets/artech_pull_to_refresh.dart';
import '../data/agenda_service.dart';
import '../data/models/agenda_models.dart';

class AgendaDetailScreen extends StatefulWidget {
  final int agendaId;
  final AgendaItem? initialItem;

  const AgendaDetailScreen({
    super.key,
    required this.agendaId,
    this.initialItem,
  });

  @override
  State<AgendaDetailScreen> createState() => _AgendaDetailScreenState();
}

class _AgendaDetailScreenState extends State<AgendaDetailScreen> {
  AgendaItem? _agenda;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isNotFound = false;

  @override
  void initState() {
    super.initState();
    _agenda = widget.initialItem;
    _fetchDetail();
  }

  Future<void> _fetchDetail({bool silent = false}) async {
    if (!silent && _agenda == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _isNotFound = false;
      });
    }

    final res = await AgendaService.getAgendaDetail(widget.agendaId);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.success && res.agenda != null) {
        _agenda = res.agenda;
        _errorMessage = null;
        _isNotFound = false;
      } else {
        _isNotFound = res.isNotFoundOrForbidden;
        _errorMessage = res.message;
      }
    });
  }

  void _shareAgenda() {
    final item = _agenda;
    if (item == null) return;

    final text =
        StringBuffer()
          ..writeln('📅 ${item.title}')
          ..writeln('🏷️ Jenis: ${item.type}')
          ..writeln('📆 Tanggal: ${item.formattedDateRange}')
          ..writeln('⏰ Waktu: ${item.formattedTimeRange}');

    if (item.location != null && item.location!.isNotEmpty) {
      text.writeln('📍 Lokasi: ${item.location}');
    }
    if (item.pic != null && item.pic!.isNotEmpty) {
      text.writeln('👤 PIC: ${item.pic}');
    }
    if (item.description != null && item.description!.isNotEmpty) {
      text.writeln('\nDeskripsi:\n${item.description}');
    }

    Share.share(text.toString(), subject: item.title);
  }

  void _copyDeepLink() {
    final link = _agenda?.deepLink ?? 'artech://agenda/${widget.agendaId}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tautan deep-link agenda berhasil disalin ke clipboard.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _agenda;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Detail Agenda',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (item != null)
            IconButton(
              icon: const Icon(
                Icons.share_outlined,
                size: 20,
                color: Color(0xFF0F172A),
              ),
              tooltip: 'Bagikan Agenda',
              onPressed: _shareAgenda,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _agenda == null) {
      return Center(
        child: ArtechLoadingWidget.page(message: 'Memuat detail agenda...'),
      );
    }

    if (_isNotFound) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  size: 48,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Agenda Tidak Tersedia',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ??
                    'Agenda sudah tidak tersedia atau Anda bukan bagian dari audiens agenda ini.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, true); // true = refresh previous list
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Kembali ke Daftar Agenda'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _agenda == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _fetchDetail(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final item = _agenda!;
    final typeColor = item.typeColor;
    final typeIcon = item.typeIcon;

    return ArtechPullToRefresh(
      onRefresh: () => _fetchDetail(silent: true),
      refreshingText: 'Memperbarui detail agenda...',
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main Card Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type and Audience row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, size: 14, color: typeColor),
                            const SizedBox(width: 6),
                            Text(
                              item.type,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: typeColor,
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
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.public_rounded,
                              size: 13,
                              color: Color(0xFF475569),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              item.audienceLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    item.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      height: 1.3,
                    ),
                  ),

                  // Description
                  if (item.description != null &&
                      item.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        item.description!.trim(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF334155),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Schedule & Location Information Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waktu & Lokasi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date
                  _buildInfoRow(
                    icon: Icons.calendar_today_rounded,
                    iconColor: const Color(0xFF0037B0),
                    title: 'Tanggal Pelaksanaan',
                    value: item.formattedDateRange,
                    subtitle:
                        (item.eventEndDate != null &&
                                item.eventEndDate!.isNotEmpty &&
                                item.eventEndDate != item.eventDate)
                            ? 'Agenda multi-hari'
                            : null,
                  ),
                  const Divider(
                    height: 20,
                    thickness: 0.8,
                    color: Color(0xFFF1F5F9),
                  ),

                  // Time
                  _buildInfoRow(
                    icon: Icons.access_time_rounded,
                    iconColor: const Color(0xFF0D9488),
                    title: 'Jam / Waktu',
                    value: item.formattedTimeRange,
                    subtitle:
                        (item.startsAt != null && item.startsAt!.isNotEmpty)
                            ? 'Waktu Indonesia Barat (WIB)'
                            : 'Agenda tanpa batasan jam spesifik',
                  ),

                  // Location
                  if (item.location != null && item.location!.isNotEmpty) ...[
                    const Divider(
                      height: 20,
                      thickness: 0.8,
                      color: Color(0xFFF1F5F9),
                    ),
                    _buildInfoRow(
                      icon: Icons.place_rounded,
                      iconColor: const Color(0xFFDC2626),
                      title: 'Lokasi / Media Pertemuan',
                      value: item.location!,
                    ),
                  ],

                  // PIC
                  if (item.pic != null && item.pic!.isNotEmpty) ...[
                    const Divider(
                      height: 20,
                      thickness: 0.8,
                      color: Color(0xFFF1F5F9),
                    ),
                    _buildInfoRow(
                      icon: Icons.account_circle_rounded,
                      iconColor: const Color(0xFF6366F1),
                      title: 'Penanggung Jawab (PIC)',
                      value: item.pic!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reminders Information Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
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
                        'Pengingat Terjadwal (Reminder)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              item.reminderOffsets.isNotEmpty
                                  ? const Color(
                                    0xFF0037B0,
                                  ).withValues(alpha: 0.1)
                                  : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.reminderOffsets.isNotEmpty
                              ? '${item.reminderOffsets.length} Aktif'
                              : 'Tidak Ada',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color:
                                item.reminderOffsets.isNotEmpty
                                    ? const Color(0xFF0037B0)
                                    : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (item.reminderOffsets.isNotEmpty) ...[
                    ...item.reminderLabels.map(
                      (label) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_active_rounded,
                              size: 14,
                              color: Color(0xFF0037B0),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Notifikasi akan otomatis masuk ke bilah notifikasi HP Anda sebelum agenda dimulai.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Tidak ada pengingat otomatis terjadwal untuk agenda ini.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Deep-link / Meta Info Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0037B0).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF0037B0).withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    size: 20,
                    color: Color(0xFF0037B0),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tautan Deep-Link',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          item.deepLink ?? 'artech://agenda/${item.id}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0037B0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: Color(0xFF0037B0),
                    ),
                    tooltip: 'Salin Tautan',
                    onPressed: _copyDeepLink,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
