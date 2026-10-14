import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/performance_models.dart';
import '../../data/performance_service.dart';

class TargetFormModal extends StatefulWidget {
  final int currentYear;
  final String currentPeriod;
  final List<MonthlyTargetItem> availableParents;
  final MonthlyTargetItem? initialTarget; // If editing
  final String? preselectedLevel;
  final int? preselectedParentId;
  final VoidCallback onSuccess;

  const TargetFormModal({
    super.key,
    required this.currentYear,
    required this.currentPeriod,
    this.availableParents = const [],
    this.initialTarget,
    this.preselectedLevel,
    this.preselectedParentId,
    required this.onSuccess,
  });

  @override
  State<TargetFormModal> createState() => _TargetFormModalState();
}

class _TargetFormModalState extends State<TargetFormModal> {
  final _formKey = GlobalKey<FormState>();

  late String _level;
  late String _priority;
  late String _status;
  int? _parentId;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _expectedResultsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();

  bool _isLoading = false;

  bool get _isEdit => widget.initialTarget != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final t = widget.initialTarget!;
      _level = t.level;
      _priority = t.priority;
      _status = t.status;
      _parentId = t.parentId;
      _titleController.text = t.title;
      _expectedResultsController.text = t.expectedResults ?? '';
      _notesController.text = t.notes ?? '';
      _startDateController.text = t.startDate ?? '';
      _deadlineController.text = t.deadline ?? '';
    } else {
      _level = widget.preselectedLevel ?? 'main';
      _priority = 'normal';
      _status = 'not_started';
      _parentId = widget.preselectedParentId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _expectedResultsController.dispose();
    _notesController.dispose();
    _startDateController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    DateTime initial = now;
    if (controller.text.isNotEmpty) {
      final parsed = DateTime.tryParse(controller.text);
      if (parsed != null) initial = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0037B0),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      setState(() {
        controller.text = formatted;
      });
    }
  }

  List<MonthlyTargetItem> _getSelectableParents() {
    if (_level == 'weekly') {
      // Parents must be main level
      return widget.availableParents.where((t) => t.level == 'main').toList();
    } else if (_level == 'daily') {
      // Parents must be weekly level
      List<MonthlyTargetItem> weeklies = [];
      for (final main in widget.availableParents) {
        for (final w in main.children) {
          if (w.level == 'weekly') {
            weeklies.add(w);
          }
        }
      }
      return weeklies;
    }
    return [];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isEdit && _level != 'main' && _parentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _level == 'weekly'
                ? 'Pilih Target Utama induk terlebih dahulu.'
                : 'Pilih Target Pekanan induk terlebih dahulu.',
            style: GoogleFonts.plusJakartaSans(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isEdit) {
        final body = <String, dynamic>{
          'title': _titleController.text.trim(),
          'expected_results': _expectedResultsController.text.trim(),
          'status': _status,
          'priority': _priority,
          'notes': _notesController.text.trim(),
        };
        if (_startDateController.text.isNotEmpty) {
          body['start_date'] = _startDateController.text;
        }
        if (_deadlineController.text.isNotEmpty) {
          body['deadline'] = _deadlineController.text;
        }

        final res = await PerformanceService.updateMonthlyTarget(
          widget.initialTarget!.id,
          body,
        );

        if (!mounted) return;
        if (res.success) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message, style: GoogleFonts.plusJakartaSans()),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message, style: GoogleFonts.plusJakartaSans()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } else {
        final body = <String, dynamic>{
          'year': widget.currentYear,
          'period': widget.currentPeriod,
          'level': _level,
          'title': _titleController.text.trim(),
          'expected_results': _expectedResultsController.text.trim(),
          'priority': _priority,
          'status': _status,
          'notes': _notesController.text.trim(),
        };
        if (_startDateController.text.isNotEmpty) {
          body['start_date'] = _startDateController.text;
        }
        if (_deadlineController.text.isNotEmpty) {
          body['deadline'] = _deadlineController.text;
        }
        if (_parentId != null) {
          body['parent_id'] = _parentId;
        }

        final res = await PerformanceService.createMonthlyTarget(body);

        if (!mounted) return;
        if (res.success) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message, style: GoogleFonts.plusJakartaSans()),
              backgroundColor: const Color(0xFF16A34A),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message, style: GoogleFonts.plusJakartaSans()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final selectableParents = _getSelectableParents();

    // Verify parentId exists in current selectable list
    final hasValidParent = selectableParents.any((p) => p.id == _parentId);
    final currentParentId = hasValidParent ? _parentId : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0037B0), Color(0xFF155DFC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0037B0).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.track_changes_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? 'Ubah Target' : 'Tambah Target Baru',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Periode: ${widget.currentPeriod} ${widget.currentYear}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Form Content
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: bottomInset + 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. TINGKATAN TARGET (Only when creating)
                    if (!_isEdit) ...[
                      Row(
                        children: [
                          Text(
                            'Tingkatan Target',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Hierarki',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0037B0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih tingkatan sasaran kinerja yang ingin Anda buat',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 3 Option Cards
                      Row(
                        children: [
                          _buildLevelCard(
                            value: 'main',
                            title: 'Target Utama',
                            badge: 'Bulanan',
                            icon: Icons.flag_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildLevelCard(
                            value: 'weekly',
                            title: 'Target Pekan',
                            badge: 'Mingguan',
                            icon: Icons.calendar_view_week_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildLevelCard(
                            value: 'daily',
                            title: 'Target Harian',
                            badge: 'Aktivitas',
                            icon: Icons.today_rounded,
                          ),
                        ],
                      ),

                      // Contextual Helper Note
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _level == 'main'
                                  ? Icons.lightbulb_outline_rounded
                                  : Icons.account_tree_outlined,
                              size: 16,
                              color: const Color(0xFF0037B0),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _level == 'main'
                                    ? 'Target Utama adalah sasaran gol bulanan Anda (dapat menaungi target pekanan & harian).'
                                    : _level == 'weekly'
                                        ? 'Target Pekanan merupakan sub-target per minggu di bawah Target Utama.'
                                        : 'Target Harian merupakan rincian tugas operasional di bawah Target Pekanan.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: const Color(0xFF475569),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 2. PARENT SELECTOR (if weekly or daily)
                    if (!_isEdit && _level != 'main') ...[
                      Row(
                        children: [
                          Text(
                            _level == 'weekly' ? 'Target Utama Induk' : 'Target Pekanan Induk',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _level == 'weekly'
                            ? 'Pilih Target Utama bulanan yang menaungi target pekan ini'
                            : 'Pilih Target Pekanan mingguan yang menaungi aktivitas harian ini',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (selectableParents.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _level == 'weekly'
                                      ? 'Belum ada Target Utama pada periode ini. Silakan buat Target Utama terlebih dahulu.'
                                      : 'Belum ada Target Pekanan pada periode ini. Silakan buat Target Pekanan terlebih dahulu.',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF92400E),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        DropdownButtonFormField<int>(
                          value: currentParentId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.account_tree_outlined, color: Color(0xFF64748B), size: 18),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0037B0), width: 1.5),
                            ),
                            hintText: _level == 'weekly' ? 'Pilih Target Utama...' : 'Pilih Target Pekanan...',
                            hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                          ),
                          items: selectableParents.map((p) {
                            return DropdownMenuItem<int>(
                              value: p.id,
                              child: Text(
                                p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _parentId = val;
                            });
                          },
                          validator: (val) {
                            if (val == null) {
                              return _level == 'weekly'
                                  ? 'Wajib memilih Target Utama induk'
                                  : 'Wajib memilih Target Pekanan induk';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],

                    // 3. JUDUL TARGET
                    Row(
                      children: [
                        Text(
                          'Judul Target',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF64748B), size: 20),
                        hintText: _level == 'main'
                            ? 'Contoh: Optimalisasi Performa Database Portal'
                            : _level == 'weekly'
                                ? 'Contoh: Refactoring Query Notifikasi & Indexing'
                                : 'Contoh: Benchmark query tabel notifications',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0037B0), width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Judul target tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 4. HASIL YANG DIHARAPKAN (EXPECTED RESULTS)
                    Text(
                      'Hasil yang Diharapkan (Expected Results)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Keluaran atau indikator keberhasilan terukur yang ingin dicapai',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _expectedResultsController,
                      maxLines: 2,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Icon(Icons.flag_outlined, color: Color(0xFF64748B), size: 18),
                        ),
                        hintText: 'Misal: Waktu response query di bawah 100ms dan beban CPU berkurang 20%',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0037B0), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. PRIORITAS TARGET (Selectable Pills)
                    Text(
                      'Prioritas Target',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPriorityChip('low', 'Rendah', const Color(0xFF64748B), const Color(0xFFF1F5F9)),
                        const SizedBox(width: 8),
                        _buildPriorityChip('normal', 'Normal', const Color(0xFF0284C7), const Color(0xFFF0F9FF)),
                        const SizedBox(width: 8),
                        _buildPriorityChip('high', 'Tinggi', const Color(0xFFEA580C), const Color(0xFFFFF7ED)),
                        const SizedBox(width: 8),
                        _buildPriorityChip('urgent', 'Mendesak', const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 6. STATUS TARGET (Selectable Pills)
                    Text(
                      'Status Pengerjaan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatusChip('not_started', 'Belum Mulai', Icons.hourglass_empty_rounded, const Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        _buildStatusChip('in_progress', 'Sedang Berjalan', Icons.sync_rounded, const Color(0xFF0037B0)),
                        const SizedBox(width: 8),
                        _buildStatusChip('completed', 'Selesai', Icons.check_circle_outline_rounded, const Color(0xFF16A34A)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 7. JADWAL (TANGGAL MULAI & TENGGAT)
                    Text(
                      'Jadwal & Tenggat Waktu',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateSelector(
                            label: 'Tanggal Mulai',
                            controller: _startDateController,
                            icon: Icons.calendar_today_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateSelector(
                            label: 'Tenggat (Deadline)',
                            controller: _deadlineController,
                            icon: Icons.event_available_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 8. CATATAN TAMBAHAN (OPSIONAL)
                    Text(
                      'Catatan Tambahan (Opsional)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Icon(Icons.sticky_note_2_outlined, color: Color(0xFF64748B), size: 18),
                        ),
                        hintText: 'Fokus pengerjaan, dependensi tim, atau kendala penting...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF0037B0), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 9. SUBMIT BUTTON
                    GestureDetector(
                      onTap: _isLoading ? null : _submit,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0037B0), Color(0xFF155DFC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0037B0).withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isEdit ? Icons.save_rounded : Icons.add_circle_outline_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isEdit ? 'Simpan Perubahan' : 'Tambah Target',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // LEVEL OPTION CARD
  Widget _buildLevelCard({
    required String value,
    required String title,
    required String badge,
    required IconData icon,
  }) {
    final isSelected = _level == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _level = value;
            _parentId = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF0037B0) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0037B0).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF0037B0) : const Color(0xFF64748B),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF0037B0) : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? const Color(0xFF0037B0) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // PRIORITY CHIP
  Widget _buildPriorityChip(String value, String label, Color color, Color bgLight) {
    final isSelected = _priority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? bgLight : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // STATUS CHIP
  Widget _buildStatusChip(String value, String label, IconData icon, Color color) {
    final isSelected = _status == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? color : const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? color : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // DATE SELECTOR WIDGET
  Widget _buildDateSelector({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    final hasValue = controller.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _pickDate(controller),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasValue ? const Color(0xFF0037B0) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: hasValue ? const Color(0xFF0037B0) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasValue ? controller.text : 'Pilih tanggal...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                      color: hasValue ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                if (hasValue)
                  GestureDetector(
                    onTap: () => setState(() => controller.clear()),
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
