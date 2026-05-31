import 'package:flutter/material.dart';

import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/color_scheme_ext.dart';
import '../../login/hut/view.dart';
import '../../utils/hut_user_api.dart';

typedef HutPortalSessionLoader =
    Future<HutServicePortalSession> Function(HutUserApi api);
typedef HutLoginPageOpener = Future<void> Function(BuildContext context);

enum HutWebViewHeaderProfile { type1, type2 }

const String hutServiceAuthExpiredMessage = '智慧工大登录状态已失效，请重新登录后再试';
const String hutServiceOpenFailureMessage = '智慧工大服务暂时无法打开，请稍后重试';

class HutServiceAuthException implements Exception {
  const HutServiceAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HutServicePortalSession {
  final String token;
  final String ticket;

  const HutServicePortalSession({required this.token, required this.ticket});
}

Future<String> loadValidHutServiceToken(HutUserApi api) async {
  final token = await api.getToken();
  if (token.trim().isNotEmpty) {
    return token.trim();
  }

  final refreshed = await api.refreshToken();
  if (refreshed) {
    final newToken = await api.getToken();
    if (newToken.trim().isNotEmpty) {
      return newToken.trim();
    }
  }

  throw const HutServiceAuthException(hutServiceAuthExpiredMessage);
}

String resolveHutServiceAuthErrorMessage(Object error) {
  if (error is HutServiceAuthException) {
    return error.message;
  }
  return hutServiceOpenFailureMessage;
}

Future<HutServicePortalSession> loadValidHutPortalSession(
  HutUserApi api,
) async {
  final token = await loadValidHutServiceToken(api);
  final ticket = await api.getPortalTicket();
  return HutServicePortalSession(token: token, ticket: ticket.trim());
}

Map<String, String> buildHutWebViewHeaders({
  required String token,
  required HutWebViewHeaderProfile profile,
}) {
  final headers = <String, String>{
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
    "X-Id-Token": token,
    "x-id-token": token,
  };

  switch (profile) {
    case HutWebViewHeaderProfile.type1:
      headers.addAll({
        "Upgrade-Insecure-Requests": "1",
        "X-Requested-With": "com.supwisdom.hut",
        "Sec-Fetch-Site": "none",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-User": "?1",
        "Sec-Fetch-Dest": "document",
        "Accept-Language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
        "Cookie": "userToken=$token",
      });
    case HutWebViewHeaderProfile.type2:
      headers.addAll({
        "upgrade-insecure-requests": "1",
        "x-requested-with": "com.supwisdom.hut",
        "sec-fetch-site": "none",
        "sec-fetch-mode": "navigate",
        "sec-fetch-user": "?1",
        "sec-fetch-dest": "document",
        "accept-language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
        "priority": "u=0, i",
      });
  }

  return headers;
}

bool isLikelyHutLoginUrl(Object? url) {
  if (url == null) {
    return false;
  }

  final uri = url is Uri ? url : Uri.tryParse(url.toString());
  if (uri == null) {
    return false;
  }

  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  if (!host.endsWith('hut.edu.cn')) {
    return false;
  }
  return path.contains('login') || path.contains('/cas/');
}

class HutServiceAuthErrorPanel extends StatelessWidget {
  const HutServiceAuthErrorPanel({
    super.key,
    required this.message,
    required this.onLogin,
  });

  final String message;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardWidth =
        (MediaQuery.sizeOf(context).width - 40).clamp(0.0, 420.0).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: cardWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_reset_rounded,
                    color: colorScheme.primary,
                    size: 34,
                  ),
                  const SizedBox(height: 16),
                  Text('需要重新登录', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onLogin,
                      child: const Text('重新登录智慧工大'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HutWebViewLoadingOverlay extends StatelessWidget {
  const HutWebViewLoadingOverlay({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.overlayScrim,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: colorScheme.floatingSurfaceStrong,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colorScheme.subtleBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppLoadingIndicator(color: colorScheme.primary, size: 40),
              const SizedBox(height: 16),
              Text(
                message,
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
    );
  }
}

Future<void> openHutLoginPage(BuildContext context) async {
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (context) => const HutLoginPage()));
}
