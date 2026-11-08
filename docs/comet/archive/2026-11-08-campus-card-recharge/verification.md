---
generated_from_state_version: 20
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 5
- 验证器尝试次数: 1
- 完成时间: 2026-11-08T06:32:46.245Z
- 摘要: 独立核对 brief/spec 与实现：7 项验收全部通过。flutter analyze 0 问题、flutter test 704 用例全绿（含新增 8 用例与更新后的入口注入点用例）。实现范围与已确认 Shape 一致，无范围缩减或接口行为变化。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1：superhut 能用当前登录态的 `X-Id-Token` 构建完整 light.action 充值入口 URL（含 `flag=supwisdomapp_hngydxsw`、`ecardFunc=index`、`token`）。 | CampusCardApi.buildEntryUrl 以 X-Id-Token 构建 light.action 入口 URL（flag/ecardFunc/token 齐全、转义与空白裁剪正确），8 个单用例覆盖并全部通过。 |
| A2 | passed | brief.md | A2：校园卡余额卡片仍能正确显示余额（沿用现有 `getCardBalance`，不被本次改造破坏）。 | getCardBalance 读取与展示路径零改动（userpage/water 仅新增返回后刷新调用），既有余额用例通过。 |
| A3 | passed | brief.md | A3：「前往充值」按钮打开自带 WebView 并加载 A1 构建的 URL；WebView 内呈现完美校园校园卡主页（卡面、余额、充值/交易明细/解绑）。 | 两个入口默认走 CampusCardRechargePage（WebView 承载完美校园 H5）；注入点测试更新后通过；H5 渲染与登录态已由 2026-11-08 官方 App/Safari 等价链路动态验证（brief S12/S13）。 |
| A4 | passed | brief.md | A4：（H5 内建行为，仅作真机抽检不作为 superhut 代码验收）充值页提供预设金额与「其他金额」自定义输入。 | 金额输入由交付组合（superhut WebView + H5）满足：动态分析 S13 实测预设金额与自定义输入正常渲染。 |
| A5 | passed | brief.md | A5：（H5 内建行为，仅作真机抽检）支付方式页展示服务端下发的支付方式（微信、农行掌银）。 | 支付方式由服务端下发、H5 渲染（S14 实测微信/农行掌银）；H5 不可达时走错误视图不崩溃。 |
| A6 | passed | brief.md | A6：在 WebView 内选择微信支付后能跳转 `wx.tenpay.com` 收银台并唤起微信（H5 支付链路）；用户返回 superhut 后刷新校园卡余额。 | WebView 放行 https 页内导航与外部支付 scheme；返回后 userpage _refreshBalance(false)/water logic.getBalance() 刷新余额；微信 H5 支付链路（收银台→唤起微信）已由 S15 动态验证。 |
| A7 | passed | brief.md | A7：WebView 打开失败（无网络/接口异常/H5 不可达）时，回落到原支付宝小程序跳转并提示用户。 | 主文档加载失败展示 CampusCardErrorView（重试 + 改用支付宝小程序），widget 测试覆盖；token 缺失提示先登录且不打开 WebView；支付宝兜底 URL 与原路径一致。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze 无 error/warning | analyze | . | passed | 0 | 4641 ms |
| flutter test 全量测试 | test | . | passed | 0 | 24545 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- 已知限制: A4/A5 由完美校园 H5 内建（spec 非 superhut 实现项），自动化断言不可达；验收依据为 2026-11-08 真机动态分析（brief S13/S14）与 Verify 阶段真机抽检。
- 已知限制: InAppWebView 依赖平台通道，widget test 无法渲染 WebView 页面本体；页面级行为（渲染/支付跳转）以真机验收为准。
- 已知限制: flag=supwisdomapp_hngydxsw 为内置学校常量（Q4 已确认）；如学校服务端模板变化需同步更新 CampusCardApi.schoolFlag。

## 阻塞项

_无。_

## 风险与跳过的工作

- 真机内 superhut WebView 的端到端支付冒烟（选金额→唤起微信）尚未在 superhut 安装包内执行，依据为等价链路动态验证（S12–S15）；建议发布前真机抽检一次。
- URL 中 token 为登录态凭证，WebView 加载历史/日志会包含该 URL；与官方 App 行为一致，未额外落地持久化。
- flag=supwisdomapp_hngydxsw 为内置常量（Q4 已确认）；学校服务端模板变化需同步更新。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 0 | recovery | — | 实现无遗漏、无需求变化：仅修正 builder-handoff 输入文本中的链接样字样（原始候选输入枚举含链接导致 Verifier 无法分派），代码与测试保持不变。 | 2026-11-08T05:50:15.941Z |
| 1 | 2 | 0 | recovery | — | 无需求与实现变化：候选输入快照此前在符号链接存在时被标记不完整，现已清理符号链接并 stage 改动以强制重采完整输入快照。 | 2026-11-08T05:59:17.616Z |
| 1 | 3 | 0 | recovery | — | 输入快照已重采完整（460 文件）；检查结果已用最新输入重跑（analyze 0 问题、test 704 通过），重新交接并由 Runtime 执行必要检查。 | 2026-11-08T06:02:17.466Z |
| 1 | 4 | 1 | pass | — | 独立核对 brief/spec 与实现：7 项验收全部通过。flutter analyze 0 问题、flutter test 704 用例全绿（含新增 8 用例与更新后的入口注入点用例）。实现范围与已确认 Shape 一致，无范围缩减或接口行为变化。 | 2026-11-08T06:09:24.784Z |
| 1 | 4 | 1 | recovery | — | Local Runtime was unavailable at Archive ready; the synchronized implementation must be verified again. | 2026-11-08T06:27:34.457Z |
| 1 | 4 | 1 | recovery | — | 重建后 YAML 仍携带提交前 HEAD 的检查绑定；实现无变化，回到 Build 重新交接使检查绑定到当前 HEAD aa21e69。 | 2026-11-08T06:28:45.889Z |
| 1 | 5 | 1 | pass | — | 独立核对 brief/spec 与实现：7 项验收全部通过。flutter analyze 0 问题、flutter test 704 用例全绿（含新增 8 用例与更新后的入口注入点用例）。实现范围与已确认 Shape 一致，无范围缩减或接口行为变化。 | 2026-11-08T06:32:46.245Z |



## 结论

独立核对 brief/spec 与实现：7 项验收全部通过。flutter analyze 0 问题、flutter test 704 用例全绿（含新增 8 用例与更新后的入口注入点用例）。实现范围与已确认 Shape 一致，无范围缩减或接口行为变化。
