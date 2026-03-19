import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/services/app_auth_storage.dart';
import '../core/services/app_logger.dart';
import '../utils/pwd.dart';
import '../utils/token.dart';

Future<bool> loginHut(String userNo, String orgPassword) async {
  AppLogger.debug('Starting JWXT login');
  final encryptedPassword = encryptPassword(orgPassword, sw);
  final pwd = base64Encode(utf8.encode(encryptedPassword));
  final dio = Dio();
  dio.options.baseUrl = 'https://jwxtsj.hut.edu.cn';
  dio.options.connectTimeout = const Duration(seconds: 5);
  dio.options.receiveTimeout = const Duration(seconds: 3);
  dio.options.headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
    'Accept': '*/*',
    'Accept-Encoding': 'gzip, deflate, br',
  };
  final response = await dio.post('/njwhd/login?userNo=$userNo&pwd=$pwd');
  final data = response.data;
  if (data is! Map || data['code'] != '1' || data['data'] is! Map) {
    return false;
  }

  final userData = data['data'] as Map;
  final name = userData['name']?.toString() ?? '';
  final token = userData['token']?.toString() ?? '';
  final entranceYear = userData['entranceYear']?.toString() ?? '';
  final academyName = userData['academyName']?.toString() ?? '';
  final clsName = userData['clsName']?.toString() ?? '';

  final storage = AppAuthStorage.instance;
  await saveToken(token);
  await storage.saveJwxtCredentials(username: userNo, password: orgPassword);
  await storage.saveLoginType('jwxt');
  await storage.setFirstOpen(false);
  await storage.saveProfile(
    name: name,
    entranceYear: entranceYear,
    academyName: academyName,
    clsName: clsName,
  );
  AppLogger.debug('JWXT login completed');
  return true;
}
