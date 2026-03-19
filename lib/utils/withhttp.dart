import 'package:dio/dio.dart';

import '../core/services/app_auth_storage.dart';

final Dio dio = Dio();

const _jwxtBaseUrl = 'https://jwxtsj.hut.edu.cn';
const _jwxtUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64';

Map<String, dynamic>? mapFromResponseData(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return null;
}

String? responseMessageOf(dynamic responseData) {
  final data = mapFromResponseData(responseData);
  if (data == null) {
    return null;
  }

  for (final key in const ['Msg', 'msg', 'message', 'errorMessage']) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') {
      return value;
    }
  }
  return null;
}

StateError buildJwxtStateError(
  dynamic responseData, {
  String fallbackMessage = '教务系统登录状态已失效，请重新登录后再试',
}) {
  return StateError(responseMessageOf(responseData) ?? fallbackMessage);
}

Map<String, dynamic> _buildJwxtHeaders(
  String token, {
  String? cookieHeader,
}) {
  return {
    'User-Agent': _jwxtUserAgent,
    'Accept': '*/*',
    'Accept-Encoding': 'gzip, deflate, br',
    'Token': token,
    if (cookieHeader != null && cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
  };
}

Dio _buildRequestDio({
  required String token,
  String? cookieHeader,
  Duration connectTimeout = const Duration(seconds: 20),
  Duration receiveTimeout = const Duration(seconds: 20),
}) {
  final requestDio = Dio();
  requestDio.options.baseUrl = _jwxtBaseUrl;
  requestDio.options.connectTimeout = connectTimeout;
  requestDio.options.receiveTimeout = receiveTimeout;
  requestDio.options.headers = _buildJwxtHeaders(
    token,
    cookieHeader: cookieHeader,
  );
  requestDio.httpClientAdapter = dio.httpClientAdapter;
  return requestDio;
}

void configureDio(String token) {
  dio.options.baseUrl = _jwxtBaseUrl;
  dio.options.connectTimeout = const Duration(seconds: 10);
  dio.options.receiveTimeout = const Duration(seconds: 10);
  dio.options.headers = _buildJwxtHeaders(token);
}

Future<void> configureDioWithCookie(
  String token, {
  String? myClientTicket,
}) async {
  dio.options.baseUrl = _jwxtBaseUrl;
  dio.options.connectTimeout = const Duration(seconds: 20);
  dio.options.receiveTimeout = const Duration(seconds: 20);

  final cookieHeader =
      myClientTicket != null && myClientTicket.isNotEmpty
          ? 'my_client_ticket=$myClientTicket'
          : null;

  dio.options.headers = _buildJwxtHeaders(token, cookieHeader: cookieHeader);
}

Future<void> configureDioFromStorage() async {
  final storage = AppAuthStorage.instance;
  final token = await storage.readJwxtToken();
  final myClientTicket = await storage.readJwxtCookie();
  await configureDioWithCookie(token, myClientTicket: myClientTicket);
}

Future<Response<dynamic>> postDio(
  String path,
  Map<String, dynamic> postData,
) async {
  final token = dio.options.headers['Token']?.toString() ?? '';
  final cookieHeader = dio.options.headers['Cookie']?.toString();
  final requestDio = _buildRequestDio(
    token: token,
    cookieHeader: cookieHeader,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  );

  return requestDio.post(
    path,
    data: postData,
    options: Options(
      followRedirects: false,
      validateStatus: (status) => status != null && status < 600,
    ),
  );
}

Future<Response<dynamic>> postDioWithCookie(
  String path,
  Map<String, dynamic> postData, {
  String? customCookie,
}) async {
  final storage = AppAuthStorage.instance;
  final token = await storage.readJwxtToken();
  final myClientTicket = await storage.readJwxtCookie();
  final defaultCookie =
      myClientTicket.isNotEmpty ? 'my_client_ticket=$myClientTicket' : null;
  final requestDio = _buildRequestDio(
    token: token,
    cookieHeader:
        customCookie != null && customCookie.isNotEmpty
            ? customCookie
            : defaultCookie,
  );

  return requestDio.post(
    path,
    data: postData,
    options: Options(
      followRedirects: false,
      validateStatus: (status) => status != null && status < 600,
    ),
  );
}
