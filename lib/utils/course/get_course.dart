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
  final Map<String, List<Course>> courseData = {};
  final Map<int, String> courseKey = {};

  void initData() {
    data = Map<String, dynamic>.from((orgdata['data'] as List).first as Map);
    expClassList = List<Map<String, dynamic>>.from(
      data['courses'] as List? ?? [],
    );
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
    for (final tempClass in expClassList) {
      try {
        final weekDay = _readInt(tempClass['weekDay'], fallback: -1);
        if (weekDay <= 0) {
          continue;
        }

        final saveDate = courseKey[weekDay] ?? '';
        if (saveDate.isEmpty) {
          continue;
        }

        final weekNoteDetail = tempClass['weekNoteDetail']?.toString() ?? '';
        if (weekNoteDetail.isEmpty) {
          continue;
        }

        final List<String> tokens =
            weekNoteDetail
                .split(',')
                .where((e) => e.trim().isNotEmpty)
                .toList();
        if (tokens.isEmpty) {
          continue;
        }

        final List<int> sections =
            tokens
                .map((t) {
                  final two = t.length >= 2 ? t.substring(t.length - 2) : t;
                  return int.tryParse(two) ?? 0;
                })
                .where((s) => s > 0)
                .toList();

        if (sections.isEmpty) {
          continue;
        }
        sections.sort();
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

  GetOrgDataWeb({required this.token});

  void initData() {
    // 不再需要configureDio，将在具体方法中配置
  }

  Future<Map<String, List<Course>>> getAllWeekClass(
    BuildContext? context, {
    CourseSyncProgressCallback? onProgress,
    required int completedUnitsOffset,
    required int totalUnits,
  }) async {
    bool needsFirstDay = true;
    bool receivedValidCourseResponse = false;
    Object? firstError;
    StackTrace? firstErrorStackTrace;
    final prefs = await SharedPreferences.getInstance();
    await configureDioFromStorage();
    courseData.clear();
    await prefs.setInt('firstWeek', firstWeek);
    await prefs.setInt('maxWeek', maxWeek);

    for (int i = firstWeek; i <= maxWeek; i++) {
      try {
        final Response<dynamic> response = await postDioWithCookie(
          '/njwhd/student/curriculum?week=$i',
          {},
        );
        final data = _asResponseMap(response.data);
        if (data == null) {
          throw _buildCourseRequestStateError(response.data);
        }
        if (data['code']?.toString() != '1') {
          throw _buildCourseRequestStateError(data);
        }
        receivedValidCourseResponse = true;

        if (_hasScheduleData(data)) {
          final getsingleweek = GetSingleWeekClass(orgdata: data);
          getsingleweek.initData();
          getsingleweek.getWeekDate();
          final tempData = getsingleweek.getSingleClass();
          _mergeCourseData(target: courseData, source: tempData);

          if (needsFirstDay && tempData.isNotEmpty) {
            final firstDate = tempData.keys.first;
            await prefs.setString('firstDay', firstDate);
            needsFirstDay = false;
          }
        } else {
          AppLogger.debug('第$i周没有课程数据');
        }

        await Future.delayed(const Duration(microseconds: 300));
        if (context != null && !context.mounted) {
          return courseData;
        }
        if (onProgress != null) {
          onProgress(
            CourseSyncProgress(
              phase: CourseSyncPhase.courseWeeks,
              completedUnits: completedUnitsOffset + (i - firstWeek + 1),
              totalUnits: totalUnits,
              message: '正在获取普通课表（第$i周）',
              currentWeek: i,
              totalWeeks: maxWeek,
            ),
          );
        } else if (context != null) {
          _showLoadingSnackBar(context, '正在获取第$i周课表');
        }
      } catch (error, stackTrace) {
        AppLogger.error('获取第$i周课表出错', error: error, stackTrace: stackTrace);
        firstError ??= error;
        firstErrorStackTrace ??= stackTrace;
      }
    }

    if (courseData.isEmpty &&
        !receivedValidCourseResponse &&
        firstError != null &&
        firstErrorStackTrace != null) {
      final capturedError = firstError;
      final capturedStackTrace = firstErrorStackTrace;
      Error.throwWithStackTrace(capturedError, capturedStackTrace);
    }

    return courseData;
  }

  Future<Map<String, List<Course>>> getSingleWeekClass(int week) async {
    try {
      await configureDioFromStorage();
      final Response<dynamic> response = await postDioWithCookie(
        '/njwhd/student/curriculum?week=$week',
        {},
      );
      final data = _asResponseMap(response.data);
      if (data == null) {
        throw _buildCourseRequestStateError(response.data);
      }
      if (data['code']?.toString() != '1') {
        throw _buildCourseRequestStateError(data);
      }

      if (!_hasScheduleData(data)) {
        AppLogger.debug('第$week周没有课程数据');
        return {};
      }

      final getsingleweek = GetSingleWeekClass(orgdata: data);
      getsingleweek.initData();
      getsingleweek.getWeekDate();
      return getsingleweek.getSingleClass();
    } catch (error, stackTrace) {
      AppLogger.error('获取第$week周课表出错', error: error, stackTrace: stackTrace);
      return {};
    }
  }

  Future<String> getCurrentSemesterId() async {
    try {
      await configureDioFromStorage();
      final Response<dynamic> response = await postDioWithCookie(
        '/njwhd/semesterList',
        {},
      );
      final data = _asResponseMap(response.data);
      if (data == null || data['code']?.toString() != '1') {
        semesterId = '';
        return '';
      }
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
      if (semesterId == null || semesterId!.isEmpty) {
        await getCurrentSemesterId();
      }
      await configureDioFromStorage();
      final sid = semesterId ?? '';
      expRawWeeklyResponses['capturedAt'] = DateTime.now().toIso8601String();
      expRawWeeklyResponses['semesterId'] = sid;
      for (int i = firstWeek; i <= maxWeek; i++) {
        final requestPath =
            '/njwhd/teacher/courseScheduleExp?xnxq01id=$sid&week=$i';
        try {
          if (sid.isEmpty) {
            continue;
          }
          final Response<dynamic> response = await postDioWithCookie(
            requestPath,
            {},
          );
          weeks['$i'] = {
            'requestPath': requestPath,
            'statusCode': response.statusCode,
            'response': _jsonSafeValue(response.data),
          };
          final data = _asResponseMap(response.data);
          if (data == null || data['code']?.toString() != '1') {
            throw _buildCourseRequestStateError(response.data);
          }
          if (_hasScheduleData(data)) {
            final getExpWeek = GetSingleWeekExpClass(orgdata: data);
            getExpWeek.initData();
            getExpWeek.getWeekDate();
            final tempData = getExpWeek.getSingleClass();
            _mergeCourseData(target: expCourseData, source: tempData);
          } else {
            AppLogger.debug('第$i周没有实验课表数据');
          }

          if (onProgress != null) {
            onProgress(
              CourseSyncProgress(
                phase: CourseSyncPhase.experimentWeeks,
                completedUnits: completedUnitsOffset + (i - firstWeek + 1),
                totalUnits: totalUnits,
                message: '正在获取实验课表（第$i周）',
                currentWeek: i,
                totalWeeks: maxWeek,
              ),
            );
          } else if (context != null) {
            if (!context.mounted) {
              return expCourseData;
            }
            _showLoadingSnackBar(context, '正在获取第$i周实验课表');
          }
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (error, stackTrace) {
          weeks['$i'] = {
            'requestPath': requestPath,
            'error': error.toString(),
            if (error is DioException && error.response != null)
              'statusCode': error.response?.statusCode,
            if (error is DioException && error.response != null)
              'response': _jsonSafeValue(error.response?.data),
          };
          AppLogger.error('获取第$i周实验课表出错', error: error, stackTrace: stackTrace);
        }
      }
    } catch (error, stackTrace) {
      AppLogger.error('获取实验课表失败总体错误', error: error, stackTrace: stackTrace);
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
