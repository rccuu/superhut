import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';

import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_snack_bar.dart';
import 'commentary_api.dart';

typedef CommentaryQuestionLoader =
    Future<List<CommentaryPayload>> Function(
      String batchId,
      String evaluationCategoriesId,
      String courseId,
      String teacherId,
      String noticeId,
    );

typedef CommentaryQuestionSubmitter =
    Future<String> Function(
      String batchId,
      String courseId,
      String evaluationCategoriesId,
      String teacherId,
      String noticeId,
      List<CommentarySubmissionItem> questionList,
    );

const commentarySubmitFailureMessage = '提交失败';

class CommentaryQuestionPage extends StatefulWidget {
  final String batchId;
  final String courseId;
  final String evaluationCategoriesId;
  final String teacherId;
  final String noticeId;
  final CommentaryQuestionLoader? loadQuestions;
  final CommentaryQuestionSubmitter? submitSelections;

  const CommentaryQuestionPage({
    super.key,
    required this.batchId,
    required this.courseId,
    required this.evaluationCategoriesId,
    required this.teacherId,
    required this.noticeId,
    this.loadQuestions,
    this.submitSelections,
  });

  @override
  State<CommentaryQuestionPage> createState() => _CommentaryQuestionPageState();
}

class _CommentaryQuestionPageState extends State<CommentaryQuestionPage> {
  List<ValueNotifier<int>>? _questionSelectionNotifiers;
  bool _isInitialized = false;
  final ValueNotifier<bool> _isSubmitting = ValueNotifier<bool>(false);
  List<CommentaryPayload> _savedQuestionList = <CommentaryPayload>[];
  List<List<QuestionOption>> _questionOptions = <List<QuestionOption>>[];
  late Future<List<CommentaryPayload>> _optionListFuture;

  @override
  void dispose() {
    _disposeQuestionSelectionNotifiers();
    _isSubmitting.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _optionListFuture = _getOptionList();
  }

  void _showSnackBar(
    String message, {
    AppSnackBarType type = AppSnackBarType.info,
  }) {
    if (!mounted) {
      return;
    }

    showAppSnackBar(context, message: message, type: type);
  }

  Future<List<CommentaryPayload>> _getOptionList() async {
    if (_isInitialized) {
      return _savedQuestionList;
    }

    final questionLoader = widget.loadQuestions ?? getCommentaryQuestions;
    final allOptionList = await questionLoader(
      widget.batchId,
      widget.evaluationCategoriesId,
      widget.courseId,
      widget.teacherId,
      widget.noticeId,
    );

    final questionSelectionNotifiers = <ValueNotifier<int>>[];
    final questionOptions = <List<QuestionOption>>[];
    for (final question in allOptionList) {
      final options = _extractQuestionOptions(question);
      questionOptions.add(options);
      questionSelectionNotifiers.add(ValueNotifier<int>(-1));
    }

    if (!mounted) {
      for (final notifier in questionSelectionNotifiers) {
        notifier.dispose();
      }
      return allOptionList;
    }

    _replaceQuestionSelectionNotifiers(questionSelectionNotifiers);
    _questionOptions = List<List<QuestionOption>>.unmodifiable(questionOptions);
    _isInitialized = true;
    _savedQuestionList = allOptionList;
    return allOptionList;
  }

  void _replaceQuestionSelectionNotifiers(List<ValueNotifier<int>> notifiers) {
    _disposeQuestionSelectionNotifiers();
    _questionSelectionNotifiers = List<ValueNotifier<int>>.unmodifiable(
      notifiers,
    );
  }

  void _disposeQuestionSelectionNotifiers() {
    final notifiers = _questionSelectionNotifiers;
    if (notifiers == null) {
      return;
    }

    for (final notifier in notifiers) {
      notifier.dispose();
    }
    _questionSelectionNotifiers = null;
  }

  List<QuestionOption> _extractQuestionOptions(CommentaryPayload question) {
    final optionList = question['optionList'];
    if (optionList is! List) {
      return <QuestionOption>[];
    }

    final options = <QuestionOption>[];
    for (final option in optionList) {
      if (option is QuestionOption) {
        options.add(option);
      }
    }
    return List<QuestionOption>.unmodifiable(options);
  }

  void _selectOption(int questionIndex, int optionIndex, bool? isSelected) {
    final questionSelectionNotifiers = _questionSelectionNotifiers;
    if (isSelected != true ||
        questionSelectionNotifiers == null ||
        questionIndex < 0 ||
        optionIndex < 0 ||
        questionIndex >= questionSelectionNotifiers.length ||
        questionIndex >= _questionOptions.length) {
      return;
    }

    final options = _questionOptions[questionIndex];
    if (optionIndex >= options.length) {
      return;
    }

    final selectionNotifier = questionSelectionNotifiers[questionIndex];
    if (selectionNotifier.value == optionIndex) {
      return;
    }

    selectionNotifier.value = optionIndex;
  }

  List<CommentarySubmissionItem> _getUserSelections() {
    final selections = <CommentarySubmissionItem>[];

    final questionSelectionNotifiers = _questionSelectionNotifiers;
    if (questionSelectionNotifiers == null ||
        _savedQuestionList.isEmpty ||
        questionSelectionNotifiers.length != _savedQuestionList.length ||
        _questionOptions.length != _savedQuestionList.length) {
      return selections;
    }

    for (int i = 0; i < _savedQuestionList.length; i++) {
      final question = _savedQuestionList[i];
      final options = _questionOptions[i];
      final selectedOptionIndex = questionSelectionNotifiers[i].value;

      if (selectedOptionIndex < 0 || selectedOptionIndex >= options.length) {
        continue;
      }

      selections.add({
        'targetid': question['targetId'].toString(),
        'targetval': options[selectedOptionIndex].optionId,
      });
    }

    return selections;
  }

  List<CommentarySubmissionItem> _buildAutoSelections() {
    final selections = <CommentarySubmissionItem>[];
    if (_questionOptions.length != _savedQuestionList.length) {
      return selections;
    }

    for (var i = 0; i < _savedQuestionList.length; i++) {
      final question = _savedQuestionList[i];
      final options = _questionOptions[i];

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

  void _setSubmitting(bool isSubmitting) {
    if (!mounted || _isSubmitting.value == isSubmitting) {
      return;
    }

    _isSubmitting.value = isSubmitting;
  }

  Future<void> _submitSelections(
    List<CommentarySubmissionItem> userSelections,
  ) async {
    if (_isSubmitting.value) {
      return;
    }

    _setSubmitting(true);

    final navigator = Navigator.of(context);
    var didPop = false;

    try {
      final submitter = widget.submitSelections ?? submitCommentary;
      final result = await submitter(
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
        _showSnackBar('提交成功', type: AppSnackBarType.success);
        didPop = true;
        navigator.pop(true);
        return;
      }

      _showSnackBar(
        commentarySubmitFailureMessage,
        type: AppSnackBarType.error,
      );
    } catch (_) {
      _showSnackBar(
        commentarySubmitFailureMessage,
        type: AppSnackBarType.error,
      );
    } finally {
      if (!didPop) {
        _setSubmitting(false);
      }
    }
  }

  Future<void> _handleAutoSubmit() async {
    if (_savedQuestionList.isEmpty) {
      _showSnackBar('题目还在加载中，请稍后再试', type: AppSnackBarType.warning);
      return;
    }

    final userSelections = _buildAutoSelections();
    if (userSelections.length < _savedQuestionList.length) {
      _showSnackBar('还有题目未匹配到可提交选项', type: AppSnackBarType.warning);
      return;
    }

    await _submitSelections(userSelections);
  }

  Future<void> _handleManualSubmit(int questionCount) async {
    final userSelections = _getUserSelections();
    if (userSelections.length < questionCount) {
      _showSnackBar('需要完成所有题目才可以提交~', type: AppSnackBarType.warning);
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
          ValueListenableBuilder<bool>(
            valueListenable: _isSubmitting,
            child: const Text('一键完成'),
            builder: (context, isSubmitting, child) {
              return TextButton(
                onPressed: isSubmitting ? null : _handleAutoSubmit,
                child: child!,
              );
            },
          ),
        ],
      ),
      body: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        child: EnhancedFutureBuilder(
          future: _optionListFuture,
          rememberFutureResult: true,
          whenDone: (List<CommentaryPayload> optionList) {
            final questionSelectionNotifiers = _questionSelectionNotifiers;
            final questionOptions = _questionOptions;
            if (questionSelectionNotifiers == null ||
                questionSelectionNotifiers.length != optionList.length ||
                questionOptions.length != optionList.length) {
              return Center(
                child: AppLoadingIndicator(
                  color: Theme.of(context).primaryColor,
                  size: 40,
                ),
              );
            }

            return ListView.builder(
              addAutomaticKeepAlives: false,
              itemCount: optionList.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index == optionList.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _isSubmitting,
                      child: const Text('提交'),
                      builder: (context, isSubmitting, child) {
                        return ElevatedButton(
                          onPressed:
                              isSubmitting
                                  ? null
                                  : () async {
                                    await _handleManualSubmit(
                                      optionList.length,
                                    );
                                  },
                          child: child!,
                        );
                      },
                    ),
                  );
                }

                final question = optionList[index];
                final options = questionOptions[index];
                final selectionNotifier = questionSelectionNotifiers[index];

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
                              ValueListenableBuilder<int>(
                                valueListenable: selectionNotifier,
                                builder: (context, selectedOptionIndex, child) {
                                  return Column(
                                    children: [
                                      for (
                                        var optionIndex = 0;
                                        optionIndex < options.length;
                                        optionIndex++
                                      )
                                        CheckboxListTile(
                                          value:
                                              selectedOptionIndex ==
                                              optionIndex,
                                          onChanged: (value) {
                                            _selectOption(
                                              index,
                                              optionIndex,
                                              value,
                                            );
                                          },
                                          title: Text(
                                            options[optionIndex].answer,
                                          ),
                                        ),
                                    ],
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
            child: AppLoadingIndicator(
              color: Theme.of(context).primaryColor,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }
}
