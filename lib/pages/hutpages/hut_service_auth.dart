import 'package:flutter/material.dart';

import '../../login/hut/view.dart';
import '../../utils/hut_user_api.dart';

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

  throw StateError('智慧工大登录状态已失效，请重新登录一次。');
}

Future<HutServicePortalSession> loadValidHutPortalSession(
  HutUserApi api,
) async {
  final token = await loadValidHutServiceToken(api);
  final ticket = await api.getPortalTicket();
  return HutServicePortalSession(token: token, ticket: ticket.trim());
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
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

Future<void> openHutLoginPage(BuildContext context) async {
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (context) => const HutLoginPage()));
}
