# 设计

## 改动点

`_LiquidGlassDock.build`：

```dart
// 视觉留白固定 12pt；safe-area 由 LiquidGlassTabBar 内部叠加，
// 这里不再重复计入。
const dockMargin = 12.0;
final hitZoneBottom = dockMargin + bottomInset;
```

- `margin: EdgeInsets.only(bottom: dockMargin)`
- hit-zone `bottom: hitZoneBottom`（= 12 + safeArea），高度保持 64。

## 预期几何（iPhone 16 Pro，safe-area 34pt）

- bar 底缘距屏幕底 = 12 + 34 = 46pt（原 89pt，降低 43pt）
- bar 顶缘距屏幕底 = 46 + 64 = 110pt（原 157pt）
- 与旧版 `_ClassicTabBar` 顶缘 ~102pt 基本一致

## 失败路径与验证

- 若某些设备 `MediaQuery.padding.bottom` 为 0（无 home indicator），底部间距 = 12pt，bar 贴底但仍有留白；可接受。
- 验证：iOS 模拟器截图测量 bar 底缘间距 ≈ 46pt、顶缘 ≈ 110pt；`flutter analyze` 无告警；`flutter test` 全过（hit-zone 位置断言仍应通过，因 rect 相对屏幕底部仍在 740 以下）。
