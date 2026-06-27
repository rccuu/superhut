import 'commentary_api.dart';
import 'commentary_auto_selection.dart';

typedef CommentaryBatchQuestionLoader =
    Future<List<CommentaryPayload>> Function(
      String batchId,
      String evaluationCategoriesId,
      String courseId,
      String teacherId,
      String noticeId,
    );

typedef CommentaryBatchSubmitter =
    Future<String> Function(
      String batchId,
      String courseId,
      String evaluationCategoriesId,
      String teacherId,
      String noticeId,
      List<CommentarySubmissionItem> questionList,
    );

typedef CommentaryBatchProgressCallback =
    void Function(CommentaryBatchProgress progress);

class CommentaryBatchProgress {
  const CommentaryBatchProgress({
    required this.completedCount,
    required this.totalCount,
    required this.currentCourseName,
  });

  final int completedCount;
  final int totalCount;
  final String currentCourseName;
}

class CommentaryBatchFailure {
  const CommentaryBatchFailure({
    required this.courseName,
    required this.message,
  });

  final String courseName;
  final String message;
}

class CommentaryBatchExecutionResult {
  const CommentaryBatchExecutionResult({
    required this.totalCount,
    required this.successCount,
    required this.failures,
  });

  final int totalCount;
  final int successCount;
  final List<CommentaryBatchFailure> failures;

  int get failureCount => failures.length;
  bool get allSucceeded => totalCount > 0 && failureCount == 0;
  bool get allFailed => totalCount > 0 && successCount == 0;
}

Future<CommentaryBatchExecutionResult> runCommentaryBatchEvaluation({
  required String batchId,
  required List<CommentaryPayload> commentaryItems,
  required CommentaryBatchQuestionLoader loadQuestions,
  required CommentaryBatchSubmitter submitSelections,
  CommentaryBatchProgressCallback? onProgress,
}) async {
  final pendingItems = commentaryItems
      .where((item) => item['isSubmitCode']?.toString() != '1')
      .toList(growable: false);
  final failures = <CommentaryBatchFailure>[];
  var successCount = 0;

  for (var index = 0; index < pendingItems.length; index++) {
    final commentary = pendingItems[index];
    final courseName = commentary['courseName']?.toString() ?? '未命名课程';
    final courseId = commentary['courseNumber'].toString();
    final evaluationCategoriesId =
        commentary['evaluationCategoriesId'].toString();
    final teacherId = commentary['teacherId'].toString();
    final noticeId = commentary['noticeId'].toString();

    try {
      final questions = await loadQuestions(
        batchId,
        evaluationCategoriesId,
        courseId,
        teacherId,
        noticeId,
      );
      final selections = buildAutoCommentarySelections(questions);
      if (selections.length < questions.length) {
        failures.add(
          CommentaryBatchFailure(
            courseName: courseName,
            message: '还有题目未匹配到可提交选项',
          ),
        );
        continue;
      }

      final submitResult = await submitSelections(
        batchId,
        courseId,
        evaluationCategoriesId,
        teacherId,
        noticeId,
        selections,
      );
      if (submitResult == 'success') {
        successCount++;
      } else {
        failures.add(
          CommentaryBatchFailure(courseName: courseName, message: '提交失败'),
        );
      }
    } catch (_) {
      failures.add(
        CommentaryBatchFailure(courseName: courseName, message: '加载题目失败'),
      );
    } finally {
      onProgress?.call(
        CommentaryBatchProgress(
          completedCount: index + 1,
          totalCount: pendingItems.length,
          currentCourseName: courseName,
        ),
      );
    }
  }

  return CommentaryBatchExecutionResult(
    totalCount: pendingItems.length,
    successCount: successCount,
    failures: List<CommentaryBatchFailure>.unmodifiable(failures),
  );
}
