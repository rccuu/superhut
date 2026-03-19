import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' as tget;
import 'package:get/get_core/src/get_main.dart';
import 'package:superhut/login/loginwithpost.dart';
import 'package:superhut/utils/withhttp.dart';

import '../core/services/app_auth_storage.dart';
import '../core/services/app_logger.dart';
import '../login/hut_cas_login_page.dart';

Future<void> saveToken(String token) async {
  final storage = AppAuthStorage.instance;
  // JWXT direct-login flows only return a token. Keep cookie empty here so
  // stale CAS cookies are not mixed with a fresh token.
  await storage.saveJwxtSession(token: token, cookie: '');
}

Future<String> getToken() async {
  return AppAuthStorage.instance.readJwxtToken();
}

Future<bool> checkTokenValid() async {
  try {
    final Response<dynamic> response = await postDioWithCookie(
      '/njwhd/noticeTab',
      const {},
    );
    final data = response.data;
    return data is Map && data['code'] == '1';
  } catch (error, stackTrace) {
    AppLogger.error(
      'JWXT token validation failed',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  }
}

Future<bool> renewToken(BuildContext context) async {
  final storage = AppAuthStorage.instance;
  final type = await storage.readLoginType();
  final isValid = await checkTokenValid();
  if (isValid) {
    return true;
  }

  if (type == 'jwxt') {
    final user = await storage.readJwxtUsername();
    final password = await storage.readJwxtPassword();
    if (user.isEmpty || password.isEmpty) {
      return false;
    }

    Get.snackbar(
      '请稍候',
      '正在刷新 token',
      snackPosition: tget.SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
    );
    return loginHut(user, password);
  }

  if (!context.mounted) {
    return false;
  }

  final result = await HutCasTokenRetriever.getJwxtTokenAndCookie(context);
  if (result == null) {
    return false;
  }

  await storage.saveJwxtSession(
    token: result['token'] ?? '',
    cookie: result['my_client_ticket'] ?? '',
  );
  AppLogger.debug('JWXT token refreshed via CAS login flow');
  return true;
}
