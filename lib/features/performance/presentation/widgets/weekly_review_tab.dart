import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/artech_loading_widget.dart';
import '../../data/models/performance_models.dart';
import '../../data/performance_service.dart';
import 'performance_paginated_list.dart';

class WeeklyReviewTab extends StatefulWidget {
  final VoidCallback onDataChanged;

  const WeeklyReviewTab({super.key, required this.onDataChanged});

  @override
  State<WeeklyReviewTab> createState() => _WeeklyReviewTabState();
}

class _WeeklyReviewTabState extends State<WeeklyReviewTab> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  WeeklyReviewData? _reviewData;
  int _requestSerial = 0;

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
  final Set<int> _expandedParentIds = {};

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
    final requestSerial = ++_requestSerial;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final dateStr = _formatDate(_currentWeekDate);
    final res = await PerformanceService.getWeeklyReview(weekDate: dateStr);

    if (!mounted || requestSerial != _requestSerial) return;

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

  /// Mendapatkan semua item yang dapat direview sesuai aturan API:
  /// - Jika target induk memiliki sub_items, ambil setiap sub-target di dalamnya.
  /// - Jika sub_items kosong, ambil target tersebut secara langsung.
  List<WeeklyReviewItem> get _reviewableItems {
    final list = <WeeklyReviewItem>[];
    if (_reviewData == null) return list;
    for (final plan in _reviewData!.plans) {
      for (final item in plan.items) {
        if (item.hasSubItems) {
          list.addAll(item.subItems);
        } else {
          list.add(item);
        }
      }
    }
    return list;
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

    final activeParentIds = <int>{};
    for (final plan in data.plans) {
      activeParentIds.addAll(
        plan.items.where((item) => item.hasSubItems).map((item) => item.id),
      );
    }
    _expandedParentIds.removeWhere((id) => !activeParentIds.contains(id));

    for (final plan in data.plans) {
      for (final item in plan.items) {
        // Inisialisasi item yang dapat direview: jika punya sub_items, inisialisasi sub_items
        final targetsToInit = item.hasSubItems ? item.subItems : [item];
        for (final target in targetsToInit) {
          final st = target.executionStatus;
          final prog = target.progressPercent.toDouble().clamp(0.0, 100.0);
          final obs = target.obstacle ?? '';
          final imp = target.improvementPlan ?? '';

          _itemStatus[target.id] = st;
          _itemProgress[target.id] = prog;
          _obstacleControllers[target.id] = TextEditingController(text: obs);
          _improvementControllers[target.id] = TextEditingController(text: imp);

          // Record initial baseline
          _initialStatus[target.id] = st;
          _initialProgress[target.id] = prog.round();
          _initialObstacle[target.id] = obs.trim();
          _initialImprovement[target.id] = imp.trim();
        }
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

    for (final target in _reviewableItems) {
      final id = target.id;
      final currentStatus =
          _itemStatus[id] ?? _initialStatus[id] ?? target.executionStatus;
      final initStatus = _initialStatus[id] ?? target.executionStatus;

      // 1. Status changed
      if (currentStatus != initStatus) return true;

      // 2. Progress changed (relevant when in_progress)
      if (currentStatus == 'in_progress') {
        final initProg = _initialProgress[id] ?? target.progressPercent.round();
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
    return false;
  }

  Future<void> _submitBatchReview() async {
    if (_reviewData == null) return;

    final reviewable = _reviewableItems;

    if (reviewable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada item untuk dievaluasi pada pekan ini.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final missingObstacle =
        reviewable.where((item) {
          final status = _itemStatus[item.id] ?? item.executionStatus;
          return status != 'completed' &&
              (_obstacleControllers[item.id]?.text.trim().isEmpty ?? true);
        }).toList();
    if (missingObstacle.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Isi kendala untuk ${missingObstacle.length} item yang belum selesai sebelum menyimpan.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final nav = Navigator.of(context, rootNavigator: true);
    setState(() => _isSubmitting = true);
    ArtechLoadingWidget.showLoadingDialog(
      context,
      message: 'Menyimpan & mengevaluasi...',
    );

    late final PerformanceApiResponse<Map<String, dynamic>> res;

    try {
      final itemsPayload = <String, dynamic>{};
      for (final item in reviewable) {
        final status = _itemStatus[item.id] ?? item.executionStatus;
        final isCompleted = status == 'completed';
        final isNotStarted = status == 'not_started';
        final progress =
            isCompleted
                ? 100
                : (isNotStarted ? 0 : (_itemProgress[item.id]?.round() ?? 0));

        final improvement =
            isCompleted
                ? (_improvementControllers[item.id]?.text.trim().isNotEmpty ==
                        true
                    ? _improvementControllers[item.id]!.text.trim()
                    : null)
                : null;

        final obstacle =
            !isCompleted
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
      debugPrint(
        '[WeeklyReviewTab] Submitting batch review for $dateStr with ${itemsPayload.length} items...',
      );
      res = await PerformanceService.submitWeeklyReviewBatch(
        weekDate: dateStr,
        items: itemsPayload,
      );
    } catch (e) {
      debugPrint('[WeeklyReviewTab] Error submitting review: $e');
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
      // Perbarui baseline sesuai response server atau input lokal
      if (res.data != null && res.data!['items'] is List) {
        for (final rawItem in res.data!['items']) {
          if (rawItem is Map) {
            final id =
                rawItem['id'] is int
                    ? rawItem['id']
                    : int.tryParse(rawItem['id'].toString());
            if (id != null) {
              final status =
                  rawItem['execution_status']?.toString() ?? 'not_started';
              final prog =
                  (rawItem['progress_percent'] ?? 0) is num
                      ? (rawItem['progress_percent'] as num).round()
                      : 0;
              final obs = rawItem['obstacle']?.toString() ?? '';
              final imp = rawItem['improvement_plan']?.toString() ?? '';

              _initialStatus[id] = status;
              _initialProgress[id] = prog;
              _initialObstacle[id] = obs.trim();
              _initialImprovement[id] = imp.trim();

              _itemStatus[id] = status;
              _itemProgress[id] = prog.toDouble();
              _obstacleControllers[id]?.text = obs;
              _improvementControllers[id]?.text = imp;
            }
          }
        }
      } else {
        for (final item in reviewable) {
          final id = item.id;
          final currentStatus = _itemStatus[id] ?? item.executionStatus;
          final isCompleted = currentStatus == 'completed';
          final isNotStarted = currentStatus == 'not_started';
          final progress =
              isCompleted
                  ? 100
                  : (isNotStarted ? 0 : (_itemProgress[id]?.round() ?? 0));
          _initialStatus[id] = currentStatus;
          _initialProgress[id] = progress;
          _initialObstacle[id] = (_obstacleControllers[id]?.text ?? '').trim();
          _initialImprovement[id] =
              (_improvementControllers[id]?.text ?? '').trim();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res.message,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
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
            duration: const Duration(seconds: 5),
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
          ArtechLoadingWidget.page(message: 'Memuat review mingguan...')
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
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
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
    final label =
        _reviewData?.week.label.isNotEmpty == true
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
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF0037B0),
            ),
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
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: Color(0xFF0037B0),
                      ),
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
                    const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF0037B0),
            ),
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

    final reviewable = _reviewableItems;
    final reviewSections = data.plans
        .expand((plan) => plan.items)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Review Timing Banner
        _buildTimingBanner(data),
        const SizedBox(height: 14),

        // Summary Scorecard (dihitung dari item yang dapat direview)
        _buildSummaryScorecard(data.summary),
        const SizedBox(height: 16),

        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Evaluasi (${reviewable.length})',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (reviewable.isEmpty)
          _buildEmptyState()
        else ...[
          PerformancePaginatedList<WeeklyReviewItem>(
            items: reviewSections,
            resetKey: data.week.start,
            spacing: 0,
            itemLabel: 'evaluasi',
            itemBuilder: (context, item, index) {
              if (item.hasSubItems) {
                return _buildParentTargetSection(item);
              }
              return _buildReviewItemCard(item);
            },
          ),
          const SizedBox(height: 16),

          // Submit Batch Button (Only visible when user makes changes)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder:
                (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SizeTransition(sizeFactor: animation, child: child),
                ),
            child:
                _hasAnyChanges
                    ? Padding(
                      key: const ValueKey('submit_btn_visible'),
                      padding: const EdgeInsets.only(bottom: 20),
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitBatchReview,
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          'Simpan ${reviewable.length} Item Evaluasi',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0037B0),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
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
              color: (isUpcoming ? AppColors.secondary : Colors.green)
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUpcoming
                  ? Icons.schedule_rounded
                  : Icons.check_circle_outline_rounded,
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
                  'Jadwal Evaluasi Mingguan',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  reviewDate,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isUpcoming ? AppColors.secondary : Colors.green)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isUpcoming ? 'TERJADWAL' : 'AKTIF',
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
    final reviewable = _reviewableItems;
    final total =
        reviewable.isNotEmpty ? reviewable.length : summary.totalItems;
    final completed =
        reviewable.isNotEmpty
            ? reviewable
                .where(
                  (i) =>
                      (_itemStatus[i.id] ?? i.executionStatus) == 'completed',
                )
                .length
            : summary.completedItems;
    final avg =
        reviewable.isNotEmpty
            ? (reviewable.fold<double>(
                      0.0,
                      (acc, i) =>
                          acc +
                          (_itemProgress[i.id] ?? i.progressPercent.toDouble()),
                    ) /
                    total)
                .clamp(0.0, 100.0)
            : summary.averageProgress.toDouble().clamp(0.0, 100.0);

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
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: const Color(0xFF0F172A),
                    ),
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$completed dari $total item target selesai',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? (completed / total) : 0,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Membangun tampilan target induk yang memiliki sub_items
  /// Status dan progresnya dihitung otomatis dari seluruh sub-target
  Widget _buildParentTargetSection(WeeklyReviewItem parent) {
    final priorityColor = _getPriorityColor(parent.priority);
    final isExpanded = _expandedParentIds.contains(parent.id);

    final subItems = parent.subItems;
    final totalSubs = subItems.length;
    final completedSubs =
        subItems
            .where(
              (s) => (_itemStatus[s.id] ?? s.executionStatus) == 'completed',
            )
            .length;
    final notStartedSubs =
        subItems
            .where(
              (s) => (_itemStatus[s.id] ?? s.executionStatus) == 'not_started',
            )
            .length;

    final double avgProg =
        subItems.isEmpty
            ? 0.0
            : (subItems.fold<double>(
                      0.0,
                      (acc, s) =>
                          acc +
                          (_itemProgress[s.id] ?? s.progressPercent.toDouble()),
                    ) /
                    totalSubs)
                .clamp(0.0, 100.0);

    final bool allCompleted = totalSubs > 0 && completedSubs == totalSubs;
    final bool allNotStarted = totalSubs > 0 && notStartedSubs == totalSubs;

    final String parentStatusLabel =
        allCompleted
            ? '100% SELESAI'
            : (allNotStarted
                ? '0% BELUM DIMULAI'
                : '${avgProg.round()}% BERJALAN');
    final Color parentStatusColor =
        allCompleted
            ? Colors.green
            : (allNotStarted
                ? const Color(0xFF64748B)
                : const Color(0xFF0037B0));

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              allCompleted
                  ? Colors.green.withValues(alpha: 0.4)
                  : const Color(0xFF0037B0).withValues(alpha: 0.25),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0037B0).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Target Induk
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0037B0).withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0037B0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.account_tree_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'INDUK',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              parent.priority.toUpperCase(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                color: priorityColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: parentStatusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          parentStatusLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: parentStatusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  parent.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (parent.expectedOutput != null &&
                    parent.expectedOutput!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Target: ${parent.expectedOutput}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: avgProg / 100.0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      allCompleted ? Colors.green : const Color(0xFF0037B0),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedParentIds.remove(parent.id);
                        } else {
                          _expandedParentIds.add(parent.id);
                        }
                      });
                    },
                    icon: Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isExpanded
                          ? 'Sembunyikan sub-target'
                          : 'Tampilkan $totalSubs sub-target',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0037B0),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(44, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // Daftar Sub-target
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Sub-target yang dievaluasi (${parent.subItems.length})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                  ),
                  ...parent.subItems.map(
                    (sub) => _buildReviewItemCard(sub, isSubItem: true),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewItemCard(WeeklyReviewItem item, {bool isSubItem = false}) {
    final status = _itemStatus[item.id] ?? item.executionStatus;
    final isCompleted = status == 'completed';
    final isNotStarted = status == 'not_started';
    final isInProgress = !isCompleted && !isNotStarted;
    final priorityColor = _getPriorityColor(item.priority);
    final progress = _itemProgress[item.id] ?? 0.0;

    final obstacleController = _obstacleControllers.putIfAbsent(
      item.id,
      () => TextEditingController(text: item.obstacle ?? ''),
    );
    final improvementController = _improvementControllers.putIfAbsent(
      item.id,
      () => TextEditingController(text: item.improvementPlan ?? ''),
    );

    return Container(
      margin: EdgeInsets.only(bottom: isSubItem ? 10 : 14),
      decoration: BoxDecoration(
        color: isSubItem ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isCompleted
                  ? Colors.green.withValues(alpha: 0.5)
                  : (isSubItem
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFFE2E8F0)),
          width: isSubItem ? 1.0 : 1.2,
        ),
        boxShadow:
            isSubItem
                ? null
                : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Priority & Title
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (isSubItem)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF475569,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.subdirectory_arrow_right_rounded,
                                size: 10,
                                color: Color(0xFF475569),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'RINCIAN',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.priority.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            color: priorityColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (item.targetDate != null &&
                          item.targetDate!.isNotEmpty)
                        Text(
                          '• ${item.targetDate}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '100% SELESAI',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: const Color(0xFF0F172A),
              ),
            ),
            if (item.expectedOutput != null &&
                item.expectedOutput!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                'Target: ${item.expectedOutput}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
            if (item.details != null && item.details!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.details!,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Status Selector Tabs
            Text(
              'Evaluasi Status:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final choices = [
                  _buildStatusChoice(
                    item.id,
                    'completed',
                    'Selesai',
                    Colors.green,
                    Icons.check_circle_outline_rounded,
                  ),
                  _buildStatusChoice(
                    item.id,
                    'in_progress',
                    'Berjalan',
                    const Color(0xFF0037B0),
                    Icons.timelapse_rounded,
                  ),
                  _buildStatusChoice(
                    item.id,
                    'not_started',
                    'Belum Mulai',
                    const Color(0xFF64748B),
                    Icons.cancel_outlined,
                  ),
                ];

                if (constraints.maxWidth < 330) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      choices[0],
                      const SizedBox(height: 6),
                      choices[1],
                      const SizedBox(height: 6),
                      choices[2],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: choices[0]),
                    const SizedBox(width: 6),
                    Expanded(child: choices[1]),
                    const SizedBox(width: 6),
                    Expanded(child: choices[2]),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Progress Slider
            if (isInProgress) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Capaian Progres:',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  Text(
                    '${progress.round()}%',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0037B0),
                    ),
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
                  Flexible(
                    child: Text(
                      'Capaian Progres:',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 11,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '0% (Belum Dimulai)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
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
              TextFormField(
                controller: improvementController,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.plusJakartaSans(fontSize: 12),
                decoration: InputDecoration(
                  hintText:
                      'Misal: Mulai integrasi lebih awal di awal pekan agar testing lebih maksimal...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
                    borderSide: const BorderSide(
                      color: Color(0xFF0037B0),
                      width: 1.5,
                    ),
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
              TextFormField(
                controller: obstacleController,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.plusJakartaSans(fontSize: 12),
                decoration: InputDecoration(
                  hintText:
                      'Misal: Menunggu konfirmasi aset dari tim desain atau akses kredensial gateway...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
                    borderSide: const BorderSide(
                      color: Color(0xFF0037B0),
                      width: 1.5,
                    ),
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onStatusChanged(itemId, value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? activeColor.withValues(alpha: 0.12)
                  : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : const Color(0xFF64748B),
                ),
              ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: const Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 48, color: AppColors.outline),
          SizedBox(height: 12),
          Text(
            'Belum ada evaluasi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            'Tidak ada aktivitas untuk pekan ini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
