# 验证报告：fix-ios-dock-height

## 结论

通过。iOS 底部 dock 因安全区重复计入导致的偏高已修复，实测几何回到旧版水平。

## 缺陷复现（修复前）

iOS 模拟器 iPhone 16 Pro（1206×2622 @3x），修复前截图测量：

- bar 底缘距屏幕底：89pt
- bar 顶缘距屏幕底：约 157pt
- 旧版 `_ClassicTabBar` 顶缘约 102pt —— 明显偏高并遮挡主页面内容

根因：`dockBottom = max(safeArea,12) + 24 = 58`，`LiquidGlassTabBar` Impeller 分支内部再叠加 `MediaQuery.padding.bottom`（34），安全区被计算两次（58 + 34 = 92pt）。

## 修复后实测

同一模拟器、同一测量方法（中间列带白色玻璃像素行统计）：

- bar 底缘距屏幕底：**46.3pt**（理论值 12 + 34 = 46）
- bar 顶缘距屏幕底：约 110pt（46 + 64）
- 与旧版 102pt 基本一致，遮挡明显减少

## 检查项

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 静态分析 | `flutter analyze` | No issues found |
| 全量测试 | `flutter test` | 727 项全部通过 |
| 几何复测 | iOS 模拟器截图测量 | 底缘 46.3pt（目标 46pt ± 3pt） |

## 影响范围审查

- 改动仅限 `lib/home/homeview/view.dart` 的 `_LiquidGlassDock`：`dockBottom` → `dockMargin = 12`，hit-zone 底部定位同步为 `dockMargin + bottomInset`（保持点击区与 bar 对齐）。
- 玻璃视觉参数、手势层（IgnorePointer + Semantics）、滚动收起/浮现逻辑均未改动。
- 桌面/iOS 无 home indicator 的设备：`bottomInset = 0` 时底部间距 12pt，仍有留白。

## 可接受偏差

- 截图自动测量把课表白色背景一并计入时区间偏大，故以「底缘间距」为主判据（该值不受背景影响）。
- bar 仍与课表最后一行视觉重叠（页面未预留底部内边距），与旧版行为一致，属既有设计而非本次回归。

## 独立审查

本次为单文件、6 行改动的定位参数修正，未涉及接口、并发、安全或数据路径；由当前会话完成代码与实测双重复核。
