import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/widgets/app_form_fields.dart';
import 'package:superhut/main.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:superhut/pages/drink/api/drink_result.dart';
import 'package:superhut/pages/drink/core/drink_home_tokens.dart';
import 'package:superhut/pages/drink/login/command.dart';
import 'package:superhut/pages/drink/login/view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the phone panel starts as the only panel', (tester) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    await _pumpLoginPage(tester, api: api, command: command);

    expect(api.captchaCalls, 1);
    expect(command.step.value, DrinkLoginStep.phone);
    expect(find.byKey(const Key('phoneField')), findsOneWidget);
    expect(find.byKey(const Key('captchaField')), findsOneWidget);
    expect(find.byKey(const Key('backFromSms')), findsNothing);
    // 旧的独立刷新按钮已被「点图片本身」取代。
    expect(find.textContaining('刷新'), findsNothing);
    // 手机号面板正好两个输入框：手机号 + 图形验证码。
    expect(find.byType(AppTextField), findsNWidgets(2));
  });

  testWidgets('the phone panel refuses to send an incomplete form', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    await _pumpLoginPage(tester, api: api, command: command);

    final sendButton = find.byType(AppPrimaryButton);

    await tester.ensureVisible(sendButton);
    await tester.tap(sendButton);
    await tester.pump();

    expect(_snackBarText('请输入手机号和图形验证码'), findsOneWidget);
    expect(api.messageCodeCalls, 0);
    await _drainSnackBars(tester);

    // 只填手机号仍然不够，图形验证码不能留空。
    await tester.enterText(_field('phoneField'), '13800138000');
    await tester.ensureVisible(sendButton);
    await tester.tap(sendButton);
    await tester.pump();

    expect(_snackBarText('请输入手机号和图形验证码'), findsOneWidget);
    expect(api.messageCodeCalls, 0);
    expect(command.step.value, DrinkLoginStep.phone);
    await _drainSnackBars(tester);
  });

  testWidgets('the sms panel refuses to submit an empty code', (tester) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    await _pumpLoginPage(tester, api: api, command: command);
    await _reachSmsPanel(tester, api: api, command: command);

    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pump();

    expect(_snackBarText('请输入短信验证码'), findsOneWidget);
    expect(api.loginCalls, 0);
    await _drainSnackBars(tester);
  });

  testWidgets('the send request is only fired once while in flight', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    await _pumpLoginPage(tester, api: api, command: command);

    await tester.enterText(_field('phoneField'), '13800138000');
    await tester.enterText(_field('captchaField'), '1234');

    final sendButton = find.byType(AppPrimaryButton);
    await tester.ensureVisible(sendButton);
    await tester.tap(sendButton);
    await tester.tap(sendButton);
    await tester.pump();

    expect(api.messageCodeCalls, 1);

    api.completeNextMessageCode(false);
    await tester.pump();
    await _drainSnackBars(tester);

    // 上一次请求结束后允许重试。
    await tester.ensureVisible(sendButton);
    await tester.tap(sendButton);
    await tester.pump();
    expect(api.messageCodeCalls, 2);

    api.completeNextMessageCode(false);
    await tester.pump();
    await _drainSnackBars(tester);
  });

  testWidgets('the submit request is only fired once while in flight', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    await _pumpLoginPage(tester, api: api, command: command);
    await _reachSmsPanel(tester, api: api, command: command);

    await tester.enterText(_field('smsField'), '5678');

    final submitButton = find.byType(AppPrimaryButton);
    await tester.tap(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(api.loginCalls, 1);

    api.completeNextLogin(false);
    await tester.pump();
    await _drainSnackBars(tester);

    await tester.tap(submitButton);
    await tester.pump();
    expect(api.loginCalls, 2);

    api.completeNextLogin(false);
    await tester.pump();
    await _drainSnackBars(tester);
  });

  testWidgets('an empty or failed captcha load recovers through the image', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);

    await tester.pumpWidget(
      MaterialApp(home: DrinkLoginPage(command: command)),
    );
    await tester.pump();

    // 首次取图未完成前显示加载指示，而不是任何错误文案。
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(_captchaPlaceholder, findsNothing);

    api.completeNextCaptcha();
    await tester.pumpAndSettle();

    // 空响应退化成占位图标，且可以点图重取。
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(_captchaPlaceholder, findsOneWidget);

    await tester.tap(find.byKey(const Key('captchaImage')));
    await tester.pump();
    expect(api.captchaCalls, 2);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    api.failNextCaptcha(Exception('captcha unavailable token=secret-token'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(_captchaPlaceholder, findsOneWidget);
    expect(find.textContaining('secret-token'), findsNothing);
    expect(find.textContaining('token='), findsNothing);

    await tester.tap(find.byKey(const Key('captchaImage')));
    await tester.pump();
    expect(api.captchaCalls, 3);

    api.completeNextCaptcha();
    await tester.pumpAndSettle();
    expect(_captchaPlaceholder, findsOneWidget);
  });

  testWidgets('tapping the captcha image refetches it', (tester) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    await _pumpLoginPage(tester, api: api, command: command);

    expect(api.captchaCalls, 1);

    await tester.tap(find.byKey(const Key('captchaImage')));
    await tester.pump();

    expect(api.captchaCalls, 2);

    api.completeNextCaptcha();
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('a successful send switches the panel in place', (tester) async {
    final recorder = _RouteRecorder();
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    await _pumpLoginPage(
      tester,
      api: api,
      command: command,
      observers: [recorder],
    );
    final pushesBefore = recorder.pushed.length;

    await tester.enterText(_field('phoneField'), '13800138000');
    await tester.enterText(_field('captchaField'), '1234');
    await tester.ensureVisible(find.byType(AppPrimaryButton));
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pump();

    api.completeNextMessageCode(true);
    await tester.pumpAndSettle();

    expect(command.step.value, DrinkLoginStep.sms);
    expect(find.text('验证码已发送至 13800138000'), findsOneWidget);
    expect(find.byKey(const Key('smsField')), findsOneWidget);
    // 短信码面板只有一个输入框。
    expect(find.byType(AppTextField), findsOneWidget);
    // 就地切换：没有压入新路由，也没有弹提示条。
    expect(recorder.pushed.length, pushesBefore);
    expect(recorder.popped, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    // 验证码是一次性凭据，切到短信面板时不能再发一次取图请求。
    expect(api.captchaCalls, 1);
  });

  testWidgets('the back button returns to the phone panel with a new captcha', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    await _pumpLoginPage(tester, api: api, command: command);
    await _reachSmsPanel(tester, api: api, command: command);

    expect(api.captchaCalls, 1);

    await tester.tap(find.byKey(const Key('backFromSms')));
    await tester.pump();

    expect(command.step.value, DrinkLoginStep.phone);
    expect(find.byKey(const Key('phoneField')), findsOneWidget);
    expect(find.byKey(const Key('smsField')), findsNothing);
    // 回到第一步必须换一张新的图形验证码。
    expect(api.captchaCalls, 2);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    api.completeNextCaptcha();
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
  });

  testWidgets('the captcha field is numeric, digits-only and capped at six', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    await _pumpLoginPage(tester, api: api, command: command);

    final captcha = _field('captchaField');
    final field = tester.widget<TextField>(captcha);
    expect(field.keyboardType, TextInputType.number);
    expect(field.maxLength, 6);
    expect(field.inputFormatters, hasLength(1));
    expect(field.inputFormatters!.single, isA<FilteringTextInputFormatter>());

    await tester.enterText(captcha, 'a1b2c');
    expect(tester.widget<TextField>(captcha).controller!.text, '12');

    await tester.enterText(captcha, '12345678');
    expect(tester.widget<TextField>(captcha).controller!.text, '123456');
  });

  testWidgets('the brand band is the only gradient in either brightness', (
    tester,
  ) async {
    for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final api = _FakeDrinkLoginApi();
      final command = DrinkLoginCommand(api: api);
      await _pumpLoginPage(tester, api: api, command: command, theme: theme);

      final gradients = _gradientsInTree(tester);
      expect(
        gradients,
        hasLength(1),
        reason: '${theme.brightness} 下只允许品牌带这一处渐变',
      );

      final band = gradients.single;
      final scaffoldColor =
          Theme.of(
            tester.element(find.byKey(const Key('loginBrandBand'))),
          ).scaffoldBackgroundColor;

      expect(band.colors, hasLength(2));
      expect(band.colors.first, DrinkBrand.primary.withValues(alpha: 0.16));
      // 尾色就是页面底色，只是完全透明，所以带子边缘不会切出硬边。
      expect(band.colors.last.a, 0);
      expect(band.colors.last, scaffoldColor.withValues(alpha: 0));
      expect(band.colors.last.r, scaffoldColor.r);
      expect(band.colors.last.g, scaffoldColor.g);
      expect(band.colors.last.b, scaffoldColor.b);

      expect(
        tester.getSize(find.byKey(const Key('loginBrandBand'))).height,
        DrinkLoginPage.bandHeight,
      );
      expect(DrinkLoginPage.bandHeight, 168);
      expect(find.byType(ShaderMask), findsNothing);
    }
  });

  testWidgets('the captcha image is 104x52 and centered on its field', (
    tester,
  ) async {
    for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final api = _FakeDrinkLoginApi();
      final command = DrinkLoginCommand(api: api);
      await _pumpLoginPage(tester, api: api, command: command, theme: theme);

      final image = find.byKey(const Key('captchaImage'));
      expect(tester.getSize(image), const Size(104, 52));
      expect(DrinkLoginPage.captchaImageWidth, 104);
      expect(DrinkLoginPage.captchaImageHeight, 52);

      final imageCenter = tester.getRect(image).center;
      final fieldCenter = tester.getRect(_field('captchaField')).center;
      expect(
        (imageCenter - fieldCenter).dy.abs(),
        lessThan(4),
        reason: '${theme.brightness} 下图片与输入框不同中线',
      );
    }
  });

  testWidgets('the page paints no legacy cyan in either brightness', (
    tester,
  ) async {
    const legacyCyan = Color(0xFF0099CC);

    for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final api = _FakeDrinkLoginApi();
      final command = DrinkLoginCommand(api: api);
      await _pumpLoginPage(tester, api: api, command: command, theme: theme);

      final colors = _colorsInTree(tester);
      // 扫描器必须真的扫到了颜色，否则这条断言是空的。
      expect(colors, contains(DrinkBrand.primary));
      expect(
        colors.any((color) => color == legacyCyan),
        isFalse,
        reason: '${theme.brightness} 下出现了历史遗留的 #0099CC',
      );

      // 切到短信码面板再扫一次，两面板都不许残留旧色值。
      await _reachSmsPanel(tester, api: api, command: command);
      expect(
        _colorsInTree(tester).any((color) => color == legacyCyan),
        isFalse,
        reason: '${theme.brightness} 短信面板出现了历史遗留的 #0099CC',
      );
    }
  });

  testWidgets('the scaffold leaves its background to the theme', (
    tester,
  ) async {
    for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final api = _FakeDrinkLoginApi();
      final command = DrinkLoginCommand(api: api);
      await _pumpLoginPage(tester, api: api, command: command, theme: theme);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, isNull);
    }
  });

  testWidgets('the shared field metrics come from the app form widgets', (
    tester,
  ) async {
    final api = _FakeDrinkLoginApi();
    final command = DrinkLoginCommand(api: api);
    await _pumpLoginPage(tester, api: api, command: command);

    expect(AppTextField.cornerRadius, 16);
    expect(AppTextField.labelGap, 8);
    expect(
      tester.widget<AppPrimaryButton>(find.byType(AppPrimaryButton)).height,
      56,
    );

    final phoneField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('phoneField')),
        matching: find.byType(TextField),
      ),
    );
    final decoration = phoneField.decoration!;
    expect(decoration.counterText, '');
    expect(decoration.filled, isTrue);

    await tester.enterText(_field('phoneField'), '13abc8001380000');
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('phoneField')),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text,
      '13800138000',
    );
  });
}

Finder get _captchaPlaceholder => find.byWidgetPredicate(
  (widget) =>
      widget is Icon &&
      widget.icon == Icons.refresh_rounded &&
      widget.size == 20,
);

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

/// 手机号面板的副标题与「字段为空」的提示用的是同一句话，
/// 所以断言必须限定在消息条里，否则两条都会命中。
Finder _snackBarText(String message) =>
    find.descendant(of: find.byType(SnackBar), matching: find.text(message));

Future<void> _pumpLoginPage(
  WidgetTester tester, {
  required _FakeDrinkLoginApi api,
  required DrinkLoginCommand command,
  ThemeData? theme,
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      navigatorObservers: observers,
      // 换 Key 强制重建 State：同一轮测试里连续换主题时，
      // 复用旧 State 就不会再发第一次取图请求。
      home: DrinkLoginPage(key: UniqueKey(), command: command),
    ),
  );
  await tester.pump();
  api.completeNextCaptcha();
  await tester.pumpAndSettle();
}

/// 走完手机号面板，用一次成功的短信发送就地切到验证码面板。
Future<void> _reachSmsPanel(
  WidgetTester tester, {
  required _FakeDrinkLoginApi api,
  required DrinkLoginCommand command,
}) async {
  expect(command.step.value, DrinkLoginStep.phone);

  await tester.enterText(_field('phoneField'), '13800138000');
  await tester.enterText(_field('captchaField'), '1234');
  await tester.ensureVisible(find.byType(AppPrimaryButton));
  await tester.tap(find.byType(AppPrimaryButton));
  await tester.pump();

  api.completeNextMessageCode(true);
  await tester.pumpAndSettle();

  expect(command.step.value, DrinkLoginStep.sms);
}

/// 消息条的自动收起是真实 Timer，收尾前必须走完，
/// 否则 flutter_test 会以「Timer 仍挂起」判失败。
Future<void> _drainSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 9));
  await tester.pumpAndSettle();
}

List<LinearGradient> _gradientsInTree(WidgetTester tester) {
  final gradients = <LinearGradient>[];
  for (final widget in tester.allWidgets) {
    Gradient? gradient;
    if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) {
        gradient = decoration.gradient;
      }
    } else if (widget is Container) {
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) {
        gradient = decoration.gradient;
      }
    }
    if (gradient is LinearGradient) {
      gradients.add(gradient);
    } else if (gradient != null) {
      fail('页面出现了预期之外的渐变类型：$gradient');
    }
  }
  return gradients;
}

Set<Color> _colorsInTree(WidgetTester tester) {
  final colors = <Color>{};
  for (final widget in tester.allWidgets) {
    _collectColors(widget, colors);
  }
  return colors;
}

void _collectColors(Object? node, Set<Color> out) {
  switch (node) {
    case null:
      return;
    case Color color:
      out.add(color);
      return;
    case TextStyle style:
      _collectColors(style.color, out);
      _collectColors(style.backgroundColor, out);
      _collectColors(style.foreground, out);
      _collectColors(style.decorationColor, out);
      return;
    case LinearGradient gradient:
      _collectColors(gradient.colors, out);
      return;
    case RadialGradient gradient:
      _collectColors(gradient.colors, out);
      return;
    case SweepGradient gradient:
      _collectColors(gradient.colors, out);
      return;
    case BoxDecoration decoration:
      _collectColors(decoration.color, out);
      _collectColors(decoration.gradient, out);
      _collectColors(decoration.border, out);
      _collectColors(decoration.boxShadow, out);
      return;
    case BoxShadow shadow:
      _collectColors(shadow.color, out);
      return;
    case Border border:
      for (final side in <BorderSide>[
        border.top,
        border.bottom,
        border.left,
        border.right,
      ]) {
        _collectColors(side.color, out);
      }
      return;
    case InputDecoration decoration:
      _collectColors(decoration.fillColor, out);
      _collectColors(decoration.iconColor, out);
      _collectColors(decoration.hintStyle, out);
      _collectColors(decoration.labelStyle, out);
      _collectColors(decoration.counterStyle, out);
      _collectColors(decoration.floatingLabelStyle, out);
      _collectColors(decoration.helperStyle, out);
      _collectColors(decoration.errorStyle, out);
      _collectColors(decoration.focusedBorder, out);
      _collectColors(decoration.enabledBorder, out);
      _collectColors(decoration.border, out);
      return;
    case OutlineInputBorder border:
      _collectColors(border.borderSide.color, out);
      return;
    case ButtonStyle style:
      for (final property in <WidgetStateProperty<Color?>?>[
        style.backgroundColor,
        style.foregroundColor,
        style.overlayColor,
        style.shadowColor,
        style.iconColor,
      ]) {
        _collectColors(property, out);
      }
      return;
    case WidgetStateProperty<Color?> property:
      _collectColors(property.resolve(const <WidgetState>{}), out);
      return;
    case FilledButton button:
      _collectColors(button.style, out);
      return;
    case IconButton button:
      _collectColors(button.style, out);
      _collectColors(button.icon, out);
      return;
    case TextButton button:
      _collectColors(button.style, out);
      return;
    case Material material:
      _collectColors(material.color, out);
      return;
    case ColoredBox box:
      _collectColors(box.color, out);
      return;
    case DecoratedBox box:
      _collectColors(box.decoration, out);
      return;
    case Container container:
      _collectColors(container.color, out);
      _collectColors(container.decoration, out);
      return;
    case Text text:
      _collectColors(text.style, out);
      return;
    case Icon icon:
      _collectColors(icon.color, out);
      return;
    case TextField field:
      _collectColors(field.decoration, out);
      _collectColors(field.style, out);
      _collectColors(field.cursorColor, out);
      return;
    case ProgressIndicator indicator:
      _collectColors(indicator.valueColor, out);
      _collectColors(indicator.backgroundColor, out);
      return;
    case Image image:
      _collectColors(image.color, out);
      return;
    case CupertinoActivityIndicator indicator:
      _collectColors(indicator.color, out);
      return;
    case Iterable<Object?> children:
      for (final child in children) {
        _collectColors(child, out);
      }
      return;
  }
}

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

class _FakeDrinkLoginApi implements DrinkLoginApiClient {
  int captchaCalls = 0;
  int messageCodeCalls = 0;
  int loginCalls = 0;
  final List<Completer<Uint8List>> _captchaCompleters =
      <Completer<Uint8List>>[];
  final List<Completer<DrinkResult>> _messageCodeCompleters =
      <Completer<DrinkResult>>[];
  final List<Completer<DrinkResult>> _loginCompleters =
      <Completer<DrinkResult>>[];

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

  /// 默认返回空字节：真实图片字节在这里不重要，重要的是状态机。
  void completeNextCaptcha([List<int> bytes = const <int>[]]) {
    final completer = _captchaCompleters.removeAt(0);
    completer.complete(Uint8List.fromList(bytes));
  }

  void failNextCaptcha(Object error) {
    final completer = _captchaCompleters.removeAt(0);
    completer.completeError(error);
  }

  @override
  Future<DrinkResult> userMessageCode({
    required String doubleRandom,
    required String photoCode,
    required String phone,
  }) {
    messageCodeCalls++;
    final completer = Completer<DrinkResult>();
    _messageCodeCompleters.add(completer);
    return completer.future;
  }

  void completeNextMessageCode(bool value) {
    final completer = _messageCodeCompleters.removeAt(0);
    completer.complete(
      value
          ? const DrinkResult(success: true, code: 0)
          : const DrinkResult(success: false, code: 2003, message: '图形验证码错误'),
    );
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
    final completer = _loginCompleters.removeAt(0);
    completer.complete(
      value
          ? const DrinkResult(success: true, code: 0)
          : const DrinkResult(success: false, code: 1002, message: '短信验证码错误'),
    );
  }
}
