# 底部 Dock 液态玻璃化

## Outcome

首页底部导航 dock（课表 / 功能 / 我的）从自定义玻璃面板样式（`_ClassicTabBar` + `GlassPanel`）替换为基于 `liquid_glass_easy` 的液态玻璃 tab 栏，视觉与上游 cc2562/superhut 的液态玻璃实现一致：中性玻璃底、specular/glow 边光、折射胶囊选中指示。dock 支持滚动收起/浮现。

## Requirements

### R1 依赖与玻璃令牌

- `pubspec.yaml` 新增 `liquid_glass_easy: ^5.1.0`。
- 新建 `lib/theme/glass/glass_theme.dart`：`AppGlassTheme`（ThemeExtension<AppGlassTheme>），从上游移植并裁剪到 dock 所需：`tint`、`foreground`、`foregroundMuted`、`selectionTint`、specular/glow/contactShadow 令牌、`tabBarStyle`、`tabItemStyleOf(ColorScheme)`、`tabPillStyle`、`AppGlassThemeContext.glassTheme` 扩展。上游的 dialogStyle、menuStyle、sheetStyle、controlStyle 等非 dock 令牌不移植。
- `lib/main.dart` 在两个 ThemeData（浅色/深色）的 `extensions` 中注入对应 brightness 的 `AppGlassTheme`。

### R2 液态玻璃 Dock

验收：A1

- dock 使用 `LiquidGlassTabBar` + `LiquidGlassTabBarItem`，悬浮于 Stack 底部：宽 `min(screenWidth - 48, 320)`、高 64、水平居中、底部边距为 safe-area（小于 12 时取 12）+ 24。
- 三个条目：课表（CupertinoIcons.calendar）、功能（CupertinoIcons.square_grid_2x2）、我的（CupertinoIcons.person），带文字标签，与现状一致。
- 样式来自 `glassTheme.tabBarStyle` 与 `glassTheme.tabItemStyleOf(colorScheme)`、`glassTheme.tabPillStyle`；浅色/深色均清晰可读。

### R3 选中与切换

验收：A2

- 选中项由现有 `_tabStateNotifier` 的 selectedIndex 驱动；onChanged 走现有 `_onTabChange`。
- 选中胶囊 `LiquidGlassPillMode.impellerOnly` + animated（300ms easeOutCubic），由包内处理 Skia 退化。
- 页面切换复用现有 `_ActiveOnlyIndexedStack` / `_AnimatedTabPage` 机制，不做改动。

### R4 滚动收起/浮现

验收：A3

- 在首页 Shell 外层包 `NotificationListener<ScrollNotification>`：下滚（ScrollUpdateNotification.delta > 2 且 pixels > 48）隐藏；上滚（delta < -2）浮现。
- 隐藏/浮现用 AnimatedSlide（Offset(0, 0.2) ↔ zero）+ AnimatedOpacity，各 200ms easeOut；隐藏时 IgnorePointer。
- tab 切换时 dock 恢复可见（对齐上游 `_resetOverlayState`）。

### R5 清理与质量

验收：A4, A5

- 删除 `_ClassicTabBar`、`_DockItemData`、`_OuterOnlyShadowPainter` 及仅其使用的辅助代码；全库无残留引用。
- `flutter analyze` 无新增告警；`flutter test` 全部通过。

## Scenario: 首次进入首页看到液态玻璃 dock

- WHEN 应用启动并进入首页（课表 tab 默认选中）
- THEN 底部呈现液态玻璃质感 dock，三个条目及标签与 R2 一致
- 验收：A1

## Scenario: 点击切换 tab

- WHEN 用户点击 dock 中任一条目
- THEN 对应 tab 页面显示，选中胶囊移动到该条目
- 验收：A2

## Scenario: 滚动隐藏与浮现

- WHEN 用户在课表/功能/我的任一可滚动区域下滚超过阈值
- THEN dock 下滑淡出且不再响应点击；上滚后 dock 立即浮现并恢复可点击
- 验收：A3

## Scenario: 质量门槛

- WHEN 运行 flutter analyze 与 flutter test
- THEN 无新增告警且测试全部通过
- 验收：A4
