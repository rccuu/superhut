part of '../hut_user_api.dart';

mixin _HutAuthMixin on _HutUserApiCore {
  static const _hexLowerDigits = '0123456789abcdef';
  static const _hexUpperDigits = '0123456789ABCDEF';
  static const _kHutAppId = 'com.supwisdom.hut';

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
      response = await _loginDio().post(loginUrl, data: {});
    } catch (_) {
      return const HutAuthResult(success: false, message: '网络异常，请稍后重试');
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
      final username = await _storage.readHutUsername();
      final url =
          '/token/login/userOnlineDetect?appId=com.supwisdom.hut'
          '&deviceId=${deviceId.isEmpty ? 'null' : deviceId}&username=$username';
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
      return false;
    }
    return userLogin(username: userName, password: orgPassword);
  }
}
