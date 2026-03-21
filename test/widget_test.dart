import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:superhut/main.dart';

import 'support/path_provider_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const packageInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );

  setUpAll(() {
    PathProviderMock.install(
      applicationDocumentsPath: Directory.systemTemp.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, (call) async {
          if (call.method == 'getAll') {
            return <String, dynamic>{
              'appName': '工大盒子',
              'packageName': 'com.superhut.test',
              'version': '1.4.0',
              'buildNumber': '1',
              'buildSignature': '',
            };
          }
          return null;
        });
  });

  tearDownAll(() {
    PathProviderMock.uninstall();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('opens the function page when there is no saved session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(IndexedStack), findsOneWidget);
    expect(find.text('功能'), findsOneWidget);
    expect(find.text('空教室查询'), findsOneWidget);

    await tester.tap(find.byIcon(Ionicons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('当前未登录'), findsOneWidget);
  });
}
