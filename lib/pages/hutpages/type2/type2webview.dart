import 'dart:convert';

import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ionicons/ionicons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:superhut/utils/hut_user_api.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/ui/app_loading_indicator.dart';
import '../../../core/ui/app_snack_bar.dart';
import '../../../core/ui/color_scheme_ext.dart';
import '../hut_service_auth.dart';

typedef HutLocationPermissionHandler = Future<void> Function();
typedef HutExternalUrlOpener = Future<bool> Function(Uri url);

class Type2Webview extends StatefulWidget {
  const Type2Webview({
    super.key,
    required this.serviceId,
    required this.serviceUrl,
    required this.serviceName,
    required this.serviceType,
    required this.tokenAccept,
    this.servicePicUrl = '',
    this.loadPortalSession,
    this.openLoginPage,
    this.handleLocationPermission,
    this.openExternalUrl,
  });

  final String serviceId;
  final String serviceUrl;
  final String serviceName;
  final String serviceType;
  final String tokenAccept;
  final String servicePicUrl;
  final HutPortalSessionLoader? loadPortalSession;
  final HutLoginPageOpener? openLoginPage;
  final HutLocationPermissionHandler? handleLocationPermission;
  final HutExternalUrlOpener? openExternalUrl;

  @override
  State<Type2Webview> createState() => _Type2WebviewState();
}

class _Type2WebviewState extends State<Type2Webview> {
  static const String _webViewCookieDomain = 'xzhngydx.hut.edu.cn';

  final api = HutUserApi();
  InAppWebViewController? _webViewController;
  final ValueNotifier<bool> _canGoBackNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isPageLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isRequestingPermissionNotifier =
      ValueNotifier<bool>(false);
  bool _permissionRequested = false; // 添加标志，表示权限已请求过
  bool _hasWarnedLoginRedirect = false;
  bool _isOpeningLogin = false;
  bool _isLaunchingAlipay = false;
  bool _isHandlingBackNavigation = false;
  InAppWebViewController? _alipayHandlerController;
  late final ValueNotifier<Future<bool>> _initialSetupFutureNotifier;
  String? _setupErrorMessage;
  String? _cachedTokenAcceptSource;
  List<Map<String, dynamic>>? _cachedTokenAcceptList;
  List<String>? _cachedCookieTokenKeys;
  int _setupGeneration = 0;
  int _canGoBackGeneration = 0;

  Map<String, String> headerMap = {};
  String resultUrl = '';
  String token = '';

  List<Map<String, dynamic>> _parseTokenAccept(String tokenAccept) {
    try {
      final parsedList = json.decode(tokenAccept);
      if (parsedList is! List) {
        return <Map<String, dynamic>>[];
      }

      final tokenAcceptList = <Map<String, dynamic>>[];
      for (final item in parsedList) {
        if (item is Map) {
          tokenAcceptList.add(Map<String, dynamic>.from(item));
        }
      }
      return tokenAcceptList;
    } catch (error) {
      AppLogger.debug('Failed to parse tokenAccept: $error');
      return <Map<String, dynamic>>[];
    }
  }

  List<Map<String, dynamic>> _tokenAcceptList() {
    final source = widget.tokenAccept;
    final cachedList = _cachedTokenAcceptList;
    if (cachedList != null && _cachedTokenAcceptSource == source) {
      return cachedList;
    }

    final parsedList = _parseTokenAccept(source);
    _cachedTokenAcceptSource = source;
    _cachedTokenAcceptList = parsedList;
    _cachedCookieTokenKeys = null;
    return parsedList;
  }

  String _applyTokenAccept({
    required Map<String, String> headers,
    required String resultUrl,
    required String token,
  }) {
    var resolvedUrl = resultUrl;
    for (final item in _tokenAcceptList()) {
      final tokenType = item['tokenType']?.toString();
      final tokenKey = item['tokenKey']?.toString();
      if (tokenKey == null || tokenKey.isEmpty) {
        continue;
      }

      if (tokenType == 'header') {
        headers[tokenKey] = token;
      } else if (tokenType == 'url') {
        final uri = Uri.tryParse(resolvedUrl);
        if (uri == null) {
          continue;
        }
        final queryParams = Map<String, String>.from(uri.queryParameters);
        queryParams[tokenKey] = token;
        resolvedUrl = uri.replace(queryParameters: queryParams).toString();
      }
    }
    return resolvedUrl;
  }

  List<String> _getCookieTokenKeys() {
    final cachedKeys = _cachedCookieTokenKeys;
    if (cachedKeys != null) {
      return cachedKeys;
    }

    final cookieKeys = <String>[];
    for (final item in _tokenAcceptList()) {
      if (item['tokenType'] != 'cookie') {
        continue;
      }
      final key = item['tokenKey']?.toString() ?? '';
      if (key.isNotEmpty && !cookieKeys.contains(key)) {
        cookieKeys.add(key);
      }
    }

    final resolvedKeys =
        cookieKeys.isEmpty ? <String>['userToken'] : cookieKeys;
    _cachedCookieTokenKeys = resolvedKeys;
    return resolvedKeys;
  }

  String _buildCookieHeaderWithAttributes(String token) {
    final buffer = StringBuffer();
    for (final key in _getCookieTokenKeys()) {
      if (buffer.isNotEmpty) {
        buffer.write('; ');
      }
      buffer.write('$key=$token; Domain=$_webViewCookieDomain; Path=/');
    }
    return buffer.toString();
  }

  Future<void> _syncWebViewCookies({
    required Map<String, String> headers,
    required String resultUrl,
    required String token,
    required int generation,
  }) async {
    headers.remove('cookie');
    headers.remove('Cookie');

    if (defaultTargetPlatform == TargetPlatform.android) {
      headers['Cookie'] = _buildCookieHeaderWithAttributes(token);
    }

    await _injectWebViewCookies(
      resultUrl: resultUrl,
      token: token,
      generation: generation,
    );
  }

  Future<void> _injectWebViewCookies({
    required String resultUrl,
    required String token,
    required int generation,
  }) async {
    if (!_isCurrentSetup(generation)) {
      return;
    }
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
        if (!_isCurrentSetup(generation)) {
          return;
        }
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
      if (!_isCurrentSetup(generation)) {
        return;
      }

      final cookieTokenKeys = _getCookieTokenKeys();
      final cookies = await cookieManager.getCookies(url: webUri);
      if (!_isCurrentSetup(generation)) {
        return;
      }
      final cookieDebugInfo = StringBuffer();
      for (final cookie in cookies) {
        if (!cookieTokenKeys.contains(cookie.name)) {
          continue;
        }
        if (cookieDebugInfo.isNotEmpty) {
          cookieDebugInfo.write(', ');
        }
        cookieDebugInfo.write(
          '${cookie.name}; domain=${cookie.domain}; path=${cookie.path}',
        );
      }
      AppLogger.debug(
        'Type2 WebView cookies injected for ${webUri.toString()}: $cookieDebugInfo',
      );
    } catch (error) {
      AppLogger.debug('Type2 WebView cookie injection failed: $error');
    }
  }

  bool _isCurrentSetup(int generation) {
    return mounted && generation == _setupGeneration;
  }

  Future<bool> getDetail() {
    final generation = ++_setupGeneration;
    return _loadDetail(generation);
  }

  @visibleForTesting
  Future<bool> debugReloadPortalSession() {
    return getDetail();
  }

  @visibleForTesting
  String get debugToken => token;

  @visibleForTesting
  String get debugResultUrl => resultUrl;

  @visibleForTesting
  Map<String, String> get debugHeaderMap => headerMap;

  @visibleForTesting
  Future<void> debugHandleAlipayUrl(String url) {
    return _handleAlipayUrl(url);
  }

  Future<bool> _loadDetail(int generation) async {
    try {
      final session =
          await widget.loadPortalSession?.call(api) ??
          await loadValidHutPortalSession(api);
      final nextToken = session.token;
      final nextHeaders = buildHutWebViewHeaders(
        token: nextToken,
        profile: HutWebViewHeaderProfile.type2,
      );
      String nextResultUrl;
      if (widget.serviceType == '5' && widget.serviceId.isNotEmpty) {
        final detailUrl = buildHutPortalServiceDetailUrl(
          serviceId: widget.serviceId,
          serviceName: widget.serviceName,
          servicePicUrl: widget.servicePicUrl,
        );
        nextResultUrl = buildHutPortalServiceEntryUrl(
          targetUrl: detailUrl,
          token: session.token,
          ticket: session.ticket,
        );
      } else {
        nextResultUrl = _applyTokenAccept(
          headers: nextHeaders,
          resultUrl: normalizeHutPortalUrl(widget.serviceUrl),
          token: nextToken,
        );
      }
      if (!_isCurrentSetup(generation)) {
        return false;
      }

      await _syncWebViewCookies(
        headers: nextHeaders,
        resultUrl: nextResultUrl,
        token: nextToken,
        generation: generation,
      );
      if (!_isCurrentSetup(generation)) {
        return false;
      }

      token = nextToken;
      headerMap = nextHeaders;
      resultUrl = nextResultUrl;
      _setupErrorMessage = null;
      AppLogger.debug(
        'Type2 result url prepared: ${describeHutUrlForLog(resultUrl)}',
      );
      return true;
    } catch (error, stackTrace) {
      if (_isCurrentSetup(generation)) {
        _setupErrorMessage = resolveHutServiceAuthErrorMessage(error);
      }
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
    _initialSetupFutureNotifier = ValueNotifier<Future<bool>>(
      _performInitialSetup(),
    );
  }

  @override
  void dispose() {
    _initialSetupFutureNotifier.dispose();
    _canGoBackNotifier.dispose();
    _isPageLoadingNotifier.dispose();
    _isRequestingPermissionNotifier.dispose();
    super.dispose();
  }

  // 初始化设置，包括权限请求和数据加载
  Future<bool> _performInitialSetup() async {
    final generation = ++_setupGeneration;
    await (widget.handleLocationPermission?.call() ??
        _handleLocationPermission());
    if (!_isCurrentSetup(generation)) {
      return false;
    }
    return await _loadDetail(generation);
  }

  Future<void> _openLoginAndRetry() async {
    if (!mounted || _isOpeningLogin) {
      return;
    }

    _isOpeningLogin = true;
    try {
      await (widget.openLoginPage?.call(context) ?? openHutLoginPage(context));
      if (!mounted) {
        return;
      }
      _setupErrorMessage = null;
      _hasWarnedLoginRedirect = false;
      _initialSetupFutureNotifier.value = _performInitialSetup();
    } finally {
      _isOpeningLogin = false;
    }
  }

  void _setPageLoading(bool isLoading) {
    if (!mounted || _isPageLoadingNotifier.value == isLoading) {
      return;
    }

    _isPageLoadingNotifier.value = isLoading;
  }

  void _setRequestingPermission(bool isRequestingPermission) {
    if (!mounted ||
        _isRequestingPermissionNotifier.value == isRequestingPermission) {
      return;
    }

    _isRequestingPermissionNotifier.value = isRequestingPermission;
  }

  void _handlePossibleLoginRedirect(WebUri? url) {
    if (!mounted || _hasWarnedLoginRedirect || !isLikelyHutLoginUrl(url)) {
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

    _permissionRequested = true;

    try {
      final status = await Permission.location.status;

      // 已经有权限，不需要再请求
      if (!mounted || status == PermissionStatus.granted) {
        return;
      }

      // 请求权限
      _setRequestingPermission(true);
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
      _setRequestingPermission(false);
    }
  }

  Future<void> _handleBackNavigationRequest() async {
    if (_isHandlingBackNavigation) {
      return;
    }

    _isHandlingBackNavigation = true;
    var shouldResetBackGuard = true;
    try {
      if (_webViewController != null && await _webViewController!.canGoBack()) {
        await _webViewController!.goBack();
        return;
      }

      if (!mounted) {
        return;
      }

      shouldResetBackGuard = false;
      Navigator.of(context).pop();
    } finally {
      if (shouldResetBackGuard) {
        _isHandlingBackNavigation = false;
      }
    }
  }

  // 更新是否可以回退的状态
  void _updateCanGoBackState() async {
    final controller = _webViewController;
    if (controller == null) {
      return;
    }

    final generation = ++_canGoBackGeneration;
    final canGoBack = await controller.canGoBack();
    if (!mounted ||
        generation != _canGoBackGeneration ||
        !identical(controller, _webViewController) ||
        canGoBack == _canGoBackNotifier.value) {
      return;
    }

    _canGoBackNotifier.value = canGoBack;
  }

  // 删除网页中的导航栏返回按钮
  void _removeNavigationElement() async {
    if (_webViewController != null) {
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

          if (removeElement() || window.__superhutHideNavObserver) {
            return;
          }

          var observer = new MutationObserver(function() {
            if (removeElement()) {
              observer.disconnect();
              window.__superhutHideNavObserver = null;
            }
          });
          window.__superhutHideNavObserver = observer;

          observer.observe(document.body, {
            childList: true,
            subtree: true
          });

          setTimeout(function() {
            if (window.__superhutHideNavObserver === observer) {
              observer.disconnect();
              window.__superhutHideNavObserver = null;
            }
          }, 60000);
        })();
      ''',
      );
    }
  }

  void _registerAlipayJavaScriptHandler(InAppWebViewController controller) {
    if (identical(_alipayHandlerController, controller)) {
      return;
    }

    _alipayHandlerController = controller;
    controller.addJavaScriptHandler(
      handlerName: 'alipayLink',
      callback: (args) {
        if (args.isNotEmpty && args[0] is String) {
          final url = args[0] as String;
          if (url.startsWith('alipays://')) {
            _handleAlipayUrl(url);
          }
        }
        return true;
      },
    );
  }

  // 监听页面中的支付宝链接。脚本需要幂等，避免 onLoadStop 多次触发时重复挂监听器。
  void _setupAlipayLinkListener() async {
    if (_webViewController != null) {
      await _webViewController!.evaluateJavascript(
        source: '''
        (function() {
          if (window.__superhutAlipayBridgeInstalled) {
            return;
          }
          window.__superhutAlipayBridgeInstalled = true;

          function notifyAlipay(url) {
            if (!url || !url.toString().startsWith('alipays://')) {
              return false;
            }
            if (
              window.flutter_inappwebview &&
              window.flutter_inappwebview.callHandler
            ) {
              window.flutter_inappwebview.callHandler('alipayLink', url.toString());
            }
            return true;
          }

          document.addEventListener('click', function(e) {
            var target = e.target;
            while(target && target.tagName !== 'A') {
              target = target.parentElement;
            }

            if (target && target.href && notifyAlipay(target.href)) {
              e.preventDefault();
              return false;
            }
          }, true);

          var originalAssign = window.location.assign;
          window.location.assign = function(url) {
            if (notifyAlipay(url)) {
              return;
            }
            originalAssign.apply(this, arguments);
          };

          var originalReplace = window.location.replace;
          window.location.replace = function(url) {
            if (notifyAlipay(url)) {
              return;
            }
            originalReplace.apply(this, arguments);
          };

          var originalOpen = window.open;
          window.open = function(url, target, features) {
            if (notifyAlipay(url)) {
              return null;
            }
            return originalOpen.call(this, url, target, features);
          };
        })();
      ''',
      );
    }
  }

  Future<void> _handleAlipayUrl(String url) async {
    if (_isLaunchingAlipay) {
      return;
    }

    _isLaunchingAlipay = true;
    try {
      final Uri uri = Uri.parse(url);
      final navigator = Navigator.of(context);
      AppLogger.debug(
        'Attempting to open Alipay url: ${describeHutUrlForLog(url)}',
      );
      final opener = widget.openExternalUrl ?? launchUrl;
      final didLaunch = await opener(uri);
      if (!mounted) {
        return;
      }

      if (!didLaunch) {
        showAppSnackBar(
          context,
          message: '无法打开支付宝，请稍后重试',
          type: AppSnackBarType.error,
        );
        return;
      }

      navigator.pop();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to open Alipay url from Type2 WebView',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          message: '无法打开支付宝，请稍后重试',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _isLaunchingAlipay = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: _canGoBackNotifier,
      child: SafeArea(
        child: Scaffold(
          extendBodyBehindAppBar: true,
          // 移除AppBar，使用Stack来实现悬浮返回按钮
          body: SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // WebView占满整个屏幕
                Positioned.fill(
                  child: ValueListenableBuilder<Future<bool>>(
                    valueListenable: _initialSetupFutureNotifier,
                    builder: (context, initialSetupFuture, _) {
                      return EnhancedFutureBuilder(
                        future: initialSetupFuture,
                        rememberFutureResult: true,
                        whenDone: (v) {
                          if (v != true) {
                            return HutServiceAuthErrorPanel(
                              message:
                                  _setupErrorMessage ?? '智慧工大登录状态已失效，请重新登录一次。',
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
                              _setPageLoading(true);
                              AppLogger.debug(
                                'Type2 start loading: ${describeHutUrlForLog(url.toString())}',
                              );
                            },
                            onWebViewCreated: (controller) {
                              _webViewController = controller;
                              _registerAlipayJavaScriptHandler(controller);
                            },
                            onLoadStop: (controller, url) {
                              _handlePossibleLoginRedirect(url);
                              _setPageLoading(false);
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
                              final url =
                                  navigationAction.request.url.toString();

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
                          child: AppLoadingIndicator(
                            color: colorScheme.primary,
                            size: 40,
                          ),
                        ),
                      );
                    },
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
                      onPressed: _handleBackNavigationRequest,
                      icon: Icon(
                        Ionicons.arrow_back_circle_outline,
                        color: colorScheme.onSurface,
                        size: 28,
                      ),
                    ),
                  ),
                ),

                // 网页加载指示器
                ValueListenableBuilder<bool>(
                  valueListenable: _isPageLoadingNotifier,
                  builder: (context, isPageLoading, _) {
                    if (!isPageLoading) {
                      return const SizedBox.shrink();
                    }
                    return const Positioned.fill(
                      child: HutWebViewLoadingOverlay(message: '加载中...'),
                    );
                  },
                ),
                // 权限请求指示器
                ValueListenableBuilder<bool>(
                  valueListenable: _isRequestingPermissionNotifier,
                  builder: (context, isRequestingPermission, _) {
                    if (!isRequestingPermission) {
                      return const SizedBox.shrink();
                    }
                    return const Positioned.fill(
                      child: HutWebViewLoadingOverlay(message: '请求位置权限...'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      builder: (context, canGoBack, child) {
        return PopScope(
          canPop: !canGoBack,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            await _handleBackNavigationRequest();
          },
          child: child!,
        );
      },
    );
  }
}
