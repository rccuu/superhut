# HUT 短信验证码登录 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在工大盒子 Phase 1 接入官方无密码短信登录（`smsInit` → `smsSend` → `smsLogin`），登录页可切换验证码模式，成功后写入与密码登录相同的 HUT 会话，并回填手机号。

**Architecture:** 在 `hut_user_api` 增加可单测的纯函数（路径拼装 + 响应解析）与 `HutAuthResult`；`_HutAuthMixin` 用现有 Dio 风格调用三步接口并落盘；新建 `HutSmsLoginCommand` 负责 nonce/倒计时/防重入；`HutLoginPage` 与 `UnifiedLoginPage` 增加验证码模式。MFA 完整流不在本计划实现，仅 `userLoginDetailed` 识别 `needMfa` 并返回明确文案。

**Tech Stack:** Flutter/Dart、现有 Dio + `HutUserApi` part 文件、`AppAuthStorage`、`flutter_test`

## Global Constraints

- Base：`https://mycas.hut.edu.cn`，path 前缀 `/token/...`（与现有 `userLogin` 一致）
- `appId=com.supwisdom.hut`，`osType=android`，`geo` 可空，`deviceId` 用 `generateDeviceIdAlphabet()`
- UA：`_kHutLoginUserAgent`；参数在 **query**；POST body `{}`
- 存储 key：`hutMobile`；清除须覆盖 `clearHutCredentials` 与 `clearAllAuthData`
- 不在日志打印完整手机号/验证码；CI 不打真实 `smsSend`
- Feature flag：`kHutSmsLoginEnabled`（默认 `true`），为 `false` 时隐藏验证码入口
- 现有 `userLogin -> bool` 签名保留；详细结果走 `userLoginDetailed`
- Spec：`docs/superpowers/specs/2026-07-28-hut-sms-login-design.md`
- Conventional Commits，scope 示例：`feat(login):` / `test(login):` / `feat(auth):`

## File Structure

| 文件 | 职责 |
|------|------|
| `lib/utils/hut_user_api.dart` | 导出 `HutAuthResult`、公开 API 方法声明（若需在 abstract core 声明） |
| `lib/utils/hut_user_api/hut_user_api_auth.dart` | `smsInit` / `smsSend` / `smsLogin` / `userLoginDetailed`；纯解析/拼装函数 |
| `lib/utils/hut_user_api/hut_user_api_support.dart` | 仅在必要时放共享常量（如 `kHutAppId`）；优先少动 |
| `lib/core/services/app_auth_storage.dart` | `saveHutMobile` / `readHutMobile` + clear 路径 |
| `lib/login/hut/sms_command.dart` | **新建** 验证码登录编排 |
| `lib/login/hut/view.dart` | 密码/验证码切换 UI |
| `lib/login/unified_login_page.dart` | 统一登录页验证码模式 |
| `lib/login/hut_sms_login_enabled.dart` | **新建**（或放 sms_command 旁）`kHutSmsLoginEnabled` 常量 |
| `test/core/services/app_auth_storage_hut_mobile_test.dart` | 手机号存储 |
| `test/utils/hut_sms_auth_helpers_test.dart` | 路径/解析纯函数 |
| `test/login/hut_sms_login_command_test.dart` | Command |
| `test/login/hut_login_page_sms_test.dart` | Hut 页 widget |
| `test/login/unified_login_page_sms_test.dart` | 统一登录页 widget（可并入现有 unified 测试文件若更合适） |

---

### Task 1: `HutAuthResult` + 纯路径/解析助手

**Files:**
- Modify: `lib/utils/hut_user_api.dart`（在 library 顶层、`part` 之前定义公开 `HutAuthResult`，便于测试 import）
- Modify: `lib/utils/hut_user_api/hut_user_api_auth.dart`（`@visibleForTesting` 纯函数）
- Test: `test/utils/hut_sms_auth_helpers_test.dart`

**Interfaces:**
- Consumes: 无
- Produces:
  - `class HutAuthResult { final bool success; final String message; final String? nonce; final bool needMfa; const HutAuthResult({required this.success, this.message = '', this.nonce, this.needMfa = false}); }`
  - `String buildHutSmsInitPath()` → `'/token/passwordless/smsInit'`
  - `String buildHutSmsSendPath({required String mobile, required String nonce})`
  - `String buildHutSmsLoginPath({required String mobile, required String smscode, required String appId, required String deviceId, required String osType, required String geo, required String nonce})`
  - `HutAuthResult parseHutSmsInitResponse(dynamic data)`
  - `HutAuthResult parseHutSmsSendResponse(dynamic data)`
  - `HutAuthResult parseHutSmsLoginTokenData(dynamic data)` — 只判断 `code` 与 token 是否可解析；**不**写 storage
  - `bool hutResponseIndicatesNeedMfa(dynamic data)` — 检查 envelope / data 上的 needMfa 等字段
  - `bool isPlausibleHutMobile(String mobile)` — 去空格后匹配 `^1\d{10}$`
  - `String normalizeHutMobile(String mobile)` — `trim` + 去内部空格

- [ ] **Step 1: Write the failing test**

Create `test/utils/hut_sms_auth_helpers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/utils/hut_user_api.dart';

void main() {
  test('buildHutSmsInitPath is under /token/passwordless', () {
    expect(buildHutSmsInitPath(), '/token/passwordless/smsInit');
  });

  test('buildHutSmsSendPath puts mobile and nonce in query', () {
    final path = buildHutSmsSendPath(mobile: '13800138000', nonce: 'abc');
    expect(path.startsWith('/token/passwordless/smsSend?'), isTrue);
    expect(path, contains('mobile=13800138000'));
    expect(path, contains('nonce=abc'));
  });

  test('buildHutSmsLoginPath includes required query keys', () {
    final path = buildHutSmsLoginPath(
      mobile: '13800138000',
      smscode: '123456',
      appId: 'com.supwisdom.hut',
      deviceId: 'abcdefghijklmnopqrstuvwx',
      osType: 'android',
      geo: '',
      nonce: 'oUOHnB',
    );
    expect(path, contains('/token/passwordless/smsLogin?'));
    expect(path, contains('mobile=13800138000'));
    expect(path, contains('smscode=123456'));
    expect(path, contains('appId=com.supwisdom.hut'));
    expect(path, contains('deviceId=abcdefghijklmnopqrstuvwx'));
    expect(path, contains('osType=android'));
    expect(path, contains('nonce=oUOHnB'));
  });

  test('parseHutSmsInitResponse reads nonce on code 0', () {
    final result = parseHutSmsInitResponse({
      'code': 0,
      'data': {
        'success': true,
        'message': 'SMS init success',
        'nonce': 'oUOHnB',
      },
    });
    expect(result.success, isTrue);
    expect(result.nonce, 'oUOHnB');
  });

  test('parseHutSmsInitResponse fails without nonce', () {
    final result = parseHutSmsInitResponse({
      'code': 0,
      'data': {'success': true, 'message': 'ok'},
    });
    expect(result.success, isFalse);
    expect(result.nonce, isNull);
  });

  test('parseHutSmsSendResponse fails on non-zero code with message', () {
    final result = parseHutSmsSendResponse({
      'code': 1,
      'message': '发送过于频繁',
      'data': null,
    });
    expect(result.success, isFalse);
    expect(result.message, contains('频繁'));
  });

  test('parseHutSmsLoginTokenData succeeds when idToken present', () {
    final result = parseHutSmsLoginTokenData({
      'code': 0,
      'data': {'idToken': 'tok', 'refreshToken': 'ref'},
    });
    expect(result.success, isTrue);
  });

  test('parseHutSmsLoginTokenData fails when token missing', () {
    final result = parseHutSmsLoginTokenData({
      'code': 0,
      'data': {'refreshToken': 'ref'},
    });
    expect(result.success, isFalse);
  });

  test('hutResponseIndicatesNeedMfa detects flag', () {
    expect(
      hutResponseIndicatesNeedMfa({
        'code': 0,
        'data': {'needMfa': true, 'mfaState': 'xyz'},
      }),
      isTrue,
    );
    expect(
      hutResponseIndicatesNeedMfa({'code': 0, 'data': {'idToken': 't'}}),
      isFalse,
    );
  });

  test('isPlausibleHutMobile and normalizeHutMobile', () {
    expect(isPlausibleHutMobile('13800138000'), isTrue);
    expect(isPlausibleHutMobile('138 0013 8000'), isTrue);
    expect(isPlausibleHutMobile('123'), isFalse);
    expect(normalizeHutMobile(' 138 0013 8000 '), '13800138000');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/hut_sms_auth_helpers_test.dart`

Expected: FAIL（`HutAuthResult` / 函数未定义）

- [ ] **Step 3: Write minimal implementation**

In `lib/utils/hut_user_api.dart` **before** `part` 指令：

```dart
class HutAuthResult {
  const HutAuthResult({
    required this.success,
    this.message = '',
    this.nonce,
    this.needMfa = false,
  });

  final bool success;
  final String message;
  final String? nonce;
  final bool needMfa;
}
```

In `hut_user_api_auth.dart`（`part of`，用 `@visibleForTesting` 的 top-level 在 part 文件里对 library 可见——**注意**：part 文件不能有自己的 import；`@visibleForTesting` 需要 `package:flutter/foundation.dart`，主库已 import foundation）。

实现要点：

- 拼 path 时对 query 值使用 `Uri.encodeQueryComponent`
- `parseHutSmsInitResponse`：`code.toString()=='0'` 且 `data` 为 Map，读 `nonce`（亦尝试 `data['data']['nonce']` 不需要）；message 优先 `data['message']` 再 envelope `message`
- `parseHutSmsLoginTokenData`：用现有 `HutPortalSession.fromLoginData` 看 `session.token.isNotEmpty`
- `hutResponseIndicatesNeedMfa`：对 envelope 与 `data` Map 检查 key：`needMfa`、`need_mfa`、`need`（值为 true/`true`/`1`）；或 `mfaEnabled`+无 token 的保守组合——**优先明确 boolean/字符串 true**，避免误伤成功登录
- 默认失败文案：`操作失败，请稍后重试`

若 part 内 top-level 测试导入别扭，把纯函数也放在主库 `hut_user_api.dart`（`part` 之前）更干净——**推荐放主库文件底部或 `HutAuthResult` 旁**，auth mixin 只调用它们。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/utils/hut_sms_auth_helpers_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/utils/hut_user_api.dart lib/utils/hut_user_api/hut_user_api_auth.dart test/utils/hut_sms_auth_helpers_test.dart
git commit -m "$(cat <<'EOF'
feat(login): add HUT SMS auth result and pure helpers

Introduce HutAuthResult plus path builders and response parsers
for passwordless SMS login, covered by unit tests.
EOF
)"
```

---

### Task 2: `AppAuthStorage` 手机号回填

**Files:**
- Modify: `lib/core/services/app_auth_storage.dart`
- Test: `test/core/services/app_auth_storage_hut_mobile_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences`
- Produces:
  - `Future<void> saveHutMobile(String mobile)`
  - `Future<String> readHutMobile()`
  - clear 时删除 key `hutMobile`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/services/app_auth_storage.dart';

import '../../support/secure_storage_mock.dart'; // 路径按仓库现有 test/support 调整

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = AppAuthStorage.instance;

  setUpAll(SecureStorageMock.install);
  tearDownAll(SecureStorageMock.uninstall);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureStorageMock.reset();
  });

  test('saveHutMobile then readHutMobile roundtrip', () async {
    await storage.saveHutMobile('13800138000');
    expect(await storage.readHutMobile(), '13800138000');
  });

  test('clearHutCredentials removes hutMobile', () async {
    await storage.saveHutMobile('13800138000');
    await storage.saveHutSession(
      token: 't',
      refreshToken: 'r',
      deviceId: 'd',
    );
    await storage.clearHutCredentials();
    expect(await storage.readHutMobile(), isEmpty);
  });

  test('clearAllAuthData removes hutMobile', () async {
    await storage.saveHutMobile('13800138000');
    await storage.clearAllAuthData();
    expect(await storage.readHutMobile(), isEmpty);
  });
}
```

若 `SecureStorageMock` 路径不同，打开 `test/utils/auth_token_helpers_test.dart` 复制其 import/setup。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/app_auth_storage_hut_mobile_test.dart`

Expected: FAIL（方法不存在）

- [ ] **Step 3: Write minimal implementation**

在 `AppAuthStorage`：

```dart
static const _hutMobileKey = 'hutMobile';

Future<void> saveHutMobile(String mobile) async {
  final prefs = await _prefs;
  final normalized = mobile.replaceAll(' ', '').trim();
  if (normalized.isEmpty) {
    await prefs.remove(_hutMobileKey);
    return;
  }
  await prefs.setString(_hutMobileKey, normalized);
}

Future<String> readHutMobile() async {
  final prefs = await _prefs;
  return prefs.getString(_hutMobileKey) ?? '';
}
```

- `clearAllAuthData` 的 `authKeys` 列表加入 `'hutMobile'`
- `clearHutCredentials` 增加 `await prefs.remove('hutMobile');`（或 `_hutMobileKey`）

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/app_auth_storage_hut_mobile_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/app_auth_storage.dart test/core/services/app_auth_storage_hut_mobile_test.dart
git commit -m "$(cat <<'EOF'
feat(auth): persist HUT mobile for SMS login refill

Store hutMobile in SharedPreferences and clear it with HUT
and full auth wipes.
EOF
)"
```

---

### Task 3: `HutUserApi` 短信登录与 `userLoginDetailed`

**Files:**
- Modify: `lib/utils/hut_user_api.dart`（abstract core 如需声明新方法——若只在 mixin/concrete 上公开，可仅通过 `HutUserApi` 实例调用，不必改 abstract；**保持与现有 `refreshToken` 一样只在 mixin 上提供**）
- Modify: `lib/utils/hut_user_api/hut_user_api_auth.dart`
- Test: 扩展 `test/utils/hut_sms_auth_helpers_test.dart` **或** 新建 `test/utils/hut_sms_login_api_test.dart`  
  因 Dio 未注入，**本 Task 的自动化测试继续覆盖解析 + 用「可注入 http 执行器」缝**。

**Interfaces:**
- Consumes: Task 1 helpers、`AppAuthStorage`、`_createConfiguredDio`、`HutPortalSession`
- Produces:
  - `Future<HutAuthResult> smsInit()`
  - `Future<HutAuthResult> smsSend({required String mobile, required String nonce})`
  - `Future<HutAuthResult> smsLogin({required String mobile, required String smscode, required String nonce})`
  - `Future<HutAuthResult> userLoginDetailed({required String username, required String password, String mfaState = ''})`
  - `userLogin` 改为 `return (await userLoginDetailed(...)).success;`（行为与旧成功条件对齐）

为可测会话落盘，在 mixin 增加 `@visibleForTesting`：

```dart
@visibleForTesting
Future<HutAuthResult> completeSmsLoginFromResponseData({
  required dynamic responseData,
  required String mobile,
  required String deviceId,
});
```

- [ ] **Step 1: Write the failing test for session completion**

在 `test/utils/hut_sms_login_api_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/services/app_auth_storage.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../support/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = AppAuthStorage.instance;

  setUpAll(SecureStorageMock.install);
  tearDownAll(SecureStorageMock.uninstall);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureStorageMock.reset();
  });

  test('completeSmsLoginFromResponseData saves session and mobile', () async {
    final api = HutUserApi();
    final result = await api.completeSmsLoginFromResponseData(
      responseData: {
        'code': 0,
        'data': {
          'idToken': 'sms-id-token',
          'refreshToken': 'sms-refresh',
          'ticket': '',
        },
      },
      mobile: '13800138000',
      deviceId: 'abcdefghijklmnopqrstuvwx',
    );

    expect(result.success, isTrue);
    expect(await storage.readHutToken(), 'sms-id-token');
    expect(await storage.readHutRefreshToken(), 'sms-refresh');
    expect(await storage.readHutDeviceId(), 'abcdefghijklmnopqrstuvwx');
    expect(await storage.readLoginType(), 'hut');
    expect(await storage.readHutMobile(), '13800138000');
    // 验证码登录不写密码凭据
    expect(await storage.readHutUsername(), isEmpty);
  });

  test('completeSmsLoginFromResponseData fails without token', () async {
    final api = HutUserApi();
    final result = await api.completeSmsLoginFromResponseData(
      responseData: {'code': 0, 'data': {}},
      mobile: '13800138000',
      deviceId: 'abcdefghijklmnopqrstuvwx',
    );
    expect(result.success, isFalse);
    expect(await storage.readHutToken(), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/hut_sms_login_api_test.dart`

Expected: FAIL

- [ ] **Step 3: Implement network + detailed password login**

在 `_HutAuthMixin`：

```dart
static const _kHutAppId = 'com.supwisdom.hut';

Dio _loginDio() => _createConfiguredDio(
  baseUrl: _kMyCasBaseUrl,
  headers: {
    'User-Agent': _kHutLoginUserAgent,
    'Accept': '*/*',
    'Accept-Encoding': 'gzip, deflate, br',
  },
);

Future<HutAuthResult> smsInit() async {
  try {
    final response = await _loginDio().get(buildHutSmsInitPath());
    return parseHutSmsInitResponse(response.data);
  } catch (_) {
    return const HutAuthResult(success: false, message: '网络异常，请稍后重试');
  }
}

Future<HutAuthResult> smsSend({
  required String mobile,
  required String nonce,
}) async {
  final normalized = normalizeHutMobile(mobile);
  if (!isPlausibleHutMobile(normalized)) {
    return const HutAuthResult(success: false, message: '请输入正确的手机号');
  }
  try {
    final response = await _loginDio().post(
      buildHutSmsSendPath(mobile: normalized, nonce: nonce),
      data: {},
    );
    return parseHutSmsSendResponse(response.data);
  } catch (_) {
    return const HutAuthResult(success: false, message: '网络异常，请稍后重试');
  }
}

Future<HutAuthResult> smsLogin({
  required String mobile,
  required String smscode,
  required String nonce,
}) async {
  final normalized = normalizeHutMobile(mobile);
  if (!isPlausibleHutMobile(normalized)) {
    return const HutAuthResult(success: false, message: '请输入正确的手机号');
  }
  if (smscode.trim().isEmpty) {
    return const HutAuthResult(success: false, message: '请输入验证码');
  }
  final deviceId = generateDeviceIdAlphabet();
  try {
    final response = await _loginDio().post(
      buildHutSmsLoginPath(
        mobile: normalized,
        smscode: smscode.trim(),
        appId: _kHutAppId,
        deviceId: deviceId,
        osType: 'android',
        geo: '',
        nonce: nonce,
      ),
      data: {},
    );
    return completeSmsLoginFromResponseData(
      responseData: response.data,
      mobile: normalized,
      deviceId: deviceId,
    );
  } catch (_) {
    return const HutAuthResult(success: false, message: '网络异常，请稍后重试');
  }
}

@visibleForTesting
Future<HutAuthResult> completeSmsLoginFromResponseData({
  required dynamic responseData,
  required String mobile,
  required String deviceId,
}) async {
  final parsed = parseHutSmsLoginTokenData(responseData);
  if (!parsed.success) {
    return parsed;
  }
  final data = responseData is Map ? responseData['data'] : null;
  if (data is! Map) {
    return const HutAuthResult(success: false, message: '登录失败，请稍后重试');
  }
  final session = HutPortalSession.fromLoginData(data);
  final refreshToken = data['refreshToken']?.toString() ?? '';
  await _storage.saveHutSession(
    token: session.token,
    refreshToken: refreshToken,
    deviceId: deviceId,
    ticket: session.ticket,
  );
  await _storage.saveHutMobile(mobile);
  await _storage.saveLoginType('hut');
  _token['idToken'] = session.token;
  AppLogger.debug('HUT SMS login completed');
  return const HutAuthResult(success: true, message: '登录成功');
}
```

`userLoginDetailed`：

- 复用现有 URL 拼装，将 `mfaState` 编入 query（`Uri.encodeQueryComponent(mfaState)`）
- 网络失败 → `message: 网络异常，请稍后重试`
- 若 `hutResponseIndicatesNeedMfa(data)` → `success: false, needMfa: true, message: '需要二次验证，请使用验证码登录或稍后再试'`
- 成功分支与旧 `userLogin` 相同（含 `saveHutCredentials`）
- 其他失败：尽量读服务端 `message`

`userLogin`：

```dart
@override
Future<bool> userLogin({required String username, required String password}) async {
  final result = await userLoginDetailed(username: username, password: password);
  return result.success;
}
```

**不要**在 `AppLogger` 里打印 `mobile`/`smscode` 全文。

- [ ] **Step 4: Run tests**

Run:

```bash
flutter test test/utils/hut_sms_login_api_test.dart test/utils/hut_sms_auth_helpers_test.dart test/utils/auth_token_helpers_test.dart
```

Expected: PASS（含既有 getToken 回归）

- [ ] **Step 5: Commit**

```bash
git add lib/utils/hut_user_api.dart lib/utils/hut_user_api/hut_user_api_auth.dart test/utils/hut_sms_login_api_test.dart
git commit -m "$(cat <<'EOF'
feat(login): wire HUT passwordless SMS API

Add smsInit/smsSend/smsLogin and userLoginDetailed with session
persistence and needMfa detection for password login.
EOF
)"
```

---

### Task 4: `HutSmsLoginCommand`（倒计时 + 防重入）

**Files:**
- Create: `lib/login/hut_sms_login_enabled.dart`（仅常量，避免 UI/command 循环依赖）
- Create: `lib/login/hut/sms_command.dart`
- Test: `test/login/hut_sms_login_command_test.dart`

**Interfaces:**
- Consumes: `HutAuthResult`；可注入的 init/send/login 函数
- Produces:

```dart
const bool kHutSmsLoginEnabled = true;

typedef HutSmsInit = Future<HutAuthResult> Function();
typedef HutSmsSend = Future<HutAuthResult> Function({
  required String mobile,
  required String nonce,
});
typedef HutSmsLogin = Future<HutAuthResult> Function({
  required String mobile,
  required String smscode,
  required String nonce,
});

class HutSmsLoginCommand {
  HutSmsLoginCommand({
    HutSmsInit? smsInit,
    HutSmsSend? smsSend,
    HutSmsLogin? smsLogin,
    this.countdownSeconds = 60,
  });

  final int countdownSeconds;

  int get remainingSeconds; // 0 = 可发送
  bool get isSending;
  bool get isLoggingIn;
  String? get activeNonce; // @visibleForTesting
  VoidCallback? onCountdownChanged;

  Future<HutAuthResult> requestCode(String mobile);
  Future<HutAuthResult> login({
    required String mobile,
    required String smscode,
  });

  @visibleForTesting
  void debugElapseSecond();

  void dispose(); // 取消 Timer
}
```

默认实现调用 `HutUserApi().smsInit/Send/Login`。

行为：

- `requestCode`：本地校验手机号 → 若 `remainingSeconds>0` 返回失败「请稍后再获取验证码」→ 防重入（in-flight 同 `HutLoginCommand`）→ `smsInit` → 存 nonce → `smsSend` → **仅成功**启动倒计时
- `login`：无 activeNonce → 失败「请先获取验证码」；有则 `smsLogin`；失败若 message 含「过期」「失效」「无效」「expire」（大小写不敏感）则 clear nonce，并提示重新获取
- `dispose` 取消倒计时

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/login/hut/sms_command.dart';
import 'package:superhut/utils/hut_user_api.dart';

void main() {
  test('requestCode success starts countdown and stores nonce', () async {
    final command = HutSmsLoginCommand(
      countdownSeconds: 60,
      smsInit: () async => const HutAuthResult(
        success: true,
        nonce: 'n1',
      ),
      smsSend: ({required mobile, required nonce}) async {
        expect(mobile, '13800138000');
        expect(nonce, 'n1');
        return const HutAuthResult(success: true, message: 'ok');
      },
    );

    final result = await command.requestCode('13800138000');
    expect(result.success, isTrue);
    expect(command.remainingSeconds, 60);
    expect(command.activeNonce, 'n1');

    command.debugElapseSecond();
    expect(command.remainingSeconds, 59);

    command.dispose();
  });

  test('requestCode does not start countdown on send failure', () async {
    final command = HutSmsLoginCommand(
      smsInit: () async => const HutAuthResult(success: true, nonce: 'n1'),
      smsSend: ({required mobile, required nonce}) async =>
          const HutAuthResult(success: false, message: '发送过于频繁'),
    );
    final result = await command.requestCode('13800138000');
    expect(result.success, isFalse);
    expect(command.remainingSeconds, 0);
  });

  test('requestCode rejects invalid mobile without calling network', () async {
    var initCalls = 0;
    final command = HutSmsLoginCommand(
      smsInit: () async {
        initCalls++;
        return const HutAuthResult(success: true, nonce: 'n');
      },
    );
    final result = await command.requestCode('123');
    expect(result.success, isFalse);
    expect(initCalls, 0);
  });

  test('login reuses in-flight future', () async {
    final completer = Completer<HutAuthResult>();
    var loginCalls = 0;
    final command = HutSmsLoginCommand(
      smsInit: () async => const HutAuthResult(success: true, nonce: 'n1'),
      smsSend: ({required mobile, required nonce}) async =>
          const HutAuthResult(success: true),
      smsLogin: ({required mobile, required smscode, required nonce}) {
        loginCalls++;
        return completer.future;
      },
    );
    await command.requestCode('13800138000');

    final first = command.login(mobile: '13800138000', smscode: '123456');
    final second = command.login(mobile: '13800138000', smscode: '123456');
    expect(identical(first, second), isTrue);
    expect(loginCalls, 1);

    completer.complete(const HutAuthResult(success: true, message: '登录成功'));
    await Future.wait([first, second]);
    expect(loginCalls, 1);
    command.dispose();
  });

  test('login without nonce fails', () async {
    var loginCalls = 0;
    final command = HutSmsLoginCommand(
      smsLogin: ({required mobile, required smscode, required nonce}) async {
        loginCalls++;
        return const HutAuthResult(success: true);
      },
    );
    final result = await command.login(mobile: '13800138000', smscode: '1');
    expect(result.success, isFalse);
    expect(loginCalls, 0);
    command.dispose();
  });

  test('countdown elapses via debugElapseSecond', () async {
    final command = HutSmsLoginCommand(
      countdownSeconds: 3,
      smsInit: () async => const HutAuthResult(success: true, nonce: 'n1'),
      smsSend: ({required mobile, required nonce}) async =>
          const HutAuthResult(success: true),
    );
    await command.requestCode('13800138000');
    expect(command.remainingSeconds, 3);
    command.debugElapseSecond();
    expect(command.remainingSeconds, 2);
    command.debugElapseSecond();
    command.debugElapseSecond();
    expect(command.remainingSeconds, 0);
    command.dispose();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/login/hut_sms_login_command_test.dart`

Expected: FAIL

- [ ] **Step 3: Implement `sms_command.dart` + `kHutSmsLoginEnabled`**

`lib/login/hut_sms_login_enabled.dart`:

```dart
const bool kHutSmsLoginEnabled = true;
```

Command 倒计时核心：

```dart
Timer? _timer;
int remainingSeconds = 0;
VoidCallback? onCountdownChanged;

void _startCountdown() {
  _timer?.cancel();
  remainingSeconds = countdownSeconds;
  onCountdownChanged?.call();
  _timer = Timer.periodic(const Duration(seconds: 1), (_) {
    _elapseSecond();
  });
}

void _elapseSecond() {
  if (remainingSeconds <= 1) {
    remainingSeconds = 0;
    _timer?.cancel();
    _timer = null;
  } else {
    remainingSeconds -= 1;
  }
  onCountdownChanged?.call();
}

@visibleForTesting
void debugElapseSecond() => _elapseSecond();

void dispose() {
  _timer?.cancel();
  _timer = null;
}
```

另实现：`requestCode` / `login` 全文、防重入字段 `_requestInFlight` / `_loginInFlight`、默认委托 `HutUserApi`。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/login/hut_sms_login_command_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/login/hut_sms_login_enabled.dart lib/login/hut/sms_command.dart test/login/hut_sms_login_command_test.dart
git commit -m "$(cat <<'EOF'
feat(login): add HUT SMS login command with countdown

Orchestrate smsInit/send/login, enforce resend cooldown, and
guard against duplicate in-flight requests.
EOF
)"
```

---

### Task 5: `HutLoginPage` 验证码模式 UI

**Files:**
- Modify: `lib/login/hut/view.dart`
- Test: `test/login/hut_login_page_sms_test.dart`

**Interfaces:**
- Consumes: `HutSmsLoginCommand`、`kHutSmsLoginEnabled`、`AppAuthStorage.readHutMobile`、现有 `HutLoginCommand`
- Produces: 可切换的密码/验证码表单

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/hut/sms_command.dart';
import 'package:superhut/login/hut/view.dart';
import 'package:superhut/utils/hut_user_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('switches to SMS mode and requests code via command', (tester) async {
    var requestMobile = '';
    final smsCommand = HutSmsLoginCommand(
      smsInit: () async => const HutAuthResult(success: true, nonce: 'n'),
      smsSend: ({required mobile, required nonce}) async {
        requestMobile = mobile;
        return const HutAuthResult(success: true);
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HutLoginPage(smsCommand: smsCommand),
      ),
    );

    // 切换到验证码登录（按钮/Segment 文案以实现为准，测试用 find.text）
    await tester.tap(find.text('验证码登录'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '13800138000');
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(requestMobile, '13800138000');
    smsCommand.dispose();
  });
}
```

需要 `HutLoginPage` 增加可选 `HutSmsLoginCommand? smsCommand` 构造参数（与现有 `command` 对称）。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/login/hut_login_page_sms_test.dart`

Expected: FAIL

- [ ] **Step 3: Implement UI**

在 `_HutLoginPageState`：

- `enum _HutLoginMode { password, sms }`
- 若 `!kHutSmsLoginEnabled`，不显示切换，仅密码
- 验证码模式控件：手机号、验证码、获取验证码（`remainingSeconds>0` 时禁用并显示 `${remainingSeconds}s`）、登录
- `initState`：`readHutMobile` 填入手机号 controller（若用户未编辑）
- `smsCommand.onCountdownChanged = () { if (mounted) setState(() {}); }`
- dispose：controllers + `smsCommand.dispose()`
- 成功：`showAppSnackBar`「登录成功」+ `Navigator.pop`（与密码 command 一致）

保持现有视觉结构（顶栏标题、圆角卡片），只在表单区切换字段。

- [ ] **Step 4: Run tests**

Run:

```bash
flutter test test/login/hut_login_page_sms_test.dart test/login/hut_login_command_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/login/hut/view.dart test/login/hut_login_page_sms_test.dart
git commit -m "$(cat <<'EOF'
feat(login): add SMS mode to HUT login page

Allow switching between password and passwordless SMS login
with code request countdown and mobile refill.
EOF
)"
```

---

### Task 6: `UnifiedLoginPage` 验证码模式

**Files:**
- Modify: `lib/login/unified_login_page.dart`
- Modify: `test/login/unified_login_page_test.dart`（扩展）或新建 `test/login/unified_login_page_sms_test.dart`

**Interfaces:**
- Consumes: `HutSmsLoginCommand` / `HutUserApi.sms*`、`kHutSmsLoginEnabled`、`readHutMobile`
- Produces: 统一登录页可走短信登录；成功后仍尝试拉取 JWXT 凭据（与现密码成功路径一致）。若短信登录后 JWXT 桥接失败，保持现有 fallback 到官方 WebView 登录的行为。

- [ ] **Step 1: Write the failing test**

覆盖：

1. 存在「验证码登录」入口（flag 开）
2. 注入 `loginWithSms` 或 sms command 成功后会走到 finish/home **或** 至少调用注入的 sms login 成功回调  

因 unified 页逻辑较重，优先测：

- 切换模式后「获取验证码」调用注入依赖
- `kHutSmsLoginEnabled` 相关：可用 override 困难则只测开启态

增加构造参数（与现有 inject 风格一致）：

```dart
final HutSmsLoginCommand? smsCommand;
// 或
final Future<HutAuthResult> Function({
  required String mobile,
  required String smscode,
})? loginWithHutSms;
final Future<HutAuthResult> Function(String mobile)? requestHutSmsCode;
```

**推荐**直接注入 `HutSmsLoginCommand?`，与 Hut 页一致，减少重复 API。

成功路径：`smsCommand.login` success → 现有 `_loadJwxtCredentials` → 失败则 `_tryOfficialJwxtLogin` → 成功 `_finishLogin`。

密码路径可选增强：若将来改用 `userLoginDetailed`，`needMfa` 时 SnackBar 引导「请使用验证码登录」——**本 Task 应用 `userLoginDetailed` 替换 unified 内直接 `userLogin` 布尔判断**，以便 Phase 1 needMfa 文案达标：

```dart
final detailed = await HutUserApi().userLoginDetailed(
  username: username,
  password: password,
);
if (detailed.needMfa) {
  _showSnackBar(
    detailed.message.isNotEmpty
        ? detailed.message
        : '需要二次验证，请使用验证码登录',
    type: AppSnackBarType.warning,
  );
  return;
}
if (!detailed.success) {
  await _tryOfficialJwxtLogin('智慧工大登录失败，正在切换到教务系统官方登录...');
  return;
}
// 其后保持现有 JWXT 凭据拉取与 _finishLogin
```

通过 `UnifiedLoginAuthenticator` 仍返回 bool 的旧 inject 保持兼容；仅默认路径用 detailed。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/login/unified_login_page_sms_test.dart`

- [ ] **Step 3: Implement**

- 模式切换 UI（文案与 Hut 页一致：「账号密码」/「验证码登录」）
- 回填 `readHutMobile`
- 接线 sms command
- 默认密码登录改 detailed + needMfa 提示
- dispose sms command / timer

- [ ] **Step 4: Run regression**

```bash
flutter test test/login/
```

Expected: 全部 PASS

- [ ] **Step 5: Commit**

```bash
git add lib/login/unified_login_page.dart test/login/unified_login_page_sms_test.dart test/login/unified_login_page_test.dart
git commit -m "$(cat <<'EOF'
feat(login): support HUT SMS login on unified page

Add passwordless SMS mode, mobile refill, and clearer needMfa
messaging on the password path.
EOF
)"
```

---

### Task 7: 静态分析、全量相关测试与联调清单核对

**Files:**
- 无新功能文件；可能小修 analyze 问题

- [ ] **Step 1: Format & analyze**

```bash
dart format lib/login lib/utils/hut_user_api.dart lib/utils/hut_user_api/hut_user_api_auth.dart lib/core/services/app_auth_storage.dart test/login test/utils test/core/services/app_auth_storage_hut_mobile_test.dart
flutter analyze lib/login lib/utils/hut_user_api.dart lib/utils/hut_user_api/hut_user_api_auth.dart lib/core/services/app_auth_storage.dart
```

Expected: 无 error（warning 按项目惯例处理）

- [ ] **Step 2: Run focused suite**

```bash
flutter test \
  test/utils/hut_sms_auth_helpers_test.dart \
  test/utils/hut_sms_login_api_test.dart \
  test/core/services/app_auth_storage_hut_mobile_test.dart \
  test/login/hut_sms_login_command_test.dart \
  test/login/hut_login_page_sms_test.dart \
  test/login/hut_login_command_test.dart \
  test/login/unified_login_page_test.dart \
  test/utils/auth_token_helpers_test.dart
```

Expected: All PASS

- [ ] **Step 3: Manual checklist（实现者本地，不进 CI）**

按 spec「手工联调清单」勾选：

1. `smsInit` 活体
2. 真机 `smsSend` 收信
3. `smsLogin` 后门户类功能
4. 杀进程手机号回填
5. 登出清除 `hutMobile` + session

- [ ] **Step 4: Final commit only if analyze fixes landed**

```bash
git add -u
git status
# 若有修复：
git commit -m "$(cat <<'EOF'
chore(login): tidy SMS login analyze findings
EOF
)"
```

---

## Phase 2（本计划不实现，仅登记）

- `mfa/detect`、`mfa/initByType/`、安全手机发码/校验 UI
- `passwordLogin(mfaState:)` 闭环
- 短信登录用户的 `refreshToken`：当前 `refreshToken()` 依赖用户名密码，SMS-only 会话需另策（refresh token API 或强制重新验证码登录）
- 按需抓包补 header / 错误码字典
- 远程关闭 `authenticationSmsCodeEnabled` 时的动态藏入口

---

## Self-Review（写作时已核对）

| Spec 项 | Task |
|---------|------|
| smsInit/send/login 协议与 query | T1 + T3 |
| HutAuthResult | T1 |
| saveHutSession + saveLoginType + saveHutMobile | T2 + T3 |
| 不 saveHutCredentials（SMS） | T3 测试断言 |
| HutSmsLoginCommand 倒计时/防重入 | T4 |
| HutLoginPage + UnifiedLoginPage | T5 + T6 |
| needMfa Phase1 文案 | T3 + T6 |
| 测试分层、CI 不发真短信 | 各 Task mock |
| kHutSmsLoginEnabled 回退 | T4 常量 + T5/T6 隐藏入口 |
| MFA 完整流 | Phase 2 登记，无实现 Task |

**类型一致性：** `HutAuthResult` 字段贯穿 T1–T6；存储 key 固定 `hutMobile`；path 助手与 mixin 共用。

**无占位符：** 各 Step 含命令、期望、关键代码；widget 文案以「验证码登录」「获取验证码」为约定，实现不得随意改测试找不到的文案（若改 UI 文案须同步测试）。
