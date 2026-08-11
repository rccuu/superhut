import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/unified_login_page.dart';

import '../support/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(SecureStorageMock.install);
  tearDownAll(SecureStorageMock.uninstall);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureStorageMock.reset();
  });

  testWidgets('guest continuation ignores duplicate taps while navigating', (
    tester,
  ) async {
    var homeRouteBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedLoginPage(
          buildHomeRoute: ({int initialIndex = 0}) {
            homeRouteBuilds++;
            return MaterialPageRoute<void>(
              builder: (_) => Scaffold(body: Text('guest home $initialIndex')),
            );
          },
        ),
      ),
    );
    await tester.pump();

    final guestButton = find.widgetWithText(OutlinedButton, '先逛功能');
    await tester.ensureVisible(guestButton);
    final button = tester.widget<OutlinedButton>(guestButton);
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();

    expect(homeRouteBuilds, 1);
    expect(find.text('guest home 1'), findsOneWidget);
    expect(find.text('先逛功能'), findsNothing);
  });

  testWidgets('guest continuation recovers after route build throws', (
    tester,
  ) async {
    var homeRouteBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedLoginPage(
          buildHomeRoute: ({int initialIndex = 0}) {
            homeRouteBuilds++;
            throw Exception('home route unavailable');
          },
        ),
      ),
    );
    await tester.pump();

    final guestButton = find.widgetWithText(OutlinedButton, '先逛功能');
    await tester.ensureVisible(guestButton);
    final button = tester.widget<OutlinedButton>(guestButton);
    button.onPressed!();
    await tester.pump();
    await tester.pump();

    expect(homeRouteBuilds, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法进入游客模式，请稍后重试'), findsOneWidget);

    button.onPressed!();
    await tester.pump();
    await tester.pump();

    expect(homeRouteBuilds, 2);
  });

  testWidgets(
    'CAS login button ignores duplicate taps while login is pending',
    (tester) async {
      final loginCompleter = Completer<bool>();
      var loginCalls = 0;
      var credentialCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: UnifiedLoginPage(
            buildHomeRoute: ({int initialIndex = 0}) {
              return MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: Text('home $initialIndex')),
              );
            },
            loginWithHut: ({required username, required password}) {
              loginCalls++;
              expect(username, '20260001');
              expect(password, 'secret-pass');
              return loginCompleter.future;
            },
            loadJwxtCredentials: (_) async {
              credentialCalls++;
              return {'token': 'jwxt-token', 'my_client_ticket': 'jwxt-cookie'};
            },
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, '20260001');
      await tester.enterText(find.byType(TextField).last, 'secret-pass');
      await tester.pump();

      final loginButton = find.widgetWithText(FilledButton, '登录并继续');
      final onPressed = tester.widget<FilledButton>(loginButton).onPressed;
      onPressed?.call();
      onPressed?.call();
      await tester.pump();

      expect(loginCalls, 1);
      expect(credentialCalls, 0);

      loginCompleter.complete(true);
      await tester.pumpAndSettle();

      expect(loginCalls, 1);
      expect(credentialCalls, 1);
      expect(find.text('home 0'), findsOneWidget);
    },
  );

  testWidgets('CAS login recovers after official login opener throws', (
    tester,
  ) async {
    var loginCalls = 0;
    var officialLoginCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedLoginPage(
          loginWithHut: ({required username, required password}) async {
            loginCalls++;
            return false;
          },
          openOfficialLogin: (
            context, {
            required username,
            required password,
          }) async {
            officialLoginCalls++;
            throw Exception('official login unavailable');
          },
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '20260001');
    await tester.enterText(find.byType(TextField).last, 'secret-pass');
    await tester.pump();

    final loginButton = find.widgetWithText(FilledButton, '登录并继续');
    var onPressed = tester.widget<FilledButton>(loginButton).onPressed;
    onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(loginCalls, 1);
    expect(officialLoginCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开教务系统官方登录页面，请稍后重试'), findsOneWidget);

    onPressed = tester.widget<FilledButton>(loginButton).onPressed;
    onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(loginCalls, 2);
    expect(officialLoginCalls, 2);
  });

  testWidgets('saved credentials do not override user edits', (tester) async {
    final savedCredentials = Completer<({String username, String password})>();

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedLoginPage(
          loadSavedLoginCredentials: () => savedCredentials.future,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'typed-user');
    await tester.enterText(find.byType(TextField).last, 'typed-pass');
    await tester.pump();

    savedCredentials.complete((username: 'saved-user', password: 'saved-pass'));
    await tester.pump();

    final usernameField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    final passwordField = tester.widget<TextField>(find.byType(TextField).last);
    expect(usernameField.controller?.text, 'typed-user');
    expect(passwordField.controller?.text, 'typed-pass');
  });

  testWidgets('saved credential load failure does not interrupt typing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedLoginPage(
          loadSavedLoginCredentials: () async {
            throw Exception('secure storage unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('读取已保存账号失败，请手动输入'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'typed-user');
    await tester.enterText(find.byType(TextField).last, 'typed-pass');
    await tester.pump();

    final usernameField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    final passwordField = tester.widget<TextField>(find.byType(TextField).last);
    expect(usernameField.controller?.text, 'typed-user');
    expect(passwordField.controller?.text, 'typed-pass');
  });

  testWidgets('returnToCaller pops with true instead of replacing home', (
    tester,
  ) async {
    bool? popResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                popResult = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder:
                        (_) => UnifiedLoginPage(
                          returnToCaller: true,
                          loginWithHut: ({
                            required username,
                            required password,
                          }) async {
                            return true;
                          },
                          loadJwxtCredentials: (_) async {
                            return {'token': 't', 'my_client_ticket': 'c'};
                          },
                        ),
                  ),
                );
              },
              child: const Text('open login'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open login'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '20260001');
    await tester.enterText(find.byType(TextField).last, 'secret-pass');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '登录并继续'));
    await tester.pumpAndSettle();

    expect(popResult, isTrue);
    expect(find.text('open login'), findsOneWidget);
  });

  testWidgets('returnToCaller hides guest continuation buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: UnifiedLoginPage(returnToCaller: true)),
    );
    await tester.pump();

    expect(find.text('先逛功能'), findsNothing);
    expect(find.text('暂不登录'), findsNothing);
  });
}
