import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/performance_models.dart';
import '../../data/performance_service.dart';

class DailyTaskFormModal extends StatefulWidget {
  final String? initialDate;
  final DailyTaskItem? initialTask;
  final int? preselectedWeeklyPlanItemId;
  final bool? movesWithMonthlyTarget;
  final Set<int> allowedKanbanColumnIds;
  final VoidCallback onSuccess;

  const DailyTaskFormModal({
    super.key,
    this.initialDate,
    this.initialTask,
    this.preselectedWeeklyPlanItemId,
    this.movesWithMonthlyTarget,
    this.allowedKanbanColumnIds = const {},
    required this.onSuccess,
  });

  @override
  State<DailyTaskFormModal> createState() => _DailyTaskFormModalState();
}

class _DailyTaskFormModalState extends State<DailyTaskFormModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _workDateController;
  late TextEditingController _detailsController;
  late TextEditingController _expectedOutputController;

  late String _priority;
  late String _executionStatus;
  int? _selectedWeeklyPlanItemId;
  List<WeeklyPlanItem> _availableWeeklyItems = [];
  bool _isLoadingWeeklyItems = false;
  String? _weeklyItemsError;
  int _weeklyItemsRequestSerial = 0;
  bool _isLoading = false;

  bool get _isEdit => widget.initialTask != null;
  bool get _movesWithTarget =>
      widget.movesWithMonthlyTarget ??
      widget.initialTask?.isMonthlyTargetTask ??
      false;
  bool get _canChangeDate => !_isEdit || _movesWithTarget;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    final defaultDate =
        widget.initialDate ?? DateTime.now().toIso8601String().substring(0, 10);

    _titleController = TextEditingController(text: task?.title ?? '');
    _workDateController = TextEditingController(
      text: task?.effectiveDate ?? defaultDate,
    );
    _detailsController = TextEditingController(text: task?.details ?? '');
    _expectedOutputController = TextEditingController(
      text: task?.expectedOutput ?? '',
    );

    _priority = task?.priority ?? 'normal';
    _executionStatus = task?.executionStatus ?? 'not_started';
    _selectedWeeklyPlanItemId =
        widget.preselectedWeeklyPlanItemId ?? task?.weeklyPlanItemId;

    _loadWeeklyPlanItems();
  }

  Future<void> _loadWeeklyPlanItems() async {
    final requestSerial = ++_weeklyItemsRequestSerial;
    setState(() {
      _isLoadingWeeklyItems = true;
      _weeklyItemsError = null;
    });
    final res = await PerformanceService.getWeeklyPlan(
      weekDate: _workDateController.text,
    );
    if (mounted && requestSerial == _weeklyItemsRequestSerial) {
      final items = <WeeklyPlanItem>[];
      if (res.success && res.data != null) {
        for (final group in res.data!.plans) {
          items.addAll(group.items);
        }
      }
      setState(() {
        _availableWeeklyItems = items;
        _isLoadingWeeklyItems = false;
        _weeklyItemsError = res.success ? null : res.message;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _workDateController.dispose();
    _detailsController.dispose();
    _expectedOutputController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    DateTime initial = now;
    if (_workDateController.text.isNotEmpty) {
      final parsed = DateTime.tryParse(_workDateController.text);
      if (parsed != null) initial = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
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
      setState(() {
        _workDateController.text =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
      _loadWeeklyPlanItems();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final selectedDate = _workDateController.text.trim();
    final body = <String, dynamic>{
      'title': _titleController.text.trim(),
      'priority': _priority,
      'execution_status': _executionStatus,
    };

    if (_isEdit) {
      final task = widget.initialTask!;
      final originalDate = task.effectiveDate;
      final dateChanged = originalDate != null && originalDate != selectedDate;
      if (dateChanged && !_movesWithTarget) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Untuk menjaga riwayat, pindahkan tugas mandiri melalui menu "Lanjutkan ke Hari Lain" pada kartu tugas.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (dateChanged) {
        body['due_at'] = task.dueAtForDate(selectedDate);
      }
    } else {
      body['work_date'] = selectedDate;
    }

    if (_detailsController.text.trim().isNotEmpty) {
      body['details'] = _detailsController.text.trim();
    }
    if (_expectedOutputController.text.trim().isNotEmpty) {
      body['expected_output'] = _expectedOutputController.text.trim();
    }
    if (_selectedWeeklyPlanItemId != null) {
      body['weekly_plan_item_id'] = _selectedWeeklyPlanItemId;
    }
    final columnId = widget.initialTask?.kanbanColumnId;
    if (columnId != null && widget.allowedKanbanColumnIds.contains(columnId)) {
      body['kanban_column_id'] = columnId;
    }

    PerformanceApiResponse res;
    if (_isEdit) {
      res = await PerformanceService.updateDailyTask(
        widget.initialTask!.id,
        body,
      );
    } else {
      res = await PerformanceService.createDailyTask(body);
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (res.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildPriorityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prioritas',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _priority,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Rendah')),
            DropdownMenuItem(value: 'normal', child: Text('Normal')),
            DropdownMenuItem(value: 'high', child: Text('Tinggi')),
            DropdownMenuItem(value: 'urgent', child: Text('Mendesak')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _priority = val);
          },
        ),
      ],
    );
  }

  Widget _buildExecutionStatusField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status Eksekusi *',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _executionStatus,
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: const [
            DropdownMenuItem(value: 'not_started', child: Text('Belum Mulai')),
            DropdownMenuItem(value: 'in_progress', child: Text('Berjalan')),
            DropdownMenuItem(value: 'completed', child: Text('Selesai')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _executionStatus = val);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0037B0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: Color(0xFF0037B0),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEdit ? 'Ubah Tugas Harian' : 'Tambah Tugas Harian',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.close_rounded, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Tanggal Kerja
              Text(
                'Tanggal Pengerjaan *',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _workDateController,
                readOnly: true,
                onTap: _canChangeDate ? _pickDate : null,
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Pilih tanggal pengerjaan',
                  suffixIcon: Icon(
                    _canChangeDate
                        ? Icons.calendar_today_rounded
                        : Icons.lock_outline_rounded,
                    size: 18,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Tanggal pengerjaan wajib diisi';
                  }
                  return null;
                },
              ),
              if (!_canChangeDate) ...[
                const SizedBox(height: 6),
                Text(
                  'Untuk memindahkan tanggal, gunakan Lanjutkan pada kartu tugas.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    height: 1.4,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Induk Rencana Mingguan
              Text(
                'Rencana Mingguan (opsional)',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<int?>(
                value:
                    _availableWeeklyItems.any(
                          (e) => e.id == _selectedWeeklyPlanItemId,
                        )
                        ? _selectedWeeklyPlanItemId
                        : null,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                hint:
                    _isLoadingWeeklyItems
                        ? Text(
                          'Memuat rencana mingguan...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        )
                        : Text(
                          'Tanpa rencana mingguan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      'Tanpa rencana mingguan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ..._availableWeeklyItems.map(
                    (item) => DropdownMenuItem<int?>(
                      value: item.id,
                      child: Text(
                        item.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged:
                    _isEdit || _isLoadingWeeklyItems
                        ? null
                        : (val) {
                          setState(() {
                            _selectedWeeklyPlanItemId = val;
                          });
                        },
              ),
              if (_weeklyItemsError != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rencana mingguan gagal dimuat. Tugas tetap dapat disimpan tanpa mengubah relasinya.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadWeeklyPlanItems,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              // Judul Task
              Text(
                'Judul Tugas / Aktivitas *',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Contoh: Slicing UI, Fixing bug login, dsb.',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Judul tugas wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Prioritas & Status adaptif untuk layar sempit / text scaling.
              LayoutBuilder(
                builder: (context, constraints) {
                  final priority = _buildPriorityField();
                  final status = _buildExecutionStatusField();
                  if (constraints.maxWidth < 380) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [priority, const SizedBox(height: 12), status],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: priority),
                      const SizedBox(width: 12),
                      Expanded(child: status),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // Rincian / Detail (Opsional)
              Text(
                'Rincian / Keterangan (Opsional)',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _detailsController,
                maxLines: 2,
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tambahkan catatan atau rincian pekerjaan...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Target Output (Opsional)
              Text(
                'Hasil yang Diharapkan (Opsional)',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _expectedOutputController,
                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Contoh: APK release, Dokumen SRS terupdate, dsb.',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Submit Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0037B0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Text(
                          _isEdit ? 'Simpan Perubahan' : 'Tambah Tugas',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
