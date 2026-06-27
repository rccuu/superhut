import 'commentary_api.dart';

List<CommentarySubmissionItem> buildAutoCommentarySelections(
  List<CommentaryPayload> questions,
) {
  final selections = <CommentarySubmissionItem>[];

  for (var questionIndex = 0; questionIndex < questions.length; questionIndex++) {
    final question = questions[questionIndex];
    final optionList = question['optionList'];
    if (optionList is! List) {
      continue;
    }

    QuestionOption? matchedOption;
    for (final option in optionList) {
      if (option is! QuestionOption) {
        continue;
      }

      final optionScore = double.tryParse(option.optionScoreValue);
      if (optionScore == null) {
        continue;
      }

      final shouldSelect =
          questionIndex == 0 ? optionScore < 4.75 : optionScore >= 4.75;
      if (shouldSelect) {
        matchedOption = option;
        break;
      }
    }

    if (matchedOption == null) {
      continue;
    }

    selections.add({
      'targetid': question['targetId'].toString(),
      'targetval': matchedOption.optionId,
    });
  }

  return List<CommentarySubmissionItem>.unmodifiable(selections);
}
