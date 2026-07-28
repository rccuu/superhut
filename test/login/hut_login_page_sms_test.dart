import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/hut/sms_command.dart';
import 'package:superhut/login/hut/view.dart';
import 'package:superhut/utils/hut_user_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('switches to SMS mode and requests code via command', (
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
      MaterialApp(home: HutLoginPage(smsCommand: smsCommand)),
    );

    // 切换到验证码登录（按钮/Segment 文案以实现为准，测试用 find.text）
    await tester.tap(find.text('验证码登录'));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '13800138000');
    await tester.tap(find.text('获取验证码'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(requestMobile, '13800138000');
    smsCommand.dispose();
  });
}
