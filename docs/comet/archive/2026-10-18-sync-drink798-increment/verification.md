---
generated_from_state_version: 8
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-10-18T10:56:36.071Z
- 摘要: 8/8 验收项通过：A1-A5、A7、A8 在候选 8d5ad4c 首轮即通过；A6 经修复提交 abec023 补齐扫码链路接线并有测试。flutter analyze 无问题，全量 flutter test 通过（Runtime 回执 +684 全绿）。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1：点击「开始接水」成功路径下，发往 `/api/v1/dev/start` 的查询参数中 `ptype` 为 `91`；其余参数仍为 `did`、`upgrade=true`、`args=`（空串）、`rcp=false`、`cnt=1`，无 `stype`、无 `sign`；有单元测试逐字断言。 | drink_api_request_test.dart 逐字断言 dev/start URL 与参数集：ptype=91、六键、无 stype/sign |
| A2 | passed | brief.md | A2：钱包支付（`ptype=91`）返回失败且失败码非 `-99` 时，自动以 `ptype=21` 再发一次 `dev/start`；第二次成功则进入接水态并只重试一次（出现 `[91, 21]` 两次请求）；`code == -99` 时不重试（只有一次请求）；有按分支断言请求序列的测试。 | 回退序列 [91,21] 恰一次；-99 只发一次；回退再拒无第三次，三条分支测试齐备 |
| A3 | passed | brief.md | A3：点击开始时的设备状态预检按三态分支：`device.status == 0`（离线）不发开始请求并提示设备离线；`gene.status == 98`（禁用）不发开始请求并提示联系管理员；链路在线但 `gene.status` 既非 99 也非 98（占用中）不发开始请求、同步进入可结算态并开始状态轮询；状态查询本身失败（网络异常）时不拦截，仍发开始请求；有覆盖四条分支的测试。 | 离线/禁用/占用三分支均断言 startCalls==0，占用进可结算态并轮询；预检失败不拦截断言 startCalls==1 |
| A4 | passed | brief.md | A4：`GET /ui/app/dev/status` 的查询参数恰为 `did` 与 `more=false`，不含 `promo`、不含 `sign`；响应按 `device.status` 与 `device.gene.status` 解析为离线 / 禁用 / 空闲 / 运行中四类判定；有单元测试断言参数集与三类响应解析。 | deviceStatus 参数恰为 did+more=false 无 promo/sign；四类状态解析有测试 |
| A5 | passed | brief.md | A5：`GET /dev/end` 的查询参数为 `did` 与 `rcp=false`；`GET /dev/favo` 的 `remove` 以 `1`（取消收藏）/`0`（收藏）上线；有单元测试断言两个请求的线上形状。 | dev/end 恰 did+rcp=false；favo remove 上线 1/0 |
| A6 | passed | brief.md | A6：扫码添加设备时，二维码末段先经 `GET /qr/use?id=<末段>` 换取真实设备 ID：解析出设备 ID 时以该 ID 收藏；响应无设备或请求失败时回退二维码末段收藏；二维码末段为空时不发起任何请求；有覆盖三条路径的测试。 | 首轮报告的缺线已修复（abec023）：新增 FunctionDrinkLogic.addDeviceByQrCode 且 view.dart 扫码链路改走该链路；三条新测试覆盖换 ID 成功/空解析回退/空码零请求；performance_boundaries 形状断言更新后全绿 |
| A7 | passed | brief.md | A7：状态轮询自开始起 30 分钟后自动停止，不再发起状态查询；既有代际丢弃、连续空闲计数与结算即停轮询的行为不变；有单元测试断言轮询停止。 | debugPollStartedAtOverride 拨回 31 分钟断言轮询停止；既有代际/结算停轮询测试仍通过 |
| A8 | passed | brief.md | A8：798 之外的页面与全局主题文件未被修改；`flutter analyze` 无告警，`flutter test` 全部通过（含按新接口形状更新的既有测试）。 | git show --name-only 仅 lib/pages/drink/** 与 test/**（runtime 修复提交含 test/core/ui/performance_boundaries_test.dart，仍属测试边界；798 产品代码之外无修改）；flutter analyze 无问题；flutter test 全量通过 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze | analyze | . | passed | 0 | 5907 ms |
| flutter test | test | . | passed | 0 | 21250 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter analyze: passed — No issues found! (ran in 6.2s)
- flutter test: passed — 全仓库 All tests passed；drink 模块 logic 56 项 + api 24 项 + 页面/UI 测试全绿
- flutter test test/pages/drink/: passed — All tests passed
- 已知限制: 真机钱包余额不足→支付宝回退的实际服务端行为无法在本环境复现，依据为请求序列测试与 drink_798 上游实测（61c5e076）
- 已知限制: qr/use 的真实服务端响应形状以 drink_798 吸收的上游实现为准，未能本机实测

## 阻塞项

_无。_

## 风险与跳过的工作

- 真机钱包不足→支付宝回退与 qr/use 真实服务端行为未在本环境验证，依据为请求序列测试与 drink_798 上游实测（brief 已声明为已知限制）

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | 8/8 验收项通过：A1-A5、A7、A8 在候选 8d5ad4c 首轮即通过；A6 经修复提交 abec023 补齐扫码链路接线并有测试。flutter analyze 无问题，全量 flutter test 通过（Runtime 回执 +684 全绿）。 | 2026-10-18T10:56:36.071Z |



## 结论

8/8 验收项通过：A1-A5、A7、A8 在候选 8d5ad4c 首轮即通过；A6 经修复提交 abec023 补齐扫码链路接线并有测试。flutter analyze 无问题，全量 flutter test 通过（Runtime 回执 +684 全绿）。
