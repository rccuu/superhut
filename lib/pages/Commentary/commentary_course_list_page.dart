import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';

import '../../core/services/app_logger.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_page_route.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/color_scheme_ext.dart';
import 'commentary_api.dart';
import 'commentary_question_page.dart';

typedef CommentaryCourseListLoader =
    Future<List<CommentaryPayload>> Function(
      String pj01id,
      String batchId,
      String pj05id,
    );
typedef CommentaryQuestionPageBuilder =
    Widget Function(CommentaryPayload commentary);
typedef CommentaryQuestionRoutePusher =
    Future<T?> Function<T>(BuildContext context, Route<T> route);

class CommentaryCourseListPage extends StatefulWidget {
  final String pj01id;
  final String batchId;
  final String pj05id;
  final CommentaryCourseListLoader? loadCommentaryItems;
  final CommentaryQuestionPageBuilder? buildQuestionPage;
  final CommentaryQuestionRoutePusher? pushRoute;

  const CommentaryCourseListPage({
    super.key,
    required this.batchId,
    required this.pj01id,
    required this.pj05id,
    this.loadCommentaryItems,
    this.buildQuestionPage,
    this.pushRoute,
  });

  @override
  State<CommentaryCourseListPage> createState() =>
      _CommentaryCourseListPageState();
}

class _CommentaryCourseListPageState extends State<CommentaryCourseListPage> {
  late final ValueNotifier<Future<List<CommentaryPayload>>>
  _commentaryItemsFutureNotifier;
  bool _isOpeningQuestionPage = false;

  @override
  void initState() {
    super.initState();
    _commentaryItemsFutureNotifier =
        ValueNotifier<Future<List<CommentaryPayload>>>(_getCommentaryItems());
  }

  @override
  void dispose() {
    _commentaryItemsFutureNotifier.dispose();
    super.dispose();
  }

  Future<List<CommentaryPayload>> _getCommentaryItems() async {
    final loader = widget.loadCommentaryItems ?? getCommentaryList;
    return loader(widget.pj01id, widget.batchId, widget.pj05id);
  }

  void _reloadCommentaryItems() {
    _commentaryItemsFutureNotifier.value = _getCommentaryItems();
  }

  Widget _buildQuestionPage(CommentaryPayload commentary) {
    final builder = widget.buildQuestionPage;
    if (builder != null) {
      return builder(commentary);
    }

    return CommentaryQuestionPage(
      batchId: widget.batchId,
      courseId: commentary['courseNumber'].toString(),
      evaluationCategoriesId: commentary['evaluationCategoriesId'].toString(),
      teacherId: commentary['teacherId'].toString(),
      noticeId: commentary['noticeId'].toString(),
    );
  }

  Future<void> _openQuestionPage(CommentaryPayload commentary) async {
    if (_isOpeningQuestionPage) {
      return;
    }

    _isOpeningQuestionPage = true;
    try {
      final pusher = widget.pushRoute ?? _pushRoute;
      final didSubmit = await pusher<bool>(
        context,
        buildAppPageRoute<bool>(builder: (_) => _buildQuestionPage(commentary)),
      );

      if (didSubmit == true && mounted) {
        _reloadCommentaryItems();
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to open commentary question page',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          message: '无法打开评教题目，请稍后重试',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _isOpeningQuestionPage = false;
    }
  }

  Future<T?> _pushRoute<T>(BuildContext context, Route<T> route) {
    return Navigator.of(context).push<T>(route);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('学生教评'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ValueListenableBuilder<Future<List<CommentaryPayload>>>(
        valueListenable: _commentaryItemsFutureNotifier,
        builder: (context, commentaryItemsFuture, _) {
          return EnhancedFutureBuilder(
            future: commentaryItemsFuture,
            rememberFutureResult: false,
            whenDone: (List<CommentaryPayload> commentaryList) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                child: ListView.builder(
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  itemCount: commentaryList.length,
                  itemBuilder: (BuildContext context, int index) {
                    final commentary = commentaryList[index];
                    final isSubmitted = commentary['isSubmitCode'] == '1';

                    return GestureDetector(
                      onTap: () async {
                        if (isSubmitted) {
                          showAppSnackBar(
                            context,
                            message: '已经评教过啦~不能重复评教',
                            type: AppSnackBarType.info,
                          );
                          return;
                        }

                        await _openQuestionPage(commentary);
                      },
                      child: Card.filled(
                        color: colorScheme.surfaceContainer,
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
                                      commentary['courseName'].toString(),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '课程编号：${commentary['courseNumber']}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.normal,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '授课教师：${commentary['teacherName']}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.normal,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Chip(
                                      label: Text(
                                        isSubmitted ? '已评教' : '未评教',
                                        style: TextStyle(
                                          color:
                                              isSubmitted
                                                  ? colorScheme
                                                      .onSuccessContainerSoft
                                                  : colorScheme
                                                      .onErrorContainer,
                                        ),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      backgroundColor:
                                          isSubmitted
                                              ? colorScheme.successContainerSoft
                                              : colorScheme.errorContainer,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            whenNotDone: Center(
              child: AppLoadingIndicator(color: colorScheme.primary, size: 40),
            ),
          );
        },
      ),
    );
  }
}
