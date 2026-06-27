import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/Commentary/commentary_batch_executor.dart';
import 'package:superhut/pages/Commentary/commentary_course_list_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('duplicate course taps open a single question route', (
    tester,
  ) async {
    var buildQuestionPageCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryCourseListPage(
          batchId: 'batch-1',
          pj01id: 'pj01-1',
          pj05id: 'pj05-1',
          loadCommentaryItems:
              (pj01id, batchId, pj05id) async => [
                {
                  'isSubmitCode': '0',
                  'courseName': '高等数学',
                  'courseNumber': 'MATH001',
                  'teacherName': '张老师',
                  'evaluationCategoriesId': 'category-1',
                  'teacherId': 'teacher-1',
                  'noticeId': 'notice-1',
                },
              ],
          buildQuestionPage: (commentary) {
            buildQuestionPageCalls++;
            return Scaffold(
              appBar: AppBar(title: const Text('评教题目')),
              body: Text('course ${commentary['courseNumber']}'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final courseTile = find.text('高等数学');
    final courseTileCenter = tester.getCenter(courseTile);
    await tester.tapAt(courseTileCenter);
    await tester.tapAt(courseTileCenter);
    await tester.pumpAndSettle();

    expect(buildQuestionPageCalls, 1);
    expect(find.text('评教题目'), findsOneWidget);
    expect(find.text('course MATH001'), findsOneWidget);

    Navigator.of(tester.element(find.text('评教题目'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(courseTile);
    await tester.pumpAndSettle();

    expect(buildQuestionPageCalls, 2);
  });

  testWidgets('course tap recovers after route push throws', (tester) async {
    var pushCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryCourseListPage(
          batchId: 'batch-1',
          pj01id: 'pj01-1',
          pj05id: 'pj05-1',
          loadCommentaryItems:
              (pj01id, batchId, pj05id) async => [
                {
                  'isSubmitCode': '0',
                  'courseName': '高等数学',
                  'courseNumber': 'MATH001',
                  'teacherName': '张老师',
                  'evaluationCategoriesId': 'category-1',
                  'teacherId': 'teacher-1',
                  'noticeId': 'notice-1',
                },
              ],
          buildQuestionPage: (_) => const Scaffold(body: Text('评教题目')),
          pushRoute: <T>(context, route) async {
            pushCalls++;
            throw Exception('navigator unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final courseTile = find.text('高等数学');
    await tester.tapAt(tester.getCenter(courseTile));
    await tester.pump();
    await tester.pump();

    expect(pushCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开评教题目，请稍后重试'), findsOneWidget);

    await tester.tapAt(tester.getCenter(courseTile));
    await tester.pump();
    await tester.pump();

    expect(pushCalls, 2);
  });

  testWidgets('submitted question route refreshes course list', (tester) async {
    var loadCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryCourseListPage(
          batchId: 'batch-1',
          pj01id: 'pj01-1',
          pj05id: 'pj05-1',
          loadCommentaryItems: (pj01id, batchId, pj05id) async {
            loadCalls++;
            return [
              {
                'isSubmitCode': loadCalls == 1 ? '0' : '1',
                'courseName': '高等数学',
                'courseNumber': 'MATH001',
                'teacherName': '张老师',
                'evaluationCategoriesId': 'category-1',
                'teacherId': 'teacher-1',
                'noticeId': 'notice-1',
              },
            ];
          },
          buildQuestionPage: (_) => const Scaffold(body: Text('评教题目')),
          pushRoute: <T>(context, route) async => true as T,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loadCalls, 1);
    expect(find.text('未评教'), findsOneWidget);
    expect(find.text('已评教'), findsNothing);

    await tester.tapAt(tester.getCenter(find.text('高等数学')));
    await tester.pumpAndSettle();

    expect(loadCalls, 2);
    expect(find.text('已评教'), findsOneWidget);
    expect(find.text('未评教'), findsNothing);
  });

  testWidgets(
    'renders course summary and refreshes after list-level batch evaluation',
    (tester) async {
      var loadCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CommentaryCourseListPage(
            batchId: 'batch-1',
            pj01id: 'pj01-1',
            pj05id: 'pj05-1',
            loadCommentaryItems: (pj01id, batchId, pj05id) async {
              loadCalls++;
              return [
                {
                  'isSubmitCode': loadCalls == 1 ? '0' : '1',
                  'courseName': '高等数学',
                  'courseNumber': 'MATH001',
                  'teacherName': '张老师',
                  'evaluationCategoriesId': 'category-1',
                  'teacherId': 'teacher-1',
                  'noticeId': 'notice-1',
                },
              ];
            },
            runBatchEvaluation: ({
              required batchId,
              required commentaryItems,
              onProgress,
            }) async {
              onProgress?.call(
                const CommentaryBatchProgress(
                  completedCount: 1,
                  totalCount: 1,
                  currentCourseName: '高等数学',
                ),
              );
              return const CommentaryBatchExecutionResult(
                totalCount: 1,
                successCount: 1,
                failures: <CommentaryBatchFailure>[],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 门未评'), findsOneWidget);
      expect(find.text('1 门总计'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '一键评完本分类'));
      await tester.pumpAndSettle();

      expect(loadCalls, 2);
      expect(find.text('0 门未评'), findsOneWidget);
      expect(find.text('已评教'), findsOneWidget);
    },
  );

  testWidgets(
    'ignores duplicate list-level batch evaluation taps while request is in flight',
    (tester) async {
      final completer = Completer<CommentaryBatchExecutionResult>();
      var runCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CommentaryCourseListPage(
            batchId: 'batch-1',
            pj01id: 'pj01-1',
            pj05id: 'pj05-1',
            loadCommentaryItems:
                (pj01id, batchId, pj05id) async => [
                  {
                    'isSubmitCode': '0',
                    'courseName': '高等数学',
                    'courseNumber': 'MATH001',
                    'teacherName': '张老师',
                    'evaluationCategoriesId': 'category-1',
                    'teacherId': 'teacher-1',
                    'noticeId': 'notice-1',
                  },
                ],
            runBatchEvaluation: ({
              required batchId,
              required commentaryItems,
              onProgress,
            }) {
              runCalls++;
              return completer.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final batchButton = find.widgetWithText(FilledButton, '一键评完本分类');
      await tester.tap(batchButton);
      await tester.tap(batchButton);
      await tester.pump();

      expect(runCalls, 1);

      completer.complete(
        const CommentaryBatchExecutionResult(
          totalCount: 1,
          successCount: 1,
          failures: <CommentaryBatchFailure>[],
        ),
      );
    },
  );
}
