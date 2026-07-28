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

  testWidgets('shows SMS login entry and requests code via command', (
    tester,
  ) async {
    var requestMobile = '';
    final smsCommand = HutSmsLoginCommand(
      smsInit: () async => const HutAuthResult(success: true, nonce: 'n'),
      smsSend: ({required mobile, required nonce}) async {
        requestMobile = mobile;
        return const HutAuthResult(success: true);
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UnifiedLoginPage(smsCommand: smsCommand),
      ),
    );
    await tester.pump();

    expect(find.text('验证码登录'), findsOneWidget);

    await tester.tap(find.text('验证码登录'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '13800138000');
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(requestMobile, '13800138000');
    smsCommand.dispose();
  });

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

    await tester.tap(find.text('验证码登录'));
    await tester.pump();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '13800138000');
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(fields.at(1), '123456');
    await tester.tap(find.widgetWithText(FilledButton, '登录并继续'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(loginMobile, '13800138000');
    expect(loginCode, '123456');
    expect(credentialCalls, 1);
    expect(find.text('home 0'), findsOneWidget);
    smsCommand.dispose();
  });
}
