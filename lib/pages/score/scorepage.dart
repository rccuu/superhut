import 'dart:async';

import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../core/services/app_logger.dart';
import '../../core/ui/apple_glass.dart';
import '../../core/ui/color_scheme_ext.dart';
import 'logic.dart';

class ScorePage extends StatefulWidget {
  const ScorePage({super.key});

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
  String? _errorMessage;
  final Map<String, ScoreLoadResult> _scoreCache = <String, ScoreLoadResult>{};
  bool _isSemesterProbeStarted = false;

  void _applyScoreData(ScoreLoadResult scoreData, {String? semesterId}) {
    setState(() {
      if (semesterId != null) {
        selectedId = semesterId;
      }
      scoreList = scoreData.achievement;
      zxf = scoreData.yxzxf;
      zxfjd = scoreData.zxfjd;
      pjjd = scoreData.pjxfjd;
      _errorMessage = scoreData.errorMessage;
    });
  }

  Future<void> _refreshScoresForSelection(String semesterId) async {
    final cached = _scoreCache[semesterId];
    if (cached != null) {
      _applyScoreData(cached, semesterId: semesterId);
      return;
    }

    setState(() {
      selectedId = semesterId;
      _isRefreshingSelection = true;
    });

    final scoreData = await _loadScoreForSemester(semesterId);
    if (!mounted) {
      return;
    }

    setState(() {
      _isRefreshingSelection = false;
    });
    _applyScoreData(scoreData, semesterId: semesterId);
  }

  Future<ScoreLoadResult> _loadScoreForSemester(String semesterId) async {
    final cached = _scoreCache[semesterId];
    if (cached != null) {
      return cached;
    }

    final scoreData = await getScore(semesterId == 'all' ? '' : semesterId);
    _scoreCache[semesterId] = scoreData;
    return scoreData;
  }

  Future<List<String>> _filterSemestersWithScores(
    List<String> semesterIds,
  ) async {
    final availableSemesterIds = <String>[];

    for (final semester in semesterIds) {
      final scoreData = await _loadScoreForSemester(semester);
      if (scoreData.errorMessage != null) {
        AppLogger.debug(
          'Failed to probe score data for semester $semester, keeping full semester list.',
        );
        return semesterIds;
      }
      if (scoreData.achievement.isNotEmpty) {
        availableSemesterIds.add(semester);
      }
    }

    return availableSemesterIds;
  }

  Future<void> _probeAvailableSemesters(List<String> semesterIds) async {
    if (_isSemesterProbeStarted) {
      return;
    }
    _isSemesterProbeStarted = true;

    final filteredSemesterIds = await _filterSemestersWithScores(semesterIds);
    if (!mounted) {
      return;
    }

    final shouldResetSelection =
        selectedId != 'all' && !filteredSemesterIds.contains(selectedId);

    setState(() {
      semesterId = filteredSemesterIds;
      if (shouldResetSelection) {
        selectedId = 'all';
      }
    });

    if (!shouldResetSelection) {
      return;
    }

    final allScoreData = await _loadScoreForSemester('all');
    if (!mounted) {
      return;
    }
    _applyScoreData(allScoreData, semesterId: 'all');
  }

  Future<void> getTimeList() async {
    if (!first) {
      return;
    }

    final timeData = await semesterIdfc();
    if (!mounted) {
      return;
    }
    setState(() {
      semesterId = timeData.idList;
      nowSemesterId = timeData.nowId.isEmpty ? 'all' : timeData.nowId;
      _errorMessage = timeData.errorMessage;
      selectedId = 'all';
    });
    if (timeData.errorMessage != null) {
      first = false;
      return;
    }

    final scoreData = await _loadScoreForSemester('all');
    if (!mounted) {
      return;
    }

    _applyScoreData(scoreData, semesterId: 'all');
    unawaited(_probeAvailableSemesters(timeData.idList));
    first = false;
  }

  String _formatSemesterLabel(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      return value;
    }

    final termLabel = switch (parts[2]) {
      '1' => '上学期',
      '2' => '下学期',
      _ => '${parts[2]}学期',
    };
    return '${parts[0]}-${parts[1]} · $termLabel';
  }

  String _compactSemesterLabel(String value) {
    if (value == 'all') {
      return '全部学期';
    }

    final parts = value.split('-');
    if (parts.length != 3) {
      return value;
    }

    final termLabel = switch (parts[2]) {
      '1' => '上',
      '2' => '下',
      _ => parts[2],
    };
    return '${parts[0]}-${parts[1]} $termLabel';
  }

  double? _numericFraction(String text) {
    final normalized = text.replaceAll(RegExp(r'[^0-9.]'), '');
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

  void _showScoreDetail(Score score) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ScoreDetailSheet(
          score: score,
          palette: _paletteForScore(context, score),
        );
      },
    );
  }

  Future<void> _showSemesterPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
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

    if (result == null || result == selectedId) {
      return;
    }
    await _refreshScoresForSelection(result);
  }

  @override
  Widget build(BuildContext context) {
    return EnhancedFutureBuilder(
      future: getTimeList(),
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
                    LoadingAnimationWidget.inkDrop(
                      color: _scoreAccent,
                      size: 42,
                    ),
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
            ListView(
              padding: EdgeInsets.fromLTRB(16, topInset + 76, 16, 28),
              children: [
                _ScoreOverviewCard(
                  accent: _scoreAccent,
                  zxf: zxf,
                  zxfjd: zxfjd,
                  pjjd: pjjd,
                  courseCount: scoreList.length,
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: '课程成绩',
                  subtitle:
                      _errorMessage != null
                          ? '当前结果未能正常加载'
                          : scoreList.isEmpty
                          ? '暂无成绩记录'
                          : '共 ${scoreList.length} 门课程',
                ),
                const SizedBox(height: 8),
                if (_errorMessage != null)
                  _FeatureEmptyState(
                    icon: Ionicons.alert_circle_outline,
                    accent: Theme.of(context).colorScheme.error,
                    title: '成绩加载失败',
                    subtitle: _errorMessage!,
                  )
                else if (scoreList.isEmpty)
                  _FeatureEmptyState(
                    icon: Ionicons.receipt_outline,
                    accent: _scoreAccent,
                    title: '还没有成绩记录',
                    subtitle:
                        selectedId == 'all'
                            ? '当前账号暂未查询到任何成绩。'
                            : '这个学期目前没有可展示的成绩条目。',
                  )
                else
                  ...scoreList.map((score) {
                    final palette = _paletteForScore(context, score);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ScoreCourseCard(
                        score: score,
                        palette: palette,
                        onTap: () => _showScoreDetail(score),
                      ),
                    );
                  }),
              ],
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
              child: _SemesterSelectorButton(
                accent: _scoreAccent,
                selectedLabel: _compactSemesterLabel(selectedId),
                isRefreshing: _isRefreshingSelection,
                onTap: _showSemesterPicker,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            )
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
    final items = <({String id, String label})>[
      (id: 'all', label: '全部学期'),
      ...semesterIds.map((semester) {
        return (id: semester, label: formatSemesterLabel(semester));
      }),
    ];

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
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 8);
                    },
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final selected = item.id == selectedId;
                      return _SemesterOptionTile(
                        accent: accent,
                        label: item.label,
                        selected: selected,
                        onTap: () => Navigator.of(context).pop(item.id),
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
                ...detailItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DetailRow(item: item, accent: palette.accent),
                  );
                }),
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
