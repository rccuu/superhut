part of '../hut_user_api.dart';

mixin _HutAuthMixin on _HutUserApiCore {
  static const _hexLowerDigits = '0123456789abcdef';
  static const _hexUpperDigits = '0123456789ABCDEF';
  static const _kHutAppId = 'com.supwisdom.hut';
  // Matches the official iOS client's CFBundleShortVersionString, surfaced in
  // the X-Device-Infos header that YYRequestManger injects on every request.
  static const _kHutAppVersion = '1.1.8';

  String generateDeviceIdAlphabet() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var index = 0; index < 24; index++) {
      buffer.write(chars[random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  String generateUuidV4() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (var index = 0; index < bytes.length; index++) {
      bytes[index] = random.nextInt(256);
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    return _hexBytes(bytes, _hexLowerDigits);
  }

  String generateJSessionId() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return _hexBytes(bytes, _hexUpperDigits);
  }

  String _hexBytes(Uint8List bytes, String digits) {
    final buffer = StringBuffer();
    for (var index = 0; index < bytes.length; index++) {
      final byte = bytes[index];
      buffer
        ..write(digits[byte >> 4])
        ..write(digits[byte & 0x0F]);
    }
    return buffer.toString();
  }

  Future<String> getFingerprint() async {
    final uuid = const Uuid();
    return uuid.v4().replaceAll('-', '');
  }

  Dio _loginDio() => _createConfiguredDio(
    baseUrl: _kMyCasBaseUrl,
    // SMS gateway + mycas can exceed the default 3s receive window.
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': _kHutLoginUserAgent,
      // Match official mini-program / wexinRequest headers for passwordless.
      'Accept': 'application/json',
      'Accept-Language': 'zh-CN',
      'Content-Type': 'application/x-www-form-urlencoded',
      // Official YYRequestManger injects X-Device-Infos on every request:
      // "packagename=<bundleId>;version=<appVersion>;system=iOS". mycas uses
      // it for origin/device validation; omitting it can make federatedBinding
      // reject the session as "exception.federated.login.state.invalid".
      'X-Device-Infos':
          'packagename=$_kHutAppId;version=$_kHutAppVersion;system=iOS',
    },
    // Business failures (wrong code, invalid nonce, unbound mobile, …) are
    // often returned as HTTP 4xx/5xx with a JSON body. Accept them so callers
    // can parse `code`/`error`/`message` instead of collapsing to "网络异常".
    validateStatus: (status) => status != null && status < 600,
  );

  HutAuthResult _authResultFromCaughtError(Object error) {
    if (error is DioException) {
      return hutAuthResultFromTransportError(
        statusCode: error.response?.statusCode,
        responseData: error.response?.data,
      );
    }
    return hutAuthResultFromTransportError();
  }

  Future<HutAuthResult> smsInit() async {
    try {
      final response = await _loginDio().get(buildHutSmsInitPath());
      return parseHutSmsInitResponse(response.data);
    } catch (error) {
      return _authResultFromCaughtError(error);
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
        // Official client posts form-urlencoded with empty body; params are query.
        data: '',
      );
      return parseHutSmsSendResponse(response.data);
    } catch (error) {
      return _authResultFromCaughtError(error);
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
    // Match the official iOS client (reverse-engineered from SWUserModel):
    //   * osType must be "iOS" — we previously sent "android" which the mycas
    //     SSO origin/device check can reject before issuing a usable session.
    //   * clientId defaults to "CLIENT_ID" when the app has not persisted one.
    //   * deviceId mirrors the officially generated UUID.
    final deviceId = generateUuidV4();
    try {
      final response = await _loginDio().post(
        buildHutSmsLoginPath(
          mobile: normalized,
          smscode: smscode.trim(),
          appId: _kHutAppId,
          deviceId: deviceId,
          osType: 'iOS',
          geo: '',
          nonce: nonce,
          clientId: 'CLIENT_ID',
        ),
        data: '',
      );
      return completeSmsLoginFromResponseData(
        responseData: response.data,
        mobile: normalized,
        deviceId: deviceId,
        nonce: nonce,
      );
    } catch (error) {
      return _authResultFromCaughtError(error);
    }
  }

  @visibleForTesting
  Future<HutAuthResult> completeSmsLoginFromResponseData({
    required dynamic responseData,
    required String mobile,
    required String deviceId,
    String? nonce,
    Future<({HutAuthResult? result, dynamic data})> Function({
      required String idToken,
      required String nonce,
    })?
    federatedBinding,
  }) async {
    final parsed = parseHutSmsLoginTokenData(responseData);
    if (!parsed.success) {
      return parsed;
    }
    final data = responseData is Map ? responseData['data'] : null;
    if (data is! Map) {
      return const HutAuthResult(success: false, message: '登录失败，请稍后重试');
    }
    // smsLogin returns an INTERMEDIATE idToken. The official iOS client then
    // POSTs /token/federation/federatedBinding with that idToken (X-Id-Token)
    // and the smsInit nonce to mint the FINAL session token. Without this
    // step mycas rejects the session as invalid ("登录状态已失效").
    //
    // CRITICAL: federatedBinding must receive the RAW smsLogin data.idToken,
    // not a JWT-decoded/transformed variant. HutPortalSession.fromLoginData
    // decodes JWT payloads and may return an embedded idToken that differs
    // from the one mycas issued for this SMS session; sending that to
    // federatedBinding yields "exception.federated.login.state.invalid".
    final intermediateToken = data['idToken']?.toString().trim() ?? '';
    if (intermediateToken.isEmpty) {
      return const HutAuthResult(success: false, message: '登录失败，请稍后重试');
    }
    final binding =
        await (federatedBinding ?? _smsFederatedBinding)(
          idToken: intermediateToken,
          nonce: nonce ?? '',
        );
    if (binding.result != null) {
      return binding.result!;
    }
    final bindingData = binding.data;
    if (bindingData is! Map) {
      return const HutAuthResult(success: false, message: '登录失败，请稍后重试');
    }
    final session = HutPortalSession.fromLoginData(bindingData);
    final refreshToken = bindingData['refreshToken']?.toString() ?? '';
    await _storage.saveHutSession(
      token: session.token,
      refreshToken: refreshToken,
      deviceId: deviceId,
      ticket: session.ticket,
    );
    await _storage.saveHutMobile(mobile);
    await _storage.saveLoginType('hut');
    _token['idToken'] = session.token;
    AppLogger.debug('HUT SMS login completed (federatedBinding)');
    return const HutAuthResult(success: true, message: '登录成功');
  }

  /// Calls `/token/federation/federatedBinding` to exchange the intermediate
  /// `smsLogin` idToken for the final HUT session token. On success returns
  /// the response `data` map; on failure returns a non-null [HutAuthResult].
  @visibleForTesting
  Future<({HutAuthResult? result, dynamic data})> smsFederatedBinding({
    required String idToken,
    required String nonce,
  }) => _smsFederatedBinding(idToken: idToken, nonce: nonce);

  Future<({HutAuthResult? result, dynamic data})> _smsFederatedBinding({
    required String idToken,
    required String nonce,
  }) async {
    if (idToken.isEmpty) {
      return (
        result: const HutAuthResult(success: false, message: '登录失败，请稍后重试'),
        data: null,
      );
    }
    try {
      final response = await _loginDio().post(
        buildHutFederatedBindingPath(),
        data: 'nonce=${Uri.encodeQueryComponent(nonce)}',
        options: Options(headers: {'X-Id-Token': idToken}),
      );
      final parsed = parseHutSmsLoginTokenData(response.data);
      if (!parsed.success) {
        return (result: parsed, data: null);
      }
      final data = response.data is Map ? response.data['data'] : null;
      if (data is! Map) {
        return (
          result: const HutAuthResult(success: false, message: '登录失败，请稍后重试'),
          data: null,
        );
      }
      return (result: null, data: data);
    } catch (error) {
      return (result: _authResultFromCaughtError(error), data: null);
    }
  }

  Future<HutAuthResult> userLoginDetailed({
    required String username,
    required String password,
    String mfaState = '',
  }) async {
    final passwordBase = Uri.encodeComponent(password);
    final deviceId = generateDeviceIdAlphabet();
    final clientId = generateUuidV4();
    final loginUrl =
        '/token/password/passwordLogin?username=$username&password=$passwordBase'
        '&appId=$_kHutAppId&geo&deviceId=$deviceId&osType=android'
        '&clientId=$clientId&mfaState=${Uri.encodeQueryComponent(mfaState)}';

    Response response;
    try {
      // passwordLogin historically used empty JSON body; keep empty body with
      // the shared form-urlencoded content-type (server accepts both).
      response = await _loginDio().post(loginUrl, data: '');
    } catch (error) {
      return _authResultFromCaughtError(error);
    }

    final data = response.data;
    if (data is! Map) {
      return const HutAuthResult(success: false, message: '登录失败，请稍后重试');
    }

    if (hutResponseIndicatesNeedMfa(data)) {
      return const HutAuthResult(
        success: false,
        needMfa: true,
        message: '需要二次验证，请使用验证码登录或稍后再试',
      );
    }

    if (data['code']?.toString() != '0' || data['data'] is! Map) {
      final payload = data['data'];
      final payloadMap =
          payload is Map ? Map<dynamic, dynamic>.from(payload) : null;
      return HutAuthResult(
        success: false,
        message: _hutAuthMessage(Map<dynamic, dynamic>.from(data), payloadMap),
      );
    }

    final tokenData = data['data'] as Map;
    final session = HutPortalSession.fromLoginData(tokenData);
    final refreshToken = tokenData['refreshToken']?.toString() ?? '';
    if (session.token.isEmpty) {
      final payloadMap = Map<dynamic, dynamic>.from(tokenData);
      return HutAuthResult(
        success: false,
        message: _hutAuthMessage(Map<dynamic, dynamic>.from(data), payloadMap),
      );
    }

    await _storage.saveHutSession(
      token: session.token,
      refreshToken: refreshToken,
      deviceId: deviceId,
      ticket: session.ticket,
    );
    await _storage.saveHutCredentials(username: username, password: password);
    await _storage.saveLoginType('hut');
    _token['idToken'] = session.token;
    AppLogger.debug('HUT login completed');
    return const HutAuthResult(success: true, message: '登录成功');
  }

  @override
  Future<bool> userLogin({
    required String username,
    required String password,
  }) async {
    final result = await userLoginDetailed(
      username: username,
      password: password,
    );
    return result.success;
  }

  @override
  Future<String> getToken() async {
    final storedToken = await _storage.readHutToken();
    if (storedToken.isNotEmpty) {
      final session = HutPortalSession.fromTicketCandidate(storedToken);
      _token['idToken'] = session.token;
      if (session.hasTicket && session.token != storedToken) {
        await _storage.saveHutSession(
          token: session.token,
          refreshToken: await _storage.readHutRefreshToken(),
          deviceId: await _storage.readHutDeviceId(),
          ticket: session.ticket,
        );
      }
    }
    return _token['idToken'];
  }

  @override
  Future<String> getPortalTicket() async {
    final storedTicket = await _storage.readHutTicket();
    if (storedTicket.isNotEmpty) {
      return storedTicket;
    }

    final storedToken = await _storage.readHutToken();
    if (storedToken.isEmpty) {
      return '';
    }

    final session = HutPortalSession.fromTicketCandidate(storedToken);
    if (!session.hasTicket) {
      return '';
    }

    await _storage.saveHutSession(
      token: session.token,
      refreshToken: await _storage.readHutRefreshToken(),
      deviceId: await _storage.readHutDeviceId(),
      ticket: session.ticket,
    );
    _token['idToken'] = session.token;
    return session.ticket;
  }

  @override
  Future<bool> checkTokenValidity() async {
    try {
      final token = await getToken();
      if (token.isEmpty) {
        return false;
      }

      final deviceId = await _storage.readHutDeviceId();
      // SMS sessions never persist hutUsername; fall back to the bound mobile
      // so onlineDetect does not reject an empty username and falsely mark a
      // freshly minted SMS idToken as invalid.
      final username = resolveHutOnlineDetectUsername(
        await _storage.readHutUsername(),
        await _storage.readHutMobile(),
      );
      final url =
          '/token/login/userOnlineDetect?appId=com.supwisdom.hut'
          '&deviceId=${deviceId.isEmpty ? 'null' : deviceId}&username=${Uri.encodeQueryComponent(username)}';
      final dio = _createConfiguredDio(
        baseUrl: _kMyCasBaseUrl,
        headers: {
          'User-Agent': _kHutLoginUserAgent,
          'Accept': '*/*',
          'Accept-Encoding': 'gzip, deflate, br',
          'X-Id-Token': token,
        },
      );
      final response = await dio.post(url, data: {});
      final data = response.data;
      return data is Map && data['code']?.toString() == '0';
    } catch (error, stackTrace) {
      AppLogger.error(
        'HUT token validation failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<bool> refreshToken() async {
    final userName = await _storage.readHutUsername();
    final orgPassword = await _storage.readHutPassword();
    if (userName.isEmpty || orgPassword.isEmpty) {
      // SMS/passwordless sessions have no stored password to re-login with.
      // Return false so callers fall back to the (still-valid) token or a CAS
      // retry rather than crashing into "登录状态已失效". A real
      // jwt/token/refreshToken path for SMS-only refresh is Phase 2.
      return false;
    }
    return userLogin(username: userName, password: orgPassword);
  }
}
