import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/coursetable/widgets/course_table_widgets.dart';
import 'package:superhut/utils/course/coursemain.dart';

void main() {
  Widget buildSheet(
    Course course, {
    CourseDetailClipboardWriter? writeClipboard,
    VoidCallback? onViewStudents,
    VoidCallback? onDeleteCurrentCourse,
    VoidCallback? onDeleteWholeScheduleCourse,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CourseDetailSheet(
          course: course,
          scheduleText: '周一 第1-2节',
          copyText: '测试课程信息',
          writeClipboard: writeClipboard,
          onViewStudents: onViewStudents,
          onDeleteCurrentCourse: onDeleteCurrentCourse,
          onDeleteWholeScheduleCourse: onDeleteWholeScheduleCourse,
        ),
      ),
    );
  }

  testWidgets('hides experiment student action when pcid is empty', (
    tester,
  ) async {
    final course = Course(
      name: '实验课',
      teacherName: '张老师',
      weekDuration: '1-16',
      location: '实验楼101',
      startSection: 1,
      duration: 2,
      isExp: true,
      pcid: '',
    );

    await tester.pumpWidget(buildSheet(course, onViewStudents: () {}));

    expect(find.text('查看实验人员名单'), findsNothing);
  });

  testWidgets('shows experiment student action when pcid is available', (
    tester,
  ) async {
    final course = Course(
      name: '实验课',
      teacherName: '张老师',
      weekDuration: '1-16',
      location: '实验楼101',
      startSection: 1,
      duration: 2,
      isExp: true,
      pcid: 'pcid-1',
    );

    await tester.pumpWidget(buildSheet(course, onViewStudents: () {}));

    expect(find.text('查看实验人员名单'), findsOneWidget);
  });

  testWidgets('shows both delete actions when delete callbacks are available', (
    tester,
  ) async {
    final course = Course(
      name: '高等数学',
      teacherName: '李老师',
      weekDuration: '1-16',
      location: '公共101',
      startSection: 1,
      duration: 2,
    );

    await tester.pumpWidget(
      buildSheet(
        course,
        onDeleteCurrentCourse: () {},
        onDeleteWholeScheduleCourse: () {},
      ),
    );

    expect(find.text('删除当前课程'), findsOneWidget);
    expect(find.text('删除整学期该课程'), findsOneWidget);
  });

  testWidgets('hides delete actions when delete callbacks are absent', (
    tester,
  ) async {
    final course = Course(
      name: '高等数学',
      teacherName: '李老师',
      weekDuration: '1-16',
      location: '公共101',
      startSection: 1,
      duration: 2,
    );

    await tester.pumpWidget(buildSheet(course));

    expect(find.text('删除当前课程'), findsNothing);
    expect(find.text('删除整学期该课程'), findsNothing);
  });

  testWidgets('copy action ignores duplicate taps while clipboard is writing', (
    tester,
  ) async {
    final writeCompleter = Completer<void>();
    final copiedTexts = <String>[];
    final course = Course(
      name: '高等数学',
      teacherName: '李老师',
      weekDuration: '1-16',
      location: '公共101',
      startSection: 1,
      duration: 2,
    );

    await tester.pumpWidget(
      buildSheet(
        course,
        writeClipboard: (text) {
          copiedTexts.add(text);
          return writeCompleter.future;
        },
      ),
    );

    final copyName = find.text('复制课程名称');
    await tester.ensureVisible(copyName);
    await tester.tap(copyName);
    await tester.pump();
    await tester.tap(copyName);
    await tester.pump();

    expect(copiedTexts, ['高等数学']);

    writeCompleter.complete();
    await tester.pump();
  });

  testWidgets('shows class name row and fallback text', (tester) async {
    final courseWithClass = Course(
      name: '体育4',
      teacherName: '彭老师',
      weekDuration: '3-10,12-15',
      location: '第二田径场-11',
      startSection: 3,
      duration: 2,
      className: '包装工程[2303-2304]班,数媒艺术2302班,3D打印2301班',
    );

    await tester.pumpWidget(buildSheet(courseWithClass));

    expect(find.textContaining('包装工程[2303-2304]班'), findsOneWidget);

    final courseWithoutClass = Course(
      name: '高等数学',
      teacherName: '李老师',
      weekDuration: '1-16',
      location: '公共101',
      startSection: 1,
      duration: 2,
    );

    await tester.pumpWidget(buildSheet(courseWithoutClass));

    expect(find.text('班级'), findsOneWidget);
    expect(find.text('暂无'), findsNWidgets(4));
  });

  testWidgets('every detail row carries a field name label', (tester) async {
    final course = Course(
      name: '工程造价与管理',
      teacherName: '曾丹',
      weekDuration: '7-10,13-16',
      location: '公共423',
      startSection: 5,
      duration: 2,
      className: '智能建造2304班',
      peopleCount: '30',
      creditHours: '16',
      assessmentType: '考试',
    );

    await tester.pumpWidget(buildSheet(course));

    for (final label in [
      '周数',
      '时间',
      '教师',
      '班级',
      '上课人数',
      '学时',
      '考核方式',
      '地点',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '缺少字段名标签 $label');
    }
  });

  testWidgets('shows people count, credit hours and assessment rows', (
    tester,
  ) async {
    final course = Course(
      name: '工程造价与管理',
      teacherName: '曾丹',
      weekDuration: '7-10,13-16',
      location: '公共423',
      startSection: 5,
      duration: 2,
      className: '智能建造2304班',
      peopleCount: '30',
      creditHours: '16',
      assessmentType: '考试',
    );

    await tester.pumpWidget(buildSheet(course));

    expect(find.text('30 人'), findsOneWidget);
    expect(find.text('16 学时'), findsOneWidget);
    expect(find.text('考试'), findsOneWidget);
  });

  testWidgets('non numeric values keep no unit suffix', (tester) async {
    final course = Course(
      name: '高等数学',
      teacherName: '李老师',
      weekDuration: '1-16',
      location: '公共101',
      startSection: 1,
      duration: 2,
      peopleCount: '三十',
      creditHours: '每周2',
    );

    await tester.pumpWidget(buildSheet(course));

    expect(find.text('三十'), findsOneWidget);
    expect(find.text('每周2'), findsOneWidget);
    expect(find.text('三十 人'), findsNothing);
    expect(find.text('每周2 学时'), findsNothing);
  });

  testWidgets('shows fallback text for missing course metadata', (tester) async {
    final course = Course(
      name: '高等数学',
      teacherName: '李老师',
      weekDuration: '1-16',
      location: '公共101',
      startSection: 1,
      duration: 2,
    );

    await tester.pumpWidget(buildSheet(course));

    expect(find.text('上课人数'), findsOneWidget);
    expect(find.text('学时'), findsOneWidget);
    expect(find.text('考核方式'), findsOneWidget);
    expect(find.text('暂无'), findsNWidgets(4));
  });

  testWidgets('detail rows are compact and stay inside the sheet', (
    tester,
  ) async {
    final course = Course(
      name: '工程造价与管理',
      teacherName: '曾丹',
      weekDuration: '7-10,13-16',
      location: '公共423',
      startSection: 5,
      duration: 2,
      className: '智能建造2304班',
      peopleCount: '30',
      creditHours: '16',
      assessmentType: '考试',
    );

    await tester.pumpWidget(buildSheet(course));

    final peopleRow = find.ancestor(
      of: find.text('上课人数'),
      matching: find.byType(Row),
    );
    expect(peopleRow, findsOneWidget);

    final rowHeight = tester.getSize(peopleRow.first).height;
    expect(
      rowHeight,
      lessThanOrEqualTo(52),
      reason: '详情行应收紧到约 48px，避免弹层内滚动过多。',
    );
  });

  testWidgets('long press copies the labelled field value', (tester) async {
    final copiedTexts = <String>[];
    final course = Course(
      name: '工程造价与管理',
      teacherName: '曾丹',
      weekDuration: '7-10,13-16',
      location: '公共423',
      startSection: 5,
      duration: 2,
      className: '智能建造2304班',
      peopleCount: '30',
      creditHours: '16',
      assessmentType: '考试',
    );

    await tester.pumpWidget(
      buildSheet(
        course,
        writeClipboard: (text) async {
          copiedTexts.add(text);
        },
      ),
    );

    await tester.longPress(find.text('30 人'));
    await tester.pump();
    await tester.longPress(find.text('16 学时'));
    await tester.pump();

    expect(copiedTexts, ['上课人数：30 人', '学时：16 学时']);
  });

  testWidgets('copy action recovers after clipboard write throws', (
    tester,
  ) async {
    var writeCalls = 0;
    final course = Course(
      name: '高等数学',
      teacherName: '李老师',
      weekDuration: '1-16',
      location: '公共101',
      startSection: 1,
      duration: 2,
    );

    await tester.pumpWidget(
      buildSheet(
        course,
        writeClipboard: (_) async {
          writeCalls++;
          throw Exception('clipboard unavailable');
        },
      ),
    );

    final copyName = find.text('复制课程名称');
    await tester.ensureVisible(copyName);
    await tester.tap(copyName);
    await tester.pump();
    await tester.pump();

    expect(writeCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('复制课程信息失败，请稍后重试'), findsOneWidget);

    await tester.ensureVisible(copyName);
    await tester.tap(copyName);
    await tester.pump();
    await tester.pump();

    expect(writeCalls, 2);
  });
}
