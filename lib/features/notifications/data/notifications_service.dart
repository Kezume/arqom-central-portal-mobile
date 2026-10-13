import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/data/auth_service.dart';
import 'models/notification_models.dart';

class NotificationsApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? unreadCount;
  final int? statusCode;

  NotificationsApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.unreadCount,
    this.statusCode,
  });
}

class NotificationsService {
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

  /// 6.1 Daftarkan Device Token Perangkat (FCM Token)
  /// POST /api/notifications/register-device
  static Future<NotificationsApiResponse<Map<String, dynamic>>> registerDevice({
    required String deviceToken,
    String deviceType = 'android',
    String? deviceName,
  }) async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/notifications/register-device');
      final headers = await _getHeaders();
      final body = jsonEncode({
        'device_token': deviceToken,
        'device_type': deviceType,
        if (deviceName != null && deviceName.isNotEmpty) 'device_name': deviceName,
      });

      final res = await http.post(uri, headers: headers, body: body);
      final decoded = jsonDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        return NotificationsApiResponse(
          success: true,
          message: decoded['message']?.toString() ?? 'Perangkat berhasil didaftarkan.',
          data: decoded['data'] is Map<String, dynamic> ? decoded['data'] : null,
          statusCode: res.statusCode,
        );
      } else {
        return NotificationsApiResponse(
          success: false,
          message: decoded['message']?.toString() ?? 'Gagal mendaftarkan perangkat (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return NotificationsApiResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }

  /// 6.2 Hapus / Nonaktifkan Device Token (Saat Logout)
  /// POST /api/notifications/unregister-device
  static Future<NotificationsApiResponse<void>> unregisterDevice({
    required String deviceToken,
  }) async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/notifications/unregister-device');
      final headers = await _getHeaders();
      final body = jsonEncode({
        'device_token': deviceToken,
      });

      final res = await http.post(uri, headers: headers, body: body);
      final decoded = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return NotificationsApiResponse(
          success: true,
          message: decoded['message']?.toString() ?? 'Perangkat berhasil dinonaktifkan.',
          statusCode: res.statusCode,
        );
      } else {
        return NotificationsApiResponse(
          success: false,
          message: decoded['message']?.toString() ?? 'Gagal menonaktifkan perangkat (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return NotificationsApiResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }

  /// 6.3 Ambil Daftar Notifikasi In-App
  /// GET /api/notifications?unread_only=...&limit=...
  static Future<NotificationsApiResponse<List<NotificationItem>>> getNotifications({
    bool? unreadOnly,
    int limit = 30,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (unreadOnly != null) {
        queryParams['unread_only'] = unreadOnly.toString();
      }

      final uri = Uri.parse('${AuthService.baseUrl}/notifications').replace(queryParameters: queryParams);
      final headers = await _getHeaders();
      final res = await http.get(uri, headers: headers);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final rawList = decoded['data'] as List<dynamic>? ?? [];
        final items = rawList
            .whereType<Map<String, dynamic>>()
            .map((e) => NotificationItem.fromJson(e))
            .toList();

        final unreadCount = decoded['unread_count'] is int
            ? decoded['unread_count'] as int
            : int.tryParse(decoded['unread_count']?.toString() ?? '') ?? 0;

        return NotificationsApiResponse(
          success: true,
          message: 'Berhasil memuat notifikasi',
          data: items,
          unreadCount: unreadCount,
          statusCode: res.statusCode,
        );
      } else {
        final decoded = jsonDecode(res.body);
        return NotificationsApiResponse(
          success: false,
          message: decoded['message']?.toString() ?? 'Gagal memuat notifikasi (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return NotificationsApiResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }

  /// 6.4 Jumlah Notifikasi Belum Dibaca (Badge Counter)
  /// GET /api/notifications/unread-count
  static Future<int> getUnreadCount() async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/notifications/unread-count');
      final headers = await _getHeaders();
      final res = await http.get(uri, headers: headers);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['unread_count'] is int) {
          return decoded['unread_count'] as int;
        }
        return int.tryParse(decoded['unread_count']?.toString() ?? '0') ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// 6.5 Tandai Satu Notifikasi Sudah Dibaca
  /// PATCH /api/notifications/{id}/read (fallback POST)
  static Future<bool> markAsRead(String id) async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/notifications/$id/read');
      final headers = await _getHeaders();

      // Try PATCH first
      var res = await http.patch(uri, headers: headers);
      if (res.statusCode != 200) {
        // Fallback POST
        res = await http.post(uri, headers: headers);
      }
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 6.6 Tandai Seluruh Notifikasi Sudah Dibaca
  /// POST /api/notifications/mark-all-read
  static Future<bool> markAllAsRead() async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/notifications/mark-all-read');
      final headers = await _getHeaders();
      final res = await http.post(uri, headers: headers);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 6.7 Uji Coba Push Notification ke Bilah HP (Test Push)
  /// POST /api/notifications/test-push
  static Future<NotificationsApiResponse<Map<String, dynamic>>> testPush({
    String? title,
    String? body,
  }) async {
    try {
      final uri = Uri.parse('${AuthService.baseUrl}/notifications/test-push');
      final headers = await _getHeaders();
      final payload = jsonEncode({
        if (title != null && title.isNotEmpty) 'title': title,
        if (body != null && body.isNotEmpty) 'body': body,
      });

      final res = await http.post(uri, headers: headers, body: payload);
      final decoded = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return NotificationsApiResponse(
          success: true,
          message: decoded['message']?.toString() ?? 'Test notifikasi berhasil dikirim.',
          data: decoded['data'] is Map<String, dynamic> ? decoded['data'] : null,
          statusCode: res.statusCode,
        );
      } else {
        return NotificationsApiResponse(
          success: false,
          message: decoded['message']?.toString() ?? 'Gagal mengirim test notifikasi (${res.statusCode}).',
          statusCode: res.statusCode,
        );
      }
    } catch (e) {
      return NotificationsApiResponse(
        success: false,
        message: 'Koneksi gagal: $e',
      );
    }
  }
}
