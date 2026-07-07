import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../core/services/app_logger.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_page_route.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/apple_glass.dart';
import '../../core/ui/color_scheme_ext.dart';
import 'commentary_api.dart';
import 'commentary_batch_executor.dart';
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
  const CommentaryCourseListPage({
    super.key,
    required this.batchId,
    required this.pj01id,
    required this.pj05id,
    this.loadCommentaryItems,
    this.runBatchEvaluation,
    this.buildQuestionPage,
    this.pushRoute,
  });

  final String pj01id;
  final String batchId;
  final String pj05id;
  final CommentaryCourseListLoader? loadCommentaryItems;
  final CommentaryBatchEvaluationRunner? runBatchEvaluation;
  final CommentaryQuestionPageBuilder? buildQuestionPage;
  final CommentaryQuestionRoutePusher? pushRoute;

  @override
  State<CommentaryCourseListPage> createState() =>
      _CommentaryCourseListPageState();
}

class _CommentaryCourseListPageState extends State<CommentaryCourseListPage> {
  static const Color _accent = Color(0xFFB6569C);

  late final ValueNotifier<Future<List<CommentaryPayload>>>
  _commentaryItemsFutureNotifier;
  bool _isOpeningQuestionPage = false;
  bool _isRunningBatchEvaluation = false;
  CommentaryBatchProgress? _batchProgress;

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

  Future<void> _handleBatchEvaluation(
    List<CommentaryPayload> commentaryList,
  ) async {
    if (_isRunningBatchEvaluation) {
      return;
    }

    final summary = _summarize(commentaryList);
    if (summary.pendingCount == 0) {
      showAppSnackBar(
        context,
        message: '该分类已全部评教完成',
        type: AppSnackBarType.info,
      );
      _reloadCommentaryItems();
      return;
    }

    setState(() {
      _isRunningBatchEvaluation = true;
      _batchProgress = CommentaryBatchProgress(
        completedCount: 0,
        totalCount: summary.pendingCount,
        currentCourseName: '',
      );
    });

    try {
      final runner = widget.runBatchEvaluation ?? _runBatchEvaluation;
      final result = await runner(
        batchId: widget.batchId,
        commentaryItems: commentaryList,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _batchProgress = progress;
          });
        },
      );

      if (!mounted) {
        return;
      }

      if (result.totalCount == 0) {
        showAppSnackBar(
          context,
          message: '该分类已全部评教完成',
          type: AppSnackBarType.info,
        );
      } else if (result.allSucceeded) {
        showAppSnackBar(
          context,
          message: '已完成 ${result.successCount} 门课程评教',
          type: AppSnackBarType.success,
        );
      } else if (result.allFailed) {
        showAppSnackBar(
          context,
          message: '本次未完成任何课程评教，请稍后重试',
          type: AppSnackBarType.error,
        );
      } else {
        showAppSnackBar(
          context,
          message:
              '成功 ${result.successCount} 门，失败 ${result.failureCount} 门，可继续手动处理',
          type: AppSnackBarType.warning,
        );
      }

      _reloadCommentaryItems();
    } finally {
      if (mounted) {
        setState(() {
          _isRunningBatchEvaluation = false;
          _batchProgress = null;
        });
      }
    }
  }

  Future<CommentaryBatchExecutionResult> _runBatchEvaluation({
    required String batchId,
    required List<CommentaryPayload> commentaryItems,
    CommentaryBatchProgressCallback? onProgress,
  }) {
    return runCommentaryBatchEvaluation(
      batchId: batchId,
      commentaryItems: commentaryItems,
      loadQuestions: getCommentaryQuestions,
      submitSelections: submitCommentary,
      onProgress: onProgress,
    );
  }

  _CommentaryCourseSummary _summarize(List<CommentaryPayload> commentaryList) {
    final pendingCount =
        commentaryList
            .where((item) => item['isSubmitCode']?.toString() != '1')
            .length;

    return _CommentaryCourseSummary(
      totalCount: commentaryList.length,
      pendingCount: pendingCount,
    );
  }

  Future<T?> _pushRoute<T>(BuildContext context, Route<T> route) {
    return Navigator.of(context).push<T>(route);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              ValueListenableBuilder<Future<List<CommentaryPayload>>>(
                valueListenable: _commentaryItemsFutureNotifier,
                builder: (context, commentaryItemsFuture, _) {
                  return EnhancedFutureBuilder(
                    future: commentaryItemsFuture,
                    rememberFutureResult: false,
                    whenDone: (List<CommentaryPayload> commentaryList) {
                      final summary = _summarize(commentaryList);
                      final progress = _batchProgress;

                      return CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              topInset + 72,
                              16,
                              0,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _CommentaryCourseOverviewCard(
                                accent: _accent,
                                totalCount: summary.totalCount,
                                pendingCount: summary.pendingCount,
                                submittedCount: summary.submittedCount,
                                progressLabel:
                                    _isRunningBatchEvaluation &&
                                            progress != null
                                        ? '${progress.completedCount} / ${progress.totalCount}'
                                        : null,
                                currentCourseName:
                                    _isRunningBatchEvaluation &&
                                            progress != null &&
                                            progress
                                                .currentCourseName
                                                .isNotEmpty
                                        ? progress.currentCourseName
                                        : null,
                                onBatch:
                                    _isRunningBatchEvaluation
                                        ? null
                                        : () => _handleBatchEvaluation(
                                          commentaryList,
                                        ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                            sliver: SliverToBoxAdapter(
                              child: _CommentarySectionHeader(
                                title: '课程列表',
                                subtitle: '${summary.totalCount} 门总计',
                              ),
                            ),
                          ),
                          if (commentaryList.isEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: _CommentaryEmptyState(
                                  title: '当前分类暂无课程',
                                  subtitle: '如果教务系统稍后同步课程，这里会自动展示。',
                                  accent: _accent,
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              sliver: SliverList.builder(
                                itemCount: commentaryList.length,
                                addRepaintBoundaries: false,
                                itemBuilder: (context, index) {
                                  final commentary = commentaryList[index];
                                  final isSubmitted =
                                      commentary['isSubmitCode']?.toString() ==
                                      '1';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _CommentaryCourseCard(
                                      commentary: commentary,
                                      accent: _accent,
                                      isSubmitted: isSubmitted,
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
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 28)),
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
                              '正在整理课程评教状态',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: topInset + 12,
                left: 16,
                child: _CommentaryBackButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentaryCourseSummary {
  const _CommentaryCourseSummary({
    required this.totalCount,
    required this.pendingCount,
  });

  final int totalCount;
  final int pendingCount;

  int get submittedCount => totalCount - pendingCount;
}

class _CommentaryCourseOverviewCard extends StatelessWidget {
  const _CommentaryCourseOverviewCard({
    required this.accent,
    required this.totalCount,
    required this.pendingCount,
    required this.submittedCount,
    this.progressLabel,
    this.currentCourseName,
    this.onBatch,
  });

  final Color accent;
  final int totalCount;
  final int pendingCount;
  final int submittedCount;
  final String? progressLabel;
  final String? currentCourseName;
  final VoidCallback? onBatch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.hero,
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassIconBadge(icon: Ionicons.book_outline, tint: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '课程评教',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '保持单门进入能力，同时支持本分类一键完成全部未评课程。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const GlassHairlineDivider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CommentaryMetricChip(
                  label: '待处理',
                  value: '$pendingCount 门未评',
                  tint: colorScheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CommentaryMetricChip(
                  label: '已完成',
                  value: '$submittedCount / $totalCount 门',
                  tint: colorScheme.success,
                ),
              ),
            ],
          ),
          if (progressLabel != null) ...[
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        currentCourseName == null
                            ? progressLabel!
                            : '$progressLabel · $currentCourseName',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBatch,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(progressLabel != null ? '处理中...' : '一键评完本分类'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentaryMetricChip extends StatelessWidget {
  const _CommentaryMetricChip({
    required this.label,
    required this.value,
    required this.tint,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: tint,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentarySectionHeader extends StatelessWidget {
  const _CommentarySectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentaryCourseCard extends StatelessWidget {
  const _CommentaryCourseCard({
    required this.commentary,
    required this.accent,
    required this.isSubmitted,
    required this.onTap,
  });

  final CommentaryPayload commentary;
  final Color accent;
  final bool isSubmitted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusTint = isSubmitted ? colorScheme.success : colorScheme.warning;

    return GlassPanel(
      style: GlassPanelStyle.card,
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      commentary['courseName']?.toString() ?? '未命名课程',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '课程编号：${commentary['courseNumber']}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CommentaryInfoPill(
                icon: Ionicons.person_outline,
                label: '授课教师：${commentary['teacherName']}',
              ),
              _CommentaryInfoPill(
                icon: Ionicons.ribbon_outline,
                label: isSubmitted ? '已评教' : '未评教',
                tint: statusTint,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentaryInfoPill extends StatelessWidget {
  const _CommentaryInfoPill({
    required this.icon,
    required this.label,
    this.tint,
  });

  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedTint = tint ?? colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedTint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: resolvedTint),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentaryEmptyState extends StatelessWidget {
  const _CommentaryEmptyState({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.hero,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(
        children: [
          GlassIconBadge(
            icon: Ionicons.information_circle_outline,
            tint: accent,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
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
