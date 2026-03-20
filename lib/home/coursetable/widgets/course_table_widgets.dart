import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../utils/course/coursemain.dart';

class CourseTableToolbar extends StatelessWidget {
  const CourseTableToolbar({
    super.key,
    required this.weekText,
    required this.isShowingCurrentWeek,
    required this.onBackToCurrentWeek,
    required this.showExperimentCourses,
    required this.onShowExperimentCoursesChanged,
  });

  final String weekText;
  final bool isShowingCurrentWeek;
  final VoidCallback onBackToCurrentWeek;
  final bool showExperimentCourses;
  final ValueChanged<bool> onShowExperimentCoursesChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        TextButton(
          onPressed: isShowingCurrentWeek ? null : onBackToCurrentWeek,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            foregroundColor: colorScheme.primary,
          ),
          child: const Text('回到本周'),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => onShowExperimentCoursesChanged(!showExperimentCourses),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  showExperimentCourses
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color:
                    showExperimentCourses
                        ? colorScheme.primary.withValues(alpha: 0.32)
                        : colorScheme.outlineVariant.withValues(alpha: 0.75),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        showExperimentCourses
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '实验课',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color:
                        showExperimentCourses
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  showExperimentCourses ? '开' : '关',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        showExperimentCourses
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            weekText,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class CourseWeekdayHeader extends StatelessWidget {
  const CourseWeekdayHeader({
    super.key,
    required this.dayLabels,
    required this.todayIndex,
  });

  final List<String> dayLabels;
  final int todayIndex;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        const Expanded(child: SizedBox()),
        ...dayLabels.asMap().entries.map((entry) {
          final index = entry.key;
          final label = entry.value;
          final isToday = index == todayIndex;

          return Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(3, 0, 3, 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isToday
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        isToday
                            ? colorScheme.primary.withValues(alpha: 0.28)
                            : colorScheme.outlineVariant.withValues(
                              alpha: 0.72,
                            ),
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
    this.slotHeight = 60,
  });

  final int sectionCount;
  final double slotHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: SizedBox(
        width: 42,
        child: Column(
          children: List.generate(sectionCount, (index) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(0, 1, 0, 1),
              child: Container(
                height: slotHeight,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
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
  });

  final Course course;
  final int nameMaxLines;
  final int locationMaxLines;
  final bool expandName;

  @override
  Widget build(BuildContext context) {
    final nameText = Text(
      course.name,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      textAlign: TextAlign.left,
      maxLines: nameMaxLines,
      overflow: TextOverflow.ellipsis,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expandName) Expanded(child: nameText) else nameText,
        const SizedBox(height: 2),
        Text(
          course.location,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.left,
          maxLines: locationMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          course.teacherName,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class CourseDetailSheet extends StatelessWidget {
  const CourseDetailSheet({
    super.key,
    required this.course,
    this.onViewStudents,
  });

  final Course course;
  final VoidCallback? onViewStudents;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: course.isExp ? 420 : 360,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(course.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _CourseInfoTile(
              icon: Ionicons.calendar_outline,
              title: course.weekDuration,
            ),
            _CourseInfoTile(
              icon: Ionicons.time_outline,
              title:
                  '第${course.startSection}-${course.duration + course.startSection - 1}节',
            ),
            _CourseInfoTile(
              icon: Ionicons.person_outline,
              title: course.teacherName,
            ),
            _CourseInfoTile(
              icon: Ionicons.location_outline,
              title: course.location,
            ),
            if (course.isExp && onViewStudents != null)
              _CourseInfoTile(
                icon: Ionicons.people_outline,
                title: '查看人员名单',
                onTap: onViewStudents,
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

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: 520,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
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
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: students.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
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
      ),
    );
  }
}

class _CourseInfoTile extends StatelessWidget {
  const _CourseInfoTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colorScheme.primary, size: 20),
        ),
        title: Text(title),
        trailing:
            onTap != null
                ? Icon(
                  Ionicons.chevron_forward_outline,
                  color: colorScheme.onSurfaceVariant,
                  size: 18,
                )
                : null,
      ),
    );
  }
}
