import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:superhut/pages/drink/api/drink_result.dart';
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

  test('dispose releases the step and submitted-phone notifiers', () {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);

    command.dispose();

    // 通知器随页面一起销毁：再写值会命中 ChangeNotifier 的已释放断言。
    expect(() => command.step.value = DrinkLoginStep.sms, throwsAssertionError);
    expect(
      () => command.submittedPhone.value = '13800138000',
      throwsAssertionError,
    );
  });

  testWidgets('message code request is reused while in flight', (tester) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    final pageContext = await _pumpLoginHarness(tester);

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
    await _drainSnackBars(tester);
  });

  testWidgets('login request is reused while in flight', (tester) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    final pageContext = await _pumpLoginHarness(tester);

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
    await _drainSnackBars(tester);
  });

  testWidgets('a rejected login surfaces the server message', (tester) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    final pageContext = await _pumpLoginHarness(tester);

    final submit = command.login('13800138000', '5678', pageContext);
    api.completeNextLoginWith(
      const DrinkResult(success: false, code: 1002, message: '短信验证码已失效，请重新获取'),
    );
    await submit;
    await tester.pump();

    // 服务端明确拒绝：标题是「登录失败」，正文原样透出服务端的 msg。
    expect(find.text('登录失败：短信验证码已失效，请重新获取'), findsOneWidget);
    expect(_snackBar(tester).duration, const Duration(seconds: 3));
    await _drainSnackBars(tester);
  });

  testWidgets('a send rejection surfaces the server message', (tester) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    final pageContext = await _pumpLoginHarness(tester);

    final send = command.sendMessageCode(pageContext, '13800138000', '1234');
    api.completeNextMessageCodeWith(
      const DrinkResult(success: false, code: 2003, message: '图形验证码错误'),
    );
    await send;
    await tester.pump();

    expect(find.text('发送失败：图形验证码错误'), findsOneWidget);
    expect(_snackBar(tester).duration, const Duration(seconds: 3));
    await _drainSnackBars(tester);
  });

  testWidgets('a request that never completed is reported as 登录异常', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    final pageContext = await _pumpLoginHarness(tester);

    final submit = command.login('13800138000', '5678', pageContext);
    // code 为 null：请求根本没跑通，不能说成用户输错了。
    api.completeNextLoginWith(
      const DrinkResult(success: false, message: '网络错误：连接超时'),
    );
    await submit;
    await tester.pump();

    expect(find.text('登录异常：网络错误：连接超时'), findsOneWidget);
    // 这类文案更长，需要 8 秒才读得完。
    expect(_snackBar(tester).duration, const Duration(seconds: 8));
    await _drainSnackBars(tester);
  });

  testWidgets('an uncompleted send is reported as 发送异常', (tester) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    final pageContext = await _pumpLoginHarness(tester);

    final send = command.sendMessageCode(pageContext, '13800138000', '1234');
    api.completeNextMessageCodeWith(
      const DrinkResult(success: false, message: '网络错误：连接超时'),
    );
    await send;
    await tester.pump();

    expect(find.text('发送异常：网络错误：连接超时'), findsOneWidget);
    expect(_snackBar(tester).duration, const Duration(seconds: 8));
    await _drainSnackBars(tester);
  });

  testWidgets('an accepted but malformed response is not blamed on captcha', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    final pageContext = await _pumpLoginHarness(tester);

    final submit = command.login('13800138000', '5678', pageContext);
    // code == 0 却没有 data.al：响应形状问题，不能反过来怪验证码。
    api.completeNextLoginWith(
      const DrinkResult(success: false, message: '登录已被接受，但响应缺少账号信息，请反馈此问题'),
    );
    await submit;
    await tester.pump();

    expect(find.text('登录异常：登录已被接受，但响应缺少账号信息，请反馈此问题'), findsOneWidget);
    expect(find.textContaining('验证码错误'), findsNothing);
    expect(find.textContaining('图形验证码'), findsNothing);
    await _drainSnackBars(tester);
  });

  testWidgets('a successful send flips the panel in place', (tester) async {
    final recorder = _RouteRecorder();
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    final pageContext = await _pumpLoginHarness(tester, recorder: recorder);
    final pushesBefore = recorder.pushed.length;

    expect(command.step.value, DrinkLoginStep.phone);

    final send = command.sendMessageCode(pageContext, '13800138000', '1234');
    api.completeNextMessageCode(true);
    await send;

    expect(command.step.value, DrinkLoginStep.sms);
    expect(command.submittedPhone.value, '13800138000');
    expect(api.messageCodeRequests, hasLength(1));
    expect(api.messageCodeRequests.single.phone, '13800138000');
    expect(api.messageCodeRequests.single.photoCode, '1234');
    // 就地切面板：既没有新路由压入，也没有弹提示条。
    expect(recorder.pushed.length, pushesBefore);
    expect(recorder.popped, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a failed send keeps the panel on the phone step', (
    tester,
  ) async {
    final recorder = _RouteRecorder();
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    final pageContext = await _pumpLoginHarness(tester, recorder: recorder);
    final pushesBefore = recorder.pushed.length;

    final send = command.sendMessageCode(pageContext, '13800138000', '1234');
    api.completeNextMessageCode(false);
    await send;

    expect(command.step.value, DrinkLoginStep.phone);
    expect(command.submittedPhone.value, isEmpty);
    expect(recorder.pushed.length, pushesBefore);
    await _drainSnackBars(tester);
  });

  testWidgets('a successful login pops the page once', (tester) async {
    final recorder = _RouteRecorder();
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    final rootContext = await _pumpLoginHarness(tester, recorder: recorder);
    final pageContext = await _pushLoginPage(tester, rootContext);
    final popsBefore = recorder.popped.length;

    final first = command.login('13800138000', '5678', pageContext);
    final second = command.login('13800138000', '5678', pageContext);
    api.completeNextLogin(true);
    await Future.wait([first, second]);
    await tester.pump();

    // 两次并发调用共用同一个请求，只允许退栈一次。
    expect(api.loginCalls, 1);
    expect(recorder.popped.length, popsBefore + 1);
    await _drainSnackBars(tester);
  });
}

Future<BuildContext> _pumpLoginHarness(
  WidgetTester tester, {
  _RouteRecorder? recorder,
}) async {
  BuildContext? pageContext;

  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers:
          recorder == null ? const <NavigatorObserver>[] : [recorder],
      home: Builder(
        builder: (context) {
          pageContext = context;
          return const Scaffold(body: Text('drink login'));
        },
      ),
    ),
  );

  return pageContext!;
}

Future<BuildContext> _pushLoginPage(
  WidgetTester tester,
  BuildContext rootContext,
) async {
  BuildContext? pageContext;

  Navigator.of(rootContext).push(
    MaterialPageRoute<void>(
      builder:
          (context) => Builder(
            builder: (context) {
              pageContext = context;
              return const Scaffold(body: Text('drink login pushed'));
            },
          ),
    ),
  );
  await tester.pumpAndSettle();

  return pageContext!;
}

/// 消息条的自动收起是真实 Timer，测试收尾前必须走完，
/// 否则 flutter_test 会以「Timer 仍挂起」判失败。
Future<void> _drainSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 9));
  await tester.pumpAndSettle();
}

SnackBar _snackBar(WidgetTester tester) =>
    tester.widget<SnackBar>(find.byType(SnackBar));

class _RouteRecorder extends NavigatorObserver {
  final List<Route<dynamic>> pushed = <Route<dynamic>>[];
  final List<Route<dynamic>> popped = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route);
  }
}

class _CaptchaRequest {
  const _CaptchaRequest({required this.doubleRandom, required this.timestamp});

  final String doubleRandom;
  final String timestamp;
}

class _MessageCodeRequest {
  const _MessageCodeRequest({
    required this.doubleRandom,
    required this.photoCode,
    required this.phone,
  });

  final String doubleRandom;
  final String photoCode;
  final String phone;
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
  final List<_MessageCodeRequest> messageCodeRequests = <_MessageCodeRequest>[];
  final List<Future<Uint8List>> _captchaResponses;
  final List<Completer<DrinkResult>> _messageCodeCompleters =
      <Completer<DrinkResult>>[];
  final List<Completer<DrinkResult>> _loginCompleters =
      <Completer<DrinkResult>>[];

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
  Future<DrinkResult> userMessageCode({
    required String doubleRandom,
    required String photoCode,
    required String phone,
  }) {
    messageCodeCalls++;
    messageCodeRequests.add(
      _MessageCodeRequest(
        doubleRandom: doubleRandom,
        photoCode: photoCode,
        phone: phone,
      ),
    );
    final completer = Completer<DrinkResult>();
    _messageCodeCompleters.add(completer);
    return completer.future;
  }

  void completeNextMessageCode(bool value) {
    completeNextMessageCodeWith(
      value
          ? const DrinkResult(success: true, code: 0)
          : const DrinkResult(success: false, code: 2003, message: '图形验证码错误'),
    );
  }

  void completeNextMessageCodeWith(DrinkResult result) {
    final completer = _messageCodeCompleters.removeAt(0);
    completer.complete(result);
  }

  @override
  Future<DrinkResult> userLogin({
    required String phone,
    required String messageCode,
  }) {
    loginCalls++;
    final completer = Completer<DrinkResult>();
    _loginCompleters.add(completer);
    return completer.future;
  }

  void completeNextLogin(bool value) {
    completeNextLoginWith(
      value
          ? const DrinkResult(success: true, code: 0)
          : const DrinkResult(success: false, code: 1002, message: '短信验证码错误'),
    );
  }

  void completeNextLoginWith(DrinkResult result) {
    final completer = _loginCompleters.removeAt(0);
    completer.complete(result);
  }
}
