import 'commentary_api.dart';

List<CommentarySubmissionItem> buildAutoCommentarySelections(
  List<CommentaryPayload> questions,
) {
  final selections = <CommentarySubmissionItem>[];

  for (
    var questionIndex = 0;
    questionIndex < questions.length;
    questionIndex++
  ) {
    final question = questions[questionIndex];
    final optionList = question['optionList'];
    if (optionList is! List) {
      continue;
    }

    for (final option in optionList) {
      if (option is! QuestionOption) {
        continue;
      }

      if (_matchesAutoCommentaryRule(option, questionIndex)) {
        selections.add({
          'targetid': question['targetId'].toString(),
          'targetval': option.optionId,
        });
        break;
      }
    }
  }

  return List<CommentarySubmissionItem>.unmodifiable(selections);
}

bool matchesAutoCommentaryRule(QuestionOption option, int questionIndex) {
  return _matchesAutoCommentaryRule(option, questionIndex);
}

bool _matchesAutoCommentaryRule(QuestionOption option, int questionIndex) {
  final optionScore = double.tryParse(option.optionScoreValue);
  if (optionScore == null) {
    return false;
  }

  return questionIndex == 0 ? optionScore < 4.75 : optionScore >= 4.75;
}
