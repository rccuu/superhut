import 'package:flutter/material.dart';

/// 798 首页提示条与语义色，取值照搬独立 App 的实测结果。
///
/// 原先直接用 `Colors.orange / red / green`，白色标签压在上面的对比度分别是
/// 2.16 / 3.68 / 2.78，全部低于 4.5:1。这里每一块都是实底，深浅模式共用一组值。
abstract final class DrinkPromptColors {
  static const Color warning = Color(0xFFB45309); // 白字 5.02:1
  static const Color error = Color(0xFFC62828); // 白字 5.62:1
  static const Color success = Color(0xFF2E7D32); // 白字 5.13:1
}

/// 798 两页共用的品牌蓝。
///
/// 刻意不读宿主 `colorScheme.primary`：superhut 的品牌蓝与独立 App 不同，
/// 而页面里的对比度数值是按这组取值实算出来的，换色就得全部重算。
abstract final class DrinkBrand {
  static const Color primary = Color(0xFF2196F3);
}

/// 798 首页专用视觉 token。
///
/// 刻意不写进全局 AppTheme：那会连带改掉其它功能页的默认值。
/// 每个「承载文字的面 / 文字」配对都按 WCAG 相对亮度实算过，改动数值必须
/// 同步重跑首页的对比度断言。
abstract final class DrinkHomeT {
  // 浅色：页面本体比卡片暗一档，白卡片才浮得起来（page→card 1.174）。
  static const pageLight = Color(0xFFE4EEF8);
  static const cardLight = Color(0xFFFFFFFF);
  static const tintLight = Color(0xFFDCEBF9);
  static const bandTopLight = Color(0xFFC5E0F7);

  // α.18 的淡边压在白卡上只有 1.133，描边画了但看不出画；提到 α.30 才有第二条通道。
  static const hairlineLight = Color(0x4D7E96AE);

  // 深色靠「抬亮」分层，但卡片必须比它真正压着的那条带也亮一档：page < band < card。
  static const pageDark = Color(0xFF0A0F14);
  static const cardDark = Color(0xFF1E2934);
  static const selectedDark = Color(0xFF283645);

  // 深色图标底与选中底必须分开，两者取同一块时选中条目的图标底会糊成一片。
  static const tintDark = Color(0xFF31404F);
  static const bandTopDark = Color(0xFF0D1A28);
  static const hairlineDark = Color(0x594C6076);

  // 强调面：白色标签在最浅停靠点仍有 4.80。
  static const accentStart = Color(0xFF0277BD);
  static const accentEnd = Color(0xFF00619E);
  static const settle = DrinkPromptColors.warning;

  // 次要文字用 α.60：主题的 black54 压在本体色上只有 4.44。
  static const inkLight = Color(0xDD000000);
  static const inkSecondaryLight = Color(0x99000000);
  static const brandInkLight = Color(0xFF0F5C99);
  static const neutralGlyphLight = Color(0xFF5A6B7B);
  static const inkDark = Color(0xFFFFFFFF);
  static const inkSecondaryDark = Color(0xB3FFFFFF);
  static const brandInkDark = Color(0xFF64B5F6);
  static const neutralGlyphDark = Color(0xFF9AA7B4);

  // 危险操作用同一份红，两处不能各写一个。
  static const destructiveLight = DrinkPromptColors.error;
  static const destructiveDark = Color(0xFFFF8A80);

  // 不可用态按 WCAG 1.4.3 属于豁免，但仍要与可用态一眼可辨。
  static const disabledLight = Color(0xFFC6D3DE);
  static const disabledInkLight = Color(0xFF4A5765);
  static const disabledDark = Color(0xFF232B33);
  static const disabledInkDark = Color(0xFF9AA7B4);

  static const radiusCard = 24.0;
  static const radiusTile = 14.0;
  static const radiusChip = 12.0;
}

/// 首页表面色按主题分支的取值，避免每处都写三元判断。
class DrinkHomePalette {
  const DrinkHomePalette.light()
    : page = DrinkHomeT.pageLight,
      card = DrinkHomeT.cardLight,
      selected = DrinkHomeT.cardLight,
      tint = DrinkHomeT.tintLight,
      bandTop = DrinkHomeT.bandTopLight,
      hairline = DrinkHomeT.hairlineLight,
      ink = DrinkHomeT.inkLight,
      inkSecondary = DrinkHomeT.inkSecondaryLight,
      brandInk = DrinkHomeT.brandInkLight,
      neutralGlyph = DrinkHomeT.neutralGlyphLight,
      disabled = DrinkHomeT.disabledLight,
      disabledInk = DrinkHomeT.disabledInkLight,
      destructive = DrinkHomeT.destructiveLight,
      isDark = false;

  const DrinkHomePalette.dark()
    : page = DrinkHomeT.pageDark,
      card = DrinkHomeT.cardDark,
      selected = DrinkHomeT.selectedDark,
      tint = DrinkHomeT.tintDark,
      bandTop = DrinkHomeT.bandTopDark,
      hairline = DrinkHomeT.hairlineDark,
      ink = DrinkHomeT.inkDark,
      inkSecondary = DrinkHomeT.inkSecondaryDark,
      brandInk = DrinkHomeT.brandInkDark,
      neutralGlyph = DrinkHomeT.neutralGlyphDark,
      disabled = DrinkHomeT.disabledDark,
      disabledInk = DrinkHomeT.disabledInkDark,
      destructive = DrinkHomeT.destructiveDark,
      isDark = true;

  static DrinkHomePalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const DrinkHomePalette.dark()
          : const DrinkHomePalette.light();

  /// 小屏或大字号时收紧留白：固定 padding 配固定高度在这种尺寸会把卡片顶出可视区。
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 640 ||
      MediaQuery.textScalerOf(context).scale(14) > 16.8;

  final Color page;
  final Color card;
  final Color selected;
  final Color tint;
  final Color bandTop;
  final Color hairline;
  final Color ink;
  final Color inkSecondary;
  final Color brandInk;
  final Color neutralGlyph;
  final Color disabled;
  final Color disabledInk;
  final Color destructive;
  final bool isDark;

  /// 选中态是否用提亮填充表达。浅色下不换填充：淡蓝底相对页面本体只有 1.118，
  /// 选中反而会把卡片粘回背景，所以浅色改用描边 + 勾选 + 抬升两个通道。
  bool get selectionTintsFill => isDark;

  Color tileFill({required bool isSelected}) =>
      isSelected && selectionTintsFill ? selected : card;

  /// 选中角标的面与符号色。深色下品牌蓝底配白勾只有 2.57，反过来用亮蓝底配页面墨色。
  Color get markerFill => isDark ? brandInk : DrinkHomeT.accentStart;
  Color get markerInk => isDark ? page : Colors.white;

  LinearGradient get idleBackground => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bandTop, Color.lerp(bandTop, page, 0.55)!, page],
    stops: const [0.0, 0.42, 1.0],
  );

  LinearGradient get activeBackground => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.alphaBlend(DrinkHomeT.accentStart.withValues(alpha: 0.28), page),
      Color.alphaBlend(DrinkHomeT.accentEnd.withValues(alpha: 0.18), page),
      page,
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  LinearGradient get accentFill => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [DrinkHomeT.accentStart, DrinkHomeT.accentEnd],
  );
}
