import 'package:flutter/material.dart';

import 'apple_glass.dart';

class AppScannerLine extends StatefulWidget {
  const AppScannerLine({super.key, required this.color});

  final Color color;

  @override
  State<AppScannerLine> createState() => _AppScannerLineState();
}

class _AppScannerLineState extends State<AppScannerLine>
    with TickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _animation;
  bool _shouldReduceMotion = false;
  bool _tickerModeEnabled = true;
  bool _shouldAnimate = false;

  @visibleForTesting
  bool get debugHasController => _controller != null;

  Animation<double> get _effectiveAnimation {
    if (_animation != null) {
      return _animation!;
    }

    final controller =
        _controller ??= AnimationController(
          duration: const Duration(seconds: 2),
          vsync: this,
        );
    return _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shouldReduceMotion = AppGlassPerformanceScope.shouldReduceMotionOf(
      context,
    );
    _tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    _syncController();
  }

  @override
  void didUpdateWidget(covariant AppScannerLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _syncController() {
    final shouldAnimate = !_shouldReduceMotion && _tickerModeEnabled;
    if (_shouldAnimate == shouldAnimate) {
      return;
    }

    _shouldAnimate = shouldAnimate;
    if (shouldAnimate) {
      _effectiveAnimation;
      _controller?.repeat();
    } else {
      _disposeController();
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _animation = null;
  }

  @override
  Widget build(BuildContext context) {
    final animation = _shouldAnimate ? _effectiveAnimation : null;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        isComplex: animation != null,
        willChange: animation != null,
        painter: AppScannerLinePainter(
          animation: animation,
          progress: 0.5,
          color: widget.color,
        ),
      ),
    );
  }
}

class AppScannerLinePainter extends CustomPainter {
  AppScannerLinePainter({
    required this.progress,
    required this.color,
    this.animation,
    this.height = 3,
  }) : super(repaint: animation);

  final double progress;
  final Color color;
  final Animation<double>? animation;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final paint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              color.withValues(alpha: 0.78),
              color,
              color.withValues(alpha: 0.78),
              Colors.transparent,
            ],
            stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, size.width, height + 1));

    final effectiveProgress = animation?.value ?? progress;
    final y = size.height * effectiveProgress;
    canvas.drawRect(Rect.fromLTWH(0, y, size.width, height), paint);
  }

  @override
  bool shouldRepaint(covariant AppScannerLinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.animation != animation ||
        oldDelegate.height != height;
  }
}
