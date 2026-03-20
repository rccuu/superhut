import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../bridge/get_course_page.dart';
import '../core/services/app_auth_storage.dart';
import '../utils/token.dart';

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
  Timer? _timeoutTimer;
  bool _hasHandledResult = false;
  bool _autoLoginTimedOut = false;

  bool _markHandled() {
    if (_hasHandledResult) {
      return false;
    }
    _hasHandledResult = true;
    _timeoutTimer?.cancel();
    return true;
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (_hasHandledResult || !mounted) {
        return;
      }

      setState(() {
        _autoLoginTimedOut = true;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('自动登录超时，请直接在页面中手动完成登录'),
          duration: Duration(seconds: 3),
        ),
      );
    });
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
    if (widget.renew || !widget.navigateToCoursePageOnSuccess) {
      navigator.pop(true);
      return;
    }
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const Getcoursepage(renew: false),
      ),
      (route) => false,
    );
  }

  void _handleLoginError(String message) {
    if (!_markHandled() || !mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    navigator.pop(false);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('登录失败：$message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
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
    final encodedUserNo = jsonEncode(widget.userNo);
    final encodedPassword = jsonEncode(widget.password);

    await _webViewController.runJavaScript('''
      (function attemptAutoLogin() {
        if (window.__superhutAutoLoginFinished) {
          return;
        }

        const userInput = document.querySelector('#xhNb');
        const pwdInput = document.querySelector('input[type="password"]');
        const submitBtn = document.querySelector('.log-btn button');

        function simulateInput(element, value) {
          element.focus();
          element.value = value;
          ['input', 'change', 'blur'].forEach((eventType) => {
            const event = new Event(eventType, { bubbles: true });
            element.dispatchEvent(event);
          });
        }

        if (!userInput || !pwdInput || !submitBtn) {
          setTimeout(attemptAutoLogin, 800);
          return;
        }

        window.__superhutAutoLoginFinished = true;
        simulateInput(userInput, $encodedUserNo);
        simulateInput(pwdInput, $encodedPassword);

        setTimeout(() => {
          if (submitBtn.disabled) {
            window.__superhutAutoLoginFinished = false;
            return;
          }
          submitBtn.dispatchEvent(
            new MouseEvent('click', {
              bubbles: true,
              cancelable: true,
            }),
          );
        }, 800);
      })();
    ''');
  }

  Widget _buildStatusBanner(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final text =
        _autoLoginTimedOut ? '自动登录耗时较长，请直接在页面中手动完成登录' : widget.showText;

    return Card(
      color:
          _autoLoginTimedOut
              ? colorScheme.secondaryContainer
              : colorScheme.surface.withAlpha(240),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (!_autoLoginTimedOut)
              LoadingAnimationWidget.inkDrop(
                color: theme.primaryColor,
                size: 24,
              )
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
                      _autoLoginTimedOut
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
                if (_hasHandledResult) {
                  return;
                }

                await _injectLoginHooks();
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
                child: _buildStatusBanner(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
