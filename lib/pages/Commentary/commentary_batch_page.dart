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
import 'commentary_course_list_page.dart';

typedef CommentaryBatchLoader = Future<List<CommentaryPayload>> Function();
typedef CommentaryBatchItemsLoader =
    Future<List<CommentaryPayload>> Function(
      String pj01id,
      String batchId,
      String pj05id,
    );
typedef CommentaryCourseListPageBuilder =
    Widget Function(CommentaryPayload batch);
typedef CommentaryBatchRoutePusher =
    Future<T?> Function<T>(BuildContext context, Route<T> route);

class CommentaryBatchPage extends StatefulWidget {
  const CommentaryBatchPage({
    super.key,
    this.loadBatches,
    this.loadCommentaryItems,
    this.runBatchEvaluation,
    this.buildCoursePage,
    this.pushRoute,
  });

  final CommentaryBatchLoader? loadBatches;
  final CommentaryBatchItemsLoader? loadCommentaryItems;
  final CommentaryBatchEvaluationRunner? runBatchEvaluation;
  final CommentaryCourseListPageBuilder? buildCoursePage;
  final CommentaryBatchRoutePusher? pushRoute;

  @override
  State<CommentaryBatchPage> createState() => _CommentaryBatchPageState();
}

class _CommentaryBatchPageState extends State<CommentaryBatchPage> {
  late Future<List<CommentaryPayload>> _batchesFuture;
  List<_CommentaryBatchCardData> _batchCards =
      const <_CommentaryBatchCardData>[];
  String? _batchLoadErrorMessage;
  bool _isOpeningBatch = false;
  String? _runningBatchId;
  CommentaryBatchProgress? _batchProgress;

  @override
  void initState() {
    super.initState();
    _batchesFuture = _getBatches();
  }

  Future<List<CommentaryPayload>> _getBatches() async {
    try {
      final batches = await (widget.loadBatches ?? getCommentaryBatches)();
      final itemsLoader = widget.loadCommentaryItems ?? getCommentaryList;
      final cards = await Future.wait(
        batches.map((batch) async {
          final commentaryItems = await itemsLoader(
            batch['PJ01ID'].toString(),
            batch['BATCHID'].toString(),
            batch['PJ05ID'].toString(),
          );
          return _CommentaryBatchCardData(
            batch: batch,
            commentaryItems: commentaryItems,
          );
        }),
      );

      _batchCards = List<_CommentaryBatchCardData>.unmodifiable(cards);
      _batchLoadErrorMessage = null;
      return batches;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load commentary batches',
        error: error,
        stackTrace: stackTrace,
      );
      _batchCards = const <_CommentaryBatchCardData>[];
      _batchLoadErrorMessage = '请稍后重试';
      return const <CommentaryPayload>[];
    }
  }

  void _reloadBatches() {
    setState(() {
      _batchCards = const <_CommentaryBatchCardData>[];
      _batchLoadErrorMessage = null;
      _batchesFuture = _getBatches();
    });
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

  Future<void> _handleBatchEvaluation(_CommentaryBatchCardData card) async {
    if (_runningBatchId != null) {
      return;
    }

    if (card.pendingItems.isEmpty) {
      showAppSnackBar(
        context,
        message: '该分类已全部评教完成',
        type: AppSnackBarType.info,
      );
      _reloadBatches();
      return;
    }

    setState(() {
      _runningBatchId = card.batchId;
      _batchProgress = CommentaryBatchProgress(
        completedCount: 0,
        totalCount: card.pendingCount,
        currentCourseName: '',
      );
    });

    try {
      final runner = widget.runBatchEvaluation ?? _runBatchEvaluation;
      final result = await runner(
        batchId: card.batchId,
        commentaryItems: card.commentaryItems,
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
              '成功 ${result.successCount} 门，失败 ${result.failureCount} 门，可进入课程列表继续处理',
          type: AppSnackBarType.warning,
        );
      }

      _reloadBatches();
    } finally {
      if (mounted) {
        setState(() {
          _runningBatchId = null;
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

  Future<T?> _pushRoute<T>(BuildContext context, Route<T> route) {
    return Navigator.of(context).push<T>(route);
  }

  _CommentaryBatchCardData _cardForBatch(
    List<_CommentaryBatchCardData> cards,
    CommentaryPayload batch,
    int index,
  ) {
    if (index < cards.length && identical(cards[index].batch, batch)) {
      return cards[index];
    }

    return _CommentaryBatchCardData(
      batch: batch,
      commentaryItems: const <CommentaryPayload>[],
    );
  }

  int _totalPendingCount(List<_CommentaryBatchCardData> cards) {
    var count = 0;
    for (final card in cards) {
      count += card.pendingCount;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
                future: _batchesFuture,
                rememberFutureResult: false,
                whenDone: (List<CommentaryPayload> batchesList) {
                  final cards = _batchCards;
                  final errorMessage = _batchLoadErrorMessage;
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(16, topInset + 24, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: _CommentaryPageHeader(
                            categoryCount: batchesList.length,
                            pendingCount: _totalPendingCount(cards),
                            accent: accent,
                          ),
                        ),
                      ),
                      if (errorMessage != null)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                          sliver: SliverToBoxAdapter(
                            child: _CommentaryEmptyState(
                              title: '评教批次加载失败',
                              subtitle: errorMessage,
                              accent: accent,
                            ),
                          ),
                        )
                      else if (batchesList.isEmpty)
                        const SliverPadding(
                          padding: EdgeInsets.fromLTRB(16, 18, 16, 24),
                          sliver: SliverToBoxAdapter(
                            child: _CommentaryEmptyState(
                              title: '当前暂无可评教批次',
                              subtitle: '如果教务系统稍后开放评教，这里会同步展示。',
                              accent: accent,
                            ),
                          ),
                        )
                      else ...[
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                          sliver: SliverToBoxAdapter(
                            child: _CommentarySectionHeader(
                              title: '评教分类',
                              subtitle: '${batchesList.length} 个分类',
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList.builder(
                            itemCount: batchesList.length,
                            addRepaintBoundaries: false,
                            itemBuilder: (context, index) {
                              final batch = batchesList[index];
                              final card = _cardForBatch(cards, batch, index);
                              final isRunning = _runningBatchId == card.batchId;
                              final progress = _batchProgress;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _CommentaryBatchCard(
                                  data: card,
                                  accent: accent,
                                  isBusy: isRunning,
                                  progressLabel:
                                      isRunning && progress != null
                                          ? '${progress.completedCount} / ${progress.totalCount}'
                                          : null,
                                  onOpen:
                                      isRunning
                                          ? null
                                          : () => _openBatch(card.batch),
                                  onBatch:
                                      isRunning
                                          ? null
                                          : () => _handleBatchEvaluation(card),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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
                          '正在整理评教批次',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentaryBatchCardData {
  const _CommentaryBatchCardData({
    required this.batch,
    required this.commentaryItems,
  });

  final CommentaryPayload batch;
  final List<CommentaryPayload> commentaryItems;

  String get batchId => batch['BATCHID'].toString();
  String get title => batch['EVALUATIONBATCH']?.toString() ?? '未命名批次';
  String get categoryName => batch['KCLBMC']?.toString() ?? '未命名分类';
  String get termName => batch['XQMC']?.toString() ?? '未知学期';
  int get totalCount => commentaryItems.length;
  List<CommentaryPayload> get pendingItems => commentaryItems
      .where((item) => item['isSubmitCode']?.toString() != '1')
      .toList(growable: false);
  int get pendingCount => pendingItems.length;
}

class _CommentaryPageHeader extends StatelessWidget {
  const _CommentaryPageHeader({
    required this.categoryCount,
    required this.pendingCount,
    required this.accent,
  });

  final int categoryCount;
  final int pendingCount;
  final Color accent;

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
              GlassIconBadge(icon: Ionicons.reader_outline, tint: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '学生评教',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '按分类进入，支持一键完成当前分类未评课程。',
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
                  label: '评教分类',
                  value: '已开放 $categoryCount 类',
                  tint: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CommentaryMetricChip(
                  label: '待处理',
                  value: '共 $pendingCount 门未评课程',
                  tint: colorScheme.warning,
                ),
              ),
            ],
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

class _CommentaryBatchCard extends StatelessWidget {
  const _CommentaryBatchCard({
    required this.data,
    required this.accent,
    required this.onOpen,
    required this.onBatch,
    this.isBusy = false,
    this.progressLabel,
  });

  final _CommentaryBatchCardData data;
  final Color accent;
  final VoidCallback? onOpen;
  final VoidCallback? onBatch;
  final bool isBusy;
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pendingLabel =
        data.pendingCount == 0 ? '全部已评' : '${data.pendingCount} 门待评';

    return GlassPanel(
      style: GlassPanelStyle.card,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      onTap: onOpen,
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
                      data.categoryName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.title,
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
                icon: Ionicons.calendar_outline,
                label: data.termName,
              ),
              _CommentaryInfoPill(
                icon: Ionicons.layers_outline,
                label: '${data.totalCount} 门课程',
              ),
              _CommentaryInfoPill(
                icon: Ionicons.alert_circle_outline,
                label: pendingLabel,
                tint:
                    data.pendingCount == 0
                        ? colorScheme.success
                        : colorScheme.warning,
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
                    Text(
                      progressLabel!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
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
              child: Text(isBusy ? '处理中...' : '一键评完'),
            ),
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
