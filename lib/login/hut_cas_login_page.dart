import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/utils/hut_user_api.dart';
import 'package:superhut/utils/token.dart';

import '../core/services/app_auth_storage.dart';
import '../core/services/app_logger.dart';
import '../core/ui/app_loading_indicator.dart';
import '../core/ui/app_snack_bar.dart';
import 'hut_login_system.dart';

typedef HutCasIdTokenLoader = Future<String?> Function();

class HutCasTokenLoadException implements Exception {
  const HutCasTokenLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HutCasLoginPage extends StatefulWidget {
  /// 登录完成后的回调函数
  final Function(Map<String, String>)? onLoginComplete;

  /// 是否在登录成功后自动返回
  final bool popOnSuccess;

  /// 用于储存和获取token的键名
  final String tokenKey;

  /// 用于储存和获取my_client_ticket的键名
  final String cookieKey;

  final HutCasIdTokenLoader? loadIdToken;

  const HutCasLoginPage({
    super.key,
    this.onLoginComplete,
    this.popOnSuccess = true,
    this.tokenKey = 'token',
    this.cookieKey = 'my_client_ticket',
    this.loadIdToken,
  });

  @override
  State<HutCasLoginPage> createState() => _HutCasLoginPageState();
}

class _HutCasLoginPageState extends State<HutCasLoginPage> {
  final HutUserApi _api = HutUserApi();
  final ValueNotifier<_HutCasTokenLoadState> _tokenLoadState =
      ValueNotifier<_HutCasTokenLoadState>(
        const _HutCasTokenLoadState.loading(),
      );
  String _idToken = '';
  bool _hasSavedCasSession = false;
  Future<void>? _idTokenLoad;

  @override
  void initState() {
    super.initState();
    unawaited(_getIdToken());
  }

  @override
  void dispose() {
    _tokenLoadState.dispose();
    super.dispose();
  }

  // 获取用于CAS登录的idToken
  Future<void> _getIdToken() {
    final inFlight = _idTokenLoad;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<void> load;
    load = _runIdTokenLoad(() => load);
    _idTokenLoad = load;
    return load;
  }

  Future<void> _runIdTokenLoad(Future<void> Function() currentLoad) async {
    try {
      await _loadIdToken();
    } finally {
      if (identical(_idTokenLoad, currentLoad())) {
        _idTokenLoad = null;
      }
    }
  }

  Future<void> _loadIdToken() async {
    try {
      final loader = widget.loadIdToken;
      final idToken =
          loader != null ? await loader() : await _loadMountedIdToken();
      if (idToken == null) {
        return;
      }
      _idToken = idToken;
      _setTokenLoadState(isLoading: false);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load HUT CAS id token',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      _setTokenLoadState(
        isLoading: false,
        errorMessage: _resolveIdTokenLoadErrorMessage(error),
      );
    }
  }

  String _resolveIdTokenLoadErrorMessage(Object error) {
    if (error is HutCasTokenLoadException) {
      return error.message;
    }
    return '获取统一认证令牌失败，请稍后重试';
  }

  Future<String?> _loadMountedIdToken() async {
    final isValid = await _api.checkTokenValidity();
    if (!mounted) {
      return null;
    }
    if (!isValid) {
      final refreshed = await _api.refreshToken();
      if (!mounted) {
        return null;
      }
      if (!refreshed) {
        throw const HutCasTokenLoadException('智慧工大登录状态已失效，请重新登录后再试');
      }
    }

    final idToken = await _api.getToken();
    if (!mounted) {
      return null;
    }
    final normalizedToken = idToken.trim();
    if (normalizedToken.isEmpty) {
      throw const HutCasTokenLoadException('未获取到统一认证令牌，请重新登录后再试');
    }
    return normalizedToken;
  }

  void _retryGetIdToken() {
    _setTokenLoadState(isLoading: true);
    unawaited(_getIdToken());
  }

  void _setTokenLoadState({required bool isLoading, String? errorMessage}) {
    final currentState = _tokenLoadState.value;
    if (!mounted ||
        (currentState.isLoading == isLoading &&
            currentState.errorMessage == errorMessage)) {
      return;
    }

    _tokenLoadState.value = _HutCasTokenLoadState(
      isLoading: isLoading,
      errorMessage: errorMessage,
    );
  }

  // 保存获取到的新token和cookie
  Future<void> _saveTokenAndCookie(Map<String, String> data) async {
    final token = (data['token'] ?? '').trim();
    final myClientTicket = (data['my_client_ticket'] ?? '').trim();

    if (token.isEmpty) {
      AppLogger.debug('忽略空的CAS教务token');
      return;
    }
    if (token == _idToken) {
      AppLogger.debug('忽略中间态HUT token，等待CAS最终教务token');
      return;
    }
    if (_hasSavedCasSession) {
      return;
    }

    _hasSavedCasSession = true;
    try {
      final prefs = AppAuthStorage.instance;

      await prefs.saveJwxtSession(token: token, cookie: myClientTicket);
      if (widget.tokenKey != 'token' ||
          widget.cookieKey != 'my_client_ticket') {
        final sharedPrefs = await SharedPreferences.getInstance();
        await sharedPrefs.setString(widget.tokenKey, token);
        if (myClientTicket.isNotEmpty) {
          await sharedPrefs.setString(widget.cookieKey, myClientTicket);
        } else {
          await sharedPrefs.remove(widget.cookieKey);
        }
      }

      if (!mounted) {
        return;
      }

      if (widget.onLoginComplete != null) {
        widget.onLoginComplete!({
          'token': token,
          'my_client_ticket': myClientTicket,
        });
      }

      if (widget.popOnSuccess && mounted) {
        Navigator.of(
          context,
        ).pop({'token': token, 'my_client_ticket': myClientTicket});
      }
    } catch (error, stackTrace) {
      _hasSavedCasSession = false;
      AppLogger.error(
        'Failed to save CAS token and cookie',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_HutCasTokenLoadState>(
      valueListenable: _tokenLoadState,
      builder: (context, tokenLoadState, _) {
        final colorScheme = Theme.of(context).colorScheme;

        if (tokenLoadState.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('统一认证登录'), leading: SizedBox()),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppLoadingIndicator(color: colorScheme.primary),
                  const SizedBox(height: 16),
                  const Text('正在打开统一认证...'),
                ],
              ),
            ),
          );
        }

        final errorMessage = tokenLoadState.errorMessage;
        if (errorMessage != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('统一认证登录'), leading: SizedBox()),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error, size: 48),
                  const SizedBox(height: 16),
                  Text(errorMessage, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _retryGetIdToken,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          );
        }

        return HutLoginSystem(
          initialIdToken: _idToken,
          onTokenAndCookieExtracted: _saveTokenAndCookie,
          onError: (errorMessage) {
            if (mounted) {
              showAppSnackBar(
                context,
                message: errorMessage,
                type: AppSnackBarType.error,
              );
            }
          },
        );
      },
    );
  }
}

class _HutCasTokenLoadState {
  const _HutCasTokenLoadState({required this.isLoading, this.errorMessage});

  const _HutCasTokenLoadState.loading()
    : this(isLoading: true, errorMessage: null);

  final bool isLoading;
  final String? errorMessage;
}

// 另一种使用方式 - 获取token和cookie不返回
class HutCasTokenRetriever {
  static Future<Map<String, String>?>? _jwxtTokenAndCookieLoad;
  static Widget Function(Function(Map<String, String>) onLoginComplete)?
  _loginPageBuilderForTest;

  static Future<Map<String, String>?> getJwxtTokenAndCookie(
    BuildContext context,
  ) {
    final inFlight = _jwxtTokenAndCookieLoad;
    if (inFlight != null) {
      return inFlight;
    }

    late final Future<Map<String, String>?> load;
    load = _runJwxtTokenAndCookieLoad(context, () => load);
    _jwxtTokenAndCookieLoad = load;
    return load;
  }

  static Future<Map<String, String>?> _runJwxtTokenAndCookieLoad(
    BuildContext context,
    Future<Map<String, String>?> Function() currentLoad,
  ) async {
    try {
      return await _loadJwxtTokenAndCookie(context);
    } finally {
      if (identical(_jwxtTokenAndCookieLoad, currentLoad())) {
        _jwxtTokenAndCookieLoad = null;
      }
    }
  }

  static Future<Map<String, String>?> _loadJwxtTokenAndCookie(
    BuildContext context,
  ) async {
    final storage = AppAuthStorage.instance;
    final cachedToken = await storage.readJwxtToken();
    final cachedCookie = await storage.readJwxtCookie();
    if (cachedToken.isNotEmpty) {
      final isTokenValid = await checkTokenValid();
      if (isTokenValid) {
        return {'token': cachedToken, 'my_client_ticket': cachedCookie};
      }
    }

    final completer = Completer<Map<String, String>?>();
    void completeOnce(Map<String, String>? value) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }

    if (!context.mounted) {
      return null;
    }

    final routeResult = Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) =>
                _loginPageBuilderForTest?.call(completeOnce) ??
                HutCasLoginPage(
                  popOnSuccess: true,
                  onLoginComplete: (data) {
                    completeOnce(data);
                  },
                ),
      ),
    );
    unawaited(_completeJwxtTokenFromRoute(routeResult, completeOnce));

    return completer.future;
  }

  static Future<void> _completeJwxtTokenFromRoute(
    Future<Object?> routeResult,
    void Function(Map<String, String>? value) completeOnce,
  ) async {
    final value = await routeResult;
    if (value is Map<String, String>) {
      completeOnce(value);
    } else if (value is Map) {
      completeOnce(Map<String, String>.from(value));
    } else {
      completeOnce(null);
    }
  }

  static void setLoginPageBuilderForTest(
    Widget Function(Function(Map<String, String>) onLoginComplete)? builder,
  ) {
    _loginPageBuilderForTest = builder;
  }

  static void resetForTest() {
    _jwxtTokenAndCookieLoad = null;
    _loginPageBuilderForTest = null;
  }

  // 保持向后兼容性的方法
  static Future<String?> getJwxtToken(BuildContext context) async {
    Map<String, String>? result = await getJwxtTokenAndCookie(context);
    return result?['token'];
  }
}
