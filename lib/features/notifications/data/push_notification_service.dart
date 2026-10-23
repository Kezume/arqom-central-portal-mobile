import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:share_plus/share_plus.dart';
import 'notifications_service.dart';
import '../presentation/notifications_screen.dart';
import '../../agenda/data/agenda_service.dart';
import '../../agenda/presentation/agenda_detail_screen.dart';
import '../../agenda/presentation/agenda_list_screen.dart';
import '../../requests/presentation/requests_screen.dart';
import '../../performance/presentation/performance_screen.dart';

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

  static const AndroidNotificationChannel downloadChannel = AndroidNotificationChannel(
    'portal_downloads_channel',
    'Unduhan Dokumen Portal',
    description: 'Notifikasi kemajuan dan penyelesaian unduhan dokumen SOP',
    importance: Importance.max, // Memunculkan Pop-up Heads-up Banner di atas layar
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
      final androidPlatform = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlatform?.createNotificationChannel(channel);
      await androidPlatform?.createNotificationChannel(downloadChannel);

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
        NotificationsService.refreshUnreadCount();
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

  /// Navigasi otomatis saat pop-up notifikasi diketuk (Menu 6.4 & 7.9)
  static void _handleMessageNavigation(RemoteMessage message) {
    final data = message.data;
    if (kDebugMode) print('Notifikasi diketuk dengan payload: $data');

    final context = navigatorKey?.currentContext;
    if (context == null) return;

    _routeFromPayloadData(context, data);
  }

  static void _handleNotificationPayload(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (kDebugMode) print('Local notification payload diketuk: $data');

      // Jika notifikasi unduhan dokumen SOP diketuk, bagikan / buka berkas
      if (data['type'] == 'sop_download' && data['filePath'] != null) {
        final filePath = data['filePath'].toString();
        final file = File(filePath);
        if (file.existsSync()) {
          Share.shareXFiles([XFile(filePath)], text: data['title'] ?? 'Dokumen Resmi');
        }
        return;
      }

      final context = navigatorKey?.currentContext;
      if (context != null) {
        _routeFromPayloadData(context, data);
      }
    } catch (_) {}
  }

  /// Helper untuk mengarahkan pengguna ke halaman yang tepat berdasarkan kontrak FCM
  static void _routeFromPayloadData(BuildContext context, Map<String, dynamic> data) {
    final type = data['type']?.toString();

    // 1. Notifikasi Agenda Perusahaan (Menu 6.4)
    if (type == 'agenda_reminder' ||
        type == 'agenda_updated' ||
        type == 'agenda_cancelled' ||
        data['entity_type'] == 'central_agenda' ||
        data['agenda_id'] != null) {
      final rawId = data['agenda_id'] ?? data['entity_id'];
      final agendaId = rawId != null ? int.tryParse(rawId.toString()) : null;

      if (type == 'agenda_cancelled') {
        AgendaService.clearCache();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AgendaListScreen()),
        );
      } else if (agendaId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AgendaDetailScreen(agendaId: agendaId)),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AgendaListScreen()),
        );
      }
      return;
    }

    // 2. Notifikasi Pengajuan Izin/Cuti/Lembur/Dinas (Menu 7.8)
    if (data['request_id'] != null ||
        type == 'request_approved' ||
        type == 'request_rejected' ||
        type == 'request_submitted') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RequestsScreen()),
      );
      return;
    }

    // 3. Notifikasi Pengingat Logbook Harian (Menu 6.4 & 7.9)
    if (type == 'performance_daily_reminder' ||
        data['action_url']?.toString().contains('daily') == true ||
        data['action_url']?.toString().contains('logbook') == true) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PerformanceScreen(initialTabIndex: 2)),
      );
      return;
    }

    // Default: Buka pusat notifikasi
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  /// Tampilkan pop-up notifikasi saat proses unduhan dimulai
  static Future<void> showDownloadProgressNotification({
    required int id,
    required String title,
    required String fileName,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        downloadChannel.id,
        downloadChannel.name,
        channelDescription: downloadChannel.description,
        importance: downloadChannel.importance,
        priority: Priority.high,
        showProgress: true,
        indeterminate: true,
        ongoing: true,
        autoCancel: false,
        icon: '@mipmap/launcher_icon',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: false,
        ),
      );

      await flutterLocalNotificationsPlugin.show(
        id,
        'Mengunduh Dokumen...',
        '$title ($fileName)',
        notificationDetails,
      );
    } catch (_) {}
  }

  /// Tampilkan pop-up notifikasi saat unduhan berhasil diselesaikan
  static Future<void> showDownloadCompletedNotification({
    required int id,
    required String title,
    required String fileName,
    String? filePath,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        downloadChannel.id,
        downloadChannel.name,
        channelDescription: downloadChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        showProgress: false,
        ongoing: false,
        autoCancel: true,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/launcher_icon',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: true,
        ),
      );

      final payload = jsonEncode({
        'type': 'sop_download',
        'title': title,
        'fileName': fileName,
        'filePath': filePath,
      });

      await flutterLocalNotificationsPlugin.show(
        id,
        'Unduhan Selesai',
        '$fileName berhasil disimpan ke perangkat.',
        notificationDetails,
        payload: payload,
      );
    } catch (_) {}
  }

  /// Tampilkan notifikasi jika proses unduhan gagal
  static Future<void> showDownloadFailedNotification({
    required int id,
    required String title,
    String? reason,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        downloadChannel.id,
        downloadChannel.name,
        channelDescription: downloadChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        showProgress: false,
        ongoing: false,
        autoCancel: true,
        icon: '@mipmap/launcher_icon',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      );

      await flutterLocalNotificationsPlugin.show(
        id,
        'Gagal Mengunduh Dokumen',
        reason ?? 'Terjadi kesalahan saat mengunduh $title.',
        notificationDetails,
      );
    } catch (_) {}
  }

  /// Batalkan notifikasi berdasarkan ID
  static Future<void> cancelNotification(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
    } catch (_) {}
  }
}
