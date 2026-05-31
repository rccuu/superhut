import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/services/app_auth_storage.dart';
import '../core/ui/app_loading_indicator.dart';
import '../core/ui/app_snack_bar.dart';
import '../home/home_route.dart';
import '../utils/course/coursemain.dart';
import '../utils/token.dart';

const String officialWebViewLoginFailureMessage = '登录失败，请稍后重试';

String resolveOfficialWebViewLoginErrorMessage(Object? _) {
  return officialWebViewLoginFailureMessage;
}

class WebViewLoginScreen extends StatefulWidget {
  final String userNo;
  final String password;
  final String showText;
  final bool renew;
  final bool navigateToCoursePageOnSuccess;

  const WebViewLoginScreen({
    super.key,
    required this.userNo,
    required this.password,
    required this.showText,
    required this.renew,
    this.navigateToCoursePageOnSuccess = true,
  });

  @override
  State<WebViewLoginScreen> createState() => _WebViewLoginScreenState();
}

class _WebViewLoginScreenState extends State<WebViewLoginScreen> {
  late final WebViewController _webViewController;
  final ValueNotifier<bool> _autoLoginTimedOutNotifier = ValueNotifier<bool>(
    false,
  );
  Timer? _timeoutTimer;
  bool _hasHandledResult = false;

  bool get _autoLoginTimedOut => _autoLoginTimedOutNotifier.value;

  bool _markHandled() {
    if (_hasHandledResult) {
      return false;
    }
    _hasHandledResult = true;
    _timeoutTimer?.cancel();
    return true;
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (_hasHandledResult || !mounted) {
        return;
      }

      _setAutoLoginTimedOut();
      showAppSnackBar(
        context,
        message: '自动登录超时，请直接在页面中手动完成登录',
        type: AppSnackBarType.warning,
      );
    });
  }

  void _setAutoLoginTimedOut() {
    if (!mounted || _autoLoginTimedOut) {
      return;
    }

    _autoLoginTimedOutNotifier.value = true;
  }

  Future<void> _handleTokenMessage(String token) async {
    if (!_markHandled()) {
      return;
    }

    final storage = AppAuthStorage.instance;
    await storage.saveJwxtCredentials(
      username: widget.userNo,
      password: widget.password,
    );
    await storage.saveLoginType('jwxt');
    await storage.setFirstOpen(false);
    await saveToken(token);
    if (!mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    if (widget.renew) {
      navigator.pop(true);
      return;
    }

    if (!widget.navigateToCoursePageOnSuccess) {
      navigator.pop(true);
      return;
    }

    unawaited(ensureCourseScheduleFreshness());
    navigator.pushAndRemoveUntil(
      buildHomePageRoute(initialIndex: 0),
      (route) => false,
    );
  }

  void _handleLoginError(String message) {
    if (!_markHandled() || !mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    showAppSnackBar(
      context,
      message: resolveOfficialWebViewLoginErrorMessage(message),
      type: AppSnackBarType.error,
    );
    navigator.pop(false);
  }

  Future<void> _injectLoginHooks() async {
    await _webViewController.runJavaScript('''
      (function() {
        if (window.__superhutLoginHooksInstalled) {
          return;
        }
        window.__superhutLoginHooksInstalled = true;

        function reportLoginResult(rawText) {
          try {
            var response = JSON.parse(rawText);
            var code = String(response.code ?? '');
            if (code === '1' && response.data && response.data.token) {
              TokenChannel.postMessage(response.data.token);
            } else if (code === '0') {
              ErrorChannel.postMessage(
                response.Msg || response.message || '登录失败，请稍后重试'
              );
            }
          } catch (error) {}
        }

        var originalOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
          this.addEventListener('load', function() {
            if (String(url).includes('/njwhd/login')) {
              reportLoginResult(this.responseText || '');
            }
          });
          originalOpen.apply(this, arguments);
        };

        var originalFetch = window.fetch;
        if (typeof originalFetch === 'function') {
          window.fetch = function(input, init) {
            var url =
              typeof input === 'string'
                ? input
                : (input && input.url) || '';

            return originalFetch.apply(this, arguments).then(function(response) {
              if (!String(url).includes('/njwhd/login')) {
                return response;
              }

              response
                .clone()
                .text()
                .then(function(text) {
                  reportLoginResult(text);
                })
                .catch(function() {});

              return response;
            });
          };
        }
      })();
    ''');
  }

  Future<void> _attemptAutoLogin() async {
    if (!mounted || _hasHandledResult || _autoLoginTimedOut) {
      return;
    }

    final encodedUserNo = jsonEncode(widget.userNo);
    final encodedPassword = jsonEncode(widget.password);

    await _webViewController.runJavaScript('''
      (function() {
        if (
          window.__superhutAutoLoginFinished ||
          window.__superhutAutoLoginAttempting
        ) {
          return;
        }
        window.__superhutAutoLoginAttempting = true;

        var attemptsLeft = 15;

        function attemptAutoLogin() {
        const userInput = document.querySelector('#xhNb');
        const pwdInput = document.querySelector('input[type="password"]');
        const submitBtn = document.querySelector('.log-btn button');

        function simulateInput(element, value) {
          element.focus();
          element.value = value;
          const eventTypes = ['input', 'change', 'blur'];
          for (let index = 0; index < eventTypes.length; index += 1) {
            const eventType = eventTypes[index];
            const event = new Event(eventType, { bubbles: true });
            element.dispatchEvent(event);
          }
        }

        if (!userInput || !pwdInput || !submitBtn) {
          attemptsLeft -= 1;
          if (attemptsLeft <= 0) {
            window.__superhutAutoLoginAttempting = false;
            return;
          }
          setTimeout(attemptAutoLogin, 800);
          return;
        }

        window.__superhutAutoLoginFinished = true;
        window.__superhutAutoLoginAttempting = false;
        simulateInput(userInput, $encodedUserNo);
        simulateInput(pwdInput, $encodedPassword);

        setTimeout(() => {
          if (submitBtn.disabled) {
            window.__superhutAutoLoginFinished = false;
            window.__superhutAutoLoginAttempting = false;
            return;
          }
          submitBtn.dispatchEvent(
            new MouseEvent('click', {
              bubbles: true,
              cancelable: true,
            }),
          );
        }, 800);
        }

        attemptAutoLogin();
      })();
    ''');
  }

  Widget _buildStatusBanner(BuildContext context, bool autoLoginTimedOut) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final text = autoLoginTimedOut ? '自动登录耗时较长，请直接在页面中手动完成登录' : widget.showText;

    return Card(
      color:
          autoLoginTimedOut
              ? colorScheme.secondaryContainer
              : colorScheme.surface.withAlpha(240),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (!autoLoginTimedOut)
              AppLoadingIndicator(color: theme.primaryColor, size: 24)
            else
              Icon(
                Icons.touch_app_outlined,
                color: colorScheme.onSecondaryContainer,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color:
                      autoLoginTimedOut
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _closePage() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _autoLoginTimedOutNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startTimeoutTimer();
    _webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..addJavaScriptChannel(
            'TokenChannel',
            onMessageReceived: (message) async {
              await _handleTokenMessage(message.message);
            },
          )
          ..addJavaScriptChannel(
            'ErrorChannel',
            onMessageReceived: (message) {
              _handleLoginError(message.message);
            },
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (url) async {
                if (!mounted || _hasHandledResult || _autoLoginTimedOut) {
                  return;
                }

                await _injectLoginHooks();
                if (!mounted || _hasHandledResult || _autoLoginTimedOut) {
                  return;
                }
                await _attemptAutoLogin();
              },
            ),
          )
          ..loadRequest(Uri.parse('https://jwxtsj.hut.edu.cn/sjd/#/login'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('教务系统官方登录'),
        actions: [TextButton(onPressed: _closePage, child: const Text('关闭'))],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: SafeArea(
              child: IgnorePointer(
                ignoring: true,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _autoLoginTimedOutNotifier,
                  builder: (context, autoLoginTimedOut, _) {
                    return _buildStatusBanner(context, autoLoginTimedOut);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
