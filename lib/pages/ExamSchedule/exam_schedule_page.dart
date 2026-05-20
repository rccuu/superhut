import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/ExamSchedule/exam_schedule_bridge.dart';

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
                    LoadingAnimationWidget.inkDrop(
                      color: _examAccent,
                      size: 42,
                    ),
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        style: AppGlassBackgroundStyle.soft,
        lightBottomColor: const Color(0xFFFFF5EA),
        darkBottomColor: const Color(0xFF21170E),
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(16, topInset + 76, 16, 28),
              children: [
                _ExamOverviewCard(
                  accent: _examAccent,
                  examCount: schedules.length,
                  nearestExamText: _nearestExamText(schedules),
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
                  )
                else
                  ...schedules.map((schedule) {
                    final examDate = _parseExamDate(
                      schedule['time']?.toString() ?? '',
                    );
                    final daysLeftText = _daysLeftText(examDate);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ExamScheduleCard(
                        accent: _examAccent,
                        courseName: _readScheduleText(
                          schedule,
                          'courseName',
                          fallback: '未命名课程',
                        ),
                        place: _readScheduleText(
                          schedule,
                          'examinationPlace',
                          fallback: '考场待公布',
                        ),
                        time: _readScheduleText(
                          schedule,
                          'time',
                          fallback: '时间待公布',
                        ),
                        courseNumber: _readScheduleText(
                          schedule,
                          'courseNumber',
                        ),
                        daysLeftText: daysLeftText,
                        daysLeftColor: _daysLeftColor(daysLeftText, context),
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
          ],
        ),
      ),
    );
  }

  String _nearestExamText(List<Map<String, dynamic>> schedules) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming =
        schedules
            .map((schedule) {
              final date = _parseExamDate(schedule['time']?.toString() ?? '');
              return (schedule: schedule, date: date);
            })
            .where((item) => item.date != null && !item.date!.isBefore(today))
            .toList()
          ..sort((a, b) => a.date!.compareTo(b.date!));

    if (upcoming.isEmpty) {
      return schedules.isEmpty ? '暂无考试' : '本学期考试已结束';
    }

    final first = upcoming.first;
    final courseName = _readScheduleText(
      first.schedule,
      'courseName',
      fallback: '最近考试',
    );
    return '$courseName · ${_daysLeftText(first.date)}';
  }

  DateTime? _parseExamDate(String input) {
    try {
      if (input.length < 10) {
        return null;
      }
      final datePart = input.substring(0, 10);
      final parts = datePart.split('-');
      if (parts.length != 3) {
        return null;
      }

      final year = int.tryParse(parts[0]) ?? DateTime.now().year;
      final month = int.tryParse(parts[1]) ?? 1;
      final day = int.tryParse(parts[2]) ?? 1;

      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _daysLeftText(DateTime? examDate) {
    if (examDate == null) {
      return '日期未知';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = examDate.difference(today).inDays;

    if (daysLeft == 0) {
      return '今天考试';
    }
    if (daysLeft > 0) {
      return '还有$daysLeft天';
    }
    return '已结束${-daysLeft}天';
  }

  Color _daysLeftColor(String text, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (text.contains('今天')) {
      return colorScheme.error;
    }
    if (text.contains('还有')) {
      final days = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return days <= 3 ? colorScheme.warning : colorScheme.success;
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
