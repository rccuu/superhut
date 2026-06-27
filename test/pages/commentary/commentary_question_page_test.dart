import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/ui/apple_glass.dart';
import 'package:superhut/pages/Commentary/commentary_api.dart';
import 'package:superhut/pages/Commentary/commentary_question_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auto submit uses the shared selection rule', (tester) async {
    final submittedItems = <List<CommentarySubmissionItem>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryQuestionPage(
          batchId: 'batch-1',
          courseId: 'course-1',
          evaluationCategoriesId: 'category-1',
          teacherId: 'teacher-1',
          noticeId: 'notice-1',
          loadQuestions: (
            batchId,
            evaluationCategoriesId,
            courseId,
            teacherId,
            noticeId,
          ) async {
            return [
              {
                'targetName': '教学态度',
                'targetId': 'target-1',
                'optionList': const [
                  QuestionOption('target-1', '非常满意', 'option-1', '5.0'),
                  QuestionOption('target-1', '满意', 'option-2', '4.0'),
                ],
              },
              {
                'targetName': '教学方法',
                'targetId': 'target-2',
                'optionList': const [
                  QuestionOption('target-2', '非常满意', 'option-3', '5.0'),
                  QuestionOption('target-2', '满意', 'option-4', '4.0'),
                ],
              },
            ];
          },
          submitSelections: (
            batchId,
            courseId,
            evaluationCategoriesId,
            teacherId,
            noticeId,
            questionList,
          ) async {
            submittedItems.add(
              List<CommentarySubmissionItem>.from(questionList),
            );
            return '提交失败';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('一键完成'));
    await tester.pump();

    expect(submittedItems.single, [
      {'targetid': 'target-1', 'targetval': 'option-2'},
      {'targetid': 'target-2', 'targetval': 'option-3'},
    ]);
  });

  testWidgets('ignores duplicate manual submits while request is in flight', (
    tester,
  ) async {
    final submitCompleter = Completer<String>();
    var loadCalls = 0;
    var submitCalls = 0;
    final submittedItems = <List<CommentarySubmissionItem>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryQuestionPage(
          batchId: 'batch-1',
          courseId: 'course-1',
          evaluationCategoriesId: 'category-1',
          teacherId: 'teacher-1',
          noticeId: 'notice-1',
          loadQuestions: (
            batchId,
            evaluationCategoriesId,
            courseId,
            teacherId,
            noticeId,
          ) async {
            loadCalls++;
            return [
              {
                'targetName': '教学态度',
                'targetId': 'target-1',
                'optionList': const [
                  QuestionOption('target-1', '满意', 'option-1', '5.0'),
                ],
              },
            ];
          },
          submitSelections: (
            batchId,
            courseId,
            evaluationCategoriesId,
            teacherId,
            noticeId,
            questionList,
          ) {
            submitCalls++;
            submittedItems.add(
              List<CommentarySubmissionItem>.from(questionList),
            );
            return submitCompleter.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loadCalls, 1);
    expect(find.text('教学态度'), findsOneWidget);

    await tester.tap(find.text('满意'));
    await tester.pump();

    final submitButton = find.widgetWithText(FilledButton, '提交');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(submitCalls, 1);
    expect(submittedItems.single, [
      {'targetid': 'target-1', 'targetval': 'option-1'},
    ]);

    submitCompleter.complete('提交失败');
    await tester.pump();

    expect(find.text('提交失败'), findsOneWidget);
  });

  testWidgets('manual option selection submits the latest selected answer', (
    tester,
  ) async {
    final submittedItems = <List<CommentarySubmissionItem>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryQuestionPage(
          batchId: 'batch-1',
          courseId: 'course-1',
          evaluationCategoriesId: 'category-1',
          teacherId: 'teacher-1',
          noticeId: 'notice-1',
          loadQuestions: (
            batchId,
            evaluationCategoriesId,
            courseId,
            teacherId,
            noticeId,
          ) async {
            return [
              {
                'targetName': '教学态度',
                'targetId': 'target-1',
                'optionList': const [
                  QuestionOption('target-1', '满意', 'option-1', '5.0'),
                  QuestionOption('target-1', '一般', 'option-2', '3.0'),
                ],
              },
            ];
          },
          submitSelections: (
            batchId,
            courseId,
            evaluationCategoriesId,
            teacherId,
            noticeId,
            questionList,
          ) async {
            submittedItems.add(
              List<CommentarySubmissionItem>.from(questionList),
            );
            return '提交失败';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('满意'));
    await tester.pump();
    await tester.tap(find.text('满意'));
    await tester.pump();
    await tester.tap(find.text('一般'));
    await tester.pump();

    final firstOption = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '满意'),
    );
    final secondOption = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '一般'),
    );
    expect(firstOption.value, isFalse);
    expect(secondOption.value, isTrue);

    final submitButton = find.widgetWithText(FilledButton, '提交');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(submittedItems.single, [
      {'targetid': 'target-1', 'targetval': 'option-2'},
    ]);
  });

  testWidgets('manual submit recovers after submitter throws', (tester) async {
    var submitCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryQuestionPage(
          batchId: 'batch-1',
          courseId: 'course-1',
          evaluationCategoriesId: 'category-1',
          teacherId: 'teacher-1',
          noticeId: 'notice-1',
          loadQuestions: (
            batchId,
            evaluationCategoriesId,
            courseId,
            teacherId,
            noticeId,
          ) async {
            return [
              {
                'targetName': '教学态度',
                'targetId': 'target-1',
                'optionList': const [
                  QuestionOption('target-1', '满意', 'option-1', '5.0'),
                ],
              },
            ];
          },
          submitSelections: (
            batchId,
            courseId,
            evaluationCategoriesId,
            teacherId,
            noticeId,
            questionList,
          ) async {
            submitCalls++;
            throw Exception('network unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('满意'));
    await tester.pump();

    final submitButton = find.widgetWithText(FilledButton, '提交');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pump();

    expect(submitCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('提交失败'), findsOneWidget);

    await tester.tap(submitButton);
    await tester.pump();
    await tester.pump();

    expect(submitCalls, 2);
  });

  testWidgets('manual submit hides backend error details', (tester) async {
    const rawBackendError =
        '接口提交失败: https://jwxt.hut.edu.cn/saveEvaluate?token=secret-token';

    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryQuestionPage(
          batchId: 'batch-1',
          courseId: 'course-1',
          evaluationCategoriesId: 'category-1',
          teacherId: 'teacher-1',
          noticeId: 'notice-1',
          loadQuestions: (
            batchId,
            evaluationCategoriesId,
            courseId,
            teacherId,
            noticeId,
          ) async {
            return [
              {
                'targetName': '教学态度',
                'targetId': 'target-1',
                'optionList': const [
                  QuestionOption('target-1', '满意', 'option-1', '5.0'),
                ],
              },
            ];
          },
          submitSelections: (
            batchId,
            courseId,
            evaluationCategoriesId,
            teacherId,
            noticeId,
            questionList,
          ) async {
            return rawBackendError;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('满意'));
    await tester.pump();

    final submitButton = find.widgetWithText(FilledButton, '提交');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(find.text(commentarySubmitFailureMessage), findsOneWidget);
    expect(find.text(rawBackendError), findsNothing);
  });

  testWidgets(
    'question page renders a glass shell around the loaded questionnaire',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CommentaryQuestionPage(
            batchId: 'batch-1',
            courseId: 'course-1',
            evaluationCategoriesId: 'category-1',
            teacherId: 'teacher-1',
            noticeId: 'notice-1',
            loadQuestions: (
              batchId,
              evaluationCategoriesId,
              courseId,
              teacherId,
              noticeId,
            ) async {
              return [
                {
                  'targetName': '教学态度',
                  'targetId': 'target-1',
                  'optionList': const [
                    QuestionOption('target-1', '满意', 'option-1', '5.0'),
                  ],
                },
              ];
            },
            submitSelections: (
              batchId,
              courseId,
              evaluationCategoriesId,
              teacherId,
              noticeId,
              questionList,
            ) async {
              return '提交失败';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppGlassBackground), findsOneWidget);
      expect(find.byType(GlassPanel), findsAtLeastNWidgets(2));
      expect(find.text('共 1 道题'), findsOneWidget);
    },
  );
}
