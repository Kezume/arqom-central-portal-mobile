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
  Timer? _taglineTimer;
  bool _isNavigating = false;
  bool _showTagline = false;
  bool _assetsPrecached = false;

  @override
  void initState() {
    super.initState();
    // Run authentication check in background concurrently with entrance animation
    _authCheckFuture = AuthService.checkProfile();

    // Fade in brand tagline smoothly once the ring & symbol start appearing (~1.2s into entrance)
    _taglineTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showTagline = true;
        });
      }
    });

    // Safety fallback timer so app never gets stuck under unforeseen edge-cases
    _safetyTimer = Timer(const Duration(milliseconds: 5000), () {
      _handleAnimationCompleted();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_assetsPrecached) {
      _assetsPrecached = true;
      // Precache all 4 ARTECH asset layers so animation frames render instantly without decode stutter
      precacheImage(const AssetImage('logo/artech_ring.png'), context);
      precacheImage(const AssetImage('logo/artech_symbol.png'), context);
      precacheImage(const AssetImage('logo/artech_text.png'), context);
      precacheImage(const AssetImage('logo/artech_full.png'), context);
    }
  }

  @override
  void dispose() {
    _taglineTimer?.cancel();
    _safetyTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleAnimationCompleted() async {
    if (_isNavigating) return;
    _isNavigating = true;
    _safetyTimer?.cancel();

    // Let the user see and admire the complete, fully-revealed logo before transitioning
    // Satisfies: "animasinya memunculkan keseluruhan terlebih dahulu baru masuk aplikasi"
    await Future.delayed(const Duration(milliseconds: 750));

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
        transitionDuration: const Duration(milliseconds: 650),
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
    // Generous stage size matching min(84vw, 420px) proportion from the HTML prototype
    final logoSize = (screenWidth * 0.74).clamp(240.0, 340.0);

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

              // Animated ARTECH Logo Centerpiece (Sweep conic ring, symbol in, text in, halo glow, finish pulse)
              Center(
                child: ArtechLoadingWidget(
                  size: logoSize,
                  showHalo: true,
                  showText: true,
                  repeat: false,
                  duration: const Duration(milliseconds: 2800),
                  onCompleted: _handleAnimationCompleted,
                ),
              ),

              const SizedBox(height: 20),

              // Subdued Brand Subtitle & Tagline
              AnimatedOpacity(
                opacity: _showTagline ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CENTRAL PORTAL',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'One platform for Arqom services',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.8,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 4),

              // Subtle footer version
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'v1.0.0 • Arqom Portal',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
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
