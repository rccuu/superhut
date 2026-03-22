import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppGlassBackground extends StatelessWidget {
  const AppGlassBackground({
    super.key,
    required this.child,
    this.bottomHighlightOpacity = 1,
    this.lightBottomColor,
    this.darkBottomColor,
  });

  final Widget child;
  final double bottomHighlightOpacity;
  final Color? lightBottomColor;
  final Color? darkBottomColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final useLiteEffects =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final orbBlurSigma = useLiteEffects ? 34.0 : 56.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors:
              isDark
                  ? [
                    const Color(0xFF0A0F17),
                    const Color(0xFF101826),
                    darkBottomColor ?? const Color(0xFF0C111A),
                  ]
                  : [
                    Color(0xFFF4F7FC),
                    Color(0xFFEAF0FA),
                    lightBottomColor ?? const Color(0xFFF8FAFD),
                  ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _AmbientOrb(
            alignment: const Alignment(-1.15, -0.92),
            width: 280,
            height: 280,
            blurSigma: orbBlurSigma,
            colors: [
              colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.18),
              colorScheme.primary.withValues(alpha: 0),
            ],
          ),
          _AmbientOrb(
            alignment: const Alignment(1.08, -0.78),
            width: 250,
            height: 250,
            blurSigma: orbBlurSigma,
            colors: [
              colorScheme.secondary.withValues(alpha: isDark ? 0.14 : 0.14),
              colorScheme.secondary.withValues(alpha: 0),
            ],
          ),
          _AmbientOrb(
            alignment: const Alignment(0.9, 0.78),
            width: 340,
            height: 340,
            blurSigma: orbBlurSigma,
            colors: [
              colorScheme.tertiary.withValues(alpha: isDark ? 0.11 : 0.10),
              colorScheme.tertiary.withValues(alpha: 0),
            ],
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.03 : 0.14),
                    Colors.transparent,
                    Colors.white.withValues(
                      alpha:
                          (isDark ? 0.02 : 0.08) *
                          bottomHighlightOpacity.clamp(0.0, 1.0),
                    ),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.blur = 20,
    this.tintColor,
    this.gradient,
    this.borderColor,
    this.boxShadow,
    this.onTap,
    this.useBackdropFilter = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final double blur;
  final Color? tintColor;
  final Gradient? gradient;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final bool useBackdropFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final useLiteEffects =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final effectiveBlur = useLiteEffects ? blur.clamp(0.0, 12.0) : blur;
    final effectiveShadowBlur = useLiteEffects ? 22.0 : 32.0;
    final effectiveShadowOffset =
        useLiteEffects ? const Offset(0, 12) : const Offset(0, 18);
    final decoration = BoxDecoration(
      color:
          gradient == null
              ? (tintColor ??
                  colorScheme.surface.withValues(alpha: isDark ? 0.20 : 0.58))
              : null,
      gradient:
          gradient ??
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: isDark ? 0.16 : 0.70),
              colorScheme.surface.withValues(alpha: isDark ? 0.10 : 0.34),
            ],
          ),
      borderRadius: borderRadius,
      border: Border.all(
        color:
            borderColor ?? Colors.white.withValues(alpha: isDark ? 0.14 : 0.62),
      ),
      boxShadow:
          boxShadow ??
          [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: isDark ? 0.22 : 0.08),
              blurRadius: effectiveShadowBlur,
              offset: effectiveShadowOffset,
            ),
          ],
    );

    final content =
        onTap == null
            ? Padding(padding: padding, child: child)
            : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: borderRadius,
                onTap: onTap,
                child: Padding(padding: padding, child: child),
              ),
            );

    final panelBody = DecoratedBox(decoration: decoration, child: content);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius,
        child:
            useBackdropFilter && effectiveBlur > 0.01
                ? BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: effectiveBlur,
                    sigmaY: effectiveBlur,
                  ),
                  child: panelBody,
                )
                : panelBody,
      ),
    );
  }
}

class GlassIconBadge extends StatelessWidget {
  const GlassIconBadge({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 52,
  });

  final IconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.24 : 0.94),
            tint.withValues(alpha: isDark ? 0.32 : 0.22),
          ],
        ),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.82),
        ),
      ),
      child: Icon(icon, color: tint, size: size * 0.42),
    );
  }
}

class GlassHairlineDivider extends StatelessWidget {
  const GlassHairlineDivider({
    super.key,
    this.horizontal = 0,
    this.vertical = 0,
  });

  final double horizontal;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      child: Container(
        height: 1,
        color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.52),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({
    required this.alignment,
    required this.width,
    required this.height,
    required this.blurSigma,
    required this.colors,
  });

  final Alignment alignment;
  final double width;
  final double height;
  final double blurSigma;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: colors),
            ),
          ),
        ),
      ),
    );
  }
}
