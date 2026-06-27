import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/Commentary/commentary_api.dart';
import 'package:superhut/pages/Commentary/commentary_auto_selection.dart';

void main() {
  test(
    'buildAutoCommentarySelections picks a low score for the first question and high scores for the rest',
    () {
      final questions = <CommentaryPayload>[
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

      expect(buildAutoCommentarySelections(questions), [
        {'targetid': 'target-1', 'targetval': 'option-2'},
        {'targetid': 'target-2', 'targetval': 'option-3'},
      ]);
    },
  );

  test(
    'buildAutoCommentarySelections leaves unmatched questions out of the result',
    () {
      final questions = <CommentaryPayload>[
        {
          'targetId': 'target-1',
          'optionList': const [
            QuestionOption('target-1', '非常满意', 'option-1', '5.0'),
          ],
        },
      ];

      expect(buildAutoCommentarySelections(questions), isEmpty);
    },
  );
}
