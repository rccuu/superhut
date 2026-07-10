import 'dart:async';
import 'dart:math' show min;

import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../core/services/app_auth_storage.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/score_semester_cache.dart';
import '../../core/ui/app_bottom_sheet.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/apple_glass.dart';
import '../../core/ui/color_scheme_ext.dart';
import 'logic.dart';

typedef ScoreSemesterLoader = Future<SemesterListResult> Function();
typedef ScoreResultLoader =
    Future<ScoreLoadResult> Function(String semesterId, {bool persistSummary});
typedef ScoreBottomSheetPresenter =
    Future<T?> Function<T>({
      required BuildContext context,
      required WidgetBuilder builder,
      bool expand,
      Color? backgroundColor,
      Color? barrierColor,
      Color? transitionBackgroundColor,
      Radius? topRadius,
      BoxShadow? shadow,
    });

({String startYear, String endYear, String term})?
_parseSemesterLabelPartsStatic(String value) {
  var firstDash = -1;
  var secondDash = -1;
  for (var index = 0; index < value.length; index++) {
    if (value.codeUnitAt(index) != 0x2D) {
      continue;
    }
    if (firstDash == -1) {
      firstDash = index;
    } else if (secondDash == -1) {
      secondDash = index;
    } else {
      return null;
    }
  }

  if (firstDash == -1 || secondDash == -1) {
    return null;
  }

  return (
    startYear: value.substring(0, firstDash),
    endYear: value.substring(firstDash + 1, secondDash),
    term: value.substring(secondDash + 1),
  );
}

@visibleForTesting
bool debugIsRegularTermSemester(String id) {
  final parts = _parseSemesterLabelPartsStatic(id);
  if (parts == null) return false;
  return parts.term == '1' || parts.term == '2';
}

class ScorePage extends StatefulWidget {
  const ScorePage({
    super.key,
    this.loadSemesters,
    this.loadScore,
    this.showBottomSheet,
  });

  final ScoreSemesterLoader? loadSemesters;
  final ScoreResultLoader? loadScore;
  final ScoreBottomSheetPresenter? showBottomSheet;

  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  static const Color _scoreAccent = Color(0xFF22966C);

  List<String> semesterId = [];
  String nowSemesterId = 'all';
  List<Score> scoreList = [];
  String zxf = '-';
  String zxfjd = '-';
  String pjjd = '-';
  String selectedId = 'all';
  bool first = true;
  bool _isRefreshingSelection = false;
  bool _isSemesterPickerOpen = false;
  bool _isScoreDetailOpen = false;
  String? _errorMessage;
  final Map<String, ScoreLoadResult> _scoreCache = <String, ScoreLoadResult>{};
  final Map<_ScoreLoadKey, Future<ScoreLoadResult>> _scoreLoads =
      <_ScoreLoadKey, Future<ScoreLoadResult>>{};
  final ValueNotifier<_ScoreContentState> _contentStateNotifier =
      ValueNotifier<_ScoreContentState>(const _ScoreContentState.initial());
  final ValueNotifier<_ScoreSelectionState> _selectionStateNotifier =
      ValueNotifier<_ScoreSelectionState>(
        const _ScoreSelectionState(selectedId: 'all', isRefreshing: false),
      );
  bool _isSemesterProbeStarted = false;
  int _selectionRefreshGeneration = 0;
  late final Future<void> _initialScoreFuture = getTimeList();

  Future<String> _resolveUserId() async {
    return AppAuthStorage.instance.readJwxtUsername();
  }

  @override
  void dispose() {
    _contentStateNotifier.dispose();
    _selectionStateNotifier.dispose();
    super.dispose();
  }

  void _assignScoreData(ScoreLoadResult scoreData, {String? semesterId}) {
    if (semesterId != null) {
      selectedId = semesterId;
    }
    scoreList = scoreData.achievement;
    zxf = scoreData.yxzxf;
    zxfjd = scoreData.zxfjd;
    pjjd = scoreData.pjxfjd;
    _errorMessage = scoreData.errorMessage;
  }

  void _setScoreData(ScoreLoadResult scoreData, {String? semesterId}) {
    _assignScoreData(scoreData, semesterId: semesterId);
    _syncScoreContentState();
    _syncSelectionState();
  }

  void _syncScoreContentState() {
    final nextState = _ScoreContentState(
      selectedId: selectedId,
      scoreList: scoreList,
      zxf: zxf,
      zxfjd: zxfjd,
      pjjd: pjjd,
      errorMessage: _errorMessage,
    );
    if (_contentStateNotifier.value == nextState) {
      return;
    }

    _contentStateNotifier.value = nextState;
  }

  void _syncSelectionState() {
    final nextState = _ScoreSelectionState(
      selectedId: selectedId,
      isRefreshing: _isRefreshingSelection,
    );
    if (_selectionStateNotifier.value == nextState) {
      return;
    }

    _selectionStateNotifier.value = nextState;
  }

  Future<void> _refreshScoresForSelection(String semesterId) async {
    if (semesterId == selectedId) {
      return;
    }

    final generation = ++_selectionRefreshGeneration;
    final cached = _scoreCache[semesterId];
    if (cached != null) {
      _isRefreshingSelection = false;
      _assignScoreData(cached, semesterId: semesterId);
      _syncScoreContentState();
      _syncSelectionState();
      return;
    }

    selectedId = semesterId;
    _isRefreshingSelection = true;
    _syncSelectionState();

    final ScoreLoadResult scoreData;
    try {
      scoreData = await _loadScoreForSemester(semesterId);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to refresh score selection',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted || generation != _selectionRefreshGeneration) {
        return;
      }
      _isRefreshingSelection = false;
      _assignScoreData(
        const ScoreLoadResult(
          achievement: [],
          yxzxf: '-',
          zxfjd: '-',
          pjxfjd: '-',
          errorMessage: '成绩加载失败，请稍后重试',
        ),
        semesterId: semesterId,
      );
      _syncScoreContentState();
      _syncSelectionState();
      showAppSnackBar(
        context,
        message: '成绩加载失败，请稍后重试',
        type: AppSnackBarType.error,
      );
      return;
    }
    if (!mounted || generation != _selectionRefreshGeneration) {
      return;
    }

    _isRefreshingSelection = false;
    _assignScoreData(scoreData, semesterId: semesterId);
    _syncScoreContentState();
    _syncSelectionState();
    unawaited(_resolveUserId().then(_writeCacheSnapshot));
  }

  Future<ScoreLoadResult> _loadScoreForSemester(
    String semesterId, {
    bool persistSummary = true,
  }) async {
    final cached = _scoreCache[semesterId];
    if (cached != null) {
      return cached;
    }

    final loadKey = _ScoreLoadKey(
      semesterId: semesterId,
      persistSummary: persistSummary,
    );
    final inFlight = _scoreLoads[loadKey];
    if (inFlight != null) {
      return inFlight;
    }

    final load = _loadAndCacheScoreForSemester(
      semesterId,
      persistSummary: persistSummary,
    );
    _scoreLoads[loadKey] = load;
    try {
      return await load;
    } finally {
      if (identical(_scoreLoads[loadKey], load)) {
        _scoreLoads.remove(loadKey);
      }
    }
  }

  Future<ScoreLoadResult> _loadAndCacheScoreForSemester(
    String semesterId, {
    required bool persistSummary,
  }) async {
    final scoreData = await (widget.loadScore ?? getScore)(
      semesterId == 'all' ? '' : semesterId,
      persistSummary: persistSummary,
    );
    if (mounted) {
      _scoreCache[semesterId] = scoreData;
    }
    return scoreData;
  }

  Future<bool> _probeSemesterKeep(String id, {int maxRetries = 2}) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (!mounted) return true;
      ScoreLoadResult? result;
      try {
        result = await _loadScoreForSemester(id, persistSummary: false);
      } catch (error, stackTrace) {
        AppLogger.error(
          'Failed to probe score data for semester $id (attempt $attempt)',
          error: error,
          stackTrace: stackTrace,
        );
        if (attempt == maxRetries) return true; // 重试耗尽 → 保留
        continue; // 否则重试
      }
      if (!mounted) return true;
      if (result.errorMessage != null) return true; // 业务失败 → 保留
      return result.achievement.isNotEmpty; // 成功：非空保留，空剔除
    }
    // 不可达：循环必在任一分支返回
    return true;
  }

  bool _isRegularTermSemesterStatic(String id) =>
      debugIsRegularTermSemester(id);

  Future<List<String>> _probeRegularSemesters(List<String> ids) async {
    if (ids.isEmpty) return const <String>[];
    const int fullConcurrencyThreshold = 6;
    const int poolSize = 6;

    if (ids.length <= fullConcurrencyThreshold) {
      return _probeKeepAll(ids);
    }

    final kept = <String>[];
    for (var i = 0; i < ids.length; i += poolSize) {
      if (!mounted) return kept;
      final batch = ids.sublist(i, min(i + poolSize, ids.length));
      kept.addAll(await _probeKeepAll(batch));
    }
    return kept;
  }

  Future<List<String>> _probeKeepAll(List<String> ids) async {
    final results = await Future.wait(ids.map((id) => _probeSemesterKeep(id)));
    return [
      for (var i = 0; i < ids.length; i++)
        if (results[i]) ids[i],
    ];
  }

  @visibleForTesting
  Future<ScoreLoadResult> debugLoadScoreForSemester(
    String semesterId, {
    bool persistSummary = true,
  }) {
    return _loadScoreForSemester(semesterId, persistSummary: persistSummary);
  }

  @visibleForTesting
  Future<void> debugRefreshScoresForSelection(String semesterId) {
    return _refreshScoresForSelection(semesterId);
  }

  @visibleForTesting
  Future<bool> debugProbeSemesterKeep(String id, {int maxRetries = 2}) {
    return _probeSemesterKeep(id, maxRetries: maxRetries);
  }

  @visibleForTesting
  Future<List<String>> debugProbeRegularSemesters(List<String> ids) {
    return _probeRegularSemesters(ids);
  }

  @visibleForTesting
  Future<List<String>> debugProbeAvailableSemesters(List<String> ids) async {
    // 复用与 _probeAvailableSemesters 相同的纯过滤+探测管线，
    // 但不写回 semesterId / 不触发 UI 同步，不持有 _isSemesterProbeStarted 锁，
    // 便于测试直接断言探测结果。
    if (ids.isEmpty) return const <String>[];
    final regularIds = ids.where(_isRegularTermSemesterStatic).toList();
    return _probeRegularSemesters(regularIds);
  }

  Future<void> _probeAvailableSemesters(List<String> semesterIds) async {
    if (_isSemesterProbeStarted) {
      return;
    }
    _isSemesterProbeStarted = true;

    final regularIds = semesterIds.where(_isRegularTermSemesterStatic).toList();
    final keptIds = await _probeRegularSemesters(regularIds);
    if (!mounted) {
      return;
    }

    final filteredSemesterIds = keptIds;

    final shouldResetSelection =
        selectedId != 'all' && !filteredSemesterIds.contains(selectedId);
    if (!shouldResetSelection && listEquals(semesterId, filteredSemesterIds)) {
      return;
    }

    final cachedAllScoreData = shouldResetSelection ? _scoreCache['all'] : null;
    if (cachedAllScoreData != null) {
      semesterId = filteredSemesterIds;
      _assignScoreData(cachedAllScoreData, semesterId: 'all');
      _syncScoreContentState();
      _syncSelectionState();
      return;
    }

    semesterId = filteredSemesterIds;
    if (shouldResetSelection) {
      selectedId = 'all';
      _syncScoreContentState();
      _syncSelectionState();
    }

    if (!shouldResetSelection) {
      return;
    }

    final allScoreData = await _loadScoreForSemester('all');
    if (!mounted || selectedId != 'all') {
      return;
    }
    _setScoreData(allScoreData, semesterId: 'all');

    // 探测完毕，持久化结果
    final cacheUserId = await _resolveUserId();
    await _writeCacheSnapshot(cacheUserId);
  }

  Future<void> getTimeList() async {
    if (!first) {
      return;
    }

    final userId = await _resolveUserId();
    final cached =
        userId.isNotEmpty
            ? await ScoreSemesterCache.instance.read(userId)
            : null;

    if (cached != null) {
      semesterId = cached.semesterIds;
      nowSemesterId =
          cached.nowSemesterId.isEmpty ? 'all' : cached.nowSemesterId;
      selectedId = cached.selectedId;
      zxf = cached.zxf;
      zxfjd = cached.zxfjd;
      pjjd = cached.pjjd;
      first = false;
      _syncScoreContentState();
      _syncSelectionState();
      unawaited(_backgroundRefresh(userId));
      return;
    }

    final timeData = await (widget.loadSemesters ?? semesterIdfc)();
    if (!mounted) {
      return;
    }
    if (timeData.errorMessage != null) {
      semesterId = timeData.idList;
      nowSemesterId = timeData.nowId.isEmpty ? 'all' : timeData.nowId;
      _errorMessage = timeData.errorMessage;
      selectedId = 'all';
      first = false;
      _syncScoreContentState();
      _syncSelectionState();
      return;
    }

    final scoreData = await _loadScoreForSemester('all');
    if (!mounted) {
      return;
    }

    semesterId = timeData.idList;
    nowSemesterId = timeData.nowId.isEmpty ? 'all' : timeData.nowId;
    selectedId = 'all';
    _assignScoreData(scoreData, semesterId: 'all');
    first = false;
    _syncScoreContentState();
    _syncSelectionState();
    unawaited(_probeAvailableSemesters(timeData.idList));
  }

  Future<void> _backgroundRefresh(String userId) async {
    try {
      final timeData = await (widget.loadSemesters ?? semesterIdfc)();
      if (!mounted) return;
      if (timeData.errorMessage != null) return;

      await _loadScoreForSemester('all');
      if (!mounted) return;

      await _probeAvailableSemesters(timeData.idList);
      if (!mounted) return;

      await _writeCacheSnapshot(userId);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Background score refresh failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _writeCacheSnapshot(String userId) async {
    if (userId.isEmpty) return;

    await ScoreSemesterCache.instance.write(
      userId,
      ScoreSemesterCacheData(
        semesterIds: semesterId,
        selectedId: selectedId,
        nowSemesterId: nowSemesterId,
        zxf: zxf,
        zxfjd: zxfjd,
        pjjd: pjjd,
        courseCount: scoreList.length,
      ),
    );
  }

  String _formatSemesterLabel(String value) {
    final parts = _parseSemesterLabelParts(value);
    if (parts == null) {
      return value;
    }

    final termLabel = switch (parts.term) {
      '1' => '上学期',
      '2' => '下学期',
      _ => '${parts.term}学期',
    };
    return '${parts.startYear}-${parts.endYear} · $termLabel';
  }

  String _compactSemesterLabel(String value) {
    if (value == 'all') {
      return '全部学期';
    }

    final parts = _parseSemesterLabelParts(value);
    if (parts == null) {
      return value;
    }

    final termLabel = switch (parts.term) {
      '1' => '上',
      '2' => '下',
      _ => parts.term,
    };
    return '${parts.startYear}-${parts.endYear} $termLabel';
  }

  ({String startYear, String endYear, String term})? _parseSemesterLabelParts(
    String value,
  ) => _parseSemesterLabelPartsStatic(value);

  double? _numericFraction(String text) {
    StringBuffer? normalizedBuffer;
    for (var index = 0; index < text.length; index++) {
      final codeUnit = text.codeUnitAt(index);
      final isNumeric = codeUnit >= 0x30 && codeUnit <= 0x39;
      final isDecimalPoint = codeUnit == 0x2E;
      if (isNumeric || isDecimalPoint) {
        normalizedBuffer?.writeCharCode(codeUnit);
        continue;
      }

      normalizedBuffer ??=
          index == 0 ? StringBuffer() : StringBuffer(text.substring(0, index));
    }

    if (normalizedBuffer == null) {
      return text.isEmpty ? null : double.tryParse(text);
    }

    final normalized = normalizedBuffer.toString();
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  _ScorePalette _paletteForScore(BuildContext context, Score score) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = _numericFraction(score.fraction);

    if (value == null) {
      return _ScorePalette(
        accent: colorScheme.primary,
        badgeBackground: colorScheme.primaryContainer.withValues(alpha: 0.88),
        badgeForeground: colorScheme.onPrimaryContainer,
        panelTint: colorScheme.primary.withValues(
          alpha: colorScheme.isDarkMode ? 0.10 : 0.05,
        ),
      );
    }
    if (value >= 90) {
      return _ScorePalette(
        accent: colorScheme.success,
        badgeBackground: colorScheme.successContainerSoft,
        badgeForeground: colorScheme.onSuccessContainerSoft,
        panelTint: colorScheme.success.withValues(
          alpha: colorScheme.isDarkMode ? 0.12 : 0.06,
        ),
      );
    }
    if (value >= 80) {
      return _ScorePalette(
        accent: _scoreAccent,
        badgeBackground: _scoreAccent.withValues(
          alpha: colorScheme.isDarkMode ? 0.20 : 0.14,
        ),
        badgeForeground:
            colorScheme.isDarkMode ? Colors.white : const Color(0xFF114934),
        panelTint: _scoreAccent.withValues(
          alpha: colorScheme.isDarkMode ? 0.12 : 0.06,
        ),
      );
    }
    if (value >= 60) {
      return _ScorePalette(
        accent: colorScheme.warning,
        badgeBackground: colorScheme.warningContainerSoft,
        badgeForeground: colorScheme.onWarningContainerSoft,
        panelTint: colorScheme.warning.withValues(
          alpha: colorScheme.isDarkMode ? 0.12 : 0.06,
        ),
      );
    }
    return _ScorePalette(
      accent: colorScheme.error,
      badgeBackground: colorScheme.errorContainer,
      badgeForeground: colorScheme.onErrorContainer,
      panelTint: colorScheme.error.withValues(
        alpha: colorScheme.isDarkMode ? 0.12 : 0.06,
      ),
    );
  }

  Future<T?> _showScoreSheet<T>({
    required WidgetBuilder builder,
    Color? backgroundColor,
  }) {
    final presenter = widget.showBottomSheet ?? showAppAdaptiveBottomSheet;
    return presenter<T>(
      context: context,
      backgroundColor: backgroundColor,
      builder: builder,
    );
  }

  void _showScoreDetail(Score score) {
    if (_isScoreDetailOpen) {
      return;
    }

    _isScoreDetailOpen = true;
    final sheet = _showScoreSheet<void>(
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ScoreDetailSheet(
          score: score,
          palette: _paletteForScore(context, score),
        );
      },
    );
    unawaited(_trackScoreDetailSheet(sheet));
  }

  Future<void> _trackScoreDetailSheet(Future<void> sheet) async {
    try {
      await sheet;
    } finally {
      _isScoreDetailOpen = false;
    }
  }

  Future<void> _showSemesterPicker() async {
    if (_isSemesterPickerOpen) {
      return;
    }

    _isSemesterPickerOpen = true;
    final String? result;
    try {
      result = await _showScoreSheet<String>(
        backgroundColor: Colors.transparent,
        builder: (context) {
          return _SemesterPickerSheet(
            accent: _scoreAccent,
            semesterIds: semesterId,
            selectedId: selectedId,
            formatSemesterLabel: _formatSemesterLabel,
          );
        },
      );
    } finally {
      _isSemesterPickerOpen = false;
    }

    if (!mounted || result == null || result == selectedId) {
      return;
    }
    await _refreshScoresForSelection(result);
  }

  @override
  Widget build(BuildContext context) {
    return EnhancedFutureBuilder(
      future: _initialScoreFuture,
      rememberFutureResult: true,
      whenDone: (_) => _buildScaffold(context),
      whenNotDone: _buildLoadingScaffold(context),
    );
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        style: AppGlassBackgroundStyle.soft,
        child: Stack(
          children: [
            Center(
              child: GlassPanel(
                style: GlassPanelStyle.hero,
                borderRadius: BorderRadius.circular(28),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 24,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.78),
                    _scoreAccent.withValues(alpha: 0.10),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLoadingIndicator(color: _scoreAccent, size: 42),
                    const SizedBox(height: 16),
                    Text(
                      '正在整理成绩档案',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '首次打开会同步学期与成绩信息',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: topInset + 12,
              left: 16,
              child: _FeatureBackButton(
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        style: AppGlassBackgroundStyle.soft,
        child: Stack(
          children: [
            ValueListenableBuilder<_ScoreContentState>(
              valueListenable: _contentStateNotifier,
              builder: (context, contentState, _) {
                return _buildScoreContentScrollView(
                  context,
                  topInset: topInset,
                  contentState: contentState,
                );
              },
            ),
            Positioned(
              top: topInset + 12,
              left: 16,
              child: _FeatureBackButton(
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            Positioned(
              top: topInset + 12,
              right: 16,
              child: ValueListenableBuilder<_ScoreSelectionState>(
                valueListenable: _selectionStateNotifier,
                builder: (context, selectionState, _) {
                  return _SemesterSelectorButton(
                    accent: _scoreAccent,
                    selectedLabel: _compactSemesterLabel(
                      selectionState.selectedId,
                    ),
                    isRefreshing: selectionState.isRefreshing,
                    onTap: _showSemesterPicker,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreContentScrollView(
    BuildContext context, {
    required double topInset,
    required _ScoreContentState contentState,
  }) {
    final scoreList = contentState.scoreList;
    final errorMessage = contentState.errorMessage;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, topInset + 76, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ScoreOverviewCard(
                  accent: _scoreAccent,
                  zxf: contentState.zxf,
                  zxfjd: contentState.zxfjd,
                  pjjd: contentState.pjjd,
                  courseCount: scoreList.length,
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: '课程成绩',
                  subtitle:
                      errorMessage != null
                          ? '当前结果未能正常加载'
                          : scoreList.isEmpty
                          ? '暂无成绩记录'
                          : '共 ${scoreList.length} 门课程',
                ),
                const SizedBox(height: 8),
                if (errorMessage != null)
                  _FeatureEmptyState(
                    icon: Ionicons.alert_circle_outline,
                    accent: Theme.of(context).colorScheme.error,
                    title: '成绩加载失败',
                    subtitle: errorMessage,
                  )
                else if (scoreList.isEmpty)
                  _FeatureEmptyState(
                    icon: Ionicons.receipt_outline,
                    accent: _scoreAccent,
                    title: '还没有成绩记录',
                    subtitle:
                        contentState.selectedId == 'all'
                            ? '当前账号暂未查询到任何成绩。'
                            : '这个学期目前没有可展示的成绩条目。',
                  ),
              ],
            ),
          ),
        ),
        if (errorMessage == null && scoreList.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final score = scoreList[index];
                  final palette = _paletteForScore(context, score);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ScoreCourseCard(
                      score: score,
                      palette: palette,
                      onTap: () => _showScoreDetail(score),
                    ),
                  );
                },
                childCount: scoreList.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}

class _ScoreLoadKey {
  const _ScoreLoadKey({required this.semesterId, required this.persistSummary});

  final String semesterId;
  final bool persistSummary;

  @override
  bool operator ==(Object other) {
    return other is _ScoreLoadKey &&
        other.semesterId == semesterId &&
        other.persistSummary == persistSummary;
  }

  @override
  int get hashCode => Object.hash(semesterId, persistSummary);
}

class _ScoreContentState {
  const _ScoreContentState({
    required this.selectedId,
    required this.scoreList,
    required this.zxf,
    required this.zxfjd,
    required this.pjjd,
    required this.errorMessage,
  });

  const _ScoreContentState.initial()
    : selectedId = 'all',
      scoreList = const <Score>[],
      zxf = '-',
      zxfjd = '-',
      pjjd = '-',
      errorMessage = null;

  final String selectedId;
  final List<Score> scoreList;
  final String zxf;
  final String zxfjd;
  final String pjjd;
  final String? errorMessage;

  @override
  bool operator ==(Object other) {
    return other is _ScoreContentState &&
        other.selectedId == selectedId &&
        listEquals(other.scoreList, scoreList) &&
        other.zxf == zxf &&
        other.zxfjd == zxfjd &&
        other.pjjd == pjjd &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
    selectedId,
    Object.hashAll(scoreList),
    zxf,
    zxfjd,
    pjjd,
    errorMessage,
  );
}

class _ScoreSelectionState {
  const _ScoreSelectionState({
    required this.selectedId,
    required this.isRefreshing,
  });

  final String selectedId;
  final bool isRefreshing;

  @override
  bool operator ==(Object other) {
    return other is _ScoreSelectionState &&
        other.selectedId == selectedId &&
        other.isRefreshing == isRefreshing;
  }

  @override
  int get hashCode => Object.hash(selectedId, isRefreshing);
}

class _ScoreOverviewCard extends StatelessWidget {
  const _ScoreOverviewCard({
    required this.accent,
    required this.zxf,
    required this.zxfjd,
    required this.pjjd,
    required this.courseCount,
  });

  final Color accent;
  final String zxf;
  final String zxfjd;
  final String pjjd;
  final int courseCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.hero,
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: colorScheme.isDarkMode ? 0.14 : 0.84),
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.08 : 0.04),
        ],
      ),
      borderColor: accent.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassIconBadge(
                icon: Ionicons.analytics_outline,
                tint: accent,
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '成绩总览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: colorScheme.isDarkMode ? 0.18 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$courseCount 门课程',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const GlassHairlineDivider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ScoreMetric(label: '已修总学分', value: zxf, accent: accent),
              ),
              Expanded(
                child: _ScoreMetric(
                  label: '总学分绩点',
                  value: zxfjd,
                  accent: accent,
                ),
              ),
              Expanded(
                child: _ScoreMetric(label: '平均绩点', value: pjjd, accent: accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SemesterSelectorButton extends StatelessWidget {
  const _SemesterSelectorButton({
    required this.accent,
    required this.selectedLabel,
    required this.isRefreshing,
    required this.onTap,
  });

  final Color accent;
  final String selectedLabel;
  final bool isRefreshing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.floating,
      blur: 16,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: accent.withValues(alpha: 0.14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: colorScheme.isDarkMode ? 0.14 : 0.82),
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.08 : 0.04),
        ],
      ),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Ionicons.calendar_clear_outline, size: 18, color: accent),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: Text(
              selectedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isRefreshing)
            AppLoadingIndicator(size: 14, color: accent)
          else
            Icon(
              Ionicons.chevron_down_outline,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }
}

class _SemesterPickerSheet extends StatelessWidget {
  const _SemesterPickerSheet({
    required this.accent,
    required this.semesterIds,
    required this.selectedId,
    required this.formatSemesterLabel,
  });

  final Color accent;
  final List<String> semesterIds;
  final String selectedId;
  final String Function(String value) formatSemesterLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemCount = semesterIds.length + 1;
    final separatorCount = itemCount > 1 ? itemCount - 1 : 0;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.42;
    final listHeight =
        (itemCount * 62.0 + separatorCount * 8.0)
            .clamp(0.0, maxListHeight)
            .toDouble();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GlassPanel(
          style: GlassPanelStyle.floating,
          borderRadius: BorderRadius.circular(30),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.floatingSurfaceStrong,
              accent.withValues(alpha: colorScheme.isDarkMode ? 0.10 : 0.05),
            ],
          ),
          borderColor: accent.withValues(alpha: 0.14),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    GlassIconBadge(
                      icon: Ionicons.calendar_clear_outline,
                      tint: accent,
                      size: 46,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '选择学期',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '切换后会立即刷新当前成绩列表。',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: listHeight,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: false,
                    itemCount: itemCount,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 8);
                    },
                    itemBuilder: (context, index) {
                      final itemId =
                          index == 0 ? 'all' : semesterIds[index - 1];
                      final itemLabel =
                          index == 0 ? '全部学期' : formatSemesterLabel(itemId);
                      final selected = itemId == selectedId;
                      return _SemesterOptionTile(
                        accent: accent,
                        label: itemLabel,
                        selected: selected,
                        onTap: () => Navigator.of(context).pop(itemId),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SemesterOptionTile extends StatelessWidget {
  const _SemesterOptionTile({
    required this.accent,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color accent;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.list,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderColor:
          selected
              ? accent.withValues(alpha: 0.20)
              : colorScheme.outlineVariant.withValues(alpha: 0.46),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: colorScheme.isDarkMode ? 0.10 : 0.72),
          selected
              ? accent.withValues(alpha: colorScheme.isDarkMode ? 0.16 : 0.08)
              : colorScheme.surface.withValues(
                alpha: colorScheme.isDarkMode ? 0.12 : 0.56,
              ),
        ],
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color:
                  selected
                      ? accent.withValues(
                        alpha: colorScheme.isDarkMode ? 0.20 : 0.12,
                      )
                      : Colors.white.withValues(
                        alpha: colorScheme.isDarkMode ? 0.08 : 0.64,
                      ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              selected ? Ionicons.checkmark : Ionicons.calendar_outline,
              size: 16,
              color: selected ? accent : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color:
                    selected
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreMetric extends StatelessWidget {
  const _ScoreMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ScoreCourseCard extends StatelessWidget {
  const _ScoreCourseCard({
    required this.score,
    required this.palette,
    required this.onTap,
  });

  final Score score;
  final _ScorePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.list,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      tintColor: colorScheme.surface.withValues(
        alpha: colorScheme.isDarkMode ? 0.90 : 0.92,
      ),
      borderColor: palette.accent.withValues(alpha: 0.14),
      boxShadow: [
        BoxShadow(
          color: palette.accent.withValues(
            alpha: colorScheme.isDarkMode ? 0.08 : 0.04,
          ),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 56,
            decoration: BoxDecoration(
              color: palette.accent.withValues(
                alpha: colorScheme.isDarkMode ? 0.70 : 0.88,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score.courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.25,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _CompactMetaText(
                      icon: Ionicons.book_outline,
                      label:
                          score.courseNature.trim().isEmpty
                              ? '课程类型未知'
                              : score.courseNature,
                    ),
                    _CompactMetaText(
                      icon: Ionicons.podium_outline,
                      label: '绩点 ${score.gradePoints}',
                    ),
                    _CompactMetaText(
                      icon: Ionicons.layers_outline,
                      label: '学分 ${score.credit}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: palette.badgeBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      score.fraction,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.badgeForeground,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (score.state.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        score.state,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: palette.badgeForeground.withValues(
                            alpha: 0.84,
                          ),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactMetaText extends StatelessWidget {
  const _CompactMetaText({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ScoreDetailSheet extends StatelessWidget {
  const _ScoreDetailSheet({required this.score, required this.palette});

  final Score score;
  final _ScorePalette palette;

  List<_DetailItem> _buildDetails() {
    return [
      _DetailItem(
        label: '课程类型',
        value: score.courseNature.trim().isEmpty ? '暂无' : score.courseNature,
        icon: Ionicons.book_outline,
      ),
      _DetailItem(
        label: '绩点',
        value: score.gradePoints.trim().isEmpty ? '-' : score.gradePoints,
        icon: Ionicons.podium_outline,
      ),
      _DetailItem(
        label: '学分',
        value: score.credit.trim().isEmpty ? '-' : score.credit,
        icon: Ionicons.layers_outline,
      ),
      _DetailItem(
        label: '考试名称',
        value: score.examName.trim().isEmpty ? '暂无' : score.examName,
        icon: Ionicons.ribbon_outline,
      ),
      _DetailItem(
        label: '考核性质',
        value:
            score.examinationNature.trim().isEmpty
                ? '暂无'
                : score.examinationNature,
        icon: Ionicons.checkbox_outline,
      ),
      _DetailItem(
        label: '课程属性',
        value:
            score.curriculumAttributes.trim().isEmpty
                ? '暂无'
                : score.curriculumAttributes,
        icon: Ionicons.sparkles_outline,
      ),
      _DetailItem(
        label: '成绩状态',
        value: score.state.trim().isEmpty ? '成绩已出' : score.state,
        icon: Ionicons.information_circle_outline,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final detailItems = _buildDetails();

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GlassPanel(
            style: GlassPanelStyle.floating,
            borderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorScheme.floatingSurfaceStrong, palette.panelTint],
            ),
            borderColor: palette.accent.withValues(alpha: 0.14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            score.courseName,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.45,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MiniPill(
                                label: '课程类型 ${score.courseNature}',
                                accent: palette.accent,
                              ),
                              _MiniPill(
                                label: '绩点 ${score.gradePoints}',
                                accent: palette.accent,
                              ),
                              _MiniPill(
                                label: '学分 ${score.credit}',
                                accent: palette.accent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: palette.badgeBackground,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          Text(
                            score.fraction,
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              color: palette.badgeForeground,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            score.state.trim().isEmpty ? '成绩已出' : score.state,
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color: palette.badgeForeground.withValues(
                                alpha: 0.84,
                              ),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                for (final item in detailItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DetailRow(item: item, accent: palette.accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.item, required this.accent});

  final _DetailItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: colorScheme.isDarkMode ? 0.08 : 0.62,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(
                alpha: colorScheme.isDarkMode ? 0.16 : 0.10,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: colorScheme.isDarkMode ? 0.10 : 0.58,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _FeatureEmptyState extends StatelessWidget {
  const _FeatureEmptyState({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      style: GlassPanelStyle.hero,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(
            alpha: Theme.of(context).colorScheme.isDarkMode ? 0.12 : 0.78,
          ),
          accent.withValues(
            alpha: Theme.of(context).colorScheme.isDarkMode ? 0.10 : 0.06,
          ),
        ],
      ),
      borderColor: accent.withValues(alpha: 0.14),
      child: Column(
        children: [
          GlassIconBadge(icon: icon, tint: accent, size: 54),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBackButton extends StatelessWidget {
  const _FeatureBackButton({required this.onTap});

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

class _ScorePalette {
  const _ScorePalette({
    required this.accent,
    required this.badgeBackground,
    required this.badgeForeground,
    required this.panelTint,
  });

  final Color accent;
  final Color badgeBackground;
  final Color badgeForeground;
  final Color panelTint;
}

class _DetailItem {
  const _DetailItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}
