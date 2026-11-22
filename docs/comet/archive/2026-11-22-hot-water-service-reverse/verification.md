---
generated_from_state_version: 6
---

# 验证

## 当前结果

- 结果: **验收通过，需要你确认**
- 验证情况: **已在实现会话中完成验收**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-11-22T14:53:03.128Z
- 摘要: 八项验收全部通过（Verifier 独立复核）：A1-A4 逆向报告与 24 个脱敏证据文件入 docs/ 且敏感值校验 CLEAN；A5 服务端 message 透传有 widget 级 SnackBar 断言；A6 忙码+传输异常重试（2 次、2s/4s 退避、会话失效重建）12 项单测覆盖；A7 水务超时 3s→15s/5s 带实测依据；A8 analyze 无问题、水务 55 项测试复跑通过（Builder 阶段全量 754 项通过）。未发现遗漏或未经授权的范围缩减。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1：分析报告完整记录开关热水链路每一步（鉴权换会话、设备列表、开阀、关阀、状态查询）的 URL、方法、关键请求头、请求体、响应结构与错误码，每步至少一处真实证据（抓包记录或 H5 JS 快照）支撑。 | 报告 §2.1-§2.3 记录鉴权换会话/设备列表/开阀/关阀/状态查询每步 URL、方法、请求头、请求体、响应结构与错误码；docs/water_hot_reverse_evidence/ 24 个文件含 zdRedirect 302 头、getOftenUsetermList、termcodeOpenValve×3（含两次失败一次成功）、endUse×2、selectCloseDeviceValve×2 真实响应与 3 页 HTML/5 个官方 JS 快照；每步均有真实证据文件支撑 |
| A2 | passed | brief.md | A2：分析报告给出「开不了水 / 关不了水」的根因清单，每条标注证据来源（抓包 / H5 JS / 官方行为实测）与置信度（实锤 / 高度可能 / 存疑）。 | 报告 §3 根因清单 R1-R8，每条标注证据来源（抓包文件/官方 JS/实测）与置信度（实锤/高度可能/存疑）；R1 终端忙为实锤（三次开阀响应 CORE35108→CORE35108→000000） |
| A3 | passed | brief.md | A3：分析报告给出 superhut 现有实现与官方行为的差异清单，以及每项差异对应的稳定性改进方案（含优先级）。 | 报告 §4 差异清单 7 项，每项含官方行为对照、改进方案与 P0/P1/P2 优先级；P0 三项与 P1 会话缓存已实现，其余记录理由 |
| A4 | passed | brief.md | A4：报告与证据文件提交入 git（docs/ 下），路径在报告开头列明。 | 报告开头列明证据目录；.gitignore 增加两条例外使报告与 docs/water_hot_reverse_evidence/（24 文件）入 git；Verifier 独立 grep 校验 token/openid/accno/姓名全部 CLEAN |
| A5 | passed | brief.md | A5：`startHotWater`/`stopHotWater` 失败时，用户提示包含服务端返回的具体 `message`（不再只有固定通用文案）；服务端未返回 message 时回退通用文案。 | hotWaterFailureMessage 透传服务端 message，startWater/endWater 均接线；widget 测试（GetMaterialApp 真实渲染）断言 SnackBar 含「无卡开阀失败,当前设备忙,请稍候再试」与「无卡关阀失败,网络或设备通讯异常，请稍候再试」；空 message 回退通用文案有纯函数测试 |
| A6 | passed | brief.md | A6：开阀/关阀对瞬时网络错误（超时、连接类异常）自动重试，重试次数与判定条件在报告中明确，并有单元测试覆盖（成功不重试、可重试错误重试、不可重试错误不重试）。 | runWaterValveOperation：忙码 CORE35106/35108 + 传输类异常重试，最多 2 次，2s→4s 退避；会话失效（资源受限/页面丢失）自动作废缓存重建后重试；12 项单测覆盖成功不重试/可重试/不可重试/退避序列/会话恢复；参数在报告 §4 定稿 |
| A7 | passed | brief.md | A7：水务接口的超时时间依据实测响应时间调整，具体数值写入报告，不再沿用 3 秒默认值。 | kWaterReceiveTimeout=15s、kWaterConnectTimeout=5s 应用于 valve 专用 Dio 与 _buildV8MobileDio；不再沿用 3s；依据（实测 P95≈1.9s、最大 2.89s、5 倍余量）写入报告 §4，常量有测试断言 |
| A8 | passed | brief.md | A8：`flutter analyze`（改动文件范围）与 `flutter test` 通过。 | Verifier 独立重跑改动范围 flutter analyze = No issues found；flutter test 水务范围 55 项全过，Builder 阶段全量 754 项全过 |

## 检查

| Agent 报告的检查 | 结果 | 执行与证据 | 验收项 | 执行原因 |
| --- | --- | --- | --- | --- |
| flutter analyze（改动文件范围） | passed | Verifier 独立重跑：flutter analyze lib/utils/hut_user_api.dart lib/utils/hut_user_api/ lib/pages/water/ test/utils/water_valve_retry_test.dart test/utils/expiring_value_cache_test.dart test/pages/water/ → No issues found! (ran in 2.7s) | A8 | — |
| flutter test（水务范围复跑） | passed | Verifier 独立重跑 flutter test test/utils/… test/pages/water/ → +55: All tests passed!（Builder 阶段全量 flutter test 754 项通过记录在 builder 交接中） | A8, A5, A6, A7 | — |
| 证据脱敏独立校验 | passed | Verifier 以 idToken 前 40 位/openid 前 20 位/accno/姓名分别 grep docs/water_hot_reverse_evidence/ 与报告 → 全部 CLEAN；证据目录 24 个文件在位 | A4 | — |
| 实现与验收逐项核对 | passed | git diff 审查：kWaterReceiveTimeout=15s 应用于 valve 专用 Dio（hut_user_api_water.dart:202）与 _buildV8MobileDio（:173）；忙码集 {'CORE35106','CORE35108'} 与 2s/4s 退避（3 处 retryDelays[index-1]）；hotWaterFailureMessage 在 startWater(:648)/endWater(:692) 接线；会话缓存 ExpiringValueCache<_HutOpenIdSession> + _invalidateOpenIdSession 会话失效重建 | A5, A6, A7 | — |
| 报告完整性核对 | passed | docs/water_hot_reverse_findings.md：§2 链路每步 API 有证据文件对应（A1）；§3 根因 R1-R8 带证据来源与置信度标注（A2）；§4 差异清单带 P0/P1/P2 优先级（A3）；§5 工具备忘记录 Frida evaluateJavaScript 限制与 curl 重放替代方案 | A1, A2, A3, A4 | — |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter analyze（改动文件范围）: passed — 命令 flutter analyze lib/utils/hut_user_api.dart lib/utils/hut_user_api/ lib/pages/water/ test/utils/water_valve_retry_test.dart test/utils/expiring_value_cache_test.dart test/pages/water/，worktree /Users/tune/Develop/GitHub/superhut/.worktrees/hot-water-service-reverse，结果 No issues found! (ran in 2.0s)
- flutter test（全量）: passed — 命令 flutter test，同 worktree，结果 +754: All tests passed!（含水务 55 项与新增 12+4+2 项）
- 证据脱敏校验: passed — grep 校验 docs/water_hot_reverse_evidence/ 无 idToken/openid/学号/姓名命中（python 脚本输出 CLEAN / openid CLEAN）
- 实开实关闭环: passed — curl 重放真实会话：termcodeOpenValve 704536 三次（CORE35108/CORE35108/000000）、selectCloseDeviceValve 有记录形状、endUse 000000、复查无未关阀记录（WATER10030）；响应文件均已入 docs/water_hot_reverse_evidence/
- 已知限制: Frida 17.26.2 的 WKWebView evaluateJavaScript completionHandler（自动与显式 ObjC.Block 包装）在主队列块内均拿不到回调，App 内 H5 流量未直接 netlog；改用官方 App 抓取真实会话后 curl 重放同一 API，API 路径与会话机制与官方 H5 完全一致（报告 §5）。
- 已知限制: 关阀补关路径（waterOpenClose 带 openappid）未实现：正常开→关路径实测空串成功（报告 §4 P1）。
- 已知限制: CORE35106/35108 重试覆盖实测『12 秒内第 3 次成功』场景，极端长时间终端离线仍会失败并透传服务端文案。
- 已知限制: 水务改动未在真机安装 superhut 实测（用户自有验证）；服务端行为证据均为官方会话实测。

## 阻塞项

- **user**: Verification passed; user acceptance is required before Archive. — next: `await-user`

## 风险与跳过的工作

- 官方服务端行为可能随版本变化；busy 码集合来自 2026-11-22 实测，后续新增忙码时需扩充 _kWaterBusyResultCodes。
- Frida 17.26.2 下 WKWebView evaluateJavaScript 回调不可用，App 内 H5 流量未直接抓取，改以真实会话 curl 重放同一 API（报告 §5）。
- 水务改动未在真机安装 superhut 实测，最终体验由用户日常使用验证。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | 八项验收全部通过（Verifier 独立复核）：A1-A4 逆向报告与 24 个脱敏证据文件入 docs/ 且敏感值校验 CLEAN；A5 服务端 message 透传有 widget 级 SnackBar 断言；A6 忙码+传输异常重试（2 次、2s/4s 退避、会话失效重建）12 项单测覆盖；A7 水务超时 3s→15s/5s 带实测依据；A8 analyze 无问题、水务 55 项测试复跑通过（Builder 阶段全量 754 项通过）。未发现遗漏或未经授权的范围缩减。 | 2026-11-22T14:53:03.128Z |



## 结论

八项验收全部通过（Verifier 独立复核）：A1-A4 逆向报告与 24 个脱敏证据文件入 docs/ 且敏感值校验 CLEAN；A5 服务端 message 透传有 widget 级 SnackBar 断言；A6 忙码+传输异常重试（2 次、2s/4s 退避、会话失效重建）12 项单测覆盖；A7 水务超时 3s→15s/5s 带实测依据；A8 analyze 无问题、水务 55 项测试复跑通过（Builder 阶段全量 754 项通过）。未发现遗漏或未经授权的范围缩减。
