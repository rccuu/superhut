part of '../hut_user_api.dart';

mixin _HutWaterMixin on _HutUserApiCore {
  Options _buildV8RequestOptions({
    required _HutOpenIdSession session,
    required String token,
    required String referer,
    bool includeOpenIdHeader = false,
  }) {
    final options = _createNoCacheOptions(_request);
    options.headers = _buildV8MobileHeaders(
      session: session,
      token: token,
      referer: referer,
      includeOpenIdHeader: includeOpenIdHeader,
    );
    return options;
  }

  Dio _buildV8MobileDio({
    required _HutOpenIdSession session,
    required String token,
    required String referer,
  }) {
    return _createConfiguredDio(
      baseUrl: _kV8MobileBaseUrl,
      headers: _buildV8MobileHeaders(
        session: session,
        token: token,
        referer: referer,
      ),
      followRedirects: true,
      validateStatus: _defaultValidateStatus,
    );
  }

  Future<Map<String, dynamic>> getHotWaterDevice() async {
    final token = await getToken();
    final session = await _getOpenIdSession();
    final dio = _buildV8MobileDio(
      session: session,
      token: token,
      referer:
          'https://v8mobile.hut.edu.cn/waterpage/waterHomePage?openid=${session.openid}',
    );
    final response = await dio.post(
      '/bathroom/getOftenUsetermList?openid=${session.openid}',
      data: {'openid': session.openid},
    );

    if (response.data == '') {
      return {'code': 500};
    }

    final data = response.data;
    final rawDevices = data['resultData']['data'];
    final devices = <dynamic>[];
    if (rawDevices is List) {
      for (var index = rawDevices.length - 1; index >= 0; index--) {
        devices.add(rawDevices[index]);
      }
    }
    return {'code': 200, 'data': devices};
  }

  Future<List> checkHotWaterDevice() async {
    final token = await getToken();
    final session = await _getOpenIdSession();
    final url = 'https://v8mobile.hut.edu.cn/bathroom/selectCloseDeviceValve';
    final options = _buildV8RequestOptions(
      session: session,
      token: token,
      referer:
          'https://v8mobile.hut.edu.cn/bathroom/selectCloseDeviceValve?openid=${session.openid}',
      includeOpenIdHeader: true,
    );
    final params = <String, dynamic>{'openid': session.openid};
    final data = <String, dynamic>{'openid': session.openid};

    final response = await _request.post(
      url,
      params: params,
      data: data,
      options: options,
    );
    if (response.data['result'] != '000000') {
      return [];
    }
    final List responseData = response.data['data'];
    final openCodeList = <String>[];
    for (var i = 0; i < responseData.length; i++) {
      openCodeList.add(responseData[i]['poscode'].toString());
    }
    return responseData.isNotEmpty ? openCodeList : [];
  }

  Future<Map> startHotWater({required String device}) async {
    final token = await getToken();
    final session = await _getOpenIdSession();
    const url = 'https://v8mobile.hut.edu.cn/boiling/termcodeOpenValve';
    final options = _buildV8RequestOptions(
      session: session,
      token: token,
      referer:
          'https://v8mobile.hut.edu.cn/boiling/termcodeOpenValve?openid=${session.openid}',
      includeOpenIdHeader: true,
    );
    final params = <String, dynamic>{'openid': session.openid};
    final data = <String, dynamic>{'openid': session.openid, 'poscode': device};

    final response = await _request.post(
      url,
      params: params,
      data: data,
      options: options,
    );
    final responseData = ResponseUtils.transformObj(response);
    return {
      'result': responseData['resultData']['result'],
      'message': responseData['resultData']['message'],
      'success': responseData['success'],
    };
  }

  Future<bool> stopHotWater({required String device}) async {
    final token = await getToken();
    final session = await _getOpenIdSession();
    const url = 'https://v8mobile.hut.edu.cn/boiling/endUse';
    final options = _buildV8RequestOptions(
      session: session,
      token: token,
      referer:
          'https://v8mobile.hut.edu.cn/boiling/endUse?openid=${session.openid}',
      includeOpenIdHeader: true,
    );
    final params = <String, dynamic>{'openid': session.openid};
    final data = <String, dynamic>{
      'openid': session.openid,
      'poscode': device,
      'openappid': '',
    };

    final response = await _request.post(
      url,
      params: params,
      data: data,
      options: options,
    );
    final responseData = ResponseUtils.transformObj(response);
    return responseData['resultData']['result'] == '000000';
  }

  Future<Map> addWaterDevice(String bindCode) async {
    final token = await getToken();
    final session = await _getOpenIdSession();
    final dio = _buildV8MobileDio(
      session: session,
      token: token,
      referer:
          'https://v8mobile.hut.edu.cn/waterpage/waterManagePage?openid=${session.openid}',
    );
    final response = await dio.post(
      '/bathroom/bindTerm?openid=${session.openid}',
      data: {'openid': session.openid, 'bindcode': bindCode},
    );
    final Map data = response.data;
    final Map resultData = data['resultData'];
    if (resultData['result'] == '000000') {
      return {'result': true, 'msg': resultData['message']};
    }
    return {'result': false, 'msg': resultData['message']};
  }

  Future<Map<String, dynamic>> delWaterDevice(String bindCode) async {
    final token = await getToken();
    final session = await _getOpenIdSession();
    final dio = _buildV8MobileDio(
      session: session,
      token: token,
      referer:
          'https://v8mobile.hut.edu.cn/waterpage/waterManagePage?openid=${session.openid}',
    );
    final response = await dio.post(
      '/bathroom/cancelBindTerm?openid=${session.openid}',
      data: {'openid': session.openid, 'bindcode': bindCode},
    );
    final Map data = response.data;
    final Map resultData = data['resultData'] ?? {};
    if (resultData.isEmpty) {
      return {'result': false, 'msg': data['message'] ?? '未知错误'};
    }
    if (resultData['result'] == '000000') {
      return {'result': true, 'msg': resultData['message']};
    }
    return {'result': false, 'msg': resultData['message']};
  }

  Future<String> getCardBalance() async {
    final token = await getToken();
    const url = 'https://v8mobile.hut.edu.cn/homezzdx/openHomePage';
    final options = _createNoCacheOptions(_request);
    final params = <String, dynamic>{'X-Id-Token': token};

    final response = await _request.get(url, params: params, options: options);
    final Document doc = parse(response.data);
    for (final element in doc.getElementsByTagName('span')) {
      if (element.attributes['name'] == 'showbalanceid') {
        return element.text.replaceAll('主钱包余额:￥', '');
      }
    }
    return 'null';
  }
}
