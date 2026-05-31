import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/userpage/view.dart';
import 'package:superhut/pages/score/logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('starts preference and account checks in parallel', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final prefsCompleter = Completer<SharedPreferences>();
    final accountCompleter = Completer<bool>();
    var startedPrefsLoad = false;
    var startedAccountCheck = false;
    var accountCheckStartedBeforePrefsCompleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: UserPage(
          loadPrefs: () {
            startedPrefsLoad = true;
            return prefsCompleter.future;
          },
          hasLinkedCampusAccount: () {
            startedAccountCheck = true;
            accountCheckStartedBeforePrefsCompleted =
                !prefsCompleter.isCompleted;
            return accountCompleter.future;
          },
        ),
      ),
    );

    expect(startedPrefsLoad, isTrue);
    expect(startedAccountCheck, isTrue);
    expect(accountCheckStartedBeforePrefsCompleted, isTrue);
    expect(find.text('正在读取个人信息'), findsOneWidget);

    prefsCompleter.complete(prefs);
    accountCompleter.complete(false);
    await tester.pump();
    await tester.pump();

    expect(find.text('当前未登录'), findsOneWidget);
  });

  testWidgets('page data load failure recovers and allows retry', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var prefsCalls = 0;
    var accountCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UserPage(
          loadPrefs: () async {
            prefsCalls++;
            if (prefsCalls == 1) {
              throw Exception('prefs unavailable');
            }
            return prefs;
          },
          hasLinkedCampusAccount: () async {
            accountCalls++;
            return accountCalls > 1;
          },
          loadBalance: () async => '12.34',
          loadScoreSummary:
              () async => const ScoreLoadResult(
                achievement: [],
                yxzxf: '40',
                zxfjd: '120',
                pjxfjd: '3.5',
              ),
        ),
      ),
    );

    await _pumpUntil(
      tester,
      () => find.text('个人信息加载失败，请稍后重试').evaluate().isNotEmpty,
    );

    expect(prefsCalls, 1);
    expect(accountCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('当前未登录'), findsOneWidget);
    expect(find.textContaining('prefs unavailable'), findsNothing);

    final dynamic pageState = tester.state(find.byType(UserPage));
    final retryLoad = pageState.debugReloadPageData() as Future<void>;
    await retryLoad;
    await tester.pump();

    expect(prefsCalls, 2);
    expect(accountCalls, 2);
    expect(find.text('刷新课表'), findsOneWidget);
    expect(find.text('当前未登录'), findsNothing);
  });

  testWidgets('stale page data load does not override latest account state', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yxzxf', '40');
    await prefs.setString('zxfjd', '120');
    await prefs.setString('pjxfjd', '3.5');

    final prefsCompleters = [
      Completer<SharedPreferences>(),
      Completer<SharedPreferences>(),
    ];
    final accountCompleters = [Completer<bool>(), Completer<bool>()];
    var prefsCalls = 0;
    var accountCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UserPage(
          loadPrefs: () {
            return prefsCompleters[prefsCalls++].future;
          },
          hasLinkedCampusAccount: () {
            return accountCompleters[accountCalls++].future;
          },
          loadBalance: () async => '12.34',
          loadScoreSummary:
              () async => const ScoreLoadResult(
                achievement: [],
                yxzxf: '40',
                zxfjd: '120',
                pjxfjd: '3.5',
              ),
        ),
      ),
    );

    expect(find.text('正在读取个人信息'), findsOneWidget);

    final dynamic pageState = tester.state(find.byType(UserPage));
    final latestLoad = pageState.debugReloadPageData() as Future<void>;
    expect(prefsCalls, 2);
    expect(accountCalls, 2);

    prefsCompleters[1].complete(prefs);
    accountCompleters[1].complete(true);
    await latestLoad;
    await tester.pump();

    expect(find.text('刷新课表'), findsOneWidget);
    expect(find.text('当前未登录'), findsNothing);

    prefsCompleters[0].complete(prefs);
    accountCompleters[0].complete(false);
    await tester.pump();
    await tester.pump();

    expect(find.text('刷新课表'), findsOneWidget);
    expect(find.text('当前未登录'), findsNothing);
  });

  testWidgets('stale balance refresh does not overwrite cached balance', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final balanceCompleters = [Completer<String>(), Completer<String>()];
    var balanceCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UserPage(
          loadPrefs: () async => prefs,
          hasLinkedCampusAccount: () async => true,
          loadBalance: () {
            return balanceCompleters[balanceCalls++].future;
          },
          loadScoreSummary:
              () async => const ScoreLoadResult(
                achievement: [],
                yxzxf: '40',
                zxfjd: '120',
                pjxfjd: '3.5',
              ),
        ),
      ),
    );

    await _pumpUntil(tester, () => balanceCalls == 1);

    final dynamic pageState = tester.state(find.byType(UserPage));
    final latestLoad = pageState.debugReloadPageData() as Future<void>;
    await _pumpUntil(tester, () => balanceCalls == 2);

    balanceCompleters[1].complete('22.00');
    await latestLoad;
    await tester.pump();

    expect(prefs.getString('user_page_cached_balance'), '22.00');

    balanceCompleters[0].complete('11.00');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(prefs.getString('user_page_cached_balance'), '22.00');
    expect(prefs.getString('user_page_cached_balance'), isNot('11.00'));
  });

  testWidgets(
    'ignores duplicate course refresh taps while refresh is pending',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final renewCompleter = Completer<bool>();
      final syncCompleter = Completer<bool>();
      var renewCalls = 0;
      var tokenCalls = 0;
      var syncCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: UserPage(
            loadPrefs: () async => prefs,
            hasLinkedCampusAccount: () async => true,
            loadBalance: () async => '12.34',
            loadScoreSummary:
                () async => const ScoreLoadResult(
                  achievement: [],
                  yxzxf: '40',
                  zxfjd: '120',
                  pjxfjd: '3.5',
                ),
            renewJwxtToken: (_) {
              renewCalls++;
              return renewCompleter.future;
            },
            loadJwxtToken: () async {
              tokenCalls++;
              return 'jwxt-token';
            },
            startCourseSync: (token) {
              syncCalls++;
              return syncCompleter.future;
            },
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('刷新课表').evaluate().isNotEmpty);

      final refreshTile = find.text('刷新课表');
      await tester.ensureVisible(refreshTile);
      await tester.tap(refreshTile);
      await tester.tap(refreshTile);
      await tester.pump();

      expect(renewCalls, 1);
      expect(tokenCalls, 0);
      expect(syncCalls, 0);

      renewCompleter.complete(true);
      await tester.pump();
      await tester.pump();

      expect(tokenCalls, 1);
      expect(syncCalls, 1);

      await tester.tap(refreshTile);
      await tester.pump();

      expect(renewCalls, 1);
      expect(tokenCalls, 1);
      expect(syncCalls, 1);

      syncCompleter.complete(true);
      await tester.pump();
    },
  );

  testWidgets('course refresh recovers after token renew throws', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var renewCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UserPage(
          loadPrefs: () async => prefs,
          hasLinkedCampusAccount: () async => true,
          loadBalance: () async => '12.34',
          loadScoreSummary:
              () async => const ScoreLoadResult(
                achievement: [],
                yxzxf: '40',
                zxfjd: '120',
                pjxfjd: '3.5',
              ),
          renewJwxtToken: (_) async {
            renewCalls++;
            throw Exception('token renew unavailable');
          },
          loadJwxtToken: () async => 'jwxt-token',
          startCourseSync: (_) async => true,
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('刷新课表').evaluate().isNotEmpty);

    final refreshTile = find.text('刷新课表');
    await tester.ensureVisible(refreshTile);
    await tester.tap(refreshTile);
    await tester.pump();
    await tester.pump();

    expect(renewCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('课表刷新失败，请稍后重试'), findsOneWidget);

    await tester.tap(refreshTile);
    await tester.pump();
    await tester.pump();

    expect(renewCalls, 2);
  });

  testWidgets('guest login button ignores duplicate taps while login is open', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final openCompleter = Completer<void>();
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UserPage(
          loadPrefs: () async => prefs,
          hasLinkedCampusAccount: () async => false,
          openLoginPage: (_) {
            openCalls++;
            return openCompleter.future;
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('登录校园账号').evaluate().isNotEmpty);

    final loginButton = find.text('登录校园账号');
    await tester.tap(loginButton);
    await tester.pump();
    await tester.tap(loginButton);
    await tester.pump();

    expect(openCalls, 1);

    openCompleter.complete();
    await tester.pump();
    await tester.pump();
  });

  testWidgets('guest login button recovers after opener throws', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UserPage(
          loadPrefs: () async => prefs,
          hasLinkedCampusAccount: () async => false,
          openLoginPage: (_) async {
            openCalls++;
            throw Exception('login page unavailable');
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('登录校园账号').evaluate().isNotEmpty);

    final loginButton = find.text('登录校园账号');
    await tester.tap(loginButton);
    await tester.pump();
    await tester.pump();

    expect(openCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开登录页面，请稍后重试'), findsOneWidget);

    await tester.tap(loginButton);
    await tester.pump();
    await tester.pump();

    expect(openCalls, 2);
  });

  testWidgets('about page tile recovers after opener throws', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UserPage(
          loadPrefs: () async => prefs,
          hasLinkedCampusAccount: () async => false,
          openAboutPage: (_) async {
            openCalls++;
            throw Exception('about page unavailable');
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('关于工大盒子').evaluate().isNotEmpty);

    final aboutTile = find.text('关于工大盒子');
    await tester.ensureVisible(aboutTile);
    await tester.tap(aboutTile);
    await tester.pump();
    await tester.pump();

    expect(openCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开关于页面，请稍后重试'), findsOneWidget);

    await tester.tap(aboutTile);
    await tester.pump();
    await tester.pump();

    expect(openCalls, 2);
  });

  testWidgets('ignores duplicate score taps while opening score page', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final renewCompleter = Completer<bool>();
    final openCompleter = Completer<void>();
    var renewCalls = 0;
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UserPage(
          loadPrefs: () async => prefs,
          hasLinkedCampusAccount: () async => true,
          loadBalance: () async => '12.34',
          loadScoreSummary:
              () async => const ScoreLoadResult(
                achievement: [],
                yxzxf: '40',
                zxfjd: '120',
                pjxfjd: '3.5',
              ),
          renewJwxtToken: (_) {
            renewCalls++;
            return renewCompleter.future;
          },
          openScorePage: (_) {
            openCalls++;
            return openCompleter.future;
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('已修学分').evaluate().isNotEmpty);

    await tester.tap(find.text('已修学分'));
    await tester.pump();
    await tester.tap(find.text('平均绩点'));
    await tester.pump();

    expect(renewCalls, 1);
    expect(openCalls, 0);

    renewCompleter.complete(true);
    await tester.pump();

    expect(renewCalls, 1);
    expect(openCalls, 1);

    await tester.tap(find.text('已修学分'));
    await tester.pump();

    expect(renewCalls, 1);
    expect(openCalls, 1);

    openCompleter.complete();
    await tester.pump();
    await tester.pump();
  });

  testWidgets('score card recovers after opener throws', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    var renewCalls = 0;
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UserPage(
          loadPrefs: () async => prefs,
          hasLinkedCampusAccount: () async => true,
          loadBalance: () async => '12.34',
          loadScoreSummary:
              () async => const ScoreLoadResult(
                achievement: [],
                yxzxf: '40',
                zxfjd: '120',
                pjxfjd: '3.5',
              ),
          renewJwxtToken: (_) async {
            renewCalls++;
            return true;
          },
          openScorePage: (_) async {
            openCalls++;
            throw Exception('score page unavailable');
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('已修学分').evaluate().isNotEmpty);

    await tester.tap(find.text('已修学分'));
    await tester.pump();
    await tester.pump();

    expect(renewCalls, 1);
    expect(openCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开成绩页面，请稍后重试'), findsOneWidget);

    await tester.tap(find.text('平均绩点'));
    await tester.pump();
    await tester.pump();

    expect(renewCalls, 2);
    expect(openCalls, 2);
  });

  testWidgets('recharge button ignores duplicate taps while opening', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final openCompleter = Completer<bool>();
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UserPage(
          loadPrefs: () async => prefs,
          hasLinkedCampusAccount: () async => true,
          loadBalance: () async => '12.34',
          loadScoreSummary:
              () async => const ScoreLoadResult(
                achievement: [],
                yxzxf: '40',
                zxfjd: '120',
                pjxfjd: '3.5',
              ),
          openRechargePage: (_) {
            openCalls++;
            return openCompleter.future;
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('前往充值').evaluate().isNotEmpty);

    final rechargeButton = find.widgetWithText(FilledButton, '前往充值');
    final onPressed = tester.widget<FilledButton>(rechargeButton).onPressed;
    onPressed?.call();
    onPressed?.call();
    await tester.pump();

    expect(openCalls, 1);

    openCompleter.complete(true);
    await tester.pump();
  });

  testWidgets('recharge button recovers after opener throws', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UserPage(
          loadPrefs: () async => prefs,
          hasLinkedCampusAccount: () async => true,
          loadBalance: () async => '12.34',
          loadScoreSummary:
              () async => const ScoreLoadResult(
                achievement: [],
                yxzxf: '40',
                zxfjd: '120',
                pjxfjd: '3.5',
              ),
          openRechargePage: (_) async {
            openCalls++;
            throw Exception('recharge unavailable');
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('前往充值').evaluate().isNotEmpty);

    final rechargeButton = find.widgetWithText(FilledButton, '前往充值');
    final onPressed = tester.widget<FilledButton>(rechargeButton).onPressed;
    onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(openCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开充值入口'), findsOneWidget);

    onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(openCalls, 2);
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(milliseconds: 200),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!predicate()) {
    if (stopwatch.elapsed >= timeout) {
      fail('Timed out while waiting for condition.');
    }
    await tester.pump(const Duration(milliseconds: 10));
  }
}
