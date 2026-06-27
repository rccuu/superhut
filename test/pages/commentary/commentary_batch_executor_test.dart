import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/Commentary/commentary_api.dart';
import 'package:superhut/pages/Commentary/commentary_batch_executor.dart';

void main() {
  test(
    'runCommentaryBatchEvaluation submits pending courses serially and keeps going after an unmatched course',
    () async {
      final callLog = <String>[];
      final progressLog = <String>[];

      final result = await runCommentaryBatchEvaluation(
        batchId: 'batch-1',
        commentaryItems: [
          {
            'isSubmitCode': '0',
            'courseName': '高等数学',
            'courseNumber': 'MATH001',
            'evaluationCategoriesId': 'category-1',
            'teacherId': 'teacher-1',
            'noticeId': 'notice-1',
          },
          {
            'isSubmitCode': '1',
            'courseName': '大学英语',
            'courseNumber': 'ENG001',
            'evaluationCategoriesId': 'category-1',
            'teacherId': 'teacher-2',
            'noticeId': 'notice-2',
          },
          {
            'isSubmitCode': '0',
            'courseName': '大学物理',
            'courseNumber': 'PHYS001',
            'evaluationCategoriesId': 'category-1',
            'teacherId': 'teacher-3',
            'noticeId': 'notice-3',
          },
        ],
        loadQuestions: (
          batchId,
          evaluationCategoriesId,
          courseId,
          teacherId,
          noticeId,
        ) async {
          callLog.add('load:$courseId');
          if (courseId == 'PHYS001') {
            return [
              {
                'targetId': 'target-3',
                'optionList': const [
                  QuestionOption('target-3', '非常满意', 'option-5', '5.0'),
                ],
              },
            ];
          }

          return [
            {
              'targetId': 'target-1',
              'optionList': const [
                QuestionOption('target-1', '非常满意', 'option-1', '5.0'),
                QuestionOption('target-1', '满意', 'option-2', '4.0'),
              ],
            },
            {
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
          callLog.add('submit:$courseId');
          return 'success';
        },
        onProgress: (progress) {
          progressLog.add(
            '${progress.completedCount}/${progress.totalCount}:${progress.currentCourseName}',
          );
        },
      );

      expect(callLog, ['load:MATH001', 'submit:MATH001', 'load:PHYS001']);
      expect(progressLog, ['1/2:高等数学', '2/2:大学物理']);
      expect(result.totalCount, 2);
      expect(result.successCount, 1);
      expect(result.failureCount, 1);
      expect(result.failures.single.courseName, '大学物理');
      expect(result.failures.single.message, '还有题目未匹配到可提交选项');
    },
  );

  test(
    'runCommentaryBatchEvaluation returns an empty result when nothing is pending',
    () async {
      final progressLog = <String>[];

      final result = await runCommentaryBatchEvaluation(
        batchId: 'batch-1',
        commentaryItems: [
          {
            'isSubmitCode': '1',
            'courseName': '高等数学',
            'courseNumber': 'MATH001',
            'evaluationCategoriesId': 'category-1',
            'teacherId': 'teacher-1',
            'noticeId': 'notice-1',
          },
        ],
        loadQuestions: (
          batchId,
          evaluationCategoriesId,
          courseId,
          teacherId,
          noticeId,
        ) async {
          fail(
            'loadQuestions should not run when every course is already submitted',
          );
        },
        submitSelections: (
          batchId,
          courseId,
          evaluationCategoriesId,
          teacherId,
          noticeId,
          questionList,
        ) async {
          fail(
            'submitSelections should not run when every course is already submitted',
          );
        },
        onProgress: (progress) {
          progressLog.add(progress.currentCourseName);
        },
      );

      expect(progressLog, isEmpty);
      expect(result.totalCount, 0);
      expect(result.successCount, 0);
      expect(result.failureCount, 0);
      expect(result.failures, isEmpty);
    },
  );
}
