import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/login/hut/command.dart';

void main() {
  testWidgets('hut login request is reused while in flight', (tester) async {
    final completers = <Completer<bool>>[];
    var submitCalls = 0;
    final command = HutLoginCommand(
      submitLogin: ({required username, required password}) {
        submitCalls++;
        final completer = Completer<bool>();
        completers.add(completer);
        return completer.future;
      },
    );
    late BuildContext pageContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('hut login'));
          },
        ),
      ),
    );

    final first = command.loginToHuT('user', 'pass', pageContext);
    final second = command.loginToHuT('user', 'pass', pageContext);
    await tester.pump();

    expect(identical(first, second), isTrue);
    expect(submitCalls, 1);

    completers.removeAt(0).complete(false);
    await Future.wait([first, second]);
    await tester.pump();

    final third = command.loginToHuT('user', 'pass', pageContext);
    expect(submitCalls, 2);

    completers.removeAt(0).complete(false);
    await third;
  });

  testWidgets('hut login drops late result after context unmounts', (
    tester,
  ) async {
    final loginCompleter = Completer<bool>();
    final command = HutLoginCommand(
      submitLogin: ({required username, required password}) {
        return loginCompleter.future;
      },
    );
    late BuildContext pageContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('hut login'));
          },
        ),
      ),
    );

    final login = command.loginToHuT('user', 'pass', pageContext);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    loginCompleter.complete(true);
    await login;
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('登录成功'), findsNothing);
  });
}
