import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/hutpages/hut_service_auth.dart';
import 'package:superhut/pages/hutpages/type1/type1webview.dart';
import 'package:superhut/pages/hutpages/type2/type2webview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HutServicePortalSession> failingSessionLoader(_) async {
    throw StateError('登录已失效');
  }

  test('HUT service auth error messages hide raw setup errors', () {
    expect(
      resolveHutServiceAuthErrorMessage(
        const HutServiceAuthException(hutServiceAuthExpiredMessage),
      ),
      hutServiceAuthExpiredMessage,
    );

    final message = resolveHutServiceAuthErrorMessage(
      StateError('portal ticket unavailable'),
    );
    expect(message, hutServiceOpenFailureMessage);
    expect(message, isNot(contains('portal ticket unavailable')));
  });

  testWidgets('Type1 retry ignores duplicate login taps while opening login', (
    tester,
  ) async {
    var loginCalls = 0;
    final loginCompleter = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Type1Webview(
          serviceId: '',
          serviceUrl: 'https://example.com/service',
          serviceName: '测试服务',
          loadPortalSession: failingSessionLoader,
          openLoginPage: (_) {
            loginCalls++;
            return loginCompleter.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final retryButton = find.text('重新登录智慧工大');
    expect(retryButton, findsOneWidget);
    expect(find.text(hutServiceOpenFailureMessage), findsOneWidget);
    expect(find.textContaining('登录已失效'), findsNothing);

    await tester.tap(retryButton);
    await tester.tap(retryButton);
    await tester.pump();

    expect(loginCalls, 1);

    loginCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Type1 ignores stale setup result after a newer reload', (
    tester,
  ) async {
    final sessionCompleters = <Completer<HutServicePortalSession>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Type1Webview(
          serviceId: '',
          serviceUrl: 'https://example.com/service',
          serviceName: '测试服务',
          loadPortalSession: (_) {
            final completer = Completer<HutServicePortalSession>();
            sessionCompleters.add(completer);
            return completer.future;
          },
        ),
      ),
    );
    await tester.pump();

    expect(sessionCompleters, hasLength(1));

    final dynamic pageState = tester.state(find.byType(Type1Webview));
    final latestReload = pageState.debugReloadPortalSession() as Future<bool>;
    await tester.pump();

    expect(sessionCompleters, hasLength(2));

    sessionCompleters[1].complete(
      const HutServicePortalSession(token: 'latest-token', ticket: ''),
    );
    expect(await latestReload, isTrue);

    expect(pageState.debugToken, 'latest-token');
    expect(pageState.debugResultUrl, contains('latest-token'));
    expect(pageState.debugHeaderMap['X-Id-Token'], 'latest-token');
    expect(pageState.debugHeaderMap['Cookie'], 'userToken=latest-token');

    sessionCompleters[0].complete(
      const HutServicePortalSession(token: 'stale-token', ticket: ''),
    );
    await tester.pump();

    expect(pageState.debugToken, 'latest-token');
    expect(pageState.debugResultUrl, contains('latest-token'));
    expect(pageState.debugResultUrl, isNot(contains('stale-token')));
    expect(pageState.debugHeaderMap['X-Id-Token'], 'latest-token');
    expect(pageState.debugHeaderMap['X-Id-Token'], isNot('stale-token'));
    expect(pageState.debugHeaderMap['Cookie'], 'userToken=latest-token');
    expect(pageState.debugHeaderMap['Cookie'], isNot(contains('stale-token')));
  });

  testWidgets('Type2 retry ignores duplicate login taps while opening login', (
    tester,
  ) async {
    var loginCalls = 0;
    final loginCompleter = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Type2Webview(
          serviceId: '',
          serviceUrl: 'https://example.com/service',
          serviceName: '测试服务',
          serviceType: '2',
          tokenAccept: '[]',
          loadPortalSession: failingSessionLoader,
          openLoginPage: (_) {
            loginCalls++;
            return loginCompleter.future;
          },
          handleLocationPermission: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final retryButton = find.text('重新登录智慧工大');
    expect(retryButton, findsOneWidget);
    expect(find.text(hutServiceOpenFailureMessage), findsOneWidget);
    expect(find.textContaining('登录已失效'), findsNothing);

    await tester.tap(retryButton);
    await tester.tap(retryButton);
    await tester.pump();

    expect(loginCalls, 1);

    loginCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('Type2 ignores stale setup result after a newer reload', (
    tester,
  ) async {
    final sessionCompleters = <Completer<HutServicePortalSession>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Type2Webview(
          serviceId: '',
          serviceUrl: '',
          serviceName: '测试服务',
          serviceType: '2',
          tokenAccept: '[{"tokenType":"header","tokenKey":"X-Test-Token"}]',
          loadPortalSession: (_) {
            final completer = Completer<HutServicePortalSession>();
            sessionCompleters.add(completer);
            return completer.future;
          },
          handleLocationPermission: () async {},
        ),
      ),
    );
    await tester.pump();

    expect(sessionCompleters, hasLength(1));

    final dynamic pageState = tester.state(find.byType(Type2Webview));
    final latestReload = pageState.debugReloadPortalSession() as Future<bool>;
    await tester.pump();

    expect(sessionCompleters, hasLength(2));

    sessionCompleters[1].complete(
      const HutServicePortalSession(token: 'latest-token', ticket: ''),
    );
    expect(await latestReload, isTrue);

    expect(pageState.debugToken, 'latest-token');
    expect(pageState.debugHeaderMap['X-Test-Token'], 'latest-token');

    sessionCompleters[0].complete(
      const HutServicePortalSession(token: 'stale-token', ticket: ''),
    );
    await tester.pump();

    expect(pageState.debugToken, 'latest-token');
    expect(pageState.debugHeaderMap['X-Test-Token'], 'latest-token');
    expect(pageState.debugHeaderMap['X-Test-Token'], isNot('stale-token'));
  });

  testWidgets('Type2 alipay opener false result hides url from user', (
    tester,
  ) async {
    final sessionCompleter = Completer<HutServicePortalSession>();
    final openedUrls = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Type2Webview(
          serviceId: '',
          serviceUrl: 'https://example.com/service',
          serviceName: '测试服务',
          serviceType: '2',
          tokenAccept: '[]',
          loadPortalSession: (_) => sessionCompleter.future,
          handleLocationPermission: () async {},
          openExternalUrl: (url) async {
            openedUrls.add(url);
            return false;
          },
        ),
      ),
    );
    await tester.pump();

    const alipayUrl =
        'alipays://platformapi/startApp?appId=20000123&token=secret-token';
    final dynamic pageState = tester.state(find.byType(Type2Webview));

    await (pageState.debugHandleAlipayUrl(alipayUrl) as Future<void>);
    await tester.pump();

    expect(openedUrls, [Uri.parse(alipayUrl)]);
    expect(find.text('无法打开支付宝，请稍后重试'), findsOneWidget);
    expect(find.textContaining(alipayUrl), findsNothing);
  });

  testWidgets('Type2 alipay opener exception recovers and can retry', (
    tester,
  ) async {
    final sessionCompleter = Completer<HutServicePortalSession>();
    final openedUrls = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Type2Webview(
          serviceId: '',
          serviceUrl: 'https://example.com/service',
          serviceName: '测试服务',
          serviceType: '2',
          tokenAccept: '[]',
          loadPortalSession: (_) => sessionCompleter.future,
          handleLocationPermission: () async {},
          openExternalUrl: (url) async {
            openedUrls.add(url);
            throw Exception('browser unavailable');
          },
        ),
      ),
    );
    await tester.pump();

    const alipayUrl =
        'alipays://platformapi/startApp?appId=20000123&token=secret-token';
    final dynamic pageState = tester.state(find.byType(Type2Webview));

    await (pageState.debugHandleAlipayUrl(alipayUrl) as Future<void>);
    await tester.pump();

    expect(openedUrls, [Uri.parse(alipayUrl)]);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开支付宝，请稍后重试'), findsOneWidget);
    expect(find.textContaining(alipayUrl), findsNothing);
    expect(find.textContaining('browser unavailable'), findsNothing);

    await (pageState.debugHandleAlipayUrl(alipayUrl) as Future<void>);
    await tester.pump();

    expect(openedUrls, [Uri.parse(alipayUrl), Uri.parse(alipayUrl)]);
  });
}
