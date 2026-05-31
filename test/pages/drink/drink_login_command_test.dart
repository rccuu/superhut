import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:superhut/pages/drink/login/command.dart';

void main() {
  test('captcha state is scoped to each login command instance', () async {
    final api = _FakeDrinkLoginApi();
    final firstCommand = DrinkLoginCommand(api: api);
    final secondCommand = DrinkLoginCommand(api: api);

    final firstCaptcha = await firstCommand.getImageCaptcha();
    final repeatedFirstCaptcha = await firstCommand.getImageCaptcha();
    final secondCaptcha = await secondCommand.getImageCaptcha();

    expect(firstCaptcha, [1, 1]);
    expect(repeatedFirstCaptcha, isEmpty);
    expect(secondCaptcha, [1, 2]);
    expect(api.captchaCalls, 2);
    expect(api.captchaRequests, hasLength(2));
    expect(api.captchaRequests[0].doubleRandom, isNot('0'));
    expect(api.captchaRequests[1].doubleRandom, isNot('0'));
  });

  test('captcha request is reused while in flight', () async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);

    final first = command.getImageCaptcha();
    final second = command.getImageCaptcha();

    expect(identical(first, second), isTrue);
    expect(api.captchaCalls, 1);

    expect(await first, [1, 1]);
    expect(await second, [1, 1]);

    final third = await command.getImageCaptcha();
    expect(third, isEmpty);
    expect(api.captchaCalls, 1);
  });

  test('captcha request failure keeps command retryable', () async {
    final api = _FakeDrinkLoginApi(
      captchaResponses: [
        Future<Uint8List>.error(Exception('captcha unavailable')),
      ],
    );
    final command = DrinkLoginCommand(api: api);

    await expectLater(command.getImageCaptcha(), throwsA(isA<Exception>()));
    expect(api.captchaCalls, 1);

    final retriedCaptcha = await command.getImageCaptcha();

    expect(retriedCaptcha, [1, 2]);
    expect(api.captchaCalls, 2);
  });

  test(
    'stale captcha result does not consume refreshed command state',
    () async {
      final staleCaptchaCompleter = Completer<Uint8List>();
      final api = _FakeDrinkLoginApi(
        captchaResponses: [staleCaptchaCompleter.future],
      );
      final command = DrinkLoginCommand(api: api);

      final staleCaptcha = command.getImageCaptcha();
      expect(api.captchaCalls, 1);

      command.dispose();
      staleCaptchaCompleter.complete(Uint8List.fromList([9, 9]));
      expect(await staleCaptcha, [9, 9]);

      final freshCaptcha = await command.getImageCaptcha();

      expect(freshCaptcha, [1, 2]);
      expect(api.captchaCalls, 2);
    },
  );

  testWidgets('message code request is reused while in flight', (tester) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    late BuildContext pageContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('drink login'));
          },
        ),
      ),
    );

    final first = command.sendMessageCode(pageContext, '13800138000', '1234');
    final second = command.sendMessageCode(pageContext, '13800138000', '1234');

    expect(identical(first, second), isTrue);
    expect(api.messageCodeCalls, 1);

    api.completeNextMessageCode(false);
    await Future.wait([first, second]);
    await tester.pump();

    final third = command.sendMessageCode(pageContext, '13800138000', '1234');
    expect(api.messageCodeCalls, 2);

    api.completeNextMessageCode(false);
    await third;
  });

  testWidgets('login request is reused while in flight', (tester) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    late BuildContext pageContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('drink login'));
          },
        ),
      ),
    );

    final first = command.login('13800138000', '5678', pageContext);
    final second = command.login('13800138000', '5678', pageContext);

    expect(identical(first, second), isTrue);
    expect(api.loginCalls, 1);

    api.completeNextLogin(false);
    await Future.wait([first, second]);
    await tester.pump();

    final third = command.login('13800138000', '5678', pageContext);
    expect(api.loginCalls, 2);

    api.completeNextLogin(false);
    await third;
  });
}

class _CaptchaRequest {
  const _CaptchaRequest({required this.doubleRandom, required this.timestamp});

  final String doubleRandom;
  final String timestamp;
}

class _FakeDrinkLoginApi implements DrinkLoginApiClient {
  _FakeDrinkLoginApi({List<Future<Uint8List>>? captchaResponses})
    : _captchaResponses = List<Future<Uint8List>>.of(
        captchaResponses ?? const <Future<Uint8List>>[],
      );

  int captchaCalls = 0;
  int messageCodeCalls = 0;
  int loginCalls = 0;
  final List<_CaptchaRequest> captchaRequests = <_CaptchaRequest>[];
  final List<Future<Uint8List>> _captchaResponses;
  final List<Completer<bool>> _messageCodeCompleters = <Completer<bool>>[];
  final List<Completer<bool>> _loginCompleters = <Completer<bool>>[];

  @override
  Future<Uint8List> userCaptcha({
    required String doubleRandom,
    required String timestamp,
  }) async {
    captchaCalls++;
    captchaRequests.add(
      _CaptchaRequest(doubleRandom: doubleRandom, timestamp: timestamp),
    );
    if (_captchaResponses.isNotEmpty) {
      return _captchaResponses.removeAt(0);
    }
    return Uint8List.fromList([1, captchaCalls]);
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
