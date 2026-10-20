import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../auth/data/auth_service.dart';
import 'models/request_models.dart';

class RequestApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? statusCode;

  RequestApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });
}

class RequestsService {
  static Future<Map<String, String>> _getHeaders({bool isMultipart = false}) async {
    final token = await AuthService.getToken();
    final headers = {
      'Accept': 'application/json',
    };
    if (!isMultipart) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
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
        return 'Sesi login telah berakhir atau tidak valid (401). Silakan login kembali.';
      case 403:
        return 'Anda tidak memiliki hak akses mengubah/menyetujui data ini (403).';
      case 404:
        return 'Data pengajuan, target, atau item rencana tidak ditemukan (404).';
      case 422:
        return 'Validasi gagal. Periksa kembali isian formulir Anda (422).';
      case 500:
        return 'Terjadi kesalahan pada server backend (500).';
      default:
        return 'Permintaan gagal diproses (${response.statusCode}).';
    }
  }

  /// 5.2 Metadata Form Pengajuan & Daftar Karyawan
  /// GET /api/requests/meta
  static Future<RequestApiResponse<RequestMeta>> getRequestMeta() async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/requests/meta');
      final headers = await _getHeaders();
      final res = await http.get(uri, headers: headers);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'] != null && decoded['data'] is Map<String, dynamic>
            ? RequestMeta.fromJson(decoded['data'] as Map<String, dynamic>)
            : RequestMeta(canUseElevatedTypes: false, availableTypes: [], employees: []);
        return RequestApiResponse(
          success: true,
          message: decoded['message']?.toString() ?? 'Berhasil memuat metadata',
          data: data,
          statusCode: res.statusCode,
        );
      } else {
        return RequestApiResponse(
          success: false,
          message: _extractErrorMessage(res),
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return RequestApiResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }

  /// 5.4 Ambil Riwayat Pengajuan Sendiri
  /// GET /api/requests?status=...&request_type=...
  static Future<RequestApiResponse<List<RequestItem>>> getRequests({
    String? status,
    String? requestType,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty && status.toLowerCase() != 'semua') {
        queryParams['status'] = status;
      }
      if (requestType != null && requestType.isNotEmpty && requestType.toLowerCase() != 'semua') {
        queryParams['request_type'] = requestType;
      }

      final uri = Uri.parse('${AuthService.baseUrl}/requests').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final headers = await _getHeaders();
      final res = await http.get(uri, headers: headers);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final rawList = decoded['data'] as List<dynamic>? ?? [];
        final items = rawList
            .map((e) => RequestItem.fromJson(e as Map<String, dynamic>))
            .toList();
        return RequestApiResponse(
          success: true,
          message: decoded['message']?.toString() ?? 'Berhasil memuat pengajuan',
          data: items,
          statusCode: res.statusCode,
        );
      } else {
        return RequestApiResponse(
          success: false,
          message: _extractErrorMessage(res),
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return RequestApiResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }

  /// 5.5 Helper URL endpoint khusus atau terpadu
  static String resolveRequestEndpoint(String requestType, {bool dedicated = false}) {
    if (!dedicated) return '${AuthService.baseUrl}/requests';
    switch (requestType.toLowerCase().trim()) {
      case 'izin':
        return '${AuthService.baseUrl}/requests/izin';
      case 'sakit':
        return '${AuthService.baseUrl}/requests/sakit';
      case 'cuti':
        return '${AuthService.baseUrl}/requests/cuti';
      case 'lembur':
        return '${AuthService.baseUrl}/requests/lembur';
      case 'perjalanan_dinas':
      case 'dinas':
        return '${AuthService.baseUrl}/requests/perjalanan-dinas';
      default:
        return '${AuthService.baseUrl}/requests';
    }
  }

  /// 5.5 Buat Pengajuan Baru
  /// POST /api/requests atau endpoint khusus (POST /api/requests/izin, /sakit, dsb)
  static Future<RequestApiResponse<Map<String, dynamic>>> createRequest({
    required String requestType,
    required String description,
    required String startDate,
    String? endDate,
    String? startTime,
    String? endTime,
    String? location,
    String? tipeWaktu,
    String? tipePeserta,
    List<int>? peserta,
    File? attachment,
    bool useDedicatedEndpoint = false,
  }) async {
    try {
      final targetUrl = resolveRequestEndpoint(requestType, dedicated: useDedicatedEndpoint);
      final uri = Uri.parse(targetUrl);
      final token = await AuthService.getToken();

      if (attachment != null && await attachment.exists()) {
        final request = http.MultipartRequest('POST', uri);
        request.headers['Accept'] = 'application/json';
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        request.fields['request_type'] = requestType;
        request.fields['description'] = description;
        request.fields['start_date'] = startDate;

        if (endDate != null && endDate.isNotEmpty) {
          request.fields['end_date'] = endDate;
        }
        if (startTime != null && startTime.isNotEmpty) {
          request.fields['start_time'] = startTime;
        }
        if (endTime != null && endTime.isNotEmpty) {
          request.fields['end_time'] = endTime;
        }
        if (location != null && location.isNotEmpty) {
          request.fields['location'] = location;
        }
        if (tipeWaktu != null && tipeWaktu.isNotEmpty) {
          request.fields['tipe_waktu'] = tipeWaktu;
        }
        if (tipePeserta != null && tipePeserta.isNotEmpty) {
          request.fields['tipe_peserta'] = tipePeserta;
        }
        if (peserta != null && peserta.isNotEmpty) {
          for (int i = 0; i < peserta.length; i++) {
            request.fields['peserta[$i]'] = peserta[i].toString();
            request.fields['peserta[]'] = peserta[i].toString();
          }
        }

        final multipartFile = await http.MultipartFile.fromPath(
          'attachment',
          attachment.path,
        );
        request.files.add(multipartFile);

        final streamedResponse = await request.send();
        final res = await http.Response.fromStream(streamedResponse);

        if (res.statusCode == 200 || res.statusCode == 201) {
          final decoded = jsonDecode(res.body);
          return RequestApiResponse(
            success: true,
            message: decoded['message']?.toString() ?? 'Pengajuan berhasil dibuat.',
            data: decoded['data'] is Map<String, dynamic> ? decoded['data'] : null,
            statusCode: res.statusCode,
          );
        } else {
          return RequestApiResponse(
            success: false,
            message: _extractErrorMessage(res),
            statusCode: res.statusCode,
          );
        }
      } else {
        final body = <String, dynamic>{
          'request_type': requestType,
          'description': description,
          'start_date': startDate,
        };
        if (endDate != null && endDate.isNotEmpty) {
          body['end_date'] = endDate;
        }
        if (startTime != null && startTime.isNotEmpty) {
          body['start_time'] = startTime;
        }
        if (endTime != null && endTime.isNotEmpty) {
          body['end_time'] = endTime;
        }
        if (location != null && location.isNotEmpty) {
          body['location'] = location;
        }
        if (tipeWaktu != null && tipeWaktu.isNotEmpty) {
          body['tipe_waktu'] = tipeWaktu;
        }
        if (tipePeserta != null && tipePeserta.isNotEmpty) {
          body['tipe_peserta'] = tipePeserta;
        }
        if (peserta != null && peserta.isNotEmpty) {
          body['peserta'] = peserta;
        }

        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        };

        final res = await http.post(uri, headers: headers, body: jsonEncode(body));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final decoded = jsonDecode(res.body);
          return RequestApiResponse(
            success: true,
            message: decoded['message']?.toString() ?? 'Pengajuan berhasil dibuat.',
            data: decoded['data'] is Map<String, dynamic> ? decoded['data'] : null,
            statusCode: res.statusCode,
          );
        } else {
          return RequestApiResponse(
            success: false,
            message: _extractErrorMessage(res),
            statusCode: res.statusCode,
          );
        }
      }
    } catch (e) {
      return RequestApiResponse(
        success: false,
        message: 'Gagal mengirim pengajuan: $e',
      );
    }
  }

  /// 5.6 Perbarui / Edit Pengajuan (Selama Masih Pending)
  /// PUT /api/requests/{id} atau PATCH /api/requests/{id}
  static Future<RequestApiResponse<Map<String, dynamic>>> updateRequest({
    required int id,
    required String requestType,
    required String description,
    required String startDate,
    String? endDate,
    String? startTime,
    String? endTime,
    String? location,
    String? tipeWaktu,
    String? tipePeserta,
    List<int>? peserta,
    File? attachment,
  }) async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/requests/$id');
      final token = await AuthService.getToken();

      if (attachment != null && await attachment.exists()) {
        final request = http.MultipartRequest('POST', uri);
        request.headers['Accept'] = 'application/json';
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }

        // Method spoofing for multipart PUT
        request.fields['_method'] = 'PUT';
        request.fields['request_type'] = requestType;
        request.fields['description'] = description;
        request.fields['start_date'] = startDate;

        if (endDate != null && endDate.isNotEmpty) {
          request.fields['end_date'] = endDate;
        }
        if (startTime != null && startTime.isNotEmpty) {
          request.fields['start_time'] = startTime;
        }
        if (endTime != null && endTime.isNotEmpty) {
          request.fields['end_time'] = endTime;
        }
        if (location != null && location.isNotEmpty) {
          request.fields['location'] = location;
        }
        if (tipeWaktu != null && tipeWaktu.isNotEmpty) {
          request.fields['tipe_waktu'] = tipeWaktu;
        }
        if (tipePeserta != null && tipePeserta.isNotEmpty) {
          request.fields['tipe_peserta'] = tipePeserta;
        }
        if (peserta != null && peserta.isNotEmpty) {
          for (int i = 0; i < peserta.length; i++) {
            request.fields['peserta[$i]'] = peserta[i].toString();
            request.fields['peserta[]'] = peserta[i].toString();
          }
        }

        final multipartFile = await http.MultipartFile.fromPath(
          'attachment',
          attachment.path,
        );
        request.files.add(multipartFile);

        final streamedResponse = await request.send();
        final res = await http.Response.fromStream(streamedResponse);

        if (res.statusCode == 200 || res.statusCode == 201) {
          final decoded = jsonDecode(res.body);
          return RequestApiResponse(
            success: true,
            message: decoded['message']?.toString() ?? 'Pengajuan berhasil diperbarui.',
            data: decoded['data'] is Map<String, dynamic> ? decoded['data'] : null,
            statusCode: res.statusCode,
          );
        } else {
          return RequestApiResponse(
            success: false,
            message: _extractErrorMessage(res),
            statusCode: res.statusCode,
          );
        }
      } else {
        final body = <String, dynamic>{
          'request_type': requestType,
          'description': description,
          'start_date': startDate,
        };
        if (endDate != null && endDate.isNotEmpty) {
          body['end_date'] = endDate;
        }
        if (startTime != null && startTime.isNotEmpty) {
          body['start_time'] = startTime;
        }
        if (endTime != null && endTime.isNotEmpty) {
          body['end_time'] = endTime;
        }
        if (location != null && location.isNotEmpty) {
          body['location'] = location;
        }
        if (tipeWaktu != null && tipeWaktu.isNotEmpty) {
          body['tipe_waktu'] = tipeWaktu;
        }
        if (tipePeserta != null && tipePeserta.isNotEmpty) {
          body['tipe_peserta'] = tipePeserta;
        }
        if (peserta != null && peserta.isNotEmpty) {
          body['peserta'] = peserta;
        }

        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        };

        final res = await http.put(uri, headers: headers, body: jsonEncode(body));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final decoded = jsonDecode(res.body);
          return RequestApiResponse(
            success: true,
            message: decoded['message']?.toString() ?? 'Pengajuan berhasil diperbarui.',
            data: decoded['data'] is Map<String, dynamic> ? decoded['data'] : null,
            statusCode: res.statusCode,
          );
        } else {
          return RequestApiResponse(
            success: false,
            message: _extractErrorMessage(res),
            statusCode: res.statusCode,
          );
        }
      }
    } catch (e) {
      return RequestApiResponse(
        success: false,
        message: 'Gagal memperbarui pengajuan: $e',
      );
    }
  }

  /// 5.7 Detail Pengajuan
  /// GET /api/requests/{id}
  static Future<RequestApiResponse<RequestItem>> getRequestDetail(int id) async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/requests/$id');
      final headers = await _getHeaders();
      final res = await http.get(uri, headers: headers);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final item = RequestItem.fromJson(decoded['data'] as Map<String, dynamic>);
        return RequestApiResponse(
          success: true,
          message: decoded['message']?.toString() ?? 'Berhasil memuat detail',
          data: item,
          statusCode: res.statusCode,
        );
      } else {
        return RequestApiResponse(
          success: false,
          message: _extractErrorMessage(res),
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return RequestApiResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }

  /// 5.8 Batalkan Pengajuan
  /// DELETE /api/requests/{id}
  static Future<RequestApiResponse<void>> cancelRequest(int id) async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/requests/$id');
      final headers = await _getHeaders();
      final res = await http.delete(uri, headers: headers);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return RequestApiResponse(
          success: true,
          message: decoded['message']?.toString() ?? 'Pengajuan berhasil dibatalkan.',
          statusCode: res.statusCode,
        );
      } else {
        return RequestApiResponse(
          success: false,
          message: _extractErrorMessage(res),
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return RequestApiResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }

  /// 5.9 Daftar Pengajuan yang Perlu Disetujui (Inbox Approval Atasan)
  /// GET /api/requests/approvals
  static Future<RequestApiResponse<List<RequestItem>>> getApprovals() async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/requests/approvals');
      final headers = await _getHeaders();
      final res = await http.get(uri, headers: headers);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final rawList = decoded['data'] as List<dynamic>? ?? [];
        final items = rawList
            .map((e) => RequestItem.fromJson(e as Map<String, dynamic>))
            .toList();
        return RequestApiResponse(
          success: true,
          message: decoded['message']?.toString() ?? 'Berhasil memuat persetujuan.',
          data: items,
          statusCode: res.statusCode,
        );
      } else {
        return RequestApiResponse(
          success: false,
          message: _extractErrorMessage(res),
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return RequestApiResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }

  /// 5.10 Setujui Pengajuan (Approve by Manager)
  /// POST /api/requests/{id}/approve
  static Future<RequestApiResponse<void>> approveRequest(
    int id, {
    String? note,
  }) async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/requests/$id/approve');
      final headers = await _getHeaders();
      final body = jsonEncode({
        if (note != null && note.isNotEmpty) 'note': note,
      });

      final res = await http.post(uri, headers: headers, body: body);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return RequestApiResponse(
          success: true,
          message: decoded['message']?.toString() ?? 'Persetujuan berhasil diproses: Disetujui.',
          statusCode: res.statusCode,
        );
      } else {
        return RequestApiResponse(
          success: false,
          message: _extractErrorMessage(res),
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return RequestApiResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }

  /// 5.11 Tolak Pengajuan (Reject by Manager)
  /// POST /api/requests/{id}/reject
  static Future<RequestApiResponse<void>> rejectRequest(
    int id, {
    required String note,
  }) async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/requests/$id/reject');
      final headers = await _getHeaders();
      final body = jsonEncode({'note': note});

      final res = await http.post(uri, headers: headers, body: body);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        return RequestApiResponse(
          success: true,
          message: decoded['message']?.toString() ?? 'Persetujuan berhasil diproses: Ditolak.',
          statusCode: res.statusCode,
        );
      } else {
        return RequestApiResponse(
          success: false,
          message: _extractErrorMessage(res),
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return RequestApiResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }
}
