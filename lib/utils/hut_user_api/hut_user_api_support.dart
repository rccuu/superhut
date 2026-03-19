part of '../hut_user_api.dart';

const _kMyCasBaseUrl = 'https://mycas.hut.edu.cn';
const _kV8MobileBaseUrl = 'https://v8mobile.hut.edu.cn';
const _kPortalBaseUrl = 'https://portal.hut.edu.cn';

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
