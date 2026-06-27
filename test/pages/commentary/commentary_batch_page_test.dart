import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/Commentary/commentary_batch_executor.dart';
import 'package:superhut/pages/Commentary/commentary_batch_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'renders overview counts and refreshes after batch evaluation succeeds',
    (tester) async {
      var loadTheoryCalls = 0;
      final batchCompleter = Completer<CommentaryBatchExecutionResult>();

      await tester.pumpWidget(
        MaterialApp(
          home: CommentaryBatchPage(
            loadBatches:
                () async => [
                  {
                    'BATCHID': 'batch-1',
                    'PJ01ID': 'pj01-1',
                    'PJ05ID': 'pj05-1',
                    'EVALUATIONBATCH': '2026 春季评教',
                    'KCLBMC': '理论课',
                    'XQMC': '2025-2026-2',
                  },
                  {
                    'BATCHID': 'batch-2',
                    'PJ01ID': 'pj01-2',
                    'PJ05ID': 'pj05-2',
                    'EVALUATIONBATCH': '2026 春季评教',
                    'KCLBMC': '实验课',
                    'XQMC': '2025-2026-2',
                  },
                ],
            loadCommentaryItems: (pj01id, batchId, pj05id) async {
              if (batchId == 'batch-1') {
                loadTheoryCalls++;
                return [
                  {
                    'isSubmitCode': loadTheoryCalls == 1 ? '0' : '1',
                    'courseName': '高等数学',
                    'courseNumber': 'MATH001',
                    'teacherName': '张老师',
                    'evaluationCategoriesId': 'category-1',
                    'teacherId': 'teacher-1',
                    'noticeId': 'notice-1',
                  },
                ];
              }

              return [
                {
                  'isSubmitCode': '1',
                  'courseName': '大学物理实验',
                  'courseNumber': 'PHYS-LAB',
                  'teacherName': '李老师',
                  'evaluationCategoriesId': 'category-2',
                  'teacherId': 'teacher-2',
                  'noticeId': 'notice-2',
                },
              ];
            },
            runBatchEvaluation: ({
              required batchId,
              required commentaryItems,
              onProgress,
            }) {
              onProgress?.call(
                const CommentaryBatchProgress(
                  completedCount: 1,
                  totalCount: 1,
                  currentCourseName: '高等数学',
                ),
              );
              return batchCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('学生评教'), findsOneWidget);
      expect(find.text('2 个分类'), findsOneWidget);
      expect(find.text('共 1 门未评课程'), findsOneWidget);
      expect(find.text('理论课'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '一键评完').first);
      await tester.pump();

      expect(find.text('1 / 1'), findsOneWidget);

      batchCompleter.complete(
        const CommentaryBatchExecutionResult(
          totalCount: 1,
          successCount: 1,
          failures: <CommentaryBatchFailure>[],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已完成 1 门课程评教'), findsOneWidget);
      expect(find.text('共 0 门未评课程'), findsOneWidget);
    },
  );

  testWidgets(
    'ignores duplicate batch evaluation taps while a batch run is in flight',
    (tester) async {
      final batchCompleter = Completer<CommentaryBatchExecutionResult>();
      var runCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: CommentaryBatchPage(
            loadBatches:
                () async => [
                  {
                    'BATCHID': 'batch-1',
                    'PJ01ID': 'pj01-1',
                    'PJ05ID': 'pj05-1',
                    'EVALUATIONBATCH': '2026 春季评教',
                    'KCLBMC': '理论课',
                    'XQMC': '2025-2026-2',
                  },
                ],
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
              return batchCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final batchButton = find.widgetWithText(FilledButton, '一键评完');
      await tester.tap(batchButton);
      await tester.tap(batchButton);
      await tester.pump();

      expect(runCalls, 1);

      batchCompleter.complete(
        const CommentaryBatchExecutionResult(
          totalCount: 1,
          successCount: 1,
          failures: <CommentaryBatchFailure>[],
        ),
      );
    },
  );

  testWidgets(
    'shows warning summary when batch evaluation partially succeeds',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommentaryBatchPage(
            loadBatches:
                () async => [
                  {
                    'BATCHID': 'batch-1',
                    'PJ01ID': 'pj01-1',
                    'PJ05ID': 'pj05-1',
                    'EVALUATIONBATCH': '2026 春季评教',
                    'KCLBMC': '理论课',
                    'XQMC': '2025-2026-2',
                  },
                ],
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
                  {
                    'isSubmitCode': '0',
                    'courseName': '大学英语',
                    'courseNumber': 'ENGL001',
                    'teacherName': '李老师',
                    'evaluationCategoriesId': 'category-2',
                    'teacherId': 'teacher-2',
                    'noticeId': 'notice-2',
                  },
                ],
            runBatchEvaluation: ({
              required batchId,
              required commentaryItems,
              onProgress,
            }) async {
              return const CommentaryBatchExecutionResult(
                totalCount: 2,
                successCount: 1,
                failures: <CommentaryBatchFailure>[
                  CommentaryBatchFailure(
                    courseName: '大学英语',
                    message: 'submit failed',
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, '一键评完'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('成功 1 门，失败 1 门，可进入课程列表继续处理'), findsOneWidget);
    },
  );

  testWidgets('shows error summary when batch evaluation fully fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryBatchPage(
          loadBatches:
              () async => [
                {
                  'BATCHID': 'batch-1',
                  'PJ01ID': 'pj01-1',
                  'PJ05ID': 'pj05-1',
                  'EVALUATIONBATCH': '2026 春季评教',
                  'KCLBMC': '理论课',
                  'XQMC': '2025-2026-2',
                },
              ],
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
          }) async {
            return const CommentaryBatchExecutionResult(
              totalCount: 1,
              successCount: 0,
              failures: <CommentaryBatchFailure>[
                CommentaryBatchFailure(
                  courseName: '高等数学',
                  message: 'submit failed',
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '一键评完'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('本次未完成任何课程评教，请稍后重试'), findsOneWidget);
  });

  testWidgets('shows empty state when no commentary batches are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CommentaryBatchPage(loadBatches: () async => const [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('当前暂无可评教批次'), findsOneWidget);
    expect(find.text('如果教务系统稍后开放评教，这里会同步展示。'), findsOneWidget);
  });

  testWidgets('shows failure state when batch loading fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryBatchPage(
          loadBatches: () async => throw Exception('load failed'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('评教批次加载失败'), findsOneWidget);
    expect(find.text('请稍后重试'), findsOneWidget);
  });

  testWidgets('duplicate batch taps open a single course list route', (
    tester,
  ) async {
    var buildCoursePageCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryBatchPage(
          loadBatches:
              () async => [
                {
                  'BATCHID': 'batch-1',
                  'PJ01ID': 'pj01-1',
                  'PJ05ID': 'pj05-1',
                  'EVALUATIONBATCH': '2026 春季评教',
                  'KCLBMC': '理论课',
                  'XQMC': '2025-2026-2',
                },
              ],
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
          buildCoursePage: (batch) {
            buildCoursePageCalls++;
            return Scaffold(
              appBar: AppBar(title: const Text('课程列表')),
              body: Text('batch ${batch['BATCHID']}'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final batchTile = find.text('2026 春季评教');
    final batchTileCenter = tester.getCenter(batchTile);
    await tester.tapAt(batchTileCenter);
    await tester.tapAt(batchTileCenter);
    await tester.pumpAndSettle();

    expect(buildCoursePageCalls, 1);
    expect(find.text('课程列表'), findsOneWidget);
    expect(find.text('batch batch-1'), findsOneWidget);

    Navigator.of(tester.element(find.text('课程列表'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(batchTile);
    await tester.pumpAndSettle();

    expect(buildCoursePageCalls, 2);
  });

  testWidgets('batch tap recovers after route push throws', (tester) async {
    var pushCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryBatchPage(
          loadBatches:
              () async => [
                {
                  'BATCHID': 'batch-1',
                  'PJ01ID': 'pj01-1',
                  'PJ05ID': 'pj05-1',
                  'EVALUATIONBATCH': '2026 春季评教',
                  'KCLBMC': '理论课',
                  'XQMC': '2025-2026-2',
                },
              ],
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
          buildCoursePage: (_) => const Scaffold(body: Text('课程列表')),
          pushRoute: <T>(context, route) async {
            pushCalls++;
            throw Exception('navigator unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final batchTile = find.text('2026 春季评教');
    await tester.tapAt(tester.getCenter(batchTile));
    await tester.pump();
    await tester.pump();

    expect(pushCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开评教课程列表，请稍后重试'), findsOneWidget);

    await tester.tapAt(tester.getCenter(batchTile));
    await tester.pump();
    await tester.pump();

    expect(pushCalls, 2);
  });
}
