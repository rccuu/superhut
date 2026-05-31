import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:superhut/pages/drink/login/command.dart';
import 'package:superhut/pages/drink/login/loginpart2.dart';
import 'package:superhut/pages/drink/login/view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captcha refresh recovers after empty captcha result', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);

    await tester.pumpWidget(
      MaterialApp(home: DrinkLoginPage(command: command)),
    );
    await tester.pump();

    expect(api.captchaCalls, 1);
    expect(find.text('正在加载验证码'), findsOneWidget);

    final refreshButton = find.text('看不清？点击刷新');
    await tester.tap(refreshButton);
    await tester.tap(refreshButton);
    await tester.pump();

    expect(api.captchaCalls, 1);

    api.completeNextCaptcha();
    await tester.pumpAndSettle();

    expect(find.text('验证码加载失败，点击重试'), findsOneWidget);
    expect(find.text('正在加载验证码'), findsNothing);

    await tester.tap(refreshButton);
    await tester.pump();
    await tester.tap(refreshButton);
    await tester.pump();

    expect(api.captchaCalls, 2);
    expect(find.text('正在加载验证码'), findsOneWidget);

    api.completeNextCaptcha();
    await tester.pumpAndSettle();

    expect(find.text('验证码加载失败，点击重试'), findsOneWidget);
    expect(find.text('正在加载验证码'), findsNothing);
  });

  testWidgets('captcha load errors show retry placeholder without raw error', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);

    await tester.pumpWidget(
      MaterialApp(home: DrinkLoginPage(command: command)),
    );
    await tester.pump();

    api.failNextCaptcha(Exception('captcha unavailable token=secret-token'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('验证码加载失败，点击重试'), findsOneWidget);
    expect(find.textContaining('secret-token'), findsNothing);

    await tester.tap(find.text('看不清？点击刷新'));
    await tester.pump();

    expect(api.captchaCalls, 2);
    expect(find.text('正在加载验证码'), findsOneWidget);
  });

  testWidgets('message code sends only once while request is in flight', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);

    await tester.pumpWidget(
      MaterialApp(home: DrinkLoginPage(command: command)),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), '13800138000');
    await tester.enterText(find.byType(TextField).at(1), '1234');

    final sendButton = find.text('发送验证码');
    await tester.tap(sendButton);
    await tester.tap(sendButton);
    await tester.pump();

    expect(api.messageCodeCalls, 1);

    api.completeNextMessageCode(false);
    await tester.pump();

    await tester.tap(sendButton);
    await tester.pump();

    expect(api.messageCodeCalls, 2);

    api.completeNextMessageCode(false);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'sms step reuses first step command after message code succeeds',
    (tester) async {
      final api = _FakeDrinkLoginApi();
      final command = DrinkLoginCommand(api: api);

      await tester.pumpWidget(
        MaterialApp(home: DrinkLoginPage(command: command)),
      );
      await tester.pump();
      api.completeNextCaptcha();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '13800138000');
      await tester.enterText(find.byType(TextField).at(1), '1234');

      await tester.tap(find.text('发送验证码'));
      await tester.pump();

      expect(api.messageCodeCalls, 1);

      api.completeNextMessageCode(true);
      await tester.pumpAndSettle();

      expect(find.text('短信验证'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '5678');
      await tester.tap(find.text('完成登录'));
      await tester.pump();

      expect(api.loginCalls, 1);

      api.completeNextLogin(false);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('sms login submits only once while request is in flight', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);

    await tester.pumpWidget(
      MaterialApp(
        home: DrinkLoginPage2(
          phoneNumber: '13800138000',
          doubleRandom: '0.1',
          timestamp: '123',
          imageCode: '1234',
          command: command,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '5678');

    final submitButton = find.text('完成登录');
    await tester.tap(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(api.loginCalls, 1);

    api.completeNextLogin(false);
    await tester.pump();

    await tester.tap(submitButton);
    await tester.pump();

    expect(api.loginCalls, 2);

    api.completeNextLogin(false);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'returning for sms code ignores duplicate taps while route pops',
    (tester) async {
      final api = _FakeDrinkLoginApi();
      final command = DrinkLoginCommand(api: api);

      await tester.pumpWidget(
        MaterialApp(home: _DrinkLoginRouteStackHarness(command: command)),
      );

      await tester.tap(find.text('open first step'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open sms step'));
      await tester.pumpAndSettle();

      final returnButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '重新获取验证码'),
      );
      returnButton.onPressed!();
      returnButton.onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('drink login first step'), findsOneWidget);
      expect(find.text('drink login root'), findsNothing);
      expect(find.text('短信验证'), findsNothing);
    },
  );
}

class _DrinkLoginRouteStackHarness extends StatelessWidget {
  const _DrinkLoginRouteStackHarness({required this.command});

  final DrinkLoginCommand command;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('drink login root'),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (context) => _DrinkLoginFirstStep(command: command),
                  ),
                );
              },
              child: const Text('open first step'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrinkLoginFirstStep extends StatelessWidget {
  const _DrinkLoginFirstStep({required this.command});

  final DrinkLoginCommand command;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('drink login first step'),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (context) => DrinkLoginPage2(
                          phoneNumber: '13800138000',
                          doubleRandom: '0.1',
                          timestamp: '123',
                          imageCode: '1234',
                          command: command,
                        ),
                  ),
                );
              },
              child: const Text('open sms step'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakeDrinkLoginApi implements DrinkLoginApiClient {
  final List<Completer<Uint8List>> _captchaCompleters =
      <Completer<Uint8List>>[];
  final List<Completer<bool>> _messageCodeCompleters = <Completer<bool>>[];
  final List<Completer<bool>> _loginCompleters = <Completer<bool>>[];
  int captchaCalls = 0;
  int messageCodeCalls = 0;
  int loginCalls = 0;

  @override
  Future<Uint8List> userCaptcha({
    required String doubleRandom,
    required String timestamp,
  }) {
    captchaCalls++;
    final completer = Completer<Uint8List>();
    _captchaCompleters.add(completer);
    return completer.future;
  }

  void completeNextCaptcha() {
    final completer = _captchaCompleters.removeAt(0);
    completer.complete(Uint8List(0));
  }

  void failNextCaptcha(Object error) {
    final completer = _captchaCompleters.removeAt(0);
    completer.completeError(error);
  }

  @override
  Future<bool> userMessageCode({
    required String doubleRandom,
    required String photoCode,
    required String phone,
  }) {
    messageCodeCalls++;
    final completer = Completer<bool>();
    _messageCodeCompleters.add(completer);
    return completer.future;
  }

  void completeNextMessageCode(bool value) {
    final completer = _messageCodeCompleters.removeAt(0);
    completer.complete(value);
  }

  @override
  Future<bool> userLogin({required String phone, required String messageCode}) {
    loginCalls++;
    final completer = Completer<bool>();
    _loginCompleters.add(completer);
    return completer.future;
  }

  void completeNextLogin(bool value) {
    final completer = _loginCompleters.removeAt(0);
    completer.complete(value);
  }
}
