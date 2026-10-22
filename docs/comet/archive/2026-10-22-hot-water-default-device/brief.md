# 目标

宿舍热水页面支持「固定默认设备」：设备较多的用户可以把某一台设备设为默认，之后每次打开宿舍热水页面都自动选中这台，不必每次手动切换。

用户可见结果：在「选择设备」列表里能把某一台设备显式设为默认（也能取消）；设置后重新进入页面仍自动选中该设备并在当前设备卡片上标注「默认」。

# 范围

## 目录结构

### 新建

- `lib/pages/water/default_device_store.dart` — 默认设备号（`poscode`）的本机读写，SharedPreferences 承载，带可注入抽象
- `docs/comet/changes/hot-water-default-device/specs/hot-water-default-device/spec.md` — 本 capability 的完整目标规格

### 修改

- `lib/pages/water/state.dart` — 新增默认设备号响应式状态
- `lib/pages/water/logic.dart` — 注入并调用默认设备存储；`_applyDeviceList` 按默认设备号解析选中下标；删除设备时清理失效默认；新增设为默认 / 取消默认入口
- `lib/pages/water/widgets/water_page_widgets.dart` — `WaterDeviceSelectionSheet` 每行新增「设为默认」星标入口；`HotWaterCurrentDeviceCard` 在选中即默认时显示「默认」标记
- `lib/pages/water/view.dart` — 串接「设为默认 / 取消默认」回调与「默认」标记传参
- `test/pages/water/function_hot_water_logic_test.dart` — 新增默认设备选中、持久化、回退、删除清理用例
- `test/pages/water/function_hot_water_page_test.dart` — 新增选择列表「设为默认」交互与「默认」标记用例

### 删除

（无）

### 明确不建

- 不做设备备注 / 改名（设备名沿用服务端下发的 `posname`）
- 不改动设备添加 / 删除流程本身，只补「删除后清理失效默认」
- 不做设备分组、排序、拖拽等列表组织能力
- 不引入新的持久化方案（沿用 SharedPreferences）

## Source coverage

不适用：需求来自用户口头描述（本轮消息），无文件 / 链接 / 附件类需求来源，不触发源文档完整覆盖模式。仓库现状由 Agent 静态调查得出，见 Decisions。

# 非目标

- 不改变「检测到有设备尚未关闭」的强制选中与提示行为——未关闭设备仍然优先于默认设备
- 不改变开始 / 结束热水的接口、请求参数与提示文案
- 不影响饮水（惠生活798）设备列表行为
- 不做跨账号的默认设备同步或云端持久化（设备号只存本机）
- 不做「默认设备余额/状态」的独立展示区

# 验收示例

- Scenario: 设备列表加载后，本机保存的默认设备号在返回列表中时，页面自动选中该设备，且当前设备卡片标注「默认」。
- Scenario: 本机没有保存过默认设备时，保持现状选中列表第一台设备。
- Scenario: 在选择设备列表中点击某台设备的「设为默认」后，该选择被持久保存，退出并重新进入宿舍热水页面仍自动选中它。
- Scenario: 在选择设备列表中再次点击已设为默认的设备可取消默认；取消后重新进入页面回到选中列表第一台。
- Scenario: 检测到有设备未关闭时，仍优先选中该未关闭设备并给出提示，不被默认设备覆盖。
- Scenario: 删除已设为默认的设备后，本机默认偏好被清理，重新进入页面选中列表第一台，且不报错、不残留旧运行态。
- Scenario: 默认设备已被学校侧解绑（不在返回列表中）时，回退选中列表第一台，不崩溃、不残留旧运行态。

# Constraints and invariants

- 默认设备按设备号（`poscode`）存储，不存列表下标：设备列表顺序由服务端下发且随新增设备变化（`getHotWaterDevice` 每次反向构造结果）。
- 沿用项目现有 SharedPreferences 存储与 `logic.dart` 已有的依赖注入风格；`_applyDeviceList` 中 `await Future.wait([_refreshOpenDeviceState(), _refreshBalanceValue()]);` 一行保持原样。
- 不得破坏 `test/core/ui/performance_boundaries_test.dart` 对 `lib/pages/water/*` 的既有断言：方法边界与相邻注释锚点、`_isDisposed` 前置/后置检查、`_applyOpenDeviceState` 的集中处理、页面只用 `Obx` 响应式（不得引入 `update();` 或 `GetBuilder`）。
- 页面关闭（`_isDisposed`）后返回的迟到的设备列表 / 默认设备读取结果不得写入状态。
- 存储读写失败不阻塞页面：读取失败按「无默认」处理；写入失败给用户可读提示。
- 与「检测到设备未关闭」的既有顺序不变：`_applyDeviceList` 先按默认选中，随后 `_refreshOpenDeviceState` 仍可覆盖为未关闭设备。

# Decisions

- D1 固定设备按 `poscode` 存储而非列表下标。理由：设备列表顺序由服务端下发且每次反向构造（`hut_user_api_water.dart:59` 的 `for (var index = rawDevices.length - 1; ...)`），下标跨会话不稳定。【Agent 静态调查得出，已随需求确认】
- D2 交互形态：在「选择设备」列表的每行增加星标入口。点行 = 本次选择（沿用原行为，选中后关闭列表）；点星标 = 设为 / 取消默认（不改变本次选择、不关闭列表）。【由用户选择「显式设为默认」得出】
- D3 手动选择设备不写入默认，只有显式点「设为默认」才写入。理由：用户要的是「固定」，临时切换不应改写默认。【由用户选择「显式设为默认」得出】
- D4 「检测到有设备未关闭」仍优先于默认设备。理由：避免热水和余额白流，与现状行为一致。【用户明确选择「未关闭设备优先」】
- D5 默认设备本机按设备号全局存储，不按 HUT 账号分桶；跨账号时该设备号不在对方列表中，自然回退到第一台。理由：保持实现简单，回退路径已覆盖全部跨账号场景。【Agent 设计选择】
- D6 当前设备卡片在选中设备即默认设备时显示「默认」标记，给用户固定生效的可见反馈。【Agent 设计选择】
- D7 工作区使用独立 worktree（`.worktrees/hot-water-default-device`），目标分支 `main`。【用户明确选择】

# Open questions

（无未决项。固定方式、未关闭设备冲突处理、工作区隔离三项决定已由用户在需求澄清中确认；其余为实现选择，无 `[blocking]`。）

# Verification expectations

- `flutter analyze` 无新增 warning / error。
- `flutter test` 全量通过，重点为 `test/pages/water/` 与 `test/core/ui/performance_boundaries_test.dart`。
- 新增 widget 用例覆盖：默认设备自动选中、「设为默认」后持久化并在卡片标注、取消默认回退、删除默认设备后清理。
