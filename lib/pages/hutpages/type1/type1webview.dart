import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/ui/app_snack_bar.dart';
import '../../../core/ui/color_scheme_ext.dart';
import '../hut_service_auth.dart';

class Type1Webview extends StatefulWidget {
  final String serviceId, serviceUrl, serviceName, servicePicUrl;

  const Type1Webview({
    super.key,
    required this.serviceId,
    required this.serviceUrl,
    required this.serviceName,
    this.servicePicUrl = '',
  });

  @override
  State<Type1Webview> createState() => _Type1WebviewState();
}

class _Type1WebviewState extends State<Type1Webview> {
  final api = HutUserApi();
  String resultUrl = '';
  String token = '';
  bool _isPageLoading = false;
  bool _hasWarnedLoginRedirect = false;
  String? _setupErrorMessage;
  late Future<bool> _initialSetupFuture;

  @override
  void initState() {
    super.initState();
    _initialSetupFuture = getDetail();
  }

  Future<bool> getDetail() async {
    try {
      _setupErrorMessage = null;
      final session = await loadValidHutPortalSession(api);
      token = session.token;
      if (widget.serviceId.isNotEmpty) {
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
        resultUrl = buildHutCasLoginUrl(
          serviceUrl: widget.serviceUrl,
          idToken: session.token,
        );
      }
      AppLogger.debug(
        'Type1 result url prepared: ${describeHutUrlForLog(resultUrl)}',
      );
      return true;
    } catch (error, stackTrace) {
      _setupErrorMessage = error.toString().replaceFirst('Bad state: ', '');
      AppLogger.error(
        'Failed to prepare HUT type1 service',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Map<String, String> _initialHeaders() {
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
      "Upgrade-Insecure-Requests": "1",
      "X-Id-Token": token,
      "x-id-token": token,
      "X-Requested-With": "com.supwisdom.hut",
      "Sec-Fetch-Site": "none",
      "Sec-Fetch-Mode": "navigate",
      "Sec-Fetch-User": "?1",
      "Sec-Fetch-Dest": "document",
      "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
      "Cookie": "userToken=$token",
    };
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
      'Type1 rewrite legacy portal url: ${describeHutUrlForLog(normalizedUrl)}',
    );
    await controller.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(normalizedUrl),
        headers: _initialHeaders(),
      ),
    );
    return NavigationActionPolicy.CANCEL;
  }

  Future<void> _openLoginAndRetry() async {
    await openHutLoginPage(context);
    if (!mounted) {
      return;
    }
    setState(() {
      _setupErrorMessage = null;
      _hasWarnedLoginRedirect = false;
      _initialSetupFuture = getDetail();
    });
  }

  void _handlePossibleLoginRedirect(WebUri? url) {
    if (_hasWarnedLoginRedirect || !isLikelyHutLoginUrl(url)) {
      return;
    }
    final hasIdToken = url?.queryParameters.containsKey('idToken') ?? false;
    if (hasIdToken) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("智慧工大")),
      body: EnhancedFutureBuilder(
        future: _initialSetupFuture,
        rememberFutureResult: true,
        whenDone: (v) {
          final colorScheme = Theme.of(context).colorScheme;
          if (v != true) {
            return HutServiceAuthErrorPanel(
              message: _setupErrorMessage ?? '智慧工大登录状态已失效，请重新登录一次。',
              onLogin: _openLoginAndRetry,
            );
          }

          return Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(resultUrl),
                  headers: _initialHeaders(), // 自定义 Header
                ),
                initialSettings: InAppWebViewSettings(
                  useShouldOverrideUrlLoading: true,
                ),

                onLoadStart: (controller, url) {
                  setState(() {
                    _isPageLoading = true;
                  });
                  AppLogger.debug(
                    'Type1 start loading: ${describeHutUrlForLog(url.toString())}',
                  );
                },

                onLoadStop: (controller, url) {
                  _handlePossibleLoginRedirect(url);
                  setState(() {
                    _isPageLoading = false;
                  });
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return _rewriteLegacyPortalNavigation(
                    controller,
                    navigationAction,
                  );
                },
              ),
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
                              '页面加载中...',
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
          );
        },
        whenNotDone: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
