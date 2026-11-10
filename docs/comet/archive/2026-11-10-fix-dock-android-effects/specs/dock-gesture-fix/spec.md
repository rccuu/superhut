# 安卓 Dock 手势拦截修复

## Outcome

安卓真机上 dock 的点击手势直达 `LiquidGlassTabBar` 内部手势层：pill 弹簧移动动画、按压形变、选中图标过渡与玻璃交互全部恢复；hit-zone 层降级为纯语义/测试锚点，不再拦截任何触摸。

## Requirements

### R1 hit-zone 不再拦截触摸

验收：A1

- `_LiquidGlassDock` 中 hit-zone 层整层 `IgnorePointer`，移除 `GestureDetector(behavior: opaque)` 与 `onTap`。
- `home-hit-zone-*` ValueKey 移到 `Semantics` widget 上；`Semantics` 继续提供 button/selected/label 语义。

### R2 bar 手势全权接管

验收：A1, A2

- 点击/拖动全部由 `LiquidGlassTabBar` 内部 InkWell 与 pill 手势层处理（InkWell onTap、pill 按压抬升、超 10px 拖动 scrub、落点 wobble 均为包内行为）。
- 视觉与上游包在同一设备的液态玻璃观感一致。

### R3 布局与滚动行为不变

验收：A3

- dock 放置方式（全屏自放置 overlay + margin）保持上一轮修复结果。
- 滚动收起/浮现逻辑不变。

### R4 测试与质量

验收：A4

- `test/widget_test.dart`：tab 切换测试改为 tap `LiquidGlassTabBar` 内部 InkWell（`find.byType(InkWell)` 定位于 dock 区域），hit-zone key 继续用于位置断言。
- `flutter analyze` 无新增告警；`flutter test` 全部通过。

## Scenario: 点击切换带动画

- WHEN 用户点击 dock 任一条目
- THEN pill 弹簧移动到目标条目、选中图标过渡为选中样式，页面切换
- 验收：A1

## Scenario: 玻璃质感恢复

- WHEN dock 显示
- THEN 呈现液态玻璃胶囊与选中 pill 折射，与上游观感一致
- 验收：A2

## Scenario: 布局不变

- WHEN 应用启动
- THEN dock 位置正确、滚动收起/浮现行为不变
- 验收：A3
