import 'package:flutter/material.dart';

import 'apple_glass.dart';

class AppLinearProgressIndicator extends StatelessWidget {
  const AppLinearProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.backgroundColor,
    this.minHeight = 4,
    this.staticIndeterminateValue = 0.42,
  });

  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final double minHeight;
  final double staticIndeterminateValue;

  @override
  Widget build(BuildContext context) {
    final effectiveValue =
        value ??
        (AppGlassPerformanceScope.shouldReduceMotionOf(context)
            ? staticIndeterminateValue.clamp(0.0, 1.0).toDouble()
            : null);

    final indicator = LinearProgressIndicator(
      minHeight: minHeight,
      value: effectiveValue,
      color: color,
      backgroundColor: backgroundColor,
      valueColor: color == null ? null : AlwaysStoppedAnimation<Color>(color!),
    );

    if (effectiveValue != null) {
      return indicator;
    }
    return RepaintBoundary(
      key: const ValueKey<String>('app-linear-progress-repaint-boundary'),
      child: indicator,
    );
  }
}
