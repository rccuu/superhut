import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/login/token_display_page.dart';

void main() {
  testWidgets('token page redirects once after token is saved', (tester) async {
    var saveCalls = 0;
    var homeRouteBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: TokenDisplayPage(
          token: 'jwxt-token',
          renew: false,
          saveTokenOverride: (token) async {
            saveCalls++;
            expect(token, 'jwxt-token');
          },
          buildHomeRoute: ({int initialIndex = 0}) {
            homeRouteBuilds++;
            return MaterialPageRoute<void>(
              builder: (_) => Scaffold(body: Text('home $initialIndex')),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(saveCalls, 1);
    expect(homeRouteBuilds, 1);
    expect(find.text('home 0'), findsOneWidget);
    expect(find.text('Token信息'), findsNothing);
  });

  testWidgets(
    'token page drops redirect when unmounted before save completes',
    (tester) async {
      final saveCompleter = Completer<void>();
      var homeRouteBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: TokenDisplayPage(
            token: 'jwxt-token',
            renew: false,
            saveTokenOverride: (_) => saveCompleter.future,
            buildHomeRoute: ({int initialIndex = 0}) {
              homeRouteBuilds++;
              return MaterialPageRoute<void>(
                builder: (_) => Scaffold(body: Text('home $initialIndex')),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('replacement'))),
      );

      saveCompleter.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(homeRouteBuilds, 0);
      expect(find.text('replacement'), findsOneWidget);
      expect(find.text('home 0'), findsNothing);
    },
  );
}
