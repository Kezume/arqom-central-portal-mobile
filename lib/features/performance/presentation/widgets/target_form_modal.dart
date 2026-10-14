import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/performance_models.dart';
import '../../data/performance_service.dart';

class TargetFormModal extends StatefulWidget {
  final int currentYear;
  final String currentPeriod;
  final List<MonthlyTargetItem> availableParents;
  final MonthlyTargetItem? initialTarget;
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
      return widget.availableParents.where((t) => t.level == 'main').toList();
    } else if (_level == 'daily') {
      List<MonthlyTargetItem> weeklies = [];
      for (final main in widget.availableParents) {
        for (final w in main.children) {
          if (w.level == 'weekly') weeklies.add(w);
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
            _level == 'weekly' ? 'Pilih Target Utama induk' : 'Pilih Target Pekanan induk',
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
        if (_startDateController.text.isNotEmpty) body['start_date'] = _startDateController.text;
        if (_deadlineController.text.isNotEmpty) body['deadline'] = _deadlineController.text;

        final res = await PerformanceService.updateMonthlyTarget(widget.initialTarget!.id, body);

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
            SnackBar(content: Text(res.message, style: GoogleFonts.plusJakartaSans()), backgroundColor: AppColors.error),
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
        if (_startDateController.text.isNotEmpty) body['start_date'] = _startDateController.text;
        if (_deadlineController.text.isNotEmpty) body['deadline'] = _deadlineController.text;
        if (_parentId != null) body['parent_id'] = _parentId;

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
            SnackBar(content: Text(res.message, style: GoogleFonts.plusJakartaSans()), backgroundColor: AppColors.error),
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
    final hasValidParent = selectableParents.any((p) => p.id == _parentId);
    final currentParentId = hasValidParent ? _parentId : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header ringkas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? 'Ubah Target' : 'Tambah Target Baru',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Periode: ${widget.currentPeriod} ${widget.currentYear}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Form fields
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: bottomInset + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tingkatan Target (Compact Segmented Bar)
                    if (!_isEdit) ...[
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _buildSegmentItem('main', '🎯 Utama'),
                            _buildSegmentItem('weekly', '📅 Pekanan'),
                            _buildSegmentItem('daily', '📋 Harian'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF0037B0)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _level == 'main'
                                    ? 'Target Utama: Sasaran bulanan (dapat menaungi target pekanan & harian)'
                                    : _level == 'weekly'
                                        ? 'Target Pekanan: Sasaran mingguan di bawah Target Utama'
                                        : 'Target Harian: Rincian aktivitas harian di bawah Target Pekanan',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: const Color(0xFF475569),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Parent Dropdown (hanya jika pekanan / harian)
                    if (!_isEdit && _level != 'main') ...[
                      if (selectableParents.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _level == 'weekly'
                                ? '⚠️ Belum ada Target Utama. Buat Target Utama dulu.'
                                : '⚠️ Belum ada Target Pekanan. Buat Target Pekan dulu.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          _level == 'weekly'
                              ? 'Pilih Target Utama bulanan yang menaungi target pekan ini:'
                              : 'Pilih Target Pekanan yang menaungi aktivitas harian ini:',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: currentParentId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: _level == 'weekly' ? 'Target Utama Induk *' : 'Target Pekanan Induk *',
                            labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          items: selectableParents.map((p) {
                            return DropdownMenuItem<int>(
                              value: p.id,
                              child: Text(
                                p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(fontSize: 12),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _parentId = val),
                          validator: (val) => val == null ? 'Wajib pilih induk' : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    // Judul Target
                    TextFormField(
                      controller: _titleController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Judul Target *',
                        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                        hintText: 'Misal: Optimalisasi Database Portal',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF0037B0), width: 1.5),
                        ),
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Judul target wajib diisi' : null,
                    ),
                    const SizedBox(height: 10),

                    // Hasil yang Diharapkan
                    TextFormField(
                      controller: _expectedResultsController,
                      maxLines: 2,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Hasil yang Diharapkan (Opsional)',
                        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                        hintText: 'Misal: Waktu response query < 100ms',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Prioritas & Status (Berdampingan dalam 1 baris)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _priority,
                            isExpanded: true,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Prioritas',
                              labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'low', child: Text('⚪ Rendah', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'normal', child: Text('🔵 Normal', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'high', child: Text('🟠 Tinggi', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'urgent', child: Text('🔴 Mendesak', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _priority = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            isExpanded: true,
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Status',
                              labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'not_started', child: Text('Belum Mulai', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'in_progress', child: Text('Berjalan', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'completed', child: Text('Selesai', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _status = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Tanggal Mulai & Deadline (Berdampingan dalam 1 baris)
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickDate(_startDateController),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0037B0)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _startDateController.text.isNotEmpty
                                          ? _startDateController.text
                                          : 'Mulai',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: _startDateController.text.isNotEmpty
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                  if (_startDateController.text.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => setState(() => _startDateController.clear()),
                                      child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickDate(_deadlineController),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF0037B0)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _deadlineController.text.isNotEmpty
                                          ? _deadlineController.text
                                          : 'Deadline',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: _deadlineController.text.isNotEmpty
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                  if (_deadlineController.text.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => setState(() => _deadlineController.clear()),
                                      child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Catatan
                    TextFormField(
                      controller: _notesController,
                      style: GoogleFonts.plusJakartaSans(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Catatan (Opsional)',
                        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
                        hintText: 'Keterangan tambahan...',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tombol Simpan
                    GestureDetector(
                      onTap: _isLoading ? null : _submit,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0037B0), Color(0xFF155DFC)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  _isEdit ? 'Simpan Perubahan' : 'Tambah Target',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
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

  Widget _buildSegmentItem(String value, String label) {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0037B0) : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
