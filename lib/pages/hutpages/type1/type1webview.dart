import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/ui/app_loading_indicator.dart';
import '../../../core/ui/app_snack_bar.dart';
import '../hut_service_auth.dart';

class Type1Webview extends StatefulWidget {
  const Type1Webview({
    super.key,
    required this.serviceId,
    required this.serviceUrl,
    required this.serviceName,
    this.servicePicUrl = '',
    this.loadPortalSession,
    this.openLoginPage,
  });

  final String serviceId, serviceUrl, serviceName, servicePicUrl;
  final HutPortalSessionLoader? loadPortalSession;
  final HutLoginPageOpener? openLoginPage;

  @override
  State<Type1Webview> createState() => _Type1WebviewState();
}

class _Type1WebviewState extends State<Type1Webview> {
  final api = HutUserApi();
  String resultUrl = '';
  String token = '';
  Map<String, String> headerMap = {};
  final ValueNotifier<bool> _isPageLoadingNotifier = ValueNotifier<bool>(false);
  bool _hasWarnedLoginRedirect = false;
  bool _isOpeningLogin = false;
  String? _setupErrorMessage;
  int _setupGeneration = 0;
  late final ValueNotifier<Future<bool>> _initialSetupFutureNotifier;

  @override
  void initState() {
    super.initState();
    _initialSetupFutureNotifier = ValueNotifier<Future<bool>>(getDetail());
  }

  @override
  void dispose() {
    _initialSetupFutureNotifier.dispose();
    _isPageLoadingNotifier.dispose();
    super.dispose();
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

  Future<bool> _loadDetail(int generation) async {
    try {
      final session =
          await widget.loadPortalSession?.call(api) ??
          await loadValidHutPortalSession(api);
      final nextToken = session.token;
      final String nextResultUrl;
      if (widget.serviceId.isNotEmpty) {
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
        nextResultUrl = buildHutCasLoginUrl(
          serviceUrl: widget.serviceUrl,
          idToken: session.token,
        );
      }
      if (!_isCurrentSetup(generation)) {
        return false;
      }

      final nextHeaders = buildHutWebViewHeaders(
        token: nextToken,
        profile: HutWebViewHeaderProfile.type1,
      );
      token = nextToken;
      headerMap = nextHeaders;
      resultUrl = nextResultUrl;
      _setupErrorMessage = null;
      AppLogger.debug(
        'Type1 result url prepared: ${describeHutUrlForLog(resultUrl)}',
      );
      return true;
    } catch (error, stackTrace) {
      if (_isCurrentSetup(generation)) {
        _setupErrorMessage = resolveHutServiceAuthErrorMessage(error);
      }
      AppLogger.error(
        'Failed to prepare HUT type1 service',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
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
      urlRequest: URLRequest(url: WebUri(normalizedUrl), headers: headerMap),
    );
    return NavigationActionPolicy.CANCEL;
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
      _initialSetupFutureNotifier.value = getDetail();
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

  void _handlePossibleLoginRedirect(WebUri? url) {
    if (!mounted || _hasWarnedLoginRedirect || !isLikelyHutLoginUrl(url)) {
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
      body: ValueListenableBuilder<Future<bool>>(
        valueListenable: _initialSetupFutureNotifier,
        builder: (context, initialSetupFuture, _) {
          return EnhancedFutureBuilder(
            future: initialSetupFuture,
            rememberFutureResult: true,
            whenDone: (v) {
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
                      headers: headerMap, // 自定义 Header
                    ),
                    initialSettings: InAppWebViewSettings(
                      useShouldOverrideUrlLoading: true,
                    ),

                    onLoadStart: (controller, url) {
                      _setPageLoading(true);
                      AppLogger.debug(
                        'Type1 start loading: ${describeHutUrlForLog(url.toString())}',
                      );
                    },

                    onLoadStop: (controller, url) {
                      _handlePossibleLoginRedirect(url);
                      _setPageLoading(false);
                    },
                    shouldOverrideUrlLoading: (
                      controller,
                      navigationAction,
                    ) async {
                      return _rewriteLegacyPortalNavigation(
                        controller,
                        navigationAction,
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _isPageLoadingNotifier,
                    builder: (context, isPageLoading, _) {
                      if (!isPageLoading) {
                        return const SizedBox.shrink();
                      }
                      return const Positioned.fill(
                        child: HutWebViewLoadingOverlay(message: '页面加载中...'),
                      );
                    },
                  ),
                ],
              );
            },
            whenNotDone: Center(
              child: AppLoadingIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}
