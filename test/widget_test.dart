import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:superhut/core/ui/apple_glass.dart';
import 'package:superhut/core/services/app_update_service.dart';
import 'package:superhut/home/coursetable/view.dart';
import 'package:superhut/home/homeview/view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/Functionpage/view.dart';
import 'package:superhut/home/userpage/view.dart';
import 'package:superhut/pages/Electricitybill/electricity_api.dart';

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
              'version': '1.5.7',
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

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('opens the function page when there is no saved session', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'isFirstOpen': false,
      'hasSeenTrustNotice': true,
    });

    await tester.pumpWidget(
      const MyApp(
        checkUpdatesOnStartup: false,
        resolveCourseStateOnStartup: false,
      ),
    );
    await pumpUntilFound(tester, find.byKey(const ValueKey('home-tab-stage')));

    expect(find.byKey(const ValueKey('home-tab-stage')), findsOneWidget);
    expect(find.text('功能'), findsOneWidget);
    expect(find.byType(FunctionPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-我的')));
    await pumpUntilFound(tester, find.byType(UserPage));

    expect(find.byType(UserPage), findsOneWidget);
  });

  testWidgets('opens the course tab when launched from the course widget', (
    WidgetTester tester,
  ) async {
    initialWidgetAction = 'course';
    SharedPreferences.setMockInitialValues({
      'isFirstOpen': false,
      'hasSeenTrustNotice': true,
    });

    await tester.pumpWidget(
      const MyApp(
        checkUpdatesOnStartup: false,
        resolveCourseStateOnStartup: false,
      ),
    );
    await pumpUntilFound(tester, find.byType(CourseTableView));

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
      const MaterialApp(
        home: HomeviewPage(initialIndex: 1, checkUpdatesOnStartup: false),
      ),
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
      const MaterialApp(
        home: HomeviewPage(initialIndex: 1, checkUpdatesOnStartup: false),
      ),
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

  testWidgets('keeps inactive tabs mounted but offstage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeviewPage(initialIndex: 1, checkUpdatesOnStartup: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FunctionPage), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-我的')));
    await tester.pumpAndSettle();

    expect(find.byType(UserPage), findsOneWidget);
    expect(find.byType(FunctionPage), findsNothing);
    expect(find.byType(FunctionPage, skipOffstage: false), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-loaded-tab-1'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('animates tab transitions horizontally by tab order', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppGlassPerformanceScope(
          isLite: false,
          child: HomeviewPage(initialIndex: 1, checkUpdatesOnStartup: false),
        ),
      ),
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

  testWidgets('reuses tab transition state after completed animations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppGlassPerformanceScope(
          isLite: false,
          child: HomeviewPage(initialIndex: 1, checkUpdatesOnStartup: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-我的')));
    await tester.pump();
    expect(find.byKey(const ValueKey('home-tab-slide-2')), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-功能')));
    await tester.pump();
    expect(find.byKey(const ValueKey('home-tab-slide-1')), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-我的')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('home-tab-slide-2')), findsOneWidget);
  });

  testWidgets('skips tab transition animation in lite mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeviewPage(initialIndex: 1, checkUpdatesOnStartup: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-我的')));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-tab-slide-2')), findsNothing);
    expect(find.byType(UserPage), findsOneWidget);
  });

  testWidgets('keeps dock style stable during tab transition', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeviewPage(initialIndex: 1, checkUpdatesOnStartup: false),
      ),
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

  testWidgets('uses shorter dock item animation in lite mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeviewPage(initialIndex: 1, checkUpdatesOnStartup: false),
      ),
    );
    await tester.pumpAndSettle();

    final nav = tester.widget<GNav>(find.byType(GNav));
    expect(nav.duration, const Duration(milliseconds: 90));
  });

  testWidgets('disables ticker activity for inactive tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeviewPage(initialIndex: 1, checkUpdatesOnStartup: false),
      ),
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
        home: const HomeviewPage(initialIndex: 1, checkUpdatesOnStartup: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-hit-zone-我的')));
    await tester.pump();

    expect(find.byKey(const ValueKey('home-tab-slide-2')), findsNothing);
    expect(find.byType(UserPage), findsOneWidget);

    final nav = tester.widget<GNav>(find.byType(GNav));
    expect(nav.duration, Duration.zero);
  });

  testWidgets(
    'electricity alert recharge action closes dialog and opens once',
    (WidgetTester tester) async {
      final openCompleter = Completer<void>();
      var openCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeviewPage(
            initialIndex: 1,
            checkUpdatesOnStartup: false,
            electricityAlertChecker: _FakeHomeElectricityAlertChecker(
              alert: const HomeElectricityAlert(
                roomCount: '8.00',
                bill: 20,
                roomName: '一舍101',
              ),
            ),
            openElectricityPage: (_) {
              openCalls++;
              return openCompleter.future;
            },
          ),
        ),
      );
      await pumpUntilFound(tester, find.text('电费达到预警值'));

      final rechargeButton = find.widgetWithText(TextButton, '立即充值');
      final onPressed = tester.widget<TextButton>(rechargeButton).onPressed;
      onPressed?.call();
      onPressed?.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(openCalls, 1);
      expect(find.text('电费达到预警值'), findsNothing);
      expect(rechargeButton, findsNothing);

      openCompleter.complete();
      await tester.pump();
    },
  );

  testWidgets('electricity alert recharge action reports opener errors', (
    WidgetTester tester,
  ) async {
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeviewPage(
          initialIndex: 1,
          checkUpdatesOnStartup: false,
          electricityAlertChecker: _FakeHomeElectricityAlertChecker(
            alert: const HomeElectricityAlert(
              roomCount: '8.00',
              bill: 20,
              roomName: '一舍101',
            ),
          ),
          openElectricityPage: (_) async {
            openCalls++;
            throw Exception('route unavailable');
          },
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('电费达到预警值'));

    final rechargeButton = find.widgetWithText(TextButton, '立即充值');
    final onPressed = tester.widget<TextButton>(rechargeButton).onPressed;
    onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(openCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('打开电费页面失败，请稍后重试'), findsOneWidget);
    expect(find.text('电费达到预警值'), findsNothing);
  });

  testWidgets('startup update check failure does not block electricity alert', (
    WidgetTester tester,
  ) async {
    var fetchCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeviewPage(
          initialIndex: 1,
          electricityAlertChecker: _FakeHomeElectricityAlertChecker(
            alert: const HomeElectricityAlert(
              roomCount: '8.00',
              bill: 20,
              roomName: '一舍101',
            ),
          ),
          fetchUpdate: ({required currentVersion}) async {
            fetchCalls++;
            throw Exception('update check unavailable');
          },
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('电费达到预警值'));

    expect(fetchCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('电费达到预警值'), findsOneWidget);
    expect(find.textContaining('update check unavailable'), findsNothing);
  });

  testWidgets('startup version read failure still checks electricity alert', (
    WidgetTester tester,
  ) async {
    var fetchCalls = 0;
    var versionCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeviewPage(
          initialIndex: 1,
          electricityAlertChecker: _FakeHomeElectricityAlertChecker(
            alert: const HomeElectricityAlert(
              roomCount: '8.00',
              bill: 20,
              roomName: '一舍101',
            ),
          ),
          loadCurrentVersion: () async {
            versionCalls++;
            throw Exception('package info unavailable');
          },
          fetchUpdate: ({required currentVersion}) async {
            fetchCalls++;
            return null;
          },
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('电费达到预警值'));

    expect(versionCalls, 1);
    expect(fetchCalls, 0);
    expect(tester.takeException(), isNull);
    expect(find.text('电费达到预警值'), findsOneWidget);
    expect(find.textContaining('package info unavailable'), findsNothing);
  });

  testWidgets('update release action closes dialog and opens once', (
    WidgetTester tester,
  ) async {
    final openCompleter = Completer<bool>();
    final openedUrls = <Uri>[];
    final downloadUrl = Uri.parse(
      'https://github.com/rccuu/superhut/releases/download/v9.9.9/superhut-v9.9.9+99-arm64-v8a-release.apk',
    );
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeviewPage(
          initialIndex: 1,
          electricityAlertChecker: _FakeHomeElectricityAlertChecker(
            alert: null,
          ),
          fetchUpdate:
              ({required currentVersion}) async => AppUpdateInfo(
                version: Version(9, 9, 9),
                tagName: 'v9.9.9',
                releaseUrl: Uri.parse('https://example.com/releases/v9.9.9'),
                downloadUrl: downloadUrl,
                downloadFileName: 'superhut-v9.9.9+99-arm64-v8a-release.apk',
                notes: '测试更新说明',
              ),
          openUpdateRelease: (url) {
            openCalls++;
            openedUrls.add(url);
            return openCompleter.future;
          },
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('发现新版本 v9.9.9'));

    final updateButton = find.widgetWithText(TextButton, '下载安装包');
    final onPressed = tester.widget<TextButton>(updateButton).onPressed;
    onPressed?.call();
    onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(openCalls, 1);
    expect(openedUrls, [downloadUrl]);
    expect(find.text('发现新版本 v9.9.9'), findsNothing);
    expect(updateButton, findsNothing);

    openCompleter.complete(true);
    await tester.pump();
  });

  testWidgets('update release action reports opener errors', (
    WidgetTester tester,
  ) async {
    var openCalls = 0;
    final releaseUrl = Uri.parse('https://example.com/releases/v9.9.9');
    final downloadUrl = Uri.parse(
      'https://github.com/rccuu/superhut/releases/download/v9.9.9/superhut-v9.9.9+99-arm64-v8a-release.apk',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeviewPage(
          initialIndex: 1,
          electricityAlertChecker: _FakeHomeElectricityAlertChecker(
            alert: null,
          ),
          fetchUpdate:
              ({required currentVersion}) async => AppUpdateInfo(
                version: Version(9, 9, 9),
                tagName: 'v9.9.9',
                releaseUrl: releaseUrl,
                downloadUrl: downloadUrl,
                downloadFileName: 'superhut-v9.9.9+99-arm64-v8a-release.apk',
                notes: '测试更新说明',
              ),
          openUpdateRelease: (_) async {
            openCalls++;
            throw Exception('browser unavailable');
          },
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('发现新版本 v9.9.9'));

    final updateButton = find.widgetWithText(TextButton, '下载安装包');
    final onPressed = tester.widget<TextButton>(updateButton).onPressed;
    onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(openCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开下载链接，请稍后重试'), findsOneWidget);
    expect(find.textContaining(releaseUrl.toString()), findsNothing);
    expect(find.textContaining(downloadUrl.toString()), findsNothing);
    expect(find.text('发现新版本 v9.9.9'), findsNothing);
  });
}

class _FakeHomeElectricityAlertChecker extends HomeElectricityAlertChecker {
  _FakeHomeElectricityAlertChecker({required this.alert})
    : super(electricityApiFactory: _neverCreateElectricityApi);

  final HomeElectricityAlert? alert;

  @override
  Future<HomeElectricityAlert?> check() async => alert;
}

ElectricityApiClient _neverCreateElectricityApi() {
  throw StateError('Fake alert checker should not create an API client.');
}
