import 'package:flutter/material.dart';
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

  setUpAll(() {
    SecureStorageMock.install();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<String> captureClipboardWrites() {
    final written = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final arguments = call.arguments as Map<Object?, Object?>;
        written.add(arguments['text'] as String);
      }
      return null;
    });
    return written;
  }

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

  SavedCourseSchedule buildSchedule(Course course) {
    final monday = currentMonday();
    return SavedCourseSchedule(
      id: 'schedule-metadata',
      name: '测试课表',
      ownerName: '测试用户',
      termLabel: '2026-2027-1',
      semesterId: '2026-2027-1',
      firstDay: dateKey(monday),
      maxWeek: 3,
      sourceType: CourseScheduleSourceType.selfSync,
      isReadOnly: false,
      createdAt: '2026-10-19T08:00:00.000',
      updatedAt: '2026-10-19T08:00:00.000',
      courseData: {
        dateKey(monday): [course],
      },
    );
  }

  testWidgets('course detail copy text includes class and course metadata', (
    tester,
  ) async {
    final copiedTexts = captureClipboardWrites();

    final course = Course(
      name: '工程造价与管理',
      teacherName: '曾丹',
      weekDuration: '7-10,13-16',
      location: '公共423',
      startSection: 1,
      duration: 2,
      className: '智能建造2304班',
      peopleCount: '30',
      creditHours: '16',
      assessmentType: '考试',
    );
    final schedule = buildSchedule(course);
    final monday = currentMonday();

    await tester.pumpWidget(
      MaterialApp(home: CourseTableView(debugScheduleOverride: schedule)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final hitTarget = find.byKey(
      ValueKey<String>('course-card-hit-${courseCardHitKey(monday, course)}'),
    );
    expect(hitTarget, findsOneWidget);

    await tester.tap(hitTarget);
    await tester.pumpAndSettle();

    final copyAction = find.text('复制课程信息为文本');
    expect(copyAction, findsOneWidget);
    await tester.ensureVisible(copyAction);
    await tester.tap(copyAction);
    await tester.pump();
    await tester.pump();

    expect(copiedTexts, hasLength(1));
    final copied = copiedTexts.single;
    expect(copied, contains('班级：智能建造2304班'));
    expect(copied, contains('上课人数：30 人'));
    expect(copied, contains('学时：16 学时'));
    expect(copied, contains('考核方式：考试'));
  });

  testWidgets('course detail copy text falls back for missing metadata', (
    tester,
  ) async {
    final copiedTexts = captureClipboardWrites();

    final course = Course(
      name: '高等数学',
      teacherName: '李老师',
      weekDuration: '1-16',
      location: '公共101',
      startSection: 1,
      duration: 2,
    );
    final schedule = buildSchedule(course);
    final monday = currentMonday();

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

    final copyAction = find.text('复制课程信息为文本');
    await tester.ensureVisible(copyAction);
    await tester.tap(copyAction);
    await tester.pump();
    await tester.pump();

    expect(copiedTexts, hasLength(1));
    final copied = copiedTexts.single;
    expect(copied, contains('班级：暂无班级信息'));
    expect(copied, contains('上课人数：暂无上课人数信息'));
    expect(copied, contains('学时：暂无学时信息'));
    expect(copied, contains('考核方式：暂无考核方式信息'));
  });
}
