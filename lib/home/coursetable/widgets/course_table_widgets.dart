import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../utils/course/coursemain.dart';

class CourseTableToolbar extends StatelessWidget {
  const CourseTableToolbar({
    super.key,
    required this.dateText,
    required this.weekText,
    required this.onBackToCurrentWeek,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  final String dateText;
  final String weekText;
  final VoidCallback onBackToCurrentWeek;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateText, style: const TextStyle(fontSize: 18)),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'current_week') {
                      onBackToCurrentWeek();
                    }
                  },
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem<String>(
                          value: 'current_week',
                          child: Text('回到当前周'),
                        ),
                      ],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(weekText, style: const TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPreviousWeek,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNextWeek,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CourseWeekdayHeader extends StatelessWidget {
  const CourseWeekdayHeader({super.key, required this.dayLabels});

  final List<String> dayLabels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(''),
          ),
        ),
        ...dayLabels.map((label) {
          return Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                maxLines: 2,
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
    return Expanded(
      child: SizedBox(
        width: 40,
        child: Column(
          children: List.generate(sectionCount, (index) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(0, 1, 0, 1),
              child: SizedBox(
                height: slotHeight,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
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
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.left,
      maxLines: nameMaxLines,
      overflow: TextOverflow.ellipsis,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expandName) Expanded(child: nameText) else nameText,
        Text(
          course.location,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.normal,
          ),
          textAlign: TextAlign.left,
          maxLines: locationMaxLines,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          course.teacherName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.normal,
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
    return Material(
      child: SizedBox(
        height: course.isExp ? 400 : 350,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          children: [
            Text(course.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            ListTile(
              leading: Icon(
                Ionicons.calendar_outline,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(course.weekDuration),
            ),
            ListTile(
              leading: Icon(
                Ionicons.time_outline,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(
                '第${course.startSection}-${course.duration + course.startSection - 1}节',
              ),
            ),
            ListTile(
              leading: Icon(
                Ionicons.person_outline,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(course.teacherName),
            ),
            ListTile(
              leading: Icon(
                Ionicons.location_outline,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(course.location),
            ),
            if (course.isExp && onViewStudents != null)
              ListTile(
                leading: Icon(
                  Ionicons.people_outline,
                  color: Theme.of(context).primaryColor,
                ),
                title: const Text('查看人员名单'),
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
    return Material(
      child: SizedBox(
        height: 500,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${baseData['kcmc']?.toString() ?? ''} - ${baseData['pcname']?.toString() ?? ''}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text('学期: ${baseData['xnxqmc']?.toString() ?? ''}'),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: students.length,
                  separatorBuilder:
                      (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return ListTile(
                      leading: Icon(
                        Ionicons.person_outline,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: Text(student['xm']?.toString() ?? ''),
                      subtitle: Text(
                        '学号: ${student['xh']?.toString() ?? ''}  班级: ${student['bj']?.toString() ?? ''}',
                      ),
                      trailing: Text(student['xbmc']?.toString() ?? ''),
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
