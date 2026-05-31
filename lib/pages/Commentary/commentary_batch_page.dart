import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../core/services/app_logger.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_page_route.dart';
import '../../core/ui/app_snack_bar.dart';
import 'commentary_api.dart';
import 'commentary_course_list_page.dart';

typedef CommentaryBatchLoader = Future<List<CommentaryPayload>> Function();
typedef CommentaryCourseListPageBuilder =
    Widget Function(CommentaryPayload batch);
typedef CommentaryBatchRoutePusher =
    Future<T?> Function<T>(BuildContext context, Route<T> route);

class CommentaryBatchPage extends StatefulWidget {
  const CommentaryBatchPage({
    super.key,
    this.loadBatches,
    this.buildCoursePage,
    this.pushRoute,
  });

  final CommentaryBatchLoader? loadBatches;
  final CommentaryCourseListPageBuilder? buildCoursePage;
  final CommentaryBatchRoutePusher? pushRoute;

  @override
  State<CommentaryBatchPage> createState() => _CommentaryBatchPageState();
}

class _CommentaryBatchPageState extends State<CommentaryBatchPage> {
  late Future<List<CommentaryPayload>> _batchesFuture;
  bool _isOpeningBatch = false;

  @override
  void initState() {
    super.initState();
    _batchesFuture = _getBatches();
  }

  Future<List<CommentaryPayload>> _getBatches() async {
    return (widget.loadBatches ?? getCommentaryBatches)();
  }

  Widget _buildCoursePage(CommentaryPayload batch) {
    final builder = widget.buildCoursePage;
    if (builder != null) {
      return builder(batch);
    }

    return CommentaryCourseListPage(
      batchId: batch['BATCHID'].toString(),
      pj01id: batch['PJ01ID'].toString(),
      pj05id: batch['PJ05ID'].toString(),
    );
  }

  Future<void> _openBatch(CommentaryPayload batch) async {
    if (_isOpeningBatch) {
      return;
    }

    _isOpeningBatch = true;
    try {
      final pusher = widget.pushRoute ?? _pushRoute;
      await pusher<void>(
        context,
        buildAppPageRoute<void>(builder: (_) => _buildCoursePage(batch)),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to open commentary course list',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          message: '无法打开评教课程列表，请稍后重试',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _isOpeningBatch = false;
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
      body: EnhancedFutureBuilder(
        future: _batchesFuture,
        rememberFutureResult: false,
        whenDone: (List<CommentaryPayload> batchesList) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            child: ListView.builder(
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: false,
              itemCount: batchesList.length,
              itemBuilder: (BuildContext context, int index) {
                final batch = batchesList[index];
                return GestureDetector(
                  onTap: () => _openBatch(batch),
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
          child: AppLoadingIndicator(color: colorScheme.primary, size: 40),
        ),
      ),
    );
  }
}
