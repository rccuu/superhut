import 'dart:math' as math;

import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ui/apple_glass.dart';
import '../../utils/course/get_course.dart';
import '../../utils/course/coursemain.dart';
import '../../widget_refresh_service.dart';
import 'widgets/course_table_widgets.dart';

class CourseTableView extends StatefulWidget {
  const CourseTableView({super.key});

  @override
  State<CourseTableView> createState() => _CourseTableViewState();
}

/*
 * 课程数据模型类
 * @param name 课程名称
 * @param startSection 课程开始的节数（1-based）
 * @param duration 课程持续节数
 */

DateTime getMondayOfCurrentWeek() {
  final DateTime now = DateTime.now();
  // 计算当前日期与本周一的差值（星期一对应的weekday为1）
  int daysToSubtract = now.weekday - 1;
  // 处理周日的情况（Dart中周日weekday=7）
  if (now.weekday == 7) {
    daysToSubtract = 6;
  }
  // 刷新桌面小组件
  WidgetRefreshService.refreshCourseTableWidget();
  return now.subtract(Duration(days: daysToSubtract));
}

class _CourseTableViewState extends State<CourseTableView> {
  static const int _defaultMaxWeek = 20;
  static const int _sectionCount = 10;
  static const String _showExperimentCoursesKey = 'showExperimentCourses';
  static const double _timeColumnWidth = 30;
  static const double _columnGap = 2;
  static const double _rowGap = 3;
  static const double _headerHeight = 54;
  static const double _headerGap = 8;
  static const double _cardInnerGap = 2;
  late final Future<void> _initialLoadFuture;

  // DateTime _currentDate = DateTime.now();
  DateTime _currentDate = getMondayOfCurrentWeek();

  //设置周数
  //当前显示周数
  int _currentWeek = 1;
  int _allWeek = 100;

  //当前实际周数
  int _currentRealWeek = 1;
  bool _showExperimentCourses = true;

  /*
   * 课程数据存储器
   * Key格式：yyyy-MM-dd 的日期字符串
   * Value：当天课程列表
   */
  late Map<String, List<Course>> _courseData = {};

  // 定义一个映射来存储 weekday 数字到中文星期名称的对应关系
  final Map<int, String> _weekdayMap = {
    1: '周一',
    2: '周二',
    3: '周三',
    4: '周四',
    5: '周五',
    6: '周六',
    7: '周日',
  };

  @override
  void initState() {
    super.initState();
    _initialLoadFuture = _loadInitialData();
  }

  // 综合计算周数的完整函数
  int calculateSchoolWeek(String? firstDayString) {
    // 异常情况处理
    if (firstDayString == null) throw ArgumentError('firstDay 不能为空');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(firstDayString)) {
      throw FormatException('日期格式应为 yyyy-MM-dd');
    }

    // 1. 字符串转DateTime
    final firstDay = DateTime.parse(firstDayString);

    // 2. 转换为当周周一
    final firstMonday = firstDay.subtract(Duration(days: firstDay.weekday - 1));

    // 3. 计算当前周数
    final now = DateTime.now();
    final difference = now.difference(firstMonday).inDays + 1;

    // 处理早于开学日的情况
    if (difference < 0) return 0;

    return (difference / 7).ceil();
  }

  int _resolveCurrentWeek(String? firstDay) {
    if (firstDay == null || firstDay.isEmpty) {
      return 1;
    }

    try {
      return calculateSchoolWeek(firstDay);
    } on ArgumentError catch (_) {
      return 1;
    } on FormatException catch (_) {
      return 1;
    }
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final firstDay = prefs.getString('firstDay');
    final allWeek = prefs.getInt('maxWeek') ?? _defaultMaxWeek;
    final currentWeek = _resolveCurrentWeek(firstDay);
    final showExperimentCourses =
        prefs.getBool(_showExperimentCoursesKey) ?? true;
    final courseData = await loadClassFromLocal();
    if (!mounted) {
      return;
    }

    setState(() {
      _allWeek = allWeek;
      _currentWeek = currentWeek;
      _currentRealWeek = currentWeek;
      _showExperimentCourses = showExperimentCourses;
      _courseData = courseData;
    });
  }

  Future<void> _setShowExperimentCourses(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showExperimentCoursesKey, value);
    if (!mounted) {
      return;
    }
    setState(() {
      _showExperimentCourses = value;
    });
  }

  /*
   * 获取指定日期所在周的起始日期（周一）
   * @param date 要计算的日期
   * @return 当周周一对应的日期对象
   */
  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  void _backToRealWeek() {
    if (_currentWeek == _currentRealWeek) {
      return;
    }
    setState(() {
      _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month,
        _currentDate.day - 7 * (_currentWeek - _currentRealWeek),
      );
      _currentWeek = _currentRealWeek;
    });
  }

  /*
   * 切换到上个月视图
   * 更新_currentDate为上月第一天
   */
  void _previousWeek() {
    if (_currentWeek <= 1) {
      return;
    }
    setState(() {
      _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month,
        _currentDate.day - 7,
      );
      _currentWeek = _currentWeek - 1;
    });
  }

  /*
   * 切换到下个月视图
   * 更新_currentDate为下月第一天
   */
  void _nextWeek() {
    if (_currentWeek >= _allWeek) {
      return;
    }
    setState(() {
      _currentDate = DateTime(
        _currentDate.year,
        _currentDate.month,
        _currentDate.day + 7,
      );
      _currentWeek = _currentWeek + 1;
    });
  }

  /*
   * 生成日期格式化键
   * @param date 要格式化的日期对象
   * @return yyyy-MM-dd格式的日期字符串
   */
  String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  bool _isToday(DateTime date) => _isSameDay(date, DateTime.now());

  List<Course> _visibleCoursesForDay(DateTime date) {
    final courses = _courseData[_dateKey(date)] ?? const <Course>[];
    if (_showExperimentCourses) {
      return List<Course>.from(courses);
    }
    return courses.where((course) => !course.isExp).toList();
  }

  /*
   * 根据课程名称生成固定颜色
   * @param seed 颜色生成种子字符串（课程名称）
   * @return HSL颜色空间生成的固定颜色
   */
  _CoursePalette _getCoursePalette(String seed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hash = seed.hashCode % 360;
    final fill =
        HSLColor.fromAHSL(
          1,
          hash.toDouble(),
          isDark ? 0.48 : 0.54,
          isDark ? 0.36 : 0.76,
        ).toColor();
    final border =
        HSLColor.fromAHSL(
          1,
          hash.toDouble(),
          isDark ? 0.42 : 0.44,
          isDark ? 0.50 : 0.64,
        ).toColor();
    final foreground =
        ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
            ? Colors.white
            : const Color(0xFF102033);

    return _CoursePalette(
      fill: fill,
      border: border.withValues(alpha: isDark ? 0.90 : 0.74),
      foreground: foreground,
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _buildSectionLabel(int startSection, int endSection) {
    if (startSection == endSection) {
      return '第$startSection节';
    }
    return '第$startSection-$endSection节';
  }

  String _buildCourseScheduleText(
    DateTime day,
    int startSection,
    int endSection,
  ) {
    final startTime = _sectionTimes[startSection - 1].start;
    final endTime = _sectionTimes[endSection - 1].end;
    final weekdayLabel = _weekdayMap[day.weekday] ?? '';
    return '$weekdayLabel ${_buildSectionLabel(startSection, endSection)} $startTime - $endTime';
  }

  String _buildCourseCopyText(_PlacedCourse placement) {
    final course = placement.course;
    return <String>[
      '课程名称：${course.name}',
      '周数：${course.weekDuration}',
      '时间：${_buildCourseScheduleText(placement.day, placement.startSection, placement.endSection)}',
      '教师：${course.teacherName.isEmpty ? '暂无教师信息' : course.teacherName}',
      '地点：${course.location.isEmpty ? '暂无上课地点' : course.location}',
    ].join('\n');
  }

  void _showCourseDetails(_PlacedCourse placement) {
    final course = placement.course;
    showCupertinoModalBottomSheet(
      expand: false,
      context: context,
      builder:
          (sheetContext) => CourseDetailSheet(
            course: course,
            scheduleText: _buildCourseScheduleText(
              placement.day,
              placement.startSection,
              placement.endSection,
            ),
            copyText: _buildCourseCopyText(placement),
            onViewStudents:
                course.isExp
                    ? () {
                      Navigator.of(sheetContext).pop();
                      _showExpStudents(course.pcid);
                    }
                    : null,
          ),
    );
  }

  static const List<_SectionTime> _sectionTimes = [
    _SectionTime(index: 1, start: '08:00', end: '08:45'),
    _SectionTime(index: 2, start: '08:55', end: '09:40'),
    _SectionTime(index: 3, start: '10:00', end: '10:45'),
    _SectionTime(index: 4, start: '10:55', end: '11:40'),
    _SectionTime(index: 5, start: '14:00', end: '14:45'),
    _SectionTime(index: 6, start: '14:55', end: '15:40'),
    _SectionTime(index: 7, start: '16:00', end: '16:45'),
    _SectionTime(index: 8, start: '16:55', end: '17:40'),
    _SectionTime(index: 9, start: '19:00', end: '19:45'),
    _SectionTime(index: 10, start: '19:55', end: '20:40'),
  ];

  String _buildWeekDateRange(List<DateTime> weekDays) {
    final start = DateFormat('M/d').format(weekDays.first);
    final end = DateFormat('M/d').format(weekDays.last);
    return '$start - $end';
  }

  String _buildCurrentWeekLabel() {
    return '当前第$_currentRealWeek周';
  }

  _WeekGridMetrics _buildGridMetrics(BoxConstraints constraints) {
    final availableGridHeight = math.max(
      0,
      constraints.maxHeight - _headerHeight - _headerGap,
    );
    final rowGapBudget = _rowGap * (_sectionCount - 1);
    var slotHeight = (availableGridHeight - rowGapBudget) / _sectionCount;
    if (!slotHeight.isFinite || slotHeight.isNegative) {
      slotHeight = 0;
    }
    slotHeight = slotHeight.clamp(16.0, 56.0).toDouble();

    final maxFitSlotHeight = math.max(
      0.0,
      (availableGridHeight - rowGapBudget) / _sectionCount,
    );
    if (slotHeight > maxFitSlotHeight) {
      slotHeight = maxFitSlotHeight.toDouble();
    }

    final gridHeight =
        slotHeight * _sectionCount + _rowGap * (_sectionCount - 1);
    final dayWidth = math.max(
      0.0,
      (constraints.maxWidth - _timeColumnWidth - (_columnGap * 6)) / 7,
    );

    return _WeekGridMetrics(
      timeColumnWidth: _timeColumnWidth,
      dayWidth: dayWidth.toDouble(),
      columnGap: _columnGap,
      rowGap: _rowGap,
      slotHeight: slotHeight,
      gridHeight: gridHeight,
    );
  }

  _CourseSpan? _normalizeCourse(Course course) {
    if (course.duration <= 0) {
      return null;
    }

    final rawEndSection = course.startSection + course.duration - 1;
    if (rawEndSection < 1 || course.startSection > _sectionCount) {
      return null;
    }

    final startSection = course.startSection.clamp(1, _sectionCount).toInt();
    final endSection = rawEndSection.clamp(startSection, _sectionCount).toInt();

    return _CourseSpan(
      course: course,
      startSection: startSection,
      endSection: endSection,
    );
  }

  List<_PlacedCourse> _buildPlacedCourses(
    List<DateTime> weekDays,
    _WeekGridMetrics metrics,
  ) {
    final placements = <_PlacedCourse>[];
    for (var dayIndex = 0; dayIndex < weekDays.length; dayIndex++) {
      final dayCourses = _visibleCoursesForDay(weekDays[dayIndex]);
      placements.addAll(
        _layoutDayCourses(
          dayCourses: dayCourses,
          dayDate: weekDays[dayIndex],
          dayIndex: dayIndex,
          metrics: metrics,
        ),
      );
    }
    return placements;
  }

  List<_PlacedCourse> _layoutDayCourses({
    required List<Course> dayCourses,
    required DateTime dayDate,
    required int dayIndex,
    required _WeekGridMetrics metrics,
  }) {
    final sortedCourses =
        dayCourses.map(_normalizeCourse).whereType<_CourseSpan>().toList()
          ..sort((a, b) {
            final startCompare = a.startSection.compareTo(b.startSection);
            if (startCompare != 0) {
              return startCompare;
            }
            return b.endSection.compareTo(a.endSection);
          });
    final clusters = <List<_CourseSpan>>[];
    var currentCluster = <_CourseSpan>[];
    var currentEnd = 0;

    for (final courseSpan in sortedCourses) {
      if (currentCluster.isEmpty || courseSpan.startSection <= currentEnd) {
        currentCluster.add(courseSpan);
        if (courseSpan.endSection > currentEnd) {
          currentEnd = courseSpan.endSection;
        }
      } else {
        clusters.add(currentCluster);
        currentCluster = [courseSpan];
        currentEnd = courseSpan.endSection;
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    final placements = <_PlacedCourse>[];
    final dayLeft = metrics.leftForDay(dayIndex);

    for (final cluster in clusters) {
      final active = <_ActiveCourseSlot>[];
      final assignments = <_CourseAssignment>[];
      var columnCount = 0;

      for (final courseSpan in cluster) {
        active.removeWhere((slot) => slot.endSection < courseSpan.startSection);

        var column = 0;
        while (active.any((slot) => slot.column == column)) {
          column++;
        }
        active.add(
          _ActiveCourseSlot(column: column, endSection: courseSpan.endSection),
        );
        assignments.add(
          _CourseAssignment(courseSpan: courseSpan, column: column),
        );
        if (column + 1 > columnCount) {
          columnCount = column + 1;
        }
      }

      final cardWidth = math.max(
        8.0,
        (metrics.dayWidth - (columnCount - 1) * _cardInnerGap) / columnCount,
      );
      for (final assignment in assignments) {
        final courseSpan = assignment.courseSpan;
        final top = metrics.topForSection(courseSpan.startSection);
        final height = metrics.heightForDuration(courseSpan.duration);
        final left = dayLeft + assignment.column * (cardWidth + _cardInnerGap);
        placements.add(
          _PlacedCourse(
            course: courseSpan.course,
            day: dayDate,
            startSection: courseSpan.startSection,
            endSection: courseSpan.endSection,
            left: left,
            top: top,
            width: cardWidth.toDouble(),
            height: height,
          ),
        );
      }
    }

    return placements;
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = _getStartOfWeek(_currentDate);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final showWeekStr = '第$_currentWeek周';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        child: SafeArea(
          bottom: false,
          child: EnhancedFutureBuilder(
            future: _initialLoadFuture,
            rememberFutureResult: true,
            whenDone: (_) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 88),
                child: Column(
                  children: [
                    CourseTableToolbar(
                      weekTitle: showWeekStr,
                      weekDateRange: _buildWeekDateRange(weekDays),
                      currentWeekLabel: _buildCurrentWeekLabel(),
                      isShowingCurrentWeek: _currentWeek == _currentRealWeek,
                      onBackToCurrentWeek: _backToRealWeek,
                      showExperimentCourses: _showExperimentCourses,
                      onShowExperimentCoursesChanged: _setShowExperimentCourses,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final metrics = _buildGridMetrics(constraints);
                          final placedCourses = _buildPlacedCourses(
                            weekDays,
                            metrics,
                          );
                          final theme = Theme.of(context);
                          final colorScheme = theme.colorScheme;
                          final isDark = theme.brightness == Brightness.dark;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragEnd: (details) {
                              final velocity = details.primaryVelocity ?? 0;
                              if (velocity > 10) {
                                _previousWeek();
                              } else if (velocity < -10) {
                                _nextWeek();
                              }
                            },
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: _headerHeight,
                                    width: metrics.totalWidth,
                                    child: _WeekHeaderStrip(
                                      weekDays: weekDays,
                                      weekdayMap: _weekdayMap,
                                      metrics: metrics,
                                    ),
                                  ),
                                  const SizedBox(height: _headerGap),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(22),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(22),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white.withValues(
                                              alpha: isDark ? 0.10 : 0.52,
                                            ),
                                            colorScheme.surface.withValues(
                                              alpha: isDark ? 0.08 : 0.30,
                                            ),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: isDark ? 0.10 : 0.72,
                                          ),
                                        ),
                                      ),
                                      child: SizedBox(
                                        width: metrics.totalWidth,
                                        height: metrics.gridHeight,
                                        child: Stack(
                                          clipBehavior: Clip.hardEdge,
                                          children: [
                                            ...weekDays.asMap().entries.map((
                                              entry,
                                            ) {
                                              final index = entry.key;
                                              final day = entry.value;
                                              final isToday = _isToday(day);
                                              return Positioned(
                                                left: metrics.leftForDay(index),
                                                top: 0,
                                                width: metrics.dayWidth,
                                                height: metrics.gridHeight,
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color:
                                                        isToday
                                                            ? colorScheme
                                                                .primary
                                                                .withValues(
                                                                  alpha:
                                                                      isDark
                                                                          ? 0.08
                                                                          : 0.06,
                                                                )
                                                            : Colors
                                                                .transparent,
                                                  ),
                                                ),
                                              );
                                            }),
                                            ...List.generate(_sectionCount, (
                                              index,
                                            ) {
                                              final top = metrics.topForSection(
                                                index + 1,
                                              );
                                              return Positioned(
                                                left:
                                                    metrics.timeColumnWidth +
                                                    _columnGap,
                                                right: 0,
                                                top: top,
                                                height: metrics.slotHeight,
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      top: BorderSide(
                                                        color: colorScheme
                                                            .outlineVariant
                                                            .withValues(
                                                              alpha:
                                                                  isDark
                                                                      ? 0.24
                                                                      : 0.34,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                            ...List.generate(6, (index) {
                                              final left =
                                                  metrics.leftForDay(index) +
                                                  metrics.dayWidth +
                                                  (_columnGap / 2);
                                              return Positioned(
                                                left: left,
                                                top: 0,
                                                width: 1,
                                                height: metrics.gridHeight,
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: colorScheme
                                                        .outlineVariant
                                                        .withValues(
                                                          alpha:
                                                              isDark
                                                                  ? 0.18
                                                                  : 0.22,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }),
                                            ..._sectionTimes.map((section) {
                                              final top = metrics.topForSection(
                                                section.index,
                                              );
                                              return Positioned(
                                                left: 0,
                                                top: top,
                                                width: metrics.timeColumnWidth,
                                                height: metrics.slotHeight,
                                                child: _TimeAxisLabel(
                                                  section: section,
                                                ),
                                              );
                                            }),
                                            if (placedCourses.isEmpty)
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: Center(
                                                    child: Text(
                                                      '本周暂无课程',
                                                      style: theme
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color: colorScheme
                                                                .onSurfaceVariant
                                                                .withValues(
                                                                  alpha: 0.82,
                                                                ),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ...placedCourses.map((placement) {
                                              final palette = _getCoursePalette(
                                                placement.course.name,
                                              );
                                              return Positioned(
                                                left: placement.left,
                                                top: placement.top,
                                                width: placement.width,
                                                height: placement.height,
                                                child: _ScheduleCourseCard(
                                                  course: placement.course,
                                                  palette: palette,
                                                  onTap:
                                                      () => _showCourseDetails(
                                                        placement,
                                                      ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
            whenNotDone: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showExpStudents(String pcid) async {
    if (pcid.isEmpty) {
      _showSnackBar('无法获取人员名单：缺少pcid，请在设置页刷新课表');
      return;
    }
    final Map<String, dynamic> re = await getExpStudentList(pcid);
    if (!mounted) {
      return;
    }

    if (re['code']?.toString() != '1') {
      _showSnackBar('获取人员名单失败');
      return;
    }
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      re['data'] as Map? ?? <String, dynamic>{},
    );
    final Map<String, dynamic> baseData = Map<String, dynamic>.from(
      data['baseData'] as Map? ?? <String, dynamic>{},
    );
    final List<Map<String, dynamic>> students =
        (data['studentList'] as List? ?? <dynamic>[])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

    showCupertinoModalBottomSheet(
      expand: false,
      context: context,
      builder:
          (sheetContext) =>
              ExperimentStudentsSheet(baseData: baseData, students: students),
    );
  }
}

class _CoursePalette {
  const _CoursePalette({
    required this.fill,
    required this.border,
    required this.foreground,
  });

  final Color fill;
  final Color border;
  final Color foreground;
}

class _SectionTime {
  const _SectionTime({
    required this.index,
    required this.start,
    required this.end,
  });

  final int index;
  final String start;
  final String end;
}

class _CourseSpan {
  const _CourseSpan({
    required this.course,
    required this.startSection,
    required this.endSection,
  });

  final Course course;
  final int startSection;
  final int endSection;

  int get duration => endSection - startSection + 1;
}

class _WeekGridMetrics {
  const _WeekGridMetrics({
    required this.timeColumnWidth,
    required this.dayWidth,
    required this.columnGap,
    required this.rowGap,
    required this.slotHeight,
    required this.gridHeight,
  });

  final double timeColumnWidth;
  final double dayWidth;
  final double columnGap;
  final double rowGap;
  final double slotHeight;
  final double gridHeight;

  double get totalWidth => timeColumnWidth + (dayWidth * 7) + (columnGap * 6);

  double leftForDay(int dayIndex) {
    return timeColumnWidth + dayIndex * (dayWidth + columnGap);
  }

  double topForSection(int section) {
    return (section - 1) * (slotHeight + rowGap);
  }

  double heightForDuration(int duration) {
    return slotHeight * duration + rowGap * (duration - 1);
  }
}

class _PlacedCourse {
  const _PlacedCourse({
    required this.course,
    required this.day,
    required this.startSection,
    required this.endSection,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final Course course;
  final DateTime day;
  final int startSection;
  final int endSection;
  final double left;
  final double top;
  final double width;
  final double height;
}

class _ActiveCourseSlot {
  const _ActiveCourseSlot({required this.column, required this.endSection});

  final int column;
  final int endSection;
}

class _CourseAssignment {
  const _CourseAssignment({required this.courseSpan, required this.column});

  final _CourseSpan courseSpan;
  final int column;
}

class _WeekHeaderStrip extends StatelessWidget {
  const _WeekHeaderStrip({
    required this.weekDays,
    required this.weekdayMap,
    required this.metrics,
  });

  final List<DateTime> weekDays;
  final Map<int, String> weekdayMap;
  final _WeekGridMetrics metrics;

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();

    return Row(
      children: [
        SizedBox(width: metrics.timeColumnWidth),
        ...weekDays.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          final isToday = _isSameDay(day, now);

          return Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : metrics.columnGap),
            child: SizedBox(
              width: metrics.dayWidth,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color:
                      isToday
                          ? colorScheme.primary.withValues(
                            alpha: isDark ? 0.18 : 0.12,
                          )
                          : Colors.white.withValues(
                            alpha: isDark ? 0.04 : 0.28,
                          ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isToday
                            ? colorScheme.primary.withValues(
                              alpha: isDark ? 0.34 : 0.22,
                            )
                            : Colors.white.withValues(
                              alpha: isDark ? 0.08 : 0.60,
                            ),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        weekdayMap[day.weekday] ?? '',
                        maxLines: 1,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color:
                              isToday
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        DateFormat('M/d').format(day),
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              isToday
                                  ? colorScheme.primary.withValues(alpha: 0.88)
                                  : colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.82,
                                  ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _TimeAxisLabel extends StatelessWidget {
  const _TimeAxisLabel({required this.section});

  final _SectionTime section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showTime = constraints.maxHeight >= 24;
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${section.index}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              if (showTime) ...[
                const SizedBox(height: 1),
                _SingleLineScaleText(
                  text: section.start,
                  height: 8,
                  alignment: Alignment.centerRight,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.78),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                _SingleLineScaleText(
                  text: section.end,
                  height: 8,
                  alignment: Alignment.centerRight,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.62),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ScheduleCourseCard extends StatelessWidget {
  const _ScheduleCourseCard({
    required this.course,
    required this.palette,
    required this.onTap,
  });

  final Course course;
  final _CoursePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;
        final compact = height < 44 || width < 38;
        final ultraCompact = height < 30 || width < 28;
        final showLocation = course.location.isNotEmpty && !ultraCompact;
        final showTeacher =
            course.teacherName.isNotEmpty && height >= 58 && width >= 34;
        final titleStyle =
            Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.foreground.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
              fontSize: compact ? 10.1 : 11.2,
              height: 1.18,
              letterSpacing: -0.12,
            ) ??
            TextStyle(
              color: palette.foreground.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
              fontSize: compact ? 10.1 : 11.2,
              height: 1.18,
              letterSpacing: -0.12,
            );
        final infoStyle =
            Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.foreground.withValues(alpha: 0.88),
              fontSize: compact ? 9.0 : 9.4,
              fontWeight: FontWeight.w700,
              height: 1,
            ) ??
            TextStyle(
              color: palette.foreground.withValues(alpha: 0.88),
              fontSize: compact ? 9.0 : 9.4,
              fontWeight: FontWeight.w700,
              height: 1,
            );
        final secondaryInfoStyle = infoStyle.copyWith(
          color: palette.foreground.withValues(alpha: 0.82),
          fontWeight: FontWeight.w600,
        );
        final horizontalPadding = compact ? 3.5 : 5.0;
        final topPadding = compact ? 3.5 : 5.0;
        final bottomPadding = compact ? 2.5 : 4.0;
        final detailSpacing = compact ? 1.0 : 2.0;
        final titleBottomSpacing =
            (showLocation || showTeacher) ? detailSpacing : 0.0;
        final locationLineHeight = compact ? 10.0 : 11.0;
        final teacherLineHeight = compact ? 9.0 : 10.0;
        final reservedDetailHeight =
            (showLocation ? locationLineHeight : 0.0) +
            (showTeacher ? teacherLineHeight : 0.0) +
            (showLocation && showTeacher ? detailSpacing : 0.0);
        final titleLineHeight =
            (titleStyle.fontSize ?? 11.4) * (titleStyle.height ?? 1.15);
        final availableTitleHeight = math.max(
          titleLineHeight,
          height -
              topPadding -
              bottomPadding -
              reservedDetailHeight -
              titleBottomSpacing,
        );
        final titleMaxLines = math.max(
          1,
          (availableTitleHeight / titleLineHeight).floor(),
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(compact ? 10 : 14),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(compact ? 10 : 14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.fill,
                    Color.lerp(palette.fill, palette.border, 0.42)!,
                  ],
                ),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: palette.border.withValues(alpha: 0.14),
                    blurRadius: compact ? 8 : 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -18,
                    right: -12,
                    child: IgnorePointer(
                      child: Container(
                        width: compact ? 34 : 52,
                        height: compact ? 34 : 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.26),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              course.name,
                              maxLines: ultraCompact ? 1 : titleMaxLines,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                          ),
                        ),
                        if (showLocation) ...[
                          SizedBox(height: detailSpacing),
                          _SingleLineScaleText(
                            text: course.location,
                            style: infoStyle,
                            height: locationLineHeight,
                          ),
                        ],
                        if (showTeacher) ...[
                          SizedBox(height: detailSpacing),
                          _SingleLineScaleText(
                            text: course.teacherName,
                            style: secondaryInfoStyle,
                            height: teacherLineHeight,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SingleLineScaleText extends StatelessWidget {
  const _SingleLineScaleText({
    required this.text,
    required this.style,
    this.height = 10,
    this.alignment = Alignment.centerLeft,
  });

  final String text;
  final TextStyle? style;
  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Align(
        alignment: alignment,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Text(text, maxLines: 1, softWrap: false, style: style),
        ),
      ),
    );
  }
}
