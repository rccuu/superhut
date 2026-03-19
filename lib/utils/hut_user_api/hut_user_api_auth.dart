part of '../hut_user_api.dart';

mixin _HutAuthMixin on _HutUserApiCore {
  String generateDeviceIdAlphabet() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random.secure();
    return List.generate(
      24,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  String generateJSessionId() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join();
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
    if (data.keys.first != 'code') {
      return false;
    }

    final tokenData = data['data'];
    final idToken = tokenData['idToken'];
    final refreshToken = tokenData['refreshToken'];
    await _storage.saveHutSession(
      token: idToken,
      refreshToken: refreshToken,
      deviceId: deviceId,
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
      _token['idToken'] = storedToken;
    }
    return _token['idToken'];
  }

  @override
  Future<bool> checkTokenValidity() async {
    final token = await getToken();
    final deviceId = await _storage.readHutDeviceId();
    final username = await _storage.readHutUsername();
    final url =
        '/token/login/userOnlineDetect?appId=com.supwisdom.hut'
        '&deviceId=${deviceId.isEmpty ? 'null' : deviceId}&username=$username';
    final dio = _createConfiguredDio(
      baseUrl: _kMyCasBaseUrl,
      headers: {
        'User-Agent': _kBrowserUserAgent,
        'Accept': '*/*',
        'Accept-Encoding': 'gzip, deflate, br',
        'X-Id-Token': token,
      },
    );
    final response = await dio.post(url, data: {});
    final data = response.data;
    return data['code'] == 0;
  }

  Future<bool> refreshToken() async {
    final userName = await _storage.readHutUsername();
    final orgPassword = await _storage.readHutPassword();
    if (userName.isEmpty || orgPassword.isEmpty) {
      return false;
    }
    await userLogin(username: userName, password: orgPassword);
    return true;
  }
}
