import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/coursetable/view.dart';
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
  const widgetActionsChannel = MethodChannel(
    'com.superhut.rice.superhut/widget_actions',
  );
  late Directory applicationDocumentsDirectory;
  String? initialWidgetAction;

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
              'version': '1.4.2',
              'buildNumber': '1',
              'buildSignature': '',
            };
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetActionsChannel, (call) async {
          if (call.method == 'getInitialWidgetAction') {
            final action = initialWidgetAction;
            initialWidgetAction = null;
            return action;
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetActionsChannel, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    initialWidgetAction = null;
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

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-我的')));
    await tester.pumpAndSettle();

    expect(find.byType(UserPage), findsOneWidget);
  });

  testWidgets('opens the course tab when launched from the course widget', (
    WidgetTester tester,
  ) async {
    initialWidgetAction = 'course';

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(CourseTableView), findsOneWidget);
    expect(find.byType(FunctionPage), findsNothing);
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
    expect(find.byKey(const ValueKey('home-hit-zone-我的')), findsOneWidget);

    final navRect = tester.getRect(
      find.byKey(const ValueKey('home-bottom-nav')),
    );
    expect(navRect.center.dy, greaterThan(740));
    expect(navRect.bottom, lessThanOrEqualTo(844));

    final leftHitZone = find.byKey(const ValueKey('home-hit-zone-课表'));
    expect(leftHitZone, findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-loaded-tab-0'), skipOffstage: false),
      findsOneWidget,
    );
    final leftHitZoneRect = tester.getRect(leftHitZone);
    expect(leftHitZoneRect.width, greaterThan(90));

    await tester.tapAt(
      Offset(
        leftHitZoneRect.left + leftHitZoneRect.width * 0.18,
        leftHitZoneRect.center.dy,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CourseTableView), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-我的')));
    await tester.pumpAndSettle();

    expect(find.byType(UserPage), findsOneWidget);
  });

  testWidgets('preloads the course tab offstage after the first frame', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeviewPage(initialIndex: 1)),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey('home-loaded-tab-0'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(CourseTableView), findsNothing);
    expect(find.byType(CourseTableView, skipOffstage: false), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets('animates tab transitions horizontally by tab order', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeviewPage(initialIndex: 1)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-我的')));
    await tester.pump();

    final slideToUser = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('home-tab-slide-2')),
    );
    expect(slideToUser.position.value.dx, greaterThan(0));
    expect(slideToUser.position.value.dy, 0);

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-课表')));
    await tester.pump();

    final slideToCourse = tester.widget<SlideTransition>(
      find.byKey(const ValueKey('home-tab-slide-0')),
    );
    expect(slideToCourse.position.value.dx, lessThan(0));
    expect(slideToCourse.position.value.dy, 0);
  });

  testWidgets('keeps dock style stable during tab transition', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeviewPage(initialIndex: 1)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-bottom-nav-panel-stable')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-我的')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('home-bottom-nav-panel-stable')),
      findsOneWidget,
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-bottom-nav-panel-stable')),
      findsOneWidget,
    );
  });

  testWidgets('disables ticker activity for inactive tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeviewPage(initialIndex: 1)),
    );
    await tester.pumpAndSettle();

    final courseTickerFinder = find.descendant(
      of: find.byKey(const ValueKey('home-loaded-tab-0'), skipOffstage: false),
      matching: find.byType(TickerMode, skipOffstage: false),
    );
    final functionTickerFinder = find.descendant(
      of: find.byKey(const ValueKey('home-loaded-tab-1'), skipOffstage: false),
      matching: find.byType(TickerMode, skipOffstage: false),
    );

    expect(
      tester.widget<TickerMode>(courseTickerFinder.first).enabled,
      isFalse,
    );
    expect(
      tester.widget<TickerMode>(functionTickerFinder.first).enabled,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-课表')));
    await tester.pump();

    expect(tester.widget<TickerMode>(courseTickerFinder.first).enabled, isTrue);
    expect(
      tester.widget<TickerMode>(functionTickerFinder.first).enabled,
      isFalse,
    );
  });

  testWidgets('skips tab transition animation when animations are disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
        home: const HomeviewPage(initialIndex: 1),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-我的')));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-tab-slide-2')), findsNothing);
    expect(find.byType(UserPage), findsOneWidget);
  });
}
