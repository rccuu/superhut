import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:superhut/pages/ExamSchedule/exam_schedule_bridge.dart';

import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/apple_glass.dart';
import '../../core/ui/color_scheme_ext.dart';

typedef ExamScheduleLoader = Future<ExamScheduleResult> Function();

class ExamSchedulePage extends StatefulWidget {
  const ExamSchedulePage({super.key, this.loadExamSchedule});

  final ExamScheduleLoader? loadExamSchedule;

  @override
  State<ExamSchedulePage> createState() => _ExamSchedulePageState();
}

class _ExamSchedulePageState extends State<ExamSchedulePage> {
  static const Color _examAccent = Color(0xFFE28A2E);

  late Future<ExamScheduleResult> _examScheduleFuture;
  final Map<Map<String, dynamic>, _ExamScheduleCardInfo>
  _examScheduleCardInfoCache = <Map<String, dynamic>, _ExamScheduleCardInfo>{};
  List<Map<String, dynamic>>? _examScheduleCardInfoSource;
  DateTime? _examScheduleCardInfoDate;

  @override
  void initState() {
    super.initState();
    _examScheduleFuture = _loadExamSchedule();
  }

  Future<ExamScheduleResult> _loadExamSchedule() {
    return widget.loadExamSchedule?.call() ?? getSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return AppGlassPerformanceScope(
      isLite: true,
      child: EnhancedFutureBuilder(
        future: _examScheduleFuture,
        rememberFutureResult: true,
        whenDone: (data) {
          final result = data;
          return _buildScaffold(context, result);
        },
        whenNotDone: _buildLoadingScaffold(context),
      ),
    );
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        style: AppGlassBackgroundStyle.soft,
        lightBottomColor: const Color(0xFFFFF5EA),
        darkBottomColor: const Color(0xFF21170E),
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
                    _examAccent.withValues(alpha: 0.10),
                  ],
                ),
                borderColor: _examAccent.withValues(alpha: 0.14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLoadingIndicator(color: _examAccent, size: 42),
                    const SizedBox(height: 16),
                    Text(
                      '正在同步考试安排',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '为你整理当前学期考试信息',
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

  Widget _buildScaffold(BuildContext context, ExamScheduleResult result) {
    final topInset = MediaQuery.paddingOf(context).top;
    final schedules = result.schedules;
    final errorMessage = result.errorMessage;
    final today = _todayDate();
    _syncExamScheduleCardInfoCache(schedules, today);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        style: AppGlassBackgroundStyle.soft,
        lightBottomColor: const Color(0xFFFFF5EA),
        darkBottomColor: const Color(0xFF21170E),
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, topInset + 76, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ExamOverviewCard(
                          accent: _examAccent,
                          examCount: schedules.length,
                          nearestExamText: _nearestExamText(schedules, today),
                        ),
                        const SizedBox(height: 16),
                        _SectionHeader(
                          title: '考试列表',
                          subtitle:
                              errorMessage != null
                                  ? '当前结果未能正常加载'
                                  : schedules.isEmpty
                                  ? '当前学期暂无考试'
                                  : '共 ${schedules.length} 门考试',
                        ),
                        const SizedBox(height: 8),
                        if (errorMessage != null)
                          _FeatureEmptyState(
                            icon: Ionicons.alert_circle_outline,
                            accent: Theme.of(context).colorScheme.error,
                            title: '考试安排加载失败',
                            subtitle: errorMessage,
                          )
                        else if (schedules.isEmpty)
                          const _FeatureEmptyState(
                            icon: Ionicons.ribbon_outline,
                            accent: _examAccent,
                            title: '当前学期暂无考试安排',
                            subtitle: '如果教务系统稍后发布考试信息，这里会同步展示。',
                          ),
                      ],
                    ),
                  ),
                ),
                if (errorMessage == null && schedules.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final schedule = schedules[index];
                          final cardInfo = _examScheduleCardInfoFor(
                            schedule,
                            today,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ExamScheduleCard(
                              accent: _examAccent,
                              courseName: cardInfo.courseName,
                              place: cardInfo.place,
                              time: cardInfo.time,
                              courseNumber: cardInfo.courseNumber,
                              daysLeftText: cardInfo.daysLeftText,
                              daysLeftColor: _daysLeftColor(
                                cardInfo.daysLeft,
                                context,
                              ),
                            ),
                          );
                        },
                        childCount: schedules.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
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

  void _syncExamScheduleCardInfoCache(
    List<Map<String, dynamic>> schedules,
    DateTime today,
  ) {
    final cachedDate = _examScheduleCardInfoDate;
    if (identical(_examScheduleCardInfoSource, schedules) &&
        cachedDate != null &&
        _isSameDate(cachedDate, today)) {
      return;
    }

    _examScheduleCardInfoCache.clear();
    _examScheduleCardInfoSource = schedules;
    _examScheduleCardInfoDate = today;
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  _ExamScheduleCardInfo _examScheduleCardInfoFor(
    Map<String, dynamic> schedule,
    DateTime today,
  ) {
    final cached = _examScheduleCardInfoCache[schedule];
    if (cached != null) {
      return cached;
    }

    final time = _readScheduleText(schedule, 'time', fallback: '时间待公布');
    final examDate = _parseExamDate(time, fallbackYear: today.year);
    final daysLeft = _daysLeft(examDate, today);
    final info = _ExamScheduleCardInfo(
      courseName: _readScheduleText(schedule, 'courseName', fallback: '未命名课程'),
      place: _readScheduleText(schedule, 'examinationPlace', fallback: '考场待公布'),
      time: time,
      courseNumber: _readScheduleText(schedule, 'courseNumber'),
      daysLeftText: _daysLeftText(daysLeft),
      daysLeft: daysLeft,
    );
    _examScheduleCardInfoCache[schedule] = info;
    return info;
  }

  DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _nearestExamText(
    List<Map<String, dynamic>> schedules,
    DateTime today,
  ) {
    Map<String, dynamic>? nearestSchedule;
    DateTime? nearestDate;
    for (final schedule in schedules) {
      final date = _parseExamDate(
        schedule['time']?.toString() ?? '',
        fallbackYear: today.year,
      );
      if (date == null || date.isBefore(today)) {
        continue;
      }
      if (nearestDate == null || date.isBefore(nearestDate)) {
        nearestDate = date;
        nearestSchedule = schedule;
      }
    }

    if (nearestSchedule == null || nearestDate == null) {
      return schedules.isEmpty ? '暂无考试' : '本学期考试已结束';
    }

    final courseName = _readScheduleText(
      nearestSchedule,
      'courseName',
      fallback: '最近考试',
    );
    return '$courseName · ${_daysLeftText(_daysLeft(nearestDate, today))}';
  }

  DateTime? _parseExamDate(String input, {required int fallbackYear}) {
    try {
      if (input.length < 10) {
        return null;
      }

      var segmentStart = 0;
      var segmentIndex = 0;
      int? year;
      int? month;
      int? day;
      for (var index = 0; index <= 10; index++) {
        if (index == 10 || input.codeUnitAt(index) == 0x2D) {
          final value = _parseExamDateSegment(input, segmentStart, index);
          switch (segmentIndex) {
            case 0:
              year = value ?? fallbackYear;
              break;
            case 1:
              month = value ?? 1;
              break;
            case 2:
              day = value ?? 1;
              break;
            default:
              return null;
          }
          segmentIndex++;
          segmentStart = index + 1;
        }
      }

      if (segmentIndex != 3 || year == null || month == null || day == null) {
        return null;
      }

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  int? _parseExamDateSegment(String input, int start, int end) {
    if (start >= end) {
      return null;
    }

    var value = 0;
    for (var index = start; index < end; index++) {
      final codeUnit = input.codeUnitAt(index);
      if (codeUnit < 0x30 || codeUnit > 0x39) {
        return null;
      }
      value = value * 10 + codeUnit - 0x30;
    }
    return value;
  }

  int? _daysLeft(DateTime? examDate, DateTime today) {
    return examDate?.difference(today).inDays;
  }

  String _daysLeftText(int? daysLeft) {
    if (daysLeft == null) {
      return '日期未知';
    }

    if (daysLeft == 0) {
      return '今天考试';
    }
    if (daysLeft > 0) {
      return '还有$daysLeft天';
    }
    return '已结束${-daysLeft}天';
  }

  Color _daysLeftColor(int? daysLeft, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (daysLeft == null) {
      return colorScheme.onSurfaceVariant;
    }
    if (daysLeft == 0) {
      return colorScheme.error;
    }
    if (daysLeft > 0) {
      return daysLeft <= 3 ? colorScheme.warning : colorScheme.success;
    }
    return colorScheme.onSurfaceVariant;
  }
}

String _readScheduleText(
  Map<String, dynamic> schedule,
  String key, {
  String fallback = '',
}) {
  final value = schedule[key]?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

class _ExamScheduleCardInfo {
  const _ExamScheduleCardInfo({
    required this.courseName,
    required this.place,
    required this.time,
    required this.courseNumber,
    required this.daysLeftText,
    required this.daysLeft,
  });

  final String courseName;
  final String place;
  final String time;
  final String courseNumber;
  final String daysLeftText;
  final int? daysLeft;
}

class _ExamOverviewCard extends StatelessWidget {
  const _ExamOverviewCard({
    required this.accent,
    required this.examCount,
    required this.nearestExamText,
  });

  final Color accent;
  final int examCount;
  final String nearestExamText;

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
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.10 : 0.05),
        ],
      ),
      borderColor: accent.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassIconBadge(icon: Ionicons.ribbon_outline, tint: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '考试总览',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nearestExamText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: colorScheme.isDarkMode ? 0.20 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$examCount 门考试',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExamScheduleCard extends StatelessWidget {
  const _ExamScheduleCard({
    required this.accent,
    required this.courseName,
    required this.place,
    required this.time,
    required this.courseNumber,
    required this.daysLeftText,
    required this.daysLeftColor,
  });

  final Color accent;
  final String courseName;
  final String place;
  final String time;
  final String courseNumber;
  final String daysLeftText;
  final Color daysLeftColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.list,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.floatingSurfaceStrong,
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.10 : 0.04),
        ],
      ),
      borderColor: accent.withValues(
        alpha: colorScheme.isDarkMode ? 0.16 : 0.10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(label: daysLeftText, color: daysLeftColor),
            ],
          ),
          const SizedBox(height: 12),
          _ExamInfoRow(
            icon: Ionicons.location_outline,
            label: place,
            accent: accent,
          ),
          const SizedBox(height: 8),
          _ExamInfoRow(
            icon: Ionicons.calendar_clear_outline,
            label: time,
            accent: accent,
          ),
          if (courseNumber.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                courseNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExamInfoRow extends StatelessWidget {
  const _ExamInfoRow({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: colorScheme.isDarkMode ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          height: 1.0,
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

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
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
            textAlign: TextAlign.center,
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
