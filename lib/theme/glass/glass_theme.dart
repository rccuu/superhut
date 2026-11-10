import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// 液态玻璃设计令牌（dock 专用子集）。
///
/// 从上游 cc2562/superhut `lib/theme/glass/glass_theme.dart` 移植并裁剪：
/// 只保留底部标签栏需要的令牌；dialogStyle / menuStyle / sheetStyle /
/// controlStyle 等非 dock 令牌不移植。
///
/// 按 Apple Liquid Glass 规范，玻璃只用于「功能层」；玻璃本身固定为
/// 中性白 / 烟灰黑，不随主题色染色；文字与图标颜色由 [foreground] /
/// [foregroundMuted] 显式给出。
@immutable
class AppGlassTheme extends ThemeExtension<AppGlassTheme> {
  const AppGlassTheme({required this.enabled, required this.brightness});

  /// 玻璃外观是否启用。为 `false` 时玻璃组件应回落到 Material 实现。
  final bool enabled;

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  /// 中性玻璃底色：浅色 35% 白、深色 40% 烟灰黑。
  Color get tint => isDark ? const Color(0x66000000) : const Color(0x59FFFFFF);

  /// 玻璃上的主要前景色。
  Color get foreground =>
      isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1B1B1F);

  /// 玻璃上的次要前景色（未选中图标）。
  Color get foregroundMuted =>
      isDark ? const Color(0xB3EBEBF5) : const Color(0x991B1B1F);

  /// 选中胶囊的底色。
  Color get selectionTint =>
      isDark ? const Color(0x33FFFFFF) : const Color(0x14000000);

  LiquidGlassLight get _specular => LiquidGlassLight.specular(
    thickness: 1.4,
    sharpness: 0.35,
    angle: 39,
    spread: 0.92,
    intensity: isDark ? 0.95 : 1,
  );

  LiquidGlassLight get _glow => LiquidGlassLight.glow(
    thickness: 7,
    angle: 129,
    spread: 0.6,
    intensity: isDark ? 0.45 : 0.6,
  );

  /// 底部标签栏胶囊：形状交给组件按高度派生全胶囊。
  LiquidGlassStyle get tabBarStyle => LiquidGlassStyle(
    specular: _specular,
    glow: _glow,
    refractionIndex: 1.04,
    refractionWidth: 14,
    blur: 5,
    color: tint,
    shadow: LiquidGlassShadow(
      blur: 18,
      opacity: isDark ? 0.4 : 0.16,
      inset: 0,
    ),
  );

  /// 底部标签栏图标配色：选中跟随主题 primary，未选中用次要前景色。
  LiquidGlassTabItemStyle tabItemStyleOf(ColorScheme scheme) =>
      LiquidGlassTabItemStyle(
        selectedColor: scheme.primary,
        unselectedColor: scheme.onSurfaceVariant,
        iconSize: 24,
        labelFontSize: 10.5,
        selectedFontWeight: FontWeight.w600,
        unselectedFontWeight: FontWeight.w500,
      );

  LiquidGlassTabPillStyle get tabPillStyle => LiquidGlassTabPillStyle(
    // 只有 Impeller 上才用折射 pill；Skia/Web 退化为普通胶囊，避免黑块。
    mode: LiquidGlassPillMode.impellerOnly,
    animated: true,
    animationDuration: const Duration(milliseconds: 300),
    animationCurve: Curves.easeOutCubic,
    color: selectionTint,
    blur: 0,
    growHeight: 6,
    refractionIndex: 1.025,
    refractionWidth: 10,
  );

  @override
  AppGlassTheme copyWith({bool? enabled, Brightness? brightness}) {
    return AppGlassTheme(
      enabled: enabled ?? this.enabled,
      brightness: brightness ?? this.brightness,
    );
  }

  /// 样式对象本身不可插值，主题切换时按中点直接取一侧，避免中间态出现
  /// 半套玻璃令牌。
  @override
  AppGlassTheme lerp(covariant AppGlassTheme? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppGlassThemeContext on BuildContext {
  /// 当前主题的玻璃令牌；主题未注入时返回一个「关闭」的占位实例。
  AppGlassTheme get glassTheme {
    return Theme.of(this).extension<AppGlassTheme>() ??
        AppGlassTheme(
          enabled: false,
          brightness: Theme.of(this).brightness,
        );
  }

  bool get glassEnabled => glassTheme.enabled;
}
