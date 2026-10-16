import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/artech_loading_widget.dart';
import '../../data/models/performance_models.dart';
import '../../data/performance_service.dart';

class WeeklyReviewTab extends StatefulWidget {
  final VoidCallback onDataChanged;

  const WeeklyReviewTab({
    super.key,
    required this.onDataChanged,
  });

  @override
  State<WeeklyReviewTab> createState() => _WeeklyReviewTabState();
}

class _WeeklyReviewTabState extends State<WeeklyReviewTab> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  WeeklyReviewData? _reviewData;

  DateTime _currentWeekDate = DateTime.now();

  // Local state for editing review items
  final Map<int, String> _itemStatus = {};
  final Map<int, double> _itemProgress = {};
  final Map<int, TextEditingController> _obstacleControllers = {};
  final Map<int, TextEditingController> _improvementControllers = {};

  // Baseline snapshot from API to detect any user changes
  final Map<int, String> _initialStatus = {};
  final Map<int, int> _initialProgress = {};
  final Map<int, String> _initialObstacle = {};
  final Map<int, String> _initialImprovement = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    for (final c in _obstacleControllers.values) {
      c.dispose();
    }
    for (final c in _improvementControllers.values) {
      c.dispose();
    }
    super.dispose();
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
    final res = await PerformanceService.getWeeklyReview(weekDate: dateStr);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _reviewData = res.data;
          _initLocalFormState(res.data!);
        } else {
          _errorMessage = res.message;
        }
      });
    }
  }

  void _initLocalFormState(WeeklyReviewData data) {
    // Clear old controllers
    for (final c in _obstacleControllers.values) {
      c.dispose();
    }
    for (final c in _improvementControllers.values) {
      c.dispose();
    }
    _obstacleControllers.clear();
    _improvementControllers.clear();
    _itemStatus.clear();
    _itemProgress.clear();
    _initialStatus.clear();
    _initialProgress.clear();
    _initialObstacle.clear();
    _initialImprovement.clear();

    for (final plan in data.plans) {
      for (final item in plan.items) {
        final st = item.executionStatus;
        final prog = item.progressPercent.toDouble().clamp(0.0, 100.0);
        final obs = item.obstacle ?? '';
        final imp = item.improvementPlan ?? '';

        _itemStatus[item.id] = st;
        _itemProgress[item.id] = prog;
        _obstacleControllers[item.id] = TextEditingController(text: obs);
        _improvementControllers[item.id] = TextEditingController(text: imp);

        // Record initial baseline
        _initialStatus[item.id] = st;
        _initialProgress[item.id] = prog.round();
        _initialObstacle[item.id] = obs.trim();
        _initialImprovement[item.id] = imp.trim();
      }
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

  void _onStatusChanged(int itemId, String newStatus) {
    setState(() {
      _itemStatus[itemId] = newStatus;
      if (newStatus == 'completed') {
        _itemProgress[itemId] = 100.0;
      } else if (newStatus == 'not_started') {
        _itemProgress[itemId] = 0.0;
      } else if (newStatus == 'in_progress') {
        final current = _itemProgress[itemId] ?? 0.0;
        if (current <= 0.0 || current >= 100.0) {
          _itemProgress[itemId] = 50.0;
        }
      }
    });
  }

  bool get _hasAnyChanges {
    if (_reviewData == null || _initialStatus.isEmpty) return false;

    for (final plan in _reviewData!.plans) {
      for (final item in plan.items) {
        final id = item.id;
        final currentStatus = _itemStatus[id] ?? _initialStatus[id] ?? item.executionStatus;
        final initStatus = _initialStatus[id] ?? item.executionStatus;

        // 1. Status changed
        if (currentStatus != initStatus) return true;

        // 2. Progress changed (relevant when in_progress)
        if (currentStatus == 'in_progress') {
          final initProg = _initialProgress[id] ?? item.progressPercent.round();
          final currProg = (_itemProgress[id] ?? 0.0).round();
          if (currProg != initProg) return true;
        }

        // 3. Obstacle changed (relevant when not completed)
        if (currentStatus != 'completed') {
          final initObs = _initialObstacle[id] ?? '';
          final currObs = (_obstacleControllers[id]?.text ?? '').trim();
          if (currObs != initObs) return true;
        }

        // 4. Improvement plan changed (relevant when completed)
        if (currentStatus == 'completed') {
          final initImp = _initialImprovement[id] ?? '';
          final currImp = (_improvementControllers[id]?.text ?? '').trim();
          if (currImp != initImp) return true;
        }
      }
    }
    return false;
  }

  Future<void> _submitBatchReview() async {
    if (_reviewData == null) return;

    final allItems = <WeeklyReviewItem>[];
    for (final p in _reviewData!.plans) {
      allItems.addAll(p.items);
    }

    if (allItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada item untuk dievaluasi pada pekan ini.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final nav = Navigator.of(context, rootNavigator: true);
    setState(() => _isSubmitting = true);
    ArtechLoadingWidget.showLoadingDialog(context, message: 'Menyimpan & mengevaluasi...');

    late final PerformanceApiResponse<Map<String, dynamic>> res;

    try {
      final itemsPayload = <String, dynamic>{};
      for (final item in allItems) {
        final status = _itemStatus[item.id] ?? item.executionStatus;
        final isCompleted = status == 'completed';
        final isNotStarted = status == 'not_started';
        final progress = isCompleted ? 100 : (isNotStarted ? 0 : (_itemProgress[item.id]?.round() ?? 0));

        final improvement = isCompleted
            ? (_improvementControllers[item.id]?.text.trim().isNotEmpty == true
                ? _improvementControllers[item.id]!.text.trim()
                : null)
            : null;

        final obstacle = !isCompleted
            ? (_obstacleControllers[item.id]?.text.trim().isNotEmpty == true
                ? _obstacleControllers[item.id]!.text.trim()
                : null)
            : null;

        itemsPayload[item.id.toString()] = {
          'execution_status': status,
          'progress_percent': progress,
          'improvement_plan': improvement,
          'obstacle': obstacle,
        };
      }

      final dateStr = _formatDate(_currentWeekDate);
      res = await PerformanceService.submitWeeklyReviewBatch(
        weekDate: dateStr,
        items: itemsPayload,
      );
    } catch (e) {
      res = PerformanceApiResponse(
        success: false,
        statusCode: 0,
        message: 'Koneksi gagal atau bermasalah: $e',
      );
    } finally {
      // 1. Selalu pastikan loading dialog ditutup menggunakan navigator yang sudah ditangkap
      if (nav.canPop()) {
        nav.pop();
      }
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }

    if (!mounted) return;

    if (res.success) {
      for (final item in allItems) {
        final id = item.id;
        final currentStatus = _itemStatus[id] ?? item.executionStatus;
        final isCompleted = currentStatus == 'completed';
        final isNotStarted = currentStatus == 'not_started';
        final progress = isCompleted ? 100 : (isNotStarted ? 0 : (_itemProgress[id]?.round() ?? 0));
        _initialStatus[id] = currentStatus;
        _initialProgress[id] = progress;
        _initialObstacle[id] = (_obstacleControllers[id]?.text ?? '').trim();
        _initialImprovement[id] = (_improvementControllers[id]?.text ?? '').trim();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res.message,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      _fetchData(silent: true);
      widget.onDataChanged();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message, style: GoogleFonts.plusJakartaSans()),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
        // Week Date Navigation Bar
        _buildWeekNavigator(),
        const SizedBox(height: 16),

        if (_isLoading)
          ArtechLoadingWidget.page(
            message: 'Memuat review mingguan...',
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
          _buildReviewContent(),
      ],
    );
  }

  Widget _buildWeekNavigator() {
    final label = _reviewData?.week.label.isNotEmpty == true
        ? _reviewData!.week.label
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
                            'Pekan Evaluasi',
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

  Widget _buildReviewContent() {
    final data = _reviewData;
    if (data == null) return const SizedBox.shrink();

    final allItems = <WeeklyReviewItem>[];
    for (final p in data.plans) {
      allItems.addAll(p.items);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Review Timing Banner
        _buildTimingBanner(data),
        const SizedBox(height: 14),

        // Summary Scorecard
        _buildSummaryScorecard(data.summary),
        const SizedBox(height: 16),

        // Guidelines Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0037B0).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0037B0).withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF0037B0)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aturan Evaluasi: Jika status "Selesai", progres otomatis 100% dan isi rencana perbaikan. Jika "Sedang Berjalan", isi kendala yang dihadapi. Sistem akan otomatis menghitung ulang capaian Anda.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF475569), height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Item Evaluasi Mingguan (${allItems.length})',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (allItems.isEmpty)
          _buildEmptyState()
        else ...[
          ...allItems.map((item) => _buildReviewItemCard(item)),
          const SizedBox(height: 16),

          // Submit Batch Button (Only visible when user makes changes)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, child: child),
            ),
            child: _hasAnyChanges
                ? Padding(
                    key: const ValueKey('submit_btn_visible'),
                    padding: const EdgeInsets.only(bottom: 20),
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitBatchReview,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        'Simpan Sekaligus (${allItems.length} Item Evaluasi)',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0037B0),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                    ),
                  )
                : const SizedBox(
                    key: ValueKey('submit_btn_hidden'),
                    height: 12,
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimingBanner(WeeklyReviewData data) {
    final timing = data.reviewTiming ?? 'upcoming';
    final isUpcoming = timing.toLowerCase() == 'upcoming';
    final reviewDate = data.reviewDate ?? '-';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isUpcoming ? AppColors.secondary : Colors.green).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUpcoming ? Icons.schedule_rounded : Icons.check_circle_outline_rounded,
              color: isUpcoming ? AppColors.secondary : Colors.green,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jadwal Review Akhir Pekan',
                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                Text(
                  reviewDate,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isUpcoming ? AppColors.secondary : Colors.green).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isUpcoming ? 'UPCOMING' : 'AKTIF',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isUpcoming ? AppColors.secondary : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryScorecard(WeeklyReviewSummary summary) {
    final avg = summary.averageProgress.toDouble().clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // Circular Progress Indicator
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: avg / 100.0,
                  strokeWidth: 6,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    avg >= 80 ? Colors.green : const Color(0xFF0037B0),
                  ),
                ),
                Center(
                  child: Text(
                    '${avg.toStringAsFixed(0)}%',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: const Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Stats text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rata-rata Capaian Pekan Ini',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${summary.completedItems} dari ${summary.totalItems} target selesai',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: summary.totalItems > 0 ? (summary.completedItems / summary.totalItems) : 0,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItemCard(WeeklyReviewItem item) {
    final status = _itemStatus[item.id] ?? item.executionStatus;
    final isCompleted = status == 'completed';
    final isNotStarted = status == 'not_started';
    final isInProgress = !isCompleted && !isNotStarted;
    final priorityColor = _getPriorityColor(item.priority);
    final progress = _itemProgress[item.id] ?? 0.0;

    final obstacleController = _obstacleControllers[item.id];
    final improvementController = _improvementControllers[item.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withValues(alpha: 0.5)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
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
            // Top Header: Priority & Title
            Row(
              children: [
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
                const Spacer(),
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '100% SELESAI',
                          style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5, color: const Color(0xFF0F172A)),
            ),
            if (item.expectedOutput != null && item.expectedOutput!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Target: ${item.expectedOutput}',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 12),

            // Status Selector Tabs
            Text(
              'Evaluasi Status:',
              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildStatusChoice(item.id, 'completed', 'Selesai', Colors.green, Icons.check_circle_outline_rounded),
                const SizedBox(width: 6),
                _buildStatusChoice(item.id, 'in_progress', 'Berjalan', const Color(0xFF0037B0), Icons.timelapse_rounded),
                const SizedBox(width: 6),
                _buildStatusChoice(item.id, 'not_started', 'Belum', const Color(0xFF64748B), Icons.cancel_outlined),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Slider
            if (isInProgress) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Capaian Progres:',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                  ),
                  Text(
                    '${progress.round()}%',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w800, color: const Color(0xFF0037B0)),
                  ),
                ],
              ),
              Slider(
                value: progress.clamp(1.0, 99.0),
                min: 1,
                max: 99,
                divisions: 98,
                activeColor: const Color(0xFF0037B0),
                onChanged: (val) {
                  setState(() {
                    _itemProgress[item.id] = val;
                  });
                },
              ),
            ] else if (isNotStarted) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Capaian Progres:',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 11, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '0% (Belum Dimulai)',
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  disabledThumbColor: const Color(0xFFCBD5E1),
                  disabledActiveTrackColor: const Color(0xFFE2E8F0),
                  disabledInactiveTrackColor: const Color(0xFFF8FAFC),
                ),
                child: const Slider(
                  value: 0,
                  min: 0,
                  max: 100,
                  onChanged: null,
                ),
              ),
            ],

            // Input Fields based on rule
            if (isCompleted) ...[
              // Improvement Plan Field
              Text(
                'Rencana Perbaikan (Improvement Plan)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade800,
                ),
              ),
              const SizedBox(height: 4),
              if (improvementController != null)
                TextFormField(
                  controller: improvementController,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Misal: Mulai integrasi lebih awal di awal pekan agar testing lebih maksimal...',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0037B0), width: 1.5),
                    ),
                  ),
                ),
            ] else ...[
              // Obstacle Field
              Text(
                'Kendala yang Dihadapi (Obstacle)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 4),
              if (obstacleController != null)
                TextFormField(
                  controller: obstacleController,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.plusJakartaSans(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Misal: Menunggu konfirmasi aset dari tim desain atau akses kredensial gateway...',
                    hintStyle: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0037B0), width: 1.5),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChoice(
    int itemId,
    String value,
    String label,
    Color activeColor,
    IconData icon,
  ) {
    final isSelected = (_itemStatus[itemId] ?? '') == value;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onStatusChanged(itemId, value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? activeColor : const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
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
      child: const Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 48, color: AppColors.outline),
          SizedBox(height: 12),
          Text(
            'Tidak Ada Item Evaluasi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            'Belum ada aktivitas mingguan yang terdaftar pada pekan ini untuk dievaluasi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
