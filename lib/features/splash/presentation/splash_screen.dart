import 'dart:async';
import 'package:flutter/material.dart';
import '../../auth/presentation/login_screen.dart';
import '../../auth/data/auth_service.dart';
import '../../navigation/presentation/main_scaffold.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/artech_loading_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Future<bool> _authCheckFuture;
  Timer? _safetyTimer;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // Run auth check in background while entrance animation plays
    _authCheckFuture = AuthService.checkProfile();

    // Safety fallback timer so app never gets stuck under unforeseen edge-cases
    _safetyTimer = Timer(const Duration(milliseconds: 4500), () {
      _handleAnimationCompleted();
    });
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleAnimationCompleted() async {
    if (_isNavigating) return;
    _isNavigating = true;
    _safetyTimer?.cancel();

    // Give a clear moment for the user to see the entire revealed logo before navigating
    await Future.delayed(const Duration(milliseconds: 650));

    bool isValid = false;
    try {
      isValid = await _authCheckFuture.timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
    } catch (_) {
      isValid = false;
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder:
            (_, __, ___) =>
                isValid ? const MainScaffold() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = (screenWidth * 0.44).clamp(140.0, 180.0);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.95,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFCFCFD),
              Color(0xFFF3F5FA),
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Animated ARTECH Logo (Reveals ring, symbol, text completely first)
              ArtechLoadingWidget(
                size: logoSize,
                showHalo: true,
                repeat: false,
                duration: const Duration(milliseconds: 3000),
                onCompleted: _handleAnimationCompleted,
              ),

              const SizedBox(height: 28),

              // Application Name & Subtitle
              Text(
                'CENTRAL PORTAL',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'One platform for Arqom services',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(flex: 4),

              // Footer branding
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'v1.0.0 • Arqom Portal',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
