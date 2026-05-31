import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/Functionpage/view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('protected feature taps share a single pending token renewal', (
    tester,
  ) async {
    final renewCompleters = [Completer<bool>(), Completer<bool>()];
    var renewCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FunctionPage(
          renewJwxtToken: (_) {
            renewCalls++;
            return renewCompleters[renewCalls - 1].future;
          },
        ),
      ),
    );
    await tester.pump();

    final scoreFeature = find.text('成绩查询');
    await tester.ensureVisible(scoreFeature);
    await tester.tap(scoreFeature);
    await tester.tap(scoreFeature);
    await tester.pump();

    expect(renewCalls, 1);

    renewCompleters[0].complete(false);
    await tester.pump();
    await tester.pump();

    await tester.tap(scoreFeature);
    await tester.pump();

    expect(renewCalls, 2);

    renewCompleters[1].complete(false);
    await tester.pump();
  });

  testWidgets(
    'different protected feature taps share one pending token renewal',
    (tester) async {
      final renewCompleters = [Completer<bool>(), Completer<bool>()];
      var renewCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: FunctionPage(
            renewJwxtToken: (_) {
              renewCalls++;
              return renewCompleters[renewCalls - 1].future;
            },
          ),
        ),
      );
      await tester.pump();

      final scoreFeature = find.text('成绩查询');
      final examFeature = find.text('考试安排');
      await tester.ensureVisible(scoreFeature);
      await tester.tap(scoreFeature);
      await tester.tap(examFeature);
      await tester.pump();

      expect(renewCalls, 1);

      renewCompleters[0].complete(false);
      await tester.pump();
      await tester.pump();

      await tester.tap(examFeature);
      await tester.pump();

      expect(renewCalls, 2);

      renewCompleters[1].complete(false);
      await tester.pump();
    },
  );

  testWidgets('protected feature tap recovers after token renewal throws', (
    tester,
  ) async {
    var renewCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FunctionPage(
          renewJwxtToken: (_) async {
            renewCalls++;
            throw Exception('token renewal unavailable');
          },
        ),
      ),
    );
    await tester.pump();

    final scoreFeature = find.text('成绩查询');
    await tester.ensureVisible(scoreFeature);
    await tester.tap(scoreFeature);
    await tester.pump();
    await tester.pump();

    expect(renewCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开该功能，请稍后重试'), findsOneWidget);

    await tester.tap(scoreFeature);
    await tester.pump();
    await tester.pump();

    expect(renewCalls, 2);
  });

  testWidgets('direct feature taps share a single pending page push', (
    tester,
  ) async {
    final pushCompleters = [Completer<void>(), Completer<void>()];
    var pushCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FunctionPage(
          openPage: (_, _) {
            pushCalls++;
            return pushCompleters[pushCalls - 1].future;
          },
        ),
      ),
    );
    await tester.pump();

    final drinkFeature = find.text('慧生活798');
    await tester.ensureVisible(drinkFeature);
    await tester.tap(drinkFeature);
    await tester.tap(drinkFeature);
    await tester.pump();

    expect(pushCalls, 1);

    pushCompleters[0].complete();
    await tester.pump();
    await tester.pump();

    await tester.tap(drinkFeature);
    await tester.pump();

    expect(pushCalls, 2);

    pushCompleters[1].complete();
    await tester.pump();
  });

  testWidgets('different direct feature taps share one pending page push', (
    tester,
  ) async {
    final pushCompleters = [Completer<void>(), Completer<void>()];
    var pushCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FunctionPage(
          openPage: (_, _) {
            pushCalls++;
            return pushCompleters[pushCalls - 1].future;
          },
        ),
      ),
    );
    await tester.pump();

    final drinkFeature = find.text('慧生活798');
    final hotWaterFeature = find.text('洗澡');
    await tester.ensureVisible(drinkFeature);
    await tester.tap(drinkFeature);
    await tester.tap(hotWaterFeature);
    await tester.pump();

    expect(pushCalls, 1);

    pushCompleters[0].complete();
    await tester.pump();
    await tester.pump();

    await tester.tap(hotWaterFeature);
    await tester.pump();

    expect(pushCalls, 2);

    pushCompleters[1].complete();
    await tester.pump();
  });

  testWidgets('direct feature tap recovers after page opener throws', (
    tester,
  ) async {
    var pushCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FunctionPage(
          openPage: (_, _) async {
            pushCalls++;
            throw Exception('page opener unavailable');
          },
        ),
      ),
    );
    await tester.pump();

    final drinkFeature = find.text('慧生活798');
    await tester.ensureVisible(drinkFeature);
    await tester.tap(drinkFeature);
    await tester.pump();
    await tester.pump();

    expect(pushCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开该功能，请稍后重试'), findsOneWidget);

    await tester.tap(drinkFeature);
    await tester.pump();
    await tester.pump();

    expect(pushCalls, 2);
  });
}
