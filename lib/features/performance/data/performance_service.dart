import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/data/auth_service.dart';
import 'models/performance_models.dart';

class PerformanceApiResponse<T> {
  final bool success;
  final T? data;
  final String message;
  final int statusCode;
  final Map<String, dynamic>? errors;

  PerformanceApiResponse({
    required this.success,
    this.data,
    required this.message,
    this.statusCode = 200,
    this.errors,
  });
}

class PerformanceService {
  static Map<String, String> _buildHeaders(String token) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['errors'] != null && decoded['errors'] is Map) {
          final errMap = decoded['errors'] as Map<String, dynamic>;
          final firstKey = errMap.keys.firstOrNull;
          if (firstKey != null) {
            final val = errMap[firstKey];
            if (val is List && val.isNotEmpty) return val.first.toString();
            return val.toString();
          }
        }
        if (decoded['message'] != null) {
          return decoded['message'].toString();
        }
      }
    } catch (_) {}

    switch (response.statusCode) {
      case 401:
        return 'Sesi telah berakhir atau tidak valid. Silakan login kembali.';
      case 403:
        return 'Anda tidak memiliki hak akses untuk mengubah data ini.';
      case 404:
        return 'Data target atau item rencana tidak ditemukan.';
      case 422:
        return 'Validasi gagal. Periksa kembali isian formulir Anda.';
      case 500:
        return 'Terjadi kesalahan pada server backend (500).';
      default:
        return 'Permintaan gagal diproses (${response.statusCode}).';
    }
  }

  // ==========================================
  // MENU 1: Target Bulanan (Monthly Targets)
  // ==========================================

  /// 4.1 Ambil Hierarki Target Bulanan
  /// GET /api/performance/monthly-targets?year=...&period=...
  static Future<PerformanceApiResponse<MonthlyTargetData>> getMonthlyTargets({
    int? year,
    String? period,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return PerformanceApiResponse(
          success: false,
          statusCode: 401,
          message: 'Pengguna tidak terautentikasi.',
        );
      }

      final queryParams = <String, String>{};
      if (year != null) queryParams['year'] = year.toString();
      if (period != null && period.isNotEmpty) queryParams['period'] = period;

      final uri = Uri.parse('${AuthService.baseUrl}/performance/monthly-targets')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http
          .get(uri, headers: _buildHeaders(token))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success' && decoded['data'] != null) {
          final data = MonthlyTargetData.fromJson(decoded['data']);
          return PerformanceApiResponse(
            success: true,
            statusCode: 200,
            data: data,
            message: decoded['message']?.toString() ?? 'Berhasil memuat target bulanan.',
          );
        }
      }

      return PerformanceApiResponse(
        success: false,
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
      );
    } catch (e) {
      return PerformanceApiResponse(
        success: false,
        statusCode: 0,
        message: 'Koneksi gagal atau bermasalah: $e',
      );
    }
  }

  /// 4.2 Tambah Target Bulanan
  /// POST /api/performance/monthly-targets
  static Future<PerformanceApiResponse<Map<String, dynamic>>> createMonthlyTarget(
    Map<String, dynamic> body,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return PerformanceApiResponse(
          success: false,
          statusCode: 401,
          message: 'Pengguna tidak terautentikasi.',
        );
      }

      final uri = Uri.parse('${AuthService.baseUrl}/performance/monthly-targets');
      final response = await http
          .post(
            uri,
            headers: _buildHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PerformanceApiResponse(
          success: true,
          statusCode: response.statusCode,
          data: decoded['data'] is Map<String, dynamic> ? decoded['data'] : null,
          message: decoded['message']?.toString() ?? 'Target berhasil ditambahkan.',
        );
      }

      return PerformanceApiResponse(
        success: false,
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
      );
    } catch (e) {
      return PerformanceApiResponse(
        success: false,
        statusCode: 0,
        message: 'Gagal menambahkan target: $e',
      );
    }
  }

  /// 4.3 Update Target Bulanan
  /// PATCH /api/performance/monthly-targets/{id}
  static Future<PerformanceApiResponse<Map<String, dynamic>>> updateMonthlyTarget(
    int id,
    Map<String, dynamic> body,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return PerformanceApiResponse(
          success: false,
          statusCode: 401,
          message: 'Pengguna tidak terautentikasi.',
        );
      }

      final uri = Uri.parse('${AuthService.baseUrl}/performance/monthly-targets/$id');
      var response = await http
          .patch(
            uri,
            headers: _buildHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      // Fallback: jika PATCH ditolak server (405 Method Not Allowed), gunakan PUT
      if (response.statusCode == 405) {
        response = await http
            .put(
              uri,
              headers: _buildHeaders(token),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
      }

      final decoded = jsonDecode(response.body);
      final isStatusSuccess = decoded is Map &&
          (decoded['status'] == 'success' ||
              decoded['status'] == true ||
              decoded['success'] == true ||
              (!decoded.containsKey('status') && !decoded.containsKey('success')));

      if ((response.statusCode == 200 || response.statusCode == 201) && isStatusSuccess) {
        return PerformanceApiResponse(
          success: true,
          statusCode: response.statusCode,
          data: decoded['data'] is Map<String, dynamic> ? decoded['data'] : null,
          message: decoded['message']?.toString() ?? 'Target berhasil diperbarui.',
        );
      }

      return PerformanceApiResponse(
        success: false,
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
      );
    } catch (e) {
      return PerformanceApiResponse(
        success: false,
        statusCode: 0,
        message: 'Gagal memperbarui target: $e',
      );
    }
  }

  // ==========================================
  // MENU 2: Weekly Plan (Rencana Mingguan)
  // ==========================================

  /// 4.4 Ambil Rencana Pekan Berjalan
  /// GET /api/performance/weekly-plan?week_date=...
  static Future<PerformanceApiResponse<WeeklyPlanData>> getWeeklyPlan({
    String? weekDate,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return PerformanceApiResponse(
          success: false,
          statusCode: 401,
          message: 'Pengguna tidak terautentikasi.',
        );
      }

      final queryParams = <String, String>{};
      if (weekDate != null && weekDate.isNotEmpty) {
        queryParams['week_date'] = weekDate;
      }

      final uri = Uri.parse('${AuthService.baseUrl}/performance/weekly-plan')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http
          .get(uri, headers: _buildHeaders(token))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success' && decoded['data'] != null) {
          final data = WeeklyPlanData.fromJson(decoded['data']);
          return PerformanceApiResponse(
            success: true,
            statusCode: 200,
            data: data,
            message: decoded['message']?.toString() ?? 'Berhasil memuat rencana mingguan.',
          );
        }
      }

      return PerformanceApiResponse(
        success: false,
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
      );
    } catch (e) {
      return PerformanceApiResponse(
        success: false,
        statusCode: 0,
        message: 'Gagal memuat rencana mingguan: $e',
      );
    }
  }

  /// 4.5 Tambah Item Rencana Mingguan Mandiri
  /// POST /api/performance/weekly-plan
  static Future<PerformanceApiResponse<Map<String, dynamic>>> createWeeklyPlanItem(
    Map<String, dynamic> body,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return PerformanceApiResponse(
          success: false,
          statusCode: 401,
          message: 'Pengguna tidak terautentikasi.',
        );
      }

      final uri = Uri.parse('${AuthService.baseUrl}/performance/weekly-plan');
      final response = await http
          .post(
            uri,
            headers: _buildHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return PerformanceApiResponse(
          success: true,
          statusCode: response.statusCode,
          data: decoded['data'] is Map<String, dynamic> ? decoded['data'] : null,
          message: decoded['message']?.toString() ?? 'Rencana mingguan berhasil ditambahkan.',
        );
      }

      return PerformanceApiResponse(
        success: false,
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
      );
    } catch (e) {
      return PerformanceApiResponse(
        success: false,
        statusCode: 0,
        message: 'Gagal menambahkan rencana mingguan: $e',
      );
    }
  }

  /// 4.6 Update Rincian Rencana Mingguan
  /// PATCH /api/performance/weekly-plan/items/{id}
  static Future<PerformanceApiResponse<Map<String, dynamic>>> updateWeeklyPlanItem(
    int itemId,
    Map<String, dynamic> body,
  ) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return PerformanceApiResponse(
          success: false,
          statusCode: 401,
          message: 'Pengguna tidak terautentikasi.',
        );
      }

      final uri = Uri.parse('${AuthService.baseUrl}/performance/weekly-plan/items/$itemId');
      final response = await http
          .patch(
            uri,
            headers: _buildHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return PerformanceApiResponse(
          success: true,
          statusCode: 200,
          data: decoded['data'] is Map<String, dynamic> ? decoded['data'] : null,
          message: decoded['message']?.toString() ?? 'Rencana berhasil diperbarui.',
        );
      }

      return PerformanceApiResponse(
        success: false,
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
      );
    } catch (e) {
      return PerformanceApiResponse(
        success: false,
        statusCode: 0,
        message: 'Gagal memperbarui item rencana: $e',
      );
    }
  }

  // ==========================================
  // MENU 3: Weekly Review (Evaluasi Mingguan)
  // ==========================================

  /// 4.7 Ambil Item Evaluasi Akhir Pekan
  /// GET /api/performance/weekly-review?week_date=...
  static Future<PerformanceApiResponse<WeeklyReviewData>> getWeeklyReview({
    String? weekDate,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return PerformanceApiResponse(
          success: false,
          statusCode: 401,
          message: 'Pengguna tidak terautentikasi.',
        );
      }

      final queryParams = <String, String>{};
      if (weekDate != null && weekDate.isNotEmpty) {
        queryParams['week_date'] = weekDate;
      }

      final uri = Uri.parse('${AuthService.baseUrl}/performance/weekly-review')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http
          .get(uri, headers: _buildHeaders(token))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == 'success' && decoded['data'] != null) {
          final data = WeeklyReviewData.fromJson(decoded['data']);
          return PerformanceApiResponse(
            success: true,
            statusCode: 200,
            data: data,
            message: decoded['message']?.toString() ?? 'Berhasil memuat weekly review.',
          );
        }
      }

      return PerformanceApiResponse(
        success: false,
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
      );
    } catch (e) {
      return PerformanceApiResponse(
        success: false,
        statusCode: 0,
        message: 'Gagal memuat evaluasi mingguan: $e',
      );
    }
  }

  /// 4.8 Simpan Batch Weekly Review (Simpan Sekaligus)
  /// PATCH /api/performance/weekly-review (bisa juga POST)
  static Future<PerformanceApiResponse<Map<String, dynamic>>> submitWeeklyReviewBatch({
    required String weekDate,
    required Map<String, dynamic> items,
  }) async {
    try {
      final token = await AuthService.getToken();
      if (token == null) {
        return PerformanceApiResponse(
          success: false,
          statusCode: 401,
          message: 'Pengguna tidak terautentikasi.',
        );
      }

      final uri = Uri.parse('${AuthService.baseUrl}/performance/weekly-review');
      final body = {
        'week_date': weekDate,
        'items': items,
      };

      // Try PATCH first as specified in docs
      var response = await http
          .patch(
            uri,
            headers: _buildHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      // If method not allowed (405), try POST as mentioned in docs "(bisa juga menggunakan POST)"
      if (response.statusCode == 405) {
        response = await http
            .post(
              uri,
              headers: _buildHeaders(token),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
      }

      final decoded = jsonDecode(response.body);
      final isStatusSuccess = decoded is Map &&
          (decoded['status'] == 'success' ||
              decoded['status'] == true ||
              decoded['success'] == true ||
              (!decoded.containsKey('status') && !decoded.containsKey('success')));

      if ((response.statusCode == 200 || response.statusCode == 201) && isStatusSuccess) {
        return PerformanceApiResponse(
          success: true,
          statusCode: response.statusCode,
          data: decoded['data'] is Map<String, dynamic> ? decoded['data'] : null,
          message: decoded['message']?.toString() ??
              'Weekly Review berhasil disimpan dan status kinerja telah dihitung ulang.',
        );
      }

      return PerformanceApiResponse(
        success: false,
        statusCode: response.statusCode,
        message: _extractErrorMessage(response),
      );
    } catch (e) {
      return PerformanceApiResponse(
        success: false,
        statusCode: 0,
        message: 'Gagal menyimpan weekly review: $e',
      );
    }
  }
}
