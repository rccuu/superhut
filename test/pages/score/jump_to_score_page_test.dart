import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/score/jump_to_score_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ignores duplicate retry taps while login renewal is in flight', (
    tester,
  ) async {
    final retryCompleter = Completer<bool>();
    var renewCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: JumpToScorePage(
          renewLogin: (_) {
            renewCalls += 1;
            if (renewCalls == 1) {
              return Future.value(false);
            }
            return retryCompleter.future;
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(renewCalls, 1);
    expect(find.text('成绩页打开失败'), findsOneWidget);

    final retryButton = find.widgetWithText(FilledButton, '重新尝试');
    await tester.tap(retryButton);
    await tester.tap(retryButton);
    await tester.pump();

    expect(renewCalls, 2);

    retryCompleter.complete(false);
    await tester.pump();
    await tester.pump();

    expect(find.text('成绩页打开失败'), findsOneWidget);
  });

  testWidgets('recovers after login renewal throws', (tester) async {
    var renewCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: JumpToScorePage(
          renewLogin: (_) async {
            renewCalls += 1;
            throw Exception('renew unavailable');
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(renewCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('成绩页打开失败'), findsOneWidget);
    expect(find.text('成绩页面暂时无法打开，请稍后重试。'), findsOneWidget);

    final retryButton = find.widgetWithText(FilledButton, '重新尝试');
    await tester.tap(retryButton);
    await tester.pump();
    await tester.pump();

    expect(renewCalls, 2);
    expect(tester.takeException(), isNull);
  });
}
