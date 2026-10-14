import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/artech_loading_widget.dart';
import '../../data/models/performance_models.dart';
import '../../data/performance_service.dart';
import 'weekly_plan_form_modal.dart';
import 'update_plan_item_modal.dart';

class WeeklyPlanTab extends StatefulWidget {
  final VoidCallback onDataChanged;

  const WeeklyPlanTab({
    super.key,
    required this.onDataChanged,
  });

  @override
  State<WeeklyPlanTab> createState() => _WeeklyPlanTabState();
}

class _WeeklyPlanTabState extends State<WeeklyPlanTab> {
  bool _isLoading = true;
  String? _errorMessage;
  WeeklyPlanData? _planData;

  DateTime _currentWeekDate = DateTime.now();

  // Track expanded daily task sections
  final Set<int> _expandedItemIds = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  String _formatDate(DateTime dt) {
    return "${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final dateStr = _formatDate(_currentWeekDate);
    final res = await PerformanceService.getWeeklyPlan(weekDate: dateStr);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _planData = res.data;
        } else {
          _errorMessage = res.message;
        }
      });
    }
  }

  void _shiftWeek(int days) {
    setState(() {
      _currentWeekDate = _currentWeekDate.add(Duration(days: days));
    });
    _fetchData();
  }

  Future<void> _pickWeekDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentWeekDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _currentWeekDate = picked;
      });
      _fetchData();
    }
  }

  void _openAddPlanModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WeeklyPlanFormModal(
        weekDate: _formatDate(_currentWeekDate),
        onSuccess: () {
          _fetchData();
          widget.onDataChanged();
        },
      ),
    );
  }

  void _openUpdateItemModal(WeeklyPlanItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UpdatePlanItemModal(
        item: item,
        onSuccess: () {
          _fetchData();
          widget.onDataChanged();
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return AppColors.primaryContainer;
      case 'not_started':
      default:
        return AppColors.onSurfaceVariant;
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
        return AppColors.error;
      case 'high':
        return Colors.orange.shade800;
      case 'normal':
        return AppColors.primary;
      case 'low':
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Week Date Navigation Card
        _buildWeekNavigator(),
        const SizedBox(height: 16),

        if (_isLoading)
          ArtechLoadingWidget.page(
            message: 'Memuat rencana mingguan...',
          )
        else if (_errorMessage != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _fetchData(),
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
          )
        else
          _buildPlanContent(),
      ],
    );
  }

  Widget _buildWeekNavigator() {
    final label = _planData?.week.label.isNotEmpty == true
        ? _planData!.week.label
        : _formatDate(_currentWeekDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF0037B0)),
            onPressed: () => _shiftWeek(-7),
            tooltip: 'Pekan Sebelumnya',
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: InkWell(
              onTap: _pickWeekDate,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0037B0).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0037B0)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Pekan Berjalan',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B), size: 20),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF0037B0)),
            onPressed: () => _shiftWeek(7),
            tooltip: 'Pekan Berikutnya',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanContent() {
    final plans = _planData?.plans ?? [];
    final allItems = <WeeklyPlanItem>[];
    for (final p in plans) {
      allItems.addAll(p.items);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action Header with overflow protection
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktivitas & Sub-Task',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${allItems.length} Rencana Terjadwal',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _openAddPlanModal,
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                'Rencana Mandiri',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0037B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (allItems.isEmpty)
          _buildEmptyState()
        else
          ...plans.map((planGroup) => _buildPlanGroupSection(planGroup)),
      ],
    );
  }

  Widget _buildPlanGroupSection(WeeklyPlanGroup planGroup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Plan status banner
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
          ),
          child: Row(
            children: [
              const Icon(Icons.assignment_outlined, size: 16, color: Color(0xFF0037B0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  planGroup.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0037B0).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'STATUS: ${planGroup.approvalStatus.toUpperCase()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0037B0),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Plan Items
        ...planGroup.items.map((item) => _buildPlanItemCard(item)),
      ],
    );
  }

  Widget _buildPlanItemCard(WeeklyPlanItem item) {
    final statusColor = _getStatusColor(item.executionStatus);
    final priorityColor = _getPriorityColor(item.priority);
    final isExpanded = _expandedItemIds.contains(item.id);
    final percent = item.progressPercent.toDouble().clamp(0.0, 100.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badges: Wrap to prevent right overflow
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (item.monthlyTargetTitle != null && item.monthlyTargetTitle!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0037B0).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.link_rounded, size: 11, color: Color(0xFF0037B0)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            item.monthlyTargetTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0037B0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'MANDIRI',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.priority.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(fontSize: 9, color: priorityColor, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getStatusLabel(item.executionStatus),
                    style: GoogleFonts.plusJakartaSans(fontSize: 9, color: statusColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              item.title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: const Color(0xFF0F172A),
              ),
            ),

            // Details or Expected Output
            if (item.details != null && item.details!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.details!,
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ],
            if (item.expectedOutput != null && item.expectedOutput!.isNotEmpty) ...[
              const SizedBox(height: 6),
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
                    const Icon(Icons.outbox_rounded, size: 14, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Target Output: ${item.expectedOutput}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Progress Bar & Percentage
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percent / 100.0,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percent == 100 ? Colors.green : const Color(0xFF0037B0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: percent == 100 ? Colors.green : const Color(0xFF0037B0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Date Range & Action Buttons with Wrap/Flexible layout to prevent overflow
            Row(
              children: [
                if (item.startDate != null || item.targetDate != null) ...[
                  const Icon(Icons.event, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${item.startDate ?? '-'} s/d ${item.targetDate ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontSize: 10.5, color: const Color(0xFF64748B)),
                    ),
                  ),
                ] else
                  const Spacer(),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _openUpdateItemModal(item),
                  icon: const Icon(Icons.edit_outlined, size: 13),
                  label: Text(
                    'Edit Rincian',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0037B0),
                    side: const BorderSide(color: Color(0xFF0037B0), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),

            // Daily Tasks section if present
            if (item.dailyTasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedItemIds.remove(item.id);
                    } else {
                      _expandedItemIds.add(item.id);
                    }
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Tasks (${item.dailyTasks.length})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.outline,
                    ),
                  ],
                ),
              ),
              if (isExpanded) ...[
                const SizedBox(height: 6),
                ...item.dailyTasks.map((dt) {
                  final dtColor = _getStatusColor(dt.executionStatus);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          dt.executionStatus == 'completed'
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 14,
                          color: dtColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dt.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                              if (dt.workDate != null)
                                Text(
                                  dt.workDate!,
                                  style: const TextStyle(fontSize: 9, color: AppColors.outline),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: dtColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${dt.progressPercent}%',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: dtColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.date_range, size: 48, color: AppColors.outline),
          const SizedBox(height: 12),
          const Text(
            'Belum ada Rencana Mingguan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Target mingguan dari Menu Target Bulanan otomatis muncul di sini, atau Anda dapat menambah rencana mandiri.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openAddPlanModal,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Tambah Rencana Mandiri', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
