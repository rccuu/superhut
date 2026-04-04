import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/app_logger.dart';
import 'course_sync_progress.dart';
import '../withhttp.dart';
import 'coursemain.dart';

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

Map<String, dynamic>? _asResponseMap(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return null;
}

String? _extractResponseMessage(Map<String, dynamic> data) {
  for (final key in const ['Msg', 'msg', 'message']) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') {
      return value;
    }
  }
  return null;
}

StateError _buildCourseRequestStateError(dynamic responseData) {
  final data = _asResponseMap(responseData);
  final message = data == null ? null : _extractResponseMessage(data);
  return StateError(message ?? '教务系统登录状态已失效，请重新登录后再试');
}

dynamic _jsonSafeValue(dynamic value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), _jsonSafeValue(item)),
    );
  }
  if (value is List) {
    return value.map(_jsonSafeValue).toList();
  }
  return value.toString();
}

bool _hasScheduleData(Map<String, dynamic> data) {
  final payload = data['data'];
  return payload is List && payload.isNotEmpty;
}

DateTime? _tryParseCourseDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return DateTime.tryParse(trimmed);
}

String _formatCourseDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

const Map<String, int> _sectionIndexByStartTime = <String, int>{
  '08:00': 1,
  '08:55': 2,
  '10:00': 3,
  '10:55': 4,
  '14:00': 5,
  '14:55': 6,
  '16:00': 7,
  '16:55': 8,
  '19:00': 9,
  '19:55': 10,
};

const Map<String, int> _sectionIndexByEndTime = <String, int>{
  '08:45': 1,
  '09:40': 2,
  '10:45': 3,
  '11:40': 4,
  '14:45': 5,
  '15:40': 6,
  '16:45': 7,
  '17:40': 8,
  '19:45': 9,
  '20:40': 10,
};

String? _findEarliestDateKey(Iterable<String> dates) {
  DateTime? earliest;
  for (final value in dates) {
    final parsed = _tryParseCourseDate(value);
    if (parsed == null) {
      continue;
    }
    if (earliest == null || parsed.isBefore(earliest)) {
      earliest = parsed;
    }
  }
  return earliest == null ? null : _formatCourseDate(earliest);
}

void _showLoadingSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.removeCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: Theme.of(context).secondaryHeaderColor,
      content: Text(message),
    ),
  );
}

void _mergeCourseData({
  required Map<String, List<Course>> target,
  required Map<String, List<Course>> source,
}) {
  source.forEach((date, courses) {
    target.putIfAbsent(date, () => []);
    target[date]!.addAll(courses);
  });
}

class _WeekFetchResult {
  const _WeekFetchResult._({
    required this.week,
    required this.courseData,
    this.error,
    this.stackTrace,
  });

  const _WeekFetchResult.success(int week, Map<String, List<Course>> courseData)
    : this._(week: week, courseData: courseData);

  const _WeekFetchResult.failure(int week, Object error, StackTrace stackTrace)
    : this._(
        week: week,
        courseData: const <String, List<Course>>{},
        error: error,
        stackTrace: stackTrace,
      );

  final int week;
  final Map<String, List<Course>> courseData;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isSuccess => error == null;
}

class _JsonRequestResult {
  const _JsonRequestResult({required this.response, required this.data});

  final Response<dynamic> response;
  final Map<String, dynamic> data;
}

class GetSingleWeekClass {
  final Map<String, dynamic> orgdata;

  GetSingleWeekClass({required this.orgdata});

  late Map<String, dynamic> data;
  late List<Map<String, dynamic>> orgclassList;
  late List<Map<String, dynamic>> dateList;
  final Map<String, List<Course>> courseData = {};
  final Map<int, String> courseKey = {};

  void initData() {
    data = Map<String, dynamic>.from((orgdata['data'] as List).first as Map);
    orgclassList = List<Map<String, dynamic>>.from(data['item'] as List? ?? []);
    dateList = List<Map<String, dynamic>>.from(data['date'] as List? ?? []);
  }

  void getWeekDate() {
    for (final tempDate in dateList) {
      final xqid = _readInt(tempDate['xqid']);
      final date = tempDate['mxrq']?.toString() ?? '';
      if (date.isEmpty) {
        continue;
      }
      courseData[date] = [];
      courseKey[xqid] = date;
    }
  }

  Map<String, List<Course>> getSingleClass() {
    for (final tempClass in orgclassList) {
      try {
        final classTime = tempClass['classTime']?.toString() ?? '';
        if (classTime.length < 3) {
          AppLogger.debug('警告：classTime 格式不正确: $classTime');
          continue;
        }

        final atDay = _readInt(classTime.substring(0, 1), fallback: -1);
        final startSection = _readInt(classTime.substring(1, 3), fallback: -1);
        final endSection = _readInt(
          classTime.substring(classTime.length - 2),
          fallback: -1,
        );
        final duration = endSection - startSection + 1;
        final saveDate = courseKey[atDay] ?? '';

        if (saveDate.isEmpty ||
            startSection <= 0 ||
            endSection < startSection) {
          AppLogger.debug('跳过异常课程时间数据: $tempClass');
          continue;
        }

        courseData[saveDate]!.add(
          Course(
            name: tempClass['courseName']?.toString() ?? '',
            teacherName: tempClass['teacherName']?.toString() ?? '',
            weekDuration: tempClass['classWeek']?.toString() ?? '',
            location: tempClass['location']?.toString() ?? '',
            startSection: startSection,
            duration: duration,
          ),
        );
      } catch (error, stackTrace) {
        AppLogger.error('解析课程数据出错', error: error, stackTrace: stackTrace);
        AppLogger.debug('问题数据: $tempClass');
      }
    }

    return courseData;
  }
}

class GetSingleWeekExpClass {
  final Map<String, dynamic> orgdata;

  GetSingleWeekExpClass({required this.orgdata});

  late Map<String, dynamic> data;
  late List<Map<String, dynamic>> expClassList;
  late List<Map<String, dynamic>> dateList;
  late List<Map<String, dynamic>> sectionDefinitionList;
  final Map<String, List<Course>> courseData = {};
  final Map<int, String> courseKey = {};
  final Map<String, int> _sectionDefinitionIndexByLabel = {};

  void initData() {
    data = Map<String, dynamic>.from((orgdata['data'] as List).first as Map);
    expClassList = List<Map<String, dynamic>>.from(
      data['courses'] as List? ?? [],
    );
    dateList = List<Map<String, dynamic>>.from(data['date'] as List? ?? []);
    sectionDefinitionList = List<Map<String, dynamic>>.from(
      orgdata['jcdatalist'] as List? ?? [],
    );
    _sectionDefinitionIndexByLabel
      ..clear()
      ..addEntries(
        sectionDefinitionList
            .asMap()
            .entries
            .map((entry) {
              final label = entry.value['DJMC']?.toString().trim() ?? '';
              return MapEntry(label, entry.key);
            })
            .where((entry) => entry.key.isNotEmpty),
      );
  }

  void getWeekDate() {
    for (final tempDate in dateList) {
      final xqid = _readInt(tempDate['xqid']);
      final date = tempDate['mxrq']?.toString() ?? '';
      if (date.isEmpty) {
        continue;
      }
      courseData[date] = [];
      courseKey[xqid] = date;
    }
  }

  List<int> _parseWeekNoteSections(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return const <int>[];
    }

    final sections =
        trimmed
            .split(RegExp(r'[,，\s]+'))
            .where((value) => value.trim().isNotEmpty)
            .map((value) {
              final normalized = value.trim();
              final lastTwo =
                  normalized.length >= 2
                      ? normalized.substring(normalized.length - 2)
                      : normalized;
              return int.tryParse(lastTwo) ?? 0;
            })
            .where((section) => section > 0)
            .toList();
    sections.sort();
    return sections;
  }

  List<int> _parseExplicitSections(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return const <int>[];
    }

    final sections =
        trimmed
            .split(RegExp(r'[,，\s]+'))
            .where((value) => value.trim().isNotEmpty)
            .map((value) => int.tryParse(value.trim()) ?? 0)
            .where((section) => section > 0)
            .toList();
    sections.sort();
    return sections;
  }

  List<int> _resolveSectionsFromSectionLabel(Map<String, dynamic> tempClass) {
    final label = tempClass['maxClassTime']?.toString().trim() ?? '';
    if (label.isEmpty) {
      return const <int>[];
    }

    final startIndex = _sectionDefinitionIndexByLabel[label];
    if (startIndex == null) {
      return const <int>[];
    }

    var expectedSectionCount = _readInt(tempClass['coursesNote'], fallback: 0);
    if (expectedSectionCount <= 0) {
      expectedSectionCount = 2;
    }

    final collected = <int>[];
    for (
      var index = startIndex;
      index < sectionDefinitionList.length &&
          collected.length < expectedSectionCount;
      index++
    ) {
      final sections = _parseExplicitSections(
        sectionDefinitionList[index]['XJMC']?.toString() ?? '',
      );
      if (sections.isEmpty) {
        continue;
      }
      collected.addAll(sections);
    }

    if (collected.isEmpty) {
      return const <int>[];
    }

    final limited =
        collected.length > expectedSectionCount
            ? collected.take(expectedSectionCount).toList()
            : collected;
    limited.sort();
    return limited;
  }

  List<int> _resolveSectionsFromTimeRange(Map<String, dynamic> tempClass) {
    final startTime = tempClass['startTime']?.toString().trim() ?? '';
    final endTime =
        (tempClass['endTIme'] ?? tempClass['endTime'])?.toString().trim() ?? '';
    if (startTime.isEmpty || endTime.isEmpty) {
      return const <int>[];
    }

    final startSection = _sectionIndexByStartTime[startTime];
    final endSection = _sectionIndexByEndTime[endTime];
    if (startSection == null ||
        endSection == null ||
        endSection < startSection) {
      return const <int>[];
    }

    return <int>[
      for (var section = startSection; section <= endSection; section++)
        section,
    ];
  }

  List<int> _resolveExperimentSections(Map<String, dynamic> tempClass) {
    final weekNoteSections = _parseWeekNoteSections(
      tempClass['weekNoteDetail']?.toString() ?? '',
    );
    if (weekNoteSections.isNotEmpty) {
      return weekNoteSections;
    }

    final sectionLabelSections = _resolveSectionsFromSectionLabel(tempClass);
    if (sectionLabelSections.isNotEmpty) {
      AppLogger.debug('实验课使用 maxClassTime 回退解析节次: $tempClass');
      return sectionLabelSections;
    }

    final timeRangeSections = _resolveSectionsFromTimeRange(tempClass);
    if (timeRangeSections.isNotEmpty) {
      AppLogger.debug('实验课使用 startTime/endTIme 回退解析节次: $tempClass');
      return timeRangeSections;
    }

    return const <int>[];
  }

  Map<String, List<Course>> getSingleClass() {
    for (final tempClass in expClassList) {
      try {
        final weekDay = _readInt(tempClass['weekDay'], fallback: -1);
        if (weekDay <= 0) {
          AppLogger.debug('跳过实验课：weekDay 无效: $tempClass');
          continue;
        }

        final saveDate = courseKey[weekDay] ?? '';
        if (saveDate.isEmpty) {
          AppLogger.debug('跳过实验课：未找到对应日期: $tempClass');
          continue;
        }

        final sections = _resolveExperimentSections(tempClass);
        if (sections.isEmpty) {
          AppLogger.debug('跳过实验课：无法解析节次信息: $tempClass');
          continue;
        }
        final startSection = sections.first;
        final endSection = sections.last;
        final duration = endSection - startSection + 1;

        final courseName = tempClass['courseName']?.toString() ?? '';
        final syxmName = tempClass['syxmName']?.toString() ?? '';
        final displayName =
            (syxmName.isNotEmpty)
                ? '$courseName 实验：$syxmName'
                : '$courseName 实验';

        courseData[saveDate]!.add(
          Course(
            name: displayName,
            teacherName: tempClass['teacherName']?.toString() ?? '',
            weekDuration: '第${tempClass['kkzc']?.toString() ?? ''}周',
            location: tempClass['classroomName']?.toString() ?? '',
            startSection: startSection,
            duration: duration,
            isExp: true,
            pcid: tempClass['pcid']?.toString() ?? '',
          ),
        );
      } catch (error, stackTrace) {
        AppLogger.error('解析实验课程数据出错', error: error, stackTrace: stackTrace);
        AppLogger.debug('问题数据: $tempClass');
      }
    }

    return courseData;
  }
}

class GetOrgDataWeb {
  static const int _defaultFirstWeek = 1;
  static const int _defaultMaxWeek = 20;
  static const int _weekFetchConcurrency = 4;
  static const int _maxWeekRequestAttempts = 2;
  static const int _maxConcurrentNetworkRequests = 6;

  final String token;
  int firstWeek = _defaultFirstWeek;
  int maxWeek = _defaultMaxWeek;
  final Map<String, List<Course>> courseData = {};
  String? semesterId;
  final Map<String, dynamic> expRawWeeklyResponses = {
    'schemaVersion': 1,
    'capturedAt': '',
    'semesterId': '',
    'weeks': <String, dynamic>{},
  };
  Future<Dio>? _sharedRequestDioFuture;
  final List<Completer<void>> _requestPermitWaiters = <Completer<void>>[];
  int _activeRequestCount = 0;

  GetOrgDataWeb({required this.token});

  void initData() {
    // 不再需要configureDio，将在具体方法中配置
  }

  Future<Dio> _getSharedRequestDio() {
    return _sharedRequestDioFuture ??= buildRequestDioFromStorage();
  }

  Future<T> _withRequestPermit<T>(Future<T> Function() action) async {
    while (_activeRequestCount >= _maxConcurrentNetworkRequests) {
      final waitHandle = Completer<void>();
      _requestPermitWaiters.add(waitHandle);
      await waitHandle.future;
    }

    _activeRequestCount += 1;
    try {
      return await action();
    } finally {
      _activeRequestCount -= 1;
      if (_requestPermitWaiters.isNotEmpty) {
        final nextWaiter = _requestPermitWaiters.removeAt(0);
        if (!nextWaiter.isCompleted) {
          nextWaiter.complete();
        }
      }
    }
  }

  Future<_JsonRequestResult> _postJsonWithRetry(
    Dio requestDio,
    String path, {
    required String requestLabel,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (int attempt = 1; attempt <= _maxWeekRequestAttempts; attempt++) {
      try {
        final Response<dynamic> response = await _withRequestPermit(
          () => postWithRequestDio(requestDio, path, {}),
        );
        final data = _asResponseMap(response.data);
        if (data == null) {
          throw _buildCourseRequestStateError(response.data);
        }
        if (data['code']?.toString() != '1') {
          throw _buildCourseRequestStateError(data);
        }
        return _JsonRequestResult(response: response, data: data);
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        AppLogger.error(
          '$requestLabel失败（第$attempt/$_maxWeekRequestAttempts次）',
          error: error,
          stackTrace: stackTrace,
        );
        if (attempt < _maxWeekRequestAttempts) {
          await Future.delayed(Duration(milliseconds: 120 * attempt));
        }
      }
    }

    if (lastError != null && lastStackTrace != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace);
    }
    throw StateError('$requestLabel失败');
  }

  Map<String, List<Course>> _parseSingleWeekCourseData(
    Map<String, dynamic> data,
  ) {
    if (!_hasScheduleData(data)) {
      return {};
    }

    final getsingleweek = GetSingleWeekClass(orgdata: data);
    getsingleweek.initData();
    getsingleweek.getWeekDate();
    return getsingleweek.getSingleClass();
  }

  Map<String, List<Course>> _parseSingleWeekExpCourseData(
    Map<String, dynamic> data,
  ) {
    if (!_hasScheduleData(data)) {
      return {};
    }

    final getExpWeek = GetSingleWeekExpClass(orgdata: data);
    getExpWeek.initData();
    getExpWeek.getWeekDate();
    return getExpWeek.getSingleClass();
  }

  Future<Map<int, Map<String, List<Course>>>> _fetchWeeklyCourseData({
    required List<int> weeks,
    required String scheduleLabel,
    required CourseSyncPhase phase,
    required BuildContext? context,
    required int completedUnitsOffset,
    required int totalUnits,
    required Future<Map<String, List<Course>>> Function(int week) fetchWeekData,
    CourseSyncProgressCallback? onProgress,
    void Function(int week, Object error, StackTrace stackTrace)? onWeekFailure,
  }) async {
    final weekResults = <int, Map<String, List<Course>>>{};
    final failedWeeks = <int>[];
    int completedWeeks = 0;
    final totalWeekCount = weeks.length;

    if (totalWeekCount <= 0) {
      return weekResults;
    }

    for (
      int startIndex = 0;
      startIndex < weeks.length;
      startIndex += _weekFetchConcurrency
    ) {
      if (context != null && !context.mounted) {
        return weekResults;
      }

      final endIndex = math.min(
        startIndex + _weekFetchConcurrency,
        weeks.length,
      );
      final batchWeeks = weeks.sublist(startIndex, endIndex);
      final batchResults = await Future.wait(
        batchWeeks.map((week) async {
          try {
            final parsedCourseData = await fetchWeekData(week);
            return _WeekFetchResult.success(week, parsedCourseData);
          } catch (error, stackTrace) {
            return _WeekFetchResult.failure(week, error, stackTrace);
          }
        }),
      );

      for (final result in batchResults) {
        completedWeeks += 1;
        if (result.isSuccess) {
          weekResults[result.week] = result.courseData;
          if (result.courseData.isEmpty) {
            AppLogger.debug('第${result.week}周没有$scheduleLabel数据');
          }
        } else {
          failedWeeks.add(result.week);
          onWeekFailure?.call(result.week, result.error!, result.stackTrace!);
          AppLogger.error(
            '第${result.week}周$scheduleLabel抓取失败',
            error: result.error,
            stackTrace: result.stackTrace,
          );
        }

        if (context != null && !context.mounted) {
          return weekResults;
        }

        final progressMessage =
            '正在获取$scheduleLabel（$completedWeeks/$totalWeekCount）';
        if (onProgress != null) {
          onProgress(
            CourseSyncProgress(
              phase: phase,
              completedUnits: completedUnitsOffset + completedWeeks,
              totalUnits: totalUnits,
              message: progressMessage,
              currentWeek: completedWeeks,
              totalWeeks: totalWeekCount,
            ),
          );
        } else if (context != null) {
          _showLoadingSnackBar(context, progressMessage);
        }
      }
    }

    if (failedWeeks.isNotEmpty) {
      failedWeeks.sort();
      throw StateError('$scheduleLabel抓取不完整，请重试（第${failedWeeks.join('、')}周失败）');
    }

    return weekResults;
  }

  void _applyWeekResults(Map<int, Map<String, List<Course>>> weekResults) {
    courseData.clear();
    final sortedWeeks = weekResults.keys.toList()..sort();
    for (final week in sortedWeeks) {
      final tempData = weekResults[week];
      if (tempData == null || tempData.isEmpty) {
        continue;
      }
      _mergeCourseData(target: courseData, source: tempData);
    }
  }

  Future<Map<String, List<Course>>> getAllWeekClass(
    BuildContext? context, {
    CourseSyncProgressCallback? onProgress,
    required int completedUnitsOffset,
    required int totalUnits,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    courseData.clear();
    await prefs.setInt('firstWeek', firstWeek);
    await prefs.setInt('maxWeek', maxWeek);

    final totalWeekCount = maxWeek >= firstWeek ? maxWeek - firstWeek + 1 : 0;
    if (totalWeekCount <= 0) {
      return courseData;
    }

    final requestDio = await _getSharedRequestDio();
    if (context != null && !context.mounted) {
      return courseData;
    }
    final weeks = <int>[
      for (int week = firstWeek; week <= maxWeek; week++) week,
    ];
    final weekResults = await _fetchWeeklyCourseData(
      weeks: weeks,
      scheduleLabel: '普通课表',
      phase: CourseSyncPhase.courseWeeks,
      context: context,
      onProgress: onProgress,
      completedUnitsOffset: completedUnitsOffset,
      totalUnits: totalUnits,
      fetchWeekData: (week) async {
        final result = await _postJsonWithRetry(
          requestDio,
          '/njwhd/student/curriculum?week=$week',
          requestLabel: '获取第$week周普通课表',
        );
        return _parseSingleWeekCourseData(result.data);
      },
    );

    _applyWeekResults(weekResults);
    final firstDate = _findEarliestDateKey(courseData.keys);
    if (firstDate != null) {
      await prefs.setString('firstDay', firstDate);
    }
    return courseData;
  }

  Future<Map<String, List<Course>>> getSingleWeekClass(int week) async {
    try {
      final requestDio = await _getSharedRequestDio();
      final result = await _postJsonWithRetry(
        requestDio,
        '/njwhd/student/curriculum?week=$week',
        requestLabel: '获取第$week周普通课表',
      );
      final tempData = _parseSingleWeekCourseData(result.data);
      if (tempData.isEmpty) {
        AppLogger.debug('第$week周没有课程数据');
      }
      return tempData;
    } catch (error, stackTrace) {
      AppLogger.error('获取第$week周课表出错', error: error, stackTrace: stackTrace);
      return {};
    }
  }

  Future<String> getCurrentSemesterId({Dio? requestDio}) async {
    try {
      final client = requestDio ?? await _getSharedRequestDio();
      final result = await _postJsonWithRetry(
        client,
        '/njwhd/semesterList',
        requestLabel: '获取当前学期',
      );
      final data = result.data;
      final List<dynamic> iddata = data['data'] as List? ?? [];
      String nowid = '';
      for (var i = 0; i < iddata.length; i++) {
        final Map tempMap = iddata[i];
        if (tempMap['nowXq']?.toString() == '1') {
          nowid = tempMap['semesterId']?.toString() ?? '';
          break;
        }
      }
      semesterId = nowid;
      return nowid;
    } catch (error, stackTrace) {
      AppLogger.error('获取当前学期ID失败', error: error, stackTrace: stackTrace);
      semesterId = '';
      return '';
    }
  }

  Future<Map<String, List<Course>>> getAllWeekExpClass(
    BuildContext? context, {
    CourseSyncProgressCallback? onProgress,
    required int completedUnitsOffset,
    required int totalUnits,
  }) async {
    final Map<String, List<Course>> expCourseData = {};
    final weeks = expRawWeeklyResponses['weeks'] as Map<String, dynamic>;
    try {
      final requestDio = await _getSharedRequestDio();
      if (context != null && !context.mounted) {
        return expCourseData;
      }
      if (semesterId == null || semesterId!.isEmpty) {
        await getCurrentSemesterId(requestDio: requestDio);
      }
      if (context != null && !context.mounted) {
        return expCourseData;
      }
      final sid = semesterId ?? '';
      if (sid.isEmpty) {
        throw StateError('未获取到当前学期信息，无法获取实验课表');
      }
      expRawWeeklyResponses['capturedAt'] = DateTime.now().toIso8601String();
      expRawWeeklyResponses['semesterId'] = sid;
      weeks.clear();
      final weekNumbers = <int>[
        for (int week = firstWeek; week <= maxWeek; week++) week,
      ];
      final weekResults = await _fetchWeeklyCourseData(
        weeks: weekNumbers,
        scheduleLabel: '实验课表',
        phase: CourseSyncPhase.experimentWeeks,
        context: context,
        onProgress: onProgress,
        completedUnitsOffset: completedUnitsOffset,
        totalUnits: totalUnits,
        fetchWeekData: (week) async {
          final requestPath =
              '/njwhd/teacher/courseScheduleExp?xnxq01id=$sid&week=$week';
          final result = await _postJsonWithRetry(
            requestDio,
            requestPath,
            requestLabel: '获取第$week周实验课表',
          );
          weeks['$week'] = {
            'requestPath': requestPath,
            'statusCode': result.response.statusCode,
            'response': _jsonSafeValue(result.response.data),
          };
          return _parseSingleWeekExpCourseData(result.data);
        },
        onWeekFailure: (week, error, stackTrace) {
          final requestPath =
              '/njwhd/teacher/courseScheduleExp?xnxq01id=$sid&week=$week';
          weeks['$week'] = {
            'requestPath': requestPath,
            'error': error.toString(),
            if (error is DioException && error.response != null)
              'statusCode': error.response?.statusCode,
            if (error is DioException && error.response != null)
              'response': _jsonSafeValue(error.response?.data),
          };
        },
      );

      final sortedWeeks = weekResults.keys.toList()..sort();
      for (final week in sortedWeeks) {
        final tempData = weekResults[week];
        if (tempData == null || tempData.isEmpty) {
          continue;
        }
        _mergeCourseData(target: expCourseData, source: tempData);
      }
    } catch (error, stackTrace) {
      AppLogger.error('获取实验课表失败总体错误', error: error, stackTrace: stackTrace);
      rethrow;
    }
    return expCourseData;
  }
}

Future<Map<String, dynamic>> getExpStudentList(String pcid) async {
  try {
    await configureDioFromStorage();
    final Response<dynamic> response = await postDioWithCookie(
      '/njwhd/xuanke/getCuarStudentListExp?pcid=$pcid',
      {},
    );
    return Map<String, dynamic>.from(response.data as Map);
  } catch (error, stackTrace) {
    AppLogger.error('获取实验人员名单失败', error: error, stackTrace: stackTrace);
    return {'code': '0', 'Msg': 'error'};
  }
}
