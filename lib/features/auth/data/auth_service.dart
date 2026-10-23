import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../notifications/data/push_notification_service.dart';
import '../../agenda/data/agenda_service.dart';

class AuthService {
  static const String baseUrl = 'https://arqomtechnology.cloud/api';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user_data';

  static Future<void> saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    AgendaService.clearCache();
  }

  static Future<Map<String, dynamic>> login(
    String identifier,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'identifier': identifier, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (data['data'] != null) {
          if (data['data']['token'] != null) {
            await saveToken(data['data']['token']);
          }
          if (data['data']['user'] != null) {
            await saveUserData(data['data']['user']);
          }
        }
        PushNotificationService.syncDeviceToken();
        return {
          'success': true,
          'message': data['message'] ?? 'Login berhasil',
        };
      } else {
        String errorMessage =
            data['message'] ?? 'Username atau kata sandi salah.';
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal terhubung ke server. Periksa koneksi internet Anda.',
      };
    }
  }

  static Future<bool> checkProfile() async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http
          .get(
            Uri.parse('$baseUrl/me'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          await saveUserData(data['data']);
        }
        return true;
      } else {
        await clearToken();
        return false;
      }
    } catch (e) {
      // Offline mode: Jika koneksi gagal tapi token ada, asumsikan masih login
      final token = await getToken();
      return token != null;
    }
  }

  static Future<bool> logout() async {
    try {
      await PushNotificationService.unregisterOnLogout();
      final token = await getToken();
      if (token != null) {
        await http
            .post(
              Uri.parse('$baseUrl/logout'),
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(const Duration(seconds: 5));
      }
      await clearToken();
      return true;
    } catch (e) {
      await clearToken();
      return true;
    }
  }
}
