import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/hut/sms_command.dart';
import 'package:superhut/login/unified_login_page.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../support/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(SecureStorageMock.install);
  tearDownAll(SecureStorageMock.uninstall);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureStorageMock.reset();
  });

  testWidgets(
    'defaults to SMS two-step: send expands code field with inline success, no snackbar',
    (tester) async {
      var requestMobile = '';
      final smsCommand = HutSmsLoginCommand(
        smsInit: () async => const HutAuthResult(success: true, nonce: 'n'),
        smsSend: ({required mobile, required nonce}) async {
          requestMobile = mobile;
          return const HutAuthResult(success: true);
        },
      );

      await tester.pumpWidget(
        MaterialApp(home: UnifiedLoginPage(smsCommand: smsCommand)),
      );
      await tester.pump();

      // 默认验证码登录：首屏只有手机号一个输入框
      expect(find.byType(TextField), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '获取验证码'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '13800138000');
      await tester.tap(find.widgetWithText(FilledButton, '获取验证码'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(requestMobile, '13800138000');
      // 两步展开：出现验证码输入框 + inline 成功提示
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('已发送到 138****8000'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      // 自动聚焦验证码框
      final codeField = tester.widget<TextField>(find.byType(TextField));
      expect(codeField.focusNode?.hasFocus, isTrue);
      smsCommand.dispose();
    },
  );

  testWidgets('SMS login success loads JWXT credentials and finishes login', (
    tester,
  ) async {
    var loginMobile = '';
    var loginCode = '';
    var credentialCalls = 0;
    final smsCommand = HutSmsLoginCommand(
      smsInit: () async => const HutAuthResult(success: true, nonce: 'n'),
      smsSend: ({required mobile, required nonce}) async {
        return const HutAuthResult(success: true);
      },
      smsLogin: ({required mobile, required smscode, required nonce}) async {
        loginMobile = mobile;
        loginCode = smscode;
        return const HutAuthResult(success: true);
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedLoginPage(
          smsCommand: smsCommand,
          buildHomeRoute: ({int initialIndex = 0}) {
            return MaterialPageRoute<void>(
              builder: (_) => Scaffold(body: Text('home $initialIndex')),
            );
          },
          loadJwxtCredentials: (_) async {
            credentialCalls++;
            return {'token': 'jwxt-token', 'my_client_ticket': 'jwxt-cookie'};
          },
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '13800138000');
    await tester.tap(find.widgetWithText(FilledButton, '获取验证码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '登录并继续'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loginMobile, '13800138000');
    expect(loginCode, '123456');
    expect(credentialCalls, 1);
    expect(find.text('home 0'), findsOneWidget);
    smsCommand.dispose();
  });

  testWidgets(
    'change phone number returns to phone step and resets countdown',
    (tester) async {
      final smsCommand = HutSmsLoginCommand(
        smsInit: () async => const HutAuthResult(success: true, nonce: 'n'),
        smsSend: ({required mobile, required nonce}) async {
          return const HutAuthResult(success: true);
        },
      );

      await tester.pumpWidget(
        MaterialApp(home: UnifiedLoginPage(smsCommand: smsCommand)),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), '13800138000');
      await tester.tap(find.widgetWithText(FilledButton, '获取验证码'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('已发送到 138****8000'), findsOneWidget);
      await tester.tap(find.text('更换号码'));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      final phoneField = tester.widget<TextField>(find.byType(TextField));
      expect(phoneField.controller?.text, '13800138000');
      expect(smsCommand.remainingSeconds, 0);
      smsCommand.dispose();
    },
  );

  testWidgets('send without mobile shows inline warning, no snackbar', (
    tester,
  ) async {
    final smsCommand = HutSmsLoginCommand(
      smsInit: () async => const HutAuthResult(success: true, nonce: 'n'),
      smsSend: ({required mobile, required nonce}) async {
        return const HutAuthResult(success: true);
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: UnifiedLoginPage(smsCommand: smsCommand)),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, '获取验证码'));
    await tester.pump();

    expect(find.text('请输入手机号'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    smsCommand.dispose();
  });
}
