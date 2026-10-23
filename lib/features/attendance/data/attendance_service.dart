import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/data/auth_service.dart';
import 'models/attendance_models.dart';

class AttendanceService {
  /// 3.4 Status Presensi Hari Ini (Realtime Status)
  /// GET /api/attendance/today?employee_id=...
  static Future<Map<String, dynamic>?> getToday({int? employeeId}) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (employeeId != null) queryParams['employee_id'] = employeeId.toString();

      final uri = Uri.parse('${AuthService.baseUrl}/attendance/today').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] is Map<String, dynamic>) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print("Today Error: $e");
      return null;
    }
  }

  /// Helper untuk mengambil model AttendanceToday langsung
  static Future<AttendanceToday?> getTodayModel({int? employeeId}) async {
    final raw = await getToday(employeeId: employeeId);
    if (raw != null) {
      return AttendanceToday.fromJson(raw);
    }
    return null;
  }

  /// 3.1 Ambil Riwayat Absensi Per Karyawan (Integrated History)
  /// GET /api/attendance/history
  static Future<AttendanceHistoryResponse?> getHistory({
    int? month,
    int? year,
    int? employeeId,
    String? status,
    String? order = 'desc',
    int? page,
    int? perPage = 31,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();
      if (employeeId != null) queryParams['employee_id'] = employeeId.toString();
      if (status != null && status.isNotEmpty && status.toLowerCase() != 'semua') {
        queryParams['status'] = status;
      }
      if (order != null) queryParams['order'] = order;
      if (page != null) queryParams['page'] = page.toString();
      if (perPage != null) queryParams['per_page'] = perPage.toString();

      final uri = Uri.parse('${AuthService.baseUrl}/attendance/history').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] != null) {
          return AttendanceHistoryResponse.fromJson(decoded['data']);
        } else if (decoded is List) {
          return AttendanceHistoryResponse.fromJson(decoded);
        }
        return AttendanceHistoryResponse.fromJson(decoded);
      } else if (response.statusCode == 403) {
        try {
          final decoded = jsonDecode(response.body);
          throw Exception(decoded['message'] ?? 'Anda tidak memiliki hak akses untuk melihat presensi karyawan ini.');
        } catch (e) {
          if (e is Exception && !e.toString().contains('FormatException')) rethrow;
          throw Exception('Akses ditolak (403 Forbidden).');
        }
      } else {
        String msg = 'Gagal memuat riwayat presensi (${response.statusCode})';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded['message'] != null) msg = decoded['message'];
        } catch (_) {}
        throw Exception(msg);
      }
    } catch (e) {
      print("GetHistory Error: $e");
      rethrow;
    }
  }

  /// 3.2 Ambil Riwayat Absensi Karyawan Spesifik (Direct URL)
  /// GET /api/attendance/employee/{employee_id}
  static Future<AttendanceHistoryResponse?> getEmployeeHistory(
    int employeeId, {
    int? month,
    int? year,
    String? status,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();
      if (status != null && status.isNotEmpty && status.toLowerCase() != 'semua') {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('${AuthService.baseUrl}/attendance/employee/$employeeId').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] != null) {
          return AttendanceHistoryResponse.fromJson(decoded['data']);
        }
      }
      return null;
    } catch (e) {
      print("GetEmployeeHistory Error: $e");
      return null;
    }
  }

  /// 3.3 Daftar Karyawan yang Dapat Dipilih (Dropdown Filter Atasan/HCGA)
  /// GET /api/attendance/employees
  static Future<List<AttendanceEmployee>> getEmployees() async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return [];

      final uri = Uri.parse('${AuthService.baseUrl}/attendance/employees');
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['data'] is List) {
          final raw = decoded['data'] as List<dynamic>;
          return raw
              .whereType<Map<String, dynamic>>()
              .map((e) => AttendanceEmployee.fromJson(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print("GetEmployees Error: $e");
      return [];
    }
  }

  /// 3.5 Statistik Kehadiran Bulanan (Statistik Terpadu)
  /// GET /api/attendance/statistics?month=...&year=...&employee_id=...
  static Future<AttendanceStatistics?> getStatistics({
    int? month,
    int? year,
    int? employeeId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();
      if (employeeId != null) queryParams['employee_id'] = employeeId.toString();

      final uri = Uri.parse('${AuthService.baseUrl}/attendance/statistics').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['data'] != null && decoded['data']['statistics'] is Map<String, dynamic>) {
          return AttendanceStatistics.fromJson(decoded['data']['statistics']);
        }
      }
      return null;
    } catch (e) {
      print("Statistics Error: $e");
      return null;
    }
  }

  /// 3.6 Ringkasan Kalender dan Absensi Bulanan (Dedicated Endpoint)
  /// GET /api/attendance/summary?month=...&year=...&employee_id=...
  /// Alias endpoint — struktur respons identik dengan GET /api/attendance/history.
  static Future<AttendanceHistoryResponse?> getSummaryDedicated({
    int? month,
    int? year,
    int? employeeId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final queryParams = <String, String>{};
      if (month != null) queryParams['month'] = month.toString();
      if (year != null) queryParams['year'] = year.toString();
      if (employeeId != null) queryParams['employee_id'] = employeeId.toString();

      final uri = Uri.parse('${AuthService.baseUrl}/attendance/summary').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['data'] != null) {
          return AttendanceHistoryResponse.fromJson(decoded['data']);
        }
      }
      return null;
    } catch (e) {
      print("GetSummary Error: $e");
      return null;
    }
  }

  /// 3.7 Export Rekapan Absensi ke CSV
  /// GET /api/attendance/export?month=10&year=2026&employee_id=...
  static Future<String?> exportAttendanceCSV(
    int month,
    int year, {
    int? employeeId,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) return null;

      final queryParams = <String, String>{
        'month': month.toString(),
        'year': year.toString(),
      };
      if (employeeId != null) queryParams['employee_id'] = employeeId.toString();

      final uri = Uri.parse('${AuthService.baseUrl}/attendance/export').replace(
        queryParameters: queryParams,
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'text/csv, application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return response.body; // Raw CSV text
      }
      return null;
    } catch (e) {
      print("Export Error: $e");
      return null;
    }
  }

  /// Backward-compatible summary accessor.
  /// Menggunakan endpoint dedicated /api/attendance/summary (3.6);
  /// fallback ke /api/attendance/history jika endpoint summary gagal.
  /// CATATAN: Endpoint POST check-in/check-out legacy (3.8) tidak digunakan
  /// di aplikasi mobile baru sesuai kontrak dokumentasi API.
  static Future<Map<String, dynamic>?> getSummary({
    int? month,
    int? year,
    int? employeeId,
  }) async {
    // Coba endpoint dedicated /summary terlebih dahulu
    final summaryRes = await getSummaryDedicated(
      month: month,
      year: year,
      employeeId: employeeId,
    );
    if (summaryRes != null) {
      return {
        'statistics': summaryRes.statistics,
        'history': summaryRes.history,
        'employee': summaryRes.employee,
        'period': summaryRes.period,
        'schedule': summaryRes.schedule,
      };
    }

    // Fallback: gunakan /history jika /summary tidak tersedia
    final histRes = await getHistory(
      month: month,
      year: year,
      employeeId: employeeId,
      perPage: 31,
    );
    if (histRes != null) {
      return {
        'statistics': histRes.statistics,
        'history': histRes.history,
        'employee': histRes.employee,
        'period': histRes.period,
        'schedule': histRes.schedule,
      };
    }
    return null;
  }
}
