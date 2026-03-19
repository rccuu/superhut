import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'commentary_api.dart';

class CommentaryQuestionPage extends StatefulWidget {
  final String batchId;
  final String courseId;
  final String evaluationCategoriesId;
  final String teacherId;
  final String noticeId;

  const CommentaryQuestionPage({
    super.key,
    required this.batchId,
    required this.courseId,
    required this.evaluationCategoriesId,
    required this.teacherId,
    required this.noticeId,
  });

  @override
  State<CommentaryQuestionPage> createState() => _CommentaryQuestionPageState();
}

class _CommentaryQuestionPageState extends State<CommentaryQuestionPage> {
  List<List<bool>>? _questionSelections;
  bool _isInitialized = false;
  List<CommentaryPayload> _savedQuestionList = <CommentaryPayload>[];

  Future<List<CommentaryPayload>> _getOptionList() async {
    if (_isInitialized) {
      return _savedQuestionList;
    }

    final allOptionList = await getCommentaryQuestions(
      widget.batchId,
      widget.evaluationCategoriesId,
      widget.courseId,
      widget.teacherId,
      widget.noticeId,
    );

    _questionSelections =
        allOptionList.map<List<bool>>((question) {
          return List<bool>.filled(_getQuestionOptions(question).length, false);
        }).toList();
    _isInitialized = true;
    _savedQuestionList = allOptionList;
    return allOptionList;
  }

  List<QuestionOption> _getQuestionOptions(CommentaryPayload question) {
    final optionList = question['optionList'];
    if (optionList is! List) {
      return <QuestionOption>[];
    }

    return optionList.whereType<QuestionOption>().toList();
  }

  void _selectOption(
    int questionIndex,
    int optionIndex,
    int optionCount,
    bool? isSelected,
  ) {
    if (isSelected != true || _questionSelections == null) {
      return;
    }

    setState(() {
      for (var i = 0; i < optionCount; i++) {
        _questionSelections![questionIndex][i] = false;
      }
      _questionSelections![questionIndex][optionIndex] = true;
    });
  }

  List<CommentarySubmissionItem> _getUserSelections() {
    final selections = <CommentarySubmissionItem>[];

    if (_questionSelections == null || _savedQuestionList.isEmpty) {
      return selections;
    }

    for (int i = 0; i < _savedQuestionList.length; i++) {
      final question = _savedQuestionList[i];
      final options = _getQuestionOptions(question);

      for (int j = 0; j < options.length; j++) {
        if (_questionSelections![i][j]) {
          selections.add({
            'targetid': question['targetId'].toString(),
            'targetval': options[j].optionId,
          });
          break;
        }
      }
    }

    return selections;
  }

  List<CommentarySubmissionItem> _buildAutoSelections() {
    final selections = <CommentarySubmissionItem>[];

    for (var i = 0; i < _savedQuestionList.length; i++) {
      final question = _savedQuestionList[i];
      final options = _getQuestionOptions(question);

      for (int j = 0; j < options.length; j++) {
        final optionScore = double.tryParse(options[j].optionScoreValue);
        if (optionScore == null) {
          continue;
        }

        final shouldSelect = i == 0 ? optionScore < 4.75 : optionScore >= 4.75;
        if (!shouldSelect) {
          continue;
        }

        selections.add({
          'targetid': question['targetId'].toString(),
          'targetval': options[j].optionId,
        });
        break;
      }
    }

    return selections;
  }

  Future<void> _submitSelections(
    List<CommentarySubmissionItem> userSelections,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final result = await submitCommentary(
      widget.batchId,
      widget.courseId,
      widget.evaluationCategoriesId,
      widget.teacherId,
      widget.noticeId,
      userSelections,
    );

    if (!mounted) {
      return;
    }

    if (result == 'success') {
      messenger.showSnackBar(const SnackBar(content: Text('提交成功~')));
      navigator.pop(true);
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(result)));
  }

  Future<void> _handleAutoSubmit() async {
    if (_savedQuestionList.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('题目还在加载中，请稍后再试')));
      return;
    }

    final userSelections = _buildAutoSelections();
    if (userSelections.length < _savedQuestionList.length) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('还有题目未匹配到可提交选项')));
      return;
    }

    await _submitSelections(userSelections);
  }

  Future<void> _handleManualSubmit(int questionCount) async {
    final userSelections = _getUserSelections();
    if (userSelections.length < questionCount) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('需要完成所有题目才可以提交~')));
      return;
    }

    await _submitSelections(userSelections);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(onPressed: _handleAutoSubmit, child: const Text('一键完成')),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: EnhancedFutureBuilder(
          future: _getOptionList(),
          rememberFutureResult: true,
          whenDone: (List optionList) {
            final typedOptionList = List<CommentaryPayload>.from(optionList);
            return ListView.builder(
              itemCount: typedOptionList.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index == typedOptionList.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: ElevatedButton(
                      onPressed: () async {
                        await _handleManualSubmit(typedOptionList.length);
                      },
                      child: const Text('提交'),
                    ),
                  );
                }

                final question = typedOptionList[index];
                final optionList = _getQuestionOptions(question);

                return Card.filled(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Flex(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      direction: Axis.horizontal,
                      children: [
                        Expanded(
                          flex: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                question['targetName'].toString(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: optionList.length,
                                itemBuilder: (
                                  BuildContext context,
                                  int optionIndex,
                                ) {
                                  return CheckboxListTile(
                                    value:
                                        _questionSelections![index][optionIndex],
                                    onChanged: (value) {
                                      _selectOption(
                                        index,
                                        optionIndex,
                                        optionList.length,
                                        value,
                                      );
                                    },
                                    title: Text(optionList[optionIndex].answer),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          whenNotDone: Center(
            child: LoadingAnimationWidget.inkDrop(
              color: Theme.of(context).primaryColor,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}
