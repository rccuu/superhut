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

  SavedCourseSchedule buildTestSchedule() {
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
      isReadOnly: false,
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
          if (call.method == 'refreshCourseTableWidget') {
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
