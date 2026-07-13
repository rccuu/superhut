import 'package:flutter/material.dart';

import '../../../core/ui/apple_glass.dart';
import '../../../core/ui/color_scheme_ext.dart';
import '../../../utils/course/get_course.dart';

class CourseSemesterPickerSheet extends StatefulWidget {
  const CourseSemesterPickerSheet({super.key, required this.semesters});

  final List<CourseSemester> semesters;

  @override
  State<CourseSemesterPickerSheet> createState() =>
      _CourseSemesterPickerSheetState();
}

class _CourseSemesterPickerSheetState extends State<CourseSemesterPickerSheet> {
  late CourseSemester _selectedSemester = widget.semesters.firstWhere(
    (semester) => semester.isCurrent,
    orElse: () => widget.semesters.first,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = colorScheme.primary;

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
              accent.withValues(alpha: colorScheme.isDarkMode ? 0.12 : 0.06),
            ],
          ),
          borderColor: accent.withValues(alpha: 0.16),
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
                      icon: Icons.calendar_month_rounded,
                      tint: accent,
                      size: 46,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '抓取教务课表',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '选择学期后同步普通与实验课程',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
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
                    padding: EdgeInsets.zero,
                    itemCount: widget.semesters.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final semester = widget.semesters[index];
                      return _SemesterTile(
                        semester: semester,
                        selected: semester.id == _selectedSemester.id,
                        accent: accent,
                        onTap:
                            () => setState(() => _selectedSemester = semester),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        () => Navigator.of(context).pop(_selectedSemester),
                    icon: const Icon(Icons.cloud_download_rounded),
                    label: Text('开始同步 · ${_selectedSemester.label}'),
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

class _SemesterTile extends StatelessWidget {
  const _SemesterTile({
    required this.semester,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final CourseSemester semester;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassPanel(
      style: GlassPanelStyle.list,
      borderRadius: BorderRadius.circular(18),
      padding: EdgeInsets.zero,
      borderColor: (selected ? accent : colorScheme.outlineVariant).withValues(
        alpha: selected ? 0.28 : 0.42,
      ),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.calendar_today_rounded,
              color: selected ? accent : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(semester.label)),
            if (semester.isCurrent)
              Text(
                '当前学期',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: accent),
              ),
          ],
        ),
      ),
    );
  }
}
