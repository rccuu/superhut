import 'package:dio/dio.dart';

import '../core/services/app_auth_storage.dart';

final Dio dio = Dio();

void configureDio(String token) {
  dio.options.baseUrl = 'https://jwxtsj.hut.edu.cn';
  dio.options.connectTimeout = const Duration(seconds: 10);
  dio.options.receiveTimeout = const Duration(seconds: 10);
  dio.options.headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
    'Accept': '*/*',
    'Accept-Encoding': 'gzip, deflate, br',
    'Token': token,
  };
}

Future<void> configureDioWithCookie(
  String token, {
  String? myClientTicket,
}) async {
  dio.options.baseUrl = 'https://jwxtsj.hut.edu.cn';
  dio.options.connectTimeout = const Duration(seconds: 20);
  dio.options.receiveTimeout = const Duration(seconds: 20);

  final cookieString =
      myClientTicket != null && myClientTicket.isNotEmpty
          ? 'my_client_ticket=$myClientTicket'
          : '';

  dio.options.headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
    'Accept': '*/*',
    'Accept-Encoding': 'gzip, deflate, br',
    'Token': token,
    if (cookieString.isNotEmpty) 'Cookie': cookieString,
  };
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
  dio.options.baseUrl = 'https://jwxtsj.hut.edu.cn';
  return dio.post(
    path,
    data: postData,
    options: Options(
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ),
  );
}

Future<Response<dynamic>> postDioWithCookie(
  String path,
  Map<String, dynamic> postData, {
  String? customCookie,
}) async {
  await configureDioFromStorage();

  if (customCookie != null && customCookie.isNotEmpty) {
    dio.options.headers['Cookie'] = customCookie;
  }

  return dio.post(
    path,
    data: postData,
    options: Options(
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ),
  );
}
