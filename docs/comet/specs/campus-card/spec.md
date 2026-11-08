# 校园卡充值能力规格

本规格描述 superhut 中「校园卡充值」能力的完整目标行为。

## 目的

让用户在 superhut 内完成校园卡充值：superhut 用自带 WebView 承载学校官方 App 同款的完美校园（17wanxiao）校园卡 H5 轻应用。金额输入、支付方式（微信 / 农行掌银）与收银台均为 H5 内建能力，superhut 不重新实现。

## 入口 URL（A1）

校园卡 H5 的入口 URL 由 superhut 构建：

```text
https://hub.17wanxiao.com/bsacs/light.action?flag=supwisdomapp_hngydxsw&ecardFunc=index&token=<X-Id-Token>
```

- `token` 为 superhut 现有登录态的 `X-Id-Token`（与 portal / 热水等接口同一凭证，不引入第二套凭证存储）。
- `flag=supwisdomapp_hngydxsw` 为学校专属常量，内置在代码中（Q4）。
- 该机制由真机动态分析证实：官方 App 的 WKWebView 即加载此 URL（brief Source coverage S12）。

Scenario: 用户已登录，构建入口 URL
  WHEN 用户点击充值入口
  THEN superhut 读取当前 `X-Id-Token` 并拼入入口 URL 模板

Scenario: token 不存在（未登录/会话失效）
  WHEN 构建入口 URL 时无法取得 token
  THEN 提示用户先登录，不打开 WebView

## 入口与回退（A3 / A7）

Scenario: 用户点击「前往充值」，URL 构建成功
  WHEN 用户在「我的」页校园卡卡片或热水页点击充值入口
  THEN 打开 superhut 自带 WebView 加载入口 URL，页面内呈现校园卡主页（卡面、余额、充值 / 交易明细 / 解绑）

Scenario: WebView 加载失败
  WHEN WebView 打开失败（无网络、H5 不可达、加载超时）
  THEN 提示用户加载失败，并提供「改用支付宝小程序」的回落跳转

Scenario: 支付宝小程序兜底
  WHEN 用户选择回落
  THEN 跳转原支付宝小程序（`alipays://platformapi/startapp?appId=2019030163398604&page=pages/index/index`），保留原有可用路径

## 余额展示（不变式，A2）

Scenario: 用户查看校园卡余额
  WHEN 进入「我的」页或热水页
  THEN 校园卡余额通过 `HutUserApi.getCardBalance()` 读取并展示
  AND 本次改造不改变该读取路径与解析逻辑

## H5 内建行为（非 superhut 实现，真机抽检项 A4 / A5）

以下行为由完美校园 H5 提供，superhut 仅保证 WebView 正常承载：

- 充值页提供预设金额（10/20/30/50/100/200/300/500 元）与「其他金额」自定义输入。
- 支付方式页展示服务端下发的支付方式（微信、农行掌银）。
- 校园卡主页展示卡面、余额、交易明细、解绑入口。

## 支付流程（A6）

Scenario: 用户在 WebView 内选择微信支付
  WHEN 用户在 H5 支付方式页选择微信
  THEN H5 跳转 `wx.tenpay.com` 微信 H5 支付收银台，系统唤起微信完成支付（微信 H5 支付 / MWEB，无需原生 SDK）
  AND superhut 的 WebView 允许该外部跳转（不拦截 `wx.tenpay.com` 与微信 scheme）

Scenario: 用户支付完成返回 superhut
  WHEN 用户从微信支付流程返回 superhut
  THEN 用户可返回校园卡 H5 页面查看最新余额（H5 自行刷新）
  AND superhut 在 WebView 关闭后刷新「我的」页与热水页的校园卡余额展示

Scenario: 用户选择农行掌银
  WHEN 用户在 H5 支付方式页选择农行掌银
  THEN 按 H5 内建流程处理（跳转掌银或其收银台），superhut 不拦截

## 安全约束

- 入口会话只使用现有 `X-Id-Token` 凭证体系；不得引入第二套凭证存储。
- 不硬编码任何支付密钥；V8 的 DES/SM2/SM4 与 Synpay 的 APP_KEY 不属于本能力。
- WebView 不注入任何脚本去操纵 H5 行为；superhut 只做承载与跳转放行。
- 所有失败路径（构建失败、加载失败）都向用户展示可读原因并提供回落。

## 非目标

- 不实现新开普 V8 付款码/消费码链路。
- 不实现 Synpay 聚合支付 SDK。
- 不接入农行掌银或微信支付原生 SDK（H5 收银台无需原生 SDK；官方 App 的原生桥方案实测崩溃）。
- 不在 superhut 内实现金额输入、支付方式列表或收银台 UI。
