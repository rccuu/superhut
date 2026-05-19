part of '../hut_user_api.dart';

const _kMyCasBaseUrl = 'https://mycas.hut.edu.cn';
const _kV8MobileBaseUrl = 'https://v8mobile.hut.edu.cn';
const _kPortalBaseUrl = 'https://portal.hut.edu.cn';
const _kPortalHomeUrl = 'https://portal.hut.edu.cn/';
const _kPortalMainPath = '/main.html';
const _kLegacyPortalIndexPath = '/portal_dist/portal_index.html';

const _kHutLoginUserAgent = 'SWSuperApp/1.1.3(XiaomidadaXiaomi15)';
const _kBrowserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64';
const _kV8MobileUserAgent =
    'Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 '
    'Mobile Safari/537.36 SuperApp';
const _kPortalUserAgent =
    'Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 '
    'Mobile Safari/537.36 uni-app Html5Plus/1.0 (Immersed/36.923077)';

bool _defaultValidateStatus(int? status) => status != null && status < 500;

String _readString(Map data, List<String> keys, {String defaultValue = ''}) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) {
      continue;
    }
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }
  return defaultValue;
}

String _readJsonString(
  Map data,
  List<String> keys, {
  String defaultValue = '',
}) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) {
      continue;
    }
    if (value is List || value is Map) {
      return jsonEncode(value);
    }
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }
  return defaultValue;
}

Map<String, dynamic>? decodeHutJwtPayload(String token) {
  final parts = token.trim().split('.');
  if (parts.length < 2 || parts[1].isEmpty) {
    return null;
  }

  try {
    final normalized = base64Url.normalize(Uri.decodeComponent(parts[1]));
    final payload = utf8.decode(base64Url.decode(normalized));
    final decoded = jsonDecode(payload);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    return null;
  }
  return null;
}

class HutPortalSession {
  final String token;
  final String ticket;

  const HutPortalSession({required this.token, required this.ticket});

  bool get hasTicket => ticket.trim().isNotEmpty;

  factory HutPortalSession.fromLoginData(Map tokenData) {
    final idToken = _readString(tokenData, const [
      'idToken',
      'id_token',
      'token',
      'accessToken',
      'access_token',
    ]);
    final ticket = _readString(tokenData, const [
      'ticket',
      'portalTicket',
      'portal_ticket',
      'casTicket',
      'cas_ticket',
    ]);

    if (ticket.isNotEmpty) {
      final payload = decodeHutJwtPayload(ticket);
      final embeddedToken = _readString(payload ?? const {}, const [
        'idToken',
        'id_token',
      ]);
      return HutPortalSession(
        token:
            embeddedToken.isNotEmpty
                ? embeddedToken
                : idToken.isNotEmpty
                ? idToken
                : ticket,
        ticket: ticket,
      );
    }
    return HutPortalSession.fromTicketCandidate(idToken);
  }

  factory HutPortalSession.fromTicketCandidate(
    String candidate, {
    String fallbackToken = '',
  }) {
    final trimmedCandidate = candidate.trim();
    final trimmedFallback = fallbackToken.trim();
    if (trimmedCandidate.isEmpty) {
      return HutPortalSession(token: trimmedFallback, ticket: '');
    }

    final payload = decodeHutJwtPayload(trimmedCandidate);
    final embeddedToken = _readString(payload ?? const {}, const [
      'idToken',
      'id_token',
    ]);
    if (embeddedToken.isNotEmpty) {
      return HutPortalSession(token: embeddedToken, ticket: trimmedCandidate);
    }

    return HutPortalSession(
      token: trimmedFallback.isNotEmpty ? trimmedFallback : trimmedCandidate,
      ticket: '',
    );
  }
}

String buildHutPortalServiceDetailUrl({
  required String serviceId,
  required String serviceName,
  String servicePicUrl = '',
  int activeS = 0,
  int activeSS = 0,
}) {
  final encodedName = Uri.encodeComponent(Uri.encodeComponent(serviceName));
  return '$_kPortalBaseUrl$_kPortalMainPath#/ServiceDetail'
      '?portalUrl=${Uri.encodeComponent(_kPortalHomeUrl)}'
      '&parentImgUrl=${Uri.encodeComponent(servicePicUrl)}'
      '&parentMenuList=${Uri.encodeComponent(serviceId)}'
      '&parentName=$encodedName'
      '&activeS=$activeS'
      '&activeSS=$activeSS';
}

String buildHutPortalAuthenticatedEntryUrl({
  required String targetUrl,
  required String ticket,
  String entryOrigin = _kPortalBaseUrl,
}) {
  final normalizedTargetUrl = normalizeHutPortalUrl(targetUrl);
  return '$entryOrigin$_kPortalMainPath'
      '?path=${Uri.encodeComponent(normalizedTargetUrl)}'
      '&redirect=true'
      '&ticket=${Uri.encodeComponent(ticket)}';
}

String buildHutPortalCasLoginEntryUrl({
  required String targetUrl,
  String entryOrigin = _kPortalBaseUrl,
  String idToken = '',
}) {
  final normalizedTargetUrl = normalizeHutPortalUrl(targetUrl);
  final serviceUrl =
      '$entryOrigin$_kPortalMainPath'
      '?path=${Uri.encodeComponent(normalizedTargetUrl)}'
      '&redirect=true';
  final uri = Uri.parse('$_kMyCasBaseUrl/cas/login');
  final queryParameters = <String, String>{'service': serviceUrl};
  if (idToken.trim().isNotEmpty) {
    queryParameters['idToken'] = idToken.trim();
  }
  return uri.replace(queryParameters: queryParameters).toString();
}

String buildHutCasLoginUrl({required String serviceUrl, String idToken = ''}) {
  final uri = Uri.parse('$_kMyCasBaseUrl/cas/login');
  final queryParameters = <String, String>{
    'service': normalizeHutPortalUrl(serviceUrl),
  };
  if (idToken.trim().isNotEmpty) {
    queryParameters['idToken'] = idToken.trim();
  }
  return uri.replace(queryParameters: queryParameters).toString();
}

String buildHutPortalServiceEntryUrl({
  required String targetUrl,
  required String token,
  String ticket = '',
  String entryOrigin = _kPortalBaseUrl,
}) {
  if (ticket.trim().isNotEmpty) {
    return buildHutPortalAuthenticatedEntryUrl(
      targetUrl: targetUrl,
      ticket: ticket.trim(),
      entryOrigin: entryOrigin,
    );
  }
  return buildHutPortalCasLoginEntryUrl(
    targetUrl: targetUrl,
    entryOrigin: entryOrigin,
    idToken: token,
  );
}

String normalizeHutPortalUrl(String url) {
  final directUrl = _replaceLegacyPortalIndexPath(url.trim());
  final uri = Uri.tryParse(directUrl);
  if (uri == null || uri.queryParameters.isEmpty) {
    return directUrl;
  }

  var changed = false;
  final normalizedQueryParameters = <String, String>{};
  uri.queryParameters.forEach((key, value) {
    final normalizedValue = _replaceLegacyPortalIndexPath(value);
    normalizedQueryParameters[key] = normalizedValue;
    changed = changed || normalizedValue != value;
  });

  if (!changed) {
    return directUrl;
  }
  return uri.replace(queryParameters: normalizedQueryParameters).toString();
}

String _replaceLegacyPortalIndexPath(String value) {
  return value.replaceAll(_kLegacyPortalIndexPath, _kPortalMainPath);
}

String describeHutUrlForLog(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return 'invalid-url';
  }
  final keys = uri.queryParameters.keys.toList()..sort();
  final fragmentPath =
      uri.fragment.isEmpty ? '' : ' fragment=${uri.fragment.split('?').first}';
  return '${uri.host}${uri.path} queryKeys=$keys$fragmentPath';
}

/// Utility for transforming response data.
class ResponseUtils {
  /// Transforms response data to a standardized format.
  static Map<String, dynamic> transformObj(Response response) {
    if (response.data is String) {
      return jsonDecode(response.data);
    } else if (response.data is Map) {
      if (response.data.containsKey('data')) {
        return response.data['data'];
      } else {
        return response.data;
      }
    }
    return {};
  }
}

/// Request manager for handling cached HTTP requests.
class RequestManager {
  final Dio _dio = Dio();
  final CacheOptions cacheOptions = CacheOptions(
    store: MemCacheStore(),
    policy: CachePolicy.request,
    maxStale: const Duration(days: 7),
    priority: CachePriority.normal,
  );

  RequestManager() {
    _dio.options.followRedirects = true;
    _dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));
  }

  Future<Response<T>> get<T>(
    String url, {
    Map<String, dynamic>? params,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.get<T>(
      url,
      queryParameters: params,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  Future<Response<T>> post<T>(
    String url, {
    dynamic data,
    Map<String, dynamic>? params,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.post<T>(
      url,
      data: data,
      queryParameters: params,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }
}

class FunctionItem {
  final String id;
  final String serviceName;
  final String servicePicUrl;
  final String serviceUrl;
  final String serviceType;
  final String tokenAccept;
  final String iconUrl;

  FunctionItem({
    required this.id,
    required this.serviceName,
    required this.servicePicUrl,
    required this.serviceUrl,
    required this.serviceType,
    required this.tokenAccept,
    required this.iconUrl,
  });

  factory FunctionItem.fromJson(Map data) {
    final servicePicUrl = _readString(data, const [
      'servicePicUrl',
      'service_pic_url',
      'SERVICE_PIC_URL',
      'servicePic',
      'picUrl',
      'pic_url',
      'iconUrl',
      'icon_url',
      'ICON_URL',
      'logoUrl',
      'logo_url',
      'LOGO_URL',
    ]);

    return FunctionItem(
      id: _readString(data, const [
        'id',
        'ID',
        'serviceId',
        'service_id',
        'SERVICE_ID',
        'code',
        'CODE',
      ]),
      serviceName: _readString(data, const [
        'serviceName',
        'service_name',
        'SERVICE_NAME',
        'name',
        'NAME',
        'title',
        'TITLE',
        'appName',
        'app_name',
        'APP_NAME',
      ]),
      servicePicUrl: servicePicUrl,
      serviceUrl: _readString(data, const [
        'serviceUrl',
        'service_url',
        'SERVICE_URL',
        'url',
        'URL',
        'appUrl',
        'app_url',
        'APP_URL',
        'linkUrl',
        'link_url',
        'LINK_URL',
      ]),
      serviceType: _readString(data, const [
        'serviceType',
        'service_type',
        'SERVICE_TYPE',
        'type',
        'TYPE',
      ], defaultValue: '2'),
      tokenAccept: _readJsonString(data, const [
        'tokenAccept',
        'token_accept',
        'TOKEN_ACCEPT',
      ], defaultValue: '[]'),
      iconUrl: _readString(data, const [
        'iconUrl',
        'icon_url',
        'ICON_URL',
        'logoUrl',
        'logo_url',
        'LOGO_URL',
      ], defaultValue: servicePicUrl),
    );
  }
}

class _HutOpenIdSession {
  final String openid;
  final String jSessionId;

  const _HutOpenIdSession({required this.openid, required this.jSessionId});

  List<dynamic> toLegacyList() => [openid, jSessionId];
}

Dio _createConfiguredDio({
  required String baseUrl,
  required Map<String, dynamic> headers,
  Duration connectTimeout = const Duration(seconds: 5),
  Duration receiveTimeout = const Duration(seconds: 3),
  bool followRedirects = true,
  ValidateStatus? validateStatus,
}) {
  final dio = Dio();
  dio.interceptors.clear();
  dio.options.baseUrl = baseUrl;
  dio.options.connectTimeout = connectTimeout;
  dio.options.receiveTimeout = receiveTimeout;
  dio.options.headers = headers;
  dio.options.followRedirects = followRedirects;
  if (validateStatus != null) {
    dio.options.validateStatus = validateStatus;
  }
  return dio;
}

Options _createNoCacheOptions(RequestManager requestManager) {
  final options =
      requestManager.cacheOptions
          .copyWith(policy: CachePolicy.noCache)
          .toOptions();
  options.validateStatus = _defaultValidateStatus;
  options.followRedirects = false;
  return options;
}

Map<String, dynamic> _buildV8MobileHeaders({
  required _HutOpenIdSession session,
  required String token,
  required String referer,
  bool includeOpenIdHeader = false,
}) {
  return {
    if (includeOpenIdHeader) 'openid': session.openid,
    'User-Agent': _kV8MobileUserAgent,
    'Connection': 'keep-alive',
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Accept-Encoding': 'gzip, deflate, br, zstd',
    'Content-Type': 'application/json',
    'sec-ch-ua-platform': '"Android"',
    'x-requested-with': 'XMLHttpRequest',
    'sec-ch-ua':
        '"Chromium";v="134", "Not:A-Brand";v="24", "Android WebView";v="134"',
    'sec-ch-ua-mobile': '?1',
    'Origin': _kV8MobileBaseUrl,
    'Sec-Fetch-Site': 'same-origin',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Dest': 'empty',
    'Referer': referer,
    'Accept-Language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    'Cookie':
        'userToken=$token; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=${session.jSessionId}',
  };
}
