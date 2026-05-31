import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/app_auth_storage.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/course_sync_service.dart';
import '../../core/ui/app_bottom_sheet.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_page_route.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/apple_glass.dart';
import '../../core/ui/color_scheme_ext.dart';
import '../../login/unified_login_page.dart';
import '../../utils/course/get_course.dart';
import '../../utils/course/coursemain.dart';
import '../../utils/token.dart';
import '../../widget_refresh_service.dart';
import 'widgets/course_table_widgets.dart';

typedef CourseTableBottomSheetPresenter =
    Future<T?> Function<T>({
      required BuildContext context,
      required WidgetBuilder builder,
      bool expand,
      Color? backgroundColor,
      Color? barrierColor,
      Color? transitionBackgroundColor,
    });
typedef CourseTableClipboardReader = Future<String?> Function();
typedef CourseTableClipboardWriter = Future<void> Function(String text);
typedef CourseTableArchiveLoader = Future<CourseScheduleArchive> Function();
typedef CourseTableShareCodeImporter =
    Future<SavedCourseSchedule> Function(String rawCode);
typedef CourseTableFileContentPicker = Future<String?> Function();
typedef CourseTableFileContentImporter =
    Future<SavedCourseSchedule> Function(String rawContent);
typedef CourseTableQrCodeScanner =
    Future<String?> Function(BuildContext context);
typedef CourseTableCampusLoginOpener =
    Future<void> Function(BuildContext context);
typedef CourseTableExperimentStudentsLoader =
    Future<Map<String, dynamic>> Function(String pcid);
typedef CourseTableCourseDeleter =
    Future<bool> Function({
      required String dateKey,
      required Course targetCourse,
      required CourseDeleteScope scope,
    });
typedef CourseTableScheduleDeleter = Future<bool> Function(String scheduleId);
typedef CourseTableScheduleSwitcher = Future<void> Function(String scheduleId);
typedef CourseTableScheduleRenamer =
    Future<void> Function(String scheduleId, String newName);
typedef CourseTableScheduleFileSaver =
    Future<String?> Function({
      required String fileName,
      required Uint8List bytes,
    });
typedef CourseTableScheduleFileSharer =
    Future<void> Function({
      required SavedCourseSchedule schedule,
      required Rect sharePositionOrigin,
    });

class CourseTableView extends StatefulWidget {
  const CourseTableView({
    super.key,
    this.transitionLiteModeListenable,
    this.debugScheduleOverride,
    this.debugForceTransitionLiteMode,
    this.showBottomSheet,
    this.readClipboardText,
    this.writeClipboardText,
    this.loadScheduleArchive,
    this.importShareCode,
    this.pickImportFileContent,
    this.importFileContent,
    this.scanQrCode,
    this.openCampusLogin,
    this.loadExperimentStudents,
    this.deleteCourse,
    this.deleteSchedule,
    this.switchSchedule,
    this.renameSchedule,
    this.saveScheduleFile,
    this.shareScheduleFile,
  });

  final ValueListenable<bool>? transitionLiteModeListenable;
  final CourseTableBottomSheetPresenter? showBottomSheet;
  final CourseTableClipboardReader? readClipboardText;
  final CourseTableClipboardWriter? writeClipboardText;
  final CourseTableArchiveLoader? loadScheduleArchive;
  final CourseTableShareCodeImporter? importShareCode;
  final CourseTableFileContentPicker? pickImportFileContent;
  final CourseTableFileContentImporter? importFileContent;
  final CourseTableQrCodeScanner? scanQrCode;
  final CourseTableCampusLoginOpener? openCampusLogin;
  final CourseTableExperimentStudentsLoader? loadExperimentStudents;
  final CourseTableCourseDeleter? deleteCourse;
  final CourseTableScheduleDeleter? deleteSchedule;
  final CourseTableScheduleSwitcher? switchSchedule;
  final CourseTableScheduleRenamer? renameSchedule;
  final CourseTableScheduleFileSaver? saveScheduleFile;
  final CourseTableScheduleFileSharer? shareScheduleFile;

  @visibleForTesting
  final SavedCourseSchedule? debugScheduleOverride;

  @visibleForTesting
  final bool? debugForceTransitionLiteMode;

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

String _formatCourseDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatCourseMonthDay(DateTime date) => '${date.month}/${date.day}';

bool _isCourseDateKey(String value) {
  return value.length == 10 &&
      _isCourseAsciiDigitAt(value, 0) &&
      _isCourseAsciiDigitAt(value, 1) &&
      _isCourseAsciiDigitAt(value, 2) &&
      _isCourseAsciiDigitAt(value, 3) &&
      value.codeUnitAt(4) == 0x2D &&
      _isCourseAsciiDigitAt(value, 5) &&
      _isCourseAsciiDigitAt(value, 6) &&
      value.codeUnitAt(7) == 0x2D &&
      _isCourseAsciiDigitAt(value, 8) &&
      _isCourseAsciiDigitAt(value, 9);
}

bool _isCourseAsciiDigitAt(String value, int index) {
  final codeUnit = value.codeUnitAt(index);
  return codeUnit >= 0x30 && codeUnit <= 0x39;
}

bool _isCourseFileNameWhitespace(int codeUnit) {
  return codeUnit <= 0x20 ||
      codeUnit == 0x85 ||
      codeUnit == 0xA0 ||
      codeUnit == 0x1680 ||
      (codeUnit >= 0x2000 && codeUnit <= 0x200A) ||
      codeUnit == 0x2028 ||
      codeUnit == 0x2029 ||
      codeUnit == 0x202F ||
      codeUnit == 0x205F ||
      codeUnit == 0x3000;
}

bool _isUnsafeCourseFileNameCodeUnit(int codeUnit) {
  return codeUnit == 0x22 ||
      codeUnit == 0x2A ||
      codeUnit == 0x2F ||
      codeUnit == 0x3A ||
      codeUnit == 0x3C ||
      codeUnit == 0x3E ||
      codeUnit == 0x3F ||
      codeUnit == 0x5C ||
      codeUnit == 0x7C;
}

class _PendingWeekPageMove {
  const _PendingWeekPageMove({
    required this.targetPage,
    required this.animated,
  });

  final int targetPage;
  final bool animated;
}

class _CourseTableViewState extends State<CourseTableView> {
  static const int _defaultMaxWeek = 20;
  static const int _sectionCount = 10;
  static const int _glassRestoreDelayFrames = 2;
  static const String _showExperimentCoursesKey = 'showExperimentCourses';
  static const double _timeColumnWidth = 30;
  static const double _columnGap = 2;
  static const double _rowGap = 3;
  static const double _headerHeight = 54;
  static const double _headerGap = 8;
  static const double _cardInnerGap = 2;
  late final PageController _weekPageController;
  late final ValueNotifier<int> _displayedWeekNotifier;
  late final ValueNotifier<bool> _transitionLiteModeNotifier;
  late final ValueNotifier<bool> _isPrimaryActionLoadingNotifier;
  late final ValueNotifier<bool> _showExperimentCoursesNotifier;
  late final ValueNotifier<DateTime> _todayDateNotifier;
  bool _hasLinkedCampusAccount = false;
  bool _isCourseDetailSheetOpen = false;
  bool _isScheduleManagerSheetOpen = false;
  bool _isImportingScheduleFromClipboard = false;
  bool _isImportingScheduleFromFile = false;
  bool _isScanningScheduleQrCode = false;
  bool _isCopyingScheduleShareCode = false;
  bool _isCurrentTermSchedule = true;
  bool _isInitialLoadComplete = false;
  bool _weekPlacementWarmupPending = false;
  bool _weekPageMovePending = false;
  _PendingWeekPageMove? _pendingWeekPageMove;
  int _transitionLiteModeRequestId = 0;
  int _handledCourseSyncSuccessEventId = 0;
  int _scheduleReloadGeneration = 0;
  int _weekPlacementWarmupGeneration = 0;
  final Map<String, List<_PlacedCourse>> _weekPlacementsCache =
      <String, List<_PlacedCourse>>{};
  final Map<String, List<_CourseCardPaintData>> _weekCourseCardPaintCache =
      <String, List<_CourseCardPaintData>>{};
  final Map<int, List<DateTime>> _weekDaysCache = <int, List<DateTime>>{};

  // DateTime _currentDate = DateTime.now();
  DateTime _currentDate = getMondayOfCurrentWeek(refreshWidget: false);
  DateTime _todayDate = DateUtils.dateOnly(DateTime.now());

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
    _displayedWeekNotifier = ValueNotifier<int>(_currentWeek);
    _transitionLiteModeNotifier = ValueNotifier<bool>(
      _resolveTransitionLiteModeValue(),
    );
    _isPrimaryActionLoadingNotifier = ValueNotifier<bool>(false);
    _showExperimentCoursesNotifier = ValueNotifier<bool>(
      _showExperimentCourses,
    );
    _todayDateNotifier = ValueNotifier<DateTime>(_todayDate);
    CourseSyncService.instance.stateListenable.addListener(
      _handleCourseSyncStateChanged,
    );
    widget.transitionLiteModeListenable?.addListener(
      _handleTransitionLiteModeChanged,
    );
    _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant CourseTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionLiteModeListenable !=
        widget.transitionLiteModeListenable) {
      oldWidget.transitionLiteModeListenable?.removeListener(
        _handleTransitionLiteModeChanged,
      );
      widget.transitionLiteModeListenable?.addListener(
        _handleTransitionLiteModeChanged,
      );
    }
    final nextTransitionLiteMode = _resolveTransitionLiteModeValue();
    if (mounted) {
      _applyTransitionLiteMode(nextTransitionLiteMode);
    }
    if (oldWidget.debugScheduleOverride != widget.debugScheduleOverride) {
      unawaited(_reloadScheduleState());
    }
  }

  @override
  void dispose() {
    widget.transitionLiteModeListenable?.removeListener(
      _handleTransitionLiteModeChanged,
    );
    CourseSyncService.instance.stateListenable.removeListener(
      _handleCourseSyncStateChanged,
    );
    _showExperimentCoursesNotifier.dispose();
    _todayDateNotifier.dispose();
    _isPrimaryActionLoadingNotifier.dispose();
    _transitionLiteModeNotifier.dispose();
    _displayedWeekNotifier.dispose();
    _weekPageController.dispose();
    super.dispose();
  }

  bool _resolveTransitionLiteModeValue() {
    return widget.debugForceTransitionLiteMode ??
        widget.transitionLiteModeListenable?.value ??
        false;
  }

  void _handleTransitionLiteModeChanged() {
    if (!mounted) {
      return;
    }
    _applyTransitionLiteMode(_resolveTransitionLiteModeValue());
  }

  void _handleCourseSyncStateChanged() {
    final snapshot = CourseSyncService.instance.state;
    if (snapshot.status != CourseSyncTaskStatus.success ||
        snapshot.eventId <= 0 ||
        snapshot.eventId == _handledCourseSyncSuccessEventId) {
      return;
    }
    _handledCourseSyncSuccessEventId = snapshot.eventId;
    unawaited(_reloadScheduleState());
  }

  void _applyTransitionLiteMode(bool nextValue) {
    if (nextValue) {
      _transitionLiteModeRequestId++;
      if (_transitionLiteModeNotifier.value) {
        return;
      }
      _transitionLiteModeNotifier.value = true;
      return;
    }

    if (!_transitionLiteModeNotifier.value) {
      _transitionLiteModeRequestId++;
      return;
    }

    final requestId = ++_transitionLiteModeRequestId;
    _scheduleLiteModeExit(
      requestId: requestId,
      framesRemaining: _glassRestoreDelayFrames,
    );
  }

  void _scheduleLiteModeExit({
    required int requestId,
    required int framesRemaining,
  }) {
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (!mounted || requestId != _transitionLiteModeRequestId) {
        return;
      }
      if (_resolveTransitionLiteModeValue()) {
        return;
      }
      if (framesRemaining > 1) {
        _scheduleLiteModeExit(
          requestId: requestId,
          framesRemaining: framesRemaining - 1,
        );
        return;
      }
      if (_transitionLiteModeNotifier.value) {
        _transitionLiteModeNotifier.value = false;
      }
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  // 综合计算周数的完整函数
  int calculateSchoolWeek(String? firstDayString, {DateTime? now}) {
    // 异常情况处理
    if (firstDayString == null) throw ArgumentError('firstDay 不能为空');
    if (!_isCourseDateKey(firstDayString)) {
      throw FormatException('日期格式应为 yyyy-MM-dd');
    }

    // 1. 字符串转DateTime
    final firstDay = DateTime.parse(firstDayString);

    // 2. 转换为当周周一
    final firstMonday = firstDay.subtract(Duration(days: firstDay.weekday - 1));

    // 3. 计算当前周数
    final currentDate = now ?? DateTime.now();
    final difference = currentDate.difference(firstMonday).inDays + 1;

    // 处理早于开学日的情况
    if (difference < 0) return 0;

    return (difference / 7).ceil();
  }

  int _resolveCurrentWeek(String? firstDay, {required DateTime now}) {
    if (firstDay == null || firstDay.isEmpty) {
      return 1;
    }

    try {
      return calculateSchoolWeek(firstDay, now: now);
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

  bool _isScheduleCurrentTerm(
    SavedCourseSchedule? schedule, {
    required DateTime now,
  }) {
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
    final termEnd = firstMonday.add(Duration(days: schedule.maxWeek * 7 - 1));
    return !now.isBefore(firstMonday) && !now.isAfter(termEnd);
  }

  int _resolveCurrentWeekForSchedule(
    SavedCourseSchedule? schedule, {
    required DateTime now,
    required bool isCurrentTermSchedule,
  }) {
    if (schedule == null) {
      return 1;
    }

    if (!isCurrentTermSchedule) {
      return 1;
    }

    final maxWeek = schedule.maxWeek > 0 ? schedule.maxWeek : _defaultMaxWeek;
    final computed = _resolveCurrentWeek(schedule.firstDay, now: now);
    return computed.clamp(1, maxWeek).toInt();
  }

  DateTime _buildInitialDateForSchedule(
    SavedCourseSchedule? schedule,
    int currentWeek,
    DateTime now,
  ) {
    if (schedule == null) {
      return _startOfMonday(now);
    }

    final firstDay = _tryParseDate(schedule.firstDay);
    if (firstDay == null) {
      return _startOfMonday(now);
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

  SavedCourseSchedule? _resolveActiveScheduleFromArchive(
    CourseScheduleArchive archive,
  ) {
    if (archive.schedules.isEmpty) {
      return null;
    }

    for (final schedule in archive.schedules) {
      if (schedule.id == archive.activeScheduleId) {
        return schedule;
      }
    }
    return archive.schedules.first;
  }

  int _nextScheduleReloadGeneration() {
    return ++_scheduleReloadGeneration;
  }

  bool _isLatestScheduleReloadGeneration(int generation) {
    return mounted && generation == _scheduleReloadGeneration;
  }

  Future<bool> _reloadScheduleState() async {
    final generation = _nextScheduleReloadGeneration();
    final overrideSchedule = widget.debugScheduleOverride;
    final prefsFuture = SharedPreferences.getInstance();
    final hasLinkedCampusAccountFuture =
        AppAuthStorage.instance.hasLinkedCampusAccount();
    final archiveFuture =
        overrideSchedule == null
            ? (widget.loadScheduleArchive ?? loadCourseScheduleArchive)()
            : null;

    final prefs = await prefsFuture;
    final showExperimentCourses =
        prefs.getBool(_showExperimentCoursesKey) ?? true;
    final hasLinkedCampusAccount = await hasLinkedCampusAccountFuture;
    final archive = overrideSchedule == null ? await archiveFuture! : null;
    final savedSchedules =
        overrideSchedule == null
            ? archive!.schedules
            : <SavedCourseSchedule>[overrideSchedule];
    final activeSchedule =
        overrideSchedule ?? _resolveActiveScheduleFromArchive(archive!);
    final courseData =
        activeSchedule?.courseData ?? const <String, List<Course>>{};
    final reloadNow = DateTime.now();
    final isCurrentTermSchedule = _isScheduleCurrentTerm(
      activeSchedule,
      now: reloadNow,
    );
    final allWeek =
        activeSchedule == null
            ? _defaultMaxWeek
            : (activeSchedule.maxWeek <= 0
                ? _defaultMaxWeek
                : activeSchedule.maxWeek);
    final currentWeek = _resolveCurrentWeekForSchedule(
      activeSchedule,
      now: reloadNow,
      isCurrentTermSchedule: isCurrentTermSchedule,
    );
    final currentDate = _buildInitialDateForSchedule(
      activeSchedule,
      currentWeek,
      reloadNow,
    );
    final todayDate = DateUtils.dateOnly(reloadNow);

    if (!_isLatestScheduleReloadGeneration(generation)) {
      return false;
    }

    if (_hasSameScheduleReloadState(
      savedSchedules: savedSchedules,
      activeSchedule: activeSchedule,
      allWeek: allWeek,
      currentRealWeek: currentWeek,
      showExperimentCourses: showExperimentCourses,
      hasLinkedCampusAccount: hasLinkedCampusAccount,
      isCurrentTermSchedule: isCurrentTermSchedule,
    )) {
      _applyTodayDateIfChanged(todayDate);
      return false;
    }

    _clearWeekPlacementCache();
    setState(() {
      _isInitialLoadComplete = true;
      _savedSchedules = savedSchedules;
      _activeSchedule = activeSchedule;
      _courseData = courseData;
      _allWeek = allWeek;
      _currentWeek = currentWeek;
      _currentRealWeek = currentWeek;
      _currentDate = currentDate;
      _todayDate = todayDate;
      _showExperimentCourses = showExperimentCourses;
      _hasLinkedCampusAccount = hasLinkedCampusAccount;
      _isCurrentTermSchedule = isCurrentTermSchedule;
    });
    _showExperimentCoursesNotifier.value = showExperimentCourses;
    _todayDateNotifier.value = todayDate;
    _displayedWeekNotifier.value = currentWeek;
    _syncWeekPageToCurrentWeek();
    return true;
  }

  bool _hasSameScheduleReloadState({
    required List<SavedCourseSchedule> savedSchedules,
    required SavedCourseSchedule? activeSchedule,
    required int allWeek,
    required int currentRealWeek,
    required bool showExperimentCourses,
    required bool hasLinkedCampusAccount,
    required bool isCurrentTermSchedule,
  }) {
    return _isInitialLoadComplete &&
        _hasSameScheduleList(_savedSchedules, savedSchedules) &&
        _activeSchedule?.id == activeSchedule?.id &&
        _allWeek == allWeek &&
        _currentRealWeek == currentRealWeek &&
        _showExperimentCourses == showExperimentCourses &&
        _hasLinkedCampusAccount == hasLinkedCampusAccount &&
        _isCurrentTermSchedule == isCurrentTermSchedule;
  }

  void _applyTodayDateIfChanged(DateTime todayDate) {
    if (!mounted || _isSameDay(_todayDate, todayDate)) {
      return;
    }

    _todayDate = todayDate;
    _todayDateNotifier.value = todayDate;
  }

  bool _hasSameScheduleList(
    List<SavedCourseSchedule> left,
    List<SavedCourseSchedule> right,
  ) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (!_hasSameSavedSchedule(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }

  bool _hasSameSavedSchedule(
    SavedCourseSchedule left,
    SavedCourseSchedule right,
  ) {
    return identical(left, right) ||
        (left.id == right.id &&
            left.name == right.name &&
            left.ownerName == right.ownerName &&
            left.ownerAccount == right.ownerAccount &&
            left.termLabel == right.termLabel &&
            left.semesterId == right.semesterId &&
            left.firstDay == right.firstDay &&
            left.maxWeek == right.maxWeek &&
            left.sourceType == right.sourceType &&
            left.isReadOnly == right.isReadOnly &&
            left.createdAt == right.createdAt &&
            left.updatedAt == right.updatedAt &&
            _hasSameCourseData(left.courseData, right.courseData));
  }

  bool _hasSameCourseData(
    Map<String, List<Course>> left,
    Map<String, List<Course>> right,
  ) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }

    for (final entry in left.entries) {
      final rightCourses = right[entry.key];
      if (rightCourses == null ||
          !_hasSameCourseList(entry.value, rightCourses)) {
        return false;
      }
    }
    return true;
  }

  bool _hasSameCourseList(List<Course> left, List<Course> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (!_hasSameCourse(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }

  bool _hasSameCourse(Course left, Course right) {
    return identical(left, right) ||
        (left.name == right.name &&
            left.teacherName == right.teacherName &&
            left.weekDuration == right.weekDuration &&
            left.location == right.location &&
            left.startSection == right.startSection &&
            left.duration == right.duration &&
            left.isExp == right.isExp &&
            left.pcid == right.pcid);
  }

  Future<void> _loadInitialData() async {
    await _reloadScheduleState();
  }

  @visibleForTesting
  Future<bool> debugReloadScheduleState() {
    return _reloadScheduleState();
  }

  Future<void> _setShowExperimentCourses(bool value) async {
    if (_showExperimentCourses == value) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showExperimentCoursesKey, value);
    _applyShowExperimentCoursesIfChanged(value);
  }

  void _applyShowExperimentCoursesIfChanged(bool value) {
    if (!mounted ||
        (_showExperimentCourses == value &&
            _showExperimentCoursesNotifier.value == value)) {
      return;
    }

    _clearWeekPlacementCache();
    _showExperimentCourses = value;
    _showExperimentCoursesNotifier.value = value;
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
    final weekDays = List<DateTime>.filled(7, weekStart, growable: false);
    var day = weekStart;
    for (var index = 0; index < weekDays.length; index++) {
      weekDays[index] = day;
      day = day.add(const Duration(days: 1));
    }
    return weekDays;
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
    final normalizedWeek = _normalizeWeek(weekNumber);
    final cachedWeekDays = _weekDaysCache[normalizedWeek];
    if (cachedWeekDays != null) {
      return cachedWeekDays;
    }
    final weekDays = _buildWeekDays(_dateForWeek(normalizedWeek));
    _weekDaysCache[normalizedWeek] = weekDays;
    return weekDays;
  }

  void _applyDisplayedWeek(int targetWeek) {
    final normalizedWeek = _normalizeWeek(targetWeek);
    final targetDate = _dateForWeek(normalizedWeek);
    if (normalizedWeek == _currentWeek &&
        _isSameDay(targetDate, _currentDate)) {
      return;
    }
    _currentWeek = normalizedWeek;
    _currentDate = targetDate;
    _displayedWeekNotifier.value = normalizedWeek;
    _invalidateWeekPlacementWarmup();
  }

  void _moveWeekPagerTo(int targetWeek, {bool animated = false}) {
    final targetPage = _normalizeWeek(targetWeek) - 1;

    void move(int page, {required bool withAnimation}) {
      if (!mounted || !_weekPageController.hasClients) {
        return;
      }
      final currentPage =
          _weekPageController.page ??
          _weekPageController.initialPage.toDouble();
      if ((currentPage - page).abs() < 0.01) {
        return;
      }
      if (withAnimation) {
        unawaited(
          _weekPageController.animateToPage(
            page,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
          ),
        );
        return;
      }
      _weekPageController.jumpToPage(page);
    }

    if (_weekPageController.hasClients) {
      move(targetPage, withAnimation: animated);
      return;
    }

    _pendingWeekPageMove = _PendingWeekPageMove(
      targetPage: targetPage,
      animated: animated,
    );
    if (_weekPageMovePending) {
      return;
    }

    _weekPageMovePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _weekPageMovePending = false;
      final pendingMove = _pendingWeekPageMove;
      _pendingWeekPageMove = null;
      if (pendingMove == null) {
        return;
      }
      move(pendingMove.targetPage, withAnimation: pendingMove.animated);
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
  String _dateKey(DateTime date) => _formatCourseDateKey(date);

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  List<Course> _coursesForDay(DateTime date) {
    return _courseData[_dateKey(date)] ?? const <Course>[];
  }

  void _clearWeekPlacementCache() {
    _weekDaysCache.clear();
    _weekPlacementsCache.clear();
    _weekCourseCardPaintCache.clear();
    _invalidateWeekPlacementWarmup();
  }

  void _invalidateWeekPlacementWarmup() {
    _weekPlacementWarmupGeneration++;
    _weekPlacementWarmupPending = false;
  }

  String _buildWeekPlacementCacheKey(
    List<DateTime> weekDays,
    _WeekGridMetrics metrics,
    bool showExperimentCourses,
  ) {
    final scheduleId = _activeSchedule?.id ?? 'no-schedule';
    final experimentMode = showExperimentCourses ? 'exp-on' : 'exp-off';
    return '$scheduleId|$experimentMode|${_dateKey(weekDays.first)}|'
        '${metrics.timeColumnWidth.toStringAsFixed(2)}|'
        '${metrics.dayWidth.toStringAsFixed(2)}|'
        '${metrics.columnGap.toStringAsFixed(2)}|'
        '${metrics.rowGap.toStringAsFixed(2)}|'
        '${metrics.slotHeight.toStringAsFixed(2)}|'
        '${metrics.gridHeight.toStringAsFixed(2)}';
  }

  bool _hasWeekPlacementCache(
    int weekNumber,
    _WeekGridMetrics metrics,
    bool showExperimentCourses,
  ) {
    final weekDays = _buildWeekDaysForWeek(weekNumber);
    return _weekPlacementsCache.containsKey(
      _buildWeekPlacementCacheKey(weekDays, metrics, showExperimentCourses),
    );
  }

  bool _hasWeekPaintCache({
    required int weekNumber,
    required _WeekGridMetrics metrics,
    required ThemeData theme,
    required ui.TextDirection textDirection,
    required TextScaler textScaler,
    required bool showExperimentCourses,
  }) {
    final weekDays = _buildWeekDaysForWeek(weekNumber);
    final placements =
        _weekPlacementsCache[_buildWeekPlacementCacheKey(
          weekDays,
          metrics,
          showExperimentCourses,
        )];
    if (placements == null || placements.isEmpty) {
      return placements != null;
    }

    return _weekCourseCardPaintCache.containsKey(
      _buildWeekCourseCardPaintCacheKey(
        weekDays,
        metrics,
        showExperimentCourses,
        theme,
        textDirection,
        textScaler,
      ),
    );
  }

  void _scheduleWeekPlacementWarmup(
    _WeekGridMetrics metrics, {
    required bool showExperimentCourses,
    required ThemeData theme,
    required ui.TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    if (_weekPlacementWarmupPending ||
        !_isInitialLoadComplete ||
        _courseData.isEmpty) {
      return;
    }

    final centerWeek = _normalizeWeek(_displayedWeekNotifier.value);
    final targetWeeks = <int>[
      if (centerWeek > 1) centerWeek - 1,
      centerWeek,
      if (centerWeek < _allWeek) centerWeek + 1,
    ];
    var needsWarmup = false;
    for (final weekNumber in targetWeeks) {
      if (!_hasWeekPlacementCache(weekNumber, metrics, showExperimentCourses) ||
          !_hasWeekPaintCache(
            weekNumber: weekNumber,
            metrics: metrics,
            theme: theme,
            textDirection: textDirection,
            textScaler: textScaler,
            showExperimentCourses: showExperimentCourses,
          )) {
        needsWarmup = true;
        break;
      }
    }
    if (!needsWarmup) {
      return;
    }

    final warmupGeneration = _weekPlacementWarmupGeneration;
    _weekPlacementWarmupPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (warmupGeneration != _weekPlacementWarmupGeneration) {
        return;
      }
      _weekPlacementWarmupPending = false;
      if (!mounted || _courseData.isEmpty) {
        return;
      }
      for (final weekNumber in targetWeeks) {
        final weekDays = _buildWeekDaysForWeek(weekNumber);
        final placedCourses = _buildPlacedCourses(
          weekDays,
          metrics,
          showExperimentCourses,
        );
        _buildWeekCourseCardPaintDataForEnvironment(
          weekDays: weekDays,
          metrics: metrics,
          placedCourses: placedCourses,
          showExperimentCourses: showExperimentCourses,
          theme: theme,
          textDirection: textDirection,
          textScaler: textScaler,
        );
      }
    });
  }

  /*
   * 根据课程名称生成固定颜色
   * @param seed 颜色生成种子字符串（课程名称）
   * @return HSL颜色空间生成的固定颜色
   */
  _CoursePalette _getCoursePalette(String seed, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
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

    showAppSnackBar(
      context,
      message: message,
      icon: CupertinoIcons.info_circle_fill,
      duration: const Duration(seconds: 2),
    );
  }

  bool get _useLiteAndroidEffects =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Color _sheetBarrierColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return colorScheme.overlayScrim.withValues(
      alpha: colorScheme.isDarkMode ? 0.20 : 0.10,
    );
  }

  Future<T?> _showAdaptiveBottomSheet<T>({
    required WidgetBuilder builder,
    bool expand = false,
  }) {
    final presenter = widget.showBottomSheet ?? showAppAdaptiveBottomSheet;
    return presenter<T>(
      context: context,
      expand: expand,
      backgroundColor: Colors.transparent,
      barrierColor: _sheetBarrierColor(context),
      transitionBackgroundColor: Colors.transparent,
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

  bool get _canEditActiveSchedule {
    final schedule = _activeSchedule;
    return schedule != null && !schedule.isReadOnly;
  }

  Future<void> _confirmDeleteCourse(
    _PlacedCourse placement, {
    BuildContext? sheetContext,
    required CourseDeleteScope scope,
  }) async {
    if (!_canEditActiveSchedule) {
      _showSnackBar('当前课表不支持删除课程');
      return;
    }

    if (sheetContext != null && Navigator.of(sheetContext).canPop()) {
      Navigator.of(sheetContext).pop();
    }

    final title =
        scope == CourseDeleteScope.currentOccurrence ? '删除当前课程' : '删除整学期课程';
    final content =
        scope == CourseDeleteScope.currentOccurrence
            ? '确认只删除当前这次“${placement.course.name}”吗？其他周的同一课程会保留。'
            : '确认从当前活动课表的整学期中删除“${placement.course.name}”吗？';
    final successMessage =
        scope == CourseDeleteScope.currentOccurrence ? '已删除当前课程' : '已删除整学期课程';

    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                title: Text(title),
                content: Text(content),
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

    try {
      final deleteCourse =
          widget.deleteCourse ?? deleteCourseFromActiveSchedule;
      final deleted = await deleteCourse(
        dateKey: _dateKey(placement.day),
        targetCourse: placement.course,
        scope: scope,
      );
      if (!mounted) {
        return;
      }
      if (!deleted) {
        _showSnackBar('删除失败，请稍后重试');
        return;
      }

      await _reloadScheduleState();
      if (!mounted) {
        return;
      }
      _showSnackBar('$successMessage：${placement.course.name}');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to delete course from active schedule',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar('删除课程失败，请稍后重试');
      }
    }
  }

  void _showCourseDetails(_PlacedCourse placement) {
    if (_isCourseDetailSheetOpen) {
      return;
    }

    _isCourseDetailSheetOpen = true;
    final course = placement.course;
    final sheet = _showAdaptiveBottomSheet<void>(
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
            onDeleteCurrentCourse:
                _canEditActiveSchedule
                    ? () => _confirmDeleteCourse(
                      placement,
                      sheetContext: sheetContext,
                      scope: CourseDeleteScope.currentOccurrence,
                    )
                    : null,
            onDeleteWholeScheduleCourse:
                _canEditActiveSchedule
                    ? () => _confirmDeleteCourse(
                      placement,
                      sheetContext: sheetContext,
                      scope: CourseDeleteScope.wholeSchedule,
                    )
                    : null,
          ),
    );
    unawaited(_trackCourseDetailSheet(sheet));
  }

  Future<void> _trackCourseDetailSheet(Future<void> sheet) async {
    try {
      await sheet;
    } finally {
      _isCourseDetailSheetOpen = false;
    }
  }

  Future<void> _openCampusLogin() async {
    final openLogin =
        widget.openCampusLogin ??
        (BuildContext context) async {
          await Navigator.of(context).push(UnifiedLoginPage.route());
        };
    await openLogin(context);
    await _reloadScheduleState();
  }

  Future<void> _handlePrimaryAction() async {
    if (_isPrimaryActionLoadingNotifier.value) {
      return;
    }
    if (CourseSyncService.instance.state.isRunning) {
      _showSnackBar('课表正在同步，请稍候');
      return;
    }

    _isPrimaryActionLoadingNotifier.value = true;

    var failureMessage = '课表同步失败，请稍后重试';
    try {
      if (!_hasLinkedCampusAccount) {
        failureMessage = '无法打开登录页面，请稍后重试';
        await _openCampusLogin();
        return;
      }

      final renewed = await renewToken(context);
      if (!mounted) {
        return;
      }
      if (!renewed) {
        return;
      }
      final token = await getToken();
      if (!mounted) {
        return;
      }
      final started = await CourseSyncService.instance.startManualSync(token);
      if (!started && mounted && CourseSyncService.instance.state.isRunning) {
        _showSnackBar('课表正在同步，请稍候');
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to run course table primary action',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar(failureMessage);
      }
    } finally {
      if (mounted) {
        _isPrimaryActionLoadingNotifier.value = false;
      }
    }
  }

  Future<void> _switchToSchedule(SavedCourseSchedule schedule) async {
    if (_activeSchedule?.id == schedule.id) {
      return;
    }

    try {
      final switchSchedule = widget.switchSchedule ?? setActiveCourseSchedule;
      await switchSchedule(schedule.id);
      await _reloadScheduleState();
      _showSnackBar('已切换到 ${schedule.name}');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to switch course schedule',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar('切换课表失败，请稍后重试');
      }
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

    try {
      final deleteSchedule = widget.deleteSchedule ?? deleteCourseSchedule;
      final deleted = await deleteSchedule(schedule.id);
      if (!mounted) {
        return;
      }
      if (!deleted) {
        _showSnackBar('删除失败，请稍后重试');
        return;
      }

      await _reloadScheduleState();
      if (!mounted) {
        return;
      }
      _showSnackBar('已删除 ${schedule.name}');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to delete course schedule',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar('删除课表失败，请稍后重试');
      }
    }
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
      final renameSchedule = widget.renameSchedule ?? renameCourseSchedule;
      await renameSchedule(schedule.id, normalizedName);
      await _reloadScheduleState();
      _showSnackBar('已重命名为 $normalizedName');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to rename course schedule',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar('重命名课表失败，请稍后重试');
      }
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
      final importShareCode =
          widget.importShareCode ?? saveImportedCourseScheduleFromShareCode;
      final importedSchedule = await importShareCode(code);
      await _reloadScheduleState();
      _showSnackBar('已导入 ${importedSchedule.name}');
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to parse course schedule share code',
        error: error,
        stackTrace: stackTrace,
      );
      if (reopenEditorOnFailure) {
        await _showManualImportDialog(
          initialText: rawCode,
          errorMessage: courseScheduleShareCodeParseFailureMessage,
        );
        return;
      }
      _showSnackBar(courseScheduleShareCodeParseFailureMessage);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to import course schedule from share code',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar('导入课表失败，请稍后重试');
      }
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
    if (_isImportingScheduleFromClipboard) {
      return;
    }

    _isImportingScheduleFromClipboard = true;
    try {
      final rawCode =
          (await (widget.readClipboardText ?? _readClipboardText)())?.trim() ??
          '';
      if (rawCode.isEmpty) {
        await _showManualImportDialog(errorMessage: '剪贴板里没有可导入的分享码');
        return;
      }
      await _importScheduleFromShareCode(rawCode, reopenEditorOnFailure: true);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to import course schedule from clipboard',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar('读取剪贴板失败，请稍后重试');
      }
    } finally {
      _isImportingScheduleFromClipboard = false;
    }
  }

  Future<String?> _readClipboardText() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    return clipboardData?.text;
  }

  Future<void> _writeClipboardText(String text) {
    final writeClipboardText = widget.writeClipboardText ?? _setClipboardText;
    return writeClipboardText(text);
  }

  Future<void> _setClipboardText(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _importScheduleFromFile() async {
    if (_isImportingScheduleFromFile) {
      return;
    }

    _isImportingScheduleFromFile = true;
    try {
      final rawContent =
          await (widget.pickImportFileContent ?? _pickImportFileContent)();
      if (rawContent == null) {
        return;
      }
      if (rawContent.trim().isEmpty) {
        _showSnackBar('选中的文件没有可导入内容');
        return;
      }

      final importFileContent =
          widget.importFileContent ?? saveImportedCourseScheduleFromFileContent;
      final importedSchedule = await importFileContent(rawContent);
      await _reloadScheduleState();
      _showSnackBar('已从文件导入 ${importedSchedule.name}');
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(
        'Failed to parse course schedule import file',
        error: error,
        stackTrace: stackTrace,
      );
      _showSnackBar(courseScheduleFileParseFailureMessage);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to import course schedule from file',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar('导入文件失败，请稍后重试');
      }
    } finally {
      _isImportingScheduleFromFile = false;
    }
  }

  Future<String?> _pickImportFileContent() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择工大盒子课表文件',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    if (file.path != null && file.path!.isNotEmpty) {
      return File(file.path!).readAsString();
    }
    return '';
  }

  String _sanitizeFileNameSegment(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'schedule';
    }

    final buffer = StringBuffer();
    var previousWasWhitespace = false;
    for (var index = 0; index < trimmed.length; index++) {
      final codeUnit = trimmed.codeUnitAt(index);
      if (_isCourseFileNameWhitespace(codeUnit)) {
        if (!previousWasWhitespace) {
          buffer.writeCharCode(0x5F);
          previousWasWhitespace = true;
        }
        continue;
      }

      previousWasWhitespace = false;
      if (_isUnsafeCourseFileNameCodeUnit(codeUnit)) {
        buffer.writeCharCode(0x2D);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }

    final safe = buffer.toString();
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

  Future<String?> _saveScheduleExportFile({
    required String fileName,
    required Uint8List bytes,
  }) {
    return FilePicker.platform.saveFile(
      dialogTitle: '导出课表文件',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
  }

  Future<void> _shareScheduleExportFile({
    required SavedCourseSchedule schedule,
    required Rect sharePositionOrigin,
  }) async {
    final file = await _writeScheduleExportTempFile(schedule);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '${schedule.name} 课表文件',
      text: '这是 ${schedule.name} 的工大盒子课表文件，导入后即可使用。',
      sharePositionOrigin: sharePositionOrigin,
    );
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
      final saveScheduleFile =
          widget.saveScheduleFile ?? _saveScheduleExportFile;
      final savedPath = await saveScheduleFile(
        fileName: _buildExportFileName(activeSchedule),
        bytes: bytes,
      );
      if (savedPath == null || savedPath.isEmpty) {
        return;
      }
      _showSnackBar('课表文件已导出');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to export course schedule file',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar('导出文件失败，请稍后重试');
      }
    }
  }

  Future<void> _shareActiveScheduleFile() async {
    final activeSchedule = _activeSchedule;
    if (activeSchedule == null) {
      _showSnackBar('当前没有可分享的课表');
      return;
    }

    try {
      final shareScheduleFile =
          widget.shareScheduleFile ?? _shareScheduleExportFile;
      await shareScheduleFile(
        schedule: activeSchedule,
        sharePositionOrigin: _sharePositionOrigin(),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to share course schedule file',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar('分享文件失败，请稍后重试');
      }
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
                                  try {
                                    await _writeClipboardText(shareCode);
                                    if (!dialogContext.mounted) {
                                      return;
                                    }
                                    Navigator.of(dialogContext).pop();
                                  } catch (error, stackTrace) {
                                    AppLogger.error(
                                      'Failed to copy course schedule share code from QR dialog',
                                      error: error,
                                      stackTrace: stackTrace,
                                    );
                                    if (mounted) {
                                      _showSnackBar('复制分享码失败，请稍后重试');
                                    }
                                  }
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
    if (_isScanningScheduleQrCode) {
      return;
    }

    _isScanningScheduleQrCode = true;
    try {
      final scanner = widget.scanQrCode ?? _scanQrCode;
      final scannedCode = await scanner(context);
      if (scannedCode == null || scannedCode.trim().isEmpty) {
        return;
      }
      await _importScheduleFromShareCode(scannedCode);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to scan course schedule QR code',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar('扫码导入失败，请稍后重试');
      }
    } finally {
      _isScanningScheduleQrCode = false;
    }
  }

  Future<String?> _scanQrCode(BuildContext context) async {
    final cameraPermission = await Permission.camera.request();
    if (!cameraPermission.isGranted) {
      if (!context.mounted) {
        return null;
      }

      final needsSettings =
          cameraPermission.isPermanentlyDenied || cameraPermission.isRestricted;
      showAppSnackBar(
        context,
        message:
            needsSettings
                ? '相机权限已关闭，请在系统设置中允许工大盒子访问相机后再扫码导入。'
                : '未授予相机权限，无法扫码导入课表。',
        type: AppSnackBarType.warning,
        icon: CupertinoIcons.camera_fill,
        actionLabel: needsSettings ? '去设置' : null,
        onAction: needsSettings ? openAppSettings : null,
      );
      return null;
    }

    if (!context.mounted) {
      return null;
    }
    return Navigator.of(context).push<String>(
      buildAppPageRoute(builder: (_) => const _CourseShareQrScannerPage()),
    );
  }

  Future<void> _exportActiveScheduleShareCode() async {
    if (_isCopyingScheduleShareCode) {
      return;
    }

    final activeSchedule = _activeSchedule;
    if (activeSchedule == null) {
      _showSnackBar('当前没有可分享的课表');
      return;
    }

    _isCopyingScheduleShareCode = true;
    try {
      final shareCode = buildCourseScheduleShareCode(activeSchedule);
      await _writeClipboardText(shareCode);
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
                    try {
                      await _writeClipboardText(shareCode);
                      navigator.pop();
                    } catch (error, stackTrace) {
                      AppLogger.error(
                        'Failed to copy course schedule share code again',
                        error: error,
                        stackTrace: stackTrace,
                      );
                      if (mounted) {
                        _showSnackBar('复制分享码失败，请稍后重试');
                      }
                    }
                  },
                  child: const Text('再次复制'),
                ),
              ],
            ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to copy course schedule share code',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar('复制分享码失败，请稍后重试');
      }
    } finally {
      _isCopyingScheduleShareCode = false;
    }
  }

  Future<void> _showScheduleManager() async {
    if (_isScheduleManagerSheetOpen) {
      return;
    }

    _isScheduleManagerSheetOpen = true;
    Future<bool>? contentReadyFuture;
    Future<bool> scheduleManagerContentReadyFuture() {
      return contentReadyFuture ??=
          _useLiteAndroidEffects
              ? Future<bool>.delayed(
                const Duration(milliseconds: 120),
                () => true,
              )
              : SynchronousFuture<bool>(true);
    }

    final _ScheduleManagerAction? action;
    try {
      action = await _showAdaptiveBottomSheet<_ScheduleManagerAction>(
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
              ),
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
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.4,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '把自己的历史课表和朋友分享的课表都收进这里，切换、备份、分享都会更清楚。',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _buildScheduleManagerPrimaryActionButton(
                            sheetContext,
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: _buildScheduleManagerBody(
                              sheetContext,
                              contentReadyFuture:
                                  scheduleManagerContentReadyFuture(),
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
    } finally {
      _isScheduleManagerSheetOpen = false;
    }

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
        return isReady
            ? KeyedSubtree(
              key: const ValueKey('schedule-manager-content'),
              child: _buildScheduleManagerSections(context),
            )
            : KeyedSubtree(
              key: const ValueKey('schedule-manager-placeholder'),
              child: _buildScheduleManagerPlaceholder(context),
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
                children: [
                  for (var index = 0; index < _savedSchedules.length; index++)
                    _buildSavedScheduleTile(
                      sheetContext,
                      schedule: _savedSchedules[index],
                      isLast: index == _savedSchedules.length - 1,
                      useLitePanels: useLitePanels,
                    ),
                ],
              ),
    );
  }

  Widget _buildSavedScheduleTile(
    BuildContext sheetContext, {
    required SavedCourseSchedule schedule,
    required bool isLast,
    required bool useLitePanels,
  }) {
    final theme = Theme.of(sheetContext);
    final colorScheme = theme.colorScheme;
    final isActive = schedule.id == _activeSchedule?.id;
    final badges = _scheduleBadges(schedule, isActive: isActive);
    final tileAccent = isActive ? colorScheme.primary : colorScheme.tertiary;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
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
              alpha: theme.brightness == Brightness.dark ? 0.08 : 0.64,
            ),
            tileAccent.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.12,
            ),
            colorScheme.surface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.12 : 0.28,
            ),
          ],
        ),
        borderColor: tileAccent.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.22 : 0.20,
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
                  children: [
                    for (final badge in badges) _ScheduleBadge(label: badge),
                  ],
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
                  Navigator.of(
                    sheetContext,
                  ).pop(_ScheduleManagerAction.rename(schedule));
                  break;
                case 'delete':
                  Navigator.of(
                    sheetContext,
                  ).pop(_ScheduleManagerAction.delete(schedule));
                  break;
              }
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('重命名')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
          ),
          onTap:
              () => Navigator.of(
                sheetContext,
              ).pop(_ScheduleManagerAction.switchSchedule(schedule)),
        ),
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
              for (var index = 2; index < lineWidths.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: placeholderLine(lineWidths[index]),
                ),
              if (trailingTiles > 0) ...[
                const Spacer(),
                for (var index = 0; index < trailingTiles; index++)
                  Padding(
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
                  ),
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
                ValueListenableBuilder<bool>(
                  valueListenable: _isPrimaryActionLoadingNotifier,
                  builder: (context, isPrimaryActionLoading, _) {
                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            isPrimaryActionLoading
                                ? null
                                : _handlePrimaryAction,
                        icon:
                            isPrimaryActionLoading
                                ? const AppLoadingIndicator(
                                  size: 18,
                                  color: Colors.white,
                                )
                                : Icon(
                                  _hasLinkedCampusAccount
                                      ? Icons.cloud_download_rounded
                                      : Icons.login_rounded,
                                ),
                        label: Text(primaryLabel),
                      ),
                    );
                  },
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

  Widget _buildPreparingState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      key: const ValueKey('course-table-preparing-state'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Center(
        child: AppLoadingIndicator(size: 22, color: colorScheme.primary),
      ),
    );
  }

  Widget _buildCourseTableContent(BuildContext context) {
    if (!_isInitialLoadComplete) {
      return _buildPreparingState(context);
    }

    if (_courseData.isEmpty) {
      return _buildEmptyState(context);
    }

    return RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: _showExperimentCoursesNotifier,
        builder: (context, showExperimentCourses, child) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 88),
            child: Column(
              children: [
                RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _displayedWeekNotifier,
                    builder: (context, displayedWeek, child) {
                      final weekDays = _buildWeekDaysForWeek(displayedWeek);
                      return ValueListenableBuilder<bool>(
                        valueListenable: _transitionLiteModeNotifier,
                        builder: (context, useLiteStyle, child) {
                          return CourseTableToolbar(
                            weekTitle: '第$displayedWeek周',
                            weekDateRange: _buildWeekDateRange(weekDays),
                            currentWeekLabel: _buildCurrentWeekLabel(),
                            isShowingCurrentWeek:
                                displayedWeek == _currentRealWeek,
                            onBackToCurrentWeek: _backToRealWeek,
                            onManageSchedules: _showScheduleManager,
                            showExperimentCourses: showExperimentCourses,
                            onShowExperimentCoursesChanged:
                                _setShowExperimentCourses,
                            useLiteStyle: useLiteStyle,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ValueListenableBuilder<DateTime>(
                    valueListenable: _todayDateNotifier,
                    builder: (context, today, child) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final metrics = _buildGridMetrics(constraints);
                          _scheduleWeekPlacementWarmup(
                            metrics,
                            showExperimentCourses: showExperimentCourses,
                            theme: Theme.of(context),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          );
                          final basePagingPhysics =
                              _allWeek <= 1
                                  ? const NeverScrollableScrollPhysics()
                                  : const _CourseTablePagingPhysics().applyTo(
                                    ScrollConfiguration.of(
                                      context,
                                    ).getScrollPhysics(context),
                                  );
                          return Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: metrics.totalWidth,
                              child: PageView.builder(
                                key: const ValueKey('course-table-week-pager'),
                                controller: _weekPageController,
                                itemCount: _allWeek,
                                dragStartBehavior: DragStartBehavior.down,
                                allowImplicitScrolling: false,
                                physics: basePagingPhysics,
                                onPageChanged: _handleWeekPageChanged,
                                itemBuilder: (context, index) {
                                  final weekNumber = index + 1;
                                  return _buildWeekPage(
                                    context: context,
                                    weekDays: _buildWeekDaysForWeek(weekNumber),
                                    metrics: metrics,
                                    today: today,
                                    showExperimentCourses:
                                        showExperimentCourses,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
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
    final start = _formatCourseMonthDay(weekDays.first);
    final end = _formatCourseMonthDay(weekDays.last);
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
    bool showExperimentCourses,
  ) {
    final cacheKey = _buildWeekPlacementCacheKey(
      weekDays,
      metrics,
      showExperimentCourses,
    );
    final cachedPlacements = _weekPlacementsCache[cacheKey];
    if (cachedPlacements != null) {
      return cachedPlacements;
    }

    final placements = <_PlacedCourse>[];
    for (var dayIndex = 0; dayIndex < weekDays.length; dayIndex++) {
      final dayCourses = _coursesForDay(weekDays[dayIndex]);
      _appendDayCoursePlacements(
        targetPlacements: placements,
        dayCourses: dayCourses,
        dayDate: weekDays[dayIndex],
        dayIndex: dayIndex,
        metrics: metrics,
        showExperimentCourses: showExperimentCourses,
      );
    }
    final cachedResult = List<_PlacedCourse>.unmodifiable(placements);
    _weekPlacementsCache[cacheKey] = cachedResult;
    return cachedResult;
  }

  String _buildWeekCourseCardPaintCacheKey(
    List<DateTime> weekDays,
    _WeekGridMetrics metrics,
    bool showExperimentCourses,
    ThemeData theme,
    ui.TextDirection textDirection,
    TextScaler textScaler,
  ) {
    final bodySmall = theme.textTheme.bodySmall;
    final labelSmall = theme.textTheme.labelSmall;
    final placementKey = _buildWeekPlacementCacheKey(
      weekDays,
      metrics,
      showExperimentCourses,
    );
    final bodyFontFamily = bodySmall?.fontFamily ?? 'default';
    final labelFontFamily = labelSmall?.fontFamily ?? 'default';
    return '$placementKey|${theme.brightness.name}|$bodyFontFamily|'
        '${(bodySmall?.fontSize ?? 0).toStringAsFixed(2)}|'
        '$labelFontFamily|'
        '${(labelSmall?.fontSize ?? 0).toStringAsFixed(2)}|'
        '${textDirection.name}|${textScaler.scale(1).toStringAsFixed(2)}';
  }

  List<_CourseCardPaintData> _buildWeekCourseCardPaintData({
    required BuildContext context,
    required List<DateTime> weekDays,
    required _WeekGridMetrics metrics,
    required List<_PlacedCourse> placedCourses,
    required bool showExperimentCourses,
  }) {
    return _buildWeekCourseCardPaintDataForEnvironment(
      weekDays: weekDays,
      metrics: metrics,
      placedCourses: placedCourses,
      showExperimentCourses: showExperimentCourses,
      theme: Theme.of(context),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  List<_CourseCardPaintData> _buildWeekCourseCardPaintDataForEnvironment({
    required List<DateTime> weekDays,
    required _WeekGridMetrics metrics,
    required List<_PlacedCourse> placedCourses,
    required bool showExperimentCourses,
    required ThemeData theme,
    required ui.TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    if (placedCourses.isEmpty) {
      return const <_CourseCardPaintData>[];
    }

    final cacheKey = _buildWeekCourseCardPaintCacheKey(
      weekDays,
      metrics,
      showExperimentCourses,
      theme,
      textDirection,
      textScaler,
    );
    final cachedCards = _weekCourseCardPaintCache[cacheKey];
    if (cachedCards != null) {
      return cachedCards;
    }

    final firstPlacement = placedCourses.first;
    final paintData = List<_CourseCardPaintData>.filled(
      placedCourses.length,
      _buildCourseCardPaintData(
        placement: firstPlacement,
        palette: _getCoursePalette(firstPlacement.course.name, theme),
        theme: theme,
        textDirection: textDirection,
        textScaler: textScaler,
      ),
      growable: false,
    );
    for (var index = 1; index < placedCourses.length; index++) {
      final placement = placedCourses[index];
      paintData[index] = _buildCourseCardPaintData(
        placement: placement,
        palette: _getCoursePalette(placement.course.name, theme),
        theme: theme,
        textDirection: textDirection,
        textScaler: textScaler,
      );
    }
    final cachedResult = List<_CourseCardPaintData>.unmodifiable(paintData);
    _weekCourseCardPaintCache[cacheKey] = cachedResult;
    return cachedResult;
  }

  _CourseCardPaintData _buildCourseCardPaintData({
    required _PlacedCourse placement,
    required _CoursePalette palette,
    required ThemeData theme,
    required ui.TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final course = placement.course;
    final width = placement.width;
    final height = placement.height;
    final compact = height < 44 || width < 38;
    final showLocation = course.location.trim().isNotEmpty;
    final showTeacher = course.teacherName.trim().isNotEmpty;
    final detailLineCount = (showLocation ? 1 : 0) + (showTeacher ? 1 : 0);
    final titleBaseStyle =
        theme.textTheme.bodySmall?.copyWith(
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
    final detailSpacing = detailLineCount == 0 ? 0.0 : (compact ? 1.0 : 2.0);
    final contentHeight = math.max(0.0, height - topPadding - bottomPadding);
    final contentWidth = math.max(0.0, width - horizontalPadding * 2);
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
    final titleHeight = math.max(
      0.0,
      contentHeight -
          detailLineCount * detailLineHeight -
          detailLineCount * detailSpacing,
    );
    final titleReferenceLineHeight = compact ? 10.6 : 12.4;
    final titleMinFontSize = compact ? 7.8 : 8.8;
    final titleMaxFontSize = math.min(
      compact ? 15.0 : 16.8,
      math.max(compact ? 10.6 : 11.8, width * (compact ? 0.34 : 0.29)),
    );
    final titleMaxLines = math.max(
      1,
      (titleHeight / titleReferenceLineHeight).floor(),
    );
    final titleFontSize = _fitMultilineFontSize(
      text: course.name,
      style: titleBaseStyle,
      maxWidth: contentWidth,
      maxHeight: titleHeight,
      maxLines: titleMaxLines,
      minFontSize: titleMinFontSize,
      maxFontSize: titleMaxFontSize,
      textDirection: textDirection,
      textScaler: textScaler,
    );
    final titlePainter = TextPainter(
      text: TextSpan(
        text: course.name,
        style: titleBaseStyle.copyWith(fontSize: titleFontSize),
      ),
      textDirection: textDirection,
      maxLines: titleMaxLines,
      ellipsis: '…',
      textScaler: textScaler,
    )..layout(maxWidth: contentWidth);

    final detailFontSize = math.max(
      compact ? 8.0 : 9.0,
      detailLineHeight * (compact ? 0.92 : 0.94),
    );
    final locationStyle =
        theme.textTheme.labelSmall?.copyWith(
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
        theme.textTheme.labelSmall?.copyWith(
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

    TextPainter? locationPainter;
    Offset? locationOffset;
    TextPainter? teacherPainter;
    Offset? teacherOffset;
    var detailTop = placement.top + topPadding + titleHeight;

    if (showLocation) {
      detailTop += detailSpacing;
      final locationFontSize = _fitSingleLineFontSize(
        text: course.location,
        style: locationStyle,
        maxWidth: contentWidth,
        maxHeight: detailLineHeight,
        textDirection: textDirection,
        textScaler: textScaler,
      );
      locationPainter = TextPainter(
        text: TextSpan(
          text: course.location,
          style: locationStyle.copyWith(fontSize: locationFontSize),
        ),
        textDirection: textDirection,
        maxLines: 1,
        textScaler: textScaler,
      )..layout(maxWidth: contentWidth);
      locationOffset = Offset(placement.left + horizontalPadding, detailTop);
      detailTop += detailLineHeight;
    }

    if (showTeacher) {
      detailTop += detailSpacing;
      final teacherFontSize = _fitSingleLineFontSize(
        text: course.teacherName,
        style: teacherStyle,
        maxWidth: contentWidth,
        maxHeight: detailLineHeight,
        textDirection: textDirection,
        textScaler: textScaler,
      );
      teacherPainter = TextPainter(
        text: TextSpan(
          text: course.teacherName,
          style: teacherStyle.copyWith(fontSize: teacherFontSize),
        ),
        textDirection: textDirection,
        maxLines: 1,
        textScaler: textScaler,
      )..layout(maxWidth: contentWidth);
      teacherOffset = Offset(placement.left + horizontalPadding, detailTop);
    }

    final borderRadius = BorderRadius.circular(compact ? 10 : 14);
    final rect = Rect.fromLTWH(
      placement.left,
      placement.top,
      placement.width,
      placement.height,
    );

    return _CourseCardPaintData(
      rect: rect,
      rrect: borderRadius.toRRect(rect),
      fillColor: palette.fill,
      accentColor: Color.lerp(palette.fill, palette.border, 0.42)!,
      borderColor: palette.border,
      shadow: BoxShadow(
        color: palette.border.withValues(alpha: 0.14),
        blurRadius: compact ? 8 : 12,
        offset: const Offset(0, 5),
      ),
      titlePainter: titlePainter,
      titleOffset: Offset(
        placement.left + horizontalPadding,
        placement.top + topPadding,
      ),
      locationPainter: locationPainter,
      locationOffset: locationOffset,
      teacherPainter: teacherPainter,
      teacherOffset: teacherOffset,
    );
  }

  double _fitMultilineFontSize({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    required int maxLines,
    required double minFontSize,
    required double maxFontSize,
    required ui.TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    if (text.trim().isEmpty || maxWidth <= 0 || maxHeight <= 0) {
      return minFontSize;
    }

    final maxReadableFontSize = _maxFontSizeForSample(
      sample: '课程名',
      style: style,
      maxWidth: maxWidth,
      minFontSize: minFontSize,
      maxFontSize: maxFontSize,
      textDirection: textDirection,
      textScaler: textScaler,
    );
    double low = minFontSize;
    double high = maxReadableFontSize;
    double best = minFontSize;

    for (var index = 0; index < 9; index++) {
      final current = (low + high) / 2;
      final painter = TextPainter(
        text: TextSpan(text: text, style: style.copyWith(fontSize: current)),
        textDirection: textDirection,
        maxLines: maxLines,
        ellipsis: '…',
        textScaler: textScaler,
      )..layout(maxWidth: maxWidth);

      if (painter.height <= maxHeight + 0.01) {
        best = current;
        low = current;
      } else {
        high = current;
      }
    }

    return best;
  }

  double _fitSingleLineFontSize({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    required ui.TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    if (text.trim().isEmpty || maxWidth <= 0 || maxHeight <= 0) {
      return style.fontSize ?? 12;
    }

    final baseFontSize = style.fontSize ?? 12;
    final minFontSize = math.max(1.0, baseFontSize * 0.55);
    final maxFontSize = baseFontSize;
    double low = minFontSize;
    double high = maxFontSize;
    double best = minFontSize;

    for (var index = 0; index < 9; index++) {
      final current = (low + high) / 2;
      final painter = TextPainter(
        text: TextSpan(text: text, style: style.copyWith(fontSize: current)),
        textDirection: textDirection,
        maxLines: 1,
        textScaler: textScaler,
      )..layout(maxWidth: double.infinity);

      if (painter.width <= maxWidth + 0.01 &&
          painter.height <= maxHeight + 0.01) {
        best = current;
        low = current;
      } else {
        high = current;
      }
    }

    return best;
  }

  double _maxFontSizeForSample({
    required String sample,
    required TextStyle style,
    required double maxWidth,
    required double minFontSize,
    required double maxFontSize,
    required ui.TextDirection textDirection,
    required TextScaler textScaler,
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
        textScaler: textScaler,
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

  String _buildCourseCardHitKey(_PlacedCourse placement) {
    return '${_dateKey(placement.day)}-${placement.startSection}-'
        '${placement.endSection}-${placement.course.name}';
  }

  Widget _buildWeekPage({
    required BuildContext context,
    required List<DateTime> weekDays,
    required _WeekGridMetrics metrics,
    required DateTime today,
    required bool showExperimentCourses,
  }) {
    final placedCourses = _buildPlacedCourses(
      weekDays,
      metrics,
      showExperimentCourses,
    );
    final paintedCards = _buildWeekCourseCardPaintData(
      context: context,
      weekDays: weekDays,
      metrics: metrics,
      placedCourses: placedCourses,
      showExperimentCourses: showExperimentCourses,
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return KeyedSubtree(
      key: ValueKey<String>(_dateKey(weekDays.first)),
      child: RepaintBoundary(
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
                  today: today,
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
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              key: const ValueKey(
                                'course-table-static-grid-layer',
                              ),
                              painter: _WeekGridStaticPainter(
                                metrics: metrics,
                                sectionCount: _sectionCount,
                                todayColumnIndex: weekDays.indexWhere(
                                  (day) => _isSameDay(day, today),
                                ),
                                todayHighlightColor: colorScheme.primary
                                    .withValues(alpha: isDark ? 0.08 : 0.06),
                                horizontalLineColor: colorScheme.outlineVariant
                                    .withValues(alpha: isDark ? 0.24 : 0.34),
                                verticalLineColor: colorScheme.outlineVariant
                                    .withValues(alpha: isDark ? 0.18 : 0.22),
                              ),
                              isComplex: true,
                              willChange: false,
                            ),
                          ),
                        ),
                        for (final section in _sectionTimes)
                          Positioned(
                            left: 0,
                            top: metrics.topForSection(section.index),
                            width: metrics.timeColumnWidth,
                            height: metrics.slotHeight,
                            child: _TimeAxisLabel(section: section),
                          ),
                        if (paintedCards.isNotEmpty)
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                key: const ValueKey(
                                  'course-table-static-card-layer',
                                ),
                                painter: _WeekCourseCardPainter(
                                  cards: paintedCards,
                                ),
                                isComplex: true,
                                willChange: false,
                              ),
                            ),
                          ),
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
                        for (final placement in placedCourses)
                          Positioned(
                            left: placement.left,
                            top: placement.top,
                            width: placement.width,
                            height: placement.height,
                            child: _ScheduleCourseCardHitTarget(
                              key: ValueKey<String>(
                                'course-card-hit-${_buildCourseCardHitKey(placement)}',
                              ),
                              semanticLabel: placement.course.name,
                              onTap: () => _showCourseDetails(placement),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _appendDayCoursePlacements({
    required List<_PlacedCourse> targetPlacements,
    required List<Course> dayCourses,
    required DateTime dayDate,
    required int dayIndex,
    required _WeekGridMetrics metrics,
    required bool showExperimentCourses,
  }) {
    final sortedCourses = <_CourseSpan>[];
    for (final course in dayCourses) {
      if (!showExperimentCourses && course.isExp) {
        continue;
      }
      final courseSpan = _normalizeCourse(course);
      if (courseSpan != null) {
        sortedCourses.add(courseSpan);
      }
    }
    sortedCourses.sort((a, b) {
      final startCompare = a.startSection.compareTo(b.startSection);
      if (startCompare != 0) {
        return startCompare;
      }
      return b.endSection.compareTo(a.endSection);
    });
    final dayLeft = metrics.leftForDay(dayIndex);
    var clusterStartIndex = 0;

    while (clusterStartIndex < sortedCourses.length) {
      var clusterEndIndex = clusterStartIndex + 1;
      var clusterEndSection = sortedCourses[clusterStartIndex].endSection;
      while (clusterEndIndex < sortedCourses.length) {
        final courseSpan = sortedCourses[clusterEndIndex];
        if (courseSpan.startSection > clusterEndSection) {
          break;
        }
        if (courseSpan.endSection > clusterEndSection) {
          clusterEndSection = courseSpan.endSection;
        }
        clusterEndIndex++;
      }

      final active = <_ActiveCourseSlot>[];
      final assignments = <_CourseAssignment>[];
      var columnCount = 0;

      for (var index = clusterStartIndex; index < clusterEndIndex; index++) {
        final courseSpan = sortedCourses[index];
        var activeWriteIndex = 0;
        for (var slotIndex = 0; slotIndex < active.length; slotIndex++) {
          final slot = active[slotIndex];
          if (slot.endSection >= courseSpan.startSection) {
            active[activeWriteIndex] = slot;
            activeWriteIndex++;
          }
        }
        if (activeWriteIndex < active.length) {
          active.removeRange(activeWriteIndex, active.length);
        }

        var column = 0;
        while (true) {
          var columnInUse = false;
          for (final slot in active) {
            if (slot.column == column) {
              columnInUse = true;
              break;
            }
          }
          if (!columnInUse) {
            break;
          }
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
        targetPlacements.add(
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

      clusterStartIndex = clusterEndIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassPerformanceScope(
        isLite: true,
        child: ValueListenableBuilder<bool>(
          valueListenable: _transitionLiteModeNotifier,
          child: SafeArea(
            bottom: false,
            child: _buildCourseTableContent(context),
          ),
          builder: (context, useLiteStyle, child) {
            return AppGlassBackground(
              style:
                  _isInitialLoadComplete && !useLiteStyle
                      ? AppGlassBackgroundStyle.soft
                      : AppGlassBackgroundStyle.flat,
              bottomHighlightOpacity: 0,
              lightBottomColor: const Color(0xFFEAF0FA),
              darkBottomColor: const Color(0xFF101826),
              child: child!,
            );
          },
        ),
      ),
    );
  }

  Future<void> _showExpStudents(String pcid) async {
    if (pcid.isEmpty) {
      _showSnackBar('无法获取人员名单：缺少pcid，请在设置页刷新课表');
      return;
    }
    final Map<String, dynamic> re;
    try {
      final loadExperimentStudents =
          widget.loadExperimentStudents ?? getExpStudentList;
      re = await loadExperimentStudents(pcid);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load experiment students',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar('获取人员名单失败，请稍后重试');
      }
      return;
    }
    if (!mounted) {
      return;
    }

    if (re['code']?.toString() != '1') {
      _showSnackBar('获取人员名单失败，请稍后重试');
      return;
    }
    final Map<String, dynamic> data = Map<String, dynamic>.from(
      re['data'] as Map? ?? <String, dynamic>{},
    );
    final Map<String, dynamic> baseData = Map<String, dynamic>.from(
      data['baseData'] as Map? ?? <String, dynamic>{},
    );
    final students = <Map<String, dynamic>>[];
    final rawStudents = data['studentList'];
    if (rawStudents is List) {
      for (final item in rawStudents) {
        if (item is Map) {
          students.add(Map<String, dynamic>.from(item));
        }
      }
    }

    _showAdaptiveBottomSheet<void>(
      expand: false,
      builder:
          (sheetContext) =>
              ExperimentStudentsSheet(baseData: baseData, students: students),
    );
  }
}

class _CourseTablePagingPhysics extends ScrollPhysics {
  const _CourseTablePagingPhysics({super.parent});

  static const double _minCourseTableFlingDistance = 8.0;
  static const double _minCourseTableFlingVelocity = 20.0;
  static const double _dragMotionThreshold = 1.5;

  @override
  _CourseTablePagingPhysics applyTo(ScrollPhysics? ancestor) {
    return _CourseTablePagingPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingDistance => _minCourseTableFlingDistance;

  @override
  double get minFlingVelocity => _minCourseTableFlingVelocity;

  @override
  double? get dragStartDistanceMotionThreshold => _dragMotionThreshold;
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

class _WeekGridStaticPainter extends CustomPainter {
  const _WeekGridStaticPainter({
    required this.metrics,
    required this.sectionCount,
    required this.todayColumnIndex,
    required this.todayHighlightColor,
    required this.horizontalLineColor,
    required this.verticalLineColor,
  });

  final _WeekGridMetrics metrics;
  final int sectionCount;
  final int todayColumnIndex;
  final Color todayHighlightColor;
  final Color horizontalLineColor;
  final Color verticalLineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (todayColumnIndex >= 0 && todayColumnIndex < 7) {
      final highlightRect = Rect.fromLTWH(
        metrics.leftForDay(todayColumnIndex),
        0,
        metrics.dayWidth,
        size.height,
      );
      canvas.drawRect(highlightRect, Paint()..color = todayHighlightColor);
    }

    final horizontalPaint =
        Paint()
          ..color = horizontalLineColor
          ..strokeWidth = 1;
    final horizontalStartX = metrics.timeColumnWidth + metrics.columnGap;
    for (var index = 0; index < sectionCount; index++) {
      final y = metrics.topForSection(index + 1) + 0.5;
      canvas.drawLine(
        Offset(horizontalStartX, y),
        Offset(size.width, y),
        horizontalPaint,
      );
    }

    final verticalPaint =
        Paint()
          ..color = verticalLineColor
          ..strokeWidth = 1;
    for (var index = 0; index < 6; index++) {
      final x =
          metrics.leftForDay(index) +
          metrics.dayWidth +
          (metrics.columnGap / 2);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), verticalPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeekGridStaticPainter oldDelegate) {
    return oldDelegate.sectionCount != sectionCount ||
        oldDelegate.todayColumnIndex != todayColumnIndex ||
        oldDelegate.todayHighlightColor != todayHighlightColor ||
        oldDelegate.horizontalLineColor != horizontalLineColor ||
        oldDelegate.verticalLineColor != verticalLineColor ||
        oldDelegate.metrics.timeColumnWidth != metrics.timeColumnWidth ||
        oldDelegate.metrics.dayWidth != metrics.dayWidth ||
        oldDelegate.metrics.columnGap != metrics.columnGap ||
        oldDelegate.metrics.rowGap != metrics.rowGap ||
        oldDelegate.metrics.slotHeight != metrics.slotHeight ||
        oldDelegate.metrics.gridHeight != metrics.gridHeight;
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
    required this.today,
  });

  final List<DateTime> weekDays;
  final Map<int, String> weekdayMap;
  final _WeekGridMetrics metrics;
  final DateTime today;

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

    return Row(
      children: [
        SizedBox(width: metrics.timeColumnWidth),
        for (var index = 0; index < weekDays.length; index++)
          _buildDayHeader(
            index: index,
            theme: theme,
            colorScheme: colorScheme,
            isDark: isDark,
          ),
      ],
    );
  }

  Widget _buildDayHeader({
    required int index,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    final day = weekDays[index];
    final isToday = _isSameDay(day, today);

    return Padding(
      padding: EdgeInsets.only(left: index == 0 ? 0 : metrics.columnGap),
      child: SizedBox(
        width: metrics.dayWidth,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color:
                isToday
                    ? colorScheme.primary.withValues(
                      alpha: isDark ? 0.18 : 0.12,
                    )
                    : Colors.white.withValues(alpha: isDark ? 0.04 : 0.28),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  isToday
                      ? colorScheme.primary.withValues(
                        alpha: isDark ? 0.34 : 0.22,
                      )
                      : Colors.white.withValues(alpha: isDark ? 0.08 : 0.60),
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
                  _formatCourseMonthDay(day),
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

class _ScheduleCourseCardHitTarget extends StatelessWidget {
  const _ScheduleCourseCardHitTarget({
    super.key,
    required this.semanticLabel,
    required this.onTap,
  });

  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CourseCardPaintData {
  const _CourseCardPaintData({
    required this.rect,
    required this.rrect,
    required this.fillColor,
    required this.accentColor,
    required this.borderColor,
    required this.shadow,
    required this.titlePainter,
    required this.titleOffset,
    this.locationPainter,
    this.locationOffset,
    this.teacherPainter,
    this.teacherOffset,
  });

  final Rect rect;
  final RRect rrect;
  final Color fillColor;
  final Color accentColor;
  final Color borderColor;
  final BoxShadow shadow;
  final TextPainter titlePainter;
  final Offset titleOffset;
  final TextPainter? locationPainter;
  final Offset? locationOffset;
  final TextPainter? teacherPainter;
  final Offset? teacherOffset;
}

class _WeekCourseCardPainter extends CustomPainter {
  const _WeekCourseCardPainter({required this.cards});

  final List<_CourseCardPaintData> cards;

  @override
  void paint(Canvas canvas, Size size) {
    for (final card in cards) {
      canvas.drawRRect(
        card.rrect.shift(card.shadow.offset),
        card.shadow.toPaint(),
      );

      final fillPaint =
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [card.fillColor, card.accentColor],
            ).createShader(card.rect);
      canvas.drawRRect(card.rrect, fillPaint);

      final borderPaint =
          Paint()
            ..color = card.borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
      canvas.drawRRect(card.rrect, borderPaint);

      canvas.save();
      canvas.clipRRect(card.rrect);
      card.titlePainter.paint(canvas, card.titleOffset);
      if (card.locationPainter != null && card.locationOffset != null) {
        card.locationPainter!.paint(canvas, card.locationOffset!);
      }
      if (card.teacherPainter != null && card.teacherOffset != null) {
        card.teacherPainter!.paint(canvas, card.teacherOffset!);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WeekCourseCardPainter oldDelegate) {
    return oldDelegate.cards != cards;
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
        final textScaler = MediaQuery.textScalerOf(context);
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
            textScaler: textScaler,
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
  final ValueNotifier<bool> _isFlashOnNotifier = ValueNotifier<bool>(false);
  bool _isTogglingFlash = false;
  bool _isScanning = true;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _controller?.dispose();
    _isFlashOnNotifier.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    _scanSubscription = controller.scannedDataStream.listen((scanData) {
      final code = scanData.code;
      if (code == null || code.isEmpty || !_isScanning || !mounted) {
        return;
      }

      _isScanning = false;
      _scanSubscription?.cancel();
      controller.pauseCamera();
      Navigator.of(context).pop(code);
    });
  }

  Future<void> _toggleFlash() async {
    if (_isTogglingFlash) {
      return;
    }

    final controller = _controller;
    if (controller == null) {
      return;
    }

    _isTogglingFlash = true;
    try {
      await controller.toggleFlash();
      final current = await controller.getFlashStatus() ?? false;
      if (!mounted || _isFlashOnNotifier.value == current) {
        return;
      }

      _isFlashOnNotifier.value = current;
    } finally {
      _isTogglingFlash = false;
    }
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
                    ValueListenableBuilder<bool>(
                      valueListenable: _isFlashOnNotifier,
                      builder: (context, isFlashOn, _) {
                        return FilledButton.icon(
                          onPressed: _toggleFlash,
                          icon: Icon(
                            isFlashOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                          ),
                          label: Text(isFlashOn ? '关闭闪光灯' : '打开闪光灯'),
                        );
                      },
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
