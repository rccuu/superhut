import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/coursetable/widgets/course_table_widgets.dart';
import 'package:superhut/utils/course/coursemain.dart';

void main() {
  Widget buildSheet(Course course, {VoidCallback? onViewStudents}) {
    return MaterialApp(
      home: Scaffold(
        body: CourseDetailSheet(
          course: course,
          scheduleText: '周一 第1-2节',
          copyText: '测试课程信息',
          onViewStudents: onViewStudents,
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
}
