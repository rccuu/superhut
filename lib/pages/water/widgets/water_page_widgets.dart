import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/ui/app_loading_indicator.dart';
import '../../../core/ui/apple_glass.dart';
import '../../../core/ui/color_scheme_ext.dart';

class HotWaterPalette {
  const HotWaterPalette._();

  static bool _isDark(BuildContext context) =>
      Theme.of(context).colorScheme.isDarkMode;

  static Color _hsl(double h, double s, double l, {double alpha = 1}) =>
      HSLColor.fromAHSL(alpha, h, s, l).toColor();

  static Color accent(BuildContext context, {bool active = false}) {
    if (_isDark(context)) {
      return active ? _hsl(340, 0.90, 0.50) : _hsl(330, 0.70, 0.55);
    }
    return active ? _hsl(340, 0.90, 0.50) : _hsl(330, 0.80, 0.70);
  }

  static Color accentStrong(BuildContext context, {bool active = false}) {
    if (_isDark(context)) {
      return active ? _hsl(330, 0.90, 0.75) : _hsl(330, 0.90, 0.68);
    }
    return active ? _hsl(330, 0.90, 0.75) : _hsl(330, 0.90, 0.69);
  }

  static Color coral(BuildContext context) {
    return _hsl(0, 1.0, 0.84);
  }

  static Color softSurface(BuildContext context) {
    if (_isDark(context)) {
      return _hsl(330, 0.30, 0.30);
    }
    return _hsl(330, 0.30, 0.92);
  }

  static Color mistSurface(BuildContext context) {
    if (_isDark(context)) {
      return _hsl(330, 0.20, 0.15);
    }
    return _hsl(330, 0.90, 0.98);
  }

  static Color buttonShell(BuildContext context) {
    if (_isDark(context)) {
      return _hsl(330, 0.30, 0.35);
    }
    return _hsl(330, 0.30, 1.0);
  }

  static Color buttonCore(BuildContext context) {
    if (_isDark(context)) {
      return _hsl(330, 0.30, 0.40);
    }
    return _hsl(330, 0.30, 0.95);
  }

  static Color foreground(BuildContext context) {
    if (_isDark(context)) {
      return _hsl(330, 0.30, 0.85);
    }
    return _hsl(330, 0.30, 0.35);
  }

  static Color mutedForeground(BuildContext context) {
    if (_isDark(context)) {
      return _hsl(330, 0.30, 0.76);
    }
    return _hsl(330, 0.24, 0.52);
  }

  static Color actionLabel(BuildContext context, {bool disabled = false}) {
    if (disabled) {
      return _isDark(context) ? _hsl(332, 0.16, 0.78) : _hsl(332, 0.18, 0.46);
    }
    return _hsl(336, 0.34, 0.28);
  }

  static Color contrast(BuildContext context, {bool active = false}) {
    if (_isDark(context)) {
      return active ? _hsl(330, 0.30, 0.94) : _hsl(330, 0.30, 0.88);
    }
    return active ? _hsl(330, 0.35, 0.28) : _hsl(330, 0.30, 0.35);
  }
}

class WaterBackground extends StatelessWidget {
  const WaterBackground({super.key, required this.waterStatus});

  final bool waterStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color accent = HotWaterPalette.accent(context, active: waterStatus);
    final Color support = HotWaterPalette.accentStrong(
      context,
      active: waterStatus,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                HotWaterPalette.buttonShell(context),
                HotWaterPalette.mistSurface(context),
                HotWaterPalette.softSurface(context),
              ],
            ),
          ),
        ),
        Positioned(
          top: -138,
          right: -68,
          child: _BackgroundGlow(
            size: 336,
            color: accent.withValues(alpha: waterStatus ? 0.20 : 0.16),
          ),
        ),
        Positioned(
          top: 142,
          left: -72,
          child: _BackgroundGlow(
            size: 236,
            color: support.withValues(alpha: waterStatus ? 0.12 : 0.10),
          ),
        ),
        Positioned(
          bottom: -166,
          left: -108,
          child: _BackgroundGlow(
            size: 388,
            color: accent.withValues(alpha: waterStatus ? 0.16 : 0.12),
          ),
        ),
        Positioned(
          bottom: 88,
          right: -46,
          child: _BackgroundGlow(
            size: 172,
            color: support.withValues(
              alpha: colorScheme.isDarkMode ? 0.18 : 0.14,
            ),
          ),
        ),
      ],
    );
  }
}

class HotWaterStatusHeader extends StatelessWidget {
  const HotWaterStatusHeader({
    super.key,
    required this.waterStatus,
    required this.hasSelectedDevice,
  });

  final bool waterStatus;
  final bool hasSelectedDevice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = colorScheme.isDarkMode;
    final Color accent = HotWaterPalette.accentStrong(
      context,
      active: waterStatus,
    );
    final Color titleColor = HotWaterPalette.foreground(context);
    final Color subtitleColor = HotWaterPalette.mutedForeground(context);
    final String title = waterStatus ? '热水已经开好' : '准备洗热水澡';
    final String subtitle =
        waterStatus
            ? '洗完记得结束，别让热水和余额一起溜走。'
            : hasSelectedDevice
            ? '设备已经选好，轻触中间按钮就能开始。'
            : '先选设备，再开始这次暖呼呼的热水澡。';

    return _WaterCardShell(
      borderRadius: BorderRadius.circular(30),
      accent: accent,
      highlightHeight: 98,
      shadowAlpha: isDark ? 0.14 : 0.07,
      borderAlpha: isDark ? 0.22 : 0.12,
      gradientColors: [
        HotWaterPalette.mistSurface(
          context,
        ).withValues(alpha: isDark ? 0.96 : 0.98),
        HotWaterPalette.softSurface(
          context,
        ).withValues(alpha: isDark ? 0.72 : 0.96),
      ],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WaterCapsule(
                        label: waterStatus ? '热水进行中' : '暖呼呼模式',
                        toneColor: accent,
                        textColor: accent,
                        icon:
                            waterStatus
                                ? Icons.water_drop_rounded
                                : Icons.favorite_border_rounded,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _WaterHeroOrb(
                  icon:
                      waterStatus
                          ? Icons.hot_tub_rounded
                          : Ionicons.water_outline,
                  color: accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HotWaterCurrentDeviceCard extends StatelessWidget {
  const HotWaterCurrentDeviceCard({
    super.key,
    required this.deviceName,
    required this.hasSelectedDevice,
    required this.onTap,
  });

  final String? deviceName;
  final bool hasSelectedDevice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = colorScheme.isDarkMode;
    final borderRadius = BorderRadius.circular(22);
    final Color accent = HotWaterPalette.accentStrong(context);

    return _WaterCardShell(
      borderRadius: borderRadius,
      accent: accent,
      highlightHeight: 72,
      shadowAlpha: isDark ? 0.12 : 0.05,
      borderAlpha: isDark ? 0.20 : 0.11,
      gradientColors: [
        HotWaterPalette.mistSurface(
          context,
        ).withValues(alpha: isDark ? 0.94 : 0.98),
        HotWaterPalette.softSurface(
          context,
        ).withValues(alpha: isDark ? 0.82 : 0.92),
      ],
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '当前设备',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _WaterCapsule(
                            label: hasSelectedDevice ? '切换' : '选择',
                            toneColor: accent,
                            textColor: accent,
                            icon: Icons.swap_horiz_rounded,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        deviceName ?? '请选择设备',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _WaterIconTile(
                  icon: Icons.keyboard_arrow_right_rounded,
                  color:
                      hasSelectedDevice ? accent : colorScheme.onSurfaceVariant,
                  backgroundColor: accent.withValues(
                    alpha: isDark ? 0.14 : 0.10,
                  ),
                  size: 44,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HotWaterControlButton extends StatelessWidget {
  const HotWaterControlButton({
    super.key,
    required this.isLoading,
    required this.deviceCheckComplete,
    required this.waterStatus,
    required this.hasSelectedDevice,
    required this.onTap,
  });

  final bool isLoading;
  final bool deviceCheckComplete;
  final bool waterStatus;
  final bool hasSelectedDevice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = isLoading || !deviceCheckComplete || !hasSelectedDevice;
    final bool isDark = colorScheme.isDarkMode;
    final bool useLiteEffects = AppGlassPerformanceScope.isLiteOf(context);
    final Color accent =
        isDisabled
            ? colorScheme.onSurfaceVariant
            : HotWaterPalette.accentStrong(context, active: waterStatus);
    final Color softAccent = HotWaterPalette.accent(
      context,
      active: waterStatus,
    );
    final Color foreground = HotWaterPalette.actionLabel(
      context,
      disabled: isDisabled,
    );
    final Color loadingForeground =
        isDisabled ? foreground : HotWaterPalette.actionLabel(context);
    final String label =
        isLoading
            ? '处理中'
            : !deviceCheckComplete
            ? '检测中'
            : !hasSelectedDevice
            ? '选择设备'
            : waterStatus
            ? '结束'
            : '开始';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 176,
        height: 176,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              HotWaterPalette.buttonShell(context),
              HotWaterPalette.softSurface(context),
            ],
          ),
          border: Border.all(
            color:
                isDisabled
                    ? colorScheme.outlineVariant.withValues(alpha: 0.42)
                    : accent.withValues(alpha: isDark ? 0.14 : 0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(
                alpha:
                    isDisabled
                        ? (useLiteEffects ? 0.03 : 0.04)
                        : (useLiteEffects ? 0.07 : 0.10),
              ),
              blurRadius:
                  isDisabled
                      ? (useLiteEffects ? 7 : 10)
                      : (useLiteEffects ? 12 : 18),
              spreadRadius:
                  isDisabled
                      ? (useLiteEffects ? 0 : 1)
                      : (useLiteEffects ? 1 : 2),
              offset: Offset(0, useLiteEffects ? 5 : 8),
            ),
          ],
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          isDisabled
                              ? HotWaterPalette.buttonShell(context)
                              : waterStatus
                              ? softAccent.withValues(alpha: 0.94)
                              : HotWaterPalette.accentStrong(context),
                          isDisabled
                              ? colorScheme.surfaceContainerHigh.withValues(
                                alpha: 0.88,
                              )
                              : waterStatus
                              ? HotWaterPalette.coral(context)
                              : HotWaterPalette.coral(
                                context,
                              ).withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(0, -1.08),
                        radius: 1.02,
                        colors: [
                          Colors.white.withValues(
                            alpha:
                                isDisabled
                                    ? (isDark ? 0.04 : 0.12)
                                    : (isDark ? 0.10 : 0.24),
                          ),
                          Colors.white.withValues(
                            alpha:
                                isDisabled
                                    ? (isDark ? 0.02 : 0.06)
                                    : (isDark ? 0.06 : 0.12),
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.28, 0.68],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 22,
                left: 30,
                child: _JellyHighlightBlob(
                  size: 24,
                  color: Colors.white.withValues(
                    alpha:
                        isDisabled
                            ? (isDark ? 0.03 : 0.08)
                            : (isDark ? 0.06 : 0.14),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                right: 24,
                child: _JellyHighlightBlob(
                  size: 36,
                  color: accent.withValues(
                    alpha:
                        isDisabled
                            ? (isDark ? 0.04 : 0.08)
                            : (isDark ? 0.10 : 0.14),
                  ),
                ),
              ),
              Center(
                child:
                    isLoading
                        ? _ProgressIndicator(
                          color: loadingForeground,
                          label: label,
                        )
                        : !deviceCheckComplete
                        ? _ProgressIndicator(
                          color: loadingForeground,
                          label: label,
                        )
                        : Text(
                          label,
                          style: (Theme.of(context).textTheme.headlineSmall ??
                                  const TextStyle())
                              .copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                height: 1,
                                color: foreground,
                              ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HotWaterActionHint extends StatelessWidget {
  const HotWaterActionHint({
    super.key,
    required this.isLoading,
    required this.deviceCheckComplete,
    required this.hasSelectedDevice,
  });

  final bool isLoading;
  final bool deviceCheckComplete;
  final bool hasSelectedDevice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String? message;
    IconData? icon;

    if (isLoading) {
      message = '正在处理本次热水操作';
      icon = Icons.autorenew_rounded;
    } else if (!deviceCheckComplete) {
      message = '正在检查设备状态';
      icon = Icons.search_rounded;
    } else if (!hasSelectedDevice) {
      message = '先选择设备，再开始';
      icon = Icons.touch_app_rounded;
    }

    if (message == null || icon == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  icon,
                  size: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextSpan(text: message),
          ],
        ),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 62,
          height: 62,
          child: AppLoadingIndicator(
            size: 62,
            color: color.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: (Theme.of(context).textTheme.labelLarge ?? const TextStyle())
              .copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                height: 1,
                color: color,
              ),
        ),
      ],
    );
  }
}

class HotWaterBalanceCard extends StatelessWidget {
  const HotWaterBalanceCard({
    super.key,
    required this.balance,
    required this.onTap,
  });

  final String balance;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = colorScheme.isDarkMode;
    final borderRadius = BorderRadius.circular(22);
    final Color accent = HotWaterPalette.accentStrong(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.floatingSurface,
            HotWaterPalette.softSurface(
              context,
            ).withValues(alpha: isDark ? 0.36 : 0.66),
          ],
        ),
        borderRadius: borderRadius,
        border: Border.all(color: colorScheme.subtleBorder),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: isDark ? 0.16 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  _WaterIconTile(
                    icon: Icons.account_balance_wallet_rounded,
                    color: accent,
                    backgroundColor: accent.withValues(
                      alpha: isDark ? 0.16 : 0.10,
                    ),
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '校园卡余额',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¥$balance',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _WaterIconTile(
                    icon: Icons.arrow_outward_rounded,
                    color: accent,
                    backgroundColor: accent.withValues(
                      alpha: isDark ? 0.16 : 0.10,
                    ),
                    size: 40,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaterCardShell extends StatelessWidget {
  const _WaterCardShell({
    required this.borderRadius,
    required this.accent,
    required this.gradientColors,
    required this.child,
    this.highlightHeight = 72,
    this.shadowAlpha = 0.06,
    this.borderAlpha = 0.12,
  });

  final BorderRadius borderRadius;
  final Color accent;
  final List<Color> gradientColors;
  final Widget child;
  final double highlightHeight;
  final double shadowAlpha;
  final double borderAlpha;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).colorScheme.isDarkMode;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: shadowAlpha),
            blurRadius: 22,
            spreadRadius: 0.5,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: accent.withValues(alpha: borderAlpha),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 1,
              left: 1,
              right: 1,
              height: highlightHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: borderRadius.topLeft,
                      topRight: borderRadius.topRight,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: isDark ? 0.10 : 0.30),
                        Colors.white.withValues(alpha: isDark ? 0.05 : 0.10),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.32, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.06 : 0.18,
                      ),
                      width: 0.8,
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _WaterIconTile extends StatelessWidget {
  const _WaterIconTile({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.size = 52,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Icon(icon, color: color, size: size * 0.46),
    );
  }
}

class _WaterHeroOrb extends StatelessWidget {
  const _WaterHeroOrb({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).colorScheme.isDarkMode;

    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.24, -0.24),
          colors: [
            color.withValues(alpha: isDark ? 0.32 : 0.18),
            color.withValues(alpha: isDark ? 0.14 : 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.68, 1.0],
        ),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        ),
      ),
      child: Icon(icon, size: 34, color: color),
    );
  }
}

class HotWaterBackButton extends StatelessWidget {
  const HotWaterBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).colorScheme.isDarkMode;
    final Color accent = HotWaterPalette.accentStrong(context);

    return GlassPanel(
      blur: 16,
      borderRadius: BorderRadius.circular(20),
      padding: EdgeInsets.zero,
      borderColor: accent.withValues(alpha: isDark ? 0.20 : 0.12),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          HotWaterPalette.buttonShell(
            context,
          ).withValues(alpha: isDark ? 0.84 : 0.94),
          HotWaterPalette.softSurface(
            context,
          ).withValues(alpha: isDark ? 0.70 : 0.90),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
      onTap: onTap,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Icon(Ionicons.chevron_back, color: accent, size: 24),
      ),
    );
  }
}

class _JellyHighlightBlob extends StatelessWidget {
  const _JellyHighlightBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _WaterCapsule extends StatelessWidget {
  const _WaterCapsule({
    required this.label,
    required this.toneColor,
    required this.textColor,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final String label;
  final Color toneColor;
  final Color textColor;
  final IconData? icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).colorScheme.isDarkMode;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: toneColor.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: toneColor.withValues(alpha: isDark ? 0.22 : 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class WaterDeviceSelectionSheet extends StatelessWidget {
  const WaterDeviceSelectionSheet({
    super.key,
    required this.devices,
    required this.deviceCount,
    required this.selectedIndex,
    required this.onManageDevices,
    required this.onSelectDevice,
  });

  final List<dynamic> devices;
  final int deviceCount;
  final int selectedIndex;
  final VoidCallback onManageDevices;
  final ValueChanged<int> onSelectDevice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color accent = HotWaterPalette.accentStrong(context);
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.5;
    final listHeight = min(maxListHeight, deviceCount * 64.0);

    return WaterBottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WaterSheetHandle(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '选择设备',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton.icon(
                  onPressed: onManageDevices,
                  icon: Icon(Icons.settings, color: accent),
                  label: Text('管理设备', style: TextStyle(color: accent)),
                ),
              ],
            ),
          ),
          if (deviceCount == 0)
            const Padding(
              padding: EdgeInsets.all(20),
              child: _EmptyDeviceState(message: '暂无可用设备，请先添加设备'),
            )
          else
            Container(
              height: listHeight + 20,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                itemCount: deviceCount,
                itemBuilder: (context, index) {
                  final device = devices[index] as Map;
                  final bool isSelected = selectedIndex == index;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    tileColor:
                        isSelected
                            ? HotWaterPalette.softSurface(context)
                            : colorScheme.surfaceContainer,
                    title: Text(
                      device['posname']?.toString() ?? '未知设备',
                      style: TextStyle(
                        fontSize: 20,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    trailing:
                        isSelected
                            ? Icon(Ionicons.checkmark_circle, color: accent)
                            : null,
                    onTap: () => onSelectDevice(index),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class WaterDeviceManagementSheet extends StatelessWidget {
  const WaterDeviceManagementSheet({
    super.key,
    required this.devices,
    required this.deviceCount,
    required this.onAddDevice,
    required this.onDeleteDevice,
  });

  final List<dynamic> devices;
  final int deviceCount;
  final VoidCallback onAddDevice;
  final ValueChanged<int> onDeleteDevice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color accent = HotWaterPalette.accentStrong(context);
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.3;
    final listHeight = min(maxListHeight, deviceCount * 72.0);

    return WaterBottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WaterSheetHandle(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '设备管理',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton.icon(
                  onPressed: onAddDevice,
                  icon: Icon(Icons.add_circle_outline, color: accent),
                  label: Text('添加设备', style: TextStyle(color: accent)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的设备',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                if (deviceCount == 0)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptyDeviceState(message: '暂无设备，请先添加设备'),
                  )
                else
                  SizedBox(
                    height: listHeight,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: false,
                      itemCount: deviceCount,
                      itemBuilder: (context, index) {
                        final device = devices[index] as Map;
                        final deviceName =
                            device['posname']?.toString() ?? '未知设备';
                        final deviceCode =
                            device['poscode']?.toString() ?? '未知设备号';
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          tileColor: HotWaterPalette.mistSurface(context),
                          title: Text(
                            deviceName,
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            '设备号: $deviceCode',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: colorScheme.error,
                            ),
                            onPressed: () => onDeleteDevice(index),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class AddWaterDeviceSheet extends StatefulWidget {
  const AddWaterDeviceSheet({
    super.key,
    required this.onClose,
    required this.onSubmit,
  });

  final VoidCallback onClose;
  final Future<bool> Function(String deviceCode) onSubmit;

  @override
  State<AddWaterDeviceSheet> createState() => _AddWaterDeviceSheetState();
}

class _AddWaterDeviceSheetState extends State<AddWaterDeviceSheet> {
  final TextEditingController _deviceCodeController = TextEditingController();
  final ValueNotifier<bool> _isSubmitting = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _deviceCodeController.dispose();
    _isSubmitting.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting.value) {
      return;
    }

    _setSubmitting(true);

    var shouldRestoreSubmitting = true;
    try {
      final closesSheet = await widget.onSubmit(
        _deviceCodeController.text.trim(),
      );
      shouldRestoreSubmitting = !closesSheet;
    } finally {
      if (shouldRestoreSubmitting) {
        _setSubmitting(false);
      }
    }
  }

  void _setSubmitting(bool isSubmitting) {
    if (!mounted || _isSubmitting.value == isSubmitting) {
      return;
    }

    _isSubmitting.value = isSubmitting;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = colorScheme.isDarkMode;
    final Color accent = HotWaterPalette.accentStrong(context);
    final Color buttonForeground =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
            ? Colors.white
            : const Color(0xFF5A1735);

    return WaterBottomSheetScaffold(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '添加新设备',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '请输入6位设备号码',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _deviceCodeController,
                  decoration: InputDecoration(
                    hintText: '输入6位设备号',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    prefixIcon: Icon(
                      Icons.confirmation_number_outlined,
                      color: accent,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: TextStyle(fontSize: 18, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _isSubmitting,
                    child: const Text('添加设备', style: TextStyle(fontSize: 18)),
                    builder: (context, isSubmitting, submitLabel) {
                      return FilledButton(
                        onPressed: _handleSubmit,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: buttonForeground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            isSubmitting
                                ? AppLoadingIndicator(
                                  size: 20,
                                  color: buttonForeground,
                                )
                                : submitLabel,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: HotWaterPalette.softSurface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accent.withValues(alpha: isDark ? 0.24 : 0.14),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: accent),
                            const SizedBox(width: 8),
                            Text(
                              '温馨提示',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. 设备号通常位于设备正门的显示屏中',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          '2. 设备号为6位数字',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          '3. 如无法添加，请联系学校管理员',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WaterBottomSheetScaffold extends StatelessWidget {
  const WaterBottomSheetScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HotWaterPalette.mistSurface(context),
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.subtleBorder),
          ),
        ),
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}

class WaterSheetHandle extends StatelessWidget {
  const WaterSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 5,
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: HotWaterPalette.accentStrong(context).withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _EmptyDeviceState extends StatelessWidget {
  const _EmptyDeviceState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color accent = HotWaterPalette.accentStrong(context);

    return Center(
      child: Column(
        children: [
          Icon(Icons.hot_tub, size: 48, color: accent.withValues(alpha: 0.88)),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
