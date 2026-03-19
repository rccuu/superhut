import 'dart:async';

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
  bool _hasResponse = false;

  // 统一响应处理方法
  void _handleResponse() {
    _hasResponse = true;
    _timeoutTimer?.cancel();
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      if (!_hasResponse) {
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.maybeOf(context);
        navigator.pop(false);
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('连接超时，请检查网络后重试'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
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
              final storage = AppAuthStorage.instance;
              await storage.saveJwxtCredentials(
                username: widget.userNo,
                password: widget.password,
              );
              await storage.saveLoginType('jwxt');
              await storage.setFirstOpen(false);
              _handleResponse();
              await saveToken(message.message);
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
            },
          )
          ..addJavaScriptChannel(
            'ErrorChannel',
            onMessageReceived: (message) {
              _handleResponse();
              if (!mounted) {
                return;
              }
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.maybeOf(context);
              navigator.pop(false);
              messenger?.showSnackBar(
                SnackBar(
                  content: Text('登录失败：${message.message}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          )
          ..loadRequest(Uri.parse('https://jwxtsj.hut.edu.cn/sjd/#/login'))
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (url) async {
                // 处理特殊字符
                final sanitizedUserNo = widget.userNo.replaceAll("'", r"\'");
                final sanitizedPassword = widget.password.replaceAll(
                  "'",
                  r"\'",
                );

                await _webViewController.runJavaScript('''
              (function() {
                // XHR拦截逻辑
                var originalOpen = XMLHttpRequest.prototype.open;
                XMLHttpRequest.prototype.open = function(method, url) {
                  this.addEventListener('load', function() {
                    if (url.includes('/njwhd/login')) {
                      try {
                        var response = JSON.parse(this.responseText);
                        if (response.code === "1" && response.data?.token) {
                          TokenChannel.postMessage(response.data.token);
                        }
                        if (response.code === "0") {
                          ErrorChannel.postMessage(response.Msg);
                        }
                      } catch(e) {
                        console.error('JSON解析错误:', e);
                      }
                    }
                  });
                  originalOpen.apply(this, arguments);
                };
              })();
            ''');

                await _webViewController.runJavaScript('''
              (function attemptAutoLogin() {
                const userInput = document.querySelector('#xhNb');
                const pwdInput = document.querySelector('input[type="password"]');
                const submitBtn = document.querySelector('.log-btn button');

                function simulateInput(element, value) {
                  element.focus();
                  element.value = value;
                  ['input', 'change', 'blur'].forEach(eventType => {
                    const event = new Event(eventType, { bubbles: true });
                    element.dispatchEvent(event);
                  });
                }

                if (userInput && pwdInput && submitBtn) {
                  simulateInput(userInput, '$sanitizedUserNo');
                  simulateInput(pwdInput, '$sanitizedPassword');
                  
                  setTimeout(() => {
                    if (submitBtn.disabled) {
                      ErrorChannel.postMessage('表单验证未通过');
                      return;
                    }
                    const clickEvent = new MouseEvent('click', {
                      bubbles: true,
                      cancelable: true
                    });
                    submitBtn.dispatchEvent(clickEvent);
                  }, 800);
                } else {
                
                  setTimeout(attemptAutoLogin, 1000);
                }
              })();
            ''');
              },
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          Container(
            color: Theme.of(context).colorScheme.surface.withAlpha(245),
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LoadingAnimationWidget.inkDrop(
                  color: Theme.of(context).primaryColor,
                  size: 40,
                ),
                SizedBox(height: 16),
                Text(widget.showText),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
