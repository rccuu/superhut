import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/hut_cas_login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HutCasTokenRetriever.resetForTest();
  });

  tearDown(HutCasTokenRetriever.resetForTest);

  testWidgets('CAS login token load failure hides raw error and can retry', (
    tester,
  ) async {
    var loadCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HutCasLoginPage(
          loadIdToken: () async {
            loadCalls++;
            throw StateError('secure storage unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(loadCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('获取统一认证令牌失败，请稍后重试'), findsOneWidget);
    expect(find.textContaining('secure storage unavailable'), findsNothing);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump();

    expect(loadCalls, 2);
    expect(find.text('获取统一认证令牌失败，请稍后重试'), findsOneWidget);
  });

  testWidgets('concurrent token retrieval opens a single CAS login page', (
    tester,
  ) async {
    var loginPageBuilds = 0;

    HutCasTokenRetriever.setLoginPageBuilderForTest((onLoginComplete) {
      loginPageBuilds++;
      return _FakeCasLoginPage(onLoginComplete: onLoginComplete);
    });

    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );

    final first = HutCasTokenRetriever.getJwxtTokenAndCookie(pageContext);
    final second = HutCasTokenRetriever.getJwxtTokenAndCookie(pageContext);
    await tester.pump();
    await tester.pump();

    expect(loginPageBuilds, 1);
    expect(find.text('fake cas login'), findsOneWidget);

    await tester.tap(find.text('finish login'));
    await tester.pumpAndSettle();

    final results = await Future.wait([first, second]);

    expect(results, [
      {'token': 'jwxt-token', 'my_client_ticket': 'jwxt-cookie'},
      {'token': 'jwxt-token', 'my_client_ticket': 'jwxt-cookie'},
    ]);
    expect(loginPageBuilds, 1);
    expect(find.text('fake cas login'), findsNothing);
  });

  testWidgets('route result completes token retrieval without callback', (
    tester,
  ) async {
    var loginPageBuilds = 0;

    HutCasTokenRetriever.setLoginPageBuilderForTest((onLoginComplete) {
      loginPageBuilds++;
      return const _RouteResultOnlyCasLoginPage();
    });

    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );

    final load = HutCasTokenRetriever.getJwxtTokenAndCookie(pageContext);
    await tester.pump();
    await tester.pump();

    expect(loginPageBuilds, 1);
    expect(find.text('route result cas login'), findsOneWidget);

    await tester.tap(find.text('finish with route result'));
    await tester.pumpAndSettle();

    expect(await load, {
      'token': 'route-token',
      'my_client_ticket': 'route-cookie',
    });
    expect(find.text('route result cas login'), findsNothing);
  });
}

class _FakeCasLoginPage extends StatelessWidget {
  const _FakeCasLoginPage({required this.onLoginComplete});

  final void Function(Map<String, String>) onLoginComplete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('fake cas login'),
          TextButton(
            onPressed: () {
              final result = {
                'token': 'jwxt-token',
                'my_client_ticket': 'jwxt-cookie',
              };
              onLoginComplete(result);
              Navigator.of(context).pop(result);
            },
            child: const Text('finish login'),
          ),
        ],
      ),
    );
  }
}

class _RouteResultOnlyCasLoginPage extends StatelessWidget {
  const _RouteResultOnlyCasLoginPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('route result cas login'),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop({
                'token': 'route-token',
                'my_client_ticket': 'route-cookie',
              });
            },
            child: const Text('finish with route result'),
          ),
        ],
      ),
    );
  }
}
