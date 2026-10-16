import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated ARTECH loading indicator based accurately on the original
/// ARTECH loading animation prototype in `logo/ARTECH_Animasi_Loading_Akurat.html`.
///
/// Features:
/// - Smooth looping animation cycle with adjustable cadence (default 2.2s for responsive in-app loading)
/// - Sweeping conic reveal of the orange/blue ring (`logo/artech_ring.png`)
/// - Sliding & scaling central symbol emblem (`logo/artech_symbol.png`)
/// - Sliding & scaling branded text (`logo/artech_text.png`)
/// - Dynamic orange ambient halo glow
/// - Finish pulse effect on the full logo (`logo/artech_full.png`)
/// - Full-featured presets: `.small()`, `.button()`, `.page()`, `.overlayCard()`, `.fullScreen()`, and `.showLoadingDialog()`
class ArtechLoadingWidget extends StatefulWidget {
  /// Dimension (width & height) of the loading logo stage.
  final double size;

  /// Optional message displayed below the animated logo.
  final String? message;

  /// Custom text style for the optional message.
  final TextStyle? messageStyle;

  /// Whether to render the ambient orange halo behind the logo.
  final bool showHalo;

  /// Whether to render the ARTECH text layer (can be false for tiny inline badges).
  final bool showText;

  /// Custom message color.
  final Color? messageColor;

  /// When true, renders with a fullscreen soft background.
  final bool isFullScreen;

  /// Custom background color when [isFullScreen] is true.
  final Color? backgroundColor;

  /// Whether the animation loops continuously. If false, plays once and stays fully revealed.
  final bool repeat;

  /// Total duration of one animation cycle. Defaults to 2.2 seconds for responsive in-app feedback.
  final Duration duration;

  /// Callback fired when the animation completes its reveal cycle (only when repeat is false).
  final VoidCallback? onCompleted;

  const ArtechLoadingWidget({
    super.key,
    this.size = 72.0,
    this.message,
    this.messageStyle,
    this.showHalo = true,
    this.showText = true,
    this.messageColor,
    this.isFullScreen = false,
    this.backgroundColor,
    this.repeat = true,
    this.duration = const Duration(milliseconds: 2200),
    this.onCompleted,
  });

  /// Compact preset for small inline badges or chips.
  const ArtechLoadingWidget.small({
    super.key,
    this.size = 24.0,
    this.message,
    this.messageStyle,
    this.showHalo = false,
    this.showText = false,
    this.messageColor,
  })  : isFullScreen = false,
        backgroundColor = null,
        repeat = true,
        duration = const Duration(milliseconds: 2200),
        onCompleted = null;

  /// Full screen loading screen with subtle radial backdrop.
  const ArtechLoadingWidget.fullScreen({
    super.key,
    this.size = 96.0,
    this.message = 'Memuat...',
    this.messageStyle,
    this.showHalo = true,
    this.showText = true,
    this.messageColor,
    this.backgroundColor,
  })  : isFullScreen = true,
        repeat = true,
        duration = const Duration(milliseconds: 2200),
        onCompleted = null;

  /// In-page tab or list loading state with clean vertical breathing room.
  static Widget page({
    String? message,
    double size = 68.0,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 48),
  }) {
    return Center(
      child: Padding(
        padding: padding,
        child: ArtechLoadingWidget(
          size: size,
          message: message,
          showHalo: true,
        ),
      ),
    );
  }

  /// Button loading badge with a crisp white circular badge background.
  /// Ensures that on dark or primary-colored buttons (e.g. #0037B0),
  /// the navy blue and orange parts of the ARTECH logo pop with 100% clarity.
  static Widget button({
    double size = 18.0,
    Color badgeColor = Colors.white,
  }) {
    final badgeDiameter = size + 10.0;
    return Center(
      child: Container(
        width: badgeDiameter,
        height: badgeDiameter,
        decoration: BoxDecoration(
          color: badgeColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: ArtechLoadingWidget.small(size: size),
        ),
      ),
    );
  }

  /// Interactive preview of the ARTECH logo matching drag/pull progress [0.0..1.0].
  /// The ring draws dynamically in sync with user's pull gesture.
  static Widget preview({
    required double progress,
    double size = 26.0,
    bool showHalo = true,
  }) {
    final clamped = progress.clamp(0.0, 1.0);
    final ringSweep = clamped;
    final ringOpacity = (clamped * 1.6).clamp(0.0, 1.0);
    final symbolProgress = ((clamped - 0.38) / 0.62).clamp(0.0, 1.0);
    final symbolOpacity = symbolProgress;
    final symbolScale = 0.82 + (0.18 * symbolProgress);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Subtle halo glow appearing near threshold
          if (showHalo && clamped >= 0.45)
            Opacity(
              opacity: ((clamped - 0.45) / 0.55 * 0.7).clamp(0.0, 0.7),
              child: Container(
                width: size * 0.95,
                height: size * 0.95,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x35FE961D),
                      Color(0x18FE961D),
                      Color(0x00FE961D),
                    ],
                    stops: [0.0, 0.45, 0.85],
                  ),
                ),
              ),
            ),

          // Dynamic conic ring reveal tied to pull gesture
          if (ringOpacity > 0.01)
            Opacity(
              opacity: ringOpacity,
              child: _buildMaskedRingStatic(ringSweep, size),
            ),

          // Symbol entering as pull reaches threshold
          if (symbolOpacity > 0.01)
            Transform.scale(
              scale: symbolScale,
              child: Opacity(
                opacity: symbolOpacity,
                child: Image.asset(
                  'logo/artech_symbol.png',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildMaskedRingStatic(double sweepProgress, double stageSize) {
    final ringImage = Image.asset(
      'logo/artech_ring.png',
      width: stageSize,
      height: stageSize,
      fit: BoxFit.contain,
    );

    if (sweepProgress >= 0.999) {
      return ringImage;
    }
    if (sweepProgress <= 0.001) {
      return const SizedBox.shrink();
    }

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        final sweep = sweepProgress.clamp(0.0, 1.0);
        return SweepGradient(
          transform: const GradientRotation(-152 * math.pi / 180),
          colors: const [
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
            Color(0x00000000),
          ],
          stops: [
            0.0,
            sweep,
            (sweep + 0.01).clamp(0.0, 1.0),
            1.0,
          ],
        ).createShader(bounds);
      },
      child: ringImage,
    );
  }

  /// Elegant floating overlay card for pull-to-refresh or background synchronization.
  /// Encloses the animated logo and status text in a frosted white rounded card.
  static Widget overlayCard({
    String message = 'Memperbarui data...',
    double size = 64.0,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFF1F5F9),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ArtechLoadingWidget(
              size: size,
              showHalo: true,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a modal dialog containing the ARTECH animated loading widget.
  static Future<void> showLoadingDialog(
    BuildContext context, {
    String message = 'Memproses...',
    bool barrierDismissible = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => PopScope(
        canPop: barrierDismissible,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ArtechLoadingWidget(
                  size: 72.0,
                  showHalo: true,
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Closes the active loading dialog if open.
  static void hideLoadingDialog(BuildContext context) {
    try {
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) {
        nav.pop();
      }
    } catch (_) {}
  }

  /// Center overlay widget that wraps any screen, modal or view.
  /// When [isLoading] is true, dims the background and centers the ArtechLoadingWidget
  /// right in the middle of the screen, preventing buttons from needing cramped spinners.
  static Widget overlay({
    required bool isLoading,
    required Widget child,
    String? message = 'Memproses...',
  }) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                color: Colors.black.withValues(alpha: 0.38),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ArtechLoadingWidget(
                        size: 72.0,
                        showHalo: true,
                      ),
                      if (message != null && message.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  State<ArtechLoadingWidget> createState() => _ArtechLoadingWidgetState();
}

class _ArtechLoadingWidgetState extends State<ArtechLoadingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Cubic curves matching the HTML/CSS specification
  static const Curve _ringDrawCurve = Cubic(0.45, 0.0, 0.2, 1.0);
  static const Curve _symbolInCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Curve _textInCurve = Curves.easeInOut;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    if (widget.repeat) {
      _controller.repeat();
    } else {
      _controller.forward().then((_) {
        if (mounted) {
          widget.onCompleted?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final stageSize = widget.size;

    Widget coreStage = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;

        // ── 1. HALO (Ambient Orange Glow) ──
        double haloOpacity = 0.0;
        double haloScale = 0.78;
        if (widget.showHalo) {
          if (t < 0.45) {
            haloOpacity = 0.0;
            haloScale = 0.78;
          } else if (t < 0.60) {
            final p = (t - 0.45) / 0.15;
            haloOpacity = _lerp(0.0, 0.55, p);
            haloScale = _lerp(0.78, 1.00, p);
          } else if (t < 0.72) {
            final p = (t - 0.60) / 0.12;
            haloOpacity = _lerp(0.55, 0.24, p);
            haloScale = _lerp(1.00, 0.93, p);
          } else if (t < 0.82) {
            final p = (t - 0.72) / 0.10;
            haloOpacity = _lerp(0.24, 0.52, p);
            haloScale = _lerp(0.93, 1.01, p);
          } else {
            if (!widget.repeat) {
              final p = (t - 0.82) / 0.18;
              haloOpacity = _lerp(0.52, 0.20, p);
              haloScale = 1.0;
            } else {
              final p = (t - 0.82) / 0.18;
              haloOpacity = _lerp(0.52, 0.0, p);
              haloScale = _lerp(1.01, 1.06, p);
            }
          }
        }

        // ── 2. RING REVEAL & DRAW ──
        double ringOpacity = 0.0;
        double ringSweep = 0.0; // 0.0 to 1.0 (0 to 360 deg)
        double ringScale = 0.985;
        if (t <= 0.06) {
          ringOpacity = 0.0;
          ringSweep = 0.0;
          ringScale = 0.985;
        } else if (t < 0.08) {
          final p = (t - 0.06) / 0.02;
          ringOpacity = _lerp(0.0, 1.0, p);
          ringSweep = 0.0;
          ringScale = _lerp(0.985, 0.990, p);
        } else if (t < 0.36) {
          final p = (t - 0.08) / 0.28;
          final curvedP = _ringDrawCurve.transform(p);
          ringOpacity = 1.0;
          ringSweep = curvedP;
          ringScale = _lerp(0.990, 1.0, curvedP);
        } else if (t <= 0.82) {
          ringOpacity = 1.0;
          ringSweep = 1.0;
          ringScale = 1.0;
        } else {
          if (!widget.repeat) {
            ringOpacity = 1.0;
          } else {
            final p = (t - 0.82) / 0.18;
            ringOpacity = _lerp(1.0, 0.0, p);
          }
          ringSweep = 1.0;
          ringScale = 1.0;
        }

        // ── 3. SYMBOL IN ──
        double symbolOpacity = 0.0;
        double symbolTranslateY = 22.0 * (stageSize / 420.0);
        double symbolScale = 0.92;
        if (t < 0.28) {
          symbolOpacity = 0.0;
        } else if (t < 0.42) {
          final p = (t - 0.28) / 0.14;
          final curvedP = _symbolInCurve.transform(p);
          symbolOpacity = _lerp(0.0, 1.0, curvedP);
          symbolTranslateY = _lerp(22.0, -2.0, curvedP) * (stageSize / 420.0);
          symbolScale = _lerp(0.92, 1.01, curvedP);
        } else if (t < 0.52) {
          final p = (t - 0.42) / 0.10;
          symbolOpacity = 1.0;
          symbolTranslateY = _lerp(-2.0, 0.0, p) * (stageSize / 420.0);
          symbolScale = _lerp(1.01, 1.0, p);
        } else if (t <= 0.82) {
          symbolOpacity = 1.0;
          symbolTranslateY = 0.0;
          symbolScale = 1.0;
        } else {
          if (!widget.repeat) {
            symbolOpacity = 1.0;
          } else {
            final p = (t - 0.82) / 0.18;
            symbolOpacity = _lerp(1.0, 0.0, p);
          }
          symbolTranslateY = 0.0;
          symbolScale = 1.0;
        }

        // ── 4. TEXT IN ──
        double textOpacity = 0.0;
        double textTranslateY = 16.0 * (stageSize / 420.0);
        double textScale = 0.98;
        if (widget.showText) {
          if (t < 0.44) {
            textOpacity = 0.0;
          } else if (t < 0.58) {
            final p = (t - 0.44) / 0.14;
            final curvedP = _textInCurve.transform(p);
            textOpacity = _lerp(0.0, 1.0, curvedP);
            textTranslateY = _lerp(16.0, -1.0, curvedP) * (stageSize / 420.0);
            textScale = _lerp(0.98, 1.005, curvedP);
          } else if (t < 0.66) {
            final p = (t - 0.58) / 0.08;
            textOpacity = 1.0;
            textTranslateY = _lerp(-1.0, 0.0, p) * (stageSize / 420.0);
            textScale = _lerp(1.005, 1.0, p);
          } else if (t <= 0.82) {
            textOpacity = 1.0;
            textTranslateY = 0.0;
            textScale = 1.0;
          } else {
            if (!widget.repeat) {
              textOpacity = 1.0;
            } else {
              final p = (t - 0.82) / 0.18;
              textOpacity = _lerp(1.0, 0.0, p);
            }
            textTranslateY = 0.0;
            textScale = 1.0;
          }
        }

        // ── 5. FINISH PULSE ──
        double pulseOpacity = 0.0;
        double pulseScale = 1.0;
        if (t < 0.58) {
          pulseOpacity = 0.0;
          pulseScale = 1.0;
        } else if (t < 0.68) {
          final p = (t - 0.58) / 0.10;
          pulseOpacity = _lerp(0.0, 0.14, p);
          pulseScale = _lerp(1.0, 1.016, p);
        } else if (t < 0.78) {
          final p = (t - 0.68) / 0.10;
          pulseOpacity = _lerp(0.14, 0.03, p);
          pulseScale = _lerp(1.016, 0.998, p);
        } else if (t < 0.84) {
          final p = (t - 0.78) / 0.06;
          pulseOpacity = _lerp(0.03, 0.12, p);
          pulseScale = _lerp(0.998, 1.012, p);
        } else {
          final p = (t - 0.84) / 0.16;
          if (!widget.repeat) {
            pulseOpacity = 0.0;
          } else {
            pulseOpacity = _lerp(0.12, 0.0, p);
          }
          pulseScale = _lerp(1.012, 1.0, p);
        }

        return SizedBox(
          width: stageSize,
          height: stageSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Layer 0: Halo Glow
              if (widget.showHalo && haloOpacity > 0.001)
                Transform.scale(
                  scale: haloScale,
                  child: Opacity(
                    opacity: haloOpacity.clamp(0.0, 1.0),
                    child: Container(
                      width: stageSize * 0.90,
                      height: stageSize * 0.90,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x35FE961D), // rgba(254,150,29, .21)
                            Color(0x18FE961D), // rgba(254,150,29, .09)
                            Color(0x00FE961D), // transparent
                          ],
                          stops: [0.0, 0.40, 0.78],
                        ),
                      ),
                    ),
                  ),
                ),

              // Layer 1: Conic Ring Reveal
              if (ringOpacity > 0.001)
                Transform.scale(
                  scale: ringScale,
                  child: Opacity(
                    opacity: ringOpacity.clamp(0.0, 1.0),
                    child: _buildMaskedRing(ringSweep, stageSize),
                  ),
                ),

              // Layer 2: Symbol In
              if (symbolOpacity > 0.001)
                Transform.translate(
                  offset: Offset(0, symbolTranslateY),
                  child: Transform.scale(
                    scale: symbolScale,
                    child: Opacity(
                      opacity: symbolOpacity.clamp(0.0, 1.0),
                      child: Image.asset(
                        'logo/artech_symbol.png',
                        width: stageSize,
                        height: stageSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

              // Layer 3: Text In
              if (widget.showText && textOpacity > 0.001)
                Transform.translate(
                  offset: Offset(0, textTranslateY),
                  child: Transform.scale(
                    scale: textScale,
                    child: Opacity(
                      opacity: textOpacity.clamp(0.0, 1.0),
                      child: Image.asset(
                        'logo/artech_text.png',
                        width: stageSize,
                        height: stageSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

              // Layer 4: Finish Pulse (Full Logo overlay)
              if (pulseOpacity > 0.001)
                Transform.scale(
                  scale: pulseScale,
                  child: Opacity(
                    opacity: pulseOpacity.clamp(0.0, 1.0),
                    child: Image.asset(
                      'logo/artech_full.png',
                      width: stageSize,
                      height: stageSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    // If message is provided, arrange in column
    Widget content = coreStage;
    if (widget.message != null && widget.message!.isNotEmpty) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          coreStage,
          const SizedBox(height: 12),
          Text(
            widget.message!,
            textAlign: TextAlign.center,
            style: widget.messageStyle ??
                TextStyle(
                  fontSize: (stageSize * 0.17).clamp(11.0, 13.5),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.25,
                  color: widget.messageColor ?? const Color(0xFF64748B),
                ),
          ),
        ],
      );
    }

    if (widget.isFullScreen) {
      return Container(
        color: widget.backgroundColor ?? const Color(0xFFFAFBFE),
        alignment: Alignment.center,
        child: content,
      );
    }

    return content;
  }

  /// Builds the ring layer with sweep mask corresponding to the CSS:
  /// `-webkit-mask-image: conic-gradient(from -152deg, #000 0deg, #000 var(--sweep), transparent calc(var(--sweep) + 0.8deg), transparent 360deg)`
  Widget _buildMaskedRing(double sweepProgress, double stageSize) {
    final ringImage = Image.asset(
      'logo/artech_ring.png',
      width: stageSize,
      height: stageSize,
      fit: BoxFit.contain,
    );

    // When fully drawn (sweep >= 0.999), avoid shader mask overhead
    if (sweepProgress >= 0.999) {
      return ringImage;
    }
    if (sweepProgress <= 0.001) {
      return const SizedBox.shrink();
    }

    // Mask with conic sweep gradient starting from -152 degrees
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        final sweep = sweepProgress.clamp(0.0, 1.0);
        return SweepGradient(
          transform: const GradientRotation(-152 * math.pi / 180),
          colors: const [
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
            Color(0x00000000),
          ],
          stops: [
            0.0,
            sweep,
            (sweep + 0.008).clamp(0.0, 1.0),
            1.0,
          ],
        ).createShader(bounds);
      },
      child: ringImage,
    );
  }
}
