import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class RequestMeta {
  final String? userRole;
  final bool canUseElevatedTypes;
  final List<RequestTypeOption> availableTypes;
  final List<EmployeeSimple> employees;

  RequestMeta({
    this.userRole,
    required this.canUseElevatedTypes,
    required this.availableTypes,
    required this.employees,
  });

  factory RequestMeta.fromJson(Map<String, dynamic> json) {
    final rawTypes = json['available_types'] as List<dynamic>? ?? [];
    final rawEmp = json['employees'] as List<dynamic>? ?? [];

    return RequestMeta(
      userRole: json['user_role']?.toString(),
      canUseElevatedTypes: json['can_use_elevated_types'] == true,
      availableTypes: rawTypes.map((e) => RequestTypeOption.fromJson(e as Map<String, dynamic>)).toList(),
      employees: rawEmp.map((e) => EmployeeSimple.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class RequestTypeOption {
  final String key;
  final String label;
  final bool elevated;

  RequestTypeOption({
    required this.key,
    required this.label,
    required this.elevated,
  });

  factory RequestTypeOption.fromJson(Map<String, dynamic> json) {
    return RequestTypeOption(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      elevated: json['elevated'] == true,
    );
  }
}

class EmployeeSimple {
  final int id;
  final String name;
  final String division;
  final String position;

  EmployeeSimple({
    required this.id,
    required this.name,
    required this.division,
    required this.position,
  });

  factory EmployeeSimple.fromJson(Map<String, dynamic> json) {
    return EmployeeSimple(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      division: json['division']?.toString() ?? '',
      position: json['position']?.toString() ?? '',
    );
  }
}

class RequestDetails {
  final String? tipeWaktu;
  final String? tipePeserta;
  final List<int> pesertaIds;
  final List<EmployeeSimple> peserta;

  RequestDetails({
    this.tipeWaktu,
    this.tipePeserta,
    this.pesertaIds = const [],
    this.peserta = const [],
  });

  factory RequestDetails.fromJson(Map<String, dynamic> json) {
    final rawIds = json['peserta_ids'] as List<dynamic>? ?? [];
    final rawList = json['peserta'] as List<dynamic>? ?? [];

    return RequestDetails(
      tipeWaktu: json['tipe_waktu']?.toString(),
      tipePeserta: json['tipe_peserta']?.toString(),
      pesertaIds: rawIds.map((e) => int.tryParse(e.toString()) ?? 0).where((id) => id > 0).toList(),
      peserta: rawList.map((e) => EmployeeSimple.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class AttendanceImpact {
  final bool affectsAttendance;
  final bool isEffective;
  final String? effectiveAfterStatus;
  final String? effectiveStatus;
  final String? startDate;
  final String? endDate;

  AttendanceImpact({
    required this.affectsAttendance,
    required this.isEffective,
    this.effectiveAfterStatus,
    this.effectiveStatus,
    this.startDate,
    this.endDate,
  });

  factory AttendanceImpact.fromJson(Map<String, dynamic> json) {
    return AttendanceImpact(
      affectsAttendance: json['affects_attendance'] == true,
      isEffective: json['is_effective'] == true,
      effectiveAfterStatus: json['effective_after_status']?.toString(),
      effectiveStatus: json['effective_status']?.toString(),
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'affects_attendance': affectsAttendance,
      'is_effective': isEffective,
      'effective_after_status': effectiveAfterStatus,
      'effective_status': effectiveStatus,
      'start_date': startDate,
      'end_date': endDate,
    };
  }
}

class RequestItem {
  final int id;
  final String requestNumber;
  final String requestType; // cuti, izin, sakit, lembur, perjalanan_dinas
  final String? rawTypeLabel;
  final String title;
  final String description;
  final String startDate;
  final String? endDate;
  final String? startTime;
  final String? endTime;
  final String? location;
  final Map<String, dynamic>? details;
  final RequestDetails? parsedDetails;
  final String? attachmentUrl;
  final String status; // Menunggu Manager, Menunggu HCGA, Disetujui, Ditolak, Dibatalkan
  final String? displayStatus;
  final String? statusClass;
  final AttendanceImpact? attendanceImpact;
  final bool isOwner;
  final bool isParticipant;
  final bool canCancel;
  final String? approvalFlow;
  final ApprovalInfo? managerApproval;
  final ApprovalInfo? hcgaApproval;
  final String? submittedAt;
  final EmployeeInfo? employee;

  RequestItem({
    required this.id,
    required this.requestNumber,
    required this.requestType,
    this.rawTypeLabel,
    required this.title,
    required this.description,
    required this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.location,
    this.details,
    this.parsedDetails,
    this.attachmentUrl,
    required this.status,
    this.displayStatus,
    this.statusClass,
    this.attendanceImpact,
    this.isOwner = true,
    this.isParticipant = false,
    required this.canCancel,
    this.approvalFlow,
    this.managerApproval,
    this.hcgaApproval,
    this.submittedAt,
    this.employee,
  });

  factory RequestItem.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString() ?? 'Menunggu Manager';
    final isOwnerVal = json['is_owner'] is bool ? json['is_owner'] as bool : true;
    final isParticipantVal = json['is_participant'] is bool ? json['is_participant'] as bool : false;
    final canCancelVal = json['can_cancel'] is bool
        ? json['can_cancel'] as bool
        : (isOwnerVal && (statusStr.toLowerCase().contains('menunggu') || statusStr.toLowerCase().contains('pending')));

    final detailsMap = json['details'] is Map<String, dynamic> ? json['details'] as Map<String, dynamic> : null;
    final parsedDetailsVal = detailsMap != null ? RequestDetails.fromJson(detailsMap) : null;

    final impactMap = json['attendance_impact'] is Map<String, dynamic>
        ? json['attendance_impact'] as Map<String, dynamic>
        : null;
    final attendanceImpactVal = impactMap != null ? AttendanceImpact.fromJson(impactMap) : null;

    return RequestItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      requestNumber: json['request_number']?.toString() ?? '',
      requestType: json['request_type']?.toString().toLowerCase() ?? 'izin',
      rawTypeLabel: json['type_label']?.toString(),
      title: json['title']?.toString() ?? 'Pengajuan',
      description: json['description']?.toString() ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString(),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      location: json['location']?.toString(),
      details: detailsMap,
      parsedDetails: parsedDetailsVal,
      attachmentUrl: json['attachment_url']?.toString(),
      status: statusStr,
      displayStatus: json['display_status']?.toString(),
      statusClass: json['status_class']?.toString(),
      attendanceImpact: attendanceImpactVal,
      isOwner: isOwnerVal,
      isParticipant: isParticipantVal,
      canCancel: canCancelVal,
      approvalFlow: json['approval_flow']?.toString(),
      managerApproval: json['manager_approval'] != null && json['manager_approval'] is Map<String, dynamic>
          ? ApprovalInfo.fromJson(json['manager_approval'] as Map<String, dynamic>)
          : null,
      hcgaApproval: json['hcga_approval'] != null && json['hcga_approval'] is Map<String, dynamic>
          ? ApprovalInfo.fromJson(json['hcga_approval'] as Map<String, dynamic>)
          : null,
      submittedAt: json['submitted_at']?.toString(),
      employee: json['employee'] != null && json['employee'] is Map<String, dynamic>
          ? EmployeeInfo.fromJson(json['employee'] as Map<String, dynamic>)
          : null,
    );
  }

  String get typeLabel {
    if (rawTypeLabel != null && rawTypeLabel!.isNotEmpty) {
      return rawTypeLabel!;
    }
    switch (requestType) {
      case 'cuti':
        return 'Libur Cuti';
      case 'sakit':
        return 'Tidak Masuk (Sakit)';
      case 'izin':
        return 'Tidak Masuk (Izin)';
      case 'lembur':
        return 'Lembur';
      case 'perjalanan_dinas':
      case 'dinas':
        return 'Perjalanan Dinas';
      default:
        return requestType.toUpperCase();
    }
  }

  String get effectiveDisplayStatus {
    if (displayStatus != null && displayStatus!.isNotEmpty) {
      return displayStatus!;
    }
    return status.toUpperCase();
  }

  IconData get typeIcon {
    switch (requestType) {
      case 'cuti':
        return Icons.beach_access_rounded;
      case 'sakit':
        return Icons.medical_services_rounded;
      case 'izin':
        return Icons.event_busy_rounded;
      case 'lembur':
        return Icons.access_time_filled_rounded;
      case 'perjalanan_dinas':
      case 'dinas':
        return Icons.flight_takeoff_rounded;
      default:
        return Icons.assignment_rounded;
    }
  }

  Color get typeColor {
    switch (requestType) {
      case 'cuti':
        return AppColors.primary;
      case 'sakit':
        return AppColors.error;
      case 'izin':
        return Colors.orange.shade800;
      case 'lembur':
        return Colors.indigo;
      case 'perjalanan_dinas':
      case 'dinas':
        return AppColors.tertiary;
      default:
        return AppColors.secondary;
    }
  }

  Color get statusColor {
    final s = status.toLowerCase();
    if (s.contains('disetujui')) {
      return Colors.green;
    } else if (s.contains('ditolak') || s.contains('dibatalkan')) {
      return AppColors.error;
    } else {
      return Colors.orange.shade800;
    }
  }
}

class ApprovalInfo {
  final String status; // Menunggu, Disetujui, Ditolak
  final String? approvedBy;
  final String? approvedAt;
  final String? note;

  ApprovalInfo({
    required this.status,
    this.approvedBy,
    this.approvedAt,
    this.note,
  });

  factory ApprovalInfo.fromJson(Map<String, dynamic> json) {
    return ApprovalInfo(
      status: json['status']?.toString() ?? 'Menunggu',
      approvedBy: json['approved_by']?.toString(),
      approvedAt: json['approved_at']?.toString(),
      note: json['note']?.toString(),
    );
  }
}

class EmployeeInfo {
  final String name;
  final String email;
  final String division;
  final String position;

  EmployeeInfo({
    required this.name,
    required this.email,
    required this.division,
    required this.position,
  });

  factory EmployeeInfo.fromJson(Map<String, dynamic> json) {
    return EmployeeInfo(
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      division: json['division']?.toString() ?? '',
      position: json['position']?.toString() ?? '',
    );
  }
}
