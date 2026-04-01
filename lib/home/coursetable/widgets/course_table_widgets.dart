import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/ui/apple_glass.dart';
import '../../../core/ui/color_scheme_ext.dart';
import '../../../utils/course/coursemain.dart';

class CourseTableToolbar extends StatelessWidget {
  const CourseTableToolbar({
    super.key,
    required this.weekTitle,
    required this.weekDateRange,
    required this.currentWeekLabel,
    required this.isShowingCurrentWeek,
    required this.onBackToCurrentWeek,
    required this.onManageSchedules,
    required this.showExperimentCourses,
    required this.onShowExperimentCoursesChanged,
    this.useLiteStyle = false,
  });

  final String weekTitle;
  final String weekDateRange;
  final String currentWeekLabel;
  final bool isShowingCurrentWeek;
  final VoidCallback onBackToCurrentWeek;
  final VoidCallback onManageSchedules;
  final bool showExperimentCourses;
  final ValueChanged<bool> onShowExperimentCoursesChanged;
  final bool useLiteStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassPanel(
      key: ValueKey<String>(
        useLiteStyle
            ? 'course-table-toolbar-lite'
            : 'course-table-toolbar-full',
      ),
      style: useLiteStyle ? GlassPanelStyle.solid : GlassPanelStyle.floating,
      blur: useLiteStyle ? 0 : 18,
      useBackdropFilter: !useLiteStyle,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      weekTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        weekDateRange,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                        ),
                      ),
                    ),
                  ],
                ),
                if (currentWeekLabel.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    currentWeekLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ToolbarAction(
            icon: Ionicons.layers_outline,
            semanticLabel: '管理课表',
            isActive: true,
            onTap: onManageSchedules,
          ),
          const SizedBox(width: 6),
          _ToolbarAction(
            icon:
                showExperimentCourses ? Ionicons.flask : Ionicons.flask_outline,
            semanticLabel: showExperimentCourses ? '隐藏实验课' : '显示实验课',
            isActive: showExperimentCourses,
            onTap: () => onShowExperimentCoursesChanged(!showExperimentCourses),
          ),
          const SizedBox(width: 6),
          _ToolbarAction(
            icon: Ionicons.return_up_back_outline,
            semanticLabel: '回到本周',
            isActive: !isShowingCurrentWeek,
            onTap: isShowingCurrentWeek ? null : onBackToCurrentWeek,
          ),
        ],
      ),
    );
  }
}

class CourseWeekdayHeader extends StatelessWidget {
  const CourseWeekdayHeader({
    super.key,
    required this.dayLabels,
    required this.dayFlexes,
    required this.todayIndex,
    required this.leadingWidth,
  });

  final List<String> dayLabels;
  final List<int> dayFlexes;
  final int todayIndex;
  final double leadingWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        SizedBox(width: leadingWidth),
        ...dayLabels.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isToday = index == todayIndex;

          return Expanded(
            flex: dayFlexes[index],
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0.6, 0, 0.6, 5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color:
                      isToday
                          ? colorScheme.primary.withValues(
                            alpha: isDark ? 0.18 : 0.12,
                          )
                          : Colors.white.withValues(
                            alpha: isDark ? 0.08 : 0.42,
                          ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isToday
                            ? colorScheme.primary.withValues(alpha: 0.32)
                            : Colors.white.withValues(
                              alpha: isDark ? 0.10 : 0.62,
                            ),
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color:
                        isToday
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class CourseSectionColumn extends StatelessWidget {
  const CourseSectionColumn({
    super.key,
    required this.sectionCount,
    required this.width,
    this.slotHeight = 60,
  });

  final int sectionCount;
  final double width;
  final double slotHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: width,
      child: Column(
        children: List.generate(sectionCount, (index) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 0.2, 0, 0.2),
            child: Container(
              height: slotHeight,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.44),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.56),
                ),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class CourseSummary extends StatelessWidget {
  const CourseSummary({
    super.key,
    required this.course,
    required this.nameMaxLines,
    required this.locationMaxLines,
    this.expandName = false,
    required this.foregroundColor,
  });

  final Course course;
  final int nameMaxLines;
  final int locationMaxLines;
  final bool expandName;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ultraCompact = constraints.maxHeight < 28;
        final compact = constraints.maxHeight < 36 || course.duration <= 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScaledLine(
              text: course.name,
              color: foregroundColor,
              fontSize: compact ? (ultraCompact ? 8.7 : 9.4) : 11.2,
              fontWeight: FontWeight.w800,
              height: compact ? (ultraCompact ? 9.5 : 11) : 14,
            ),
            if (course.location.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: compact ? 0.4 : 1.8),
                child: _ScaledLine(
                  text: course.location,
                  color: foregroundColor.withValues(alpha: 0.92),
                  fontSize: compact ? (ultraCompact ? 6.8 : 7.4) : 8.9,
                  fontWeight: FontWeight.w700,
                  height: compact ? (ultraCompact ? 8 : 9) : 11,
                ),
              ),
            if (!compact && course.teacherName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 0.8),
                child: _ScaledLine(
                  text: course.teacherName,
                  color: foregroundColor.withValues(alpha: 0.76),
                  fontSize: 8.1,
                  fontWeight: FontWeight.w600,
                  height: 10,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ScaledLine extends StatelessWidget {
  const _ScaledLine({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    required this.height,
  });

  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: fontWeight,
              letterSpacing: -0.18,
            ),
          ),
        ),
      ),
    );
  }
}

class CourseDetailSheet extends StatelessWidget {
  const CourseDetailSheet({
    super.key,
    required this.course,
    required this.scheduleText,
    required this.copyText,
    this.onViewStudents,
    this.onDeleteCurrentCourse,
    this.onDeleteWholeScheduleCourse,
  });

  final Course course;
  final String scheduleText;
  final String copyText;
  final VoidCallback? onViewStudents;
  final VoidCallback? onDeleteCurrentCourse;
  final VoidCallback? onDeleteWholeScheduleCourse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Future<void> copyValue(String text, String message) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }

    final detailItems = [
      _CourseDetailItem(
        icon: Ionicons.calendar_outline,
        text: course.weekDuration.isEmpty ? '暂无周数信息' : course.weekDuration,
      ),
      _CourseDetailItem(icon: Ionicons.time_outline, text: scheduleText),
      _CourseDetailItem(
        icon: Ionicons.person_outline,
        text: course.teacherName.isEmpty ? '暂无教师信息' : course.teacherName,
      ),
      _CourseDetailItem(
        icon: Ionicons.location_outline,
        text: course.location.isEmpty ? '暂无上课地点' : course.location,
      ),
    ];

    final actionItems = [
      _CourseActionItem(
        icon: Ionicons.copy_outline,
        text: '复制课程名称',
        onTap: () => copyValue(course.name, '已复制课程名称'),
      ),
      _CourseActionItem(
        icon: Ionicons.document_text_outline,
        text: '复制课程信息为文本',
        onTap: () => copyValue(copyText, '已复制课程详情'),
      ),
      if (course.isExp && course.pcid.isNotEmpty && onViewStudents != null)
        _CourseActionItem(
          icon: Ionicons.people_outline,
          text: '查看实验人员名单',
          onTap: onViewStudents,
        ),
      if (onDeleteCurrentCourse != null)
        _CourseActionItem(
          icon: Ionicons.trash_outline,
          text: '删除当前课程',
          accentColor: colorScheme.error,
          onTap: onDeleteCurrentCourse,
        ),
      if (onDeleteWholeScheduleCourse != null)
        _CourseActionItem(
          icon: Ionicons.trash_bin_outline,
          text: '删除整学期该课程',
          accentColor: colorScheme.error,
          onTap: onDeleteWholeScheduleCourse,
        ),
    ];

    return _CourseSheetShell(
      maxHeightFactor: 0.84,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CourseSheetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.92,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    course.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        '详情',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '长按下方信息可复制',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.78,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _CourseDetailGroup(
              children:
                  detailItems
                      .map(
                        (item) => _CourseDetailRow(
                          icon: item.icon,
                          text: item.text,
                          onLongPress:
                              () => copyValue(item.text, '已复制${item.text}'),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            _CourseDetailGroup(
              children:
                  actionItems
                      .map(
                        (item) => _CourseDetailRow(
                          icon: item.icon,
                          text: item.text,
                          accentColor: item.accentColor ?? colorScheme.primary,
                          trailing: Icon(
                            Ionicons.chevron_forward_outline,
                            size: 18,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.72,
                            ),
                          ),
                          onTap: item.onTap,
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class ExperimentStudentsSheet extends StatelessWidget {
  const ExperimentStudentsSheet({
    super.key,
    required this.baseData,
    required this.students,
  });

  final Map<String, dynamic> baseData;
  final List<Map<String, dynamic>> students;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sheetHeight = math.min(
      MediaQuery.sizeOf(context).height * 0.72,
      520.0,
    );

    return _CourseSheetShell(
      maxHeightFactor: 0.82,
      panelPadding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CourseSheetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.92,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${baseData['kcmc']?.toString() ?? ''} - ${baseData['pcname']?.toString() ?? ''}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '学期: ${baseData['xnxqmc']?.toString() ?? ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: students.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final student = students[index];
                  return GlassPanel(
                    style: GlassPanelStyle.list,
                    blur: 0,
                    useBackdropFilter: false,
                    borderRadius: BorderRadius.circular(22),
                    padding: EdgeInsets.zero,
                    borderColor: colorScheme.outlineVariant.withValues(
                      alpha: colorScheme.isDarkMode ? 0.20 : 0.24,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.surfaceContainerHighest.withValues(
                          alpha: colorScheme.isDarkMode ? 0.88 : 0.90,
                        ),
                        Color.alphaBlend(
                          colorScheme.primary.withValues(
                            alpha: colorScheme.isDarkMode ? 0.08 : 0.04,
                          ),
                          colorScheme.surfaceContainerHigh.withValues(
                            alpha: colorScheme.isDarkMode ? 0.82 : 0.86,
                          ),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Ionicons.person_outline,
                          color: colorScheme.primary,
                        ),
                      ),
                      title: Text(student['xm']?.toString() ?? ''),
                      subtitle: Text(
                        '学号 ${student['xh']?.toString() ?? ''}  ·  ${student['bj']?.toString() ?? ''}',
                      ),
                      trailing: Text(student['xbmc']?.toString() ?? ''),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseSheetShell extends StatelessWidget {
  const _CourseSheetShell({
    required this.child,
    this.maxHeightFactor,
    this.panelPadding = const EdgeInsets.fromLTRB(20, 14, 20, 20),
  });

  final Widget child;
  final double? maxHeightFactor;
  final EdgeInsetsGeometry panelPadding;

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (maxHeightFactor != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor!,
        ),
        child: child,
      );
    }

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Padding(padding: panelPadding, child: content),
        ),
      ),
    );
  }
}

class _CourseSheetCard extends StatelessWidget {
  const _CourseSheetCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.solid,
      useBackdropFilter: false,
      blur: 0,
      borderRadius: BorderRadius.circular(32),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      borderColor: colorScheme.primary.withValues(
        alpha: colorScheme.isDarkMode ? 0.14 : 0.08,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.surfaceContainerHighest.withValues(
            alpha: colorScheme.isDarkMode ? 0.90 : 0.92,
          ),
          Color.alphaBlend(
            colorScheme.primary.withValues(
              alpha: colorScheme.isDarkMode ? 0.10 : 0.05,
            ),
            colorScheme.surfaceContainerHigh.withValues(
              alpha: colorScheme.isDarkMode ? 0.86 : 0.88,
            ),
          ),
          colorScheme.primary.withValues(
            alpha: colorScheme.isDarkMode ? 0.05 : 0.02,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CourseDetailItem {
  const _CourseDetailItem({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class _CourseActionItem {
  const _CourseActionItem({
    required this.icon,
    required this.text,
    required this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final Color? accentColor;
}

class _CourseDetailGroup extends StatelessWidget {
  const _CourseDetailGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.list,
      blur: 0,
      useBackdropFilter: false,
      borderRadius: BorderRadius.circular(24),
      borderColor: colorScheme.outlineVariant.withValues(
        alpha: colorScheme.isDarkMode ? 0.20 : 0.24,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.surfaceContainerHighest.withValues(
            alpha: colorScheme.isDarkMode ? 0.88 : 0.90,
          ),
          Color.alphaBlend(
            colorScheme.primary.withValues(
              alpha: colorScheme.isDarkMode ? 0.08 : 0.04,
            ),
            colorScheme.surfaceContainerHigh.withValues(
              alpha: colorScheme.isDarkMode ? 0.82 : 0.86,
            ),
          ),
        ],
      ),
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(children.length * 2 - 1, (index) {
          if (index.isOdd) {
            return const GlassHairlineDivider(horizontal: 18);
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }
}

class _CourseDetailRow extends StatelessWidget {
  const _CourseDetailRow({
    required this.icon,
    required this.text,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.accentColor,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final tint = accentColor ?? colorScheme.primary;
    final isInteractive = onTap != null || onLongPress != null;

    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: tint, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: accentColor ?? colorScheme.onSurface,
                fontWeight:
                    accentColor != null ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.2,
                height: 1.25,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );

    if (!isInteractive) {
      return rowContent;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: rowContent),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.icon,
    required this.semanticLabel,
    required this.isActive,
    this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Ink(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient:
                  isActive
                      ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: isDark ? 0.20 : 0.90),
                          colorScheme.primary.withValues(
                            alpha: isDark ? 0.20 : 0.18,
                          ),
                        ],
                      )
                      : null,
              color:
                  isActive
                      ? null
                      : Colors.white.withValues(alpha: isDark ? 0.05 : 0.26),
              border: Border.all(
                color:
                    isActive
                        ? Colors.white.withValues(alpha: isDark ? 0.16 : 0.72)
                        : Colors.white.withValues(alpha: isDark ? 0.08 : 0.52),
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color:
                  isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
