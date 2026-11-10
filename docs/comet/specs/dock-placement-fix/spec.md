# 底部 Dock 错位修复

## Outcome

首页底部液态玻璃 dock 恢复正确布局：`LiquidGlassTabBar` 按包设计的全屏自放置 overlay 用法放置（作为首页 shell Stack 的直接 child，bottom 间距走 margin 参数），三个条目在玻璃胶囊内等距排布，点击热区与视觉位置重合，滚动收起/浮现交互保持。

## Requirements

### R1 放置方式修正

验收：A1

- `_LiquidGlassDock` 不再用 `SizedBox(width, height: 64)` + 外层 `Align` + `Padding` 包裹 `LiquidGlassTabBar`。
- `LiquidGlassTabBar` 直接渲染，bottom 间距通过 `margin: EdgeInsets.only(bottom: dockBottom)` 传入（dockBottom = max(safeArea, 12) + 24；包内在 Impeller 分支自动叠加 `MediaQuery.padding.bottom`）。
- 说明：Impeller + impellerOnly pill 模式下 bar 是全屏自放置 overlay，任何外层尺寸约束都会导致内部 `Positioned.fill` 层错乱——这是本次错位的根因。

### R2 hit-zone 对齐

验收：A2

- 语义化 hit-zone 层按 bar 的实际几何定位：底部对齐、宽度与 bar 一致（min(screenWidth - 48, 320)）、高度 64、bottom 间距与 bar 的有效 bottom 间距一致。
- 保证 home-hit-zone-* 测试 key 与 Semantics 节点位置和视觉一致。

### R3 交互保持

验收：A3

- 滚动收起/浮现（`_dockHiddenNotifier` + AnimatedSlide/Opacity 200ms + IgnorePointer）逻辑不变。
- tab 切换恢复 dock 可见的行为不变。

### R4 质量门槛

验收：A4

- `flutter analyze` 无新增告警；`flutter test` 全部通过。

## Scenario: 首页 dock 正确布局

- WHEN 应用启动进入首页
- THEN 底部中央呈现完整液态玻璃胶囊 dock，条目无错位，选中指示落在选中条目上
- 验收：A1

## Scenario: 点击与视觉一致

- WHEN 用户点击任一条目
- THEN 对应 tab 切换，点击区域与渲染区域重合
- 验收：A2

## Scenario: 滚动交互不变

- WHEN 下滚/上滚
- THEN dock 隐藏/浮现行为与修复前一致
- 验收：A3
