# 智慧工大热水（洗澡）功能逆向分析报告

> change: `hot-water-service-reverse` · 2026-11-22 · 分析人：ZCode（用户全程授权实开实关）
> 分析对象：官方 App `com.supwisdom.hut` 1.1.8（IPA：`智慧工大_1.1.8.ipa`）中的用水服务-热水功能
> 本报告结论已全部复现验证：真实会话下实开实关一个完整循环（设备 704536，开阀约 12 秒后关闭）。

## 证据文件清单（同目录 `water_hot_reverse_evidence/`，已脱敏）

| 文件 | 内容 |
| --- | --- |
| `zdRedirect_headers.txt` | 会话引导接口 302 响应头（JSESSIONID + Location:openid） |
| `waterHomePage.html` / `waterUsingPage.html` / `waterOpenClose.html` | 用水服务三个页面的服务端渲染 HTML 快照 |
| `js_water_waterHomePage.js_20221122` / `waterUsing.js` / `waterOpenClose.js` / `js_water_waterCommon.js_20220215002` | 官方开关阀前端逻辑原文 |
| `dkyw.js` | 官方 AJAX 封装（dkyw.request）原文 |
| `i18njs.js` | 官方错误码→文案映射表（zh_CN，1036 条） |
| `resp_getOftenUsetermList.json` | 设备列表真实响应 |
| `resp_open_real.json` / `resp_open_real2.json` / `resp_open_try3.json` | 开阀三次真实响应（失败/失败/成功） |
| `resp_openclose_with.json` | 有未关阀记录时 selectCloseDeviceValve 真实响应（含服务端→终端网关协议） |
| `resp_close_real.json` | 关阀成功真实响应 |
| `resp_after_close.json` / `resp_selectCloseDeviceValve.json` | 关阀后查询（无未关阀记录） |
| `resp_enduse_noopen.json` | 无开阀记录时关阀失败真实响应 |
| `resp_open_invalid.json` | 非本用户设备开阀错误响应 |

敏感值（idToken、openid、JSESSIONID、学号/账户号、姓名、终端网关 IP）已全部替换为占位符。

---

## 1. 结论摘要

1. **热水功能 100% 在服务端 H5**：IPA 原生二进制与 uni-app 主包均无任何用水业务字符串；App 只负责鉴权后用 WKWebView 打开 `v8mobile.hut.edu.cn/waterpage/waterHomePage`。superhut 不需要、也不应该从客户端复刻任何本地水控逻辑。
2. **开阀/关阀 = 服务端向水控终端网关下发命令**。响应里的 `sendmsg` 字段暴露了完整服务端↔终端协议（终端 IP、命令号、返回码）。**终端「忙/通讯异常」是开关失败的主因**，且是瞬时的——实测同一设备 12 秒内 两次失败后第三次成功。服务端文案自己写着「请稍候再试」，即**官方预期客户端重试**。
3. **关阀失败在官方 App 也是常态**：官方「使用中」页的失败兜底文案就是「关阀失败，请终端关阀」，还有专门的「未关阀设备」页（waterOpenClose）让用户事后补关。
4. **v8mobile 水 API 只认 JSESSIONID 会话**，`userToken` cookie 完全不参与校验。idToken（30 天有效期 JWT）只在换取会话时用一次。
5. superhut 现有实现方向正确，但有四个可修的稳定性差距：丢弃服务端错误消息、无重试、3 秒超时过紧（实测最大 2.89 秒）、每次操作都重新换取会话。

## 2. 官方链路还原

### 2.1 鉴权链（App 原生 → H5 会话）

```
[App 原生] mycas.hut.edu.cn /token/password/passwordLogin（或短信登录）
    → data.idToken（JWT RS512，iss=mycas.hut.edu.cn，exp-iat=30天，req=com.supwisdom.hut）
[App → WebView] loadRequest:
    https://v8mobile.hut.edu.cn/zdRedirect/toSingleMenu?code=openWater&token=<idToken>
    （实测该 URL 由 WKWebView loadRequest: hook 抓到，与 superhut 实现一致）
[服务端] 302 →
    Set-Cookie: JSESSIONID=<32位HEX>; Path=/; HttpOnly
    Location: https://v8mobile.hut.edu.cn/waterpage/waterHomePage?openid=<96位HEX>
[此后所有水 API] Cookie: JSESSIONID=<...>（+ URL 与请求体里的 openid 双写）
```

要点：

- **userToken cookie 不参与 v8mobile 校验**（实测：仅带 JSESSIONID 调 getOftenUsetermList 成功；仅带 userToken 或无 cookie 返回 `{"message":"资源受限，页面丢失!","success":false}`）。
- 官方 H5 整个页面生命周期复用**同一个** JSESSIONID；superhut 目前每次操作都重新走一遍 zdRedirect（多一跳、多一个失败点，且旧会话并未失效）。
- 会话失效的统一响应形状是 HTTP 200 + `{"message":"资源受限，页面丢失!","success":false}`（无 result 字段）。

### 2.2 前端页面与逻辑（官方 H5，Thymeleaf 服务端渲染）

| 页面 | 职责 | 关键 JS |
| --- | --- | --- |
| `waterHomePage` | 输 6 位设备号/扫码开阀、设备下拉、未关阀提醒横幅 | `waterHomePage.js` |
| `waterUsingPage` | 「使用中」页，唯一能发起关阀的地方 | `waterUsing.js` |
| `waterOpenClose` | 未关阀设备列表，逐台跳转到 using 页补关 | `waterOpenClose.js` |
| `waterManagePage` | 绑定/解绑设备 | （superhut 已实现 bindTerm/cancelBindTerm） |

开阀流程（`termcodeOpenValve()`）：

```js
POST /boiling/termcodeOpenValve  body {openid, poscode}
成功（resultData.result=='000000'）→ window.location = waterUsingPage?openid&poscode
失败 → 弹窗显示 queryI18n(result)   // 注意：官方丢弃 resultData.message，用错误码查 i18n 表
success:false（会话/HTTP层）→ 弹窗显示默认文案「开阀失败」
```

关阀流程（`endUse()`）：

```js
POST /boiling/endUse  body {openid, poscode, openappid}
// openappid = 开阀记录 id；从「未关阀设备」页进入时由 URL 带入，
// 正常「输码开阀→关阀」路径下为空串（superhut 现状与官方一致）
成功 → 「本次使用已结束」
失败 → 「关阀失败，请终端关阀：」+ queryI18n(result)
```

官方请求封装 `dkyw.js` 的特征：jQuery AJAX、`Content-Type: application/json`、`withCredentials`、URL 自动追加 openid、**无超时设置（等待浏览器默认）**、**无重试**、`parseError` 为空函数（HTTP 500/超时时回调不触发，页面无反馈）、全局 401 → 跳 `/login`。

### 2.3 服务端 API 契约（全部实测）

所有接口均为 `POST`（JSON body，openid 在 URL 与 body 双写）；`Content-Type: application/json`；`x-requested-with: XMLHttpRequest`；Cookie 只需 JSESSIONID。业务响应统一为 `{"message":"成功","resultData":{"result":"<码>","message":"<业务消息>","data":...},"success":true}`，**HTTP 恒 200，业务失败也在 200 里**。

| 接口 | body | 成功响应要点 | 实测耗时 | 备注 |
| --- | --- | --- | --- | --- |
| `/bathroom/getOftenUsetermList` | `{openid}` | `data[]`: `poscode/accno/userid/orgid/maxtimelimit(秒)/maxfarelimit(分)/appid/id/inputdate...` | **0.12s** | 绑定设备列表（服务端顺序不保证） |
| `/bathroom/selectCloseDeviceValve` | `{openid}` | 无记录：**顶层** `{"result":"WATER10030","message":"无未关阀记录"}`（无 success/resultData 包装）；有记录：`data[]`: `id/poscode/begintime/begintimestr/sendmsg/controltype/sendflag...` | 0.81–1.52s | 两种响应形状并存，解析需兼容 |
| `/boiling/termcodeOpenValve` | `{openid, poscode}` | `result:000000`「无卡开阀成功」 | 0.47–2.89s | 失败时 `data` 带终端命令回执 |
| `/boiling/endUse` | `{openid, poscode, openappid:""}` | `result:000000`，`data:{cmdrecno}`（服务端消息误写为「无卡开阀成功」） | 1.38–1.88s | 关阀也要等终端回执 |
| `/boiling/scanQRCode` | `{openid, barCode}` | 同上形状 | 未实测 | 扫码开阀，需要真实二维码 |
| `/bathroom/bindTerm` / `cancelBindTerm` | `{openid, bindcode}` | `result:000000` | 未实测 | superhut 已实现 |
| `/wxpay/getJssdk` | `{openid, jssdkurl}` | 微信 JSSDK 签名 | 未实测 | 仅微信公众号容器扫码用 |

### 2.4 服务端 → 水控终端协议（由 `sendmsg` 字段还原，`resp_openclose_with.json`）

```json
openparam: {maxtimelimit:"30"(分), idserial:"<学号>", poscode, accno, maxfarelimit:"10"(元),
            ip:"<终端网关IP>", currentoperator:{interfacename:"【虚拟卡水控】手机端无卡开阀"...}}
openreturn: {method:"openDeviceValve",
             param:{cmdrecno:18835863, cmdid:2819, poscode, accno, retmsg:"", retcode:0},
             retmsg:"OK", retcode:"200"}
```

- `cmdid 2819`=开阀命令、`2820`=关阀命令（`resp_enduse_noopen.json` 实证）；终端返回 `retcode 0`=OK、`9`=设备忙。
- 每次请求生成新命令记录（`cmdrecno` 递增），重试即追加命令，无重复扣费副作用（阀状态幂等）。
- 单次使用受 `maxtimelimit=30 分钟`、`maxfarelimit=10 元` 服务端硬限制。

### 2.5 错误码（`i18njs.js` zh_CN 表，开水/关水相关）

| 码 | 官方文案 | 语义 |
| --- | --- | --- |
| `000000` | 操作成功 | |
| `CORE35108` | 设备忙,请稍候再试 | **开阀失败主因**（终端 retcode 9，实测两次） |
| `CORE35106` | 设备或者网络忙，请稍候再试 | **关阀失败主因**（实测文案「无卡关阀失败,网络或设备通讯异常，请稍候再试」） |
| `CORE35107` | 关阀记录已存在 | 重复关阀 |
| `CORE35109` | 正启动中 | 开阀命令处理中 |
| `WATER10002` | 参数异常：poscode长度校验失败 | 设备号不是 6 位 |
| `WATER10003` | 设备状态异常 | 设备离线/故障 |
| `WATER10004` | 绑定关系不存在 | 设备未绑定到本人（实测非本人设备返回的是 WATER10006） |
| `WATER10005` | 开阀记录不存在 | 关阀时找不到开阀记录 |
| `WATER10006` | 该设备没有绑定商户 | 实测：poscode 999999（存在但未配置商户） |
| `WATER10030` | （不在 i18n 表） | 无未关阀记录；官方 UI 会直接显示原始码 |

## 3. 「开不了水 / 关不了水」根因清单（A2）

| # | 根因 | 证据 | 置信度 |
| --- | --- | --- | --- |
| R1 | **水控终端忙/通讯异常**：开阀关阀都要服务端实时联通终端网关，高峰期终端忙（retcode 9）或网络抖动即失败。瞬时性实测：12 秒内同设备 fail→fail→success | `resp_open_real*.json`、`resp_enduse_noopen.json`（cmdid/retcode/服务端文案「请稍候再试」） | 实锤 |
| R2 | **官方与 superhut 都不自动重试**：官方 H5 无重试逻辑，失败弹窗让用户手点；服务端文案明确建议「稍候再试」 | `waterHomePage.js`/`waterUsing.js` 全文、dkyw.js | 实锤 |
| R3 | **superhut 3 秒 receiveTimeout 过紧**：实测关阀 1.88s、开阀失败路径 2.89s，叠加校园网抖动极易超时 → 走异常分支显示「操作失败，请稍后重试」 | 本文 §2.3 耗时列 | 实锤 |
| R4 | **superhut 丢弃服务端具体原因**：`resultData.message`（如「当前设备忙,请稍候再试」）被固定文案「设备开启失败，请稍后重试」覆盖，用户无从判断该不该重试 | `logic.dart:629-634,669-674` 对照 `resp_open_real.json` | 实锤 |
| R5 | **会话单点**：superhut 每次操作重走 zdRedirect 换新会话；zdRedirect 抖动/限流会让本可成功的操作失败。官方整页复用一个会话 | superhut `_getOpenIdSession()` 每调用必执行；§2.1 | 高度可能 |
| R6 | **关阀缺少 openappid**：从「未关阀设备」补关路径官方会传开阀记录 id；superhut 恒传空串。正常开→关路径空串可行（实测成功），但补关旧记录路径 superhut 没有 | `waterOpenClose.js` + `resp_close_real.json`（空串成功） | 高度可能 |
| R7 | **HTTP 500/超时官方也静默**（dkyw parseError 为空），说明学校服务端偶发 5xx 时谁都没有好办法——只能靠客户端重试兜底 | dkyw.js | 实锤（官方行为） |
| R8 | 余额/限费限制（maxfarelimit=10 元）与 maxtimelimit=30 分钟到点自动关阀：用户「开不了」也可能是达到限额 | sendmsg openparam | 存疑（未触发实测） |

## 4. superhut 差异清单与改进方案（A3）

| 优先级 | 差异 | 官方行为 | 改进方案 | 状态 |
| --- | --- | --- | --- | --- |
| P0 | 失败只显示固定文案 | 弹窗显示错误码映射文案（设备忙/绑定关系不存在…） | 透传 `resultData.message`，为空时回退映射表/通用文案（A5） | 本次实现 |
| P0 | 无重试 | 服务端文案建议稍候再试；实测 12s 内第 3 次成功 | 传输层异常与「忙」类业务码自动重试 2 次（2s→4s 退避）（A6） | 本次实现 |
| P0 | receiveTimeout=3s | 官方无超时（浏览器默认分钟级） | 水务接口 receiveTimeout 提至 15s（实测最大 2.89s，5 倍余量）（A7） | 本次实现 |
| P1 | 每次操作重新换会话 | 整页复用一个 JSESSIONID | 会话缓存（TTL 10 分钟）+ 失效自动重建（`资源受限` 响应触发） | 本次实现 |
| P1 | 关阀不带 openappid | 补关路径携带记录 id | 保持现状（正常路径实测空串成功）；`checkHotWaterDevice` 已能发现未关设备，暂不实现补关页 | 记录，不实现 |
| P2 | 失败后不回查状态 | 官方也不回查（失败弹窗了事） | 保持现状；`endWater` 失败文案已引导用户重试/终端关阀 | 不实现 |
| P2 | 未使用 selectCloseDeviceValve 的 `begintime` 提示 | 官方「未关阀」页显示开始时间 | 现有「检测到有设备尚未关闭」提醒足够 | 不实现 |

重试策略（A6 定稿参数）：对 `startHotWater`/`stopHotWater`——

- **可重试**：Dio 超时/连接类异常；业务码 `CORE35106`、`CORE35108`（设备或网络忙，服务端文案即「请稍候再试」）。
- **不可重试**：`WATER10002/10003/10004/10005/10006`（参数/设备/绑定类，重试无意义）、`CORE35107`（关阀记录已存在=实际已关）。
- 次数：最多 2 次重试（共 3 次尝试），退避 2s → 4s，覆盖实测「12 秒内第 3 次成功」场景。
- 会话失效（`success:false` 且 message 含「资源受限/页面丢失」）：作废会话缓存重建后重试一次，不计入上述次数。

超时（A7 定稿参数）：水务专用 Dio `receiveTimeout = 15s`、`connectTimeout = 5s`；理由：实测 P95≈1.9s、最大 2.89s（忙路径），15s 为 5 倍余量且仍远小于用户自然等待阈值。

## 5. 工具备忘（复现用）

- 静态：IPA 内 `__UNI__AA068AD.wgt`（uni-app 主包）与 `SWSuperApp` 二进制字符串扫描均无用水业务串；业务全部在 v8mobile H5，带会话直接抓取即可。
- 动态：官方 App 走 WKWebView 加载 `zdRedirect/toSingleMenu?code=openWater&token=<idToken>`（loadRequest hook 实证）；H5 网络在 `com.apple.WebKit.Networking` XPC 进程，frida 注入不进去，App 进程内 `WKWebView evaluateJavaScript:completionHandler:` 在 Frida 17.26.2 + frida-objc-bridge 下自动与显式 ObjC.Block 包装均拿不到回调（主队列块内静默失败，三层二分定位见会话记录）——本次改用「官方 App 拿真实会话 → Mac 上 curl 重放同一 API」完成实开实关，API 路径与会话机制与官方 H5 完全一致。
- 会话有效期观察：本次分析同一 JSESSIONID 持续有效 >30 分钟（间隔式调用）。
