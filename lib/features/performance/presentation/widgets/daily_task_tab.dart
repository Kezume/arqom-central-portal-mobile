import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/artech_loading_widget.dart';
import '../../data/models/performance_models.dart';
import '../../data/performance_service.dart';
import 'daily_task_form_modal.dart';
import 'performance_paginated_list.dart';

class DailyTaskTab extends StatefulWidget {
  final VoidCallback onDataChanged;

  const DailyTaskTab({super.key, required this.onDataChanged});

  @override
  State<DailyTaskTab> createState() => _DailyTaskTabState();
}

class _DailyTaskTabState extends State<DailyTaskTab> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DailyTaskItem> _tasks = [];
  List<KanbanColumn> _kanbanColumns = [];
  int _requestSerial = 0;
  final Set<int> _busyTaskIds = {};

  DateTime _selectedDate = DateTime.now();
  String _selectedStatusFilter =
      'semua'; // 'semua', 'not_started', 'in_progress', 'completed'

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  String _formatDate(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchTasks({bool silent = false}) async {
    final requestSerial = ++_requestSerial;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final dateStr = _formatDate(_selectedDate);
    final res = await PerformanceService.getDailyTasks(
      date: dateStr,
      status: _selectedStatusFilter == 'semua' ? null : _selectedStatusFilter,
    );

    if (!mounted || requestSerial != _requestSerial) return;

    setState(() {
      _isLoading = false;
      if (res.success && res.data != null) {
        _tasks = res.data!.tasks;
        _kanbanColumns = res.data!.kanbanColumns;
      } else {
        _errorMessage = res.message;
      }
    });
  }

  void _shiftDay(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
    _fetchTasks();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
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
      setState(() {
        _selectedDate = picked;
      });
      _fetchTasks();
    }
  }

  void _openAddTaskModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => DailyTaskFormModal(
            initialDate: _formatDate(_selectedDate),
            onSuccess: () {
              _fetchTasks();
              widget.onDataChanged();
            },
          ),
    );
  }

  void _openEditTaskModal(DailyTaskItem task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => DailyTaskFormModal(
            initialDate: _formatDate(_selectedDate),
            initialTask: task,
            allowedKanbanColumnIds:
                _kanbanColumns.map((column) => column.id).toSet(),
            onSuccess: () {
              _fetchTasks();
              widget.onDataChanged();
            },
          ),
    );
  }

  Future<void> _quickToggleStatus(DailyTaskItem task) async {
    if (_busyTaskIds.contains(task.id)) return;
    String nextStatus;
    if (task.executionStatus == 'not_started') {
      nextStatus = 'in_progress';
    } else if (task.executionStatus == 'in_progress') {
      nextStatus = 'completed';
    } else {
      nextStatus = 'not_started';
    }

    setState(() => _busyTaskIds.add(task.id));
    final res = await PerformanceService.updateDailyTaskStatus(
      task.id,
      nextStatus,
    );
    if (!mounted) return;
    setState(() => _busyTaskIds.remove(task.id));

    if (res.success) {
      _fetchTasks(silent: true);
      widget.onDataChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status diubah ke ${_getStatusLabel(nextStatus)}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  Future<void> _carryForwardTask(DailyTaskItem task) async {
    final tomorrow = _selectedDate.add(const Duration(days: 1));
    final defaultNextDate = _formatDate(tomorrow);
    final movesLinkedTarget = task.isMonthlyTargetTask;

    final nextDateController = TextEditingController(text: defaultNextDate);

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
                  Icons.forward_to_inbox_rounded,
                  color: Color(0xFF0037B0),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Lanjutkan Tugas ke Hari Lain',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movesLinkedTarget
                      ? 'Target "${task.title}" akan dipindahkan ke tanggal tujuan dan disinkronkan dengan papan kinerja web.'
                      : 'Tugas "${task.title}" akan dibuat kembali pada tanggal tujuan. Catatan pada tanggal saat ini tetap tersimpan.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Pilih tanggal tujuan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nextDateController,
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: tomorrow,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 7),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) {
                      nextDateController.text = _formatDate(picked);
                    }
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    suffixIcon: const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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
                  backgroundColor: const Color(0xFF0037B0),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Pindahkan'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      if (_busyTaskIds.contains(task.id)) return;
      setState(() => _busyTaskIds.add(task.id));
      final nextDate = nextDateController.text.trim();
      final PerformanceApiResponse res;
      if (movesLinkedTarget) {
        res = await PerformanceService.updateDailyTask(task.id, {
          'execution_status': task.executionStatus,
          'due_at': task.dueAtForDate(nextDate),
        });
      } else {
        res = await PerformanceService.carryForwardDailyTask(task.id, nextDate);
      }
      if (!mounted) return;
      setState(() => _busyTaskIds.remove(task.id));

      if (res.success) {
        _fetchTasks();
        widget.onDataChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
  }

  Future<void> _deleteTask(DailyTaskItem task) async {
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
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Hapus Tugas Harian?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Text(
              'Tugas "${task.title}" akan dihapus. Rencana mingguan yang terhubung akan disesuaikan otomatis.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                color: const Color(0xFF475569),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      if (_busyTaskIds.contains(task.id)) return;
      setState(() => _busyTaskIds.add(task.id));
      final res = await PerformanceService.deleteDailyTask(task.id);
      if (!mounted) return;
      setState(() => _busyTaskIds.remove(task.id));

      if (res.success) {
        _fetchTasks();
        widget.onDataChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return const Color(0xFF0037B0);
      case 'not_started':
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Selesai';
      case 'in_progress':
        return 'Berjalan';
      case 'not_started':
        return 'Belum Mulai';
      default:
        return status;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red.shade700;
      case 'high':
        return Colors.orange.shade800;
      case 'low':
        return Colors.teal.shade700;
      case 'normal':
      default:
        return const Color(0xFF0037B0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday =
        DateFormat('yyyy-MM-dd').format(DateTime.now()) ==
        _formatDate(_selectedDate);

    final completedCount = _tasks.where((t) => t.isCompleted).length;
    final inProgressCount = _tasks.where((t) => t.isInProgress).length;
    final totalCount = _tasks.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date Selector Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _shiftDay(-1),
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Hari Sebelumnya',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.event_note_rounded,
                        size: 16,
                        color: Color(0xFF0037B0),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          DateFormat(
                            'EEEE, d MMMM yyyy',
                            'id_ID',
                          ).format(_selectedDate),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0037B0,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Hari Ini',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              color: const Color(0xFF0037B0),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _shiftDay(1),
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Hari Berikutnya',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Summary Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  label: 'Total',
                  value: '$totalCount',
                  icon: Icons.assignment_rounded,
                  color: const Color(0xFF0037B0),
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildSummaryItem(
                  label: 'Berjalan',
                  value: '$inProgressCount',
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFD97706),
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildSummaryItem(
                  label: 'Selesai',
                  value: '$completedCount',
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Action & Filter Row
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterChip('semua', 'Semua ($totalCount)'),
                    const SizedBox(width: 6),
                    _buildFilterChip('not_started', 'Belum Mulai'),
                    const SizedBox(width: 6),
                    _buildFilterChip('in_progress', 'Berjalan'),
                    const SizedBox(width: 6),
                    _buildFilterChip('completed', 'Selesai'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _openAddTaskModal,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                'Tambah',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0037B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Task List or Loading / Empty state
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: ArtechLoadingWidget(),
          )
        else if (_errorMessage != null)
          _buildErrorState()
        else if (_tasks.isEmpty)
          _buildEmptyState()
        else
          PerformancePaginatedList<DailyTaskItem>(
            items: _tasks,
            resetKey: '${_formatDate(_selectedDate)}-$_selectedStatusFilter',
            itemLabel: 'tugas',
            itemBuilder: (context, task, index) => _buildTaskCard(task),
          ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 5),
              Icon(icon, size: 15, color: color),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedStatusFilter == key;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatusFilter = key;
        });
        _fetchTasks();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0037B0) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0037B0) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(DailyTaskItem task) {
    final statusColor = _getStatusColor(task.executionStatus);
    final priorityColor = _getPriorityColor(task.priority);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              task.isCompleted
                  ? Colors.green.withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row Top: Status Toggle & Priority Badge
            Row(
              children: [
                // Quick Toggle Status Checkbox
                InkWell(
                  onTap: () => _quickToggleStatus(task),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color:
                          task.isCompleted
                              ? Colors.green.withValues(alpha: 0.15)
                              : (task.isInProgress
                                  ? const Color(
                                    0xFF0037B0,
                                  ).withValues(alpha: 0.12)
                                  : Colors.grey.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      task.isCompleted
                          ? Icons.check_circle_rounded
                          : (task.isInProgress
                              ? Icons.play_circle_fill_rounded
                              : Icons.radio_button_unchecked_rounded),
                      size: 18,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusLabel(task.executionStatus),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priority.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              task.title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: const Color(0xFF0F172A),
                decoration:
                    task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),

            // Details
            if (task.details != null && task.details!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.details!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],

            // Expected Output
            if (task.expectedOutput != null &&
                task.expectedOutput!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.outbox_rounded,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Target Output: ${task.expectedOutput}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 6),

            // Actions row: Carry-Forward, Edit, Delete
            Row(
              children: [
                // Carry forward button
                InkWell(
                  onTap: () => _carryForwardTask(task),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: Color(0xFF0037B0),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pindah ke Besok',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0037B0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Aksi tugas',
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: Color(0xFF64748B),
                  ),
                  onSelected: (action) {
                    if (action == 'edit') {
                      _openEditTaskModal(task);
                    } else if (action == 'delete') {
                      _deleteTask(task);
                    }
                  },
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Ubah tugas')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Hapus tugas',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_rounded,
            size: 44,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 10),
          Text(
            'Belum ada tugas',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan tugas untuk tanggal ini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _openAddTaskModal,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(
              'Tambah Tugas',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0037B0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Gagal memuat tugas harian',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _fetchTasks(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0037B0),
              foregroundColor: Colors.white,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
