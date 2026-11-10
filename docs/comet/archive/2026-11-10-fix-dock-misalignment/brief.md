# 目标

修复首页底部 dock（液态玻璃 LiquidGlassTabBar）在真机/模拟器上的整体错位：dock 图标与胶囊错乱、bar 位置不对，用户报告"选项栏直接全部错位了，没有弄好"。已通过模拟器截图（iPhone 16 Pro, iOS 18.6）与包源码定位根因。

根因（已调查确认）：

- `LiquidGlassTabBar` 在 Impeller + `pillStyle.mode: impellerOnly` 下走 `_glassPillBar` 分支，包文档明确它是"full-screen overlay that places itself"——自放置为全屏 overlay（`Align(bottomCenter)` + `Padding(bottom: margin.bottom + safeArea)`），margin/safe-area 全部自管。
- 现有 `_LiquidGlassDock` 把它包在 `SizedBox(width: min(width-48,320), height: 64)` 里，外层还有 `Align(bottomCenter)` + `Padding(bottom: dockBottom)`。全屏自放置 overlay 被钳制进 320×64 小盒子：内部 `Positioned.fill` 图标层、放置层全部错乱，margin.bottom=24 的 padding 把 62 高的 bar 顶出 64 高的盒子——即用户看到的错位。
- hit-zone 层（`Positioned.fill` Row）也因此与 bar 实际渲染位置对不上，点击热区同样错位。

修法（照包文档用法）：

- `LiquidGlassTabBar` 直接作为首页 shell `Stack` 的最后 child，不套 SizedBox/Align/Padding；bottom 间距传给它自己的 `margin: EdgeInsets.only(bottom: ...)`（包内自动叠加 safe-area bottom inset，见 `_glassPillBar` 的 `bottomInset: MediaQuery.padding.bottom`）。
- hit-zone 层改为与 bar 自放置几何一致的对齐层（底部对齐、固定宽高），确保点击热区与渲染位置重合。
- 外层 `AnimatedSlide/AnimatedOpacity/IgnorePointer` 滚动收起/浮现逻辑保留不变。

# 范围

## 目录结构

### 修改

- lib/home/homeview/view.dart — `_LiquidGlassDock.build` 重写放置方式（去 SizedBox/Align/Padding 包裹，bar 直接自放置 + margin 传间距）；hit-zone 层改为按 bar 几何对齐的定位层。

### 明确不建

- 不改动 glass_theme.dart 玻璃令牌 — 视觉参数（颜色/边光/折射）不是本次问题。
- 不改动滚动收起/浮现逻辑 — 交互行为正常，只是 dock 本体错位。

# 非目标

- 不调整玻璃视觉参数（tint/specular/glow/refraction）。
- 不改动三个 tab 内容页。
- 不改动 `AppGlassPerformanceScope` lite 体系。

# 验收示例

- A1: iPhone 模拟器（iPhone 16 Pro, iOS 18.6）上首页底部 dock 呈现完整液态玻璃胶囊（宽约 320、高 64、底部居中悬浮、含 safe-area 间距），三个条目（课表/功能/我的）图标与标签在胶囊内等距排布、无错位；选中项胶囊指示正确落在选中条目上。
- A2: 点击 dock 三个条目均能正确切换 tab；点击位置与视觉位置一致（hit-zone 对齐）。
- A3: 下滚 dock 收起、上滚浮现行为保持不变。
- A4: `flutter analyze` 无新增告警；`flutter test` 全部通过。
