// Performance Data Models

class MonthlyTargetSummary {
  final int totalMain;
  final int totalWeekly;
  final int completedWeekly;
  final num progressPercent;

  MonthlyTargetSummary({
    required this.totalMain,
    required this.totalWeekly,
    required this.completedWeekly,
    required this.progressPercent,
  });

  factory MonthlyTargetSummary.fromJson(Map<String, dynamic> json) {
    return MonthlyTargetSummary(
      totalMain: json['total_main'] ?? 0,
      totalWeekly: json['total_weekly'] ?? 0,
      completedWeekly: json['completed_weekly'] ?? 0,
      progressPercent: json['progress_percent'] ?? 0,
    );
  }
}

class MonthlyTargetItem {
  final int id;
  final int? parentId;
  final String level; // 'main', 'weekly', 'daily'
  final String title;
  final String? expectedResults;
  final String status; // 'not_started', 'in_progress', 'completed', etc.
  final String priority; // 'high', 'normal', 'low', 'urgent'
  final String? approvalStatus; // 'approved', 'pending', 'rejected', dll.
  final String? picName;
  final String? startDate;
  final String? deadline;
  final String? notes;
  final List<MonthlyTargetItem> children;

  MonthlyTargetItem({
    required this.id,
    this.parentId,
    required this.level,
    required this.title,
    this.expectedResults,
    required this.status,
    required this.priority,
    this.approvalStatus,
    this.picName,
    this.startDate,
    this.deadline,
    this.notes,
    this.children = const [],
  });

  factory MonthlyTargetItem.fromJson(Map<String, dynamic> json) {
    var rawChildren = json['children'] as List<dynamic>? ?? [];
    List<MonthlyTargetItem> childList =
        rawChildren
            .map((e) => MonthlyTargetItem.fromJson(e as Map<String, dynamic>))
            .toList();

    return MonthlyTargetItem(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      parentId:
          json['parent_id'] != null
              ? (json['parent_id'] is int
                  ? json['parent_id']
                  : int.tryParse(json['parent_id'].toString()))
              : null,
      level: json['level']?.toString() ?? 'main',
      title: json['title']?.toString() ?? '',
      expectedResults: json['expected_results']?.toString(),
      status:
          json['status']?.toString() ??
          json['execution_status']?.toString() ??
          'not_started',
      priority: json['priority']?.toString() ?? 'normal',
      approvalStatus: json['approval_status']?.toString(),
      picName: json['pic_name']?.toString(),
      startDate: json['start_date']?.toString(),
      deadline: json['deadline']?.toString(),
      notes: json['notes']?.toString(),
      children: childList,
    );
  }
}

class MonthlyTargetData {
  final int year;
  final String currentPeriod;
  final List<String> availablePeriods;
  final List<MonthlyTargetItem> targets;
  final MonthlyTargetSummary summary;

  MonthlyTargetData({
    required this.year,
    required this.currentPeriod,
    required this.availablePeriods,
    required this.targets,
    required this.summary,
  });

  factory MonthlyTargetData.fromJson(Map<String, dynamic> json) {
    var rawTargets = json['targets'] as List<dynamic>? ?? [];
    var rawPeriods = json['available_periods'] as List<dynamic>? ?? [];

    return MonthlyTargetData(
      year:
          json['year'] is int
              ? json['year']
              : int.tryParse(json['year']?.toString() ?? '') ??
                  DateTime.now().year,
      currentPeriod: json['current_period']?.toString() ?? '',
      availablePeriods: rawPeriods.map((e) => e.toString()).toList(),
      targets:
          rawTargets
              .map((e) => MonthlyTargetItem.fromJson(e as Map<String, dynamic>))
              .toList(),
      summary:
          json['summary'] != null
              ? MonthlyTargetSummary.fromJson(
                json['summary'] as Map<String, dynamic>,
              )
              : MonthlyTargetSummary(
                totalMain: 0,
                totalWeekly: 0,
                completedWeekly: 0,
                progressPercent: 0,
              ),
    );
  }
}

class WeekInfo {
  final String start;
  final String end;
  final int isoYear;
  final int isoWeek;
  final String label;

  WeekInfo({
    required this.start,
    required this.end,
    required this.isoYear,
    required this.isoWeek,
    required this.label,
  });

  factory WeekInfo.fromJson(Map<String, dynamic> json) {
    return WeekInfo(
      start: json['start']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
      isoYear:
          json['iso_year'] is int
              ? json['iso_year']
              : int.tryParse(json['iso_year']?.toString() ?? '') ?? 0,
      isoWeek:
          json['iso_week'] is int
              ? json['iso_week']
              : int.tryParse(json['iso_week']?.toString() ?? '') ?? 0,
      label: json['label']?.toString() ?? '',
    );
  }
}

class DailyTaskItem {
  final int id;
  final int? weeklyPlanItemId;
  final int? monthlyTargetId;
  final int? kanbanColumnId;
  final String title;
  final String? workDate;
  final String? dueAt;
  final String? details;
  final String priority;
  final String executionStatus;
  final num progressPercent;
  final String? obstacle;
  final String? improvementPlan;
  final String? expectedOutput;

  DailyTaskItem({
    required this.id,
    this.weeklyPlanItemId,
    this.monthlyTargetId,
    this.kanbanColumnId,
    required this.title,
    this.workDate,
    this.dueAt,
    this.details,
    this.priority = 'normal',
    required this.executionStatus,
    required this.progressPercent,
    this.obstacle,
    this.improvementPlan,
    this.expectedOutput,
  });

  bool get isCompleted => executionStatus.toLowerCase() == 'completed';
  bool get isInProgress => executionStatus.toLowerCase() == 'in_progress';
  bool get isNotStarted =>
      executionStatus.toLowerCase() == 'not_started' || executionStatus.isEmpty;

  bool get isMonthlyTargetTask => monthlyTargetId != null;

  /// Date-only value used by the mobile date picker. `due_at` is authoritative
  /// when the API returns it, while `work_date` remains the list/filter date.
  String? get effectiveDate {
    final value = dueAt ?? workDate;
    if (value == null || value.isEmpty) return null;
    return value.length >= 10 ? value.substring(0, 10) : value;
  }

  /// Moves the deadline to [date] while preserving its existing time and
  /// separator. The API uses this field to synchronize linked targets with
  /// the web Kanban board.
  String dueAtForDate(String date) {
    final currentDueAt = dueAt;
    if (currentDueAt == null || currentDueAt.length <= 10) return date;

    final separator = currentDueAt.contains('T') ? 'T' : ' ';
    final separatorIndex = currentDueAt.indexOf(separator);
    if (separatorIndex < 0) return date;

    return '$date${currentDueAt.substring(separatorIndex)}';
  }

  factory DailyTaskItem.fromJson(Map<String, dynamic> json) {
    return DailyTaskItem(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      weeklyPlanItemId:
          json['weekly_plan_item_id'] != null
              ? (json['weekly_plan_item_id'] is int
                  ? json['weekly_plan_item_id']
                  : int.tryParse(json['weekly_plan_item_id'].toString()))
              : null,
      monthlyTargetId:
          json['monthly_target_id'] != null
              ? int.tryParse(json['monthly_target_id'].toString())
              : json['source_monthly_target_id'] != null
              ? int.tryParse(json['source_monthly_target_id'].toString())
              : null,
      kanbanColumnId:
          json['kanban_column_id'] != null
              ? int.tryParse(json['kanban_column_id'].toString())
              : null,
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      workDate:
          json['work_date']?.toString() ??
          json['date']?.toString() ??
          json['deadline']?.toString() ??
          json['target_date']?.toString() ??
          json['start_date']?.toString(),
      dueAt: json['due_at']?.toString(),
      details:
          json['details']?.toString() ??
          json['description']?.toString() ??
          json['notes']?.toString(),
      priority: json['priority']?.toString() ?? 'normal',
      executionStatus:
          json['execution_status']?.toString() ??
          json['status']?.toString() ??
          'not_started',
      progressPercent:
          json['progress_percent'] is num
              ? json['progress_percent']
              : num.tryParse(
                    json['progress_percent']?.toString() ??
                        json['progress']?.toString() ??
                        '',
                  ) ??
                  ((json['status'] == 'completed' ||
                          json['execution_status'] == 'completed')
                      ? 100
                      : 0),
      obstacle: json['obstacle']?.toString(),
      improvementPlan: json['improvement_plan']?.toString(),
      expectedOutput:
          json['expected_output']?.toString() ??
          json['expected_results']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (weeklyPlanItemId != null) 'weekly_plan_item_id': weeklyPlanItemId,
      if (monthlyTargetId != null) 'monthly_target_id': monthlyTargetId,
      if (kanbanColumnId != null) 'kanban_column_id': kanbanColumnId,
      'title': title,
      if (workDate != null) 'work_date': workDate,
      if (dueAt != null) 'due_at': dueAt,
      if (details != null) 'details': details,
      'priority': priority,
      'execution_status': executionStatus,
      'progress_percent': progressPercent,
      if (obstacle != null) 'obstacle': obstacle,
      if (improvementPlan != null) 'improvement_plan': improvementPlan,
      if (expectedOutput != null) 'expected_output': expectedOutput,
    };
  }
}

class KanbanColumn {
  final int id;
  final String name;
  final String? slug;
  final int? position;

  const KanbanColumn({
    required this.id,
    required this.name,
    this.slug,
    this.position,
  });

  factory KanbanColumn.fromJson(Map<String, dynamic> json) {
    return KanbanColumn(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name:
          json['name']?.toString() ??
          json['title']?.toString() ??
          json['label']?.toString() ??
          '',
      slug: json['slug']?.toString() ?? json['key']?.toString(),
      position: int.tryParse(
        (json['position'] ?? json['order'] ?? json['sort_order'])?.toString() ??
            '',
      ),
    );
  }
}

class DailyTaskListData {
  final List<DailyTaskItem> tasks;
  final List<KanbanColumn> kanbanColumns;

  const DailyTaskListData({required this.tasks, this.kanbanColumns = const []});

  factory DailyTaskListData.fromJson(dynamic rawData) {
    List<dynamic> rawTasks = const [];
    List<dynamic> rawColumns = const [];

    if (rawData is List) {
      rawTasks = rawData;
    } else if (rawData is Map) {
      if (rawData['tasks'] is List) {
        rawTasks = rawData['tasks'] as List<dynamic>;
      } else if (rawData['data'] is List) {
        rawTasks = rawData['data'] as List<dynamic>;
      }

      final meta = rawData['meta'];
      if (meta is Map && meta['kanban_columns'] is List) {
        rawColumns = meta['kanban_columns'] as List<dynamic>;
      } else if (rawData['kanban_columns'] is List) {
        rawColumns = rawData['kanban_columns'] as List<dynamic>;
      }
    }

    return DailyTaskListData(
      tasks:
          rawTasks
              .whereType<Map>()
              .map(
                (item) =>
                    DailyTaskItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList(),
      kanbanColumns:
          rawColumns
              .whereType<Map>()
              .map(
                (item) =>
                    KanbanColumn.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((column) => column.id > 0)
              .toList(),
    );
  }

  bool ownsKanbanColumn(int id) =>
      kanbanColumns.any((column) => column.id == id);
}

class WeeklyPlanItem {
  final int id;
  final int? monthlyTargetId;
  final String? monthlyTargetTitle;
  final int? sourceDailyTaskId;
  final int? sourceMonthlyTargetId;
  final bool isMainPlan;
  final String title;
  final String? details;
  final String? expectedOutput;
  final String? startDate;
  final String? targetDate;
  final String priority;
  final String executionStatus;
  final num progressPercent;
  final List<DailyTaskItem> dailyTasks;

  WeeklyPlanItem({
    required this.id,
    this.monthlyTargetId,
    this.monthlyTargetTitle,
    this.sourceDailyTaskId,
    this.sourceMonthlyTargetId,
    this.isMainPlan = false,
    required this.title,
    this.details,
    this.expectedOutput,
    this.startDate,
    this.targetDate,
    required this.priority,
    required this.executionStatus,
    required this.progressPercent,
    this.dailyTasks = const [],
  });

  bool get isStandalone =>
      monthlyTargetId == null &&
      sourceMonthlyTargetId == null &&
      sourceDailyTaskId == null;

  WeeklyPlanItem copyWith({
    int? id,
    int? monthlyTargetId,
    String? monthlyTargetTitle,
    int? sourceDailyTaskId,
    int? sourceMonthlyTargetId,
    bool? isMainPlan,
    String? title,
    String? details,
    String? expectedOutput,
    String? startDate,
    String? targetDate,
    String? priority,
    String? executionStatus,
    num? progressPercent,
    List<DailyTaskItem>? dailyTasks,
  }) {
    return WeeklyPlanItem(
      id: id ?? this.id,
      monthlyTargetId: monthlyTargetId ?? this.monthlyTargetId,
      monthlyTargetTitle: monthlyTargetTitle ?? this.monthlyTargetTitle,
      sourceDailyTaskId: sourceDailyTaskId ?? this.sourceDailyTaskId,
      sourceMonthlyTargetId:
          sourceMonthlyTargetId ?? this.sourceMonthlyTargetId,
      isMainPlan: isMainPlan ?? this.isMainPlan,
      title: title ?? this.title,
      details: details ?? this.details,
      expectedOutput: expectedOutput ?? this.expectedOutput,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      priority: priority ?? this.priority,
      executionStatus: executionStatus ?? this.executionStatus,
      progressPercent: progressPercent ?? this.progressPercent,
      dailyTasks: dailyTasks ?? this.dailyTasks,
    );
  }

  factory WeeklyPlanItem.fromJson(Map<String, dynamic> json) {
    var rawTasks = json['daily_tasks'] as List<dynamic>?;
    if (rawTasks == null || rawTasks.isEmpty) {
      rawTasks = json['sub_items'] as List<dynamic>?;
    }
    if (rawTasks == null || rawTasks.isEmpty) {
      rawTasks = json['children'] as List<dynamic>?;
    }
    if (rawTasks == null || rawTasks.isEmpty) {
      rawTasks = json['daily_targets'] as List<dynamic>?;
    }
    if (rawTasks == null || rawTasks.isEmpty) {
      rawTasks = json['tasks'] as List<dynamic>? ?? [];
    }

    return WeeklyPlanItem(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      monthlyTargetId:
          json['monthly_target_id'] != null
              ? (json['monthly_target_id'] is int
                  ? json['monthly_target_id']
                  : int.tryParse(json['monthly_target_id'].toString()))
              : null,
      monthlyTargetTitle: json['monthly_target_title']?.toString(),
      sourceDailyTaskId:
          json['source_daily_task_id'] != null
              ? (json['source_daily_task_id'] is int
                  ? json['source_daily_task_id']
                  : int.tryParse(json['source_daily_task_id'].toString()))
              : null,
      sourceMonthlyTargetId:
          json['source_monthly_target_id'] != null
              ? (json['source_monthly_target_id'] is int
                  ? json['source_monthly_target_id']
                  : int.tryParse(json['source_monthly_target_id'].toString()))
              : null,
      isMainPlan:
          json['is_main_plan'] == true ||
          json['is_main_plan']?.toString().toLowerCase() == 'true',
      title: json['title']?.toString() ?? '',
      details: json['details']?.toString(),
      expectedOutput: json['expected_output']?.toString(),
      startDate: json['start_date']?.toString(),
      targetDate: json['target_date']?.toString(),
      priority: json['priority']?.toString() ?? 'normal',
      executionStatus: json['execution_status']?.toString() ?? 'not_started',
      progressPercent: json['progress_percent'] ?? 0,
      dailyTasks:
          rawTasks
              .map((e) => DailyTaskItem.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class WeeklyPlanGroup {
  final int id;
  final String title;
  final String approvalStatus;
  final String executionStatus;
  final List<WeeklyPlanItem> items;

  WeeklyPlanGroup({
    required this.id,
    required this.title,
    required this.approvalStatus,
    required this.executionStatus,
    required this.items,
  });

  factory WeeklyPlanGroup.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    return WeeklyPlanGroup(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      approvalStatus: json['approval_status']?.toString() ?? 'draft',
      executionStatus: json['execution_status']?.toString() ?? 'in_progress',
      items:
          rawItems
              .map((e) => WeeklyPlanItem.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class WeeklyPlanData {
  final WeekInfo week;
  final List<WeeklyPlanGroup> plans;

  WeeklyPlanData({required this.week, required this.plans});

  factory WeeklyPlanData.fromJson(Map<String, dynamic> json) {
    var rawPlans = json['plans'] as List<dynamic>? ?? [];
    return WeeklyPlanData(
      week:
          json['week'] != null
              ? WeekInfo.fromJson(json['week'] as Map<String, dynamic>)
              : WeekInfo(start: '', end: '', isoYear: 0, isoWeek: 0, label: ''),
      plans:
          rawPlans
              .map((e) => WeeklyPlanGroup.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class WeeklyReviewItem {
  final int id;
  final String title;
  final bool isMainPlan;
  final int? monthlyTargetId;
  final String priority;
  final String? expectedOutput;
  final String? details;
  final String? startDate;
  final String? targetDate;
  String executionStatus;
  num progressPercent;
  String? obstacle;
  String? improvementPlan;
  final String? picName;
  final List<WeeklyReviewItem> subItems;

  WeeklyReviewItem({
    required this.id,
    required this.title,
    this.isMainPlan = false,
    this.monthlyTargetId,
    required this.priority,
    this.expectedOutput,
    this.details,
    this.startDate,
    this.targetDate,
    required this.executionStatus,
    required this.progressPercent,
    this.obstacle,
    this.improvementPlan,
    this.picName,
    this.subItems = const [],
  });

  bool get hasSubItems => subItems.isNotEmpty;
  bool get isReviewable => !isMainPlan || subItems.isEmpty;

  factory WeeklyReviewItem.fromJson(Map<String, dynamic> json) {
    var rawSub = json['sub_items'] as List<dynamic>?;
    if (rawSub == null || rawSub.isEmpty) {
      // Compatibility fallback: daily_tasks
      rawSub = json['daily_tasks'] as List<dynamic>?;
    }
    if (rawSub == null || rawSub.isEmpty) {
      rawSub = json['children'] as List<dynamic>?;
    }
    if (rawSub == null || rawSub.isEmpty) {
      rawSub = json['daily_targets'] as List<dynamic>? ?? [];
    }

    final parsedSubItems =
        rawSub
            .map((e) => WeeklyReviewItem.fromJson(e as Map<String, dynamic>))
            .toList();

    return WeeklyReviewItem(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      isMainPlan:
          json['is_main_plan'] == true ||
          (json['is_main_plan']?.toString().toLowerCase() == 'true'),
      monthlyTargetId:
          json['monthly_target_id'] != null
              ? int.tryParse(json['monthly_target_id'].toString())
              : null,
      priority: json['priority']?.toString() ?? 'normal',
      expectedOutput: json['expected_output']?.toString(),
      details: json['details']?.toString(),
      startDate: json['start_date']?.toString(),
      targetDate: json['target_date']?.toString(),
      executionStatus: json['execution_status']?.toString() ?? 'not_started',
      progressPercent: json['progress_percent'] ?? 0,
      obstacle: json['obstacle']?.toString(),
      improvementPlan: json['improvement_plan']?.toString(),
      picName: json['pic_name']?.toString(),
      subItems: parsedSubItems,
    );
  }
}

class WeeklyReviewPlanGroup {
  final int id;
  final String title;
  final String? ownerName; // 4.7: owner_name dari respons weekly-review
  final String?
  executionStatus; // 4.7: execution_status dari respons weekly-review
  final List<WeeklyReviewItem> items;

  WeeklyReviewPlanGroup({
    required this.id,
    required this.title,
    this.ownerName,
    this.executionStatus,
    required this.items,
  });

  factory WeeklyReviewPlanGroup.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    return WeeklyReviewPlanGroup(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      ownerName: json['owner_name']?.toString(),
      executionStatus: json['execution_status']?.toString(),
      items:
          rawItems
              .map((e) => WeeklyReviewItem.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class WeeklyReviewSummary {
  final int totalItems;
  final int completedItems;
  final num averageProgress;

  WeeklyReviewSummary({
    required this.totalItems,
    required this.completedItems,
    required this.averageProgress,
  });

  factory WeeklyReviewSummary.fromJson(Map<String, dynamic> json) {
    return WeeklyReviewSummary(
      totalItems: json['total_items'] ?? 0,
      completedItems: json['completed_items'] ?? 0,
      averageProgress: json['average_progress'] ?? 0,
    );
  }
}

class WeeklyReviewData {
  final WeekInfo week;
  final String? reviewDate;
  final String? reviewTiming;
  final WeeklyReviewSummary summary;
  final List<WeeklyReviewPlanGroup> plans;

  WeeklyReviewData({
    required this.week,
    this.reviewDate,
    this.reviewTiming,
    required this.summary,
    required this.plans,
  });

  factory WeeklyReviewData.fromJson(Map<String, dynamic> json) {
    var rawPlans = json['plans'] as List<dynamic>? ?? [];
    return WeeklyReviewData(
      week:
          json['week'] != null
              ? WeekInfo.fromJson(json['week'] as Map<String, dynamic>)
              : WeekInfo(start: '', end: '', isoYear: 0, isoWeek: 0, label: ''),
      reviewDate: json['review_date']?.toString(),
      reviewTiming: json['review_timing']?.toString(),
      summary:
          json['summary'] != null
              ? WeeklyReviewSummary.fromJson(
                json['summary'] as Map<String, dynamic>,
              )
              : WeeklyReviewSummary(
                totalItems: 0,
                completedItems: 0,
                averageProgress: 0,
              ),
      plans:
          rawPlans
              .map(
                (e) =>
                    WeeklyReviewPlanGroup.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}
