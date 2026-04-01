import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/widget_refresh_service.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/app_auth_storage.dart';
import '../../core/services/app_logger.dart';
import '../../login/loginwithpost.dart';
import 'course_sync_progress.dart';
import 'get_course.dart';

const int _courseScheduleArchiveSchemaVersion = 1;
const int _courseScheduleShareSchemaVersion = 1;
const int _courseScheduleFileSchemaVersion = 1;
const int _courseWidgetStoreSchemaVersion = 2;
const String _courseScheduleArchiveFileName = 'course_schedules.json';
const String _legacyCourseDataFileName = 'course_data.json';
const String _courseWidgetStoreFileName = 'course_widget_store.json';
const String _courseWidgetPayloadFileName = 'course_widget_payload.json';
const String _courseSharePrefix = 'SUPERHUT1:';
const String _courseScheduleSharePayloadType = 'superhut_course_schedule_share';
const String _courseScheduleFilePayloadType = 'superhut_course_schedule_file';
const String _courseSilentRefreshAttemptAtKey = 'courseSilentRefreshAttemptAt';
const String _courseSilentRefreshAttemptAccountKey =
    'courseSilentRefreshAttemptAccount';
const Uuid _uuid = Uuid();

const Map<int, String> _courseSectionStartTimes = <int, String>{
  1: '08:00',
  2: '08:55',
  3: '10:00',
  4: '10:55',
  5: '14:00',
  6: '14:55',
  7: '16:00',
  8: '16:55',
  9: '19:00',
  10: '19:55',
};

const Map<int, String> _courseSectionEndTimes = <int, String>{
  1: '08:45',
  2: '09:40',
  3: '10:45',
  4: '11:40',
  5: '14:45',
  6: '15:40',
  7: '16:45',
  8: '17:40',
  9: '19:45',
  10: '20:40',
};

abstract final class CourseScheduleSourceType {
  static const String selfSync = 'self_sync';
  static const String shareImport = 'share_import';
  static const String migratedLegacy = 'migrated_legacy';
  static const String manual = 'manual';
}

String _stringValue(dynamic value) => value?.toString() ?? '';

int _intValue(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

class Course {
  final String name;
  final String teacherName;
  final String weekDuration;
  final String location;
  final int startSection;
  final int duration;
  final bool isExp;
  final String pcid;

  Course({
    required this.name,
    required this.teacherName,
    required this.weekDuration,
    required this.location,
    required this.startSection,
    required this.duration,
    this.isExp = false,
    this.pcid = '',
  });

  // 将 Course 对象转换为 Map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'teacherName': teacherName,
      'weekDuration': weekDuration,
      'location': location,
      'startSection': startSection,
      'duration': duration,
      'isExp': isExp,
      'pcid': pcid,
    };
  }

  // 从 Map 构造 Course 对象
  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      name: json['name'],
      teacherName: json['teacherName'],
      weekDuration: json['weekDuration'],
      location: json['location'],
      startSection: json['startSection'],
      duration: json['duration'],
      isExp: json['isExp'] ?? false,
      pcid: json['pcid'] ?? '',
    );
  }

  Course sanitizedForShare() {
    return Course(
      name: name,
      teacherName: teacherName,
      weekDuration: weekDuration,
      location: location,
      startSection: startSection,
      duration: duration,
      isExp: isExp,
      pcid: '',
    );
  }
}

bool _isSameCourse(Course left, Course right) {
  return left.name == right.name &&
      left.teacherName == right.teacherName &&
      left.weekDuration == right.weekDuration &&
      left.location == right.location &&
      left.startSection == right.startSection &&
      left.duration == right.duration &&
      left.isExp == right.isExp &&
      left.pcid == right.pcid;
}

bool _isSameWholeScheduleCourse(Course left, Course right) {
  if (left.name != right.name) {
    return false;
  }
  if (left.isExp != right.isExp) {
    return false;
  }
  if (left.teacherName.isNotEmpty &&
      right.teacherName.isNotEmpty &&
      left.teacherName != right.teacherName) {
    return false;
  }
  if (left.pcid.isNotEmpty &&
      right.pcid.isNotEmpty &&
      left.pcid != right.pcid) {
    return false;
  }
  return true;
}

enum CourseDeleteScope { currentOccurrence, wholeSchedule }

class SavedCourseSchedule {
  const SavedCourseSchedule({
    required this.id,
    required this.name,
    required this.ownerName,
    this.ownerAccount = '',
    required this.termLabel,
    required this.semesterId,
    required this.firstDay,
    required this.maxWeek,
    required this.sourceType,
    required this.isReadOnly,
    required this.createdAt,
    required this.updatedAt,
    required this.courseData,
  });

  final String id;
  final String name;
  final String ownerName;
  final String ownerAccount;
  final String termLabel;
  final String semesterId;
  final String firstDay;
  final int maxWeek;
  final String sourceType;
  final bool isReadOnly;
  final String createdAt;
  final String updatedAt;
  final Map<String, List<Course>> courseData;

  factory SavedCourseSchedule.fromJson(Map<String, dynamic> json) {
    final rawCourseData = Map<String, dynamic>.from(
      json['courseData'] as Map? ?? const <String, dynamic>{},
    );
    final courseData = <String, List<Course>>{};
    rawCourseData.forEach((date, rawCourses) {
      final courseList = rawCourses is List ? rawCourses : const <dynamic>[];
      courseData[date] =
          courseList
              .map(
                (rawCourse) => Course.fromJson(
                  Map<String, dynamic>.from(rawCourse as Map),
                ),
              )
              .toList();
    });

    return SavedCourseSchedule(
      id: _stringValue(json['id']),
      name: _stringValue(json['name']),
      ownerName: _stringValue(json['ownerName']),
      ownerAccount: _stringValue(json['ownerAccount']),
      termLabel: _stringValue(json['termLabel']),
      semesterId: _stringValue(json['semesterId']),
      firstDay: _stringValue(json['firstDay']),
      maxWeek: _intValue(json['maxWeek'], fallback: 20),
      sourceType: _stringValue(json['sourceType']),
      isReadOnly: json['isReadOnly'] == true,
      createdAt: _stringValue(json['createdAt']),
      updatedAt: _stringValue(json['updatedAt']),
      courseData: courseData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ownerName': ownerName,
      'ownerAccount': ownerAccount,
      'termLabel': termLabel,
      'semesterId': semesterId,
      'firstDay': firstDay,
      'maxWeek': maxWeek,
      'sourceType': sourceType,
      'isReadOnly': isReadOnly,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'courseData': _encodeCourseDataMap(courseData),
    };
  }

  Map<String, dynamic> toShareJson() {
    final sharedCourseData = <String, List<Course>>{};
    courseData.forEach((date, courses) {
      sharedCourseData[date] =
          courses.map((course) => course.sanitizedForShare()).toList();
    });

    return {
      'name': name,
      'ownerName': ownerName,
      'termLabel': termLabel,
      'semesterId': semesterId,
      'firstDay': firstDay,
      'maxWeek': maxWeek,
      'courseData': _encodeCourseDataMap(sharedCourseData),
    };
  }

  SavedCourseSchedule copyWith({
    String? id,
    String? name,
    String? ownerName,
    String? ownerAccount,
    String? termLabel,
    String? semesterId,
    String? firstDay,
    int? maxWeek,
    String? sourceType,
    bool? isReadOnly,
    String? createdAt,
    String? updatedAt,
    Map<String, List<Course>>? courseData,
  }) {
    return SavedCourseSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      ownerAccount: ownerAccount ?? this.ownerAccount,
      termLabel: termLabel ?? this.termLabel,
      semesterId: semesterId ?? this.semesterId,
      firstDay: firstDay ?? this.firstDay,
      maxWeek: maxWeek ?? this.maxWeek,
      sourceType: sourceType ?? this.sourceType,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      courseData: courseData ?? this.courseData,
    );
  }
}

class CourseScheduleArchive {
  const CourseScheduleArchive({
    required this.schemaVersion,
    required this.activeScheduleId,
    required this.schedules,
  });

  const CourseScheduleArchive.empty()
    : this(
        schemaVersion: _courseScheduleArchiveSchemaVersion,
        activeScheduleId: '',
        schedules: const [],
      );

  final int schemaVersion;
  final String activeScheduleId;
  final List<SavedCourseSchedule> schedules;

  factory CourseScheduleArchive.fromJson(Map<String, dynamic> json) {
    final rawSchedules = json['schedules'] as List? ?? const <dynamic>[];
    return CourseScheduleArchive(
      schemaVersion: _intValue(
        json['schemaVersion'],
        fallback: _courseScheduleArchiveSchemaVersion,
      ),
      activeScheduleId: _stringValue(json['activeScheduleId']),
      schedules:
          rawSchedules
              .map(
                (rawSchedule) => SavedCourseSchedule.fromJson(
                  Map<String, dynamic>.from(rawSchedule as Map),
                ),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'activeScheduleId': activeScheduleId,
      'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
    };
  }

  CourseScheduleArchive copyWith({
    int? schemaVersion,
    String? activeScheduleId,
    List<SavedCourseSchedule>? schedules,
  }) {
    return CourseScheduleArchive(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      activeScheduleId: activeScheduleId ?? this.activeScheduleId,
      schedules: schedules ?? this.schedules,
    );
  }
}

class CourseSyncSnapshot {
  const CourseSyncSnapshot({
    required this.courseData,
    required this.semesterId,
    required this.firstDay,
    required this.maxWeek,
  });

  final Map<String, List<Course>> courseData;
  final String semesterId;
  final String firstDay;
  final int maxWeek;
}

class CourseSyncResult {
  final bool success;
  final String message;

  const CourseSyncResult._({required this.success, required this.message});

  const CourseSyncResult.success([String message = '课表同步成功'])
    : this._(success: true, message: message);

  const CourseSyncResult.failure(String message)
    : this._(success: false, message: message);
}

abstract final class CourseSilentRefreshReason {
  static const String none = 'none';
  static const String noSession = 'no_session';
  static const String cooldown = 'cooldown';
  static const String cacheFresh = 'cache_fresh';
  static const String userManaged = 'user_managed';
  static const String noActiveSchedule = 'no_active_schedule';
  static const String migratedLegacy = 'migrated_legacy';
  static const String accountChanged = 'account_changed';
  static const String missingOwnerAccount = 'missing_owner_account';
  static const String staleSchedule = 'stale_schedule';
}

class CourseSilentRefreshPlan {
  const CourseSilentRefreshPlan({
    required this.shouldSync,
    required this.shouldClearSyncedSchedules,
    required this.reason,
    required this.accountId,
  });

  final bool shouldSync;
  final bool shouldClearSyncedSchedules;
  final String reason;
  final String accountId;
}

CourseSyncResult _buildCourseSyncFailure(Object error, StackTrace stackTrace) {
  AppLogger.error(
    'Error saving course JSON file',
    error: error,
    stackTrace: stackTrace,
  );

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const CourseSyncResult.failure('网络连接失败，请检查网络后重试');
      default:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          return const CourseSyncResult.failure('教务系统登录状态已失效，请重新登录后再试');
        }
        break;
    }
  }

  return const CourseSyncResult.failure('课表加载失败，请稍后重试');
}

class CourseWidgetCourseEntry {
  const CourseWidgetCourseEntry({
    required this.name,
    required this.meta,
    required this.location,
    required this.startSection,
    required this.endSection,
    required this.startTime,
    required this.sectionLabel,
  });

  final String name;
  final String meta;
  final String location;
  final int startSection;
  final int endSection;
  final String startTime;
  final String sectionLabel;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'meta': meta,
      'location': location,
      'startSection': startSection,
      'endSection': endSection,
      'startTime': startTime,
      'sectionLabel': sectionLabel,
    };
  }

  factory CourseWidgetCourseEntry.fromJson(Map<String, dynamic> json) {
    return CourseWidgetCourseEntry(
      name: _stringValue(json['name']),
      meta: _stringValue(json['meta']),
      location: _stringValue(json['location']),
      startSection: _intValue(json['startSection'], fallback: 0),
      endSection: _intValue(json['endSection'], fallback: 0),
      startTime: _stringValue(json['startTime']),
      sectionLabel: _stringValue(json['sectionLabel']),
    );
  }
}

class CourseWidgetStore {
  const CourseWidgetStore({
    required this.schemaVersion,
    required this.updatedAt,
    required this.days,
    required this.dayCourses,
  });

  final int schemaVersion;
  final String updatedAt;
  final Map<String, CourseWidgetPayload> days;
  final Map<String, List<CourseWidgetCourseEntry>> dayCourses;

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'updatedAt': updatedAt,
      'days': days.map(
        (date, payload) => MapEntry<String, dynamic>(date, payload.toJson()),
      ),
      'dayCourses': dayCourses.map(
        (date, courses) => MapEntry<String, dynamic>(
          date,
          courses.map((course) => course.toJson()).toList(),
        ),
      ),
    };
  }

  factory CourseWidgetStore.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as Map?;
    if (rawDays != null) {
      final days = <String, CourseWidgetPayload>{};
      rawDays.forEach((date, rawPayload) {
        days[date.toString()] = CourseWidgetPayload.fromJson(
          Map<String, dynamic>.from(rawPayload as Map),
        );
      });

      final rawDayCourses = json['dayCourses'] as Map?;
      final dayCourses = <String, List<CourseWidgetCourseEntry>>{};
      if (rawDayCourses != null) {
        rawDayCourses.forEach((date, rawCourses) {
          final courseList =
              rawCourses is List ? rawCourses : const <dynamic>[];
          dayCourses[date.toString()] =
              courseList
                  .map(
                    (rawCourse) => CourseWidgetCourseEntry.fromJson(
                      Map<String, dynamic>.from(rawCourse as Map),
                    ),
                  )
                  .toList();
        });
      }

      return CourseWidgetStore(
        schemaVersion: _intValue(
          json['schemaVersion'],
          fallback: _courseWidgetStoreSchemaVersion,
        ),
        updatedAt: _stringValue(json['updatedAt']),
        days: days,
        dayCourses: dayCourses,
      );
    }

    final legacyCourseData = Map<String, dynamic>.from(
      json['courseData'] as Map? ?? const <String, dynamic>{},
    );
    final parsedCourseData = <String, List<Course>>{};
    legacyCourseData.forEach((date, rawCourses) {
      final courseList = rawCourses is List ? rawCourses : const <dynamic>[];
      parsedCourseData[date] =
          courseList
              .map(
                (rawCourse) => Course.fromJson(
                  Map<String, dynamic>.from(rawCourse as Map),
                ),
              )
              .toList();
    });

    return buildCourseWidgetStoreFromRawData(
      firstDay: _stringValue(json['firstDay']),
      maxWeek: _intValue(json['maxWeek'], fallback: 20),
      updatedAt: _stringValue(json['updatedAt']),
      courseData: parsedCourseData,
    );
  }
}

class CourseWidgetPayload {
  const CourseWidgetPayload({
    required this.date,
    required this.weekdayLabel,
    required this.weekIndex,
    required this.status,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.emptyText,
    required this.isEmpty,
    required this.updatedAt,
    required this.courses,
  });

  final String date;
  final String weekdayLabel;
  final int weekIndex;
  final String status;
  final String headerTitle;
  final String headerSubtitle;
  final String emptyText;
  final bool isEmpty;
  final String updatedAt;
  final List<CourseWidgetCourseEntry> courses;

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'weekdayLabel': weekdayLabel,
      'weekIndex': weekIndex,
      'status': status,
      'headerTitle': headerTitle,
      'headerSubtitle': headerSubtitle,
      'emptyText': emptyText,
      'isEmpty': isEmpty,
      'updatedAt': updatedAt,
      'courses': courses.map((course) => course.toJson()).toList(),
    };
  }

  factory CourseWidgetPayload.fromJson(Map<String, dynamic> json) {
    final rawCourses = json['courses'] as List? ?? const <dynamic>[];
    return CourseWidgetPayload(
      date: _stringValue(json['date']),
      weekdayLabel: _stringValue(json['weekdayLabel']),
      weekIndex: _intValue(json['weekIndex'], fallback: 0),
      status: _stringValue(json['status']),
      headerTitle: _stringValue(json['headerTitle']),
      headerSubtitle: _stringValue(json['headerSubtitle']),
      emptyText: _stringValue(json['emptyText']),
      isEmpty: json['isEmpty'] == true,
      updatedAt: _stringValue(json['updatedAt']),
      courses:
          rawCourses
              .map(
                (rawCourse) => CourseWidgetCourseEntry.fromJson(
                  Map<String, dynamic>.from(rawCourse as Map),
                ),
              )
              .toList(),
    );
  }
}

Future<void> saveExperimentRawDataToJson(
  Map<String, dynamic> experimentRawData,
) async {
  final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
  final String appDocumentsPath = appDocumentsDir.path;
  final file = File('$appDocumentsPath/experiment_course_raw.json');
  await file.writeAsString(jsonEncode(experimentRawData));
}

Map<String, List<Map<String, dynamic>>> _encodeCourseDataMap(
  Map<String, List<Course>> courseData,
) {
  final courseDataMap = <String, List<Map<String, dynamic>>>{};
  courseData.forEach((date, courses) {
    courseDataMap[date] = courses.map((course) => course.toJson()).toList();
  });
  return courseDataMap;
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime _startOfMonday(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final daysToSubtract =
      normalized.weekday == DateTime.sunday ? 6 : normalized.weekday - 1;
  return normalized.subtract(Duration(days: daysToSubtract));
}

int _resolveCourseWidgetWeekIndex({
  required String firstDay,
  required int maxWeek,
  required DateTime today,
}) {
  final parsedFirstDay = DateTime.tryParse(firstDay);
  if (parsedFirstDay == null) {
    return 0;
  }

  final firstMonday = _startOfMonday(parsedFirstDay);
  final currentMonday = _startOfMonday(today);
  final difference = currentMonday.difference(firstMonday).inDays;
  if (difference < 0) {
    return 0;
  }

  final computedWeek = difference ~/ 7 + 1;
  if (maxWeek <= 0) {
    return computedWeek;
  }
  return computedWeek.clamp(1, maxWeek).toInt();
}

CourseWidgetPayload buildCompactCourseWidgetPayloadFromStore(
  CourseWidgetStore? store, {
  DateTime? now,
}) {
  final resolvedNow = now ?? DateTime.now();
  final today = DateTime(resolvedNow.year, resolvedNow.month, resolvedNow.day);
  if (store == null) {
    return _buildEmptyCourseWidgetPayload(
      date: today,
      updatedAt: resolvedNow.toIso8601String(),
    );
  }

  return _buildRelevantCourseWidgetPayloadFromStore(
    store: store,
    now: resolvedNow,
  );
}

CourseWidgetPayload buildCompactCourseWidgetPayload(
  SavedCourseSchedule? schedule, {
  DateTime? now,
}) {
  if (schedule == null) {
    return buildCompactCourseWidgetPayloadFromStore(null, now: now);
  }

  return buildCompactCourseWidgetPayloadFromStore(
    buildCourseWidgetStore(schedule),
    now: now,
  );
}

List<Course> _sortedCoursesForDate(
  Map<String, List<Course>> courseData,
  String dateKey,
) {
  final courses = [...(courseData[dateKey] ?? const <Course>[])]
    ..sort((left, right) => left.startSection.compareTo(right.startSection));
  return courses;
}

List<CourseWidgetCourseEntry> _sortedWidgetCourses(
  List<CourseWidgetCourseEntry> courses,
) {
  final sorted = [...courses]
    ..sort((left, right) => left.startSection.compareTo(right.startSection));
  return sorted;
}

DateTime _startOfDay(DateTime dateTime) {
  return DateTime(dateTime.year, dateTime.month, dateTime.day);
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

DateTime? _timeOnDate(DateTime date, String timeLabel) {
  if (timeLabel.isEmpty || timeLabel == '--:--') {
    return null;
  }
  final parts = timeLabel.split(':');
  if (parts.length != 2) {
    return null;
  }
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  return DateTime(date.year, date.month, date.day, hour, minute);
}

DateTime? _courseEndsAt(DateTime date, CourseWidgetCourseEntry course) {
  final endSection =
      course.endSection > 0 ? course.endSection : course.startSection;
  final timeLabel = _sectionEndTime(endSection);
  return _timeOnDate(date, timeLabel);
}

List<CourseWidgetCourseEntry> _remainingCoursesForDate({
  required DateTime date,
  required DateTime now,
  required List<CourseWidgetCourseEntry> courses,
}) {
  final sorted = _sortedWidgetCourses(courses);
  if (!_isSameDate(date, now)) {
    return sorted;
  }

  return sorted.where((course) {
    final endAt = _courseEndsAt(date, course);
    if (endAt == null) {
      return true;
    }
    return endAt.isAfter(now);
  }).toList();
}

List<CourseWidgetCourseEntry> _resolveStoreDayCourses(
  CourseWidgetStore store,
  String dateKey,
) {
  final rawDayCourses = store.dayCourses[dateKey];
  if (rawDayCourses != null && rawDayCourses.isNotEmpty) {
    return _sortedWidgetCourses(rawDayCourses);
  }

  final payload = store.days[dateKey];
  if (payload != null &&
      payload.status == 'today_courses' &&
      payload.courses.isNotEmpty) {
    return _sortedWidgetCourses(payload.courses);
  }

  return const <CourseWidgetCourseEntry>[];
}

DateTime? _findNextCourseDateAfterInStore(
  DateTime currentDate,
  CourseWidgetStore store,
) {
  final actualDateKeys = <String>{...store.dayCourses.keys};
  if (actualDateKeys.isEmpty) {
    store.days.forEach((dateKey, payload) {
      if (payload.status == 'today_courses' && payload.courses.isNotEmpty) {
        actualDateKeys.add(dateKey);
      }
    });
  }

  final sortedDateKeys = actualDateKeys.toList()..sort();
  for (final dateKey in sortedDateKeys) {
    final parsedDate = DateTime.tryParse(dateKey);
    if (parsedDate == null) {
      continue;
    }
    if (!parsedDate.isAfter(currentDate)) {
      continue;
    }
    if (_resolveStoreDayCourses(store, dateKey).isNotEmpty) {
      return parsedDate;
    }
  }
  return null;
}

CourseWidgetPayload _buildEmptyCourseWidgetPayload({
  required DateTime date,
  required String updatedAt,
}) {
  final dateKey = _dateKey(date);
  return CourseWidgetPayload(
    date: dateKey,
    weekdayLabel: _weekdayLabel(date.weekday),
    weekIndex: 0,
    status: 'empty',
    headerTitle: '当前暂无课表',
    headerSubtitle: '同步或导入后显示课程',
    emptyText: '同步或导入后显示课程',
    isEmpty: true,
    updatedAt: updatedAt,
    courses: const [],
  );
}

int _weekIndexFromStore(CourseWidgetStore store, DateTime date) {
  return store.days[_dateKey(date)]?.weekIndex ?? 0;
}

String _weekdayLabelFromStore(CourseWidgetStore store, DateTime date) {
  final payload = store.days[_dateKey(date)];
  final label = payload?.weekdayLabel ?? '';
  return label.isNotEmpty ? label : _weekdayLabel(date.weekday);
}

CourseWidgetPayload _buildRelevantCourseWidgetPayloadFromStore({
  required CourseWidgetStore store,
  required DateTime now,
}) {
  final today = _startOfDay(now);
  final todayKey = _dateKey(today);
  final updatedAt =
      store.updatedAt.isNotEmpty ? store.updatedAt : now.toIso8601String();
  final todayWeekIndex = _weekIndexFromStore(store, today);

  final todayCourses = _remainingCoursesForDate(
    date: today,
    now: now,
    courses: _resolveStoreDayCourses(store, todayKey),
  );

  if (todayCourses.isNotEmpty) {
    return CourseWidgetPayload(
      date: todayKey,
      weekdayLabel: _weekdayLabelFromStore(store, today),
      weekIndex: todayWeekIndex,
      status: 'today_courses',
      headerTitle: '今天课程',
      headerSubtitle: _composeWeekSubtitle(
        date: today,
        weekIndex: todayWeekIndex,
      ),
      emptyText: '今日暂无课程',
      isEmpty: false,
      updatedAt: updatedAt,
      courses: todayCourses.take(2).toList(),
    );
  }

  final tomorrow = today.add(const Duration(days: 1));
  final tomorrowKey = _dateKey(tomorrow);
  final tomorrowCourses = _resolveStoreDayCourses(store, tomorrowKey);

  if (today.weekday == DateTime.sunday && tomorrowCourses.isNotEmpty) {
    final mondayWeekIndex = _weekIndexFromStore(store, tomorrow);
    return CourseWidgetPayload(
      date: todayKey,
      weekdayLabel: _weekdayLabelFromStore(store, today),
      weekIndex: todayWeekIndex,
      status: 'next_monday',
      headerTitle: '周一有课',
      headerSubtitle: mondayWeekIndex > 0 ? '下周第$mondayWeekIndex周' : '明天上午别睡过',
      emptyText: '周一有课',
      isEmpty: false,
      updatedAt: updatedAt,
      courses: tomorrowCourses.take(2).toList(),
    );
  }

  if (tomorrowCourses.isNotEmpty) {
    final tomorrowWeekIndex = _weekIndexFromStore(store, tomorrow);
    return CourseWidgetPayload(
      date: todayKey,
      weekdayLabel: _weekdayLabelFromStore(store, today),
      weekIndex: todayWeekIndex,
      status: 'tomorrow_courses',
      headerTitle: '明天有课',
      headerSubtitle: _composeWeekSubtitle(
        date: tomorrow,
        weekIndex: tomorrowWeekIndex,
      ),
      emptyText: '明天有课',
      isEmpty: false,
      updatedAt: updatedAt,
      courses: tomorrowCourses.take(2).toList(),
    );
  }

  final nextCourseDate = _findNextCourseDateAfterInStore(today, store);
  if (nextCourseDate != null) {
    final nextCourses = _resolveStoreDayCourses(
      store,
      _dateKey(nextCourseDate),
    );
    final nextWeekIndex = _weekIndexFromStore(store, nextCourseDate);
    final sameWeek = _startOfMonday(nextCourseDate) == _startOfMonday(today);
    return CourseWidgetPayload(
      date: todayKey,
      weekdayLabel: _weekdayLabelFromStore(store, today),
      weekIndex: todayWeekIndex,
      status: 'next_course',
      headerTitle: '下次课程',
      headerSubtitle:
          sameWeek
              ? _composeWeekSubtitle(
                date: nextCourseDate,
                weekIndex: nextWeekIndex,
              )
              : _composeWeekSubtitle(
                date: nextCourseDate,
                weekIndex: nextWeekIndex,
                prefix: '本周无课',
              ),
      emptyText: '下次课程',
      isEmpty: false,
      updatedAt: updatedAt,
      courses: nextCourses.take(2).toList(),
    );
  }

  return _buildEmptyCourseWidgetPayload(date: today, updatedAt: updatedAt);
}

String _formatMonthDay(DateTime date) {
  return '${date.month}/${date.day.toString().padLeft(2, '0')}';
}

String _composeWeekSubtitle({
  required DateTime date,
  required int weekIndex,
  String? prefix,
}) {
  final parts = <String>[];
  if (prefix != null && prefix.isNotEmpty) {
    parts.add(prefix);
  }
  parts.add(_weekdayLabel(date.weekday));
  if (weekIndex > 0) {
    parts.add('第$weekIndex周');
  }
  return parts.join(' · ');
}

CourseWidgetCourseEntry _buildDisplayEntry(
  Course course, {
  required bool includeDatePrefix,
  DateTime? date,
}) {
  final endSection = course.startSection + course.duration - 1;
  final timeLabel = _sectionStartTime(course.startSection);
  final titleBuffer = StringBuffer();
  if (includeDatePrefix && date != null) {
    titleBuffer.write('${_formatMonthDay(date)} ');
  }
  if (timeLabel.isNotEmpty && timeLabel != '--:--') {
    titleBuffer.write('$timeLabel ');
  }
  titleBuffer.write(course.name);

  final meta =
      course.location.isNotEmpty
          ? course.location
          : '${course.startSection}-$endSection节';

  return CourseWidgetCourseEntry(
    name: titleBuffer.toString().trim(),
    meta: meta,
    location: course.location,
    startSection: course.startSection,
    endSection: endSection,
    startTime: timeLabel,
    sectionLabel: '${course.startSection}-$endSection节',
  );
}

DateTime? _findNextCourseDateAfter(
  DateTime currentDate,
  Map<String, List<Course>> courseData,
) {
  final sortedDateKeys = courseData.keys.toList()..sort();
  for (final dateKey in sortedDateKeys) {
    final parsedDate = DateTime.tryParse(dateKey);
    if (parsedDate == null) {
      continue;
    }
    if (!parsedDate.isAfter(currentDate)) {
      continue;
    }
    if ((courseData[dateKey] ?? const <Course>[]).isNotEmpty) {
      return parsedDate;
    }
  }
  return null;
}

CourseWidgetPayload _buildCourseWidgetPayloadForDate({
  required DateTime date,
  required Map<String, List<Course>> courseData,
  required String firstDay,
  required int maxWeek,
  required String updatedAt,
}) {
  final dateKey = _dateKey(date);
  final weekIndex = _resolveCourseWidgetWeekIndex(
    firstDay: firstDay,
    maxWeek: maxWeek,
    today: date,
  );
  final todayCourses = _sortedCoursesForDate(courseData, dateKey);
  final tomorrow = date.add(const Duration(days: 1));
  final tomorrowCourses = _sortedCoursesForDate(courseData, _dateKey(tomorrow));

  if (todayCourses.isNotEmpty) {
    return CourseWidgetPayload(
      date: dateKey,
      weekdayLabel: _weekdayLabel(date.weekday),
      weekIndex: weekIndex,
      status: 'today_courses',
      headerTitle: '今天课程',
      headerSubtitle: _composeWeekSubtitle(date: date, weekIndex: weekIndex),
      emptyText: '今日暂无课程',
      isEmpty: false,
      updatedAt: updatedAt,
      courses:
          todayCourses
              .take(2)
              .map(
                (course) =>
                    _buildDisplayEntry(course, includeDatePrefix: false),
              )
              .toList(),
    );
  }

  if (date.weekday == DateTime.sunday && tomorrowCourses.isNotEmpty) {
    final mondayWeekIndex = _resolveCourseWidgetWeekIndex(
      firstDay: firstDay,
      maxWeek: maxWeek,
      today: tomorrow,
    );
    return CourseWidgetPayload(
      date: dateKey,
      weekdayLabel: _weekdayLabel(date.weekday),
      weekIndex: weekIndex,
      status: 'next_monday',
      headerTitle: '周一有课',
      headerSubtitle: mondayWeekIndex > 0 ? '下周第$mondayWeekIndex周' : '明天上午别睡过',
      emptyText: '周一有课',
      isEmpty: false,
      updatedAt: updatedAt,
      courses:
          tomorrowCourses
              .take(2)
              .map(
                (course) =>
                    _buildDisplayEntry(course, includeDatePrefix: false),
              )
              .toList(),
    );
  }

  if (tomorrowCourses.isNotEmpty) {
    final tomorrowWeekIndex = _resolveCourseWidgetWeekIndex(
      firstDay: firstDay,
      maxWeek: maxWeek,
      today: tomorrow,
    );
    return CourseWidgetPayload(
      date: dateKey,
      weekdayLabel: _weekdayLabel(date.weekday),
      weekIndex: weekIndex,
      status: 'tomorrow_courses',
      headerTitle: '明天有课',
      headerSubtitle: _composeWeekSubtitle(
        date: tomorrow,
        weekIndex: tomorrowWeekIndex,
      ),
      emptyText: '明天有课',
      isEmpty: false,
      updatedAt: updatedAt,
      courses:
          tomorrowCourses
              .take(2)
              .map(
                (course) =>
                    _buildDisplayEntry(course, includeDatePrefix: false),
              )
              .toList(),
    );
  }

  final nextCourseDate = _findNextCourseDateAfter(date, courseData);
  if (nextCourseDate != null) {
    final nextCourses = _sortedCoursesForDate(
      courseData,
      _dateKey(nextCourseDate),
    );
    final nextWeekIndex = _resolveCourseWidgetWeekIndex(
      firstDay: firstDay,
      maxWeek: maxWeek,
      today: nextCourseDate,
    );
    final sameWeek = _startOfMonday(nextCourseDate) == _startOfMonday(date);
    return CourseWidgetPayload(
      date: dateKey,
      weekdayLabel: _weekdayLabel(date.weekday),
      weekIndex: weekIndex,
      status: 'next_course',
      headerTitle: '下次课程',
      headerSubtitle:
          sameWeek
              ? _composeWeekSubtitle(
                date: nextCourseDate,
                weekIndex: nextWeekIndex,
              )
              : _composeWeekSubtitle(
                date: nextCourseDate,
                weekIndex: nextWeekIndex,
                prefix: '本周无课',
              ),
      emptyText: '下次课程',
      isEmpty: false,
      updatedAt: updatedAt,
      courses:
          nextCourses
              .take(2)
              .map(
                (course) => _buildDisplayEntry(
                  course,
                  includeDatePrefix: true,
                  date: nextCourseDate,
                ),
              )
              .toList(),
    );
  }

  return CourseWidgetPayload(
    date: dateKey,
    weekdayLabel: _weekdayLabel(date.weekday),
    weekIndex: weekIndex,
    status: 'empty',
    headerTitle: '当前暂无课表',
    headerSubtitle: '同步或导入后显示课程',
    emptyText: '同步或导入后显示课程',
    isEmpty: true,
    updatedAt: updatedAt,
    courses: const [],
  );
}

CourseWidgetStore buildCourseWidgetStoreFromRawData({
  required String firstDay,
  required int maxWeek,
  required String updatedAt,
  required Map<String, List<Course>> courseData,
}) {
  final normalizedUpdatedAt =
      updatedAt.isEmpty ? DateTime.now().toIso8601String() : updatedAt;
  final days = <String, CourseWidgetPayload>{};
  final dayCourses = <String, List<CourseWidgetCourseEntry>>{};

  final sortedActualDateKeys = courseData.keys.toList()..sort();
  for (final dateKey in sortedActualDateKeys) {
    final courses = _sortedCoursesForDate(courseData, dateKey);
    if (courses.isEmpty) {
      continue;
    }
    dayCourses[dateKey] =
        courses
            .map(
              (course) => _buildDisplayEntry(course, includeDatePrefix: false),
            )
            .toList();
  }

  final parsedFirstDay = DateTime.tryParse(firstDay);
  if (parsedFirstDay != null && maxWeek > 0) {
    final firstMonday = _startOfMonday(parsedFirstDay);
    for (var index = 0; index < maxWeek * 7; index++) {
      final date = firstMonday.add(Duration(days: index));
      final dateKey = _dateKey(date);
      days[dateKey] = _buildCourseWidgetPayloadForDate(
        date: date,
        courseData: courseData,
        firstDay: firstDay,
        maxWeek: maxWeek,
        updatedAt: normalizedUpdatedAt,
      );
    }
  } else {
    final sortedDateKeys = courseData.keys.toList()..sort();
    for (final dateKey in sortedDateKeys) {
      final parsedDate = DateTime.tryParse(dateKey);
      if (parsedDate == null) {
        continue;
      }
      days[dateKey] = _buildCourseWidgetPayloadForDate(
        date: parsedDate,
        courseData: courseData,
        firstDay: firstDay,
        maxWeek: maxWeek,
        updatedAt: normalizedUpdatedAt,
      );
    }
  }

  return CourseWidgetStore(
    schemaVersion: _courseWidgetStoreSchemaVersion,
    updatedAt: normalizedUpdatedAt,
    days: days,
    dayCourses: dayCourses,
  );
}

CourseWidgetStore buildCourseWidgetStore(SavedCourseSchedule? schedule) {
  if (schedule == null) {
    return CourseWidgetStore(
      schemaVersion: _courseWidgetStoreSchemaVersion,
      updatedAt: DateTime.now().toIso8601String(),
      days: const <String, CourseWidgetPayload>{},
      dayCourses: const <String, List<CourseWidgetCourseEntry>>{},
    );
  }

  return buildCourseWidgetStoreFromRawData(
    firstDay: schedule.firstDay,
    maxWeek: schedule.maxWeek,
    updatedAt: schedule.updatedAt,
    courseData: schedule.courseData,
  );
}

String _findFirstCourseDate(Map<String, List<Course>> courseData) {
  if (courseData.isEmpty) {
    return '';
  }

  final dates = courseData.keys.toList()..sort();
  return dates.first;
}

Future<Directory> _ensureCourseWidgetDirectory() async {
  final appDocumentsDir = await getApplicationDocumentsDirectory();
  final flutterDir = Directory('${appDocumentsDir.path}/app_flutter');
  if (!flutterDir.existsSync()) {
    flutterDir.createSync(recursive: true);
  }
  return flutterDir;
}

Future<File> _courseArchiveFile() async {
  final appDocumentsDir = await getApplicationDocumentsDirectory();
  return File('${appDocumentsDir.path}/$_courseScheduleArchiveFileName');
}

Future<File> _legacyCourseCacheFile() async {
  final appDocumentsDir = await getApplicationDocumentsDirectory();
  return File('${appDocumentsDir.path}/$_legacyCourseDataFileName');
}

Future<File> _courseWidgetPayloadCacheFile() async {
  final appDocumentsDir = await getApplicationDocumentsDirectory();
  return File('${appDocumentsDir.path}/$_courseWidgetPayloadFileName');
}

Future<File> _courseWidgetStoreCacheFile() async {
  final appDocumentsDir = await getApplicationDocumentsDirectory();
  return File('${appDocumentsDir.path}/$_courseWidgetStoreFileName');
}

DateTime? _tryParseIsoTime(String value) {
  if (value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String _normalizeCourseAccountId(String value) {
  return value.trim().toLowerCase();
}

Future<String> _readCurrentCourseAccountId() async {
  final storage = AppAuthStorage.instance;
  final jwxtUsername = _normalizeCourseAccountId(
    await storage.readJwxtUsername(),
  );
  if (jwxtUsername.isNotEmpty) {
    return jwxtUsername;
  }

  return _normalizeCourseAccountId(await storage.readHutUsername());
}

Future<void> _markCourseSilentRefreshAttempt({
  required String accountId,
  required DateTime attemptedAt,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _courseSilentRefreshAttemptAtKey,
    attemptedAt.toIso8601String(),
  );
  await prefs.setString(_courseSilentRefreshAttemptAccountKey, accountId);
}

Future<void> _clearCourseSilentRefreshAttempt() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_courseSilentRefreshAttemptAtKey);
  await prefs.remove(_courseSilentRefreshAttemptAccountKey);
}

Future<CourseSilentRefreshPlan> buildCourseSilentRefreshPlan({
  DateTime? now,
  Duration staleAfter = const Duration(hours: 6),
  Duration attemptCooldown = const Duration(minutes: 30),
}) async {
  final currentTime = now ?? DateTime.now();
  final storage = AppAuthStorage.instance;
  final accountId = await _readCurrentCourseAccountId();
  if (!(await storage.hasAnyCampusSession()) || accountId.isEmpty) {
    return CourseSilentRefreshPlan(
      shouldSync: false,
      shouldClearSyncedSchedules: false,
      reason: CourseSilentRefreshReason.noSession,
      accountId: accountId,
    );
  }

  final activeSchedule = await loadActiveCourseSchedule();
  if (activeSchedule == null) {
    return CourseSilentRefreshPlan(
      shouldSync: true,
      shouldClearSyncedSchedules: false,
      reason: CourseSilentRefreshReason.noActiveSchedule,
      accountId: accountId,
    );
  }

  if (activeSchedule.sourceType == CourseScheduleSourceType.manual ||
      activeSchedule.sourceType == CourseScheduleSourceType.shareImport) {
    return CourseSilentRefreshPlan(
      shouldSync: false,
      shouldClearSyncedSchedules: false,
      reason: CourseSilentRefreshReason.userManaged,
      accountId: accountId,
    );
  }

  if (activeSchedule.sourceType == CourseScheduleSourceType.selfSync &&
      activeSchedule.ownerAccount.isNotEmpty &&
      _normalizeCourseAccountId(activeSchedule.ownerAccount) != accountId) {
    return CourseSilentRefreshPlan(
      shouldSync: true,
      shouldClearSyncedSchedules: true,
      reason: CourseSilentRefreshReason.accountChanged,
      accountId: accountId,
    );
  }

  final prefs = await SharedPreferences.getInstance();
  final lastAttemptAt = _tryParseIsoTime(
    prefs.getString(_courseSilentRefreshAttemptAtKey) ?? '',
  );
  final lastAttemptAccount = _normalizeCourseAccountId(
    prefs.getString(_courseSilentRefreshAttemptAccountKey) ?? '',
  );
  if (lastAttemptAt != null &&
      lastAttemptAccount == accountId &&
      currentTime.difference(lastAttemptAt) < attemptCooldown) {
    return CourseSilentRefreshPlan(
      shouldSync: false,
      shouldClearSyncedSchedules: false,
      reason: CourseSilentRefreshReason.cooldown,
      accountId: accountId,
    );
  }

  if (activeSchedule.sourceType == CourseScheduleSourceType.migratedLegacy) {
    return CourseSilentRefreshPlan(
      shouldSync: true,
      shouldClearSyncedSchedules: false,
      reason: CourseSilentRefreshReason.migratedLegacy,
      accountId: accountId,
    );
  }

  if (activeSchedule.ownerAccount.isEmpty) {
    return CourseSilentRefreshPlan(
      shouldSync: true,
      shouldClearSyncedSchedules: false,
      reason: CourseSilentRefreshReason.missingOwnerAccount,
      accountId: accountId,
    );
  }

  final updatedAt = _tryParseIsoTime(activeSchedule.updatedAt);
  if (updatedAt == null || currentTime.difference(updatedAt) >= staleAfter) {
    return CourseSilentRefreshPlan(
      shouldSync: true,
      shouldClearSyncedSchedules: false,
      reason: CourseSilentRefreshReason.staleSchedule,
      accountId: accountId,
    );
  }

  return CourseSilentRefreshPlan(
    shouldSync: false,
    shouldClearSyncedSchedules: false,
    reason: CourseSilentRefreshReason.cacheFresh,
    accountId: accountId,
  );
}

Future<String> _renewCourseSyncTokenSilently() async {
  final storage = AppAuthStorage.instance;
  final username = await storage.readJwxtUsername();
  final password = await storage.readJwxtPassword();
  if (username.isEmpty || password.isEmpty) {
    return '';
  }

  final loginSuccess = await loginHut(username, password);
  if (!loginSuccess) {
    return '';
  }
  return storage.readJwxtToken();
}

int _compareScheduleTimestamp(
  SavedCourseSchedule left,
  SavedCourseSchedule right,
) {
  final leftTime = _tryParseIsoTime(left.updatedAt);
  final rightTime = _tryParseIsoTime(right.updatedAt);
  if (leftTime == null && rightTime == null) {
    return right.name.compareTo(left.name);
  }
  if (leftTime == null) {
    return 1;
  }
  if (rightTime == null) {
    return -1;
  }
  return rightTime.compareTo(leftTime);
}

List<SavedCourseSchedule> _sortSchedulesForArchive(
  List<SavedCourseSchedule> schedules,
  String activeScheduleId,
) {
  final sorted = [...schedules];
  sorted.sort((left, right) {
    final leftActive = left.id == activeScheduleId;
    final rightActive = right.id == activeScheduleId;
    if (leftActive != rightActive) {
      return leftActive ? -1 : 1;
    }
    return _compareScheduleTimestamp(left, right);
  });
  return sorted;
}

SavedCourseSchedule? _resolveArchiveActiveSchedule(
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

Future<void> _writeLegacyCourseDataCache(
  Map<String, List<Course>> courseData,
) async {
  final jsonString = jsonEncode(_encodeCourseDataMap(courseData));
  final file = await _legacyCourseCacheFile();
  await file.writeAsString(jsonString);

  final flutterDir = await _ensureCourseWidgetDirectory();
  final widgetFile = File('${flutterDir.path}/$_legacyCourseDataFileName');
  await widgetFile.writeAsString(jsonString);
}

Future<String> _writeCourseWidgetStore(CourseWidgetStore store) async {
  final storeJson = jsonEncode(store.toJson());
  final file = await _courseWidgetStoreCacheFile();
  await file.writeAsString(storeJson);

  final flutterDir = await _ensureCourseWidgetDirectory();
  final widgetFile = File('${flutterDir.path}/$_courseWidgetStoreFileName');
  await widgetFile.writeAsString(storeJson);
  return storeJson;
}

Future<String> _writeCompactCourseWidgetPayload(
  CourseWidgetPayload payload,
) async {
  final payloadJson = jsonEncode(payload.toJson());
  final file = await _courseWidgetPayloadCacheFile();
  await file.writeAsString(payloadJson);

  final flutterDir = await _ensureCourseWidgetDirectory();
  final widgetFile = File('${flutterDir.path}/$_courseWidgetPayloadFileName');
  await widgetFile.writeAsString(payloadJson);
  return payloadJson;
}

Future<void> _persistCourseScheduleArchive(
  CourseScheduleArchive archive, {
  bool refreshWidget = true,
}) async {
  final archiveFile = await _courseArchiveFile();
  await archiveFile.writeAsString(jsonEncode(archive.toJson()));

  final activeSchedule = _resolveArchiveActiveSchedule(archive);
  await _writeLegacyCourseDataCache(
    activeSchedule?.courseData ?? const <String, List<Course>>{},
  );

  final widgetStore = buildCourseWidgetStore(activeSchedule);
  final storeJson = await _writeCourseWidgetStore(widgetStore);
  final widgetPayload = buildCompactCourseWidgetPayload(activeSchedule);
  final payloadJson = await _writeCompactCourseWidgetPayload(widgetPayload);
  if (refreshWidget) {
    await WidgetRefreshService.syncCourseTableWidget(
      payloadJson: payloadJson,
      storeJson: storeJson,
    );
  }
}

Future<void> syncActiveCourseWidgetState() async {
  final activeSchedule = await loadActiveCourseSchedule();
  final widgetStore = buildCourseWidgetStore(activeSchedule);
  final storeJson = await _writeCourseWidgetStore(widgetStore);
  final widgetPayload = buildCompactCourseWidgetPayload(activeSchedule);
  final payloadJson = await _writeCompactCourseWidgetPayload(widgetPayload);
  await WidgetRefreshService.syncCourseTableWidget(
    payloadJson: payloadJson,
    storeJson: storeJson,
  );
}

Future<CourseSyncResult> ensureCourseScheduleFreshness({
  DateTime? now,
  Duration staleAfter = const Duration(hours: 6),
  Duration attemptCooldown = const Duration(minutes: 30),
}) async {
  final currentTime = now ?? DateTime.now();
  final plan = await buildCourseSilentRefreshPlan(
    now: currentTime,
    staleAfter: staleAfter,
    attemptCooldown: attemptCooldown,
  );
  if (!plan.shouldSync) {
    return CourseSyncResult.success(plan.reason);
  }

  await _markCourseSilentRefreshAttempt(
    accountId: plan.accountId,
    attemptedAt: currentTime,
  );

  if (plan.shouldClearSyncedSchedules) {
    await clearCourseSchedules(
      sourceTypes: {
        CourseScheduleSourceType.selfSync,
        CourseScheduleSourceType.migratedLegacy,
      },
    );
  }

  final storage = AppAuthStorage.instance;
  final cachedToken = await storage.readJwxtToken();
  if (cachedToken.isNotEmpty) {
    final cachedResult = await saveClassToLocal(cachedToken);
    if (cachedResult.success) {
      await _clearCourseSilentRefreshAttempt();
      return cachedResult;
    }
  }

  final renewedToken = await _renewCourseSyncTokenSilently();
  if (renewedToken.isEmpty) {
    return const CourseSyncResult.failure('当前登录态无法静默刷新课表');
  }

  final result = await saveClassToLocal(renewedToken);
  if (result.success) {
    await _clearCourseSilentRefreshAttempt();
  }
  return result;
}

Future<SavedCourseSchedule?> _migrateLegacyCourseCacheIfNeeded() async {
  final legacyFile = await _legacyCourseCacheFile();
  if (!legacyFile.existsSync()) {
    return null;
  }

  final legacyCourseData = await readCourseDataFromJson(legacyFile.path);
  if (legacyCourseData.isEmpty) {
    return null;
  }

  final prefs = await SharedPreferences.getInstance();
  final ownerName = prefs.getString('name') ?? '';
  final ownerAccount = await _readCurrentCourseAccountId();
  final firstDay =
      prefs.getString('firstDay') ?? _findFirstCourseDate(legacyCourseData);
  final maxWeek = prefs.getInt('maxWeek') ?? 20;
  final now = DateTime.now().toIso8601String();
  final termLabel = firstDay.isEmpty ? '本地课表' : '$firstDay 开始';
  final name = ownerName.isEmpty ? '本地课表' : '$ownerName的课表';

  return SavedCourseSchedule(
    id: _uuid.v4(),
    name: name,
    ownerName: ownerName,
    ownerAccount: ownerAccount,
    termLabel: termLabel,
    semesterId: '',
    firstDay: firstDay,
    maxWeek: maxWeek,
    sourceType: CourseScheduleSourceType.migratedLegacy,
    isReadOnly: false,
    createdAt: now,
    updatedAt: now,
    courseData: legacyCourseData,
  );
}

Future<CourseScheduleArchive> loadCourseScheduleArchive() async {
  final archiveFile = await _courseArchiveFile();
  if (archiveFile.existsSync()) {
    try {
      final archiveJson =
          jsonDecode(await archiveFile.readAsString()) as Map<String, dynamic>;
      final archive = CourseScheduleArchive.fromJson(archiveJson);
      if (archive.schedules.isNotEmpty) {
        final activeId =
            archive.schedules.any((item) => item.id == archive.activeScheduleId)
                ? archive.activeScheduleId
                : archive.schedules.first.id;
        final sortedSchedules = _sortSchedulesForArchive(
          archive.schedules,
          activeId,
        );
        return archive.copyWith(
          activeScheduleId: activeId,
          schedules: sortedSchedules,
        );
      }
      return archive;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Error reading course schedule archive',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  final migratedSchedule = await _migrateLegacyCourseCacheIfNeeded();
  if (migratedSchedule == null) {
    return const CourseScheduleArchive.empty();
  }

  final migratedArchive = CourseScheduleArchive(
    schemaVersion: _courseScheduleArchiveSchemaVersion,
    activeScheduleId: migratedSchedule.id,
    schedules: [migratedSchedule],
  );
  await _persistCourseScheduleArchive(migratedArchive, refreshWidget: false);
  return migratedArchive;
}

Future<List<SavedCourseSchedule>> loadSavedCourseSchedules() async {
  final archive = await loadCourseScheduleArchive();
  return _sortSchedulesForArchive(archive.schedules, archive.activeScheduleId);
}

Future<SavedCourseSchedule?> loadActiveCourseSchedule() async {
  final archive = await loadCourseScheduleArchive();
  return _resolveArchiveActiveSchedule(archive);
}

Future<void> saveCourseSchedule(
  SavedCourseSchedule schedule, {
  bool setActive = true,
  bool refreshWidget = true,
}) async {
  final archive = await loadCourseScheduleArchive();
  final normalizedSchedule =
      schedule.id.isEmpty ? schedule.copyWith(id: _uuid.v4()) : schedule;

  final schedules = [...archive.schedules];
  final existingIndex = schedules.indexWhere(
    (item) => item.id == normalizedSchedule.id,
  );
  if (existingIndex >= 0) {
    schedules[existingIndex] = normalizedSchedule;
  } else {
    schedules.add(normalizedSchedule);
  }

  final activeScheduleId =
      setActive
          ? normalizedSchedule.id
          : archive.activeScheduleId.isNotEmpty
          ? archive.activeScheduleId
          : normalizedSchedule.id;
  final sortedSchedules = _sortSchedulesForArchive(schedules, activeScheduleId);

  await _persistCourseScheduleArchive(
    CourseScheduleArchive(
      schemaVersion: _courseScheduleArchiveSchemaVersion,
      activeScheduleId: activeScheduleId,
      schedules: sortedSchedules,
    ),
    refreshWidget: refreshWidget,
  );
}

Future<void> renameCourseSchedule(String scheduleId, String newName) async {
  final normalizedName = newName.trim();
  if (normalizedName.isEmpty) {
    throw StateError('课表名称不能为空');
  }

  final archive = await loadCourseScheduleArchive();
  final scheduleIndex = archive.schedules.indexWhere(
    (schedule) => schedule.id == scheduleId,
  );
  if (scheduleIndex < 0) {
    throw StateError('未找到要重命名的课表');
  }

  final updatedSchedule = archive.schedules[scheduleIndex].copyWith(
    name: normalizedName,
    updatedAt: DateTime.now().toIso8601String(),
  );
  await saveCourseSchedule(
    updatedSchedule,
    setActive: archive.activeScheduleId == scheduleId,
  );
}

Future<void> setActiveCourseSchedule(String scheduleId) async {
  final archive = await loadCourseScheduleArchive();
  if (!archive.schedules.any((schedule) => schedule.id == scheduleId)) {
    throw StateError('未找到要切换的课表');
  }

  await _persistCourseScheduleArchive(
    CourseScheduleArchive(
      schemaVersion: archive.schemaVersion,
      activeScheduleId: scheduleId,
      schedules: _sortSchedulesForArchive(archive.schedules, scheduleId),
    ),
  );
}

Future<bool> deleteCourseSchedule(String scheduleId) async {
  final archive = await loadCourseScheduleArchive();
  final remainingSchedules =
      archive.schedules.where((schedule) => schedule.id != scheduleId).toList();
  if (remainingSchedules.length == archive.schedules.length) {
    return false;
  }

  final nextActiveId =
      remainingSchedules.any(
            (schedule) => schedule.id == archive.activeScheduleId,
          )
          ? archive.activeScheduleId
          : remainingSchedules.isEmpty
          ? ''
          : remainingSchedules.first.id;

  await _persistCourseScheduleArchive(
    CourseScheduleArchive(
      schemaVersion: archive.schemaVersion,
      activeScheduleId: nextActiveId,
      schedules: _sortSchedulesForArchive(remainingSchedules, nextActiveId),
    ),
  );
  return true;
}

Future<void> clearCourseSchedules({
  Set<String>? sourceTypes,
  bool refreshWidget = true,
}) async {
  final archive = await loadCourseScheduleArchive();
  final retainedSchedules =
      sourceTypes == null
          ? <SavedCourseSchedule>[]
          : archive.schedules
              .where((schedule) => !sourceTypes.contains(schedule.sourceType))
              .toList();

  final nextActiveId =
      retainedSchedules.any(
            (schedule) => schedule.id == archive.activeScheduleId,
          )
          ? archive.activeScheduleId
          : retainedSchedules.isEmpty
          ? ''
          : retainedSchedules.first.id;

  await _persistCourseScheduleArchive(
    CourseScheduleArchive(
      schemaVersion: archive.schemaVersion,
      activeScheduleId: nextActiveId,
      schedules: _sortSchedulesForArchive(retainedSchedules, nextActiveId),
    ),
    refreshWidget: refreshWidget,
  );
}

Map<String, dynamic> _buildCourseScheduleTransferPayload({
  required SavedCourseSchedule schedule,
  required int schemaVersion,
  required String type,
}) {
  return {
    'schemaVersion': schemaVersion,
    'type': type,
    'exportedAt': DateTime.now().toIso8601String(),
    'schedule': schedule.toShareJson(),
  };
}

SavedCourseSchedule _parseImportedSchedulePayload(
  Map<String, dynamic> payloadJson, {
  required Set<String> acceptedTypes,
}) {
  final payloadType = _stringValue(payloadJson['type']);
  if (!acceptedTypes.contains(payloadType)) {
    throw const FormatException('分享内容类型不匹配');
  }

  final rawSchedule = Map<String, dynamic>.from(
    payloadJson['schedule'] as Map? ?? const <String, dynamic>{},
  );
  final now = DateTime.now().toIso8601String();
  final imported = SavedCourseSchedule.fromJson({
    'id': _uuid.v4(),
    'name':
        _stringValue(rawSchedule['name']).isEmpty
            ? '分享课表'
            : rawSchedule['name'],
    'ownerName': _stringValue(rawSchedule['ownerName']),
    'termLabel': _stringValue(rawSchedule['termLabel']),
    'semesterId': _stringValue(rawSchedule['semesterId']),
    'firstDay': _stringValue(rawSchedule['firstDay']),
    'maxWeek': _intValue(rawSchedule['maxWeek'], fallback: 20),
    'sourceType': CourseScheduleSourceType.shareImport,
    'isReadOnly': true,
    'createdAt': now,
    'updatedAt': now,
    'courseData': rawSchedule['courseData'],
  });

  if (imported.courseData.isEmpty) {
    throw const FormatException('分享内容里没有可导入的课表数据');
  }
  return imported;
}

String buildCourseScheduleShareCode(SavedCourseSchedule schedule) {
  final payload = _buildCourseScheduleTransferPayload(
    schedule: schedule,
    schemaVersion: _courseScheduleShareSchemaVersion,
    type: _courseScheduleSharePayloadType,
  );
  final compressed = gzip.encode(utf8.encode(jsonEncode(payload)));
  return '$_courseSharePrefix${base64Url.encode(compressed)}';
}

String _normalizeCourseShareCode(String rawCode) {
  final compact = rawCode.replaceAll(RegExp(r'\s+'), '');
  final prefixIndex = compact.indexOf(_courseSharePrefix);
  if (prefixIndex < 0) {
    throw const FormatException('未识别到工大盒子课表分享码');
  }
  return compact.substring(prefixIndex + _courseSharePrefix.length);
}

String _normalizeBase64Payload(String encoded) {
  final remainder = encoded.length % 4;
  if (remainder == 0) {
    return encoded;
  }
  return encoded.padRight(encoded.length + 4 - remainder, '=');
}

SavedCourseSchedule parseCourseScheduleShareCode(String rawCode) {
  try {
    final encodedPayload = _normalizeCourseShareCode(rawCode);
    final rawBytes = base64Url.decode(_normalizeBase64Payload(encodedPayload));
    final payloadString = utf8.decode(gzip.decode(rawBytes));
    final payloadJson = jsonDecode(payloadString) as Map<String, dynamic>;
    return _parseImportedSchedulePayload(
      payloadJson,
      acceptedTypes: {_courseScheduleSharePayloadType},
    );
  } on FormatException {
    rethrow;
  } catch (error) {
    throw FormatException('分享码解析失败：$error');
  }
}

String buildCourseScheduleExportJsonString(SavedCourseSchedule schedule) {
  final payload = _buildCourseScheduleTransferPayload(
    schedule: schedule,
    schemaVersion: _courseScheduleFileSchemaVersion,
    type: _courseScheduleFilePayloadType,
  );
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(payload);
}

SavedCourseSchedule parseCourseScheduleExportJsonString(String rawJson) {
  try {
    final payloadJson = jsonDecode(rawJson) as Map<String, dynamic>;
    return _parseImportedSchedulePayload(
      payloadJson,
      acceptedTypes: {
        _courseScheduleFilePayloadType,
        _courseScheduleSharePayloadType,
      },
    );
  } on FormatException {
    rethrow;
  } catch (error) {
    throw FormatException('课表文件解析失败：$error');
  }
}

Future<SavedCourseSchedule> saveImportedCourseScheduleFromShareCode(
  String rawCode,
) async {
  final importedSchedule = parseCourseScheduleShareCode(rawCode);
  await saveCourseSchedule(importedSchedule, setActive: true);
  return importedSchedule;
}

Future<SavedCourseSchedule> saveImportedCourseScheduleFromFileContent(
  String rawJson,
) async {
  final importedSchedule = parseCourseScheduleExportJsonString(rawJson);
  await saveCourseSchedule(importedSchedule, setActive: true);
  return importedSchedule;
}

Future<void> saveCourseDataToJson(Map<String, List<Course>> courseData) async {
  final archive = await loadCourseScheduleArchive();
  final activeSchedule = _resolveArchiveActiveSchedule(archive);
  final prefs = await SharedPreferences.getInstance();
  final currentAccountId = await _readCurrentCourseAccountId();
  final ownerName =
      activeSchedule?.ownerName ?? (prefs.getString('name') ?? '');
  final firstDay =
      _findFirstCourseDate(courseData).isNotEmpty
          ? _findFirstCourseDate(courseData)
          : activeSchedule?.firstDay ?? (prefs.getString('firstDay') ?? '');
  final maxWeek = activeSchedule?.maxWeek ?? (prefs.getInt('maxWeek') ?? 20);
  final now = DateTime.now().toIso8601String();

  final schedule =
      activeSchedule?.copyWith(
        ownerAccount:
            activeSchedule.ownerAccount.isNotEmpty
                ? activeSchedule.ownerAccount
                : currentAccountId,
        firstDay: firstDay,
        maxWeek: maxWeek,
        updatedAt: now,
        courseData: courseData,
      ) ??
      SavedCourseSchedule(
        id: _uuid.v4(),
        name: ownerName.isEmpty ? '本地课表' : '$ownerName的课表',
        ownerName: ownerName,
        ownerAccount: currentAccountId,
        termLabel: firstDay.isEmpty ? '本地课表' : '$firstDay 开始',
        semesterId: '',
        firstDay: firstDay,
        maxWeek: maxWeek,
        sourceType: CourseScheduleSourceType.manual,
        isReadOnly: false,
        createdAt: now,
        updatedAt: now,
        courseData: courseData,
      );

  await saveCourseSchedule(schedule, setActive: true);
}

Future<bool> deleteCourseFromActiveSchedule({
  required String dateKey,
  required Course targetCourse,
  CourseDeleteScope scope = CourseDeleteScope.currentOccurrence,
}) async {
  final activeSchedule = await loadActiveCourseSchedule();
  if (activeSchedule == null || activeSchedule.isReadOnly) {
    return false;
  }

  final updatedCourseData = <String, List<Course>>{};
  activeSchedule.courseData.forEach((key, courses) {
    updatedCourseData[key] = List<Course>.from(courses);
  });

  final coursesForDate = updatedCourseData[dateKey];
  if (coursesForDate == null || coursesForDate.isEmpty) {
    return false;
  }

  switch (scope) {
    case CourseDeleteScope.currentOccurrence:
      final targetIndex = coursesForDate.indexWhere(
        (course) => _isSameCourse(course, targetCourse),
      );
      if (targetIndex < 0) {
        return false;
      }

      coursesForDate.removeAt(targetIndex);
      if (coursesForDate.isEmpty) {
        updatedCourseData.remove(dateKey);
      }
      break;
    case CourseDeleteScope.wholeSchedule:
      var removedAny = false;
      final keys = updatedCourseData.keys.toList(growable: false);
      for (final key in keys) {
        final sourceCourses = updatedCourseData[key];
        if (sourceCourses == null || sourceCourses.isEmpty) {
          continue;
        }
        final filteredCourses =
            sourceCourses
                .where(
                  (course) => !_isSameWholeScheduleCourse(course, targetCourse),
                )
                .toList();
        if (filteredCourses.length != sourceCourses.length) {
          removedAny = true;
        }
        if (filteredCourses.isEmpty) {
          updatedCourseData.remove(key);
        } else {
          updatedCourseData[key] = filteredCourses;
        }
      }
      if (!removedAny) {
        return false;
      }
      break;
  }

  await saveCourseSchedule(
    activeSchedule.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
      courseData: updatedCourseData,
    ),
    setActive: true,
  );
  return true;
}

// 从 JSON 文件读取并转换为 Map<String, List<Course>>
Future<Map<String, List<Course>>> readCourseDataFromJson(
  String filePath,
) async {
  // 读取 JSON 文件内容
  final file = File(filePath);
  String jsonString = await file.readAsString();

  // 解析 JSON 字符串为 Map<String, dynamic>
  Map<String, dynamic> jsonData = jsonDecode(jsonString);

  // 将 Map<String, dynamic> 转换为 Map<String, List<Course>>
  Map<String, List<Course>> courseData = {};
  jsonData.forEach((key, coursesJson) {
    List<Course> courses =
        (coursesJson as List).map((courseJson) {
          return Course.fromJson(courseJson);
        }).toList();
    courseData[key] = courses;
  });

  return courseData;
}

Future<Map<String, List<Course>>> loadClassFromLocal() async {
  try {
    final activeSchedule = await loadActiveCourseSchedule();
    if (activeSchedule != null) {
      return activeSchedule.courseData;
    }

    final legacyFile = await _legacyCourseCacheFile();
    if (!legacyFile.existsSync()) {
      return {};
    }
    return await readCourseDataFromJson(legacyFile.path);
  } catch (error, stackTrace) {
    AppLogger.error(
      'Error reading course JSON file',
      error: error,
      stackTrace: stackTrace,
    );
    return {};
  }
}

Future<CourseWidgetPayload?> loadCourseWidgetPayloadFromLocal() async {
  try {
    final payloadFile = await _courseWidgetPayloadCacheFile();
    if (!payloadFile.existsSync()) {
      return null;
    }
    final payloadJson =
        jsonDecode(await payloadFile.readAsString()) as Map<String, dynamic>;
    return CourseWidgetPayload.fromJson(payloadJson);
  } catch (error, stackTrace) {
    AppLogger.error(
      'Error reading compact course widget payload',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<CourseWidgetStore?> loadCourseWidgetStoreFromLocal() async {
  try {
    final storeFile = await _courseWidgetStoreCacheFile();
    if (!storeFile.existsSync()) {
      return null;
    }
    final storeJson =
        jsonDecode(await storeFile.readAsString()) as Map<String, dynamic>;
    return CourseWidgetStore.fromJson(storeJson);
  } catch (error, stackTrace) {
    AppLogger.error(
      'Error reading course widget store',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

String _weekdayLabel(int weekday) {
  const labels = <int, String>{
    DateTime.monday: '周一',
    DateTime.tuesday: '周二',
    DateTime.wednesday: '周三',
    DateTime.thursday: '周四',
    DateTime.friday: '周五',
    DateTime.saturday: '周六',
    DateTime.sunday: '周日',
  };
  return labels[weekday] ?? '';
}

String _sectionStartTime(int startSection) {
  return _courseSectionStartTimes[startSection] ?? '--:--';
}

String _sectionEndTime(int endSection) {
  return _courseSectionEndTimes[endSection] ?? '';
}

Future<CourseSyncResult> saveClassToLocal(
  String token, {
  BuildContext? context,
  CourseSyncProgressCallback? onProgress,
}) async {
  if (token.isEmpty) {
    return const CourseSyncResult.failure('登录信息已失效，请重新登录后再试');
  }

  if (context != null && !context.mounted) {
    return const CourseSyncResult.failure('课表加载已取消');
  }

  try {
    final snapshot = await loadCourseSyncSnapshotFromUrl(
      token,
      context: context,
      onProgress: onProgress,
    );
    if (snapshot.courseData.isEmpty) {
      return const CourseSyncResult.failure('未获取到任何课表数据，请确认当前学期已有课表');
    }

    final totalUnits = snapshot.maxWeek > 0 ? 1 + snapshot.maxWeek * 2 + 1 : 42;
    onProgress?.call(
      CourseSyncProgress(
        phase: CourseSyncPhase.saving,
        completedUnits: totalUnits - 1,
        totalUnits: totalUnits,
        message: '正在保存课表',
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    final ownerName = prefs.getString('name') ?? '';
    final ownerAccount = await _readCurrentCourseAccountId();
    final archive = await loadCourseScheduleArchive();
    SavedCourseSchedule? matchedSchedule;
    for (final schedule in archive.schedules) {
      final sameSelfSync =
          schedule.sourceType == CourseScheduleSourceType.selfSync;
      final sameSemester =
          snapshot.semesterId.isNotEmpty &&
          schedule.semesterId == snapshot.semesterId;
      if (sameSelfSync && (sameSemester || matchedSchedule == null)) {
        matchedSchedule = schedule;
        if (sameSemester) {
          break;
        }
      }
    }

    final now = DateTime.now().toIso8601String();
    final scheduleName = ownerName.isEmpty ? '我的课表' : '$ownerName的课表';
    final termLabel =
        snapshot.semesterId.isNotEmpty
            ? snapshot.semesterId
            : snapshot.firstDay.isEmpty
            ? '当前课表'
            : '${snapshot.firstDay} 开始';
    final savedSchedule =
        matchedSchedule?.copyWith(
          name:
              matchedSchedule.name.isEmpty
                  ? scheduleName
                  : matchedSchedule.name,
          ownerName: ownerName,
          ownerAccount: ownerAccount,
          termLabel: termLabel,
          semesterId: snapshot.semesterId,
          firstDay: snapshot.firstDay,
          maxWeek: snapshot.maxWeek,
          sourceType: CourseScheduleSourceType.selfSync,
          isReadOnly: false,
          updatedAt: now,
          courseData: snapshot.courseData,
        ) ??
        SavedCourseSchedule(
          id: _uuid.v4(),
          name: scheduleName,
          ownerName: ownerName,
          ownerAccount: ownerAccount,
          termLabel: termLabel,
          semesterId: snapshot.semesterId,
          firstDay: snapshot.firstDay,
          maxWeek: snapshot.maxWeek,
          sourceType: CourseScheduleSourceType.selfSync,
          isReadOnly: false,
          createdAt: now,
          updatedAt: now,
          courseData: snapshot.courseData,
        );

    await saveCourseSchedule(savedSchedule, setActive: true);
    onProgress?.call(
      CourseSyncProgress(
        phase: CourseSyncPhase.saving,
        completedUnits: totalUnits,
        totalUnits: totalUnits,
        message: '课表同步完成',
      ),
    );
    return CourseSyncResult.success(
      '课表同步完成，共更新 ${snapshot.courseData.length} 天的数据',
    );
  } on StateError catch (error, stackTrace) {
    AppLogger.error(
      'Course sync failed with state error',
      error: error,
      stackTrace: stackTrace,
    );
    return CourseSyncResult.failure(error.message.toString());
  } catch (error, stackTrace) {
    return _buildCourseSyncFailure(error, stackTrace);
  }
}

Future<Map<String, List<Course>>> testc() async {
  String jsonString =
      '{"Msg":"success~","code":"1","data":[{"date":[{"xqmc":"一","mxrq":"2025-03-03","zc":"all","xqid":1},{"xqmc":"二","mxrq":"2025-03-04","zc":"all","xqid":2},{"xqmc":"三","mxrq":"2025-03-05","zc":"all","xqid":3},{"xqmc":"四","mxrq":"2025-03-06","zc":"all","xqid":4},{"xqmc":"五","mxrq":"2025-03-07","zc":"all","xqid":5},{"xqmc":"六","mxrq":"2025-03-08","zc":"all","xqid":6},{"xqmc":"日","mxrq":"2025-03-09","zc":"all","xqid":7}],"item":[{"classWeek":"3-10,12-15","teacherName":"彭永群","buttonCode":"0","ktmc":"包装设计[2303-2304]班,数媒艺术2302班,3D打印2301班,艺术设计学[2301-2302]班,包装工程[2301-2306]班,播音主持2301班","classTime":"10304","jx0408id":"5B41D8B32D0449C5964518E4A4675613","kch":"30110080","courseName":"体育4","isRepeatCode":"0","maxClassTime":"第二大节","startTime":"10:00","endTIme":"11:40","location":"第二田径场-11","classWeekDetails":",3,4,5,6,7,8,9,10,12,13,14,15,","coursesNote":2},{"classWeek":"1-5,8-10,12-15","teacherName":"李慧源","buttonCode":"0","ktmc":"包装工程[2303-2304]班","classTime":"10506","jx0408id":"2260705AEE73489C8B310150613229A1","kch":"06110300","courseName":"通用学术英语A","isRepeatCode":"0","maxClassTime":"第三大节","startTime":"14:00","endTIme":"15:40","location":"公共304","classWeekDetails":",1,2,3,4,5,8,9,10,12,13,14,15,","coursesNote":2},{"classWeek":"3-10,12-15","teacherName":"何新快","buttonCode":"0","ktmc":"包装工程[2303-2304]班","classTime":"20304","jx0408id":"6AFCF1BEC88E457A9F3A8B8B0041FE64","kch":"04120035","courseName":"包装材料学","isRepeatCode":"0","maxClassTime":"第二大节","startTime":"10:00","endTIme":"11:40","location":"公共222","classWeekDetails":",3,4,5,6,7,8,9,10,12,13,14,15,","coursesNote":2},{"classWeek":"1-3,5-6,8-10","teacherName":"卢富德","buttonCode":"0","ktmc":"包装工程[2303-2304]班","classTime":"30102","jx0408id":"36163EC057574DCCB562879517E19112","kch":"04126570","courseName":"数值计算与工程应用","isRepeatCode":"0","maxClassTime":"第一大节","startTime":"08:00","endTIme":"09:40","location":"公共302","classWeekDetails":",1,2,3,5,6,8,9,10,","coursesNote":2},{"classWeek":"1-5,8-15","teacherName":"邓英剑","buttonCode":"0","ktmc":"包装工程[2303-2304]班","classTime":"30304","jx0408id":"9A1F9B6186C4490F8B1B6F2F067C0871","kch":"05123030","courseName":"机械设计基础","isRepeatCode":"0","maxClassTime":"第二大节","startTime":"10:00","endTIme":"11:40","location":"公共205","classWeekDetails":",1,2,3,4,5,8,9,10,11,12,13,14,15,","coursesNote":2},{"classWeek":"1-5,8-10,12-13","teacherName":"刘俊萍","buttonCode":"0","ktmc":"包装工程[2304-2306]班","classTime":"30506","jx0408id":"77EEDF2CE4E942FF9184F2C459B67626","kch":"01110010","courseName":"电工学1","isRepeatCode":"0","maxClassTime":"第三大节","startTime":"14:00","endTIme":"15:40","location":"公共115","classWeekDetails":",1,2,3,4,5,8,9,10,12,13,","coursesNote":2},{"classWeek":"1-5,8-10,12-13","teacherName":"余霄","buttonCode":"0","ktmc":"包装工程[2304-2306]班","classTime":"30708","jx0408id":"85A80553D9ED488BB19DC47B8896BBF0","kch":"29110250","courseName":"毛泽东思想和中国特色社会主义理论体系概论","isRepeatCode":"0","maxClassTime":"第四大节","startTime":"16:00","endTIme":"17:40","location":"外语楼111","classWeekDetails":",1,2,3,4,5,8,9,10,12,13,","coursesNote":2},{"classWeek":"1-5,8-15","teacherName":"邓英剑","buttonCode":"0","ktmc":"包装工程[2303-2304]班","classTime":"40304","jx0408id":"39451A236EC64C39BB380E93BD6D7763","kch":"05123030","courseName":"机械设计基础","isRepeatCode":"0","maxClassTime":"第二大节","startTime":"10:00","endTIme":"11:40","location":"公共205","classWeekDetails":",1,2,3,4,5,8,9,10,11,12,13,14,15,","coursesNote":2},{"classWeek":"2-5","teacherName":"陈腊文","buttonCode":"0","ktmc":"包装工程[2304-2306]班","classTime":"40506","jx0408id":"689AFBB898744117A7177CF8F18F36EC","kch":"40110010","courseName":"创业基础","isRepeatCode":"0","maxClassTime":"第三大节","startTime":"14:00","endTIme":"15:40","location":"公共407","classWeekDetails":",2,3,4,5,","coursesNote":2},{"classWeek":"1-5,8-10,12-13","teacherName":"余霄","buttonCode":"0","ktmc":"包装工程[2304-2306]班","classTime":"40708","jx0408id":"D3D71A6BA5C3469D80AB3F9263E801E7","kch":"29110250","courseName":"毛泽东思想和中国特色社会主义理论体系概论","isRepeatCode":"0","maxClassTime":"第四大节","startTime":"16:00","endTIme":"17:40","location":"公共309","classWeekDetails":",1,2,3,4,5,8,9,10,12,13,","coursesNote":2},{"classWeek":"1-4","teacherName":"李慧源","buttonCode":"0","ktmc":"包装工程[2303-2304]班","classTime":"50102","jx0408id":"0EDC6194AFCC4CF59DAAFD65628D2F59","kch":"06110300","courseName":"通用学术英语A","isRepeatCode":"0","maxClassTime":"第一大节","startTime":"08:00","endTIme":"09:40","location":"外语楼206","classWeekDetails":",1,2,3,4,","coursesNote":2},{"classWeek":"1-5,8-10,12-13","teacherName":"刘俊萍","buttonCode":"0","ktmc":"包装工程[2304-2306]班","classTime":"50506","jx0408id":"8BA04C12343748C2BCDE1461471E24E5","kch":"01110010","courseName":"电工学1","isRepeatCode":"0","maxClassTime":"第三大节","startTime":"14:00","endTIme":"15:40","location":"公共409","classWeekDetails":",1,2,3,4,5,8,9,10,12,13,","coursesNote":2},{"classWeek":"1-5,8-10,12-19","teacherName":"李世霖","buttonCode":"0","ktmc":"包装工程[2301-2304]班","classTime":"50708","jx0408id":"EEEEC32BA08B47908E618EB6E63C5ED7","kch":"11121730","courseName":"概率论与数理统计","isRepeatCode":"0","maxClassTime":"第四大节","startTime":"16:00","endTIme":"17:40","location":"公共332","classWeekDetails":",1,2,3,4,5,8,9,10,12,13,14,15,16,17,18,19,","coursesNote":2}],"week":2,"weekday":"五"}],"nowWeek":"3","jcdatalist":[{"XJMC":"01,02","DJMC":"第一大节"},{"XJMC":"03,04","DJMC":"第二大节"},{"XJMC":"05,06","DJMC":"第三大节"},{"XJMC":"07,08","DJMC":"第四大节"},{"XJMC":"09,10","DJMC":"第五大节"}],"nkbList":[{"kch":"05141030","kcmc":"金工实习C","jgxm":"张灵","zc":"6-7","tzdlb":"2","sjzcbz":""},{"kch":"04120035","kcmc":"包装材料学","jgxm":"何新快","zc":"12-15","tzdlb":"2","sjzcbz":""},{"kch":"01140060","kcmc":"电工学实验1","jgxm":"刘俊萍","zc":"3-5,8-10","tzdlb":"2","sjzcbz":""},{"kch":"05123030","kcmc":"机械设计基础","jgxm":"卢定军","zc":"1-4","tzdlb":"2","sjzcbz":""},{"kch":"53110030","kcmc":"大学生劳动教育","jgxm":"","zc":"1","tzdlb":"1","sjzcbz":""},{"kch":"53110030","kcmc":"大学生劳动教育","jgxm":"","zc":"1-18","tzdlb":"1","sjzcbz":""}]}';

  final Map<String, dynamic> map = jsonDecode(jsonString);

  final GetSingleWeekClass oneJson = GetSingleWeekClass(orgdata: map);
  oneJson.initData();
  oneJson.getWeekDate();
  final Map<String, List<Course>> courseData = oneJson.getSingleClass();
  return courseData;
}

Future<CourseSyncSnapshot> loadCourseSyncSnapshotFromUrl(
  String token, {
  BuildContext? context,
  CourseSyncProgressCallback? onProgress,
}) async {
  final GetOrgDataWeb getOrgDataWeb = GetOrgDataWeb(token: token);
  getOrgDataWeb.initData();
  final totalWeeks =
      getOrgDataWeb.maxWeek >= getOrgDataWeb.firstWeek
          ? getOrgDataWeb.maxWeek - getOrgDataWeb.firstWeek + 1
          : 0;
  final totalUnits = 1 + totalWeeks * 2 + 1;
  onProgress?.call(
    CourseSyncProgress(
      phase: CourseSyncPhase.preparing,
      completedUnits: 0,
      totalUnits: totalUnits,
      message: '正在准备同步课表',
    ),
  );
  await getOrgDataWeb.getCurrentSemesterId();
  onProgress?.call(
    CourseSyncProgress(
      phase: CourseSyncPhase.semester,
      completedUnits: 1,
      totalUnits: totalUnits,
      message: '正在确认当前学期',
    ),
  );
  if (context != null && !context.mounted) {
    return const CourseSyncSnapshot(
      courseData: <String, List<Course>>{},
      semesterId: '',
      firstDay: '',
      maxWeek: 20,
    );
  }
  final Map<String, List<Course>> courseData = await getOrgDataWeb
      .getAllWeekClass(
        context,
        onProgress: onProgress,
        completedUnitsOffset: 1,
        totalUnits: totalUnits,
      );
  if (context != null && !context.mounted) {
    return CourseSyncSnapshot(
      courseData: courseData,
      semesterId: getOrgDataWeb.semesterId ?? '',
      firstDay: _findFirstCourseDate(courseData),
      maxWeek: getOrgDataWeb.maxWeek,
    );
  }
  final Map<String, List<Course>> expCourseData = await getOrgDataWeb
      .getAllWeekExpClass(
        context,
        onProgress: onProgress,
        completedUnitsOffset: 1 + totalWeeks,
        totalUnits: totalUnits,
      );
  try {
    await saveExperimentRawDataToJson(getOrgDataWeb.expRawWeeklyResponses);
  } catch (error, stackTrace) {
    AppLogger.error(
      'Failed to persist experiment course raw snapshot',
      error: error,
      stackTrace: stackTrace,
    );
  }
  expCourseData.forEach((date, list) {
    if (courseData.containsKey(date)) {
      courseData[date]!.addAll(list);
    } else {
      courseData[date] = list;
    }
  });
  return CourseSyncSnapshot(
    courseData: courseData,
    semesterId: getOrgDataWeb.semesterId ?? '',
    firstDay: _findFirstCourseDate(courseData),
    maxWeek: getOrgDataWeb.maxWeek,
  );
}

Future<Map<String, List<Course>>> loadClassFormUrl(
  String token,
  BuildContext context,
) async {
  final snapshot = await loadCourseSyncSnapshotFromUrl(token, context: context);
  return snapshot.courseData;
}
