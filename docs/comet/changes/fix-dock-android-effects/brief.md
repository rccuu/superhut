# 目标

修复安卓真机上首页底部 dock "切换动画、选中图标、液态玻璃全部无效果"的问题。用户实测：位置已正确，但点击无动画、选中态不变化、无玻璃质感；同一台设备安装上游 cc2562/superhut 构建的包可以正常显示液态玻璃。

根因（已调查确认，代码级）：

1. **点击/手势被 hit-zone 层拦截（主因）**：上一轮修复为对齐点击热区，在 bar 之上叠了一层 `Positioned` + `Row` + `GestureDetector(behavior: HitTestBehavior.opaque)`。opaque 命中后事件不再向下传递，`LiquidGlassTabBar` 内部的 InkWell、按压手势、pill 的动画/滑动/形变全部收不到触摸——表现为"点了就跳转，但没有切换动画、选中图标无过渡、pill 不动"。pill 不动的玻璃条视觉上也只剩静态磨砂，用户感知为"液态玻璃没效果"。
2. 液态玻璃的折射与 pill 动画共用同一条 Impeller 管线；手势被拦截时整条管线不会被驱动，因此三个症状同时出现，与用户描述完全吻合。

修复方案：

- hit-zone 层改为纯语义/测试锚点：整层 `IgnorePointer`，移除 `GestureDetector` 与 `onTap`，`home-hit-zone-*` key 移到 `Semantics` 上。
- 所有点击完全交给 `LiquidGlassTabBar` 自己的手势层（InkWell + pill 拖动/按压），恢复切换动画、选中态过渡与玻璃交互。
- 相应更新 widget 测试：不再通过 tap hit-zone 切换，改为 tap bar 内部的可点击区域（`LiquidGlassTabBar` 内的 InkWell）驱动切换，且 key 查找继续可用。

验证手段说明：本机安卓模拟器（API 35, arm64, OpenGLES Impeller）无论 release/debug、5.1.0/5.2.0、host GPU/swiftshader 均渲染黑屏，无法作为视觉对照环境（已排除包版本因素）；iOS 模拟器可正常渲染但无法验证安卓手势差异。因此本轮以代码级根因修复 + widget 测试 + 用户真机复验为准。

# 范围

## 目录结构

### 修改

- lib/home/homeview/view.dart — `_LiquidGlassDock` 的 hit-zone 层改为 IgnorePointer + 纯 Semantics（key 移到 Semantics），删除 GestureDetector/onTap。
- test/widget_test.dart — 点击切换改为 tap bar 内部 InkWell（或按 hit-zone 坐标 tapAt），保留位置断言。

### 明确不建

- 不改动普通玻璃令牌与 pill 样式参数 — 视觉参数与上游一致，非本次问题。
- 不降级/升级 liquid_glass_easy — 已用 5.1.0/5.2.0 对照排除版本因素。

# 非目标

- 不改动 iOS 上的行为（iOS 模拟器已确认动画与玻璃正常）。
- 不改动滚动收起/浮现逻辑。
- 不改动三个 tab 内容页。

# 验收示例

- A1: 安卓真机上点击 dock 三个条目，pill 指示器带弹簧移动动画到达目标条目，选中图标切换为选中样式（primary 色 + selectedIcon），点击时 pill 有按压抬升反馈。
- A2: 安卓真机上 dock 呈现液态玻璃质感（玻璃胶囊 + 选中 pill 折射），与上游包在同一设备的观感一致。
- A3: dock 位置与尺寸保持上一轮修复后的正确布局；滚动收起/浮现不变。
- A4: `flutter analyze` 无新增告警；`flutter test` 全部通过（含改写后的点击切换测试）。