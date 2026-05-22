import 'dart:convert';

import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:superhut/utils/hut_user_api.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/ui/app_snack_bar.dart';
import '../../../core/ui/color_scheme_ext.dart';
import '../hut_service_auth.dart';

class Type2Webview extends StatefulWidget {
  final String serviceId;
  final String serviceUrl;
  final String serviceName;
  final String serviceType;
  final String tokenAccept;
  final String servicePicUrl;

  const Type2Webview({
    super.key,
    required this.serviceId,
    required this.serviceUrl,
    required this.serviceName,
    required this.serviceType,
    required this.tokenAccept,
    this.servicePicUrl = '',
  });

  @override
  State<Type2Webview> createState() => _Type2WebviewState();
}

class _Type2WebviewState extends State<Type2Webview> {
  static const String _webViewCookieDomain = 'xzhngydx.hut.edu.cn';

  final api = HutUserApi();
  InAppWebViewController? _webViewController;
  bool _canGoBack = false;
  bool _isPageLoading = false;
  bool _isRequestingPermission = false;
  bool _permissionRequested = false; // 添加标志，表示权限已请求过
  bool _hasWarnedLoginRedirect = false;
  late Future<bool> _initialSetupFuture;
  String? _setupErrorMessage;

  Map<String, String> headerMap = {};
  String resultUrl = '';
  String token = '';

  Map<String, String> _baseHeaders(String token) {
    return {
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
      "X-Id-Token": token,
      "x-id-token": token,
      "x-requested-with": "com.supwisdom.hut",
      "sec-fetch-site": "none",
      "sec-fetch-mode": "navigate",
      "sec-fetch-user": "?1",
      "sec-fetch-dest": "document",
      "accept-language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
      "priority": "u=0, i",
    };
  }

  List<Map<String, dynamic>> _parseTokenAccept(String tokenAccept) {
    try {
      final parsedList = json.decode(tokenAccept);
      if (parsedList is! List) {
        return <Map<String, dynamic>>[];
      }

      return parsedList
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (error) {
      AppLogger.debug('Failed to parse tokenAccept: $error');
      return <Map<String, dynamic>>[];
    }
  }

  void _applyTokenAccept() {
    final tokenAcceptList = _parseTokenAccept(widget.tokenAccept);
    for (final item in tokenAcceptList) {
      final tokenType = item['tokenType']?.toString();
      final tokenKey = item['tokenKey']?.toString();
      if (tokenKey == null || tokenKey.isEmpty) {
        continue;
      }

      if (tokenType == 'header') {
        headerMap[tokenKey] = token;
      } else if (tokenType == 'url') {
        final uri = Uri.tryParse(resultUrl);
        if (uri == null) {
          continue;
        }
        final queryParams = Map<String, String>.from(uri.queryParameters);
        queryParams[tokenKey] = token;
        resultUrl = uri.replace(queryParameters: queryParams).toString();
      }
    }
  }

  List<String> _getCookieTokenKeys() {
    final tokenAcceptList = _parseTokenAccept(widget.tokenAccept);
    final cookieKeys =
        tokenAcceptList
            .where((item) => item['tokenType'] == 'cookie')
            .map((item) => item['tokenKey']?.toString() ?? '')
            .where((key) => key.isNotEmpty)
            .toSet()
            .toList();

    return cookieKeys.isEmpty ? ['userToken'] : cookieKeys;
  }

  String _buildCookieHeaderWithAttributes() {
    return _getCookieTokenKeys()
        .map((key) => '$key=$token; Domain=$_webViewCookieDomain; Path=/')
        .join('; ');
  }

  Future<void> _syncWebViewCookies() async {
    headerMap.remove('cookie');
    headerMap.remove('Cookie');

    if (defaultTargetPlatform == TargetPlatform.android) {
      headerMap['Cookie'] = _buildCookieHeaderWithAttributes();
    }

    await _injectWebViewCookies();
  }

  Future<void> _injectWebViewCookies() async {
    if (resultUrl.isEmpty || token.isEmpty) {
      return;
    }

    try {
      final uri = Uri.parse(resultUrl);
      if (!uri.hasScheme || uri.host.isEmpty) {
        return;
      }

      final cookieManager = CookieManager.instance();
      final webUri = WebUri('${uri.scheme}://$_webViewCookieDomain');

      for (final cookieName in _getCookieTokenKeys()) {
        await cookieManager.setCookie(
          url: webUri,
          name: cookieName,
          value: token,
          domain: _webViewCookieDomain,
          path: '/',
          isSecure: uri.scheme == 'https',
          sameSite: HTTPCookieSameSitePolicy.LAX,
        );
      }

      final cookies = await cookieManager.getCookies(url: webUri);
      final cookieDebugInfo = cookies
          .where((cookie) => _getCookieTokenKeys().contains(cookie.name))
          .map(
            (cookie) =>
                '${cookie.name}; domain=${cookie.domain}; path=${cookie.path}',
          )
          .join(', ');
      AppLogger.debug(
        'Type2 WebView cookies injected for ${webUri.toString()}: $cookieDebugInfo',
      );
    } catch (error) {
      AppLogger.debug('Type2 WebView cookie injection failed: $error');
    }
  }

  Future<bool> getDetail() async {
    try {
      _setupErrorMessage = null;
      final session = await loadValidHutPortalSession(api);
      token = session.token;
      headerMap = _baseHeaders(token);
      if (widget.serviceType == '5' && widget.serviceId.isNotEmpty) {
        final detailUrl = buildHutPortalServiceDetailUrl(
          serviceId: widget.serviceId,
          serviceName: widget.serviceName,
          servicePicUrl: widget.servicePicUrl,
        );
        resultUrl = buildHutPortalServiceEntryUrl(
          targetUrl: detailUrl,
          token: session.token,
          ticket: session.ticket,
        );
      } else {
        resultUrl = normalizeHutPortalUrl(widget.serviceUrl);
        _applyTokenAccept();
      }
      await _syncWebViewCookies();
      AppLogger.debug(
        'Type2 result url prepared: ${describeHutUrlForLog(resultUrl)}',
      );
      return true;
    } catch (error, stackTrace) {
      _setupErrorMessage = error.toString().replaceFirst('Bad state: ', '');
      AppLogger.error(
        'Failed to prepare HUT type2 service',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    // 在 initState 中初始化而不是在 build 中重复调用
    _initialSetupFuture = _performInitialSetup();
  }

  // 初始化设置，包括权限请求和数据加载
  Future<bool> _performInitialSetup() async {
    await _handleLocationPermission();
    return await getDetail();
  }

  Future<void> _openLoginAndRetry() async {
    await openHutLoginPage(context);
    if (!mounted) {
      return;
    }
    setState(() {
      _setupErrorMessage = null;
      _hasWarnedLoginRedirect = false;
      _initialSetupFuture = _performInitialSetup();
    });
  }

  void _handlePossibleLoginRedirect(WebUri? url) {
    if (_hasWarnedLoginRedirect || !isLikelyHutLoginUrl(url)) {
      return;
    }

    _hasWarnedLoginRedirect = true;
    showAppSnackBar(
      context,
      message: '智慧工大登录状态可能已失效，请重新登录后再试',
      type: AppSnackBarType.warning,
      icon: Icons.lock_reset_rounded,
      actionLabel: '重新登录',
      onAction: () {
        _openLoginAndRetry();
      },
    );
  }

  Future<NavigationActionPolicy> _rewriteLegacyPortalNavigation(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) async {
    final url = navigationAction.request.url?.toString();
    if (url == null) {
      return NavigationActionPolicy.ALLOW;
    }

    final normalizedUrl = normalizeHutPortalUrl(url);
    if (normalizedUrl == url) {
      return NavigationActionPolicy.ALLOW;
    }

    AppLogger.debug(
      'Type2 rewrite legacy portal url: ${describeHutUrlForLog(normalizedUrl)}',
    );
    await controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(normalizedUrl), headers: headerMap),
    );
    return NavigationActionPolicy.CANCEL;
  }

  // 处理位置权限一次性请求
  Future<void> _handleLocationPermission() async {
    if (_permissionRequested) return; // 如果已经请求过，不再请求

    setState(() {
      _isRequestingPermission = true;
      _permissionRequested = true;
    });

    try {
      final status = await Permission.location.status;

      // 已经有权限，不需要再请求
      if (status == PermissionStatus.granted) {
        return;
      }

      // 请求权限
      final result = await Permission.location.request();
      if (result != PermissionStatus.granted) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          message: '某些功能可能需要位置权限才能正常使用',
          type: AppSnackBarType.warning,
        );
      }
    } catch (e) {
      AppLogger.debug('请求位置权限错误: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
        });
      }
    }
  }

  // 处理WebView的回退逻辑
  Future<bool> _handleBackPressed() async {
    if (_webViewController != null && await _webViewController!.canGoBack()) {
      _webViewController!.goBack();
      return false; // 不关闭页面，只是返回上一个网页
    } else {
      return true; // 关闭页面
    }
  }

  // 更新是否可以回退的状态
  void _updateCanGoBackState() async {
    if (_webViewController != null) {
      bool canGoBack = await _webViewController!.canGoBack();
      if (!mounted) {
        return;
      }
      if (canGoBack != _canGoBack) {
        setState(() {
          _canGoBack = canGoBack;
        });
      }
    }
  }

  // 删除网页中的导航栏返回按钮
  void _removeNavigationElement() async {
    if (_webViewController != null) {
      // 使用JavaScript删除指定元素
      await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          function removeElement() {
            var elements = document.querySelectorAll('.van-nav-bar__left');
            if (elements.length > 0) {
              for (var i = 0; i < elements.length; i++) {
                elements[i].style.display = 'none';
              }
              return true;
            }
            return false;
          }
          
          // 立即尝试移除元素
          if (!removeElement()) {
            // 如果元素尚未加载，设置一个观察器来监视DOM变化
            var observer = new MutationObserver(function(mutations) {
              if (removeElement()) {
                observer.disconnect(); // 成功移除后停止观察
              }
            });
            
            observer.observe(document.body, {
              childList: true,
              subtree: true
            });
            
            // 60秒后停止观察以避免内存泄漏
            setTimeout(function() {
              observer.disconnect();
            }, 60000);
          }
        })();
      ''',
      );
    }
  }

  // 监听页面中的支付宝链接
  void _setupAlipayLinkListener() async {
    if (_webViewController != null) {
      await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          // 拦截所有的a标签点击
          document.addEventListener('click', function(e) {
            var target = e.target;
            // 遍历父元素找到最近的a标签
            while(target && target.tagName !== 'A') {
              target = target.parentElement;
            }
            
            if (target && target.href) {
              var url = target.href;
              if (url.startsWith('alipays://')) {
                // 通知Flutter处理支付宝链接
                window.flutter_inappwebview.callHandler('alipayLink', url);
                e.preventDefault();
                return false;
              }
            }
          }, true);
          
          // 拦截window.location变更
          var originalAssign = window.location.assign;
          window.location.assign = function(url) {
            if (url && url.toString().startsWith('alipays://')) {
              window.flutter_inappwebview.callHandler('alipayLink', url);
              return;
            }
            originalAssign.apply(this, arguments);
          };
          
          var originalReplace = window.location.replace;
          window.location.replace = function(url) {
            if (url && url.toString().startsWith('alipays://')) {
              window.flutter_inappwebview.callHandler('alipayLink', url);
              return;
            }
            originalReplace.apply(this, arguments);
          };
          
          // 拦截window.open
          var originalOpen = window.open;
          window.open = function(url, target, features) {
            if (url && url.toString().startsWith('alipays://')) {
              window.flutter_inappwebview.callHandler('alipayLink', url);
              return null;
            }
            return originalOpen.call(this, url, target, features);
          };
          
          // 监控DOM变化，查找动态添加的支付宝链接
          var observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              if (mutation.type === 'attributes' && mutation.attributeName === 'href') {
                var element = mutation.target;
                if (element.href && element.href.startsWith('alipays://')) {
                  element.addEventListener('click', function(e) {
                    window.flutter_inappwebview.callHandler('alipayLink', element.href);
                    e.preventDefault();
                  });
                }
              }
            });
          });
          
          observer.observe(document.body, {
            attributes: true,
            attributeFilter: ['href'],
            childList: true,
            subtree: true
          });
        })();
      ''',
      );

      // 注册处理程序来接收JavaScript的回调
      _webViewController!.addJavaScriptHandler(
        handlerName: 'alipayLink',
        callback: (args) {
          if (args.isNotEmpty && args[0] is String) {
            String url = args[0];
            if (url.startsWith('alipays://')) {
              // 不要尝试使用_handleAlipayUrl的返回值
              _handleAlipayUrl(url);
            }
          }
          // 确保回调始终返回一个值给JavaScript
          return true;
        },
      );
    }
  }

  Future<void> _handleAlipayUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      final navigator = Navigator.of(context);
      AppLogger.debug('Attempting to open Alipay url: $url');
      final didLaunch = await launchUrl(uri);
      if (!mounted) {
        return;
      }

      if (!didLaunch) {
        showAppSnackBar(
          context,
          message: '无法打开支付宝: $url',
          type: AppSnackBarType.error,
        );
        return;
      }

      navigator.pop();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: '打开链接失败：$e',
          type: AppSnackBarType.error,
        );
      }
      AppLogger.debug('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final navigator = Navigator.of(context);
        final shouldPop = await _handleBackPressed();
        if (!mounted || !shouldPop) {
          return;
        }
        navigator.pop();
      },
      child: SafeArea(
        child: Scaffold(
          extendBodyBehindAppBar: true,
          // 移除AppBar，使用Stack来实现悬浮返回按钮
          body: Stack(
            children: [
              // WebView占满整个屏幕
              Positioned.fill(
                child: EnhancedFutureBuilder(
                  future: _initialSetupFuture,
                  rememberFutureResult: true,
                  whenDone: (v) {
                    if (v != true) {
                      return HutServiceAuthErrorPanel(
                        message: _setupErrorMessage ?? '智慧工大登录状态已失效，请重新登录一次。',
                        onLogin: _openLoginAndRetry,
                      );
                    }

                    return InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(resultUrl),
                        headers: headerMap, // 自定义 Header
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        geolocationEnabled: true,
                        // 启用地理位置功能
                        supportZoom: true,
                        mediaPlaybackRequiresUserGesture: false,
                        // 允许自动播放媒体
                        allowsInlineMediaPlayback: true,
                        useShouldOverrideUrlLoading: true,
                        useOnLoadResource: true,
                      ),
                      onGeolocationPermissionsShowPrompt: (
                        controller,
                        origin,
                      ) async {
                        // 直接允许所有地理位置请求，不再弹出系统对话框
                        return GeolocationPermissionShowPromptResponse(
                          origin: origin,
                          allow: true,
                          retain: true,
                        );
                      },
                      onLoadStart: (controller, url) {
                        setState(() {
                          _isPageLoading = true;
                        });
                        AppLogger.debug(
                          'Type2 start loading: ${describeHutUrlForLog(url.toString())}',
                        );
                      },
                      onWebViewCreated: (controller) {
                        _webViewController = controller;
                      },
                      onLoadStop: (controller, url) {
                        _handlePossibleLoginRedirect(url);
                        setState(() {
                          _isPageLoading = false;
                        });
                        _updateCanGoBackState();
                        _removeNavigationElement();
                        _setupAlipayLinkListener(); // 添加支付宝链接监听
                        AppLogger.debug(
                          'Type2 stop loading: ${describeHutUrlForLog(url.toString())}',
                        );
                      },
                      onUpdateVisitedHistory: (
                        controller,
                        url,
                        androidIsReload,
                      ) {
                        _handlePossibleLoginRedirect(url);
                        _updateCanGoBackState();
                        AppLogger.debug(
                          'Type2 history updated: ${describeHutUrlForLog(url.toString())}',
                        );
                      },
                      shouldOverrideUrlLoading: (
                        controller,
                        navigationAction,
                      ) async {
                        final url = navigationAction.request.url.toString();

                        // 检查是否是支付宝协议链接
                        if (url.startsWith('alipays://')) {
                          _handleAlipayUrl(url);
                          return NavigationActionPolicy.CANCEL;
                        }

                        return _rewriteLegacyPortalNavigation(
                          controller,
                          navigationAction,
                        );
                      },
                    );
                  },
                  whenNotDone: Center(
                    child: LoadingAnimationWidget.inkDrop(
                      color: colorScheme.primary,
                      size: 40,
                    ),
                  ),
                ),
              ),

              // 悬浮返回按钮，放在左上角，不会阻挡其他内容的点击
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.floatingSurfaceStrong,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.subtleBorder),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Ionicons.arrow_back_circle_outline,
                      color: colorScheme.onSurface,
                      size: 28,
                    ),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      if (!await _handleBackPressed()) {
                        return;
                      }
                      if (!mounted) {
                        return;
                      }
                      navigator.pop();
                    },
                  ),
                ),
              ),

              // 网页加载指示器
              if (_isPageLoading)
                Positioned.fill(
                  child: Container(
                    color: colorScheme.overlayScrim,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.floatingSurfaceStrong,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: colorScheme.subtleBorder),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LoadingAnimationWidget.inkDrop(
                              color: colorScheme.primary,
                              size: 40,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '加载中...',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // 权限请求指示器
              if (_isRequestingPermission)
                Positioned.fill(
                  child: Container(
                    color: colorScheme.overlayScrim,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.floatingSurfaceStrong,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: colorScheme.subtleBorder),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '请求位置权限...',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
