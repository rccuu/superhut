import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/homeview/view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/Functionpage/view.dart';
import 'package:superhut/home/userpage/view.dart';

import 'package:superhut/main.dart';

import 'support/path_provider_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const packageInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );
  late Directory applicationDocumentsDirectory;

  setUpAll(() {
    applicationDocumentsDirectory = Directory.systemTemp.createTempSync(
      'superhut_widget_test_',
    );
    PathProviderMock.install(
      applicationDocumentsPath: applicationDocumentsDirectory.path,
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
    if (applicationDocumentsDirectory.existsSync()) {
      applicationDocumentsDirectory.deleteSync(recursive: true);
    }
    PathProviderMock.uninstall();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    for (final entity in applicationDocumentsDirectory.listSync()) {
      entity.deleteSync(recursive: true);
    }
  });

  testWidgets('opens the function page when there is no saved session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(IndexedStack), findsOneWidget);
    expect(find.text('功能'), findsOneWidget);
    expect(find.byType(FunctionPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-tab-我的')));
    await tester.pumpAndSettle();

    expect(find.byType(UserPage), findsOneWidget);
  });

  testWidgets('switches tabs on a phone-sized viewport', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: HomeviewPage(initialIndex: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-bottom-nav')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-tab-我的')), findsOneWidget);

    final navRect = tester.getRect(
      find.byKey(const ValueKey('home-bottom-nav')),
    );
    expect(navRect.center.dy, greaterThan(740));
    expect(navRect.bottom, lessThanOrEqualTo(844));

    await tester.tap(find.byKey(const ValueKey('home-tab-我的')));
    await tester.pumpAndSettle();

    expect(find.byType(UserPage), findsOneWidget);
  });
}
