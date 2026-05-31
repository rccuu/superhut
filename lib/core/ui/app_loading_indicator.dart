import 'package:flutter/cupertino.dart';

import 'apple_glass.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.color,
    this.size = 40,
    this.animating = true,
  });

  final Color? color;
  final double size;
  final bool animating;

  @override
  Widget build(BuildContext context) {
    final radius = (size / 2).clamp(3.0, 22.0).toDouble();
    final effectiveAnimating =
        animating && !AppGlassPerformanceScope.shouldReduceMotionOf(context);

    final indicator = SizedBox.square(
      dimension: size,
      child: Center(
        child: CupertinoActivityIndicator(
          color: color,
          radius: radius,
          animating: effectiveAnimating,
        ),
      ),
    );

    if (!effectiveAnimating) {
      return indicator;
    }
    return RepaintBoundary(child: indicator);
  }
}
