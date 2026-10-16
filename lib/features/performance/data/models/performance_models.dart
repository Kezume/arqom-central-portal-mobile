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
    this.picName,
    this.startDate,
    this.deadline,
    this.notes,
    this.children = const [],
  });

  factory MonthlyTargetItem.fromJson(Map<String, dynamic> json) {
    var rawChildren = json['children'] as List<dynamic>? ?? [];
    List<MonthlyTargetItem> childList =
        rawChildren.map((e) => MonthlyTargetItem.fromJson(e as Map<String, dynamic>)).toList();

    return MonthlyTargetItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      parentId: json['parent_id'] != null
          ? (json['parent_id'] is int
              ? json['parent_id']
              : int.tryParse(json['parent_id'].toString()))
          : null,
      level: json['level']?.toString() ?? 'main',
      title: json['title']?.toString() ?? '',
      expectedResults: json['expected_results']?.toString(),
      status: json['status']?.toString() ??
          json['execution_status']?.toString() ??
          'not_started',
      priority: json['priority']?.toString() ?? 'normal',
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
      year: json['year'] is int ? json['year'] : int.tryParse(json['year']?.toString() ?? '') ?? DateTime.now().year,
      currentPeriod: json['current_period']?.toString() ?? '',
      availablePeriods: rawPeriods.map((e) => e.toString()).toList(),
      targets: rawTargets.map((e) => MonthlyTargetItem.fromJson(e as Map<String, dynamic>)).toList(),
      summary: json['summary'] != null
          ? MonthlyTargetSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : MonthlyTargetSummary(totalMain: 0, totalWeekly: 0, completedWeekly: 0, progressPercent: 0),
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
      isoYear: json['iso_year'] is int ? json['iso_year'] : int.tryParse(json['iso_year']?.toString() ?? '') ?? 0,
      isoWeek: json['iso_week'] is int ? json['iso_week'] : int.tryParse(json['iso_week']?.toString() ?? '') ?? 0,
      label: json['label']?.toString() ?? '',
    );
  }
}

class DailyTaskItem {
  final int id;
  final String title;
  final String? workDate;
  final String executionStatus;
  final num progressPercent;

  DailyTaskItem({
    required this.id,
    required this.title,
    this.workDate,
    required this.executionStatus,
    required this.progressPercent,
  });

  factory DailyTaskItem.fromJson(Map<String, dynamic> json) {
    return DailyTaskItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      workDate: json['work_date']?.toString(),
      executionStatus: json['execution_status']?.toString() ?? 'not_started',
      progressPercent: json['progress_percent'] ?? 0,
    );
  }
}

class WeeklyPlanItem {
  final int id;
  final int? monthlyTargetId;
  final String? monthlyTargetTitle;
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

  factory WeeklyPlanItem.fromJson(Map<String, dynamic> json) {
    var rawTasks = json['daily_tasks'] as List<dynamic>? ?? [];
    return WeeklyPlanItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      monthlyTargetId: json['monthly_target_id'] != null
          ? (json['monthly_target_id'] is int
              ? json['monthly_target_id']
              : int.tryParse(json['monthly_target_id'].toString()))
          : null,
      monthlyTargetTitle: json['monthly_target_title']?.toString(),
      title: json['title']?.toString() ?? '',
      details: json['details']?.toString(),
      expectedOutput: json['expected_output']?.toString(),
      startDate: json['start_date']?.toString(),
      targetDate: json['target_date']?.toString(),
      priority: json['priority']?.toString() ?? 'normal',
      executionStatus: json['execution_status']?.toString() ?? 'not_started',
      progressPercent: json['progress_percent'] ?? 0,
      dailyTasks: rawTasks.map((e) => DailyTaskItem.fromJson(e as Map<String, dynamic>)).toList(),
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
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      approvalStatus: json['approval_status']?.toString() ?? 'draft',
      executionStatus: json['execution_status']?.toString() ?? 'in_progress',
      items: rawItems.map((e) => WeeklyPlanItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class WeeklyPlanData {
  final WeekInfo week;
  final List<WeeklyPlanGroup> plans;

  WeeklyPlanData({
    required this.week,
    required this.plans,
  });

  factory WeeklyPlanData.fromJson(Map<String, dynamic> json) {
    var rawPlans = json['plans'] as List<dynamic>? ?? [];
    return WeeklyPlanData(
      week: json['week'] != null
          ? WeekInfo.fromJson(json['week'] as Map<String, dynamic>)
          : WeekInfo(start: '', end: '', isoYear: 0, isoWeek: 0, label: ''),
      plans: rawPlans.map((e) => WeeklyPlanGroup.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class WeeklyReviewItem {
  final int id;
  final String title;
  final String priority;
  final String? expectedOutput;
  String executionStatus;
  num progressPercent;
  String? obstacle;
  String? improvementPlan;

  WeeklyReviewItem({
    required this.id,
    required this.title,
    required this.priority,
    this.expectedOutput,
    required this.executionStatus,
    required this.progressPercent,
    this.obstacle,
    this.improvementPlan,
  });

  factory WeeklyReviewItem.fromJson(Map<String, dynamic> json) {
    return WeeklyReviewItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'normal',
      expectedOutput: json['expected_output']?.toString(),
      executionStatus: json['execution_status']?.toString() ?? 'not_started',
      progressPercent: json['progress_percent'] ?? 0,
      obstacle: json['obstacle']?.toString(),
      improvementPlan: json['improvement_plan']?.toString(),
    );
  }
}

class WeeklyReviewPlanGroup {
  final int id;
  final String title;
  final List<WeeklyReviewItem> items;

  WeeklyReviewPlanGroup({
    required this.id,
    required this.title,
    required this.items,
  });

  factory WeeklyReviewPlanGroup.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    return WeeklyReviewPlanGroup(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      items: rawItems.map((e) => WeeklyReviewItem.fromJson(e as Map<String, dynamic>)).toList(),
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
      week: json['week'] != null
          ? WeekInfo.fromJson(json['week'] as Map<String, dynamic>)
          : WeekInfo(start: '', end: '', isoYear: 0, isoWeek: 0, label: ''),
      reviewDate: json['review_date']?.toString(),
      reviewTiming: json['review_timing']?.toString(),
      summary: json['summary'] != null
          ? WeeklyReviewSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : WeeklyReviewSummary(totalItems: 0, completedItems: 0, averageProgress: 0),
      plans: rawPlans.map((e) => WeeklyReviewPlanGroup.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
