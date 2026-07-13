import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/coursetable/widgets/course_semester_picker_sheet.dart';
import 'package:superhut/utils/course/get_course.dart';

void main() {
  testWidgets('selects a semester and confirms explicitly', (tester) async {
    final result = <CourseSemester?>[];
    final semesters = const [
      CourseSemester(
        id: '2025-2026-3',
        label: '2025-2026 · 暑期',
        isCurrent: false,
      ),
      CourseSemester(
        id: '2025-2026-2',
        label: '2025-2026 · 下学期',
        isCurrent: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => FilledButton(
                  onPressed: () async {
                    result.add(
                      await showModalBottomSheet<CourseSemester>(
                        context: context,
                        builder:
                            (_) =>
                                CourseSemesterPickerSheet(semesters: semesters),
                      ),
                    );
                  },
                  child: const Text('打开'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('抓取教务课表'), findsOneWidget);
    expect(find.text('当前学期'), findsOneWidget);
    expect(find.textContaining('开始同步'), findsOneWidget);

    await tester.tap(find.text('2025-2026 · 暑期'));
    await tester.pump();
    expect(result, isEmpty);

    await tester.tap(find.textContaining('开始同步'));
    await tester.pumpAndSettle();
    expect(result.single?.id, '2025-2026-3');
  });
}
