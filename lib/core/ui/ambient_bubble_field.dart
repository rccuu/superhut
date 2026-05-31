import 'dart:math';

import 'package:flutter/material.dart';

import 'apple_glass.dart';

class AmbientBubbleField extends StatefulWidget {
  const AmbientBubbleField({
    super.key,
    required this.isActive,
    required this.color,
    required this.bubbles,
    this.duration = const Duration(seconds: 14),
    this.travelOverflow = 120,
    this.fillOpacity = 0.24,
    this.strokeOpacity = 0.36,
  });

  const AmbientBubbleField.hotWater({
    super.key,
    required this.isActive,
    this.color = Colors.blue,
  }) : bubbles = AmbientBubblePresets.hotWater,
       duration = const Duration(seconds: 14),
       travelOverflow = 120,
       fillOpacity = 0.26,
       strokeOpacity = 0.38;

  const AmbientBubbleField.drink({
    super.key,
    required this.isActive,
    required this.color,
  }) : bubbles = AmbientBubblePresets.drink,
       duration = const Duration(seconds: 12),
       travelOverflow = 140,
       fillOpacity = 0.22,
       strokeOpacity = 0.34;

  final bool isActive;
  final Color color;
  final List<AmbientBubbleSpec> bubbles;
  final Duration duration;
  final double travelOverflow;
  final double fillOpacity;
  final double strokeOpacity;

  @override
  State<AmbientBubbleField> createState() => _AmbientBubbleFieldState();
}

class _AmbientBubbleFieldState extends State<AmbientBubbleField>
    with TickerProviderStateMixin {
  AnimationController? _controller;

  bool _shouldReduceMotion = false;
  bool _tickerModeEnabled = true;
  bool _shouldAnimate = false;

  @visibleForTesting
  bool get debugHasController => _controller != null;

  AnimationController get _effectiveController {
    return _controller ??= AnimationController(
      vsync: this,
      duration: widget.duration,
    );
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
  void didUpdateWidget(AmbientBubbleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller?.duration = widget.duration;
    }
    _syncController();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _syncController() {
    final shouldAnimate =
        widget.isActive && !_shouldReduceMotion && _tickerModeEnabled;

    if (_shouldAnimate == shouldAnimate) {
      return;
    }

    _shouldAnimate = shouldAnimate;
    if (shouldAnimate) {
      _effectiveController.repeat();
    } else {
      _disposeController();
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    final controller = _shouldAnimate ? _effectiveController : null;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          isComplex: controller != null,
          willChange: controller != null,
          painter: _buildPainter(controller),
        ),
      ),
    );
  }

  AmbientBubblePainter _buildPainter(Animation<double>? animation) {
    return AmbientBubblePainter(
      animation: animation,
      progress: 0.62,
      color: widget.color,
      bubbles: widget.bubbles,
      travelOverflow: widget.travelOverflow,
      fillOpacity: widget.fillOpacity,
      strokeOpacity: widget.strokeOpacity,
    );
  }
}

abstract final class AmbientBubblePresets {
  static const hotWater = <AmbientBubbleSpec>[
    AmbientBubbleSpec(
      xFactor: 0.12,
      size: 10,
      speed: 0.44,
      drift: 18,
      phase: 0.02,
    ),
    AmbientBubbleSpec(
      xFactor: 0.23,
      size: 18,
      speed: 0.36,
      drift: -22,
      phase: 0.20,
    ),
    AmbientBubbleSpec(
      xFactor: 0.35,
      size: 12,
      speed: 0.50,
      drift: 12,
      phase: 0.38,
    ),
    AmbientBubbleSpec(
      xFactor: 0.47,
      size: 22,
      speed: 0.32,
      drift: -16,
      phase: 0.56,
    ),
    AmbientBubbleSpec(
      xFactor: 0.60,
      size: 14,
      speed: 0.48,
      drift: 20,
      phase: 0.72,
    ),
    AmbientBubbleSpec(
      xFactor: 0.74,
      size: 20,
      speed: 0.34,
      drift: -14,
      phase: 0.12,
    ),
    AmbientBubbleSpec(
      xFactor: 0.88,
      size: 11,
      speed: 0.54,
      drift: 16,
      phase: 0.84,
    ),
  ];

  static const drink = <AmbientBubbleSpec>[
    AmbientBubbleSpec(
      xFactor: 0.08,
      size: 24,
      speed: 0.54,
      drift: 18,
      phase: 0,
    ),
    AmbientBubbleSpec(
      xFactor: 0.18,
      size: 34,
      speed: 0.48,
      drift: -22,
      phase: 0.18,
    ),
    AmbientBubbleSpec(
      xFactor: 0.31,
      size: 18,
      speed: 0.62,
      drift: 12,
      phase: 0.36,
    ),
    AmbientBubbleSpec(
      xFactor: 0.44,
      size: 30,
      speed: 0.42,
      drift: -16,
      phase: 0.52,
    ),
    AmbientBubbleSpec(
      xFactor: 0.58,
      size: 22,
      speed: 0.58,
      drift: 20,
      phase: 0.70,
    ),
    AmbientBubbleSpec(
      xFactor: 0.72,
      size: 38,
      speed: 0.38,
      drift: -14,
      phase: 0.10,
    ),
    AmbientBubbleSpec(
      xFactor: 0.86,
      size: 26,
      speed: 0.50,
      drift: 16,
      phase: 0.82,
    ),
    AmbientBubbleSpec(
      xFactor: 0.95,
      size: 16,
      speed: 0.66,
      drift: -10,
      phase: 0.44,
    ),
  ];
}

class AmbientBubbleSpec {
  const AmbientBubbleSpec({
    required this.xFactor,
    required this.size,
    required this.speed,
    required this.drift,
    required this.phase,
  });

  final double xFactor;
  final double size;
  final double speed;
  final double drift;
  final double phase;
}

class AmbientBubblePainter extends CustomPainter {
  AmbientBubblePainter({
    required this.progress,
    required this.color,
    required this.bubbles,
    required this.travelOverflow,
    required this.fillOpacity,
    required this.strokeOpacity,
    this.animation,
  }) : super(repaint: animation);

  final double progress;
  final Color color;
  final List<AmbientBubbleSpec> bubbles;
  final double travelOverflow;
  final double fillOpacity;
  final double strokeOpacity;
  final Animation<double>? animation;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final travel = size.height + travelOverflow;
    final effectiveProgress = animation?.value ?? progress;

    for (final bubble in bubbles) {
      final cycle = (effectiveProgress * bubble.speed + bubble.phase) % 1.0;
      final fadeIn = (cycle / 0.16).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - cycle) / 0.30).clamp(0.0, 1.0);
      final opacity = fadeIn < fadeOut ? fadeIn : fadeOut;
      if (opacity <= 0.01) {
        continue;
      }

      final wave = sin((cycle + bubble.phase) * pi * 2);
      final center = Offset(
        size.width * bubble.xFactor + wave * bubble.drift,
        size.height + bubble.size - cycle * travel,
      );
      final radius = bubble.size / 2;

      fillPaint.color = color.withValues(alpha: opacity * fillOpacity);
      strokePaint.color = color.withValues(alpha: opacity * strokeOpacity);
      canvas.drawCircle(center, radius, fillPaint);
      canvas.drawCircle(center, radius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant AmbientBubblePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.bubbles != bubbles ||
        oldDelegate.travelOverflow != travelOverflow ||
        oldDelegate.fillOpacity != fillOpacity ||
        oldDelegate.strokeOpacity != strokeOpacity ||
        oldDelegate.animation != animation;
  }
}
