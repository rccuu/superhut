import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../bridge/get_course_page.dart';
import '../../core/services/app_auth_storage.dart';
import '../../core/ui/apple_glass.dart';
import '../../core/ui/color_scheme_ext.dart';
import '../../login/unified_login_page.dart';
import '../../utils/course/get_course.dart';
import '../../utils/course/coursemain.dart';
import '../../utils/token.dart';
import '../../widget_refresh_service.dart';
import 'widgets/course_table_widgets.dart';

class CourseTableView extends StatefulWidget {
  const CourseTableView({super.key, this.debugScheduleOverride});

  @visibleForTesting
  final SavedCourseSchedule? debugScheduleOverride;

  @override
  State<CourseTableView> createState() => _CourseTableViewState();
}

/*
 * 课程数据模型类
 * @param name 课程名称
 * @param startSection 课程开始的节数（1-based）
 * @param duration 课程持续节数
 */

DateTime getMondayOfCurrentWeek({bool refreshWidget = true}) {
  final DateTime now = DateTime.now();
  // 计算当前日期与本周一的差值（星期一对应的weekday为1）
  int daysToSubtract = now.weekday - 1;
  // 处理周日的情况（Dart中周日weekday=7）
  if (now.weekday == 7) {
    daysToSubtract = 6;
  }
  // 刷新桌面小组件
  if (refreshWidget) {
    WidgetRefreshService.refreshCourseTableWidget();
  }
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
  late final PageController _weekPageController;
  bool _hasLinkedCampusAccount = false;
  bool _isPrimaryActionLoading = false;
  bool _isCurrentTermSchedule = true;

  // DateTime _currentDate = DateTime.now();
  DateTime _currentDate = getMondayOfCurrentWeek();

  //设置周数
  //当前显示周数
  int _currentWeek = 1;
  int _allWeek = _defaultMaxWeek;

  //当前实际周数
  int _currentRealWeek = 1;
  bool _showExperimentCourses = true;
  SavedCourseSchedule? _activeSchedule;
  List<SavedCourseSchedule> _savedSchedules = const [];

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
    _weekPageController = PageController();
    _initialLoadFuture = _loadInitialData();
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    super.dispose();
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

  DateTime? _tryParseDate(String value) {
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  DateTime _startOfMonday(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  bool _isScheduleCurrentTerm(SavedCourseSchedule? schedule) {
    if (schedule == null ||
        schedule.firstDay.isEmpty ||
        schedule.maxWeek <= 0) {
      return false;
    }

    final firstDay = _tryParseDate(schedule.firstDay);
    if (firstDay == null) {
      return false;
    }

    final firstMonday = _startOfMonday(firstDay);
    final now = DateTime.now();
    final termEnd = firstMonday.add(Duration(days: schedule.maxWeek * 7 - 1));
    return !now.isBefore(firstMonday) && !now.isAfter(termEnd);
  }

  int _resolveCurrentWeekForSchedule(SavedCourseSchedule? schedule) {
    if (schedule == null) {
      return 1;
    }

    if (!_isScheduleCurrentTerm(schedule)) {
      return 1;
    }

    final maxWeek = schedule.maxWeek > 0 ? schedule.maxWeek : _defaultMaxWeek;
    final computed = _resolveCurrentWeek(schedule.firstDay);
    return computed.clamp(1, maxWeek).toInt();
  }

  DateTime _buildInitialDateForSchedule(
    SavedCourseSchedule? schedule,
    int currentWeek,
  ) {
    if (schedule == null) {
      return getMondayOfCurrentWeek(refreshWidget: false);
    }

    final firstDay = _tryParseDate(schedule.firstDay);
    if (firstDay == null) {
      return getMondayOfCurrentWeek(refreshWidget: false);
    }

    final firstMonday = _startOfMonday(firstDay);
    return firstMonday.add(Duration(days: (currentWeek - 1) * 7));
  }

  String _buildScheduleStatusLabel() {
    if (_activeSchedule == null) {
      return '';
    }
    if (!_isCurrentTermSchedule) {
      return '已归档';
    }
    return '当前第$_currentRealWeek周';
  }

  String _scheduleSourceLabel(SavedCourseSchedule schedule) {
    switch (schedule.sourceType) {
      case CourseScheduleSourceType.selfSync:
        return '登录同步';
      case CourseScheduleSourceType.shareImport:
        return '朋友分享';
      case CourseScheduleSourceType.migratedLegacy:
        return '本地迁移';
      default:
        return '本地保存';
    }
  }

  String _buildScheduleListSubtitle(SavedCourseSchedule schedule) {
    final parts = <String>[
      if (schedule.ownerName.isNotEmpty) schedule.ownerName,
      if (schedule.termLabel.isNotEmpty) schedule.termLabel,
      _scheduleSourceLabel(schedule),
    ];
    return parts.join(' · ');
  }

  List<String> _scheduleBadges(
    SavedCourseSchedule schedule, {
    required bool isActive,
  }) {
    final badges = <String>[];
    if (isActive) {
      badges.add('当前');
    }
    if (schedule.sourceType == CourseScheduleSourceType.selfSync) {
      badges.add('我的');
    } else if (schedule.sourceType == CourseScheduleSourceType.shareImport) {
      badges.add('分享');
    }
    return badges;
  }

  Future<void> _reloadScheduleState() async {
    final prefs = await SharedPreferences.getInstance();
    final showExperimentCourses =
        prefs.getBool(_showExperimentCoursesKey) ?? true;
    final hasLinkedCampusAccount =
        await AppAuthStorage.instance.hasLinkedCampusAccount();
    final overrideSchedule = widget.debugScheduleOverride;
    final savedSchedules =
        overrideSchedule == null
            ? await loadSavedCourseSchedules()
            : <SavedCourseSchedule>[overrideSchedule];
    final activeSchedule = overrideSchedule ?? await loadActiveCourseSchedule();
    final courseData =
        activeSchedule?.courseData ?? const <String, List<Course>>{};
    final isCurrentTermSchedule = _isScheduleCurrentTerm(activeSchedule);
    final allWeek =
        activeSchedule == null
            ? _defaultMaxWeek
            : (activeSchedule.maxWeek <= 0
                ? _defaultMaxWeek
                : activeSchedule.maxWeek);
    final currentWeek = _resolveCurrentWeekForSchedule(activeSchedule);
    final currentDate = _buildInitialDateForSchedule(
      activeSchedule,
      currentWeek,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _savedSchedules = savedSchedules;
      _activeSchedule = activeSchedule;
      _courseData = courseData;
      _allWeek = allWeek;
      _currentWeek = currentWeek;
      _currentRealWeek = currentWeek;
      _currentDate = currentDate;
      _showExperimentCourses = showExperimentCourses;
      _hasLinkedCampusAccount = hasLinkedCampusAccount;
      _isCurrentTermSchedule = isCurrentTermSchedule;
    });
    _syncWeekPageToCurrentWeek();
  }

  Future<void> _loadInitialData() async {
    await _reloadScheduleState();
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

  List<DateTime> _buildWeekDays(DateTime anchorDate) {
    final weekStart = _getStartOfWeek(anchorDate);
    return List.generate(7, (i) => weekStart.add(Duration(days: i)));
  }

  int _normalizeWeek(int weekNumber) {
    return weekNumber.clamp(1, _allWeek).toInt();
  }

  DateTime _dateForWeek(int weekNumber) {
    final normalizedWeek = _normalizeWeek(weekNumber);
    final schedule = _activeSchedule;
    final firstDay = schedule == null ? null : _tryParseDate(schedule.firstDay);
    if (firstDay != null) {
      final firstMonday = _startOfMonday(firstDay);
      return firstMonday.add(Duration(days: (normalizedWeek - 1) * 7));
    }

    return _currentDate.add(
      Duration(days: (normalizedWeek - _currentWeek) * 7),
    );
  }

  List<DateTime> _buildWeekDaysForWeek(int weekNumber) {
    return _buildWeekDays(_dateForWeek(weekNumber));
  }

  void _applyDisplayedWeek(int targetWeek) {
    final normalizedWeek = _normalizeWeek(targetWeek);
    final targetDate = _dateForWeek(normalizedWeek);
    if (normalizedWeek == _currentWeek &&
        _isSameDay(targetDate, _currentDate)) {
      return;
    }
    setState(() {
      _currentWeek = normalizedWeek;
      _currentDate = targetDate;
    });
  }

  void _moveWeekPagerTo(int targetWeek, {bool animated = false}) {
    final targetPage = _normalizeWeek(targetWeek) - 1;

    void move() {
      if (!mounted || !_weekPageController.hasClients) {
        return;
      }
      final currentPage =
          _weekPageController.page ??
          _weekPageController.initialPage.toDouble();
      if ((currentPage - targetPage).abs() < 0.01) {
        return;
      }
      if (animated) {
        unawaited(
          _weekPageController.animateToPage(
            targetPage,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          ),
        );
        return;
      }
      _weekPageController.jumpToPage(targetPage);
    }

    if (_weekPageController.hasClients) {
      move();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      move();
    });
  }

  void _syncWeekPageToCurrentWeek({bool animated = false}) {
    _moveWeekPagerTo(_currentWeek, animated: animated);
  }

  void _handleWeekPageChanged(int pageIndex) {
    _applyDisplayedWeek(pageIndex + 1);
  }

  void _goToWeek(int targetWeek, {bool animated = true}) {
    final normalizedWeek = _normalizeWeek(targetWeek);
    if (!animated) {
      _applyDisplayedWeek(normalizedWeek);
    }
    _moveWeekPagerTo(normalizedWeek, animated: animated);
  }

  void _backToRealWeek() {
    if (_currentWeek == _currentRealWeek) {
      return;
    }
    _goToWeek(_currentRealWeek, animated: false);
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

  bool get _useLiteAndroidEffects =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Color _sheetRouteBackground(BuildContext context) {
    return Colors.transparent;
  }

  Color _sheetBarrierColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return colorScheme.overlayScrim.withValues(
      alpha: colorScheme.isDarkMode ? 0.20 : 0.10,
    );
  }

  Color _sheetTransitionBackground(BuildContext context) {
    return Colors.transparent;
  }

  Future<T?> _showAdaptiveBottomSheet<T>({
    required WidgetBuilder builder,
    bool expand = false,
  }) {
    if (_useLiteAndroidEffects) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: _sheetBarrierColor(context),
        builder: builder,
      );
    }

    return showCupertinoModalBottomSheet<T>(
      context: context,
      expand: expand,
      backgroundColor: _sheetRouteBackground(context),
      barrierColor: _sheetBarrierColor(context),
      transitionBackgroundColor: _sheetTransitionBackground(context),
      builder: builder,
    );
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
    _showAdaptiveBottomSheet<void>(
      expand: false,
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
                course.isExp && course.pcid.isNotEmpty
                    ? () {
                      Navigator.of(sheetContext).pop();
                      _showExpStudents(course.pcid);
                    }
                    : null,
          ),
    );
  }

  Future<void> _openCampusLogin() async {
    await Navigator.of(context).push(UnifiedLoginPage.route());
    await _reloadScheduleState();
  }

  Future<void> _handlePrimaryAction() async {
    if (_isPrimaryActionLoading) {
      return;
    }

    if (!_hasLinkedCampusAccount) {
      await _openCampusLogin();
      return;
    }

    setState(() {
      _isPrimaryActionLoading = true;
    });

    try {
      final renewed = await renewToken(context);
      if (!mounted) {
        return;
      }
      if (!renewed) {
        await _openCampusLogin();
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const Getcoursepage(renew: true),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPrimaryActionLoading = false;
        });
      }
    }
  }

  Future<void> _switchToSchedule(SavedCourseSchedule schedule) async {
    if (_activeSchedule?.id == schedule.id) {
      return;
    }

    try {
      await setActiveCourseSchedule(schedule.id);
      await _reloadScheduleState();
      _showSnackBar('已切换到 ${schedule.name}');
    } catch (error) {
      _showSnackBar('切换课表失败：$error');
    }
  }

  Future<void> _confirmDeleteSchedule(SavedCourseSchedule schedule) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: const Text('删除课表'),
                content: Text('确认删除“${schedule.name}”吗？删除后只能重新导入或重新同步。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('删除'),
                  ),
                ],
              ),
        ) ??
        false;
    if (!shouldDelete) {
      return;
    }

    final deleted = await deleteCourseSchedule(schedule.id);
    if (!deleted) {
      _showSnackBar('删除失败，请稍后重试');
      return;
    }

    await _reloadScheduleState();
    _showSnackBar('已删除 ${schedule.name}');
  }

  Future<void> _renameSchedule(SavedCourseSchedule schedule) async {
    var draftName = schedule.name;
    final newName = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('重命名课表'),
            content: SizedBox(
              width: 420,
              child: TextFormField(
                initialValue: schedule.name,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: '输入新的课表名称'),
                onChanged: (value) {
                  draftName = value;
                },
                onFieldSubmitted: (value) {
                  Navigator.of(dialogContext).pop(value);
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(draftName),
                child: const Text('保存'),
              ),
            ],
          ),
    );

    if (newName == null) {
      return;
    }

    final normalizedName = newName.trim();
    if (normalizedName.isEmpty) {
      _showSnackBar('课表名称不能为空');
      return;
    }
    if (normalizedName == schedule.name) {
      return;
    }

    try {
      await renameCourseSchedule(schedule.id, normalizedName);
      await _reloadScheduleState();
      _showSnackBar('已重命名为 $normalizedName');
    } catch (error) {
      _showSnackBar('重命名失败：$error');
    }
  }

  Future<void> _importScheduleFromShareCode(
    String rawCode, {
    bool reopenEditorOnFailure = false,
  }) async {
    final code = rawCode.trim();
    if (code.isEmpty) {
      _showSnackBar('请输入分享码');
      return;
    }

    try {
      final importedSchedule = await saveImportedCourseScheduleFromShareCode(
        code,
      );
      await _reloadScheduleState();
      _showSnackBar('已导入 ${importedSchedule.name}');
    } on FormatException catch (error) {
      final message = error.message.toString();
      if (reopenEditorOnFailure) {
        await _showManualImportDialog(
          initialText: rawCode,
          errorMessage: message,
        );
        return;
      }
      _showSnackBar(message);
    } catch (error) {
      _showSnackBar('导入失败：$error');
    }
  }

  Future<void> _showManualImportDialog({
    String initialText = '',
    String? errorMessage,
  }) async {
    var draftCode = initialText;
    final rawCode = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('导入分享课表'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '粘贴工大盒子的课表分享码后即可导入并保存到本地。',
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  if (errorMessage != null && errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextFormField(
                    initialValue: initialText,
                    minLines: 5,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      hintText: 'SUPERHUT1:...',
                    ),
                    onChanged: (value) {
                      draftCode = value;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(draftCode),
                child: const Text('导入'),
              ),
            ],
          ),
    );

    if (rawCode == null) {
      return;
    }
    await _importScheduleFromShareCode(rawCode);
  }

  Future<void> _importScheduleFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final rawCode = clipboardData?.text?.trim() ?? '';
    if (rawCode.isEmpty) {
      await _showManualImportDialog(errorMessage: '剪贴板里没有可导入的分享码');
      return;
    }
    await _importScheduleFromShareCode(rawCode, reopenEditorOnFailure: true);
  }

  Future<void> _importScheduleFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择工大盒子课表文件',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      String rawContent = '';
      if (file.bytes != null) {
        rawContent = utf8.decode(file.bytes!);
      } else if (file.path != null && file.path!.isNotEmpty) {
        rawContent = await File(file.path!).readAsString();
      }

      if (rawContent.trim().isEmpty) {
        _showSnackBar('选中的文件没有可导入内容');
        return;
      }

      final importedSchedule = await saveImportedCourseScheduleFromFileContent(
        rawContent,
      );
      await _reloadScheduleState();
      _showSnackBar('已从文件导入 ${importedSchedule.name}');
    } on FormatException catch (error) {
      _showSnackBar(error.message.toString());
    } catch (error) {
      _showSnackBar('导入文件失败：$error');
    }
  }

  String _sanitizeFileNameSegment(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), '_');
    final safe = normalized.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    return safe.isEmpty ? 'schedule' : safe;
  }

  String _buildExportFileName(SavedCourseSchedule schedule) {
    final name = _sanitizeFileNameSegment(schedule.name);
    final term =
        schedule.termLabel.isEmpty
            ? ''
            : '_${_sanitizeFileNameSegment(schedule.termLabel)}';
    return '$name$term.superhut-course.json';
  }

  Future<File> _writeScheduleExportTempFile(
    SavedCourseSchedule schedule,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${_buildExportFileName(schedule)}');
    await file.writeAsString(buildCourseScheduleExportJsonString(schedule));
    return file;
  }

  Rect _sharePositionOrigin() {
    final box = context.findRenderObject();
    if (box is RenderBox) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  Future<void> _saveActiveScheduleToFile() async {
    final activeSchedule = _activeSchedule;
    if (activeSchedule == null) {
      _showSnackBar('当前没有可导出的课表');
      return;
    }

    try {
      final bytes = Uint8List.fromList(
        utf8.encode(buildCourseScheduleExportJsonString(activeSchedule)),
      );
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '导出课表文件',
        fileName: _buildExportFileName(activeSchedule),
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: bytes,
      );
      if (savedPath == null || savedPath.isEmpty) {
        return;
      }
      _showSnackBar('课表文件已导出');
    } catch (error) {
      _showSnackBar('导出文件失败：$error');
    }
  }

  Future<void> _shareActiveScheduleFile() async {
    final activeSchedule = _activeSchedule;
    if (activeSchedule == null) {
      _showSnackBar('当前没有可分享的课表');
      return;
    }

    try {
      final file = await _writeScheduleExportTempFile(activeSchedule);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '${activeSchedule.name} 课表文件',
        text: '这是 ${activeSchedule.name} 的工大盒子课表文件，导入后即可使用。',
        sharePositionOrigin: _sharePositionOrigin(),
      );
    } catch (error) {
      _showSnackBar('分享文件失败：$error');
    }
  }

  Future<void> _showActiveScheduleQrCode() async {
    final activeSchedule = _activeSchedule;
    if (activeSchedule == null) {
      _showSnackBar('当前没有可分享的课表');
      return;
    }

    final shareCode = buildCourseScheduleShareCode(activeSchedule);
    final validation = QrValidator.validate(
      data: shareCode,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
    );
    if (!validation.isValid) {
      _showSnackBar('当前课表内容较大，二维码方式暂不可用，请改用复制或文件分享');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screenSize = MediaQuery.sizeOf(dialogContext);
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final dialogWidth = math.min(screenSize.width - 16, 560.0);
        final dialogHeight = math.min(screenSize.height - 32, 760.0);
        final dialogPadding = screenSize.width < 420 ? 14.0 : 18.0;
        final footerSpacing = screenSize.width < 420 ? 10.0 : 12.0;
        final qrPanelPadding = screenSize.width < 420 ? 12.0 : 16.0;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              maxHeight: dialogHeight,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final reservedHeight = screenSize.width < 420 ? 244.0 : 262.0;
                final availableWidth =
                    constraints.maxWidth - (dialogPadding * 2);
                final qrPanelSize = math.min(
                  availableWidth,
                  math.max(220.0, constraints.maxHeight - reservedHeight),
                );
                final qrSize = qrPanelSize - (qrPanelPadding * 2);

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors:
                          isDark
                              ? [
                                colorScheme.surfaceContainerHigh,
                                colorScheme.surface,
                                colorScheme.surfaceContainerLow,
                              ]
                              : [
                                Colors.white,
                                colorScheme.surface,
                                colorScheme.surfaceContainerLow,
                              ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : colorScheme.outlineVariant.withValues(
                                alpha: 0.56,
                              ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(
                          alpha: isDark ? 0.28 : 0.12,
                        ),
                        blurRadius: isDark ? 36 : 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      dialogPadding,
                      dialogPadding,
                      dialogPadding,
                      footerSpacing + 2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            GlassIconBadge(
                              icon: Icons.qr_code_2_rounded,
                              tint: colorScheme.primary,
                              size: 50,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '课表分享二维码',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '让对方在工大盒子里使用“扫码导入”即可保存这份课表。',
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
                        Container(
                          width: qrPanelSize,
                          height: qrPanelSize,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors:
                                  isDark
                                      ? [
                                        colorScheme.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.92),
                                      ]
                                      : [
                                        colorScheme.primary.withValues(
                                          alpha: 0.06,
                                        ),
                                        colorScheme.surfaceContainerLow,
                                      ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color:
                                  isDark
                                      ? colorScheme.primary.withValues(
                                        alpha: 0.20,
                                      )
                                      : colorScheme.outlineVariant.withValues(
                                        alpha: 0.56,
                                      ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(
                                  alpha: isDark ? 0.20 : 0.08,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color:
                                      isDark
                                          ? Colors.white.withValues(alpha: 0.18)
                                          : colorScheme.outlineVariant
                                              .withValues(alpha: 0.36),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.22 : 0.08,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(qrPanelPadding),
                                child: QrImageView(
                                  data: shareCode,
                                  size: qrSize,
                                  backgroundColor: Colors.white,
                                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '若扫码失败，可改用“复制分享码”或“分享文件”。',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    () => Navigator.of(dialogContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.72),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('关闭'),
                              ),
                            ),
                            SizedBox(width: footerSpacing),
                            Expanded(
                              child: FilledButton(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: shareCode),
                                  );
                                  if (!dialogContext.mounted) {
                                    return;
                                  }
                                  Navigator.of(dialogContext).pop();
                                },
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('复制分享码'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _scanScheduleQrCode() async {
    try {
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        if (!mounted) {
          return;
        }

        final needsSettings =
            cameraPermission.isPermanentlyDenied ||
            cameraPermission.isRestricted;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              needsSettings
                  ? '相机权限已关闭，请在系统设置中允许工大盒子访问相机后再扫码导入。'
                  : '未授予相机权限，无法扫码导入课表。',
            ),
            action:
                needsSettings
                    ? SnackBarAction(label: '去设置', onPressed: openAppSettings)
                    : null,
          ),
        );
        return;
      }

      if (!mounted) {
        return;
      }
      final navigator = Navigator.of(context);
      final scannedCode = await navigator.push<String>(
        MaterialPageRoute(builder: (_) => const _CourseShareQrScannerPage()),
      );
      if (scannedCode == null || scannedCode.trim().isEmpty) {
        return;
      }
      await _importScheduleFromShareCode(scannedCode);
    } catch (error) {
      _showSnackBar('扫码导入失败：$error');
    }
  }

  Future<void> _exportActiveScheduleShareCode() async {
    final activeSchedule = _activeSchedule;
    if (activeSchedule == null) {
      _showSnackBar('当前没有可分享的课表');
      return;
    }

    final shareCode = buildCourseScheduleShareCode(activeSchedule);
    await Clipboard.setData(ClipboardData(text: shareCode));
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('分享码已复制'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '已经复制 ${activeSchedule.name} 的分享码。对方打开工大盒子后，从剪贴板导入即可使用。',
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(
                            dialogContext,
                          ).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SelectableText(
                      shareCode,
                      maxLines: 6,
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('关闭'),
              ),
              FilledButton(
                onPressed: () async {
                  final navigator = Navigator.of(dialogContext);
                  await Clipboard.setData(ClipboardData(text: shareCode));
                  navigator.pop();
                },
                child: const Text('再次复制'),
              ),
            ],
          ),
    );
  }

  Future<void> _showScheduleManager() async {
    final contentReadyFuture =
        _useLiteAndroidEffects
            ? Future<bool>.delayed(
              const Duration(milliseconds: 120),
              () => true,
            )
            : SynchronousFuture<bool>(true);

    final action = await _showAdaptiveBottomSheet<_ScheduleManagerAction>(
      expand: false,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final sheetHeight = math.min(
          MediaQuery.sizeOf(sheetContext).height * 0.82,
          620.0,
        );

        return Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
            child: _buildScheduleManagerBackground(
              sheetContext,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: SizedBox(
                    height: sheetHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            GlassIconBadge(
                              icon: Icons.layers_rounded,
                              tint: colorScheme.primary,
                              size: 46,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '课表库',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '把自己的历史课表和朋友分享的课表都收进这里，切换、备份、分享都会更清楚。',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildScheduleManagerPrimaryActionButton(sheetContext),
                        const SizedBox(height: 14),
                        Expanded(
                          child: _buildScheduleManagerBody(
                            sheetContext,
                            contentReadyFuture: contentReadyFuture,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (action == null) {
      return;
    }

    switch (action.type) {
      case _ScheduleManagerActionType.scanImport:
        await _scanScheduleQrCode();
        break;
      case _ScheduleManagerActionType.clipboardImport:
        await _importScheduleFromClipboard();
        break;
      case _ScheduleManagerActionType.fileImport:
        await _importScheduleFromFile();
        break;
      case _ScheduleManagerActionType.manualImport:
        await _showManualImportDialog();
        break;
      case _ScheduleManagerActionType.copyShareCode:
        await _exportActiveScheduleShareCode();
        break;
      case _ScheduleManagerActionType.showQrCode:
        await _showActiveScheduleQrCode();
        break;
      case _ScheduleManagerActionType.exportFile:
        await _saveActiveScheduleToFile();
        break;
      case _ScheduleManagerActionType.shareFile:
        await _shareActiveScheduleFile();
        break;
      case _ScheduleManagerActionType.syncMine:
        await _handlePrimaryAction();
        break;
      case _ScheduleManagerActionType.switchSchedule:
        final schedule = action.schedule;
        if (schedule != null) {
          await _switchToSchedule(schedule);
        }
        break;
      case _ScheduleManagerActionType.renameSchedule:
        final schedule = action.schedule;
        if (schedule != null) {
          await _renameSchedule(schedule);
        }
        break;
      case _ScheduleManagerActionType.deleteSchedule:
        final schedule = action.schedule;
        if (schedule != null) {
          await _confirmDeleteSchedule(schedule);
        }
        break;
    }
  }

  Widget _buildScheduleManagerBackground(
    BuildContext context, {
    required Widget child,
  }) {
    if (!_useLiteAndroidEffects) {
      return AppGlassBackground(
        style: AppGlassBackgroundStyle.soft,
        child: child,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:
              isDark
                  ? const [
                    Color(0xFF121A26),
                    Color(0xFF0E1520),
                    Color(0xFF0B121B),
                  ]
                  : [
                    colorScheme.surfaceContainerHighest,
                    colorScheme.surface,
                    colorScheme.surfaceContainerLow,
                  ],
        ),
      ),
      child: child,
    );
  }

  Widget _buildScheduleManagerPrimaryActionButton(BuildContext sheetContext) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed:
            () => Navigator.of(
              sheetContext,
            ).pop(const _ScheduleManagerAction.syncMine()),
        icon: Icon(
          _hasLinkedCampusAccount
              ? Icons.cloud_download_rounded
              : Icons.login_rounded,
        ),
        label: Text(_hasLinkedCampusAccount ? '从教务系统抓取课表' : '登录后从教务系统抓取课表'),
      ),
    );
  }

  Widget _buildScheduleManagerBody(
    BuildContext context, {
    required Future<bool> contentReadyFuture,
  }) {
    if (!_useLiteAndroidEffects) {
      return _buildScheduleManagerSections(context);
    }

    return FutureBuilder<bool>(
      future: contentReadyFuture,
      builder: (context, snapshot) {
        final isReady = snapshot.data ?? false;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offsetAnimation, child: child),
            );
          },
          child:
              isReady
                  ? KeyedSubtree(
                    key: const ValueKey('schedule-manager-content'),
                    child: _buildScheduleManagerSections(context),
                  )
                  : KeyedSubtree(
                    key: const ValueKey('schedule-manager-placeholder'),
                    child: _buildScheduleManagerPlaceholder(context),
                  ),
        );
      },
    );
  }

  Widget _buildScheduleManagerSections(BuildContext sheetContext) {
    final theme = Theme.of(sheetContext);
    final colorScheme = theme.colorScheme;
    final useLitePanels = _useLiteAndroidEffects;

    return RepaintBoundary(
      child: ListView(
        cacheExtent: 320,
        children: [
          _buildScheduleManagerSection(
            sheetContext,
            title: '导入到课表库',
            description: '把朋友分享的课表或你之前导出的课表保存下来，不登录也能用。',
            icon: Icons.move_to_inbox_rounded,
            accent: colorScheme.secondary,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.14 : 0.78,
                ),
                colorScheme.secondary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.28 : 0.20,
                ),
                colorScheme.tertiary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.18 : 0.16,
                ),
              ],
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed:
                      () => Navigator.of(
                        sheetContext,
                      ).pop(const _ScheduleManagerAction.scanImport()),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('扫码导入'),
                ),
                FilledButton.icon(
                  onPressed:
                      () => Navigator.of(
                        sheetContext,
                      ).pop(const _ScheduleManagerAction.clipboardImport()),
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text('从剪贴板导入'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      () => Navigator.of(
                        sheetContext,
                      ).pop(const _ScheduleManagerAction.fileImport()),
                  icon: const Icon(Icons.file_open_rounded),
                  label: const Text('导入文件'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      () => Navigator.of(
                        sheetContext,
                      ).pop(const _ScheduleManagerAction.manualImport()),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('手动粘贴'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildScheduleManagerSection(
            sheetContext,
            title: '导出与分享当前课表',
            description:
                _activeSchedule == null
                    ? '当前还没有可导出的课表。'
                    : '把当前正在使用的课表复制、导出或分享给别人。',
            icon: Icons.ios_share_rounded,
            accent: colorScheme.primary,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.13 : 0.78,
                ),
                colorScheme.primary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.30 : 0.22,
                ),
                colorScheme.tertiary.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.16 : 0.14,
                ),
              ],
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _activeSchedule == null
                          ? null
                          : () => Navigator.of(
                            sheetContext,
                          ).pop(const _ScheduleManagerAction.copyShareCode()),
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('复制分享码'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _activeSchedule == null
                          ? null
                          : () => Navigator.of(
                            sheetContext,
                          ).pop(const _ScheduleManagerAction.showQrCode()),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('显示二维码'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _activeSchedule == null
                          ? null
                          : () => Navigator.of(
                            sheetContext,
                          ).pop(const _ScheduleManagerAction.exportFile()),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('导出文件'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _activeSchedule == null
                          ? null
                          : () => Navigator.of(
                            sheetContext,
                          ).pop(const _ScheduleManagerAction.shareFile()),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('分享文件'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildScheduleManagerSavedSection(
            sheetContext,
            useLitePanels: useLitePanels,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleManagerSavedSection(
    BuildContext sheetContext, {
    required bool useLitePanels,
  }) {
    final theme = Theme.of(sheetContext);
    final colorScheme = theme.colorScheme;

    return _buildScheduleManagerSection(
      sheetContext,
      title: '已保存课表',
      description:
          _savedSchedules.isEmpty
              ? '还没有保存的课表。你可以登录同步自己的课表，或者导入朋友分享的课表。'
              : '点击课表可切换当前显示，右上角可重命名或删除。',
      icon: Icons.bookmarks_rounded,
      accent: colorScheme.tertiary,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.12 : 0.72,
          ),
          colorScheme.tertiary.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.26 : 0.18,
          ),
          colorScheme.surface.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.10 : 0.36,
          ),
        ],
      ),
      child:
          _savedSchedules.isEmpty
              ? null
              : Column(
                children:
                    _savedSchedules.asMap().entries.map((entry) {
                      final schedule = entry.value;
                      final isActive = schedule.id == _activeSchedule?.id;
                      final badges = _scheduleBadges(
                        schedule,
                        isActive: isActive,
                      );
                      final tileAccent =
                          isActive ? colorScheme.primary : colorScheme.tertiary;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom:
                              entry.key == _savedSchedules.length - 1 ? 0 : 8,
                        ),
                        child: GlassPanel(
                          style: GlassPanelStyle.list,
                          blur: useLitePanels ? 0 : 18,
                          useBackdropFilter: !useLitePanels,
                          borderRadius: BorderRadius.circular(18),
                          padding: EdgeInsets.zero,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(
                                alpha:
                                    theme.brightness == Brightness.dark
                                        ? 0.08
                                        : 0.64,
                              ),
                              tileAccent.withValues(
                                alpha:
                                    theme.brightness == Brightness.dark
                                        ? 0.18
                                        : 0.12,
                              ),
                              colorScheme.surface.withValues(
                                alpha:
                                    theme.brightness == Brightness.dark
                                        ? 0.12
                                        : 0.28,
                              ),
                            ],
                          ),
                          borderColor: tileAccent.withValues(
                            alpha:
                                theme.brightness == Brightness.dark
                                    ? 0.22
                                    : 0.20,
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    schedule.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (badges.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children:
                                        badges
                                            .map(
                                              (badge) =>
                                                  _ScheduleBadge(label: badge),
                                            )
                                            .toList(),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              _buildScheduleListSubtitle(schedule),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            leading: Icon(
                              isActive
                                  ? Icons.check_circle_rounded
                                  : Icons.calendar_month_rounded,
                              color: tileAccent,
                            ),
                            trailing: PopupMenuButton<String>(
                              tooltip: '课表操作',
                              onSelected: (value) {
                                switch (value) {
                                  case 'rename':
                                    Navigator.of(sheetContext).pop(
                                      _ScheduleManagerAction.rename(schedule),
                                    );
                                    break;
                                  case 'delete':
                                    Navigator.of(sheetContext).pop(
                                      _ScheduleManagerAction.delete(schedule),
                                    );
                                    break;
                                }
                              },
                              itemBuilder:
                                  (context) => const [
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Text('重命名'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('删除'),
                                    ),
                                  ],
                            ),
                            onTap:
                                () => Navigator.of(sheetContext).pop(
                                  _ScheduleManagerAction.switchSchedule(
                                    schedule,
                                  ),
                                ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
    );
  }

  Widget _buildScheduleManagerPlaceholder(BuildContext context) {
    final placeholderCount = math.max(2, math.min(_savedSchedules.length, 3));

    return IgnorePointer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildScheduleManagerPlaceholderCard(
            context,
            height: 162,
            lineWidths: const [0.36, 0.72, 0.58],
          ),
          const SizedBox(height: 14),
          _buildScheduleManagerPlaceholderCard(
            context,
            height: 148,
            lineWidths: const [0.40, 0.70, 0.62],
          ),
          const SizedBox(height: 14),
          _buildScheduleManagerPlaceholderCard(
            context,
            height: 112 + (placeholderCount * 62),
            lineWidths: const [0.30, 0.64],
            trailingTiles: placeholderCount,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleManagerPlaceholderCard(
    BuildContext context, {
    required double height,
    required List<double> lineWidths,
    int trailingTiles = 0,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor =
        isDark
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.white.withValues(alpha: 0.82);
    final strokeColor = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.20 : 0.42,
    );
    final shimmerColor = colorScheme.onSurface.withValues(
      alpha: isDark ? 0.08 : 0.07,
    );

    Widget placeholderLine(double widthFactor, {double height = 12}) {
      return FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: strokeColor),
      ),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        placeholderLine(lineWidths.first, height: 14),
                        const SizedBox(height: 10),
                        placeholderLine(
                          lineWidths.length > 1 ? lineWidths[1] : 0.72,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...lineWidths
                  .skip(2)
                  .map(
                    (widthFactor) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: placeholderLine(widthFactor),
                    ),
                  ),
              if (trailingTiles > 0) ...[
                const Spacer(),
                ...List.generate(trailingTiles, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == trailingTiles - 1 ? 0 : 8,
                    ),
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(
                          alpha: isDark ? 0.16 : 0.54,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleManagerSection(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color accent,
    required Gradient gradient,
    Widget? child,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final useLitePanels = _useLiteAndroidEffects;

    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent.withValues(alpha: isDark ? 0.42 : 0.96),
            foregroundColor: Colors.white,
            disabledBackgroundColor: accent.withValues(
              alpha: isDark ? 0.14 : 0.18,
            ),
            disabledForegroundColor: colorScheme.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            backgroundColor: accent.withValues(alpha: isDark ? 0.10 : 0.08),
            disabledForegroundColor: colorScheme.onSurfaceVariant,
            side: BorderSide(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      child: GlassPanel(
        style: GlassPanelStyle.card,
        blur: useLitePanels ? 0 : 22,
        useBackdropFilter: !useLitePanels,
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.all(18),
        gradient: gradient,
        borderColor: accent.withValues(alpha: isDark ? 0.18 : 0.16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GlassIconBadge(icon: icon, tint: accent, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (child != null) ...[const SizedBox(height: 14), child],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent =
        _hasLinkedCampusAccount ? colorScheme.primary : colorScheme.secondary;
    final title = _hasLinkedCampusAccount ? '课表暂未同步' : '登录后抓取或导入课表';
    final description =
        _hasLinkedCampusAccount
            ? '最推荐的方式是直接从教务系统抓取课表；也可以导入朋友分享的课表。'
            : '登录校园账号后可直接从教务系统抓取课表；不登录也能导入朋友分享的课表。';
    final primaryLabel = _hasLinkedCampusAccount ? '从教务系统抓取课表' : '登录后抓取课表';
    const secondaryLabel = '从剪贴板导入';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: GlassPanel(
            style: GlassPanelStyle.hero,
            blur: 26,
            borderRadius: BorderRadius.circular(34),
            padding: const EdgeInsets.all(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.14 : 0.82),
                colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.15),
                colorScheme.secondary.withValues(alpha: isDark ? 0.16 : 0.12),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GlassIconBadge(
                  icon:
                      _hasLinkedCampusAccount
                          ? Icons.calendar_month_rounded
                          : Icons.lock_outline_rounded,
                  tint: accent,
                  size: 62,
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    letterSpacing: -0.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _isPrimaryActionLoading ? null : _handlePrimaryAction,
                    icon:
                        _isPrimaryActionLoading
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Icon(
                              _hasLinkedCampusAccount
                                  ? Icons.cloud_download_rounded
                                  : Icons.login_rounded,
                            ),
                    label: Text(primaryLabel),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _importScheduleFromClipboard,
                    icon: Icon(
                      _hasLinkedCampusAccount
                          ? Icons.content_paste_rounded
                          : Icons.content_paste_rounded,
                    ),
                    label: Text(secondaryLabel),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _scanScheduleQrCode,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('扫码导入'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importScheduleFromFile,
                      icon: const Icon(Icons.file_open_rounded),
                      label: const Text('导入文件'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _importScheduleFromClipboard,
                      icon: const Icon(Icons.content_paste_rounded),
                      label: const Text('剪贴板导入'),
                    ),
                    if (_savedSchedules.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _showScheduleManager,
                        icon: const Icon(Icons.layers_outlined),
                        label: const Text('打开课表库'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
    return _buildScheduleStatusLabel();
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

  Widget _buildWeekPage({
    required BuildContext context,
    required List<DateTime> weekDays,
    required _WeekGridMetrics metrics,
  }) {
    final placedCourses = _buildPlacedCourses(weekDays, metrics);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return KeyedSubtree(
      key: ValueKey<String>(_dateKey(weekDays.first)),
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
                      Colors.white.withValues(alpha: isDark ? 0.10 : 0.52),
                      colorScheme.surface.withValues(
                        alpha: isDark ? 0.08 : 0.30,
                      ),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.72),
                  ),
                ),
                child: SizedBox(
                  width: metrics.totalWidth,
                  height: metrics.gridHeight,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      ...weekDays.asMap().entries.map((entry) {
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
                                      ? colorScheme.primary.withValues(
                                        alpha: isDark ? 0.08 : 0.06,
                                      )
                                      : Colors.transparent,
                            ),
                          ),
                        );
                      }),
                      ...List.generate(_sectionCount, (index) {
                        final top = metrics.topForSection(index + 1);
                        return Positioned(
                          left: metrics.timeColumnWidth + _columnGap,
                          right: 0,
                          top: top,
                          height: metrics.slotHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: isDark ? 0.24 : 0.34,
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
                              color: colorScheme.outlineVariant.withValues(
                                alpha: isDark ? 0.18 : 0.22,
                              ),
                            ),
                          ),
                        );
                      }),
                      ..._sectionTimes.map((section) {
                        final top = metrics.topForSection(section.index);
                        return Positioned(
                          left: 0,
                          top: top,
                          width: metrics.timeColumnWidth,
                          height: metrics.slotHeight,
                          child: _TimeAxisLabel(section: section),
                        );
                      }),
                      if (placedCourses.isEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: Text(
                                '本周暂无课程',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.82),
                                  fontWeight: FontWeight.w600,
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
                            onTap: () => _showCourseDetails(placement),
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
    final weekDays = _buildWeekDaysForWeek(_currentWeek);
    final showWeekStr = '第$_currentWeek周';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        style: AppGlassBackgroundStyle.soft,
        bottomHighlightOpacity: 0,
        lightBottomColor: const Color(0xFFEAF0FA),
        darkBottomColor: const Color(0xFF101826),
        child: SafeArea(
          bottom: false,
          child: EnhancedFutureBuilder(
            future: _initialLoadFuture,
            rememberFutureResult: true,
            whenDone: (_) {
              if (_courseData.isEmpty) {
                return _buildEmptyState(context);
              }

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
                      onManageSchedules: _showScheduleManager,
                      showExperimentCourses: _showExperimentCourses,
                      onShowExperimentCoursesChanged: _setShowExperimentCourses,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final metrics = _buildGridMetrics(constraints);
                          return Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: metrics.totalWidth,
                              child: PageView.builder(
                                key: const ValueKey('course-table-week-pager'),
                                controller: _weekPageController,
                                itemCount: _allWeek,
                                physics:
                                    _allWeek <= 1
                                        ? const NeverScrollableScrollPhysics()
                                        : null,
                                onPageChanged: _handleWeekPageChanged,
                                itemBuilder: (context, index) {
                                  final weekNumber = index + 1;
                                  return _buildWeekPage(
                                    context: context,
                                    weekDays: _buildWeekDaysForWeek(weekNumber),
                                    metrics: metrics,
                                  );
                                },
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

    _showAdaptiveBottomSheet<void>(
      expand: false,
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
        final showLocation = course.location.trim().isNotEmpty;
        final showTeacher = course.teacherName.trim().isNotEmpty;
        final detailLineCount = (showLocation ? 1 : 0) + (showTeacher ? 1 : 0);
        final titleBaseStyle =
            Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.foreground.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
              height: 1.18,
              letterSpacing: -0.12,
            ) ??
            TextStyle(
              color: palette.foreground.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
              height: 1.18,
              letterSpacing: -0.12,
            );
        final horizontalPadding = compact ? 3.5 : 5.0;
        final topPadding = compact ? 3.5 : 5.0;
        final bottomPadding = compact ? 2.5 : 4.0;
        final detailSpacing =
            detailLineCount == 0 ? 0.0 : (compact ? 1.0 : 2.0);
        final contentHeight = math.max(
          0.0,
          height - topPadding - bottomPadding,
        );
        final minTitleHeight = compact ? 9.0 : 11.5;
        final preferredDetailLineHeight = compact ? 9.4 : 11.8;
        final detailHeightBudget = math.max(
          0.0,
          contentHeight - minTitleHeight - detailSpacing * detailLineCount,
        );
        final detailLineHeight =
            detailLineCount == 0
                ? 0.0
                : math.min(
                  preferredDetailLineHeight,
                  detailHeightBudget / detailLineCount,
                );
        final titleReferenceLineHeight = compact ? 10.6 : 12.4;
        final titleMinFontSize = compact ? 7.8 : 8.8;
        final titleMaxFontSize = math.min(
          compact ? 15.0 : 16.8,
          math.max(compact ? 10.6 : 11.8, width * (compact ? 0.34 : 0.29)),
        );
        final detailFontSize = math.max(
          compact ? 8.0 : 9.0,
          detailLineHeight * (compact ? 0.92 : 0.94),
        );
        final locationStyle =
            Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.foreground.withValues(alpha: 0.88),
              fontSize: detailFontSize,
              fontWeight: FontWeight.w700,
              height: 1,
            ) ??
            TextStyle(
              color: palette.foreground.withValues(alpha: 0.88),
              fontSize: detailFontSize,
              fontWeight: FontWeight.w700,
              height: 1,
            );
        final teacherStyle =
            Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.foreground.withValues(alpha: 0.82),
              fontSize: detailFontSize,
              fontWeight: FontWeight.w600,
              height: 1,
            ) ??
            TextStyle(
              color: palette.foreground.withValues(alpha: 0.82),
              fontSize: detailFontSize,
              fontWeight: FontWeight.w600,
              height: 1,
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
                          child: LayoutBuilder(
                            builder: (context, titleConstraints) {
                              final titleHeight = titleConstraints.maxHeight;
                              final titleMaxLines = math.max(
                                1,
                                (titleHeight / titleReferenceLineHeight)
                                    .floor(),
                              );
                              return _AdaptiveCourseTitleText(
                                text: course.name,
                                style: titleBaseStyle,
                                maxLines: titleMaxLines,
                                maxHeight: titleHeight,
                                minFontSize: titleMinFontSize,
                                maxFontSize: titleMaxFontSize,
                              );
                            },
                          ),
                        ),
                        if (showLocation) ...[
                          SizedBox(height: detailSpacing),
                          _SingleLineScaleText(
                            text: course.location,
                            style: locationStyle,
                            height: detailLineHeight,
                          ),
                        ],
                        if (showTeacher) ...[
                          SizedBox(height: detailSpacing),
                          _SingleLineScaleText(
                            text: course.teacherName,
                            style: teacherStyle,
                            height: detailLineHeight,
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

class _AdaptiveCourseTitleText extends StatelessWidget {
  const _AdaptiveCourseTitleText({
    required this.text,
    required this.style,
    required this.maxLines,
    required this.maxHeight,
    required this.minFontSize,
    required this.maxFontSize,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final double maxHeight;
  final double minFontSize;
  final double maxFontSize;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty || maxHeight <= 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0) {
          return const SizedBox.shrink();
        }

        final textDirection = Directionality.of(context);
        final maxReadableFontSize = _maxFontSizeForSample(
          sample: '课程名',
          style: style,
          maxWidth: maxWidth,
          minFontSize: minFontSize,
          maxFontSize: maxFontSize,
          textDirection: textDirection,
        );
        double low = minFontSize;
        double high = maxReadableFontSize;
        double best = minFontSize;

        for (var index = 0; index < 9; index++) {
          final current = (low + high) / 2;
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: style.copyWith(fontSize: current),
            ),
            textDirection: textDirection,
            maxLines: maxLines,
            ellipsis: '…',
          )..layout(maxWidth: maxWidth);

          if (painter.height <= maxHeight + 0.01) {
            best = current;
            low = current;
          } else {
            high = current;
          }
        }

        return ClipRect(
          child: SizedBox(
            width: double.infinity,
            height: maxHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                text,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(fontSize: best),
              ),
            ),
          ),
        );
      },
    );
  }

  double _maxFontSizeForSample({
    required String sample,
    required TextStyle style,
    required double maxWidth,
    required double minFontSize,
    required double maxFontSize,
    required ui.TextDirection textDirection,
  }) {
    double low = minFontSize;
    double high = maxFontSize;
    double best = minFontSize;

    for (var index = 0; index < 9; index++) {
      final current = (low + high) / 2;
      final painter = TextPainter(
        text: TextSpan(text: sample, style: style.copyWith(fontSize: current)),
        textDirection: textDirection,
        maxLines: 1,
      )..layout(maxWidth: double.infinity);

      if (painter.width <= maxWidth + 0.01) {
        best = current;
        low = current;
      } else {
        high = current;
      }
    }

    return best;
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

    final resolvedStyle = style;
    if (resolvedStyle == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }

        final textDirection = Directionality.of(context);
        final baseFontSize = resolvedStyle.fontSize ?? 12;
        final minFontSize = math.max(1.0, baseFontSize * 0.55);
        final maxFontSize = baseFontSize;
        double low = minFontSize;
        double high = maxFontSize;
        double best = minFontSize;

        for (var index = 0; index < 9; index++) {
          final current = (low + high) / 2;
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: resolvedStyle.copyWith(fontSize: current),
            ),
            textDirection: textDirection,
            maxLines: 1,
          )..layout(maxWidth: double.infinity);

          if (painter.width <= maxWidth + 0.01 &&
              painter.height <= height + 0.01) {
            best = current;
            low = current;
          } else {
            high = current;
          }
        }

        return SizedBox(
          width: double.infinity,
          height: height,
          child: Align(
            alignment: alignment,
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: resolvedStyle.copyWith(fontSize: best),
            ),
          ),
        );
      },
    );
  }
}

class _ScheduleBadge extends StatelessWidget {
  const _ScheduleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _ScheduleManagerActionType {
  scanImport,
  clipboardImport,
  fileImport,
  manualImport,
  copyShareCode,
  showQrCode,
  exportFile,
  shareFile,
  syncMine,
  switchSchedule,
  renameSchedule,
  deleteSchedule,
}

class _ScheduleManagerAction {
  const _ScheduleManagerAction._(this.type, {this.schedule});

  const _ScheduleManagerAction.scanImport()
    : this._(_ScheduleManagerActionType.scanImport);

  const _ScheduleManagerAction.clipboardImport()
    : this._(_ScheduleManagerActionType.clipboardImport);

  const _ScheduleManagerAction.fileImport()
    : this._(_ScheduleManagerActionType.fileImport);

  const _ScheduleManagerAction.manualImport()
    : this._(_ScheduleManagerActionType.manualImport);

  const _ScheduleManagerAction.copyShareCode()
    : this._(_ScheduleManagerActionType.copyShareCode);

  const _ScheduleManagerAction.showQrCode()
    : this._(_ScheduleManagerActionType.showQrCode);

  const _ScheduleManagerAction.exportFile()
    : this._(_ScheduleManagerActionType.exportFile);

  const _ScheduleManagerAction.shareFile()
    : this._(_ScheduleManagerActionType.shareFile);

  const _ScheduleManagerAction.syncMine()
    : this._(_ScheduleManagerActionType.syncMine);

  factory _ScheduleManagerAction.switchSchedule(SavedCourseSchedule schedule) =>
      _ScheduleManagerAction._(
        _ScheduleManagerActionType.switchSchedule,
        schedule: schedule,
      );

  factory _ScheduleManagerAction.rename(SavedCourseSchedule schedule) =>
      _ScheduleManagerAction._(
        _ScheduleManagerActionType.renameSchedule,
        schedule: schedule,
      );

  factory _ScheduleManagerAction.delete(SavedCourseSchedule schedule) =>
      _ScheduleManagerAction._(
        _ScheduleManagerActionType.deleteSchedule,
        schedule: schedule,
      );

  final _ScheduleManagerActionType type;
  final SavedCourseSchedule? schedule;
}

class _CourseShareQrScannerPage extends StatefulWidget {
  const _CourseShareQrScannerPage();

  @override
  State<_CourseShareQrScannerPage> createState() =>
      _CourseShareQrScannerPageState();
}

class _CourseShareQrScannerPageState extends State<_CourseShareQrScannerPage> {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'course-share-qr');
  QRViewController? _controller;
  StreamSubscription<Barcode>? _scanSubscription;
  bool _isFlashOn = false;
  bool _isScanning = true;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    _scanSubscription = controller.scannedDataStream.listen((scanData) {
      final code = scanData.code;
      if (code == null || code.isEmpty || !_isScanning || !mounted) {
        return;
      }

      setState(() {
        _isScanning = false;
      });
      _scanSubscription?.cancel();
      controller.pauseCamera();
      Navigator.of(context).pop(code);
    });
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.toggleFlash();
    final current = await controller.getFlashStatus() ?? false;
    if (!mounted) {
      return;
    }
    setState(() {
      _isFlashOn = current;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cutOutSize = MediaQuery.sizeOf(context).width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          QRView(
            key: _qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: colorScheme.primary,
              borderRadius: 18,
              borderLength: 30,
              borderWidth: 4,
              cutOutSize: cutOutSize,
              overlayColor: const Color.fromRGBO(0, 0, 0, 0.7),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const Text(
                    '扫描课表二维码',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.84),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '将朋友发来的工大盒子课表二维码放入框内，即可自动识别并导入。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _toggleFlash,
                      icon: Icon(
                        _isFlashOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                      ),
                      label: Text(_isFlashOn ? '关闭闪光灯' : '打开闪光灯'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
