import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'artech_loading_widget.dart';

/// Interactive Pull-To-Refresh widget featuring the ARTECH loading preview.
///
/// As the user pulls down:
/// - The ARTECH ring sweeps around in direct sync with the pull distance.
/// - At ~40% pull, the central emblem symbol fades and scales into place.
/// - At 100% (threshold reached), the floating capsule highlights and indicates
///   "Lepas untuk memuat" with subtle tactile feedback.
/// - On release, the capsule stays pinned at the top while playing the live
///   ARTECH loading animation and running [onRefresh].
/// - Once finished, shows a brief success check before smoothly sliding away.
class ArtechPullToRefresh extends StatefulWidget {
  /// The async refresh callback to execute when pulled past threshold.
  final Future<void> Function() onRefresh;

  /// The scrollable child widget (e.g. [SingleChildScrollView], [ListView]).
  final Widget child;

  /// Pull distance in logical pixels required to trigger refresh. Defaults to 78.0.
  final double threshold;

  /// Offset from top safe-area where the pill rests while refreshing.
  final double topDisplacement;

  /// Custom hint text while dragging before threshold.
  final String pullText;

  /// Custom hint text when threshold reached.
  final String releaseText;

  /// Custom text while refresh callback is executing.
  final String refreshingText;

  /// Custom text when refresh successfully completed.
  final String completedText;

  const ArtechPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.threshold = 78.0,
    this.topDisplacement = 14.0,
    this.pullText = 'Tarik untuk memuat',
    this.releaseText = 'Lepas untuk memuat',
    this.refreshingText = 'Memperbarui data...',
    this.completedText = 'Data terbaru siap',
  });

  @override
  State<ArtechPullToRefresh> createState() => _ArtechPullToRefreshState();
}

class _ArtechPullToRefreshState extends State<ArtechPullToRefresh>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isRefreshing = false;
  bool _isSuccess = false;
  bool _isArmed = false;
  bool _isUserTouching = false;
  bool _hasHapticsFired = false;
  bool _hasPendingFrameUpdate = false;
  bool _checkTriggerAfterFrame = false;
  bool _dismissAfterFrame = false;
  double? _dragOffsetAfterFrame;

  late final AnimationController _dismissController;
  Animation<double>? _dismissAnimation;

  @override
  void initState() {
    super.initState();
    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
      if (_dismissAnimation != null) {
        setState(() {
          _dragOffset = _dismissAnimation!.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissController.dispose();
    super.dispose();
  }

  void _updateDrag(double newOffset) {
    if (_isRefreshing || _isSuccess || _dismissController.isAnimating) return;

    final clampedOffset = newOffset.clamp(0.0, widget.threshold * 2.4);
    final wasArmed = _isArmed;
    final nowArmed = clampedOffset >= widget.threshold;

    if (nowArmed && !wasArmed && !_hasHapticsFired) {
      // Light tactile click when arming
      HapticFeedback.lightImpact();
      _hasHapticsFired = true;
    } else if (!nowArmed && wasArmed) {
      _hasHapticsFired = false;
    }

    setState(() {
      _dragOffset = clampedOffset;
      _isArmed = nowArmed;
    });
  }

  void _checkTrigger() {
    if (_isRefreshing || _isSuccess) return;

    if (_dragOffset >= widget.threshold) {
      _startRefresh();
    } else if (_dragOffset > 0.0) {
      _animateDismiss();
    }
  }

  void _queueFrameUpdate({
    double? dragOffset,
    double? dragDelta,
    bool checkTrigger = false,
    bool dismiss = false,
  }) {
    if (dragOffset != null) {
      _dragOffsetAfterFrame = dragOffset;
    } else if (dragDelta != null) {
      _dragOffsetAfterFrame =
          (_dragOffsetAfterFrame ?? _dragOffset) + dragDelta;
    }
    _checkTriggerAfterFrame = _checkTriggerAfterFrame || checkTrigger;
    _dismissAfterFrame = _dismissAfterFrame || dismiss;

    if (_hasPendingFrameUpdate) return;
    _hasPendingFrameUpdate = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hasPendingFrameUpdate = false;
      if (!mounted) return;

      final pendingDragOffset = _dragOffsetAfterFrame;
      final shouldDismiss = _dismissAfterFrame;
      final shouldCheckTrigger = _checkTriggerAfterFrame;
      _dragOffsetAfterFrame = null;
      _dismissAfterFrame = false;
      _checkTriggerAfterFrame = false;

      if (pendingDragOffset != null) {
        _updateDrag(pendingDragOffset);
      }
      if (shouldDismiss && _dragOffset > 0.0) {
        _animateDismiss();
      } else if (shouldCheckTrigger) {
        _checkTrigger();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _startRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _isArmed = false;
      _dragOffset = widget.threshold;
    });

    try {
      await widget.onRefresh();
      if (!mounted) return;

      setState(() {
        _isSuccess = true;
      });

      // Brief moment to show success state
      await Future.delayed(const Duration(milliseconds: 480));
    } catch (_) {
      // Refresh error silently ignored or handled by parent
    } finally {
      if (mounted) {
        _animateDismiss(
          onComplete: () {
            if (mounted) {
              setState(() {
                _isRefreshing = false;
                _isSuccess = false;
                _isArmed = false;
                _hasHapticsFired = false;
                _dragOffset = 0.0;
              });
            }
          },
        );
      }
    }
  }

  void _animateDismiss({VoidCallback? onComplete}) {
    _dismissAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _dismissController, curve: Curves.easeOutCubic),
    );

    _dismissController.forward(from: 0.0).then((_) {
      _hasHapticsFired = false;
      _isArmed = false;
      if (onComplete != null) {
        onComplete();
      } else if (mounted) {
        setState(() {
          _dragOffset = 0.0;
        });
      }
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // Only respond to the top-level scrollable
    if (notification.depth != 0) return false;
    if (_isRefreshing || _isSuccess) return false;

    if (notification is ScrollStartNotification) {
      if (_dismissController.isAnimating) {
        _dismissController.stop();
      }
    } else if (notification is ScrollUpdateNotification) {
      // If user has scrolled down into page content, cancel drag
      if (notification.metrics.extentBefore > 0.0) {
        if (_dragOffset > 0.0) {
          _queueFrameUpdate(dismiss: true);
        }
        return false;
      }

      // Negative pixels on BouncingScrollPhysics represents overscroll at top
      if (notification.metrics.pixels < 0.0) {
        _queueFrameUpdate(dragOffset: -notification.metrics.pixels);
      } else if (_dragOffset > 0.0 && notification.scrollDelta != null) {
        _queueFrameUpdate(dragDelta: -notification.scrollDelta!);
      }

      // Check if user released finger during ballistic scroll
      if (notification.dragDetails == null && _isUserTouching) {
        _isUserTouching = false;
        _queueFrameUpdate(checkTrigger: true);
      }
    } else if (notification is OverscrollNotification) {
      // ClampingScrollPhysics on Android emits negative overscroll
      if (notification.metrics.extentBefore == 0.0 &&
          notification.overscroll < 0.0) {
        final delta = -notification.overscroll / 1.6;
        _queueFrameUpdate(dragDelta: delta);
      }
    } else if (notification is ScrollEndNotification) {
      _isUserTouching = false;
      _queueFrameUpdate(checkTrigger: true);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final progress =
        (widget.threshold > 0)
            ? (_dragOffset / widget.threshold).clamp(0.0, 1.0)
            : 0.0;

    // Resting position when pinned (e.g. 14px below top padding)
    final restingTop = topPadding + widget.topDisplacement;
    // Hidden top starting position (just above the resting position)
    final initialTop = (restingTop - 44.0).clamp(0.0, double.infinity);

    double pillTop;
    double pillOpacity;
    double pillScale;

    if (_isRefreshing || _isSuccess) {
      pillTop = restingTop;
      pillOpacity = 1.0;
      pillScale = 1.0;
    } else if (_dragOffset > 0.0) {
      // As user pulls down, smoothly slide from initialTop down to restingTop
      pillTop = initialTop + (progress * (restingTop - initialTop));
      if (_dragOffset > widget.threshold) {
        // Elastic rubber-band extension
        pillTop += (_dragOffset - widget.threshold) * 0.22;
      }
      pillOpacity = (progress * 1.6).clamp(0.0, 1.0);
      pillScale = (0.76 + (0.24 * progress)).clamp(0.76, 1.05);
    } else {
      pillTop = initialTop;
      pillOpacity = 0.0;
      pillScale = 0.76;
    }

    return Stack(
      children: [
        // Scrollable child with pointer event listener and notification listener
        Listener(
          onPointerDown: (_) {
            _isUserTouching = true;
            if (_dismissController.isAnimating) {
              _dismissController.stop();
            }
          },
          onPointerUp: (_) {
            _isUserTouching = false;
            _queueFrameUpdate(checkTrigger: true);
          },
          onPointerCancel: (_) {
            _isUserTouching = false;
            _queueFrameUpdate(checkTrigger: true);
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: widget.child,
          ),
        ),

        // Floating ARTECH preview pill
        if (pillOpacity > 0.01)
          Positioned(
            top: pillTop,
            left: 0,
            right: 0,
            child: Center(
              child: Opacity(
                opacity: pillOpacity,
                child: Transform.scale(
                  scale: pillScale,
                  child: _buildFloatingPill(progress),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFloatingPill(double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color:
              _isSuccess
                  ? const Color(0xFF10B981).withValues(alpha: 0.5)
                  : _isArmed
                  ? const Color(0xFFFE961D).withValues(alpha: 0.55)
                  : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                _isSuccess
                    ? const Color(0x3310B981)
                    : _isArmed
                    ? const Color(0x40FE961D)
                    : Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dynamic ARTECH Indicator
          SizedBox(
            width: 26,
            height: 26,
            child: Center(child: _buildIndicator(progress)),
          ),
          const SizedBox(width: 9),
          // Dynamic Status Text
          Text(
            _getStatusText(),
            style: TextStyle(
              fontSize: 12.0,
              fontWeight:
                  (_isArmed || _isRefreshing || _isSuccess)
                      ? FontWeight.w700
                      : FontWeight.w600,
              color: _getTextColor(),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(double progress) {
    if (_isSuccess) {
      return const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF10B981),
        size: 22,
      );
    }

    if (_isRefreshing) {
      return const ArtechLoadingWidget(
        size: 26,
        showHalo: true,
        showText: false,
      );
    }

    // Realtime dragging preview: conic ring sweep + emblem scale-in
    return ArtechLoadingWidget.preview(
      progress: progress,
      size: 26,
      showHalo: true,
    );
  }

  String _getStatusText() {
    if (_isSuccess) return widget.completedText;
    if (_isRefreshing) return widget.refreshingText;
    if (_isArmed) return widget.releaseText;
    return widget.pullText;
  }

  Color _getTextColor() {
    if (_isSuccess) return const Color(0xFF059669);
    if (_isRefreshing) return const Color(0xFF0037B0);
    if (_isArmed) return const Color(0xFFE87700);
    return const Color(0xFF64748B);
  }
}
