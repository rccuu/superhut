# 任务

## 1. 复现与证据

- [x] 1.1 iOS 模拟器测量当前 bar 底缘/顶缘位置（已测得：底缘 89pt、顶缘 157pt，见 proposal.md）

## 2. 实现

- [x] 2.1 `lib/home/homeview/view.dart` 的 `_LiquidGlassDock`：`dockBottom` 改为固定 12pt 视觉留白，不再计入 safe-area；hit-zone 底部定位改为 `12 + bottomInset`

## 3. 验证

- [x] 3.1 iOS 模拟器截图复测：bar 底缘约 46pt、顶缘约 110pt，内容遮挡明显减少
- [x] 3.2 `flutter analyze` 无告警
- [x] 3.3 `flutter test` 全部通过
