import '../../core/services/app_logger.dart';
import '../../utils/withhttp.dart';

typedef CommentaryPayload = Map<String, dynamic>;
typedef CommentarySubmissionItem = Map<String, String>;

class QuestionOption {
  final String targetId;
  final String answer;
  final String optionId;
  final String optionScoreValue;

  const QuestionOption(
    this.targetId,
    this.answer,
    this.optionId,
    this.optionScoreValue,
  );
}

Future<List<CommentaryPayload>> getCommentaryBatches() async {
  await configureDioFromStorage();
  final response = await postDioWithCookie(
    '/njwhd/student/studentEvaluate',
    {},
  );
  final data = _toPayloadMap(response.data);
  return _toPayloadList(data['data']);
}

Future<List<CommentaryPayload>> getCommentaryList(
  String pj01id,
  String batchId,
  String pj05id,
) async {
  await configureDioFromStorage();
  final response = await postDioWithCookie(
    '/njwhd/student/teachingEvaluation?pj01id=$pj01id&batchId=$batchId&pj05id=$pj05id&issubmit=all',
    {},
  );
  final data = _toPayloadMap(response.data);
  return _toPayloadList(data['data']);
}

Future<List<CommentaryPayload>> getCommentaryQuestions(
  String batchId,
  String evaluationCategoriesId,
  String courseId,
  String teacherId,
  String noticeId,
) async {
  await configureDioFromStorage();
  final response = await postDioWithCookie(
    '/njwhd/student/evaluationIndex?batchId=$batchId&evaluationCategoriesId=$evaluationCategoriesId&courseId=$courseId&teacherId=$teacherId&noticeId=$noticeId&schoolClassificationId=""',
    {},
  );
  final data = _toPayloadMap(response.data);
  final mapData = _toPayloadMap(data['data']);
  final targetData = _toPayloadList(mapData['targetData']);
  final resultList = <CommentaryPayload>[];

  for (final target in targetData) {
    if (_stringValue(target['parentTargetId']).isEmpty) {
      continue;
    }

    final commentaryQuestions = _toPayloadList(target['optionData']);
    final questionList =
        commentaryQuestions.map((commentaryQuestion) {
          return QuestionOption(
            _stringValue(target['targetId']),
            _stringValue(commentaryQuestion['optionName']),
            _stringValue(commentaryQuestion['optionId']),
            _stringValue(commentaryQuestion['optionScoreValue']),
          );
        }).toList();

    resultList.add({
      'targetName': _stringValue(target['targetName']),
      'targetId': _stringValue(target['targetId']),
      'optionList': questionList,
    });
  }

  return resultList;
}

Future<String> submitCommentary(
  String batchId,
  String courseId,
  String evaluationCategoriesId,
  String teacherId,
  String noticeId,
  List<CommentarySubmissionItem> questionList,
) async {
  await configureDioFromStorage();
  final response = await postDioWithCookie('/njwhd/student/saveEvaluate', {
    'batchId': batchId,
    'courseId': courseId,
    'evaluationCategoriesId': evaluationCategoriesId,
    'teacherId': teacherId,
    'noticeId': noticeId,
    'schoolClassificationId': '',
    'target': questionList,
  });
  final data = _toPayloadMap(response.data);
  final result =
      _stringValue(data['code']).isNotEmpty
          ? _stringValue(data['code'])
          : _stringValue(data['errorMessage']);
  AppLogger.debug('Commentary submit result: $result');
  return result;
}

CommentaryPayload _toPayloadMap(Object? rawMap) {
  if (rawMap is! Map) {
    return <String, dynamic>{};
  }

  return Map<String, dynamic>.from(rawMap);
}

List<CommentaryPayload> _toPayloadList(Object? rawList) {
  if (rawList is! List) {
    return <CommentaryPayload>[];
  }

  return rawList
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _stringValue(Object? value) {
  return value?.toString() ?? '';
}
