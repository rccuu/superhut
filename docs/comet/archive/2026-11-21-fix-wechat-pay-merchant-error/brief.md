# 目标

修复 Android 端校园卡充值的微信支付链路：在 superhut 的校园卡 H5 WebView 内选择微信支付后，跳转 `wx.tenpay.com` 微信 H5 支付（MWEB）收银台时微信侧报「商户配置错误，请联系商户解决」，无法完成支付；iOS 端同链路正常。

根因（外部权威结论，多来源一致）：微信 H5 支付校验收银台请求的 `Referer` 是否为商户平台配置的 H5 支付域名；Referer 缺失或不匹配时即报该错误。iOS 的 WKWebView 在页面内跳转时自动携带页面来源 Referer（`ecardh5.17wanxiao.com`，iOS 实测已走通 → 证明商户配置包含该域），Android WebView 的该请求 Referer 不满足校验。

修复方式（业界标准做法）：Android 端 WebView 加载 `wx.tenpay.com` 收银台 URL 时显式附加 `Referer: https://ecardh5.17wanxiao.com/`，模拟 iOS WebView 自动携带的行为。

# 调查结论（事实）

- 支付链路（2026-11-08 campus-card-recharge 逆向事实）：H5 支付方式页在 `ecardh5.17wanxiao.com`（recharge.html，hash 路由 `#/payWays?money=N`）→ 跳转 `wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb`（MWEB 收银台）→ 收银台页面重定向 `weixin://wap/pay` 深链唤起微信。superhut 当前 `shouldOverrideUrlLoading` 对 http/https 一律放行、对非 http(s) scheme 用 `launchUrl` 外开（lib/pages/campuscard/campus_card_recharge_page.dart:206-219）。
- 微信报错机制：微信支付官方文档《H5 支付常见问题》与多个开发案例确认——跳转 H5 支付的网页域名（微信从 `Referer` 取）必须与商户平台【开发配置】中的「H5 支付域名」一致，否则报「商户配置错误，请联系商户解决 / 商家存在未配置的参数」。
- 平台差异根因：iOS WKWebView 自动携带页面来源 Referer；Android WebView 场景下该请求 Referer 缺失/不匹配。
- 既往验收缺口：campus-card-recharge 的 A6 仅在 iOS（Safari / WKWebView）动态验证，Android 端从未真机验证。
- 技术可行性已核实：flutter_inappwebview（6.1.5 / android 1.1.3）`URLRequest.headers` 在 Android 实现为原生 `WebView.loadUrl(url, headers)`（InAppWebView.java:644-654），headers 应用于该请求；Android `loadUrl()` 发起的加载不触发 `shouldOverrideUrlLoading`，取消原导航后带头重载无循环风险。
- 入口覆盖：`CampusCardRechargePage` 是唯一 WebView 承载页（我的页 lib/home/userpage/view.dart:417 与热水页 lib/pages/water/view.dart:71 两个入口共用），单一修复点覆盖全部充值入口。

# 范围

## 目录结构

### 修改

- `lib/pages/campuscard/campus_card_api.dart` — 新增收银台 Referer 决策常量与纯函数（域名判断 + Referer 取值），供页面与测试复用。
- `lib/pages/campuscard/campus_card_recharge_page.dart` — `shouldOverrideUrlLoading` 中：Android 平台且目标为 `wx.tenpay.com`（含子域）的 http(s) 导航，取消原导航并以附加 `Referer` 头的 `URLRequest` 重载；其余行为不变。
- `test/campus_card_recharge_test.dart` — 新增 Referer 决策逻辑单元测试。

## Source coverage

无用户提供的源文档/附件/链接作为需求来源。需求来自用户口述，事实依据为仓库代码、既往 change 归档（2026-11-08-campus-card-recharge）与微信支付官方文档调查。

# 约束

- Referer 值使用常量 `https://ecardh5.17wanxiao.com/`（iOS 实测通过证明该域在商户 H5 支付配置内；具体页面路径不影响微信的域名校验）。
- 仅 Android 平台附加该头；iOS 端行为保持现状（自动 Referer 已可用）。
- 沿用既有安全约束：WebView 不注入脚本操纵 H5 行为；不引入第二套凭证；不硬编码支付密钥。

# 非目标

- 不改变 iOS 端微信支付行为。
- 不调整 WebView User-Agent（若真机实测 Referer 修复后仍报错，作为后续修订单独排查，不在本 change 内预设）。
- 不接入微信支付 / 农行掌银原生 SDK，不改动农行掌银流程。
- 不实现或修改 H5 内部页面逻辑（金额输入、支付方式列表、收银台 UI 均为完美校园 H5 内建）。

# Open questions

（无。所有影响结果的决定均可从 iOS 实测行为、代码现状与外部文档可靠推断。若 Android 真机实测 Referer 修复无效，走 revise-implementation 回 Build 排查次级因素，不阻塞当前 Shape。）

# Acceptance examples

- A1（Android 收银台 Referer）：Android 平台上，WebView 内任何 http(s) 顶层导航目标为 `wx.tenpay.com`（含其子域）时，取消原导航并以附加 `Referer: https://ecardh5.17wanxiao.com/` 的请求重新加载该收银台页。
- A2（iOS 行为不变）：非 Android 平台（iOS 等）对 `wx.tenpay.com` 导航保持现有行为：不附加任何头，WebView 内直接放行。
- A3（其余导航不受影响）：`wx.tenpay.com` 以外的 http/https 导航仍在 WebView 内直接放行且不附加头；外部 scheme（`weixin://`、`alipays://`、掌银 scheme 等）仍被拦截并交由系统打开。
- A4（决策逻辑可测）：Referer 决策为纯函数并有单元测试覆盖：Android + `wx.tenpay.com` → 返回 Referer 值；Android + 子域 → 返回；Android + 其他域 → null；非 Android + `wx.tenpay.com` → null。
- A5（静态检查）：`flutter analyze`（限定本次改动文件范围）与相关 `flutter test` 通过。
- A6（Android 真机实测）：Android 真机上从校园卡 H5 选择微信支付，不再出现「商户配置错误，请联系商户解决」，能唤起微信进入支付页（需用户参与验证）。
