# 目标

把「智慧工大」iOS 客户端（`智慧工大_1.1.8.ipa`，`com.supwisdom.hut`）中的校园卡充值能力，逆向分析清楚并接入 superhut，替代当前直接跳支付宝小程序的单一入口，让用户在 superhut 内完成校园卡充值。

# 范围

## 目录结构

### 新建

- `lib/pages/campuscard/` — 校园卡充值页（构建 light.action 链接 + WebView 承载完美校园 H5 + 失败回落）
- `test/campus_card_recharge_test.dart` — URL 构建与回退逻辑单测

### 修改

- `lib/home/userpage/view.dart` — 「校园卡余额」卡片「前往充值」按钮改走新入口
- `lib/pages/water/view.dart` — 热水页「校园卡」入口同步接入

### 删除

- 无

### 明确不建

- 不实现新开普 V8 付款码/消费码（SM2/SM4 密钥交换、`/openplartform/business/*`），那是「消费」而非「充值」
- 不实现 Synpay 聚合支付 SDK（`/berserker-app/ykt/tsm/*`），该 SDK 在本包 `openSynpayQrcode: false` 处于关闭态且无服务端配置
- 不接入农行掌银/微信支付原生 SDK（动态验证：H5 收银台 wx.tenpay.com 走微信 H5 支付，无需原生 SDK；官方 App 原生桥方案反而崩溃）
- 不在 superhut 内重新实现金额输入、支付方式列表、收银台——这些由完美校园 H5 内建提供

## Source coverage

需求来源：用户指定的本地文件 `/Users/tune/Develop/GitHub/superhut/智慧工大_1.1.8.ipa`（iOS App Zip，49 MB）。覆盖边界：用户明确要求逆向「校园卡充值」流程，因此边界为该 IPA 内与校园卡充值、支付方式、支付渠道相关的全部代码、配置与资源。

| 来源条目与位置                                        | 读取状态 | 需要保留的内容                                                                                                  | Spec 位置                       | 验收 ID | 覆盖状态           | 理由或替代关系                                                                                                     |
| ----------------------------------------------------- | -------- | --------------------------------------------------------------------------------------------------------------- | -------------------------------- | ------- | ------------------ | -------------------------------------------------------------------------------------------------------------------- |
| S1：`config.plist` → `SYNPAYQRCODE.openSynpayQrcode`   | complete | Synpay 聚合支付开关为 `false`，无 `SERVER_URL`/`SOCKET_URL`/`APP_ID`/`APP_KEY`                                     | —                               | —       | non-goal           | Synpay SDK 关闭且无服务端配置，无法实现其支付流程                                                                     |
| S2：`config.plist` → `V8QRCODE.openV8Qrcode` = `true`   | complete | V8 虚拟卡开启，`REQUEST_URL=https://kfpt.hut.edu.cn:1243`、`SCHOOL_CODE=786`、`SM4_KEY=NEWCAPECNEWCAPEC`、DES/SM2 密钥 | —                               | —       | non-goal           | V8 是「付款码/消费码」链路，语义为消费不是充值                                                                         |
| S3：二进制 `/openplartform/business/*` 端点集           | complete | `getPaycode`/`queryPaycodeStatus`/`queryBasicInfo`/`offlineCodeapplyBind` 等                                                                       | —                               | —       | non-goal           | 属 V8 付款码链路                                                                                                     |
| S4：二进制 UTF-16 文案「我要充值」「请选择支付方式」     | complete | 「我要充值」属百度语音 demo 语料；「请选择支付方式」属 SWPayList 页面                                                                                | —                               | —       | background         | 均非「自定义金额 + 微信/农行」充值流程                                                                                 |
| S5：二进制 `SWSynPayTypeModel`/`getPayType:finish:`      | complete | 存在服务端下发的支付方式列表模型与查询接口                                                                            | —                               | —       | background         | 但宿主 SDK 关闭，无法触达                                                                                             |
| S6：WeChat SDK 符号集（`WXApi`/`sendAuthRequest`/`qrconnect`） | complete | 仅登录/授权能力，无 `PayReq`/`prepayId`/`partnerId` 等支付符号；`openWechatLogin: false`                              | —                               | —       | non-goal           | 本包不含微信支付能力                                                                                                 |
| S7：农行掌银相关检索（字符串/scheme/SDK）                | complete | 零命中：无「农行/掌银/abcpay」字符串、无 ABC URL scheme、无 ABC SDK                                                    | —                               | —       | non-goal           | 用户描述中的农行掌银支付方式在本包不存在                                                                               |
| S8：`wgt` 内 `My.ecard`/`getECardDataList`               | complete | `GET /v2/personalData/getMyECard`、`GET /v1/personalData/getECardDataList`（注释「获取一卡通相关链接地址」）             | specs/campus-card/spec.md 链接解析 | A1      | covered            | 学校专属校园卡 H5 地址由此接口下发，是充值入口的真实来源                                                               |
| S9：superhut 现状 `getCardBalance()`                    | complete | `GET https://v8mobile.hut.edu.cn/homezzdx/openHomePage`，解析 `span[name=showbalanceid]`                              | specs/campus-card/spec.md 余额展示 | A2      | covered            | 已实现，作为余额展示基线保留                                                                                           |
| S10：superhut 现状充值入口 `_url`                        | complete | `alipays://platformapi/startapp?appId=2019030163398604&page=pages/index/index`                                      | specs/campus-card/spec.md 入口替换 | A3      | covered            | 当前唯一充值入口，本次改造对象                                                                                         |
| S11：完美校园（17wanmei）相关检索                        | complete | 静态零命中；运行时证实完美校园（17wanxiao）为充值服务提供方（见 S12–S15）                                              | —                               | —       | superseded by S12  | 2026-10-20 静态结论「非完美校园」被运行时证据修正：品牌在服务端，IPA 内无字符串                                        |
| S12：WKWebView 加载 `hub.17wanxiao.com/bsacs/light.action?flag=supwisdomapp_hngydxsw&ecardFunc=index&token=<X-Id-Token>` | complete | 充值入口 URL 机制：token 即 portal 的 X-Id-Token（RS512 JWT），Frida WKLOAD 实测捕获                                  | specs/campus-card/spec.md 入口替换 | A3      | covered            | superhut 可直接构建同一 URL；`flag` 为学校专属常量（Q4 待确认内置）                                                    |
| S13：`ecardh5.17wanxiao.com/ecardh5/ecard_t/{index,recharge}.html` | complete | 校园卡主页与充值页（hash 路由 `#/`→`#/payWays?money=N`），余额/卡号服务端渲染                                        | specs/campus-card/spec.md 入口替换 | A3      | covered            | Safari 独立复测完整渲染，证明脱离官方 App 可用                                                                          |
| S14：支付方式页（服务端下发）                            | complete | 微信、农行掌银 两种支付方式（真机截图 + UI 元素树）                                                                    | specs/campus-card/spec.md 支付    | A6      | covered            | 用户原始描述正确；由 H5 内建，superhut 不重新实现                                                                       |
| S15：Safari 点「微信」→ `wx.tenpay.com` 微信 H5 支付收银台  | complete | 纯 WebView 无原生 SDK 完成支付跳转（系统弹「在 WeChat 中打开」）；官方 App 同位置原生桥崩溃                            | specs/campus-card/spec.md 支付    | A6      | covered            | 决定 superhut 采用 WebView 方案的核心证据                                                                               |

# 非目标

- 不实现校园卡「付款码/消费码」（新开普 V8 `/openplartform/business/*` 链路，含 SM2/SM4/RSA 密钥协商）
- 不实现 Synpay 聚合支付（`/berserker-app/ykt/tsm/*`，本包关闭且无服务端配置）
- 不接入农行掌银 SDK（本包不存在）
- 不接入微信支付 SDK（本包仅有微信登录，且 `openWechatLogin: false`）
- 不改变电费充值、热水、饮水等既有功能的校园卡余额展示与扣费逻辑
- 不替换现有支付宝小程序跳转作为兜底（在新入口不可用时保留）

# 验收示例

- A1：superhut 能用当前登录态的 `X-Id-Token` 构建完整 light.action 充值入口 URL（含 `flag=supwisdomapp_hngydxsw`、`ecardFunc=index`、`token`）。
- A2：校园卡余额卡片仍能正确显示余额（沿用现有 `getCardBalance`，不被本次改造破坏）。
- A3：「前往充值」按钮打开自带 WebView 并加载 A1 构建的 URL；WebView 内呈现完美校园校园卡主页（卡面、余额、充值/交易明细/解绑）。
- A4：（H5 内建行为，仅作真机抽检不作为 superhut 代码验收）充值页提供预设金额与「其他金额」自定义输入。
- A5：（H5 内建行为，仅作真机抽检）支付方式页展示服务端下发的支付方式（微信、农行掌银）。
- A6：在 WebView 内选择微信支付后能跳转 `wx.tenpay.com` 收银台并唤起微信（H5 支付链路）；用户返回 superhut 后刷新校园卡余额。
- A7：WebView 打开失败（无网络/接口异常/H5 不可达）时，回落到原支付宝小程序跳转并提示用户。

# Constraints and invariants

- 必须复用现有 `HutUserApi` 的 token 与会话体系（`getToken()`、`_getOpenIdSession()`），不得引入第二套凭证存储。
- 不得把任何密钥（DES/SM2/SM4/APP_KEY）硬编码进 superhut；V8/Synpay 属非目标，不复制其密钥。
- 校园卡 H5 必须在 WebView 中携带校园服务会话（Cookie/`X-Id-Token`），参考 `lib/pages/hutpages/type2webview.dart` 的注入方式。
- 遵循项目既有 GetX/StatefulWidget 混用模式，新页面采用与 `lib/pages/Electricitybill/` 相近的 StatefulWidget 结构。
- 所有网络失败必须有用户可读提示，不静默吞异常（项目准则：快速失败 + 上下文）。

# Decisions

- [2026-10-20，静态分析结论] 该 IPA 的校园卡后端是**新开普（NewCapec/supwisdom）V8 + Synpay**，不是完美校园。全包无 `wanmei`/`17wan`/`完美校园` 字符串；`config.plist` 中 `APP_NAME=智慧工大`、`APPLICATION_ID=com.supwisdom.hut`、`TEAM_NAME=Hunan University of Technology`、`packTestNew=release/6.7.0/superapp`。
- [2026-10-20，静态分析结论] 本包**不存在**「自定义金额 + 微信/农行掌银二选一」的充值流程。微信 SDK 仅登录用途且 `openWechatLogin: false`；农行掌银零命中；Synpay 支付方式列表（`SWSynPayTypeModel`/`getPayType:finish:`）所在 SDK `openSynpayQrcode: false` 且无服务端配置。
- [2026-10-20，静态分析结论] 唯一可触达的校园卡充值路径是 H5：`wgt` 的 `getECardDataList`（`/v1/personalData/getECardDataList`，注释「获取一卡通相关链接地址」）下发学校专属链接，由 `ecard-center` 组件跳转。superhut 应以 WebView 承载该 H5 完成充值。
- [2026-11-08，真机动态分析结论（推翻 2026-10-20 部分静态结论）] 官方 App 的校园卡充值页是**完美校园（17wanxiao，新开普旗下品牌）轻应用 H5**，内容在服务端，IPA 内无字符串故静态检索不可见。完整链路（Frida + WKWebView hook + H5 内 JS 注入实测）：
  1. 首页「校园卡充值」→ uni-app 容器在 WKWebView 打开 `https://hub.17wanxiao.com/bsacs/light.action?flag=supwisdomapp_hngydxsw&ecardFunc=index&token=<X-Id-Token JWT>`；
  2. `token` 即 portal 接口用的 `X-Id-Token`（RS512 JWT，iss=mycas.hut.edu.cn，sub=学号）——**superhut 已持有同一 token**；
  3. light.action 重定向到 `https://ecardh5.17wanxiao.com/ecardh5/ecard_t/index.html`（校园卡主页：卡面、余额、充值/交易明细/解绑），充值走 `recharge.html#/`（金额选择，服务端渲染预设 10/20/30/50/100/200/300/500 + 其他金额）→ `#/payWays?money=N`（支付方式）；
  4. 支付方式由服务端下发：**微信、农行掌银**——用户原始描述正确，2026-10-20 的「不存在微信/农行充值流程」结论仅对 IPA 二进制成立，对运行时不成立；
  5. Safari 独立复测：仅凭 URL+token 即可完整渲染并走通支付入口；点「微信」跳转 `wx.tenpay.com`（微信 H5 支付/MWEB 收银台），系统弹「在 WeChat 中打开」——**纯 WebView 无需任何原生 SDK 即可完成支付跳转**；
  6. 官方 App 自身在「微信」上会**崩溃（进程终止，Frida 两次实测）**：其 uni-app 容器把支付劫持到未编译的微信支付原生桥（与静态 S6 一致）。
- [2026-11-08，方案修订] superhut 本期目标改为：**用自带 WebView 直接承载完美校园 light.action 链接**。superhut 只负责：构建 URL（拼入现有 `X-Id-Token`）、WebView 承载、失败回落支付宝小程序、返回后刷新余额。金额输入/支付方式/收银台均为 H5 内建行为，不在 superhut 内重新实现。

# Open questions

- [已解决 2026-11-08] Q1: 动态证据表明「接入学校下发的校园卡 H5（完美校园轻应用）」与用户原始描述（微信/农行掌银）**同时成立**，方案即「WebView 承载 light.action 链接」。待用户确认修订后的目标与验收项。
- [已解决 2026-11-08] Q2: 微信/农行掌银来自完美校园 ecard H5（服务端下发），用户在官方 App 看到的即此页面；非独立客户端。
- [已解决 2026-11-08] Q3: 真机抓取已完成（本节动态分析结论），无需再抓。
- [待确认] Q4: superhut 端 URL 模板中的 `flag=supwisdomapp_hngydxsw` 为学校专属常量，计划直接内置（学校定制 App，无多校需求）；如后续 portal 服务配置接口能下发该模板可改为动态获取。是否接受内置常量？

# Verification expectations

- `flutter analyze` 无新增 warning/error。
- `flutter test` 全绿，新增 `test/campus_card_recharge_test.dart` 覆盖 URL 构建（A1）、token 缺失时的错误处理与入口回退（A7）。
- A3/A6 属真机项：以真机截图与 WebView 加载日志作为验收证据（2026-11-08 已在官方 App 与 Safari 完成等价链路验证，见 Decisions 与 S12–S15）。
- 逆向结论本身以本文件 Source coverage 表中的条目与 `verification.md` 中记录的证据为准，不复述模型推理。
