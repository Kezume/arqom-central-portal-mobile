class AttendanceCheckItem {
  final bool recorded;
  final String? time;
  final String? timestamp;

  AttendanceCheckItem({
    required this.recorded,
    this.time,
    this.timestamp,
  });

  factory AttendanceCheckItem.fromJson(dynamic json) {
    if (json == null) {
      return AttendanceCheckItem(recorded: false);
    }
    if (json is Map) {
      final rec = json['recorded'] == true || (json['time'] != null && json['time'].toString().isNotEmpty);
      final t = json['time']?.toString() ?? json['jam']?.toString() ?? json['check_in']?.toString() ?? json['check_out']?.toString();
      final ts = json['timestamp']?.toString() ?? json['created_at']?.toString();
      return AttendanceCheckItem(
        recorded: rec,
        time: t,
        timestamp: ts,
      );
    }
    // If backend returns a plain String e.g. "08:15:00"
    final str = json.toString().trim();
    if (str.isNotEmpty && str != '--:--' && str != 'null') {
      return AttendanceCheckItem(
        recorded: true,
        time: str,
        timestamp: null,
      );
    }
    return AttendanceCheckItem(recorded: false);
  }

  String get formattedTime {
    if (!recorded || time == null || time!.isEmpty || time == '--:--') {
      return '--:--';
    }
    final parts = time!.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return time!;
  }
}

class AttendanceApprovedRequest {
  final int? id;
  final String? requestNumber;
  final String? requestType;
  final String? typeLabel;
  final String? description;
  final String? startDate;
  final String? endDate;
  final String? location;
  final String? approvedAt;

  AttendanceApprovedRequest({
    this.id,
    this.requestNumber,
    this.requestType,
    this.typeLabel,
    this.description,
    this.startDate,
    this.endDate,
    this.location,
    this.approvedAt,
  });

  factory AttendanceApprovedRequest.fromJson(dynamic json) {
    if (json == null || json is! Map) {
      return AttendanceApprovedRequest();
    }
    return AttendanceApprovedRequest(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      requestNumber: json['request_number']?.toString(),
      requestType: json['request_type']?.toString(),
      typeLabel: json['type_label']?.toString(),
      description: json['description']?.toString(),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      location: json['location']?.toString(),
      approvedAt: json['approved_at']?.toString(),
    );
  }
}

class AttendanceToday {
  final String date;
  final String status;
  final String statusBadge;
  final String? statusSource;
  final AttendanceApprovedRequest? approvedRequest;
  final AttendanceCheckItem checkIn;
  final AttendanceCheckItem checkOut;
  final String? source;
  final String? sourceLabel;
  final int lateMinutes;
  final String? lateCategory;
  final String? lateLabel;
  final String? notes;
  final Map<String, dynamic>? schedule;

  AttendanceToday({
    required this.date,
    required this.status,
    required this.statusBadge,
    this.statusSource,
    this.approvedRequest,
    required this.checkIn,
    required this.checkOut,
    this.source,
    this.sourceLabel,
    this.lateMinutes = 0,
    this.lateCategory,
    this.lateLabel,
    this.notes,
    this.schedule,
  });

  factory AttendanceToday.fromJson(Map<String, dynamic> json) {
    return AttendanceToday(
      date: json['date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Belum Presensi',
      statusBadge: json['status_badge']?.toString() ?? 'secondary',
      statusSource: json['status_source']?.toString(),
      approvedRequest: json['approved_request'] != null
          ? AttendanceApprovedRequest.fromJson(json['approved_request'])
          : null,
      checkIn: AttendanceCheckItem.fromJson(json['check_in']),
      checkOut: AttendanceCheckItem.fromJson(json['check_out']),
      source: json['source']?.toString(),
      sourceLabel: json['source_label']?.toString(),
      lateMinutes: json['late_minutes'] is int
          ? json['late_minutes']
          : int.tryParse(json['late_minutes']?.toString() ?? '0') ?? 0,
      lateCategory: json['late_category']?.toString(),
      lateLabel: json['late_label']?.toString(),
      notes: json['notes']?.toString(),
      schedule: json['schedule'] is Map<String, dynamic> ? json['schedule'] : null,
    );
  }

  bool get isCheckedIn => checkIn.recorded;
  bool get isCheckedOut => checkOut.recorded;

  bool get isApprovedRequest =>
      (statusSource ?? '').toLowerCase() == 'approved_request' || approvedRequest != null;

  String get displayCheckIn => checkIn.formattedTime;
  String get displayCheckOut => checkOut.formattedTime;

  bool get isFingerSpot => (source ?? '').toLowerCase().contains('finger') ||
      (sourceLabel ?? '').toLowerCase().contains('mesin');
}

class AttendanceStatistics {
  final int hadir;
  final int terlambat;
  final int belumAbsenPulang;
  final int tidakHadir;
  final int belumAbsen;
  final int sakit;
  final int izin;
  final int cuti;
  final int perjalananDinas;
  final int lembur;
  final int hariLibur;
  final int totalHadirDanDinas;
  final int hariKerjaBerlalu;
  final num persentaseKehadiran;

  AttendanceStatistics({
    this.hadir = 0,
    this.terlambat = 0,
    this.belumAbsenPulang = 0,
    this.tidakHadir = 0,
    this.belumAbsen = 0,
    this.sakit = 0,
    this.izin = 0,
    this.cuti = 0,
    this.perjalananDinas = 0,
    this.lembur = 0,
    this.hariLibur = 0,
    this.totalHadirDanDinas = 0,
    this.hariKerjaBerlalu = 0,
    this.persentaseKehadiran = 0.0,
  });

  static int _parseInt(dynamic val, {int fallback = 0}) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? fallback;
  }

  static num _parseNum(dynamic val, {num fallback = 0.0}) {
    if (val == null) return fallback;
    if (val is num) return val;
    return num.tryParse(val.toString()) ?? fallback;
  }

  factory AttendanceStatistics.fromJson(Map<String, dynamic> json) {
    // Map supports both Indonesian keys ("Hadir", "Terlambat") and English legacy keys ("present", "late")
    return AttendanceStatistics(
      hadir: _parseInt(json['Hadir'] ?? json['present'] ?? json['hadir']),
      terlambat: _parseInt(json['Terlambat'] ?? json['late'] ?? json['terlambat']),
      belumAbsenPulang: _parseInt(json['Belum Absen Pulang'] ?? json['belum_absen_pulang']),
      tidakHadir: _parseInt(json['Tidak Hadir'] ?? json['absent'] ?? json['alpha'] ?? json['alpa']),
      belumAbsen: _parseInt(json['Belum Absen'] ?? json['belum_absen']),
      sakit: _parseInt(json['Sakit'] ?? json['sick'] ?? json['sakit']),
      izin: _parseInt(json['Izin'] ?? json['permission'] ?? json['izin']),
      cuti: _parseInt(json['Cuti'] ?? json['leave'] ?? json['cuti']),
      perjalananDinas: _parseInt(json['Perjalanan Dinas'] ?? json['dinas'] ?? json['business_trip']),
      lembur: _parseInt(json['Lembur'] ?? json['overtime'] ?? json['lembur']),
      hariLibur: _parseInt(json['Hari Libur'] ?? json['holiday'] ?? json['hari_libur']),
      totalHadirDanDinas: _parseInt(json['total_hadir_dan_dinas']),
      hariKerjaBerlalu: _parseInt(json['hari_kerja_berlalu']),
      persentaseKehadiran: _parseNum(json['persentase_kehadiran']),
    );
  }
}

class AttendanceHistoryItem {
  final int? id;
  final String date;
  final String dayName;
  final String dayCode;
  final bool isToday;
  final bool isWeekend;
  final bool isHoliday;
  final String status;
  final String statusBadge;
  final String? statusSource;
  final AttendanceApprovedRequest? approvedRequest;
  final String? checkInAt;
  final String? checkInTime;
  final String? checkOutAt;
  final String? checkOutTime;
  final String? source;
  final String? sourceLabel;
  final String? lateCategory;
  final String? lateLabel;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final String? notes;

  AttendanceHistoryItem({
    this.id,
    required this.date,
    required this.dayName,
    required this.dayCode,
    this.isToday = false,
    this.isWeekend = false,
    this.isHoliday = false,
    required this.status,
    required this.statusBadge,
    this.statusSource,
    this.approvedRequest,
    this.checkInAt,
    this.checkInTime,
    this.checkOutAt,
    this.checkOutTime,
    this.source,
    this.sourceLabel,
    this.lateCategory,
    this.lateLabel,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.notes,
  });

  static String _extractStr(dynamic val, {String fallback = ''}) {
    if (val == null) return fallback;
    if (val is String) return val.trim();
    if (val is Map) {
      final possible = val['time'] ?? val['name'] ?? val['label'];
      if (possible != null) return possible.toString().trim();
      return fallback;
    }
    return val.toString().trim();
  }

  static String _extractTimeFromTimestamp(String? ts) {
    if (ts == null || ts.isEmpty) return '';
    try {
      if (ts.contains('T')) {
        final afterT = ts.split('T')[1];
        final clean = afterT.split('+')[0].split('-')[0].split('Z')[0].split('.')[0];
        return clean.trim();
      } else if (ts.contains(' ')) {
        final parts = ts.split(' ');
        if (parts.length >= 2) {
          final clean = parts[1].split('+')[0].split('-')[0].split('Z')[0].split('.')[0];
          return clean.trim();
        }
      }
    } catch (_) {}
    return '';
  }

  static int _parseSafeInt(dynamic val, {int fallback = 0}) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    final clean = val.toString().trim();
    return num.tryParse(clean)?.toInt() ?? fallback;
  }

  factory AttendanceHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawDate = _extractStr(json['date']);
    String dayName = _extractStr(json['day_name']);
    String dayCode = _extractStr(json['day_code']);

    // Fallback: derive weekday from date string if dayName or dayCode is missing
    if ((dayCode.isEmpty || dayName.isEmpty) && rawDate.isNotEmpty) {
      final parsedDate = DateTime.tryParse(rawDate);
      if (parsedDate != null) {
        const codes = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];
        const names = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
        final idx = parsedDate.weekday - 1;
        if (idx >= 0 && idx < 7) {
          if (dayCode.isEmpty) dayCode = codes[idx];
          if (dayName.isEmpty) dayName = names[idx];
        }
      }
    }

    final inAt = json['check_in_at']?.toString();
    String inTime = _extractStr(json['check_in_time'] ?? json['check_in']);
    if ((inTime.isEmpty || inTime == '--:--') && inAt != null) {
      inTime = _extractTimeFromTimestamp(inAt);
    }

    final outAt = json['check_out_at']?.toString();
    String outTime = _extractStr(json['check_out_time'] ?? json['check_out']);
    if ((outTime.isEmpty || outTime == '--:--') && outAt != null) {
      outTime = _extractTimeFromTimestamp(outAt);
    }

    return AttendanceHistoryItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      date: rawDate,
      dayName: dayName,
      dayCode: dayCode,
      isToday: json['is_today'] == true,
      isWeekend: json['is_weekend'] == true,
      isHoliday: json['is_holiday'] == true,
      status: _extractStr(json['status'], fallback: 'Tidak Hadir'),
      statusBadge: _extractStr(json['status_badge'], fallback: 'secondary'),
      statusSource: json['status_source']?.toString(),
      approvedRequest: json['approved_request'] != null && json['approved_request'] is Map
          ? AttendanceApprovedRequest.fromJson(json['approved_request'])
          : null,
      checkInAt: inAt,
      checkInTime: inTime.isNotEmpty ? inTime : null,
      checkOutAt: outAt,
      checkOutTime: outTime.isNotEmpty ? outTime : null,
      source: json['source']?.toString(),
      sourceLabel: json['source_label']?.toString(),
      lateCategory: json['late_category']?.toString(),
      lateLabel: json['late_label']?.toString(),
      lateMinutes: _parseSafeInt(json['late_minutes']),
      earlyLeaveMinutes: _parseSafeInt(json['early_leave_minutes']),
      notes: json['notes']?.toString(),
    );
  }

  bool get isApprovedRequest =>
      (statusSource ?? '').toLowerCase() == 'approved_request' || approvedRequest != null;

  String get formattedCheckIn {
    if (checkInTime == null || checkInTime!.isEmpty || checkInTime == '--:--') {
      return '--:--';
    }
    final parts = checkInTime!.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return checkInTime!;
  }

  String get formattedCheckOut {
    if (checkOutTime == null || checkOutTime!.isEmpty || checkOutTime == '--:--') {
      return '--:--';
    }
    final parts = checkOutTime!.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return checkOutTime!;
  }

  bool get isFingerSpot => (source ?? '').toLowerCase().contains('finger') ||
      (sourceLabel ?? '').toLowerCase().contains('mesin');
}

class AttendanceEmployee {
  final int id;
  final String name;
  final String email;
  final String division;
  final String position;
  final String status;
  final String? joinDate;

  AttendanceEmployee({
    required this.id,
    required this.name,
    required this.email,
    required this.division,
    required this.position,
    required this.status,
    this.joinDate,
  });

  factory AttendanceEmployee.fromJson(Map<String, dynamic> json) {
    return AttendanceEmployee(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      division: json['division']?.toString() ?? '',
      position: json['position']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Aktif',
      joinDate: json['join_date']?.toString(),
    );
  }
}

class AttendanceHistoryResponse {
  final AttendanceEmployee? employee;
  final Map<String, dynamic>? period;
  final Map<String, dynamic>? schedule;
  final AttendanceStatistics statistics;
  final List<AttendanceHistoryItem> history;
  final Map<String, dynamic>? pagination;

  AttendanceHistoryResponse({
    this.employee,
    this.period,
    this.schedule,
    required this.statistics,
    required this.history,
    this.pagination,
  });

  factory AttendanceHistoryResponse.fromJson(dynamic rawJson) {
    if (rawJson == null) {
      return AttendanceHistoryResponse(
        statistics: AttendanceStatistics(),
        history: [],
      );
    }

    if (rawJson is List) {
      return AttendanceHistoryResponse(
        statistics: AttendanceStatistics(),
        history: rawJson
            .map((e) => e is Map ? AttendanceHistoryItem.fromJson(Map<String, dynamic>.from(e)) : null)
            .whereType<AttendanceHistoryItem>()
            .toList(),
      );
    }

    final json = rawJson is Map ? Map<String, dynamic>.from(rawJson) : <String, dynamic>{};

    List<dynamic> rawHistory = [];
    if (json['history'] is List) {
      rawHistory = json['history'] as List<dynamic>;
    } else if (json['history'] is Map && json['history']['data'] is List) {
      rawHistory = json['history']['data'] as List<dynamic>;
    } else if (json['data'] is List) {
      rawHistory = json['data'] as List<dynamic>;
    }

    final List<AttendanceHistoryItem> parsedHistory = rawHistory
        .map((e) => e is Map ? AttendanceHistoryItem.fromJson(Map<String, dynamic>.from(e)) : null)
        .whereType<AttendanceHistoryItem>()
        .toList();

    return AttendanceHistoryResponse(
      employee: json['employee'] is Map
          ? AttendanceEmployee.fromJson(Map<String, dynamic>.from(json['employee']))
          : null,
      period: json['period'] is Map ? Map<String, dynamic>.from(json['period']) : null,
      schedule: json['schedule'] is Map ? Map<String, dynamic>.from(json['schedule']) : null,
      statistics: json['statistics'] is Map
          ? AttendanceStatistics.fromJson(Map<String, dynamic>.from(json['statistics']))
          : AttendanceStatistics(),
      history: parsedHistory,
      pagination: json['pagination'] is Map ? Map<String, dynamic>.from(json['pagination']) : null,
    );
  }
}

