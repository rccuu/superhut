# 目标

参考上游 cc2562/superhut 的液态玻璃实现（f9214af 起，基于 `liquid_glass_easy ^5.1.0`），将首页底部 dock（课表 / 功能 / 我的）从现有 `_ClassicTabBar` 玻璃面板样式替换为真正的液态玻璃质感 tab 栏。用户已确认：全平台（iOS / Android / 桌面）直接使用 `liquid_glass_easy` 包实现，不再沿用本项目的 lite 性能降级路径处理 dock。

事实依据（已调查）：

- 上游实现：`lib/theme/glass/glass_theme.dart` 定义 `AppGlassTheme`（ThemeExtension，含 specular/glow/refraction/tabBarStyle/tabPillStyle 等令牌），homeview 用 `LiquidGlassTabBar` 悬浮于 Stack 底部（宽 min(width-48, 320)、高 64、bottom margin 24），滚动驱动隐藏/浮现。
- 我方现状：`lib/home/homeview/view.dart` 的 `_ClassicTabBar`（第 1178 行起）基于 `GlassPanel`（`lib/core/ui/apple_glass.dart`）+ `_OuterOnlyShadowPainter` 自绘阴影，条目为 `_DockItemData`（CupertinoIcons + 文字标签），经 `_tabStateNotifier` 控制选中与页面切换。
- 我方未引入上游的 `AppGlassTheme` ThemeExtension；`liquid_glass_easy` 未在依赖中。
- 上游 tabPillStyle 用 `LiquidGlassPillMode.impellerOnly`：Skia/Web 渲染器上 pill 自动退化为普通胶囊，避免黑块——该降级由包内处理，不需要我方另行实现。

# 范围

## 目录结构

### 新建

- lib/theme/glass/glass_theme.dart — 液态玻璃设计令牌（AppGlassTheme ThemeExtension，含 tabBarStyle / tabItemStyleOf / tabPillStyle 及其依赖的 specular、glow、contactShadow 令牌），从上游移植并裁剪到本 change 需要的部分。

### 修改

- pubspec.yaml — 新增 `liquid_glass_easy` 依赖（版本对齐上游 ^5.1.0）。
- lib/main.dart — 在 ThemeData 的 extensions 中注入 AppGlassTheme（随 brightness 构造）。
- lib/home/homeview/view.dart —
  - dock 挂载点（约第 598-623 行）替换为 LiquidGlassTabBar 悬浮实现：宽 min(screenWidth - 48, 320)、高 64、底部留 safe-area + 24 边距；
  - 新增滚动监听（NotificationListener<ScrollNotification>）：下滚（delta > 2 且 pixels > 48）dock 下滑淡出，上滚（delta < -2）浮现，AnimatedSlide + AnimatedOpacity 各 200ms；
  - 图标沿用现有 CupertinoIcons（calendar / square_grid_2x2 / person），选中色跟随 colorScheme.primary；
  - 保留 `_tabStateNotifier` 选中切换逻辑、`_ActiveOnlyIndexedStack` 与 `_AnimatedTabPage` 动画机制。

### 删除

- lib/home/homeview/view.dart 内 `_ClassicTabBar`、`_DockItemData`、`_OuterOnlyShadowPainter`（仅 dock 专用，液态玻璃落地后无引用）— 若实现中发现仍被其他位置引用则保留并在 Verifier 报告中说明。

# 非目标

- 不改动课程表、功能页、我的页等三个 tab 内容页的任何 UI。
- 不移植上游的 GlassTopBar、GlassSegmented、GlassSearchBar、glass_menu 等其他液态玻璃部件。
- 不改动 `AppGlassPerformanceScope` 现有 lite 体系在项目其他位置的行为。
- 不改动现有 tab 切换动画（_AnimatedTabPage 滑动 + TickerMode）机制。
- 不在设置页新增液态玻璃开关（用户已确认），不保留 _ClassicTabBar 作为回落样式。

# 验收示例

- A1: 应用启动后首页底部 dock 呈现液态玻璃质感（LiquidGlassTabBar），三个条目为课表 / 功能 / 我的，图标与现在一致；浅色与深色模式下文字图标均清晰可读。
- A2: 点击任一 dock 条目，页面切换到对应 tab，选中项出现液态玻璃胶囊指示（Impeller 下为折射 pill），切换行为与现有逻辑（_tabStateNotifier）一致，无重复点击副作用。
- A3: 在任一含纵向滚动列表的 tab 内下滚超过 48px，dock 下滑淡出隐藏；上滚立即浮现。停止滚动后 dock 保持当前可见性状态。
- A4: `flutter analyze` 无新增告警；`flutter test` 全部通过；Android 与 iOS 构建成功（本地 debug 构建即可）。
- A5: 删除 `_ClassicTabBar` / `_DockItemData` / `_OuterOnlyShadowPainter` 后代码库无残留死代码引用（grep 无引用）。

# Decisions

- D1（用户确认）：实现路线为全平台直接使用 `liquid_glass_easy` 包，不做 iOS 原生 / Android 降级双路径。
- D2（用户确认）：带上游的滚动收起/浮现交互，照抄上游阈值与动画参数。
- D3（用户确认）：不加设置页开关，不保留旧 dock 样式回落。
- D4：图标沿用现有 CupertinoIcons 而非上游 Ionicons，保持与其他页面图标体系一致；标签文字保留（课表/功能/我的）。
