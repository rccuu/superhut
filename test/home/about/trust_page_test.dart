import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/about/trust_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('repository link ignores duplicate taps while opening', (
    tester,
  ) async {
    var openCalls = 0;
    var openCompleter = Completer<bool>();

    await tester.pumpWidget(
      MaterialApp(
        home: TrustCenterPage(
          openUrl: (url) {
            openCalls++;
            return openCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();

    final repoButton = find.text('打开仓库');
    await tester.scrollUntilVisible(
      repoButton,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    await tester.tap(repoButton);
    await tester.pump();
    await tester.tap(repoButton);
    await tester.pump();

    expect(openCalls, 1);

    openCompleter.complete(true);
    await tester.pump();

    openCompleter = Completer<bool>();
    await tester.tap(repoButton);
    await tester.pump();

    expect(openCalls, 2);
  });

  testWidgets('repository link recovers after opener throws', (tester) async {
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: TrustCenterPage(
          openUrl: (url) async {
            openCalls++;
            throw Exception('browser unavailable');
          },
        ),
      ),
    );
    await tester.pump();

    final repoButton = find.text('打开仓库');
    await tester.scrollUntilVisible(
      repoButton,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    await tester.tap(repoButton);
    await tester.pump();

    expect(openCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开链接，请稍后重试'), findsOneWidget);
    expect(
      find.textContaining('https://github.com/rccuu/superhut'),
      findsNothing,
    );
    expect(find.textContaining('browser unavailable'), findsNothing);

    await tester.tap(repoButton);
    await tester.pump();

    expect(openCalls, 2);
  });
}
