import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/utils/hut_user_api.dart';
import 'package:superhut/utils/token.dart';

import '../core/services/app_auth_storage.dart';
import '../core/services/app_logger.dart';
import 'hut_login_system.dart';

class HutCasLoginPage extends StatefulWidget {
  /// 登录完成后的回调函数
  final Function(Map<String, String>)? onLoginComplete;

  /// 是否在登录成功后自动返回
  final bool popOnSuccess;

  /// 用于储存和获取token的键名
  final String tokenKey;

  /// 用于储存和获取my_client_ticket的键名
  final String cookieKey;

  const HutCasLoginPage({
    super.key,
    this.onLoginComplete,
    this.popOnSuccess = true,
    this.tokenKey = 'token',
    this.cookieKey = 'my_client_ticket',
  });

  @override
  State<HutCasLoginPage> createState() => _HutCasLoginPageState();
}

class _HutCasLoginPageState extends State<HutCasLoginPage> {
  final HutUserApi _api = HutUserApi();
  bool _isLoading = true;
  String _idToken = '';
  String? _errorMessage;
  bool _hasSavedCasSession = false;

  @override
  void initState() {
    super.initState();
    _getIdToken();
  }

  // 获取用于CAS登录的idToken
  Future<void> _getIdToken() async {
    try {
      _idToken = await _api.getToken();
      /*
      _api.checkTokenValidity().then((isValid) async {
        if (!isValid) {
          await _api.refreshToken();
          _idToken = await _api.getToken();
        }
      });

      */
      await _api.refreshToken();
      _idToken = await _api.getToken();
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '获取认证令牌失败: $e';
      });
    }
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('HUT统一认证'), leading: SizedBox()),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在准备登录...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('HUT统一认证'), leading: SizedBox()),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isLoading = true;
                  });
                  _getIdToken();
                },
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      },
    );
  }
}

// 使用示例
class HutCasLoginExample extends StatelessWidget {
  const HutCasLoginExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final result = await Navigator.of(context).push<Map<String, String>>(
          MaterialPageRoute(
            builder:
                (context) => const HutCasLoginPage(
                  tokenKey: 'token',
                  cookieKey: 'my_client_ticket',
                ),
          ),
        );
        if (result != null) {
          final token = result['token'] ?? '';
          final myClientTicket = result['my_client_ticket'] ?? '';
          AppLogger.debug('CAS token acquired: $token');
          AppLogger.debug('CAS cookie acquired: $myClientTicket');
        }
      },
      child: const Text('登录教务系统'),
    );
  }
}

// 另一种使用方式 - 获取token和cookie不返回
class HutCasTokenRetriever {
  static Future<Map<String, String>?> getJwxtTokenAndCookie(
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

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder:
                (context) => HutCasLoginPage(
                  popOnSuccess: true,
                  onLoginComplete: (data) {
                    completeOnce(data);
                  },
                ),
          ),
        )
        .then((value) {
          completeOnce(value as Map<String, String>?);
        });

    return completer.future;
  }

  // 保持向后兼容性的方法
  static Future<String?> getJwxtToken(BuildContext context) async {
    Map<String, String>? result = await getJwxtTokenAndCookie(context);
    return result?['token'];
  }
}
