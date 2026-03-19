import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/services/app_logger.dart';

bool _isUsableJwxtTokenCandidate(
  String? token, {
  required String initialIdToken,
}) {
  if (token == null) {
    return false;
  }
  final trimmedToken = token.trim();
  return trimmedToken.isNotEmpty && trimmedToken != initialIdToken;
}

String? _extractTokenValue(String source) {
  final tokenMatch = RegExp("token=([^&'\"]+)").firstMatch(source);
  return tokenMatch?.group(1);
}

@visibleForTesting
String? extractJwxtTokenFromCasUrl(
  String url, {
  required String initialIdToken,
}) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return null;
  }

  final fragment = uri.fragment;
  if (!fragment.contains('casLogin') || !fragment.contains('token=')) {
    return null;
  }

  final token = _extractTokenValue(fragment);
  if (!_isUsableJwxtTokenCandidate(token, initialIdToken: initialIdToken)) {
    return null;
  }
  return token!.trim();
}

@visibleForTesting
String? extractJwxtTokenFromCasHtml(
  String html, {
  required String initialIdToken,
}) {
  final casRedirectMatch = RegExp(
    "#/casLogin\\?token=([^&'\\\"]+)",
  ).firstMatch(html);
  final token = casRedirectMatch?.group(1);
  if (!_isUsableJwxtTokenCandidate(token, initialIdToken: initialIdToken)) {
    return null;
  }
  return token!.trim();
}

class HutLoginSystem extends StatefulWidget {
  /// The initial idToken to pass to the CAS login URL
  final String initialIdToken;

  /// Callback function when token and cookie are successfully extracted
  final Function(Map<String, String>) onTokenAndCookieExtracted;

  /// Callback function when an error occurs during the login process
  final Function(String)? onError;

  const HutLoginSystem({
    super.key,
    required this.initialIdToken,
    required this.onTokenAndCookieExtracted,
    this.onError,
  });

  @override
  State<HutLoginSystem> createState() => _HutLoginSystemState();
}

class _HutLoginSystemState extends State<HutLoginSystem> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  String _currentUrl = '';
  bool _hasDeliveredCredentials = false;
  bool _isDeliveringCredentials = false;
  static const String _initialUrl = 'https://mycas.hut.edu.cn/cas/login';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _deliverExtractedCredentials(String token) async {
    if (_hasDeliveredCredentials || _isDeliveringCredentials) {
      return;
    }

    _isDeliveringCredentials = true;
    try {
      final myClientTicket = await _getCookie('my_client_ticket');
      if (_hasDeliveredCredentials) {
        return;
      }

      _hasDeliveredCredentials = true;
      widget.onTokenAndCookieExtracted({
        'token': token,
        'my_client_ticket': myClientTicket ?? '',
      });
    } catch (error) {
      if (widget.onError != null) {
        widget.onError!('Token和Cookie提取错误: $error');
      }
    } finally {
      _isDeliveringCredentials = false;
    }
  }

  Future<void> _checkUrlAndExtractTokenAndCookie(String url) async {
    _currentUrl = url;
    final token = extractJwxtTokenFromCasUrl(
      url,
      initialIdToken: widget.initialIdToken,
    );
    if (token == null) {
      return;
    }

    await _deliverExtractedCredentials(token);
  }

  Future<void> _checkHtmlAndExtractTokenAndCookie() async {
    final controller = _webViewController;
    if (controller == null || _hasDeliveredCredentials) {
      return;
    }

    try {
      final html = await controller.getHtml();
      if (html == null || html.isEmpty) {
        return;
      }

      final token = extractJwxtTokenFromCasHtml(
        html,
        initialIdToken: widget.initialIdToken,
      );
      if (token == null) {
        return;
      }

      await _deliverExtractedCredentials(token);
    } catch (error) {
      AppLogger.debug('读取CAS页面HTML时出错: $error');
    }
  }

  // 获取指定名称的cookie
  Future<String?> _getCookie(String cookieName) async {
    if (_webViewController == null) return null;

    try {
      CookieManager cookieManager = CookieManager.instance();
      List<Cookie> cookies = await cookieManager.getCookies(
        url: WebUri(_currentUrl),
      );

      for (Cookie cookie in cookies) {
        if (cookie.name == cookieName) {
          return cookie.value;
        }
      }

      // 如果在当前域名没找到，尝试从其他相关域名获取
      List<String> relatedDomains = [
        'https://mycas.hut.edu.cn',
        'https://jwxtsj.hut.edu.cn',
      ];

      for (String domain in relatedDomains) {
        try {
          List<Cookie> domainCookies = await cookieManager.getCookies(
            url: WebUri(domain),
          );
          for (Cookie cookie in domainCookies) {
            if (cookie.name == cookieName) {
              return cookie.value;
            }
          }
        } catch (e) {
          // 忽略单个域名的错误，继续尝试下一个
          AppLogger.debug('获取域名 $domain 的cookie时出错: $e');
        }
      }

      return null;
    } catch (e) {
      AppLogger.debug('获取cookie时出错: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HUT统一认证'),
        leading: SizedBox(),
        //  leading: IconButton(
        //    icon: const Icon(Icons.arrow_back),
        //    onPressed: () => Navigator.of(context).pop(),
        //  ),
        //  actions: [
        //    if (_webViewController != null)
        //      IconButton(
        //        icon: const Icon(Icons.refresh),
        //        onPressed: () => _webViewController!.reload(),
        //      ),
        //  ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(
                '$_initialUrl?idToken=${widget.initialIdToken}&service=https%3A%2F%2Fjwxtsj.hut.edu.cn%2Fnjwhd%2FloginSso&token=${widget.initialIdToken}',
              ),
              headers: {
                "User-Agent":
                    "Mozilla/5.0 (Linux; Android 15; 24129PN74C Build/AQ3A.240812.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.39 Mobile Safari/537.36 SuperApp",
                "Connection": "keep-alive",
                "Accept":
                    "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
                "Accept-Encoding": "gzip, deflate, br, zstd",
                "sec-ch-ua":
                    "\"Chromium\";v=\"134\", \"Not:A-Brand\";v=\"24\", \"Android WebView\";v=\"134\"",
                "sec-ch-ua-mobile": "?1",
                "sec-ch-ua-platform": "\"Android\"",
                "upgrade-insecure-requests": "1",
                "x-requested-with": "com.supwisdom.hut",
                "sec-fetch-site": "none",
                "sec-fetch-mode": "navigate",
                "sec-fetch-user": "?1",
                "sec-fetch-dest": "document",
                "accept-language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
              },
            ),
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              useOnLoadResource: true,
              javaScriptEnabled: true,
              cacheEnabled: true,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url.toString();
              await _checkUrlAndExtractTokenAndCookie(url);
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStart: (controller, url) {
              if (url != null) {
                setState(() {
                  _isLoading = true;
                  _currentUrl = url.toString();
                });
                _checkUrlAndExtractTokenAndCookie(_currentUrl);
              }
            },
            onLoadStop: (controller, url) async {
              if (url != null) {
                setState(() {
                  _isLoading = false;
                  _currentUrl = url.toString();
                });
                await _checkUrlAndExtractTokenAndCookie(_currentUrl);
                await _checkHtmlAndExtractTokenAndCookie();

                AppLogger.debug('页面加载完成: $_currentUrl');
              }
            },
            onReceivedError: (controller, request, error) {
              setState(() {
                _isLoading = false;
              });
              if (widget.onError != null) {
                widget.onError!('页面加载错误: ${error.description}');
              }
            },
            onConsoleMessage: (controller, consoleMessage) {
              AppLogger.debug('Console: ${consoleMessage.message}');
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withAlpha(179),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

// 使用示例：

class HutLoginExample extends StatelessWidget {
  final String idToken;

  const HutLoginExample({super.key, required this.idToken});

  @override
  Widget build(BuildContext context) {
    return HutLoginSystem(
      initialIdToken: idToken,
      onTokenAndCookieExtracted: (result) {
        String token = result['token'] ?? '';
        String myClientTicket = result['my_client_ticket'] ?? '';
        AppLogger.debug('提取到的token: $token');
        AppLogger.debug('提取到的my_client_ticket: $myClientTicket');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('登录成功！')));
        Navigator.of(context).pop(result); // 返回包含token和cookie的Map并关闭页面
      },
      onError: (errorMessage) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        // );
      },
    );
  }
}
