import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../auth/data/auth_service.dart';
import 'models/attendance_models.dart';

class AttendanceService {
  /// Flag konfigurasi untuk presensi mobile via kamera selfie & GPS.
  /// Sementara dinonaktifkan (`false`) karena presensi terhubung ke mesin absensi fisik (FingerSpot).
  /// Jangan dihapus: ubah kembali ke `true` jika fitur kamera selfie ingin diaktifkan lagi di kemudian hari.
  static const bool isSelfieAttendanceEnabled = false;

  /// Flag konfigurasi untuk menampilkan peta lokasi kantor & radius absensi di halaman kehadiran.
  /// Sementara di-hidden (`false`) sesuai arahan operasional.
  /// Jangan dihapus: ubah kembali ke `true` jika peta ingin dimunculkan kembali.
  static const bool isMapVisible = false;

  /// 3.6 Absen Masuk Mobile (Check-In GPS & Foto)
  /// POST /api/attendance/check-in
  static Future<Map<String, dynamic>> checkIn(
    String lat,
    String lng,
    File photo,
  ) async {
    return _sendMultipartRequest('/attendance/check-in', lat, lng, photo);
  }

  /// 3.7 Absen Pulang Mobile (Check-Out GPS & Foto)
  /// POST /api/attendance/check-out
  static Future<Map<String, dynamic>> checkOut(
    String lat,
    String lng,
    File? photo,
  ) async {
    return _sendMultipartRequest('/attendance/check-out', lat, lng, photo);
  }

  static Future<Map<String, dynamic>> _sendMultipartRequest(
    String endpoint,
    String lat,
    String lng,
    File? photo,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Sesi telah berakhir. Silakan login kembali.',
        };
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AuthService.baseUrl}$endpoint'),
      );
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.fields['latitude'] = lat;
      request.fields['longitude'] = lng;

      if (photo != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', photo.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      try {
        final data = jsonDecode(response.body);

        if (data['distance'] != null) {
          final num jarak = data['distance'];
          print('Jarak user saat ini: $jarak meter');
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          return {
            'success': true,
            'message': data['message'] ?? 'Berhasil',
            'data': data['data'],
            'distance': data['distance'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Terjadi kesalahan pada server (${response.statusCode}).',
          };
        }
      } catch (e) {
        print("Server returned HTML or non-JSON! Status: ${response.statusCode}, Body: ${response.body}");
        return {
          'success': false,
          'message': 'API Error (Status ${response.statusCode}). Cek console.',
        };
      }
    } catch (e) {
      print("Attendance Error: $e");
      return {'success': false, 'message': 'Gagal: $e'};
    }
  }

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

  /// 3.8 Export Rekapan Absensi ke CSV
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

  /// Backward-compatible summary accessor
  static Future<Map<String, dynamic>?> getSummary({
    int? month,
    int? year,
    int? employeeId,
  }) async {
    final res = await getHistory(
      month: month,
      year: year,
      employeeId: employeeId,
      perPage: 31,
    );
    if (res != null) {
      return {
        'statistics': res.statistics,
        'history': res.history,
        'employee': res.employee,
        'period': res.period,
        'schedule': res.schedule,
      };
    }
    return null;
  }
}
