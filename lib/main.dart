import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'features/splash/presentation/splash_screen.dart';
import 'features/notifications/data/push_notification_service.dart';

import 'features/performance/presentation/performance_screen.dart';
import 'features/agenda/presentation/agenda_list_screen.dart';
import 'features/agenda/presentation/agenda_detail_screen.dart';
import 'features/requests/presentation/requests_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set status bar to transparent
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Inisialisasi format tanggal lokal Indonesia
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi Push Notifications & Channel Pop-Up
  await PushNotificationService.initialize(navKey: navigatorKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Central Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/daily-logbook': (context) => const PerformanceScreen(initialTabIndex: 2),
        '/agendas': (context) => const AgendaListScreen(),
        '/requests': (context) => const RequestsScreen(),
        '/performance': (context) => const PerformanceScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/agenda-detail') {
          final args = settings.arguments;
          if (args is int) {
            return MaterialPageRoute(
              builder: (_) => AgendaDetailScreen(agendaId: args),
            );
          }
        }
        return null;
      },
    );
  }
}
