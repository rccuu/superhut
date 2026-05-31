import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

Route<T> buildAppPageRoute<T>({
  required WidgetBuilder builder,
  Duration androidTransitionDuration = const Duration(milliseconds: 140),
  Duration androidReverseTransitionDuration = const Duration(milliseconds: 120),
  Offset androidSlideOffset = const Offset(0, 0.012),
}) {
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (!isAndroid) {
    return MaterialPageRoute<T>(builder: builder);
  }

  return PageRouteBuilder<T>(
    transitionDuration: androidTransitionDuration,
    reverseTransitionDuration: androidReverseTransitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return AppLightRouteTransition(
        animation: animation,
        slideOffset: androidSlideOffset,
        child: child,
      );
    },
  );
}

class AppLightPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppLightPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AppLightRouteTransition(animation: animation, child: child);
  }
}

class AppLightRouteTransition extends StatelessWidget {
  const AppLightRouteTransition({
    super.key,
    required this.animation,
    required this.child,
    this.slideOffset = const Offset(0, 0.012),
  });

  final Animation<double> animation;
  final Widget child;
  final Offset slideOffset;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations;
    if (disableAnimations == true || !TickerMode.valuesOf(context).enabled) {
      return child;
    }

    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final slideAnimation = Tween<Offset>(
      begin: slideOffset,
      end: Offset.zero,
    ).animate(curvedAnimation);
    final transitionChild = _RouteTransitionRepaintBoundary(
      animation: animation,
      child: child,
    );

    // Perf: route 转场只保留位移，不再叠加整屏透明度动画。
    // Flutter 官方性能建议明确指出 opacity 在动画里更贵，这里直接避免。
    return SlideTransition(position: slideAnimation, child: transitionChild);
  }
}

class _RouteTransitionRepaintBoundary extends SingleChildRenderObjectWidget {
  const _RouteTransitionRepaintBoundary({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderRouteTransitionRepaintBoundary(animation: animation);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderRouteTransitionRepaintBoundary renderObject,
  ) {
    renderObject.animation = animation;
  }
}

class _RenderRouteTransitionRepaintBoundary extends RenderProxyBox {
  _RenderRouteTransitionRepaintBoundary({required Animation<double> animation})
    : _animation = animation,
      _isTransitioning = _resolveIsTransitioning(animation);

  Animation<double> get animation => _animation;
  Animation<double> _animation;
  set animation(Animation<double> value) {
    if (_animation == value) {
      return;
    }
    if (attached) {
      _animation.removeStatusListener(_handleAnimationStatusChanged);
    }
    _animation = value;
    if (attached) {
      _animation.addStatusListener(_handleAnimationStatusChanged);
    }
    _updateTransitioningState();
  }

  bool _isTransitioning;

  @override
  bool get isRepaintBoundary => child != null && _isTransitioning;

  static bool _resolveIsTransitioning(Animation<double> animation) {
    return animation.status == AnimationStatus.forward ||
        animation.status == AnimationStatus.reverse;
  }

  void _handleAnimationStatusChanged(AnimationStatus status) {
    _updateTransitioningState();
  }

  void _updateTransitioningState() {
    final nextValue = _resolveIsTransitioning(_animation);
    if (_isTransitioning == nextValue) {
      return;
    }
    _isTransitioning = nextValue;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation.addStatusListener(_handleAnimationStatusChanged);
    _updateTransitioningState();
  }

  @override
  void detach() {
    _animation.removeStatusListener(_handleAnimationStatusChanged);
    super.detach();
  }
}
