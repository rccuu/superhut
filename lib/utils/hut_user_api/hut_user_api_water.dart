part of '../hut_user_api.dart';

/// Water-service timeouts, derived from the reverse-engineering captures in
/// docs/water_hot_reverse_findings.md (§2.3): list ~0.1s, valve operations
/// 0.5–2.9s under load. The previous 3s receive timeout cut off real
/// responses; 15s keeps a 5x margin while staying far below the official
/// client, which sets no timeout at all.
const Duration kWaterConnectTimeout = Duration(seconds: 5);
const Duration kWaterReceiveTimeout = Duration(seconds: 15);

/// Server "busy" codes whose official copy literally says 请稍候再试
/// (CORE35106 设备或者网络忙 / CORE35108 设备忙). Real captures show
/// open-valve failing twice with CORE35108 and succeeding on a third attempt
/// seconds later — transient by design.
const Set<String> _kWaterBusyResultCodes = {'CORE35106', 'CORE35108'};

/// The session bootstrap answers `{"message":"资源受限，页面丢失!","success":false}`
/// once the JSESSIONID is no longer accepted (verified against the live
/// service with a missing/wrong session).
bool waterResponseIndicatesSessionLost(Map<String, dynamic> value) {
  if (value['success'] != false) {
    return false;
  }
  final message = value['message']?.toString() ?? '';
  return message.contains('资源受限') || message.contains('页面丢失');
}

/// True for transport failures worth retrying: timeouts and connection-level
/// errors. HTTP-level rejections (4xx/5xx responses) are business verdicts and
/// are not retried.
bool isWaterValveTransientError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }
  return false;
}

/// True when the business result code itself says "busy, try again".
bool isWaterValveRetryableResult(Map<String, dynamic> value) {
  final code = value['result']?.toString();
  return code != null && _kWaterBusyResultCodes.contains(code);
}

Future<void> _defaultWaterRetryDelay(Duration duration) {
  return Future<void>.delayed(duration);
}

/// Retry wrapper for open/close valve calls.
///
/// Retries transport-transient failures and the two server "busy" codes with a
/// 2s → 4s backoff, at most [maxRetries] times (i.e. three attempts total),
/// mirroring the server's own “请稍候再试” guidance and the observed
/// fail→fail→success sequence. A lost v8mobile session is recovered by calling
/// [onSessionLost] (invalidates the cached session so the next attempt
/// rebuilds it) and retrying within the same budget.
Future<Map<String, dynamic>> runWaterValveOperation(
  Future<Map<String, dynamic>> Function() attempt, {
  int maxRetries = 2,
  List<Duration> retryDelays = const [
    Duration(seconds: 2),
    Duration(seconds: 4),
  ],
  Future<void> Function(Duration duration)? delay,
  void Function()? onSessionLost,
}) async {
  final wait = delay ?? _defaultWaterRetryDelay;
  var index = 0;
  while (true) {
    Map<String, dynamic> value;
    try {
      value = await attempt();
    } on DioException catch (error) {
      if (index >= maxRetries || !isWaterValveTransientError(error)) {
        rethrow;
      }
      index += 1;
      await wait(retryDelays[index - 1]);
      continue;
    }

    if (waterResponseIndicatesSessionLost(value)) {
      onSessionLost?.call();
      if (index >= maxRetries) {
        return value;
      }
      index += 1;
      await wait(retryDelays[index - 1]);
      continue;
    }

    if (index < maxRetries && isWaterValveRetryableResult(value)) {
      index += 1;
      await wait(retryDelays[index - 1]);
      continue;
    }
    return value;
  }
}

Map<String, dynamic> _waterValveResultFromResponse(Response response) {
  Map<String, dynamic> data;
  try {
    final raw = response.data;
    if (raw is String) {
      final decoded = jsonDecode(raw);
      data = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } else if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    } else {
      data = <String, dynamic>{};
    }
  } catch (_) {
    return <String, dynamic>{'result': '', 'message': '响应解析失败', 'success': false};
  }

  // Business envelope: {"message":..., "resultData":{result,message,data},
  // "success":true}. Session-loss responses carry no resultData; the
  // top-level message is the only hint ("资源受限，页面丢失!").
  final resultData = data['resultData'];
  if (resultData is Map) {
    final map = Map<String, dynamic>.from(resultData);
    return <String, dynamic>{
      'result': map['result']?.toString() ?? '',
      'message': map['message']?.toString() ?? '',
      'success': data['success'] == true,
    };
  }
  return <String, dynamic>{
    'result': data['result']?.toString() ?? '',
    'message': data['message']?.toString() ?? '',
    'success': data['success'] == true,
  };
}

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
      connectTimeout: kWaterConnectTimeout,
      receiveTimeout: kWaterReceiveTimeout,
      followRedirects: true,
      validateStatus: _defaultValidateStatus,
    );
  }

  /// One open/close valve operation with the reverse-engineered retry policy.
  ///
  /// Valve commands relay through the campus terminal gateway and are the
  /// slowest water endpoints (measured 0.5–2.9s), so each attempt uses a
  /// dedicated Dio with the widened [kWaterReceiveTimeout] instead of the
  /// shared request manager.
  Future<Map<String, dynamic>> _runValveOperation({
    required String path,
    required Map<String, dynamic> Function(_HutOpenIdSession session) bodyBuilder,
  }) {
    return runWaterValveOperation(
      () async {
        final token = await getToken();
        final session = await _getOpenIdSession();
        final dio = _createConfiguredDio(
          baseUrl: _kV8MobileBaseUrl,
          headers: _buildV8MobileHeaders(
            session: session,
            token: token,
            referer: '$_kV8MobileBaseUrl$path?openid=${session.openid}',
            includeOpenIdHeader: true,
          ),
          connectTimeout: kWaterConnectTimeout,
          receiveTimeout: kWaterReceiveTimeout,
          followRedirects: true,
          validateStatus: _defaultValidateStatus,
        );
        final response = await dio.post(
          path,
          queryParameters: <String, dynamic>{'openid': session.openid},
          data: bodyBuilder(session),
        );
        return _waterValveResultFromResponse(response);
      },
      onSessionLost: _invalidateOpenIdSession,
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

  Future<Map<String, dynamic>> startHotWater({required String device}) {
    return _runValveOperation(
      path: '/boiling/termcodeOpenValve',
      bodyBuilder:
          (session) => <String, dynamic>{
            'openid': session.openid,
            'poscode': device,
          },
    );
  }

  /// openappid stays empty for the regular open-by-code → close flow, matching
  /// the official H5 (waterUsingPage renders it empty unless the user arrives
  /// via the “未关阀设备” page, which superhut does not implement).
  Future<Map<String, dynamic>> stopHotWater({required String device}) {
    return _runValveOperation(
      path: '/boiling/endUse',
      bodyBuilder:
          (session) => <String, dynamic>{
            'openid': session.openid,
            'poscode': device,
            'openappid': '',
          },
    );
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
