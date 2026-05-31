import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import 'color_scheme_ext.dart';

const Duration _appBottomSheetAndroidDuration = Duration(milliseconds: 140);
const Duration _appBottomSheetAndroidReverseDuration = Duration(
  milliseconds: 110,
);
const AnimationStyle _appBottomSheetAndroidAnimationStyle = AnimationStyle(
  duration: _appBottomSheetAndroidDuration,
  reverseDuration: _appBottomSheetAndroidReverseDuration,
);

Future<T?> showAppAdaptiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool expand = false,
  Color? backgroundColor,
  Color? barrierColor,
  Color? transitionBackgroundColor,
  Radius? topRadius,
  BoxShadow? shadow,
}) {
  final effectiveBarrierColor =
      barrierColor ?? _defaultAppBottomSheetBarrierColor(context);
  final effectiveBackgroundColor = backgroundColor ?? Colors.transparent;
  final reduceMotion =
      MediaQuery.maybeOf(context)?.disableAnimations == true ||
      !TickerMode.valuesOf(context).enabled;

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: effectiveBackgroundColor,
      barrierColor: effectiveBarrierColor,
      sheetAnimationStyle:
          reduceMotion
              ? AnimationStyle.noAnimation
              : _appBottomSheetAndroidAnimationStyle,
      builder: builder,
    );
  }

  if (topRadius != null || shadow != null) {
    return showCupertinoModalBottomSheet<T>(
      context: context,
      expand: expand,
      backgroundColor: effectiveBackgroundColor,
      barrierColor: effectiveBarrierColor,
      transitionBackgroundColor:
          transitionBackgroundColor ?? effectiveBackgroundColor,
      topRadius: topRadius ?? const Radius.circular(12),
      shadow: shadow,
      duration: reduceMotion ? Duration.zero : null,
      builder: builder,
    );
  }

  return showCupertinoModalBottomSheet<T>(
    context: context,
    expand: expand,
    backgroundColor: effectiveBackgroundColor,
    barrierColor: effectiveBarrierColor,
    transitionBackgroundColor:
        transitionBackgroundColor ?? effectiveBackgroundColor,
    duration: reduceMotion ? Duration.zero : null,
    builder: builder,
  );
}

Color _defaultAppBottomSheetBarrierColor(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return colorScheme.overlayScrim.withValues(
    alpha: colorScheme.isDarkMode ? 0.20 : 0.10,
  );
}
