import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/bridge/get_course_page.dart';
import 'package:superhut/utils/course/coursemain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ignores duplicate retry taps while course sync is in flight', (
    tester,
  ) async {
    final retryCompleter = Completer<CourseSyncResult>();
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Getcoursepage(
          renew: true,
          loadToken: () async => 'jwxt-token',
          saveClass: (token, {context}) {
            saveCalls += 1;
            if (saveCalls == 1) {
              return Future.value(const CourseSyncResult.failure('首次同步失败'));
            }
            return retryCompleter.future;
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(saveCalls, 1);
    expect(find.text('课表加载失败'), findsOneWidget);

    final retryButton = find.widgetWithText(FilledButton, '重试');
    await tester.tap(retryButton);
    await tester.tap(retryButton);
    await tester.pump();

    expect(saveCalls, 2);

    retryCompleter.complete(const CourseSyncResult.failure('重试仍然失败'));
    await tester.pump();
    await tester.pump();

    expect(find.text('重试仍然失败'), findsOneWidget);
  });
}
