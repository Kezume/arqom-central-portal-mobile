class Announcement {
  final int id;
  final String title;
  final String description;
  final String priority;
  final String startsAt;
  final String endsAt;

  Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.startsAt,
    required this.endsAt,
  });

  static String _extractStr(dynamic val, {String fallback = ''}) {
    if (val == null) return fallback;
    if (val is String) return val;
    if (val is Map) {
      return val['name']?.toString() ??
          val['title']?.toString() ??
          val['description']?.toString() ??
          val['label']?.toString() ??
          fallback;
    }
    return val.toString();
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: _extractStr(json['title']),
      description: _extractStr(json['description']),
      priority: _extractStr(json['priority'], fallback: 'normal'),
      startsAt: _extractStr(json['starts_at']),
      endsAt: _extractStr(json['ends_at']),
    );
  }
}
