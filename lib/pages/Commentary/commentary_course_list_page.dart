import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../core/ui/color_scheme_ext.dart';
import 'commentary_api.dart';
import 'commentary_question_page.dart';

class CommentaryCourseListPage extends StatefulWidget {
  final String pj01id;
  final String batchId;
  final String pj05id;

  const CommentaryCourseListPage({
    super.key,
    required this.batchId,
    required this.pj01id,
    required this.pj05id,
  });

  @override
  State<CommentaryCourseListPage> createState() =>
      _CommentaryCourseListPageState();
}

class _CommentaryCourseListPageState extends State<CommentaryCourseListPage> {
  Future<List<CommentaryPayload>> _getCommentaryItems() async {
    return getCommentaryList(widget.pj01id, widget.batchId, widget.pj05id);
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
      body: EnhancedFutureBuilder(
        future: _getCommentaryItems(),
        rememberFutureResult: false,
        whenDone: (List commentaryList) {
          final typedCommentaryList = List<CommentaryPayload>.from(
            commentaryList,
          );
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            child: ListView.builder(
              itemCount: typedCommentaryList.length,
              itemBuilder: (BuildContext context, int index) {
                final commentary = typedCommentaryList[index];
                final isSubmitted = commentary['isSubmitCode'] == '1';

                return GestureDetector(
                  onTap: () async {
                    if (isSubmitted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已经评教过啦~不能重复评教')),
                      );
                      return;
                    }

                    final didSubmit = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => CommentaryQuestionPage(
                              batchId: widget.batchId,
                              courseId: commentary['courseNumber'].toString(),
                              evaluationCategoriesId:
                                  commentary['evaluationCategoriesId']
                                      .toString(),
                              teacherId: commentary['teacherId'].toString(),
                              noticeId: commentary['noticeId'].toString(),
                            ),
                      ),
                    );

                    if (didSubmit == true && mounted) {
                      setState(() {});
                    }
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
                                              : colorScheme.onErrorContainer,
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
          child: LoadingAnimationWidget.inkDrop(
            color: colorScheme.primary,
            size: 40,
          ),
        ),
      ),
    );
  }
}
