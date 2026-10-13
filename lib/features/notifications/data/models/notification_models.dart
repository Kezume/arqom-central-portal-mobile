class NotificationData {
  final int? requestId;
  final String? requestNumber;
  final String? requestType;
  final String? status;
  final String? decision;
  final String? reviewer;
  final String? note;
  final String? clickAction;

  NotificationData({
    this.requestId,
    this.requestNumber,
    this.requestType,
    this.status,
    this.decision,
    this.reviewer,
    this.note,
    this.clickAction,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      requestId: json['request_id'] is int
          ? json['request_id']
          : int.tryParse(json['request_id']?.toString() ?? ''),
      requestNumber: json['request_number']?.toString(),
      requestType: json['request_type']?.toString(),
      status: json['status']?.toString(),
      decision: json['decision']?.toString(),
      reviewer: json['reviewer']?.toString(),
      note: json['note']?.toString(),
      clickAction: json['click_action']?.toString(),
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
    };
  }
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
