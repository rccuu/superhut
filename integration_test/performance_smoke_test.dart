import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/coursetable/view.dart';
import 'package:superhut/main.dart';
import 'package:superhut/utils/course/coursemain.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home tab and course table interaction performance smoke', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'isFirstOpen': false,
      'hasSeenTrustNotice': true,
      'enableBillWarning': false,
      'showExperimentCourses': true,
    });

    await tester.pumpWidget(
      const MyApp(
        checkUpdatesOnStartup: false,
        resolveCourseStateOnStartup: false,
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const ValueKey('home-tab-stage')));
    await tester.pumpAndSettle();

    await binding.watchPerformance(() async {
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('home-hit-zone-我的')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('home-hit-zone-课表')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('home-hit-zone-功能')));
        await tester.pumpAndSettle();
      }
    }, reportKey: 'home_tab_switch_performance');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CourseTableView(debugScheduleOverride: _buildSmokeSchedule()),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('course-table-week-pager')),
    );
    await tester.pumpAndSettle();

    await binding.watchPerformance(() async {
      for (var i = 0; i < 3; i++) {
        await tester.fling(
          find.byKey(const ValueKey('course-table-week-pager')),
          const Offset(-420, 0),
          1200,
        );
        await tester.pumpAndSettle();
        await tester.fling(
          find.byKey(const ValueKey('course-table-week-pager')),
          const Offset(420, 0),
          1200,
        );
        await tester.pumpAndSettle();
      }
    }, reportKey: 'course_table_week_swipe_performance');
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 40,
}) async {
  for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

SavedCourseSchedule _buildSmokeSchedule() {
  final monday = _currentMonday();
  final now = DateTime.now().toIso8601String();
  final courseData = <String, List<Course>>{};

  for (var week = 0; week < 6; week++) {
    final weekStart = monday.add(Duration(days: week * 7));
    courseData[_dateKey(weekStart)] = [
      Course(
        name: '性能测试课程${week + 1}',
        teacherName: '测试教师',
        weekDuration: '${week + 1}',
        location: '测试楼101',
        startSection: 1,
        duration: 2,
      ),
      Course(
        name: '交互样本${week + 1}',
        teacherName: '测试教师',
        weekDuration: '${week + 1}',
        location: '测试楼202',
        startSection: 5,
        duration: 2,
      ),
    ];
  }

  return SavedCourseSchedule(
    id: 'performance-smoke-schedule',
    name: '性能冒烟课表',
    ownerName: '性能测试',
    termLabel: '性能测试学期',
    semesterId: 'performance-smoke',
    firstDay: _dateKey(monday),
    maxWeek: 6,
    sourceType: CourseScheduleSourceType.manual,
    isReadOnly: false,
    createdAt: now,
    updatedAt: now,
    courseData: courseData,
  );
}

DateTime _currentMonday() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final daysToSubtract = now.weekday == DateTime.sunday ? 6 : now.weekday - 1;
  return today.subtract(Duration(days: daysToSubtract));
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
