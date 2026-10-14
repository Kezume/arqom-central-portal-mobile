import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notifications_service.dart';
import '../presentation/notifications_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) print('Firebase background init error: $e');
  }
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  static GlobalKey<NavigatorState>? navigatorKey;

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'portal_requests_channel', // Harus sama persis dengan backend
    'Persetujuan Pengajuan Portal',
    description: 'Notifikasi status persetujuan cuti, izin, lembur, dan dinas',
    importance: Importance.max, // PENTING: max memunculkan Pop-up Heads-up Banner di atas layar
    playSound: true,
    enableVibration: true,
  );

  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static String? _fcmToken;
  static String? get fcmToken => _fcmToken;

  /// Inisialisasi Firebase & Local Notifications
  static Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_initialized) return;
    if (navKey != null) navigatorKey = navKey;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Konfigurasi Flutter Local Notifications untuk Android Heads-Up Banner
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationPayload(response.payload);
        },
      );

      // Daftarkan channel prioritas MAX di Android Oreo 8.0+
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Minta izin notifikasi (Android 13+ & iOS)
      final NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (kDebugMode) {
        print('Status izin notifikasi: ${settings.authorizationStatus}');
      }

      // Ambil dan daftarkan token perangkat ke backend
      await syncDeviceToken();

      // Listener token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _registerTokenToBackend(newToken);
      });

      // 1. Tangani notifikasi saat aplikasi di Foreground (Tampilkan banner mengambang)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });

      // 2. Tangani saat pop-up diketuk ketika aplikasi di Background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessageNavigation(message);
      });

      // 3. Tangani saat aplikasi dibuka dari keadaan Terminated (Mati)
      final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageNavigation(initialMessage);
      }

      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('Error inisialisasi push notification: $e');
      }
    }
  }

  /// Sinkronisasi token FCM ke backend server
  static Future<void> syncDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        _fcmToken = token;
        if (kDebugMode) print('FCM Token didapatkan: $token');
        await _registerTokenToBackend(token);
      }
    } catch (e) {
      if (kDebugMode) print('Gagal mengambil FCM token: $e');
    }
  }

  /// Kirim token ke endpoint 6.1 POST /api/notifications/register-device
  static Future<void> _registerTokenToBackend(String token) async {
    try {
      final deviceType = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'android');
      await NotificationsService.registerDevice(
        deviceToken: token,
        deviceType: deviceType,
        deviceName: Platform.operatingSystem,
      );
    } catch (_) {}
  }

  /// Hapus token saat logout (6.2 POST /api/notifications/unregister-device)
  static Future<void> unregisterOnLogout() async {
    if (_fcmToken != null) {
      try {
        await NotificationsService.unregisterDevice(deviceToken: _fcmToken!);
      } catch (_) {}
    }
  }

  /// Tampilkan Heads-Up Banner saat aplikasi sedang dibuka (Foreground)
  static void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: channel.importance,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            icon: android?.smallIcon ?? '@mipmap/launcher_icon',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Navigasi otomatis saat pop-up notifikasi diketuk
  static void _handleMessageNavigation(RemoteMessage message) {
    final data = message.data;
    if (kDebugMode) print('Notifikasi diketuk dengan payload: $data');

    final context = navigatorKey?.currentContext;
    if (context != null) {
      // Langsung arahkan ke halaman pusat notifikasi
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
    }
  }

  static void _handleNotificationPayload(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (kDebugMode) print('Local notification payload diketuk: $data');
      final context = navigatorKey?.currentContext;
      if (context != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
      }
    } catch (_) {}
  }
}
