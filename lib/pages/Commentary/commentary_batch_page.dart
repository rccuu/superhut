import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'commentary_api.dart';
import 'commentary_course_list_page.dart';

class CommentaryBatchPage extends StatefulWidget {
  const CommentaryBatchPage({super.key});

  @override
  State<CommentaryBatchPage> createState() => _CommentaryBatchPageState();
}

class _CommentaryBatchPageState extends State<CommentaryBatchPage> {
  Future<List<CommentaryPayload>> _getBatches() async {
    return getCommentaryBatches();
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
        future: _getBatches(),
        rememberFutureResult: false,
        whenDone: (List batchesList) {
          final typedBatchesList = List<CommentaryPayload>.from(batchesList);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            child: ListView.builder(
              itemCount: typedBatchesList.length,
              itemBuilder: (BuildContext context, int index) {
                final batch = typedBatchesList[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => CommentaryCourseListPage(
                              batchId: batch['BATCHID'].toString(),
                              pj01id: batch['PJ01ID'].toString(),
                              pj05id: batch['PJ05ID'].toString(),
                            ),
                      ),
                    );
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
                                  batch['EVALUATIONBATCH'].toString(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      Ionicons.location,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      batch['KCLBMC'].toString(),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.normal,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      Ionicons.calendar,
                                      size: 20,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      batch['XQMC'].toString(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.normal,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(8),
                              alignment: Alignment.center,
                              child: const Icon(Icons.arrow_forward, size: 16),
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
