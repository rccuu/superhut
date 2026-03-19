part of '../hut_user_api.dart';

mixin _HutSessionMixin on _HutUserApiCore {
  @override
  Future<List> getOpenid() async {
    final token = await getToken();
    const url = 'https://v8mobile.hut.edu.cn/zdRedirect/toSingleMenu';
    final options = _createNoCacheOptions(_request);
    options.headers = {'X-Id-Token': token};
    final params = <String, dynamic>{'code': 'openWater', 'token': token};

    return _request.get(url, params: params, options: options).then((value) {
      if (value.data != '') {
        return [];
      }

      final setCookieHeader = value.headers['set-cookie'];
      final cookieString = setCookieHeader?.firstWhere(
        (cookie) => cookie.startsWith('JSESSIONID='),
        orElse: () => '',
      );

      String jSessionId = '';
      final parts = cookieString?.split(';');
      jSessionId =
          parts![0].split('=').length > 1 ? parts[0].split('=')[1] : '';

      final location = value.headers.value('location')!;
      return [location.split('openid=')[1], jSessionId];
    });
  }

  @override
  Future<_HutOpenIdSession> _getOpenIdSession() async {
    final openIdData = await getOpenid();
    return _HutOpenIdSession(openid: openIdData[0], jSessionId: openIdData[1]);
  }
}
