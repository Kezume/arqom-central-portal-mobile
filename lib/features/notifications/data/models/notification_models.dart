class NotificationData {
  final int? requestId;
  final String? requestNumber;
  final String? requestType;
  final String? status;
  final String? decision;
  final String? reviewer;
  final String? note;
  final String? clickAction;

  // Field khusus agenda perusahaan (Menu 6.4)
  final int? agendaId;
  final String? entityType;
  final String? entityId;
  final String? startsAt;
  final String? reminderOffsetMinutes;
  final String? deepLink;
  final String? priority;

  // Field khusus pengingat logbook (Menu 6.4 & 7.9)
  final String? actionUrl;

  // Raw data mapping
  final Map<String, dynamic> rawJson;

  NotificationData({
    this.requestId,
    this.requestNumber,
    this.requestType,
    this.status,
    this.decision,
    this.reviewer,
    this.note,
    this.clickAction,
    this.agendaId,
    this.entityType,
    this.entityId,
    this.startsAt,
    this.reminderOffsetMinutes,
    this.deepLink,
    this.priority,
    this.actionUrl,
    this.rawJson = const {},
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    int? parseId(dynamic val) {
      if (val is int) return val;
      if (val != null) return int.tryParse(val.toString());
      return null;
    }

    final agendaIdParsed = parseId(json['agenda_id']) ?? parseId(json['entity_id']);

    return NotificationData(
      requestId: parseId(json['request_id']),
      requestNumber: json['request_number']?.toString(),
      requestType: json['request_type']?.toString(),
      status: json['status']?.toString(),
      decision: json['decision']?.toString(),
      reviewer: json['reviewer']?.toString(),
      note: json['note']?.toString(),
      clickAction: json['click_action']?.toString(),
      agendaId: agendaIdParsed,
      entityType: json['entity_type']?.toString(),
      entityId: json['entity_id']?.toString(),
      startsAt: json['starts_at']?.toString(),
      reminderOffsetMinutes: json['reminder_offset_minutes']?.toString(),
      deepLink: json['deep_link']?.toString(),
      priority: json['priority']?.toString(),
      actionUrl: json['action_url']?.toString(),
      rawJson: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'request_number': requestNumber,
      'request_type': requestType,
      'status': status,
      'decision': decision,
      'reviewer': reviewer,
      'note': note,
      'click_action': clickAction,
      'agenda_id': agendaId,
      'entity_type': entityType,
      'entity_id': entityId,
      'starts_at': startsAt,
      'reminder_offset_minutes': reminderOffsetMinutes,
      'deep_link': deepLink,
      'priority': priority,
      'action_url': actionUrl,
    };
  }

  bool get isAgenda =>
      agendaId != null || entityType == 'central_agenda' || deepLink?.contains('agenda') == true;

  bool get isRequest => requestId != null || requestNumber != null;

  bool get isPerformanceDailyReminder =>
      actionUrl?.contains('logbook') == true || actionUrl?.contains('daily') == true;
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final NotificationData? data;
  final bool isRead;
  final String? readAt;
  final String createdAt;
  final String timeAgo;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    required this.timeAgo,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    NotificationData? dataObj;
    if (json['data'] != null && json['data'] is Map<String, dynamic>) {
      dataObj = NotificationData.fromJson(json['data'] as Map<String, dynamic>);
    }

    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Pemberitahuan',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      data: dataObj,
      isRead: json['is_read'] == true,
      readAt: json['read_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      timeAgo: json['time_ago']?.toString() ?? 'Baru saja',
    );
  }

  NotificationItem copyWith({
    bool? isRead,
    String? readAt,
  }) {
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      type: type,
      data: data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      timeAgo: timeAgo,
    );
  }
}
