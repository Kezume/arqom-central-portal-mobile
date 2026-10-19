import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../auth/data/auth_service.dart';
import 'models/agenda_models.dart';

class AgendaService {
  /// Cache in-memory untuk efisiensi loading daftar agenda
  static List<AgendaItem>? _cachedAgendas;
  static DateTime? _lastCacheTime;

  static List<AgendaItem>? get cachedAgendas => _cachedAgendas;
  static DateTime? get lastCacheTime => _lastCacheTime;

  /// Bersihkan cache agenda saat logout / berganti akun
  static void clearCache() {
    _cachedAgendas = null;
    _lastCacheTime = null;
    if (kDebugMode) {
      print('Agenda cache berhasil dibersihkan.');
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// 6.2 Ambil Daftar Agenda Saya
  /// GET /api/agendas?from=...&to=...&type=...&page=...&per_page=...
  static Future<AgendaListResponse> getAgendas({
    String? from,
    String? to,
    String? type,
    int page = 1,
    int perPage = 30,
    bool forceRefresh = false,
  }) async {
    try {
      // Default dates as specified in 6.2:
      // from: default hari ini WIB (YYYY-MM-DD)
      // to: default 3 bulan setelah from
      final now = DateTime.now();
      final fromDateStr = from ?? DateFormat('yyyy-MM-dd').format(now);
      final fromDate = DateTime.tryParse(fromDateStr) ?? now;
      final defaultToDate = DateTime(fromDate.year, fromDate.month + 3, fromDate.day);
      final toDateStr = to ?? DateFormat('yyyy-MM-dd').format(defaultToDate);

      final queryParams = <String, String>{
        'from': fromDateStr,
        'to': toDateStr,
        'page': page.toString(),
        'per_page': perPage.clamp(1, 100).toString(),
      };

      if (type != null && type.isNotEmpty && type != 'Semua') {
        queryParams['type'] = type;
      }

      final uri = Uri.parse('${AuthService.baseUrl}/agendas').replace(queryParameters: queryParams);
      final headers = await _getHeaders();

      if (kDebugMode) {
        print('GET /api/agendas request: $uri');
      }

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('GET /api/agendas response status: ${res.statusCode}');
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final rawList = decoded['data'] as List<dynamic>? ?? [];
        final items = rawList
            .whereType<Map<String, dynamic>>()
            .map((e) => AgendaItem.fromJson(e))
            .toList();

        AgendaPaginationMeta? meta;
        if (decoded['meta'] is Map<String, dynamic>) {
          meta = AgendaPaginationMeta.fromJson(decoded['meta']);
        }

        // Cache hasil jika halaman 1 dan tanpa filter khusus
        if (page == 1 && (type == null || type == 'Semua')) {
          _cachedAgendas = items;
          _lastCacheTime = DateTime.now();
        }

        return AgendaListResponse(
          success: true,
          message: 'Berhasil memuat daftar agenda',
          items: items,
          meta: meta,
          statusCode: res.statusCode,
        );
      } else {
        final decoded = jsonDecode(res.body);
        return AgendaListResponse(
          success: false,
          message: decoded['message']?.toString() ?? 'Gagal memuat agenda (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getAgendas: $e');
      }
      return AgendaListResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }

  /// 6.3 Ambil Detail Agenda Berdasarkan ID
  /// GET /api/agendas/{id}
  static Future<AgendaDetailResponse> getAgendaDetail(int id) async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/agendas/$id');
      final headers = await _getHeaders();

      if (kDebugMode) {
        print('GET /api/agendas/$id request');
      }

      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('GET /api/agendas/$id response status: ${res.statusCode}');
      }

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return AgendaDetailResponse(
            success: true,
            message: 'Berhasil memuat detail agenda',
            agenda: AgendaItem.fromJson(data),
            statusCode: res.statusCode,
          );
        }
        return AgendaDetailResponse(
          success: false,
          message: 'Format data detail agenda tidak sesuai.',
          statusCode: res.statusCode,
        );
      } else if (res.statusCode == 404) {
        // Kontrak 6.3: 404 dikembalikan jika agenda tidak ada ATAU pengguna bukan bagian dari audiens.
        return AgendaDetailResponse(
          success: false,
          isNotFoundOrForbidden: true,
          message: 'Agenda sudah tidak tersedia atau Anda bukan bagian dari audiens agenda ini.',
          statusCode: res.statusCode,
        );
      } else {
        final decoded = jsonDecode(res.body);
        return AgendaDetailResponse(
          success: false,
          message: decoded['message']?.toString() ?? 'Gagal memuat detail agenda (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return AgendaDetailResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }
}
