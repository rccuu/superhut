import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/apple_glass.dart';
import '../../core/ui/color_scheme_ext.dart';
import 'commentary_api.dart';
import 'commentary_auto_selection.dart';

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

      for (final option in options) {
        if (matchesAutoCommentaryRule(option, i)) {
          selections.add({
            'targetid': question['targetId'].toString(),
            'targetval': option.optionId,
          });
          break;
        }
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    const accent = Color(0xFFB6569C);

    return AppGlassPerformanceScope(
      isLite: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppGlassBackground(
          style: AppGlassBackgroundStyle.soft,
          lightBottomColor: const Color(0xFFFFF3FA),
          darkBottomColor: const Color(0xFF1D1320),
          child: Stack(
            children: [
              EnhancedFutureBuilder(
                future: _optionListFuture,
                rememberFutureResult: true,
                whenDone: (List<CommentaryPayload> optionList) {
                  final questionSelectionNotifiers =
                      _questionSelectionNotifiers;
                  final questionOptions = _questionOptions;
                  if (questionSelectionNotifiers == null ||
                      questionSelectionNotifiers.length != optionList.length ||
                      questionOptions.length != optionList.length) {
                    return Center(
                      child: AppLoadingIndicator(
                        color: colorScheme.primary,
                        size: 40,
                      ),
                    );
                  }

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(16, topInset + 72, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: GlassPanel(
                            style: GlassPanelStyle.hero,
                            borderRadius: BorderRadius.circular(28),
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(
                                  alpha: colorScheme.isDarkMode ? 0.16 : 0.84,
                                ),
                                accent.withValues(
                                  alpha: colorScheme.isDarkMode ? 0.12 : 0.08,
                                ),
                              ],
                            ),
                            borderColor: accent.withValues(
                              alpha: colorScheme.isDarkMode ? 0.18 : 0.14,
                            ),
                            child: Row(
                              children: [
                                const GlassIconBadge(
                                  icon: Icons.checklist_rounded,
                                  tint: accent,
                                  size: 46,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '本课程评教',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: colorScheme.onSurface,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '共 ${optionList.length} 道题',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final question = optionList[index];
                            final options = questionOptions[index];
                            final selectionNotifier =
                                questionSelectionNotifiers[index];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassPanel(
                                style: GlassPanelStyle.list,
                                borderRadius: BorderRadius.circular(24),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      question['targetName'].toString(),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: colorScheme.onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 10),
                                    ValueListenableBuilder<int>(
                                      valueListenable: selectionNotifier,
                                      builder: (
                                        context,
                                        selectedOptionIndex,
                                        child,
                                      ) {
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
                                                controlAffinity:
                                                    ListTileControlAffinity
                                                        .leading,
                                                activeColor: accent,
                                                checkColor: Colors.white,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }, childCount: optionList.length),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        sliver: SliverToBoxAdapter(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _isSubmitting,
                            child: const Text('提交'),
                            builder: (context, isSubmitting, child) {
                              return FilledButton(
                                onPressed:
                                    isSubmitting
                                        ? null
                                        : () => _handleManualSubmit(
                                          optionList.length,
                                        ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
                whenNotDone: Center(
                  child: GlassPanel(
                    style: GlassPanelStyle.hero,
                    borderRadius: BorderRadius.circular(28),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLoadingIndicator(
                          color: colorScheme.primary,
                          size: 42,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '正在加载评教题目',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: topInset + 12,
                left: 16,
                child: _CommentaryBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                top: topInset + 12,
                right: 16,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isSubmitting,
                  builder: (context, isSubmitting, child) {
                    return Opacity(
                      opacity: isSubmitting ? 0.45 : 1,
                      child: GlassPanel(
                        style: GlassPanelStyle.floating,
                        blur: 16,
                        borderRadius: BorderRadius.circular(20),
                        padding: EdgeInsets.zero,
                        onTap: isSubmitting ? null : _handleAutoSubmit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Text(
                            '一键完成',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentaryBackButton extends StatelessWidget {
  const _CommentaryBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      style: GlassPanelStyle.floating,
      blur: 16,
      borderRadius: BorderRadius.circular(20),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(
          Ionicons.chevron_back,
          color: Theme.of(context).colorScheme.onSurface,
          size: 22,
        ),
      ),
    );
  }
}
