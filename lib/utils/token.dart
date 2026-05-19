import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:superhut/login/loginwithpost.dart';
import 'package:superhut/utils/withhttp.dart';

import '../core/services/app_auth_storage.dart';
import '../core/services/app_logger.dart';
import '../login/hut_cas_login_page.dart';
import '../login/unified_login_page.dart';

bool _isReauthPromptShowing = false;

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
      if (context.mounted) {
        await _showReauthPrompt(context);
      }
      return false;
    }

    try {
      final renewed = await loginHut(user, password);
      if (!renewed) {
        if (context.mounted) {
          await _showReauthPrompt(context);
        }
      }
      return renewed;
    } catch (error, stackTrace) {
      AppLogger.error(
        'JWXT token refresh failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        await _showReauthPrompt(context);
      }
      return false;
    }
  }

  if (!context.mounted) {
    return false;
  }

  final result = await HutCasTokenRetriever.getJwxtTokenAndCookie(context);
  if (result == null || (result['token'] ?? '').trim().isEmpty) {
    if (context.mounted) {
      await _showReauthPrompt(context);
    }
    return false;
  }

  await storage.saveJwxtSession(
    token: result['token'] ?? '',
    cookie: result['my_client_ticket'] ?? '',
  );
  AppLogger.debug('JWXT token refreshed via CAS login flow');
  return true;
}

Future<void> _showReauthPrompt(BuildContext context) async {
  if (!context.mounted || _isReauthPromptShowing) {
    return;
  }

  _isReauthPromptShowing = true;
  try {
    final shouldLogin =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('登录状态已失效'),
                content: const Text('教务系统登录状态已失效，请重新登录一次。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('稍后再说'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('重新登录'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!context.mounted || !shouldLogin) {
      return;
    }
    await Navigator.of(context).push(UnifiedLoginPage.route());
  } finally {
    _isReauthPromptShowing = false;
  }
}
