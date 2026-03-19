part of '../hut_user_api.dart';

mixin _HutSessionMixin on _HutUserApiCore {
  @override
  Future<List<String>> getOpenid() async {
    final token = await getToken();
    const url = 'https://v8mobile.hut.edu.cn/zdRedirect/toSingleMenu';
    final options = _createNoCacheOptions(_request);
    options.headers = {'X-Id-Token': token};
    final params = <String, dynamic>{'code': 'openWater', 'token': token};

    return _request.get(url, params: params, options: options).then((value) {
      final responseBody = value.data?.toString().trim() ?? '';
      if (responseBody.isNotEmpty) {
        throw StateError('校园服务跳转失败，请重新登录后重试');
      }

      final setCookieHeader = value.headers['set-cookie'] ?? const [];
      final cookieString = setCookieHeader.firstWhere(
        (cookie) => cookie.startsWith('JSESSIONID='),
        orElse: () => '',
      );
      final jSessionId = cookieString
          .split(';')
          .firstWhere(
            (part) => part.startsWith('JSESSIONID='),
            orElse: () => '',
          )
          .replaceFirst('JSESSIONID=', '');
      if (jSessionId.isEmpty) {
        throw StateError('未获取到校园服务会话，请稍后重试');
      }

      final location = value.headers.value('location');
      if (location == null || location.isEmpty) {
        throw StateError('未获取到校园服务跳转地址，请稍后重试');
      }

      final openid =
          Uri.tryParse(location)?.queryParameters['openid'] ??
          (location.contains('openid=') ? location.split('openid=').last : '');
      if (openid.isEmpty) {
        throw StateError('未获取到校园服务身份信息，请稍后重试');
      }

      return [openid, jSessionId];
    });
  }

  @override
  Future<_HutOpenIdSession> _getOpenIdSession() async {
    final openIdData = await getOpenid();
    return _HutOpenIdSession(openid: openIdData[0], jSessionId: openIdData[1]);
  }
}
