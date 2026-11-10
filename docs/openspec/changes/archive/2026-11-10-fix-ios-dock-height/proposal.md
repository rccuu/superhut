# 修复 iOS 底部 dock 过高遮挡内容

## 问题

iOS 上首页底部液态玻璃 dock 位置明显偏高、遮挡主页面内容。模拟器实测（iPhone 16 Pro, 3x）：

- bar 底缘距屏幕底 89pt（旧版 `_ClassicTabBar` 约 34pt）
- bar 顶缘距屏幕底约 157pt（旧版约 102pt）

## 根因

`_LiquidGlassDock` 把底部间距通过 `margin: EdgeInsets.only(bottom: dockBottom)` 传给 `LiquidGlassTabBar`，而 `dockBottom = max(safeArea, 12) + 24` 已经包含一次安全区；`LiquidGlassTabBar` 的 Impeller 分支内部还会再叠加一次 `MediaQuery.padding.bottom`（安全区），导致安全区被计算两次、外加多余的 24pt：

- 预期底部间距 = 24（视觉留白）+ 34（safe-area）= 58pt
- 实际 = max(34,12) + 24 + 34 = 92pt

hit-zone 层同样用 `dockBottom + bottomInset` 定位，叠加方式一致，因此点击区仍然对齐（但整体一起偏高）。

## 修复目标

底部间距改为「固定视觉留白 + 单次安全区」，bar 底缘回到约 46pt、顶缘约 110pt，与旧版观感一致且不再明显遮挡内容；hit-zone 同步按新几何对齐。

## 范围

- `lib/home/homeview/view.dart`：`_LiquidGlassDock` 的 `dockBottom` 计算与 hit-zone 定位。
- 不涉及接口、依赖或架构变更；不改动玻璃视觉参数、交互与滚动逻辑。
