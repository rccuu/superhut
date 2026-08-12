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
  }) async {
    final parsed = parseHutSmsLoginTokenData(responseData);
    if (!parsed.success) {
      return parsed;
    }
    final data = responseData is Map ? responseData['data'] : null;
    if (data is! Map) {
      return const HutAuthResult(success: false, message: '登录失败，请稍后重试');
    }
    // Official SMS login success handler (sub_100079334 / vercodeLoginSuccess)
    // stores data.idToken VERBATIM into kToken — it does NOT call
    // federation/federatedBinding (that is SWLHBindController for third-party
    // federated login, not SMS). We previously inserted a federatedBinding
    // call here, which mycas rejected as "exception.federated.login.state.invalid"
    // because no federated session exists for SMS.
    //
    // CRITICAL: store the RAW data.idToken, not a JWT-decoded variant.
    // HutPortalSession.fromLoginData decodes JWT payloads and may return an
    // embedded idToken that differs from the one mycas issued; persisting that
    // makes checkTokenValidity / CAS send the wrong token → "登录状态已失效".
    final idToken = data['idToken']?.toString().trim() ?? '';
    if (idToken.isEmpty) {
      return const HutAuthResult(success: false, message: '登录失败，请稍后重试');
    }
    final refreshToken = data['refreshToken']?.toString().trim() ?? '';
    final ticket = data['ticket']?.toString().trim() ?? '';
    await _storage.saveHutSession(
      token: idToken,
      refreshToken: refreshToken,
      deviceId: deviceId,
      ticket: ticket,
    );
    await _storage.saveHutMobile(mobile);
    // Persist the mycas account id (JWT `sub`) so checkTokenValidity can run
    // userOnlineDetect for this SMS session without a stored username — mirror
    // the official client, which decodes only the `sub` claim for that check.
    await _storage.saveHutAccount(extractHutJwtSubject(idToken) ?? '');
    // Clear any leftover password credentials from a prior password login so
    // checkTokenValidity/refreshToken don't reuse a stale username with the
    // fresh SMS token (which would falsely invalidate the session on account
    // switch). Mark the auth method explicitly instead of inferring it.
    await _storage.clearHutPasswordCredentials();
    await _storage.saveHutAuthMethod(kHutAuthMethodSms);
    await _storage.saveLoginType('hut');
    _token['idToken'] = idToken;
    AppLogger.debug('HUT SMS login completed');
    return const HutAuthResult(success: true, message: '登录成功');
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
    await _storage.saveHutAuthMethod(kHutAuthMethodPassword);
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
    final token = await getToken();
    if (token.isEmpty) {
      return false;
    }

    // Branch on the explicit auth-method marker. Fall back to inferring from
    // hutUsername for sessions persisted before hutAuthMethod existed, so the
    // migration is transparent.
    final username = await _storage.readHutUsername();
    final authMethod = await _storage.readHutAuthMethod();
    final resolvedMethod = authMethod.isNotEmpty
        ? authMethod
        : (username.trim().isNotEmpty
              ? kHutAuthMethodPassword
              : kHutAuthMethodSms);

    // Fail-fast local gate: an expired or malformed SMS JWT is invalid before
    // it ever reaches the server.
    if (resolvedMethod == kHutAuthMethodSms && isHutJwtExpired(token)) {
      return false;
    }

    // The account mycas's userOnlineDetect validates against. Password
    // sessions use the persisted username; SMS sessions persist `hutAccount`
    // (the JWT `sub`, mirroring the official client which decodes only that
    // claim for this check). Migrate a legacy SMS session that predates
    // hutAccount by extracting sub from the token itself.
    var account = resolvedMethod == kHutAuthMethodSms
        ? await _storage.readHutAccount()
        : username;
    if (resolvedMethod == kHutAuthMethodSms && account.trim().isEmpty) {
      account = extractHutJwtSubject(token) ?? '';
      if (account.isNotEmpty) {
        await _storage.saveHutAccount(account);
      }
    }
    if (account.trim().isEmpty) {
      return false;
    }

    final deviceId = await _storage.readHutDeviceId();
    final validator = _onlineTokenValidator;
    if (validator != null) {
      return validator(
        token: token,
        account: account.trim(),
        deviceId: deviceId.isEmpty ? 'null' : deviceId,
      );
    }

    // Server-side verdict. No try/catch here on purpose: a transport failure
    // must propagate so refreshToken keeps the session (transient network ≠
    // logged out) and the caller's own error handling surfaces it.
    final url =
        '/token/login/userOnlineDetect?appId=com.supwisdom.hut'
        '&deviceId=${deviceId.isEmpty ? 'null' : deviceId}'
        '&username=${Uri.encodeQueryComponent(account.trim())}';
    final dio = _createConfiguredDio(
      baseUrl: _kMyCasBaseUrl,
      headers: {
        'User-Agent': _kHutLoginUserAgent,
        'Accept': '*/*',
        'Accept-Encoding': 'gzip, deflate, br',
        'X-Id-Token': token,
        // Official YYRequestManger injects X-Device-Infos on every request.
        'X-Device-Infos':
            'packagename=$_kHutAppId;version=$_kHutAppVersion;system=iOS',
      },
    );
    final response = await dio.post(url, data: {});
    final data = response.data;
    return data is Map && data['code']?.toString() == '0';
  }

  Future<bool> refreshToken() async {
    final userName = await _storage.readHutUsername();
    final orgPassword = await _storage.readHutPassword();

    // SMS/passwordless sessions have no stored password to re-login with. The
    // SMS token is long-lived (official research shows it never expires), so
    // there is no refresh network path. Unify with checkTokenValidity: local
    // JWT expiry is a fail-fast, then an online userOnlineDetect verdict
    // decides. Only a definite invalid verdict clears the session — a network
    // failure propagates from checkTokenValidity so a transient blip doesn't
    // sign the user out.
    if (userName.isEmpty || orgPassword.isEmpty) {
      final authMethod = await _storage.readHutAuthMethod();
      if (authMethod == kHutAuthMethodSms) {
        final isValid = await checkTokenValidity();
        if (!isValid) {
          await _storage.clearHutSessionState();
          _token['idToken'] = '';
          return false;
        }
        return true;
      }
      return false;
    }
    return userLogin(username: userName, password: orgPassword);
  }
}
