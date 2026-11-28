# 目标

把第四轮热水安全研究（hut-water-research 仓库 `hot-water-billing-abuse-chains`，已归档）的可回流结论做进 superhut 热水页：关阀失败的自动关阀兜底提示、未关阀设备补关路径、CORE35104 重复开阀特判。不改变任何 API 协议形状与服务端交互语义。

## 背景（研究结论摘要）

1. **关阀接口可长时间故障**（第四轮活体事件）：开阀成功后 `endUse`/`selectCloseDeviceValve` 连续 40 次/43 分钟失败（「服务异常」→ HTTP 500）。期间用户无法主动关阀，资金敞口仅由服务端强制限额兜底：`maxtimelimit=30 分钟`（终端到点自动关阀）+ `maxfarelimit`（金额上限）。二者由服务端下发并强制（第一轮 openparam + 本轮设备列表字段），客户端不可覆盖。
2. **补关路径需要 `openappid`**（第一轮 P1 遗留）：官方「未关阀设备」页补关时 `endUse` 携带开阀记录 id；该 id 来自 `selectCloseDeviceValve` 响应 `data[].id`。superhut 现状：`checkHotWaterDevice` 只返回 poscode 列表（丢弃 id），`stopHotWater` 恒传 `openappid:''`（仅对当前会话开阀有效）。
3. **重复开阀返回 CORE35104**（第二轮 F-04 实测）：已开阀状态下再次开阀返回 CORE35104「无卡开阀失败,网络或设备通讯异常」（耗时约 5.2s），与 i18n 表声称的 CORE35107 不符；官方客户端会把它当"忙"误导用户重试。

# 范围

## 目录结构

### 修改 `lib/utils/hut_user_api/hut_user_api_water.dart`

- `checkHotWaterDevice` 或新增方法：返回未关阀记录明细（poscode + 记录 id + 开始时间），不再丢弃 id
- `stopHotWater`：新增可选 `openappid` 参数，缺省保持 `''`（现有调用点行为不变）

### 修改 `lib/pages/water/state.dart`

- 保存未关阀记录明细（供 UI 展示与补关）

### 修改 `lib/pages/water/logic.dart`

- `startWater`：CORE35104 特判——收到 CORE35104 时复查未关阀状态，确认设备已开则提示「设备已在用水中」并同步 waterStatus
- `endWater`：关阀失败时提示服务端 30 分钟自动关阀兜底
- `_refreshOpenDeviceState`/`_applyOpenDeviceState`：保存记录明细；未关阀设备不在常用列表时仍可见并可补关

### 修改 `lib/pages/water/widgets/`

- 未关阀设备的补关入口 UI（banner 卡片形式，含设备号与开始时间，点击补关；关阀成功后刷新状态）

# 非目标

- 不实现 scanQRCode/getJssdk/wxpay 等微信 H5 专属面
- 不改动会话引导链（zdRedirect/token）、CORS/HSTS 等服务端问题（无客户端动作）
- 不引入第二~四轮研究报告全文/证据目录到本仓库（研究产物留在 hut-water-research；本 brief 即结论摘要）
- 不改变开阀/关阀请求的协议字段语义（openappid 仅按官方补关路径语义使用）
- 不做支付、充值、预约相关功能

# 约束

- 错误文案遵循现有模式：优先透传服务端 message，无 message 时回退通用文案（`hotWaterFailureMessage`）
- 重试策略沿用 `runWaterValveOperation`（CORE35106/35108 忙码 + 传输瞬态）；CORE35104 不加入自动重试（它是确定性"已开阀"信号，重试无意义）
- Dart 分析零警告（`flutter analyze` 通过）；现有测试行为不回归
- UI 文案中文，与现有页面风格一致

# 验收示例

- A1: 关阀失败（业务失败或异常）时，用户能看到包含「30 分钟自动关阀」兜底含义的提示，而不只是「设备关闭失败，请稍后重试」
- A2: `stopHotWater` 支持可选 `openappid`；未传时行为与现状完全一致（`openappid:''`）
- A3: 未关阀记录（`selectCloseDeviceValve` 返回 data 非空）无论设备是否在常用列表，用户都能在热水页看到未关阀设备（设备号+开始时间）并可通过补关按钮尝试关闭；补关请求携带该记录 id 作为 openappid
- A4: 开阀返回 CORE35104 且复查确认设备已开时，提示「设备已在用水中」而非网络异常，且 waterStatus 同步为已开
- A5: `flutter analyze` 零警告；现有测试全部通过
