import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/coursetable/view.dart';
import 'package:superhut/utils/course/coursemain.dart';

import '../../support/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const widgetChannel = MethodChannel(
    'com.superhut.rice.superhut/coursetable_widget',
  );

  DateTime currentMonday() {
    final now = DateTime.now();
    final daysToSubtract = now.weekday == DateTime.sunday ? 6 : now.weekday - 1;
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysToSubtract));
  }

  String dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String courseCardHitKey(DateTime day, Course course) {
    final endSection = course.startSection + course.duration - 1;
    return '${dateKey(day)}-${course.startSection}-$endSection-${course.name}';
  }

  SavedCourseSchedule buildTestSchedule({bool isReadOnly = false}) {
    final monday = currentMonday();
    final nextMonday = monday.add(const Duration(days: 7));

    return SavedCourseSchedule(
      id: 'schedule-swipe',
      name: '测试课表',
      ownerName: '测试用户',
      termLabel: '测试学期',
      semesterId: '2026-test',
      firstDay: dateKey(monday),
      maxWeek: 3,
      sourceType: CourseScheduleSourceType.manual,
      isReadOnly: isReadOnly,
      createdAt: '2026-03-24T16:00:00.000',
      updatedAt: '2026-03-24T16:00:00.000',
      courseData: {
        dateKey(monday): [
          Course(
            name: '当前周课程',
            teacherName: '张老师',
            weekDuration: '1-3',
            location: '公共101',
            startSection: 1,
            duration: 2,
          ),
        ],
        dateKey(nextMonday): [
          Course(
            name: '下一周课程',
            teacherName: '李老师',
            weekDuration: '2-3',
            location: '公共102',
            startSection: 3,
            duration: 2,
          ),
        ],
      },
    );
  }

  setUpAll(() {
    SecureStorageMock.install();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, null);
    SecureStorageMock.uninstall();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureStorageMock.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, (call) async {
          if (call.method == 'syncCourseTableWidget') {
            return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, null);
  });

  testWidgets('swipes to the next week with a real page transition', (
    tester,
  ) async {
    final schedule = buildTestSchedule();
    await tester.pumpWidget(
      MaterialApp(home: CourseTableView(debugScheduleOverride: schedule)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('第1周'), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('course-table-week-pager')),
      const Offset(-420, 0),
      1200,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('第2周'), findsOneWidget);
    expect(find.text('当前第1周'), findsOneWidget);
  });

  testWidgets('shows a compact cupertino preparing indicator first', (
    tester,
  ) async {
    final schedule = buildTestSchedule();
    await tester.pumpWidget(
      MaterialApp(home: CourseTableView(debugScheduleOverride: schedule)),
    );

    expect(
      find.byKey(const ValueKey('course-table-preparing-state')),
      findsOneWidget,
    );
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('正在准备课表'), findsNothing);
    expect(find.text('正在恢复本地课表数据'), findsNothing);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byKey(const ValueKey('course-table-preparing-state')),
      findsNothing,
    );
    expect(find.text('第1周'), findsOneWidget);
  });

  testWidgets('renders the static grid on a dedicated custom paint layer', (
    tester,
  ) async {
    final schedule = buildTestSchedule();
    await tester.pumpWidget(
      MaterialApp(home: CourseTableView(debugScheduleOverride: schedule)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byKey(const ValueKey('course-table-static-grid-layer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('course-table-static-card-layer')),
      findsOneWidget,
    );
    expect(find.byType(CustomPaint), findsWidgets);

    final gridPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('course-table-static-grid-layer')),
    );
    final cardPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('course-table-static-card-layer')),
    );

    expect(gridPaint.isComplex, isTrue);
    expect(gridPaint.willChange, isFalse);
    expect(cardPaint.isComplex, isTrue);
    expect(cardPaint.willChange, isFalse);
  });

  testWidgets('keeps painterized course cards interactive', (tester) async {
    final schedule = buildTestSchedule();
    final monday = currentMonday();
    final course = schedule.courseData[dateKey(monday)]!.single;

    await tester.pumpWidget(
      MaterialApp(home: CourseTableView(debugScheduleOverride: schedule)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final hitTarget = find.byKey(
      ValueKey<String>('course-card-hit-${courseCardHitKey(monday, course)}'),
    );

    expect(hitTarget, findsOneWidget);
    expect(find.text('当前周课程'), findsNothing);

    await tester.tap(hitTarget);
    await tester.pumpAndSettle();

    expect(find.text('当前周课程'), findsOneWidget);
    expect(find.text('公共101'), findsOneWidget);
  });

  testWidgets('stale schedule reload does not override latest archive', (
    tester,
  ) async {
    final monday = currentMonday();
    SavedCourseSchedule scheduleWithCourse(String id, String courseName) {
      return buildTestSchedule().copyWith(
        id: id,
        name: courseName,
        courseData: {
          dateKey(monday): [
            Course(
              name: courseName,
              teacherName: '张老师',
              weekDuration: '1-3',
              location: '公共101',
              startSection: 1,
              duration: 2,
            ),
          ],
        },
      );
    }

    final staleSchedule = scheduleWithCourse('stale-schedule', '旧课表课程');
    final latestSchedule = scheduleWithCourse('latest-schedule', '新课表课程');
    final archiveLoads = [
      Completer<CourseScheduleArchive>(),
      Completer<CourseScheduleArchive>(),
    ];
    var loadCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          loadScheduleArchive: () {
            return archiveLoads[loadCalls++].future;
          },
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('course-table-preparing-state')),
      findsOneWidget,
    );

    final dynamic pageState = tester.state(find.byType(CourseTableView));
    final latestReload = pageState.debugReloadScheduleState() as Future<bool>;
    expect(loadCalls, 2);

    archiveLoads[1].complete(
      CourseScheduleArchive(
        schemaVersion: 1,
        activeScheduleId: latestSchedule.id,
        schedules: [latestSchedule],
      ),
    );
    expect(await latestReload, isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final latestHitTarget = find.byKey(
      ValueKey<String>(
        'course-card-hit-${courseCardHitKey(monday, latestSchedule.courseData[dateKey(monday)]!.single)}',
      ),
    );
    final staleHitTarget = find.byKey(
      ValueKey<String>(
        'course-card-hit-${courseCardHitKey(monday, staleSchedule.courseData[dateKey(monday)]!.single)}',
      ),
    );

    expect(latestHitTarget, findsOneWidget);
    expect(staleHitTarget, findsNothing);

    archiveLoads[0].complete(
      CourseScheduleArchive(
        schemaVersion: 1,
        activeScheduleId: staleSchedule.id,
        schedules: [staleSchedule],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(latestHitTarget, findsOneWidget);
    expect(staleHitTarget, findsNothing);
  });

  testWidgets('unchanged schedule reload skips rebuild and keeps viewed week', (
    tester,
  ) async {
    var loadCalls = 0;

    CourseScheduleArchive loadArchive() {
      loadCalls++;
      final schedule = buildTestSchedule();
      return CourseScheduleArchive(
        schemaVersion: 1,
        activeScheduleId: schedule.id,
        schedules: [schedule],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(loadScheduleArchive: () async => loadArchive()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('第1周'), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('course-table-week-pager')),
      const Offset(-420, 0),
      1200,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('第2周'), findsOneWidget);

    final dynamic pageState = tester.state(find.byType(CourseTableView));
    final didReload = await pageState.debugReloadScheduleState() as bool;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(loadCalls, 2);
    expect(didReload, isFalse);
    expect(find.text('第2周'), findsOneWidget);
    expect(find.text('第1周'), findsNothing);
  });

  testWidgets('course detail sheet ignores duplicate taps while open', (
    tester,
  ) async {
    final sheetCompleter = Completer<void>();
    final schedule = buildTestSchedule();
    final monday = currentMonday();
    final course = schedule.courseData[dateKey(monday)]!.single;
    var sheetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          debugScheduleOverride: schedule,
          showBottomSheet: <T>({
            required BuildContext context,
            required WidgetBuilder builder,
            bool expand = false,
            Color? backgroundColor,
            Color? barrierColor,
            Color? transitionBackgroundColor,
          }) {
            sheetCalls++;
            return sheetCompleter.future.then<T?>((_) => null);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final hitTarget = find.byKey(
      ValueKey<String>('course-card-hit-${courseCardHitKey(monday, course)}'),
    );

    await tester.tap(hitTarget);
    await tester.pump();
    await tester.tap(hitTarget);
    await tester.pump();

    expect(sheetCalls, 1);

    sheetCompleter.complete();
    await tester.pump();

    await tester.tap(hitTarget);
    await tester.pump();

    expect(sheetCalls, 2);
  });

  testWidgets('schedule manager sheet ignores duplicate taps while open', (
    tester,
  ) async {
    final sheetCompleter = Completer<void>();
    final schedule = buildTestSchedule();
    var sheetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          debugScheduleOverride: schedule,
          showBottomSheet: <T>({
            required BuildContext context,
            required WidgetBuilder builder,
            bool expand = false,
            Color? backgroundColor,
            Color? barrierColor,
            Color? transitionBackgroundColor,
          }) {
            sheetCalls++;
            return sheetCompleter.future.then<T?>((_) => null);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final manageButton = find.bySemanticsLabel('管理课表');
    await tester.tap(manageButton);
    await tester.pump();
    await tester.tap(manageButton);
    await tester.pump();

    expect(sheetCalls, 1);

    sheetCompleter.complete();
    await tester.pump();

    await tester.tap(manageButton);
    await tester.pump();

    expect(sheetCalls, 2);
  });

  testWidgets(
    'clipboard import ignores duplicate taps while reading clipboard',
    (tester) async {
      final clipboardCompleter = Completer<String?>();
      final importSchedule = buildTestSchedule();
      final shareCode = buildCourseScheduleShareCode(importSchedule);
      var archive = const CourseScheduleArchive.empty();
      var clipboardReads = 0;
      final importedCodes = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: CourseTableView(
            loadScheduleArchive: () async => archive,
            readClipboardText: () {
              clipboardReads++;
              return clipboardCompleter.future;
            },
            importShareCode: (rawCode) async {
              importedCodes.add(rawCode);
              archive = archive.copyWith(
                activeScheduleId: importSchedule.id,
                schedules: [importSchedule],
              );
              return importSchedule;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('登录后抓取或导入课表'), findsOneWidget);

      final primaryClipboardButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '从剪贴板导入'),
      );
      final secondaryClipboardButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '剪贴板导入'),
      );

      primaryClipboardButton.onPressed?.call();
      secondaryClipboardButton.onPressed?.call();
      await tester.pump();

      expect(clipboardReads, 1);

      clipboardCompleter.complete(shareCode);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(importedCodes, [shareCode]);
      expect(
        find.byKey(const ValueKey('course-table-week-pager')),
        findsOneWidget,
      );
    },
  );

  testWidgets('clipboard import recovers after clipboard read throws', (
    tester,
  ) async {
    var clipboardReads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          loadScheduleArchive: () async => const CourseScheduleArchive.empty(),
          readClipboardText: () async {
            clipboardReads++;
            throw Exception('clipboard unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('登录后抓取或导入课表'), findsOneWidget);

    var clipboardButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '从剪贴板导入'),
    );
    clipboardButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(clipboardReads, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('读取剪贴板失败，请稍后重试'), findsOneWidget);

    clipboardButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '从剪贴板导入'),
    );
    clipboardButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(clipboardReads, 2);
  });

  testWidgets('clipboard import recovers after share code importer throws', (
    tester,
  ) async {
    var importCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          loadScheduleArchive: () async => const CourseScheduleArchive.empty(),
          readClipboardText: () async => 'SUPERHUT1:bad-share-code',
          importShareCode: (_) async {
            importCalls++;
            throw Exception('share code import unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('登录后抓取或导入课表'), findsOneWidget);

    var clipboardButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '从剪贴板导入'),
    );
    clipboardButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(importCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('导入课表失败，请稍后重试'), findsOneWidget);
    expect(find.textContaining('share code import unavailable'), findsNothing);

    clipboardButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '从剪贴板导入'),
    );
    clipboardButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(importCalls, 2);
  });

  testWidgets('clipboard import hides raw share code parse errors', (
    tester,
  ) async {
    const rawError =
        'raw secret token https://cas.example.test/path?ticket=ST-sensitive';
    var importCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          loadScheduleArchive: () async => const CourseScheduleArchive.empty(),
          readClipboardText: () async => 'SUPERHUT1:bad-share-code',
          importShareCode: (_) async {
            importCalls++;
            throw const FormatException(rawError);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    var clipboardButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '从剪贴板导入'),
    );
    clipboardButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(importCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('导入分享课表'), findsOneWidget);
    expect(
      find.text(courseScheduleShareCodeParseFailureMessage),
      findsOneWidget,
    );
    expect(find.textContaining('raw secret token'), findsNothing);
    expect(find.textContaining('https://cas.example.test'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    clipboardButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '从剪贴板导入'),
    );
    clipboardButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(importCalls, 2);
  });

  testWidgets(
    'primary login action ignores duplicate taps while login is pending',
    (tester) async {
      final loginCompleter = Completer<void>();
      var loginCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CourseTableView(
            loadScheduleArchive:
                () async => const CourseScheduleArchive.empty(),
            openCampusLogin: (_) {
              loginCalls++;
              return loginCompleter.future;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('登录后抓取或导入课表'), findsOneWidget);

      final loginButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '登录后抓取课表'),
      );

      loginButton.onPressed?.call();
      loginButton.onPressed?.call();
      await tester.pump();

      expect(loginCalls, 1);

      loginCompleter.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final nextLoginButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '登录后抓取课表'),
      );
      nextLoginButton.onPressed?.call();
      await tester.pump();

      expect(loginCalls, 2);
    },
  );

  testWidgets('primary login action recovers after opener throws', (
    tester,
  ) async {
    var loginCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          loadScheduleArchive: () async => const CourseScheduleArchive.empty(),
          openCampusLogin: (_) async {
            loginCalls++;
            throw Exception('login unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('登录后抓取或导入课表'), findsOneWidget);

    var loginButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '登录后抓取课表'),
    );
    loginButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(loginCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开登录页面，请稍后重试'), findsOneWidget);

    loginButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '登录后抓取课表'),
    );
    loginButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(loginCalls, 2);
  });

  testWidgets('file import ignores duplicate taps while picking file', (
    tester,
  ) async {
    final fileCompleter = Completer<String?>();
    final importSchedule = buildTestSchedule();
    final exportJson = buildCourseScheduleExportJsonString(importSchedule);
    var archive = const CourseScheduleArchive.empty();
    var filePicks = 0;
    final importedContents = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          loadScheduleArchive: () async => archive,
          pickImportFileContent: () {
            filePicks++;
            return fileCompleter.future;
          },
          importFileContent: (rawContent) async {
            importedContents.add(rawContent);
            archive = archive.copyWith(
              activeScheduleId: importSchedule.id,
              schedules: [importSchedule],
            );
            return importSchedule;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final fileButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '导入文件'),
    );

    fileButton.onPressed?.call();
    fileButton.onPressed?.call();
    await tester.pump();

    expect(filePicks, 1);

    fileCompleter.complete(exportJson);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(importedContents, [exportJson]);
    expect(
      find.byKey(const ValueKey('course-table-week-pager')),
      findsOneWidget,
    );
  });

  testWidgets('file import recovers after file content importer throws', (
    tester,
  ) async {
    var filePicks = 0;
    var importCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          loadScheduleArchive: () async => const CourseScheduleArchive.empty(),
          pickImportFileContent: () async {
            filePicks++;
            return '{"schemaVersion":1}';
          },
          importFileContent: (_) async {
            importCalls++;
            throw Exception('file import unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    var fileButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '导入文件'),
    );
    fileButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(filePicks, 1);
    expect(importCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('导入文件失败，请稍后重试'), findsOneWidget);
    expect(find.textContaining('file import unavailable'), findsNothing);

    fileButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '导入文件'),
    );
    fileButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(filePicks, 2);
    expect(importCalls, 2);
  });

  testWidgets('file import hides raw parse errors', (tester) async {
    const rawError = 'raw path /tmp/secret.json token=sensitive-ticket';
    var filePicks = 0;
    var importCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          loadScheduleArchive: () async => const CourseScheduleArchive.empty(),
          pickImportFileContent: () async {
            filePicks++;
            return '{"schemaVersion":1}';
          },
          importFileContent: (_) async {
            importCalls++;
            throw const FormatException(rawError);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    var fileButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '导入文件'),
    );
    fileButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(filePicks, 1);
    expect(importCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text(courseScheduleFileParseFailureMessage), findsOneWidget);
    expect(find.textContaining('/tmp/secret.json'), findsNothing);
    expect(find.textContaining('sensitive-ticket'), findsNothing);

    fileButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '导入文件'),
    );
    fileButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(filePicks, 2);
    expect(importCalls, 2);
  });

  testWidgets('qr import ignores duplicate taps while scanner is open', (
    tester,
  ) async {
    final scanCompleter = Completer<String?>();
    final importSchedule = buildTestSchedule();
    final shareCode = buildCourseScheduleShareCode(importSchedule);
    var archive = const CourseScheduleArchive.empty();
    var scanCalls = 0;
    final importedCodes = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          loadScheduleArchive: () async => archive,
          scanQrCode: (_) {
            scanCalls++;
            return scanCompleter.future;
          },
          importShareCode: (rawCode) async {
            importedCodes.add(rawCode);
            archive = archive.copyWith(
              activeScheduleId: importSchedule.id,
              schedules: [importSchedule],
            );
            return importSchedule;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final scanButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '扫码导入'),
    );

    scanButton.onPressed?.call();
    scanButton.onPressed?.call();
    await tester.pump();

    expect(scanCalls, 1);

    scanCompleter.complete(shareCode);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(importedCodes, [shareCode]);
    expect(
      find.byKey(const ValueKey('course-table-week-pager')),
      findsOneWidget,
    );
  });

  testWidgets('qr import recovers after scanner throws', (tester) async {
    var scanCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          loadScheduleArchive: () async => const CourseScheduleArchive.empty(),
          scanQrCode: (_) async {
            scanCalls++;
            throw Exception('scanner unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    var scanButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '扫码导入'),
    );
    scanButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(scanCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('扫码导入失败，请稍后重试'), findsOneWidget);
    expect(find.textContaining('scanner unavailable'), findsNothing);

    scanButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '扫码导入'),
    );
    scanButton.onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(scanCalls, 2);
  });

  testWidgets('copy share code ignores duplicate actions while writing', (
    tester,
  ) async {
    final writeCompleter = Completer<void>();
    final schedule = buildTestSchedule();
    final copiedTexts = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          debugScheduleOverride: schedule,
          writeClipboardText: (text) {
            copiedTexts.add(text);
            return writeCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    Future<void> copyShareCodeFromManager() async {
      await tester.tap(find.bySemanticsLabel('管理课表'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '复制分享码'));
      await tester.pumpAndSettle();
    }

    await copyShareCodeFromManager();
    expect(copiedTexts.length, 1);

    await copyShareCodeFromManager();
    expect(copiedTexts.length, 1);

    writeCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('分享码已复制'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '关闭'));
    await tester.pumpAndSettle();
  });

  testWidgets('copy share code recovers after clipboard write throws', (
    tester,
  ) async {
    final schedule = buildTestSchedule();
    var writeCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          debugScheduleOverride: schedule,
          writeClipboardText: (_) async {
            writeCalls++;
            throw Exception('clipboard write unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    Future<void> copyShareCodeFromManager() async {
      await tester.tap(find.bySemanticsLabel('管理课表'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '复制分享码'));
      await tester.pump(const Duration(milliseconds: 600));
    }

    await copyShareCodeFromManager();

    expect(writeCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('复制分享码失败，请稍后重试'), findsOneWidget);

    await copyShareCodeFromManager();

    expect(writeCalls, 2);
  });

  testWidgets(
    'qr dialog copy share code recovers after clipboard write throws',
    (tester) async {
      final schedule = buildTestSchedule();
      var writeCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CourseTableView(
            debugScheduleOverride: schedule,
            writeClipboardText: (_) async {
              writeCalls++;
              throw Exception('qr clipboard write unavailable');
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.bySemanticsLabel('管理课表'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '显示二维码'));
      await tester.pumpAndSettle();

      expect(find.text('课表分享二维码'), findsOneWidget);

      var copyButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '复制分享码'),
      );
      copyButton.onPressed?.call();
      await tester.pump();
      await tester.pump();

      expect(writeCalls, 1);
      expect(tester.takeException(), isNull);
      expect(find.text('课表分享二维码'), findsOneWidget);
      expect(find.text('复制分享码失败，请稍后重试'), findsOneWidget);

      copyButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '复制分享码'),
      );
      copyButton.onPressed?.call();
      await tester.pump();
      await tester.pump();

      expect(writeCalls, 2);
    },
  );

  testWidgets('schedule export file action recovers after saver throws', (
    tester,
  ) async {
    final schedule = buildTestSchedule();
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          debugScheduleOverride: schedule,
          saveScheduleFile: ({required fileName, required bytes}) async {
            saveCalls++;
            expect(fileName, contains('测试课表'));
            expect(bytes, isNotEmpty);
            throw Exception('file export unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    Future<void> exportFileFromManager() async {
      await tester.tap(find.bySemanticsLabel('管理课表'));
      await tester.pumpAndSettle();
      final exportButton = find.widgetWithText(OutlinedButton, '导出文件');
      await tester.ensureVisible(exportButton);
      await tester.pumpAndSettle();
      await tester.tap(exportButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await exportFileFromManager();

    expect(saveCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('导出文件失败，请稍后重试'), findsOneWidget);
    expect(find.textContaining('file export unavailable'), findsNothing);

    await exportFileFromManager();

    expect(saveCalls, 2);
  });

  testWidgets('schedule share file action recovers after sharer throws', (
    tester,
  ) async {
    final schedule = buildTestSchedule();
    var shareCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          debugScheduleOverride: schedule,
          shareScheduleFile: ({
            required schedule,
            required sharePositionOrigin,
          }) async {
            shareCalls++;
            expect(schedule.name, '测试课表');
            expect(sharePositionOrigin, isA<Rect>());
            throw Exception('file share unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    Future<void> shareFileFromManager() async {
      await tester.tap(find.bySemanticsLabel('管理课表'));
      await tester.pumpAndSettle();
      final shareButton = find.widgetWithText(OutlinedButton, '分享文件');
      await tester.ensureVisible(shareButton);
      await tester.pumpAndSettle();
      await tester.tap(shareButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await shareFileFromManager();

    expect(shareCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('分享文件失败，请稍后重试'), findsOneWidget);
    expect(find.textContaining('file share unavailable'), findsNothing);

    await shareFileFromManager();

    expect(shareCalls, 2);
  });

  testWidgets('shows both delete actions for editable active schedule', (
    tester,
  ) async {
    final schedule = buildTestSchedule();
    final monday = currentMonday();
    final course = schedule.courseData[dateKey(monday)]!.single;

    await tester.pumpWidget(
      MaterialApp(home: CourseTableView(debugScheduleOverride: schedule)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final hitTarget = find.byKey(
      ValueKey<String>('course-card-hit-${courseCardHitKey(monday, course)}'),
    );

    await tester.tap(hitTarget);
    await tester.pumpAndSettle();

    expect(find.text('删除当前课程'), findsOneWidget);
    expect(find.text('删除整学期该课程'), findsOneWidget);
  });

  testWidgets('hides delete actions for read-only active schedule', (
    tester,
  ) async {
    final schedule = buildTestSchedule(isReadOnly: true);
    final monday = currentMonday();
    final course = schedule.courseData[dateKey(monday)]!.single;

    await tester.pumpWidget(
      MaterialApp(home: CourseTableView(debugScheduleOverride: schedule)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final hitTarget = find.byKey(
      ValueKey<String>('course-card-hit-${courseCardHitKey(monday, course)}'),
    );

    await tester.tap(hitTarget);
    await tester.pumpAndSettle();

    expect(find.text('删除当前课程'), findsNothing);
    expect(find.text('删除整学期该课程'), findsNothing);
  });

  testWidgets('course delete action recovers after deleter throws', (
    tester,
  ) async {
    final schedule = buildTestSchedule();
    final monday = currentMonday();
    final course = schedule.courseData[dateKey(monday)]!.single;
    var deleteCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          debugScheduleOverride: schedule,
          deleteCourse: ({
            required dateKey,
            required targetCourse,
            required scope,
          }) async {
            deleteCalls++;
            throw Exception('course delete unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    Future<void> deleteCurrentCourse() async {
      final hitTarget = find.byKey(
        ValueKey<String>('course-card-hit-${courseCardHitKey(monday, course)}'),
      );
      await tester.tap(hitTarget);
      await tester.pumpAndSettle();

      final deleteAction = find.text('删除当前课程');
      await tester.ensureVisible(deleteAction);
      await tester.pumpAndSettle();
      await tester.tap(deleteAction);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await deleteCurrentCourse();

    expect(deleteCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('删除课程失败，请稍后重试'), findsOneWidget);

    await deleteCurrentCourse();

    expect(deleteCalls, 2);
  });

  testWidgets('schedule delete action recovers after deleter throws', (
    tester,
  ) async {
    final schedule = buildTestSchedule();
    var deleteCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          debugScheduleOverride: schedule,
          deleteSchedule: (_) async {
            deleteCalls++;
            throw Exception('schedule delete unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    Future<void> deleteScheduleFromManager() async {
      await tester.tap(find.bySemanticsLabel('管理课表'));
      await tester.pumpAndSettle();
      final scheduleMenu = find.byTooltip('课表操作');
      await tester.ensureVisible(scheduleMenu);
      await tester.pumpAndSettle();
      await tester.tap(scheduleMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await deleteScheduleFromManager();

    expect(deleteCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('删除课表失败，请稍后重试'), findsOneWidget);

    await deleteScheduleFromManager();

    expect(deleteCalls, 2);
  });

  testWidgets('schedule switch action recovers after switcher throws', (
    tester,
  ) async {
    final currentSchedule = buildTestSchedule();
    final targetSchedule = buildTestSchedule().copyWith(
      id: 'target-schedule',
      name: '备用课表',
    );
    var switchCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          loadScheduleArchive:
              () async => CourseScheduleArchive(
                schemaVersion: 1,
                activeScheduleId: currentSchedule.id,
                schedules: [currentSchedule, targetSchedule],
              ),
          switchSchedule: (_) async {
            switchCalls++;
            throw Exception('schedule switch unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    Future<void> switchToTargetSchedule() async {
      await tester.tap(find.bySemanticsLabel('管理课表'));
      await tester.pumpAndSettle();
      final targetTile = find.text('备用课表');
      await tester.ensureVisible(targetTile);
      await tester.pumpAndSettle();
      await tester.tap(targetTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await switchToTargetSchedule();

    expect(switchCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('切换课表失败，请稍后重试'), findsOneWidget);

    await switchToTargetSchedule();

    expect(switchCalls, 2);
  });

  testWidgets('schedule rename action recovers after renamer throws', (
    tester,
  ) async {
    final schedule = buildTestSchedule();
    var renameCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          debugScheduleOverride: schedule,
          renameSchedule: (_, _) async {
            renameCalls++;
            throw Exception('schedule rename unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    Future<void> renameScheduleFromManager(String name) async {
      await tester.tap(find.bySemanticsLabel('管理课表'));
      await tester.pumpAndSettle();
      final scheduleMenu = find.byTooltip('课表操作');
      await tester.ensureVisible(scheduleMenu);
      await tester.pumpAndSettle();
      await tester.tap(scheduleMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('重命名'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), name);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await renameScheduleFromManager('新课表');

    expect(renameCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('重命名课表失败，请稍后重试'), findsOneWidget);

    await renameScheduleFromManager('另一个课表');

    expect(renameCalls, 2);
  });

  testWidgets('experiment students action recovers after loader throws', (
    tester,
  ) async {
    final monday = currentMonday();
    final experimentCourse = Course(
      name: '实验课程',
      teacherName: '实验老师',
      weekDuration: '1-3',
      location: '实验楼101',
      startSection: 1,
      duration: 2,
      isExp: true,
      pcid: 'pcid-1',
    );
    final schedule = buildTestSchedule().copyWith(
      courseData: {
        dateKey(monday): [experimentCourse],
      },
    );
    var loadCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          debugScheduleOverride: schedule,
          loadExperimentStudents: (_) async {
            loadCalls++;
            throw Exception('experiment students unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    Future<void> openStudents() async {
      final hitTarget = find.byKey(
        ValueKey<String>(
          'course-card-hit-${courseCardHitKey(monday, experimentCourse)}',
        ),
      );
      await tester.tap(hitTarget);
      await tester.pumpAndSettle();
      final viewStudentsAction = find.text('查看实验人员名单');
      await tester.ensureVisible(viewStudentsAction);
      await tester.pumpAndSettle();
      await tester.tap(viewStudentsAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await openStudents();

    expect(loadCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('获取人员名单失败，请稍后重试'), findsOneWidget);

    await openStudents();

    expect(loadCalls, 2);
  });

  testWidgets('switches toolbar to lite style during tab transition', (
    tester,
  ) async {
    final schedule = buildTestSchedule();
    final transitionLiteMode = ValueNotifier<bool>(false);
    addTearDown(transitionLiteMode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: CourseTableView(
          transitionLiteModeListenable: transitionLiteMode,
          debugScheduleOverride: schedule,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byKey(const ValueKey('course-table-toolbar-full')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('course-table-toolbar-lite')),
      findsNothing,
    );

    transitionLiteMode.value = true;
    await tester.pump();

    expect(
      find.byKey(const ValueKey('course-table-toolbar-lite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('course-table-toolbar-full')),
      findsNothing,
    );

    transitionLiteMode.value = false;
    await tester.pump();

    expect(
      find.byKey(const ValueKey('course-table-toolbar-lite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('course-table-toolbar-full')),
      findsNothing,
    );

    await tester.pump();

    expect(
      find.byKey(const ValueKey('course-table-toolbar-lite')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('course-table-toolbar-full')),
      findsOneWidget,
    );
  });

  testWidgets('keeps the pager under the finger during a slow drag', (
    tester,
  ) async {
    final schedule = buildTestSchedule();
    await tester.pumpWidget(
      MaterialApp(home: CourseTableView(debugScheduleOverride: schedule)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final pagerFinder = find.byKey(const ValueKey('course-table-week-pager'));
    final pagerSize = tester.getSize(pagerFinder);
    final gesture = await tester.startGesture(tester.getCenter(pagerFinder));

    await gesture.moveBy(Offset(-pagerSize.width * 0.65, 0));
    await tester.pump();

    final pager = tester.widget<PageView>(pagerFinder);
    final page = pager.controller!.page ?? 0;
    expect(page, greaterThan(0.5));
    expect(page, lessThan(0.95));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('第2周'), findsOneWidget);
  });

  testWidgets(
    'uses immediate drag start without implicit adjacent-week prebuild',
    (tester) async {
      final schedule = buildTestSchedule();
      await tester.pumpWidget(
        MaterialApp(home: CourseTableView(debugScheduleOverride: schedule)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final pager = tester.widget<PageView>(
        find.byKey(const ValueKey('course-table-week-pager')),
      );

      expect(pager.dragStartBehavior, DragStartBehavior.down);
      expect(pager.allowImplicitScrolling, isFalse);
      expect(pager.physics?.minFlingDistance, 8.0);
      expect(pager.physics?.minFlingVelocity, 20.0);
      expect(pager.physics?.dragStartDistanceMotionThreshold, 1.5);
    },
  );

  testWidgets('turns page on a short but fast fling', (tester) async {
    final schedule = buildTestSchedule();
    await tester.pumpWidget(
      MaterialApp(home: CourseTableView(debugScheduleOverride: schedule)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final pagerFinder = find.byKey(const ValueKey('course-table-week-pager'));
    final pagerSize = tester.getSize(pagerFinder);

    await tester.fling(pagerFinder, Offset(-pagerSize.width * 0.22, 0), 2600);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('第2周'), findsOneWidget);
  });

  testWidgets(
    'recognizes a lower-speed fling once drag has cleared touch slop',
    (tester) async {
      final schedule = buildTestSchedule();
      await tester.pumpWidget(
        MaterialApp(home: CourseTableView(debugScheduleOverride: schedule)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final pagerFinder = find.byKey(const ValueKey('course-table-week-pager'));
      final pager = tester.widget<PageView>(pagerFinder);
      final recognizer =
          HorizontalDragGestureRecognizer()
            ..minFlingDistance = pager.physics?.minFlingDistance
            ..minFlingVelocity = pager.physics?.minFlingVelocity;

      try {
        expect(
          recognizer.isFlingGesture(
            const VelocityEstimate(
              pixelsPerSecond: Offset(-24, 0),
              offset: Offset(-24, 0),
              duration: Duration(milliseconds: 20),
              confidence: 1.0,
            ),
            PointerDeviceKind.touch,
          ),
          isTrue,
        );
      } finally {
        recognizer.dispose();
      }
    },
  );
}
