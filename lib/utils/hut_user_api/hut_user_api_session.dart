part of '../hut_user_api.dart';

mixin _HutSessionMixin on _HutUserApiCore {
  @override
  Future<List<String>> getOpenid() async {
    final token = await getToken();
    const url = 'https://v8mobile.hut.edu.cn/zdRedirect/toSingleMenu';
    final options = _createNoCacheOptions(_request);
    options.headers = {'X-Id-Token': token};
    final params = <String, dynamic>{'code': 'openWater', 'token': token};

    final response = await _request.get(url, params: params, options: options);
    final responseBody = response.data?.toString().trim() ?? '';
    if (responseBody.isNotEmpty) {
      throw StateError('校园服务跳转失败，请重新登录后重试');
    }

    final setCookieHeader = response.headers['set-cookie'] ?? const [];
    final jSessionId = _extractJSessionId(setCookieHeader);
    if (jSessionId.isEmpty) {
      throw StateError('未获取到校园服务会话，请稍后重试');
    }

    final location = response.headers.value('location');
    if (location == null || location.isEmpty) {
      throw StateError('未获取到校园服务跳转地址，请稍后重试');
    }

    final openid = _extractOpenIdFromLocation(location);
    if (openid.isEmpty) {
      throw StateError('未获取到校园服务身份信息，请稍后重试');
    }

    return [openid, jSessionId];
  }

  @override
  Future<_HutOpenIdSession> _getOpenIdSession() async {
    final openIdData = await getOpenid();
    return _HutOpenIdSession(openid: openIdData[0], jSessionId: openIdData[1]);
  }
}

String _extractJSessionId(List<String> setCookieHeader) {
  const prefix = 'JSESSIONID=';
  for (final cookie in setCookieHeader) {
    if (!cookie.startsWith(prefix)) {
      continue;
    }
    final endIndex = cookie.indexOf(';', prefix.length);
    return cookie.substring(
      prefix.length,
      endIndex == -1 ? cookie.length : endIndex,
    );
  }
  return '';
}

String _extractOpenIdFromLocation(String location) {
  final openid = Uri.tryParse(location)?.queryParameters['openid'];
  if (openid != null) {
    return openid;
  }

  const parameter = 'openid=';
  final startIndex = location.indexOf(parameter);
  if (startIndex == -1) {
    return '';
  }

  final valueStart = startIndex + parameter.length;
  var valueEnd = valueStart;
  while (valueEnd < location.length) {
    final codeUnit = location.codeUnitAt(valueEnd);
    if (codeUnit == 0x26 || codeUnit == 0x23) {
      break;
    }
    valueEnd++;
  }
  return location.substring(valueStart, valueEnd);
}
