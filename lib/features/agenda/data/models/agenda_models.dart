import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Model untuk item agenda perusahaan sesuai spesifikasi API Central Portal
class AgendaItem {
  final int id;
  final String title;
  final String type; // 'Meeting', 'Libur', 'Agenda Lainnya', 'Deadline'
  final String eventDate;
  final String? eventEndDate;
  final String? startTime;
  final String? endTime;
  final String? startsAt;
  final String? location;
  final String? pic;
  final String? description;
  final String audienceScope; // 'all', 'division', 'users'
  final String audienceLabel;
  final List<int> reminderOffsets;
  final String? deepLink;
  final String? updatedAt;

  AgendaItem({
    required this.id,
    required this.title,
    required this.type,
    required this.eventDate,
    this.eventEndDate,
    this.startTime,
    this.endTime,
    this.startsAt,
    this.location,
    this.pic,
    this.description,
    required this.audienceScope,
    required this.audienceLabel,
    this.reminderOffsets = const [],
    this.deepLink,
    this.updatedAt,
  });

  factory AgendaItem.fromJson(Map<String, dynamic> json) {
    List<int> parseOffsets(dynamic val) {
      if (val is List) {
        return val.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toList();
      }
      return [];
    }

    return AgendaItem(
      id: json['id'] is int ? json['id'] as int : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Agenda Lainnya',
      eventDate: json['event_date']?.toString() ?? '',
      eventEndDate: json['event_end_date']?.toString(),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      startsAt: json['starts_at']?.toString(),
      location: json['location']?.toString(),
      pic: json['pic']?.toString(),
      description: json['description']?.toString(),
      audienceScope: json['audience_scope']?.toString() ?? 'all',
      audienceLabel: json['audience_label']?.toString() ?? 'Semua pegawai aktif',
      reminderOffsets: parseOffsets(json['reminder_offsets']),
      deepLink: json['deep_link']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'event_date': eventDate,
      'event_end_date': eventEndDate,
      'start_time': startTime,
      'end_time': endTime,
      'starts_at': startsAt,
      'location': location,
      'pic': pic,
      'description': description,
      'audience_scope': audienceScope,
      'audience_label': audienceLabel,
      'reminder_offsets': reminderOffsets,
      'deep_link': deepLink,
      'updated_at': updatedAt,
    };
  }

  /// Warna representatif berdasarkan jenis agenda
  Color get typeColor {
    switch (type.toLowerCase()) {
      case 'meeting':
        return const Color(0xFF0037B0); // Primary Blue
      case 'libur':
        return const Color(0xFFDC2626); // Red
      case 'deadline':
        return const Color(0xFFD97706); // Amber / Orange
      case 'agenda lainnya':
      default:
        return const Color(0xFF0D9488); // Teal
    }
  }

  /// Ikon representatif berdasarkan jenis agenda
  IconData get typeIcon {
    switch (type.toLowerCase()) {
      case 'meeting':
        return Icons.groups_rounded;
      case 'libur':
        return Icons.beach_access_rounded;
      case 'deadline':
        return Icons.timer_outlined;
      case 'agenda lainnya':
      default:
        return Icons.event_note_rounded;
    }
  }

  /// Label rentang tanggal rapi dalam Bahasa Indonesia
  String get formattedDateRange {
    try {
      final start = DateTime.tryParse(eventDate);
      if (start == null) return eventDate;

      String formatWithFallback(DateTime dt, String pattern) {
        try {
          return DateFormat(pattern, 'id_ID').format(dt);
        } catch (_) {
          try {
            return DateFormat(pattern).format(dt);
          } catch (_) {
            return '${dt.day}/${dt.month}/${dt.year}';
          }
        }
      }

      if (eventEndDate != null && eventEndDate!.isNotEmpty && eventEndDate != eventDate) {
        final end = DateTime.tryParse(eventEndDate!);
        if (end != null) {
          if (start.year == end.year && start.month == end.month) {
            return '${start.day} - ${formatWithFallback(end, 'd MMM yyyy')}';
          }
          return '${formatWithFallback(start, 'd MMM')} - ${formatWithFallback(end, 'd MMM yyyy')}';
        }
      }

      return formatWithFallback(start, 'd MMM yyyy');
    } catch (_) {
      return eventDate;
    }
  }

  /// Format waktu (misal: "08:00 - 09:30 WIB" atau "Sepanjang Hari")
  String get formattedTimeRange {
    if (startTime != null && startTime!.isNotEmpty) {
      final startClean = startTime!.length > 5 ? startTime!.substring(0, 5) : startTime!;
      if (endTime != null && endTime!.isNotEmpty) {
        final endClean = endTime!.length > 5 ? endTime!.substring(0, 5) : endTime!;
        return '$startClean - $endClean WIB';
      }
      return '$startClean WIB';
    }
    return 'Sepanjang Hari';
  }

  /// Format daftar offset reminder ke label manusia
  List<String> get reminderLabels {
    return reminderOffsets.map((minutes) {
      if (minutes >= 1440) {
        final days = minutes ~/ 1440;
        return 'H-$days (${days * 24} jam sebelumnya)';
      } else if (minutes >= 60) {
        final hours = minutes ~/ 60;
        return '$hours jam sebelumnya';
      } else {
        return '$minutes menit sebelumnya';
      }
    }).toList();
  }
}

/// Metadata pagination daftar agenda
class AgendaPaginationMeta {
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  AgendaPaginationMeta({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory AgendaPaginationMeta.fromJson(Map<String, dynamic> json) {
    return AgendaPaginationMeta(
      currentPage: json['current_page'] is int ? json['current_page'] : int.tryParse(json['current_page']?.toString() ?? '1') ?? 1,
      perPage: json['per_page'] is int ? json['per_page'] : int.tryParse(json['per_page']?.toString() ?? '30') ?? 30,
      total: json['total'] is int ? json['total'] : int.tryParse(json['total']?.toString() ?? '0') ?? 0,
      lastPage: json['last_page'] is int ? json['last_page'] : int.tryParse(json['last_page']?.toString() ?? '1') ?? 1,
    );
  }
}

/// Response kembalian dari endpoint GET /api/agendas
class AgendaListResponse {
  final bool success;
  final String message;
  final List<AgendaItem> items;
  final AgendaPaginationMeta? meta;
  final int? statusCode;

  AgendaListResponse({
    required this.success,
    required this.message,
    this.items = const [],
    this.meta,
    this.statusCode,
  });
}

/// Response kembalian dari endpoint GET /api/agendas/{id}
class AgendaDetailResponse {
  final bool success;
  final String message;
  final AgendaItem? agenda;
  final bool isNotFoundOrForbidden;
  final int? statusCode;

  AgendaDetailResponse({
    required this.success,
    required this.message,
    this.agenda,
    this.isNotFoundOrForbidden = false,
    this.statusCode,
  });
}
