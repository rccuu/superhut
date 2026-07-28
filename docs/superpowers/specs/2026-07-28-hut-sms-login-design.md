# 智慧工大短信验证码登录设计

## 概述

工大盒子当前只支持 HUT（智慧工大）账号密码登录（`HutUserApi.userLogin` → `POST /token/password/passwordLogin`）。官方「智慧工大」App（`com.supwisdom.hut` / `SWSuperApp` 1.1.8）还提供手机号 + 短信验证码无密码登录，以及密码登录后的 MFA 安全手机二次验证。

本设计基于**已砸壳 IPA 的静态分析**与 **`smsInit` 无副作用活体探测**，定义可对接协议，并把无密码短信登录集成进工大盒子；MFA 完整 UI 作为 Phase 2。

## 背景与接口发现结论

### 为什么不是「先模拟器 / 先 IDA」

| 手段 | 适用性 | 结论 |
|------|--------|------|
| 砸壳 IPA 静态分析 | 本包 `cryptid 0`，可直接 `unzip` + `strings` + `class-dump` + 解 `wgt` | **主手段**。路径、参数、类名、JS 拼装已足够 |
| 无副作用活体 | 仅 `GET smsInit` | **已验证**：200 + `nonce` |
| 真机抓包 | 联调补请求头 / 错误码 / 频控表现 | **联调可选**，不阻塞设计与首版实现 |
| 模拟器安装砸壳包 | arm64 设备包 + 签名/完整性问题 | **不作为主路径** |
| IDA / Frida 深逆向 | 仅当出现请求签名、SSL Pinning、字段对不上 | **按需**；当前会话亦未挂载 IDA MCP |

官方包关键事实：

- Bundle：`com.supwisdom.hut`，可执行文件 `SWSuperApp`
- 登录基址（`config.plist`）：`LOGIN_BASE_URL = https://mycas.hut.edu.cn/token`
- 与盒子现有 `_kMyCasBaseUrl` / `passwordLogin` 同源
- 登录能力由服务端 `GET /token/login/configs` 下发；模式模型含 `authenticationSmsCodeEnabled` 等开关
- 原生侧：`smsInit:` / `smsSendWithMobile:CallBack:` / `smsLoginWithMobile:smscode:complete:`
- uni-app `app-service.js` 给出完整 query 拼装（见下节）

### 与「验证码」相关的多条链路（避免混淆）

1. **无密码短信登录（本设计主路径）**  
   `passwordless/smsInit` → `smsSend` → `smsLogin`
2. **密码登录后的 MFA 安全手机（Phase 2）**  
   `passwordLogin`（可带 `mfaState`）→ `mfa/detect` → `mfa/initByType/` → 安全手机发码/校验 → 再 `passwordLogin(mfaState:)`
3. **忘记密码 / 账号激活 / 绑定手机发码**  
   `api/v1/personal/.../sendCode*` 等，**首版不做**

## 目标

- 用户可用绑定手机号完成验证码登录，进入与密码登录相同的 HUT 会话状态
- 协议与实现可测试、可回退
- 成功后回填手机号，减少重复输入

## 非目标（首版）

- 人脸、微信/支付宝/企业微信等联邦登录
- 忘记密码、账号激活完整流程
- 官方 App UI 复刻
- 主动绕过 SSL Pinning / 伪造签名（当前静态与 `smsInit` 活体未表明必需）
- CI 中对真实短信网关发码

## 推荐实现路线

在 brainstorm 中比较了三种路线，**采用 C：静态协议落地 + 最小 UI 集成**：

| 路线 | 做法 | 取舍 |
|------|------|------|
| A 纯抓包驱动 | 先跑官方 App 抓全量再写 | 慢；砸壳包已给出 path/参数 |
| B 深逆向优先 | IDA/Frida 挖签名与控制流 | 成本高；当前证据不足 |
| **C 静态 + 活体 + 集成（推荐）** | IPA/JS 定协议，`smsInit` 验证可达，扩展 `HutUserApi` + 登录页 | 与现有密码登录扩展方式一致，最快可交付 |

## 架构

```
[登录 UI]
  ├─ 账号密码模式 → HutUserApi.userLogin（现有）
  │                   └─ Phase1：识别 needMfa，给出明确失败引导
  │                   └─ Phase2：MfaPhoneFlow → passwordLogin(mfaState:)
  └─ 验证码模式   → HutSmsLoginCommand
                       1) smsInit
                       2) smsSend(mobile, nonce)
                       3) smsLogin(mobile, smscode, …)
                       └─ HutPortalSession + AppAuthStorage
```

### 分层

| 层 | 职责 | 落点 |
|----|------|------|
| API | 请求拼装、响应解析、会话落盘 | `lib/utils/hut_user_api/hut_user_api_auth.dart`（`_HutAuthMixin`） |
| Command | 倒计时、防重入、错误文案、调用 API | 新建 `lib/login/hut/sms_command.dart`（与现有 `command.dart` 密码登录并列，不混在同一类里） |
| View | 密码/验证码模式切换、输入与按钮状态 | `lib/login/hut/view.dart`、`lib/login/unified_login_page.dart` |
| Storage | token / 手机号回填 / 登录类型 | `lib/core/services/app_auth_storage.dart` |

### 关键约定

- Base：`https://mycas.hut.edu.cn`（path 以 `/token/...` 拼接，与现有 `userLogin` 一致）
- `appId`：`com.supwisdom.hut`
- `osType`：`android`（与现有密码登录保持一致，降低服务端分支差异）
- `deviceId`：复用 `generateDeviceIdAlphabet()`（24 位字母）
- `geo`：可传空字符串
- User-Agent：复用 `_kHutLoginUserAgent`
- 参数位置：与官方 JS 一致，**query string**；POST body 为空（与现有 `passwordLogin` 的 `data: {}` 一致）

## API 协议

### A. 无密码短信登录（Phase 1 主路径）

Base path prefix：`/token`

| 步骤 | Method | Path | Query | 状态 |
|------|--------|------|-------|------|
| 1 | GET | `/passwordless/smsInit` | 无 | **已活体验证** |
| 2 | POST | `/passwordless/smsSend` | `mobile`, `nonce` | 静态确认（IPA + JS） |
| 3 | POST | `/passwordless/smsLogin` | `mobile`, `smscode`, `appId`, `deviceId`, `osType`, `geo`, `nonce` | 静态确认（IPA + JS） |

#### `smsInit` 活体样例（2026-07-28）

```http
GET https://mycas.hut.edu.cn/token/passwordless/smsInit
User-Agent: SWSuperApp/1.1.3(XiaomidadaXiaomi15)
```

```json
{
  "code": 0,
  "data": {
    "success": true,
    "message": "SMS init success",
    "nonce": "oUOHnB"
  }
}
```

#### 官方 JS 拼装（摘自 IPA 内 `__UNI__*.wgt` → `app-service.js`）

```text
WechatBase = https://mycas.hut.edu.cn/token/

GET  WechatBase + /passwordless/smsInit
POST WechatBase + /passwordless/smsSend?mobile={mobile}&nonce={nonce}
POST WechatBase + /passwordless/smsLogin?mobile={mobile}&smscode={smscode}
     &appId={appId}&deviceId={deviceId}&osType={osType}&geo={geo}&nonce={nonce}
```

#### Dart 表面（Phase 1 定稿）

新增轻量结果类型（放在 `hut_user_api` 可见处，供 command/UI 使用）：

```dart
class HutAuthResult {
  final bool success;
  final String message;
  final String? nonce; // 仅 smsInit 使用
  final bool needMfa;  // Phase 1 供密码路径识别；Phase 2 可扩展 mfaState
}
```

```dart
Future<HutAuthResult> smsInit();
Future<HutAuthResult> smsSend({required String mobile, required String nonce});
Future<HutAuthResult> smsLogin({
  required String mobile,
  required String smscode,
  required String nonce,
});
// 现有 userLogin -> bool 保留；新增：
Future<HutAuthResult> userLoginDetailed({
  required String username,
  required String password,
  String mfaState = '',
});
```

行为约定：

- `smsInit`：`code == 0` 且 `data.nonce` 非空 → `success=true` 并填 `nonce`；否则 `success=false`，`message` 取服务端或通用失败文案
- `smsSend` / `smsLogin`：`code == 0` 为成功门槛；`smsLogin` 还需能解析出非空 token
- `smsLogin` 成功后：
  - `HutPortalSession.fromLoginData(data)` 解析 `idToken` / `ticket` 等（多 key 兼容已有）
  - `saveHutSession(token, refreshToken, deviceId, ticket)`
  - `saveLoginType('hut')`
  - **`saveHutMobile(mobile)`** 供登录页回填
  - 不调用 `saveHutCredentials`（验证码登录无密码可存）
- `userLogin` 继续返回 `bool`，内部可委托 `userLoginDetailed`，避免大面积改旧调用点

### B. 密码 + MFA（Phase 1 最小 / Phase 2 完整）

静态可见：

- `password/passwordLogin`（已实现，query 含空 `mfaState`）
- `passwordLoginWithAccount:password:mfaState:complete:`
- `mfa/detect`、`mfa/initByType/`、`doMfaDetectWithUserName:deviceId:callBack:`
- 模型：`SWMfaDetectModel`（`mfaEnabled` / `need` / 各 `mfaType*` / `state`）
- 安全手机：`doSecurephoneWithAttestServerUrl:...`、`doGuardSecurephoneValidWith...`

**Phase 1**：解析密码登录响应中的 MFA 需求，向用户展示明确文案（引导改用验证码登录或提示暂不支持完整 MFA），不静默失败。  
**Phase 2**：实现 detect → init → 发码/校验 → 带 `mfaState` 重登的完整流与 UI。

### C. 错误、频控与隐私

| 情况 | 行为 |
|------|------|
| 手机号本地非法 | 不发请求；提示检查手机号 |
| `code != 0` | SnackBar 展示服务端 `message`（若空则通用失败文案） |
| 网络异常 | 「网络异常，请稍后重试」 |
| 密码路径 needMfa（Phase 1） | 明确引导，不假装登录成功 |
| 发码间隔 | UI 60s 倒计时，未结束不可再次发送 |
| 日志 | 不打印完整手机号与验证码；nonce 可打脱敏/截断 debug |
| 重试 | 不自动重试 `smsSend` |

## UI 设计

### 入口

- `HutLoginPage`（`lib/login/hut/view.dart`）：增加「账号密码 / 验证码登录」切换
- `UnifiedLoginPage`（`lib/login/unified_login_page.dart`）：同样支持验证码模式（与 HUT 认证共用 API）

### 验证码模式字段

- 手机号输入（回填上次成功登录手机号）
- 验证码输入
- 「获取验证码」按钮（倒计时文案如「59s 后重试」）
- 「登录」按钮
- 发送中 / 登录中 loading；防重复提交（对齐现有 `HutLoginCommand` 的 in-flight 模式）

### 交互顺序

1. 用户输入手机号 → 点「获取验证码」
2. Command：`smsInit` → 存 nonce → `smsSend`
3. 成功则开始 60s 倒计时；失败展示 message，不启动倒计时（或按服务端限流要求启动——联调时定，默认失败不倒计时）
4. 用户输入验证码 → 点登录 → `smsLogin`（使用同一次 init 的 nonce；若 nonce 过期则重新 init + 提示重发）
5. 成功：SnackBar「登录成功」+ 返回/进首页（与现网密码登录一致）

## 存储

在 `AppAuthStorage` 增加 HUT 手机号读写（SharedPreferences，非密码）：

| Key | 说明 |
|-----|------|
| `hutMobile` | 上次验证码登录成功的手机号，仅用于回填 |

API：`saveHutMobile` / `readHutMobile` / 在 `clearHutCredentials` 与 `clearAllAuthData` 中删除该 key。

- `smsLogin` 成功后写入规范化后的手机号（去空格）
- 登录页与现有「读取已保存账号」并行 `readHutMobile`，填入验证码模式手机号框
- **不**把短信验证码或 nonce 写入任何持久存储

密码登录仍使用现有 `hutUsername` / `hutPassword`（secure）逻辑；验证码登录不覆盖密码，除非产品后续要求「用手机号当用户名展示」。

## 测试计划

| 层级 | 内容 |
|------|------|
| API 单元 | mock Dio：`smsInit` 解析 nonce；`smsSend`/`smsLogin` 的 method/path/query；成功时 session 写入（mock storage） |
| Command | 倒计时启动/结束、防重入、失败不落盘、成功回调 |
| Widget | 模式切换、按钮禁用、回填手机号 |
| 回归 | 现有 `userLogin` / `HutLoginCommand` / unified login 测试不被破坏 |
| 禁区 | CI 不对真实 `smsSend` 发码；活体探测仅限本地手工 |

测试风格对齐现有：`SharedPreferences.setMockInitialValues`、command 可注入 submitter。

## 风险与回退

| 风险 | 缓解 |
|------|------|
| `smsLogin` 响应字段与 `passwordLogin` 不完全一致 | 继续用 `HutPortalSession.fromLoginData` 多 key 读取；联调补字段 |
| 服务端增加图形验证码 / 设备指纹 | 联调暴露后扩展协议；首版不做猜测实现 |
| `authenticationSmsCodeEnabled` 被学校关闭 | UI 仍可隐藏入口；或请求失败时展示服务端 message |
| nonce 一次性/短时效 | 登录前若失败可重新 init；发送与登录共用同一次 nonce |
| MFA 用户无法密码登录 | Phase 1 引导验证码登录；Phase 2 补 MFA |
| 回退 | 编译期/简单常量关闭验证码 Tab（如 `kHutSmsLoginEnabled`）；不删除密码路径 |

## 实现阶段

### Phase 1（本设计交付）

1. 扩展 `_HutAuthMixin`：`smsInit` / `smsSend` / `smsLogin` + 会话/手机号落盘
2. `HutSmsLoginCommand` + 倒计时/防重入
3. `HutLoginPage`、`UnifiedLoginPage` 验证码模式与回填
4. `userLogin` 对 needMfa 的可观测失败（最小）
5. 单测与手工联调清单（init → send → login）

### Phase 2

1. `mfa/detect`、`mfa/initByType`、安全手机发码/校验
2. `passwordLogin(mfaState:)` 闭环 UI
3. 按需抓包确认 header / 错误码字典

## 手工联调清单（实现后）

1. 仅 `smsInit`：应稳定返回 `code=0` + `nonce`
2. 真实手机号 `smsSend`：应收到短信；错误号/限流应有 message
3. `smsLogin`：会话可读，`loginType=hut`，门户/饮水等依赖 HUT token 的功能可用
4. 杀进程重开：手机号回填；token 仍符合现有刷新逻辑
5. 登出：手机号与 HUT session 清除

## 参考产物（分析时）

- IPA：`智慧工大_1.1.8.ipa` → `Payload/SWSuperApp.app`
- `config.plist`：HOST / `LOGIN_BASE_URL`
- 主二进制字符串与 `class-dump`：`passwordless/*`、`SWMfa*`、`MobileLoginView`、`NewMobileLiginView`
- Wgt：`__UNI__AA068AD.wgt` → `app-service.js` 中 `asyncNonce` / `asyncCode` / `asyncCodeLogin`
