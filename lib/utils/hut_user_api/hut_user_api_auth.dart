part of '../hut_user_api.dart';

mixin _HutAuthMixin on _HutUserApiCore {
  static const _hexLowerDigits = '0123456789abcdef';
  static const _hexUpperDigits = '0123456789ABCDEF';

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

  @override
  Future<bool> userLogin({
    required String username,
    required String password,
  }) async {
    final passwordBase = Uri.encodeComponent(password);
    final deviceId = generateDeviceIdAlphabet();
    final clientId = generateUuidV4();
    final loginUrl =
        '/token/password/passwordLogin?username=$username&password=$passwordBase'
        '&appId=com.supwisdom.hut&geo&deviceId=$deviceId&osType=android'
        '&clientId=$clientId&mfaState';
    final dio = _createConfiguredDio(
      baseUrl: _kMyCasBaseUrl,
      headers: {
        'User-Agent': _kHutLoginUserAgent,
        'Accept': '*/*',
        'Accept-Encoding': 'gzip, deflate, br',
      },
    );

    Response response;
    try {
      response = await dio.post(loginUrl, data: {});
    } catch (_) {
      return false;
    }

    final data = response.data;
    if (data is! Map ||
        data['code']?.toString() != '0' ||
        data['data'] is! Map) {
      return false;
    }

    final tokenData = data['data'] as Map;
    final session = HutPortalSession.fromLoginData(tokenData);
    final refreshToken = tokenData['refreshToken']?.toString() ?? '';
    if (session.token.isEmpty) {
      return false;
    }
    await _storage.saveHutSession(
      token: session.token,
      refreshToken: refreshToken,
      deviceId: deviceId,
      ticket: session.ticket,
    );
    await _storage.saveHutCredentials(username: username, password: password);
    await _storage.saveLoginType('hut');
    AppLogger.debug('HUT login completed');
    return true;
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
