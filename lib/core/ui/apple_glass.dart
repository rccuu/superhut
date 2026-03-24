import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum AppGlassBackgroundStyle { rich, soft, flat }

enum GlassPanelStyle { hero, floating, card, list, solid }

class AppGlassBackground extends StatelessWidget {
  const AppGlassBackground({
    super.key,
    required this.child,
    this.bottomHighlightOpacity = 1,
    this.lightBottomColor,
    this.darkBottomColor,
    this.style = AppGlassBackgroundStyle.rich,
  });

  final Widget child;
  final double bottomHighlightOpacity;
  final Color? lightBottomColor;
  final Color? darkBottomColor;
  final AppGlassBackgroundStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final useLiteEffects =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final effectiveStyle =
        useLiteEffects && style == AppGlassBackgroundStyle.rich
            ? AppGlassBackgroundStyle.soft
            : style;
    final orbBlurSigma = switch (effectiveStyle) {
      AppGlassBackgroundStyle.rich => useLiteEffects ? 34.0 : 56.0,
      AppGlassBackgroundStyle.soft => useLiteEffects ? 20.0 : 34.0,
      AppGlassBackgroundStyle.flat => 0.0,
    };
    final orbScale = switch (effectiveStyle) {
      AppGlassBackgroundStyle.rich => 1.0,
      AppGlassBackgroundStyle.soft => 0.78,
      AppGlassBackgroundStyle.flat => 0.0,
    };
    final orbOpacity = switch (effectiveStyle) {
      AppGlassBackgroundStyle.rich => 1.0,
      AppGlassBackgroundStyle.soft => 0.58,
      AppGlassBackgroundStyle.flat => 0.0,
    };
    final highlightStrength = switch (effectiveStyle) {
      AppGlassBackgroundStyle.rich => 1.0,
      AppGlassBackgroundStyle.soft => 0.62,
      AppGlassBackgroundStyle.flat => 0.22,
    };

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
          if (orbOpacity > 0)
            _AmbientOrb(
              alignment: const Alignment(-1.15, -0.92),
              width: 280 * orbScale,
              height: 280 * orbScale,
              blurSigma: orbBlurSigma,
              colors: [
                colorScheme.primary.withValues(
                  alpha: (isDark ? 0.18 : 0.18) * orbOpacity,
                ),
                colorScheme.primary.withValues(alpha: 0),
              ],
            ),
          if (effectiveStyle == AppGlassBackgroundStyle.rich)
            _AmbientOrb(
              alignment: const Alignment(1.08, -0.78),
              width: 250 * orbScale,
              height: 250 * orbScale,
              blurSigma: orbBlurSigma,
              colors: [
                colorScheme.secondary.withValues(
                  alpha: (isDark ? 0.14 : 0.14) * orbOpacity,
                ),
                colorScheme.secondary.withValues(alpha: 0),
              ],
            ),
          if (orbOpacity > 0)
            _AmbientOrb(
              alignment: const Alignment(0.9, 0.78),
              width: 340 * orbScale,
              height: 340 * orbScale,
              blurSigma: orbBlurSigma,
              colors: [
                colorScheme.tertiary.withValues(
                  alpha: (isDark ? 0.11 : 0.10) * orbOpacity,
                ),
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
                    Colors.white.withValues(
                      alpha: (isDark ? 0.03 : 0.14) * highlightStrength,
                    ),
                    Colors.transparent,
                    Colors.white.withValues(
                      alpha:
                          (isDark ? 0.02 : 0.08) *
                          highlightStrength *
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
    this.style = GlassPanelStyle.card,
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
  final GlassPanelStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final useLiteEffects =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final canUseBackdrop = switch (style) {
      GlassPanelStyle.hero => !useLiteEffects,
      GlassPanelStyle.floating => !useLiteEffects,
      GlassPanelStyle.card => !useLiteEffects && blur >= 16,
      GlassPanelStyle.list => false,
      GlassPanelStyle.solid => false,
    };
    final effectiveBlur =
        useBackdropFilter && canUseBackdrop && blur > 0.01
            ? (useLiteEffects ? blur.clamp(0.0, 12.0) : blur)
            : 0.0;
    final effectiveShadowBlur = switch (style) {
      GlassPanelStyle.hero => useLiteEffects ? 20.0 : 30.0,
      GlassPanelStyle.floating => useLiteEffects ? 18.0 : 24.0,
      GlassPanelStyle.card => useLiteEffects ? 14.0 : 18.0,
      GlassPanelStyle.list => useLiteEffects ? 8.0 : 12.0,
      GlassPanelStyle.solid => 0.0,
    };
    final effectiveShadowOffset = switch (style) {
      GlassPanelStyle.hero =>
        useLiteEffects ? const Offset(0, 10) : const Offset(0, 16),
      GlassPanelStyle.floating =>
        useLiteEffects ? const Offset(0, 9) : const Offset(0, 12),
      GlassPanelStyle.card =>
        useLiteEffects ? const Offset(0, 7) : const Offset(0, 10),
      GlassPanelStyle.list =>
        useLiteEffects ? const Offset(0, 4) : const Offset(0, 6),
      GlassPanelStyle.solid => Offset.zero,
    };
    final effectiveSurfaceOpacity = switch (style) {
      GlassPanelStyle.hero => isDark ? 0.18 : 0.54,
      GlassPanelStyle.floating => isDark ? 0.20 : 0.60,
      GlassPanelStyle.card => isDark ? 0.22 : 0.68,
      GlassPanelStyle.list => isDark ? 0.26 : 0.78,
      GlassPanelStyle.solid => isDark ? 0.34 : 0.92,
    };
    final effectiveBorderAlpha = switch (style) {
      GlassPanelStyle.hero => isDark ? 0.14 : 0.62,
      GlassPanelStyle.floating => isDark ? 0.13 : 0.52,
      GlassPanelStyle.card => isDark ? 0.12 : 0.34,
      GlassPanelStyle.list => isDark ? 0.10 : 0.24,
      GlassPanelStyle.solid => isDark ? 0.08 : 0.16,
    };
    final effectiveShadowAlpha = switch (style) {
      GlassPanelStyle.hero => isDark ? 0.24 : 0.08,
      GlassPanelStyle.floating => isDark ? 0.20 : 0.07,
      GlassPanelStyle.card => isDark ? 0.16 : 0.06,
      GlassPanelStyle.list => isDark ? 0.10 : 0.04,
      GlassPanelStyle.solid => 0.0,
    };
    final defaultGradientColors = switch (style) {
      GlassPanelStyle.hero => [
        Colors.white.withValues(alpha: isDark ? 0.16 : 0.70),
        colorScheme.surface.withValues(alpha: isDark ? 0.10 : 0.34),
      ],
      GlassPanelStyle.floating => [
        Colors.white.withValues(alpha: isDark ? 0.14 : 0.74),
        colorScheme.surface.withValues(alpha: isDark ? 0.12 : 0.38),
      ],
      GlassPanelStyle.card => [
        Colors.white.withValues(alpha: isDark ? 0.12 : 0.80),
        colorScheme.surface.withValues(alpha: isDark ? 0.14 : 0.44),
      ],
      GlassPanelStyle.list => [
        Colors.white.withValues(alpha: isDark ? 0.08 : 0.88),
        colorScheme.surface.withValues(alpha: isDark ? 0.18 : 0.56),
      ],
      GlassPanelStyle.solid => [
        Colors.white.withValues(alpha: isDark ? 0.04 : 0.94),
        colorScheme.surface.withValues(alpha: isDark ? 0.24 : 0.74),
      ],
    };
    final decoration = BoxDecoration(
      color:
          gradient == null
              ? (tintColor ??
                  colorScheme.surface.withValues(
                    alpha: effectiveSurfaceOpacity,
                  ))
              : null,
      gradient:
          gradient ??
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: defaultGradientColors,
          ),
      borderRadius: borderRadius,
      border: Border.all(
        color:
            borderColor ?? Colors.white.withValues(alpha: effectiveBorderAlpha),
      ),
      boxShadow:
          boxShadow ??
          (effectiveShadowBlur <= 0
              ? const []
              : [
                BoxShadow(
                  color: colorScheme.shadow.withValues(
                    alpha: effectiveShadowAlpha,
                  ),
                  blurRadius: effectiveShadowBlur,
                  offset: effectiveShadowOffset,
                ),
              ]),
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

    final decoratedBody =
        effectiveBlur > 0.01
            ? ClipRRect(
              borderRadius: borderRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: effectiveBlur,
                  sigmaY: effectiveBlur,
                ),
                child: panelBody,
              ),
            )
            : panelBody;

    return Container(margin: margin, child: decoratedBody);
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
