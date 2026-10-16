class Activity {
  final int id;
  final String title;
  final String category;
  final String activityDate;
  final String location;
  final String pic;
  final String status;

  Activity({
    required this.id,
    required this.title,
    required this.category,
    required this.activityDate,
    required this.location,
    required this.pic,
    required this.status,
  });

  static String _extractStr(dynamic val, {String fallback = ''}) {
    if (val == null) return fallback;
    if (val is String) return val;
    if (val is Map) {
      return val['name']?.toString() ??
          val['title']?.toString() ??
          val['label']?.toString() ??
          val['location']?.toString() ??
          fallback;
    }
    return val.toString();
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: _extractStr(json['title']),
      category: _extractStr(json['category']),
      activityDate: _extractStr(json['activity_date']),
      location: _extractStr(json['location']),
      pic: _extractStr(json['pic']),
      status: _extractStr(json['status']),
    );
  }
}
