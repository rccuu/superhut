import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/utils/course/get_course.dart';
import 'package:superhut/utils/course/coursemain.dart';
import 'package:superhut/utils/withhttp.dart';

import '../../support/path_provider_mock.dart';

class _FakeCourseHttpClientAdapter implements HttpClientAdapter {
  _FakeCourseHttpClientAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const widgetChannel = MethodChannel(
    'com.superhut.rice.superhut/coursetable_widget',
  );
  final widgetRefreshCalls = <MethodCall>[];
  late Directory tempDirectory;

  setUpAll(() {
    PathProviderMock.install();
  });

  tearDownAll(() {
    PathProviderMock.uninstall();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, null);
  });

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'superhut_coursemain_test_',
    );
    PathProviderMock.updateApplicationDocumentsPath(tempDirectory.path);
    SharedPreferences.setMockInitialValues({});
    widgetRefreshCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, (call) async {
          widgetRefreshCalls.add(call);
          return true;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, null);
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test(
    'buildCompactCourseWidgetPayload limits to three courses and computes week',
    () {
      final schedule = SavedCourseSchedule(
        id: 'widget-schedule',
        name: '紧凑课表',
        ownerName: '测试用户',
        termLabel: '2025-2026-2',
        semesterId: '2025-2026-2',
        firstDay: '2026-03-16',
        maxWeek: 20,
        sourceType: CourseScheduleSourceType.manual,
        isReadOnly: false,
        createdAt: '2026-03-16T08:00:00.000',
        updatedAt: '2026-03-27T07:30:00.000',
        courseData: {
          '2026-03-27': [
            Course(
              name: '课程1',
              teacherName: '张老师',
              weekDuration: '1-16',
              location: '公共101',
              startSection: 1,
              duration: 2,
            ),
            Course(
              name: '课程2',
              teacherName: '李老师',
              weekDuration: '1-16',
              location: '公共102',
              startSection: 3,
              duration: 2,
            ),
            Course(
              name: '课程3',
              teacherName: '王老师',
              weekDuration: '1-16',
              location: '公共103',
              startSection: 5,
              duration: 2,
            ),
            Course(
              name: '课程4',
              teacherName: '赵老师',
              weekDuration: '1-16',
              location: '公共104',
              startSection: 7,
              duration: 2,
            ),
          ],
        },
      );

      final payload = buildCompactCourseWidgetPayload(
        schedule,
        now: DateTime.parse('2026-03-27T09:00:00'),
      );

      expect(payload.date, '2026-03-27');
      expect(payload.weekdayLabel, '周五');
      expect(payload.weekIndex, 2);
      expect(payload.isEmpty, isFalse);
      expect(payload.courses, hasLength(3));
      expect(payload.courses.first.name, '课程1');
      expect(payload.courses.first.startTime, '08:00');
      expect(payload.courses.first.sectionLabel, '1-2节');
      expect(payload.courses.last.name, '课程3');
    },
  );

  test('saveCourseDataToJson writes cache for app and widget readers', () async {
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final courseData = <String, List<Course>>{
      dateKey: [
        Course(
          name: '软件工程',
          teacherName: '张老师',
          weekDuration: '1-16',
          location: '公共201',
          startSection: 1,
          duration: 2,
        ),
      ],
    };

    await saveCourseDataToJson(courseData);

    final appFile = File('${tempDirectory.path}/course_data.json');
    final widgetFile = File(
      '${tempDirectory.path}/app_flutter/course_data.json',
    );
    final payloadFile = File(
      '${tempDirectory.path}/course_widget_payload.json',
    );
    final widgetPayloadFile = File(
      '${tempDirectory.path}/app_flutter/course_widget_payload.json',
    );

    expect(appFile.existsSync(), isTrue);
    expect(widgetFile.existsSync(), isTrue);
    expect(payloadFile.existsSync(), isTrue);
    expect(widgetPayloadFile.existsSync(), isTrue);

    final appJson =
        jsonDecode(await appFile.readAsString()) as Map<String, dynamic>;
    final widgetJson =
        jsonDecode(await widgetFile.readAsString()) as Map<String, dynamic>;
    final payloadJson =
        jsonDecode(await payloadFile.readAsString()) as Map<String, dynamic>;
    final loadedCourseData = await loadClassFromLocal();
    final savedSchedules = await loadSavedCourseSchedules();
    final loadedPayload = await loadCourseWidgetPayloadFromLocal();

    expect((appJson[dateKey] as List).single['name'], '软件工程');
    expect((widgetJson[dateKey] as List).single['location'], '公共201');
    expect(loadedCourseData[dateKey]?.single.name, '软件工程');
    expect(loadedCourseData[dateKey]?.single.teacherName, '张老师');
    expect(savedSchedules, hasLength(1));
    expect(savedSchedules.single.courseData[dateKey]?.single.name, '软件工程');
    expect(payloadJson['date'], dateKey);
    expect(payloadJson['isEmpty'], isFalse);
    expect((payloadJson['courses'] as List).single['name'], '软件工程');
    expect(loadedPayload?.courses.single.location, '公共201');
    expect(widgetRefreshCalls.map((call) => call.method).toList(), [
      'syncCourseTableWidget',
    ]);
    expect(
      (widgetRefreshCalls.single.arguments as Map)['payloadJson'],
      contains('软件工程'),
    );
  });

  test(
    'loadClassFromLocal returns empty data when cache file is missing',
    () async {
      expect(await loadClassFromLocal(), isEmpty);
    },
  );

  test('buildCourseScheduleShareCode round-trips through parser', () async {
    final schedule = SavedCourseSchedule(
      id: 'schedule-1',
      name: '张三的课表',
      ownerName: '张三',
      termLabel: '2025-2026-2',
      semesterId: '2025-2026-2',
      firstDay: '2026-03-16',
      maxWeek: 20,
      sourceType: CourseScheduleSourceType.selfSync,
      isReadOnly: false,
      createdAt: '2026-03-16T08:00:00.000',
      updatedAt: '2026-03-16T08:00:00.000',
      courseData: {
        '2026-03-16': [
          Course(
            name: '软件工程',
            teacherName: '张老师',
            weekDuration: '1-16',
            location: '公共201',
            startSection: 1,
            duration: 2,
            isExp: true,
            pcid: 'pcid-1',
          ),
        ],
      },
    );

    final shareCode = buildCourseScheduleShareCode(schedule);
    final imported = parseCourseScheduleShareCode(shareCode);

    expect(shareCode, startsWith('SUPERHUT1:'));
    expect(imported.name, '张三的课表');
    expect(imported.ownerName, '张三');
    expect(imported.sourceType, CourseScheduleSourceType.shareImport);
    expect(imported.isReadOnly, isTrue);
    expect(imported.courseData['2026-03-16']?.single.name, '软件工程');
    expect(imported.courseData['2026-03-16']?.single.pcid, isEmpty);
  });

  test(
    'buildCourseScheduleExportJsonString round-trips through parser',
    () async {
      final schedule = SavedCourseSchedule(
        id: 'schedule-file-1',
        name: '王五的课表',
        ownerName: '王五',
        termLabel: '2025-2026-2',
        semesterId: '2025-2026-2',
        firstDay: '2026-03-16',
        maxWeek: 20,
        sourceType: CourseScheduleSourceType.selfSync,
        isReadOnly: false,
        createdAt: '2026-03-16T08:00:00.000',
        updatedAt: '2026-03-16T08:00:00.000',
        courseData: {
          '2026-03-18': [
            Course(
              name: '编译原理',
              teacherName: '王老师',
              weekDuration: '1-16',
              location: '信工楼301',
              startSection: 5,
              duration: 2,
            ),
          ],
        },
      );

      final exportJson = buildCourseScheduleExportJsonString(schedule);
      final imported = parseCourseScheduleExportJsonString(exportJson);

      expect(exportJson, contains('superhut_course_schedule_file'));
      expect(imported.name, '王五的课表');
      expect(imported.ownerName, '王五');
      expect(imported.courseData['2026-03-18']?.single.name, '编译原理');
    },
  );

  test(
    'saveImportedCourseScheduleFromShareCode stores imported schedule',
    () async {
      final sourceSchedule = SavedCourseSchedule(
        id: 'schedule-2',
        name: '朋友课表',
        ownerName: '李四',
        termLabel: '2025-2026-2',
        semesterId: '2025-2026-2',
        firstDay: '2026-03-16',
        maxWeek: 20,
        sourceType: CourseScheduleSourceType.selfSync,
        isReadOnly: false,
        createdAt: '2026-03-16T08:00:00.000',
        updatedAt: '2026-03-16T08:00:00.000',
        courseData: {
          '2026-03-16': [
            Course(
              name: '离散数学',
              teacherName: '李老师',
              weekDuration: '1-16',
              location: '公教101',
              startSection: 3,
              duration: 2,
            ),
          ],
        },
      );

      final shareCode = buildCourseScheduleShareCode(sourceSchedule);
      final imported = await saveImportedCourseScheduleFromShareCode(shareCode);
      final activeCourseData = await loadClassFromLocal();
      final savedSchedules = await loadSavedCourseSchedules();

      expect(imported.name, '朋友课表');
      expect(savedSchedules, hasLength(1));
      expect(
        savedSchedules.single.sourceType,
        CourseScheduleSourceType.shareImport,
      );
      expect(activeCourseData['2026-03-16']?.single.name, '离散数学');
      expect(widgetRefreshCalls.map((call) => call.method).toList(), [
        'syncCourseTableWidget',
      ]);
    },
  );

  test(
    'saveImportedCourseScheduleFromFileContent stores imported schedule',
    () async {
      final sourceSchedule = SavedCourseSchedule(
        id: 'schedule-file-2',
        name: '文件课表',
        ownerName: '赵六',
        termLabel: '2025-2026-2',
        semesterId: '2025-2026-2',
        firstDay: '2026-03-16',
        maxWeek: 20,
        sourceType: CourseScheduleSourceType.selfSync,
        isReadOnly: false,
        createdAt: '2026-03-16T08:00:00.000',
        updatedAt: '2026-03-16T08:00:00.000',
        courseData: {
          '2026-03-20': [
            Course(
              name: '操作系统',
              teacherName: '周老师',
              weekDuration: '1-16',
              location: '计科楼201',
              startSection: 1,
              duration: 2,
            ),
          ],
        },
      );

      final exportJson = buildCourseScheduleExportJsonString(sourceSchedule);
      final imported = await saveImportedCourseScheduleFromFileContent(
        exportJson,
      );
      final activeCourseData = await loadClassFromLocal();
      final savedSchedules = await loadSavedCourseSchedules();

      expect(imported.name, '文件课表');
      expect(savedSchedules, hasLength(1));
      expect(savedSchedules.single.ownerName, '赵六');
      expect(activeCourseData['2026-03-20']?.single.name, '操作系统');
      expect(widgetRefreshCalls.map((call) => call.method).toList(), [
        'syncCourseTableWidget',
      ]);
    },
  );

  test('renameCourseSchedule updates saved schedule name', () async {
    final schedule = SavedCourseSchedule(
      id: 'schedule-rename-1',
      name: '原始名称',
      ownerName: '测试用户',
      termLabel: '2025-2026-2',
      semesterId: '2025-2026-2',
      firstDay: '2026-03-16',
      maxWeek: 20,
      sourceType: CourseScheduleSourceType.manual,
      isReadOnly: false,
      createdAt: '2026-03-16T08:00:00.000',
      updatedAt: '2026-03-16T08:00:00.000',
      courseData: {
        '2026-03-17': [
          Course(
            name: '数据库原理',
            teacherName: '周老师',
            weekDuration: '1-16',
            location: '信工楼201',
            startSection: 1,
            duration: 2,
          ),
        ],
      },
    );

    await saveCourseSchedule(schedule, setActive: true);
    await renameCourseSchedule(schedule.id, '新名称');

    final activeSchedule = await loadActiveCourseSchedule();
    final savedSchedules = await loadSavedCourseSchedules();

    expect(activeSchedule?.name, '新名称');
    expect(savedSchedules.single.name, '新名称');
    expect(widgetRefreshCalls.map((call) => call.method).toList(), [
      'syncCourseTableWidget',
      'syncCourseTableWidget',
    ]);
  });

  testWidgets(
    'saveClassToLocal trusts curriculum fetch and does not require noticeTab precheck',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'token': 'jwxt-token',
        'my_client_ticket': '',
      });

      final originalAdapter = dio.httpClientAdapter;
      dio.httpClientAdapter = _FakeCourseHttpClientAdapter((options) {
        final path = options.path;
        if (path == '/njwhd/noticeTab') {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'noticeTab should not be called during course sync',
          );
        }
        if (path == '/njwhd/student/curriculum?week=1') {
          return _jsonResponse({
            'code': '1',
            'data': [
              {
                'date': [
                  {'xqid': 1, 'mxrq': '2026-03-16'},
                ],
                'item': [
                  {
                    'classTime': '10102',
                    'courseName': '软件工程',
                    'teacherName': '张老师',
                    'classWeek': '1-16',
                    'location': '公共201',
                  },
                ],
              },
            ],
          });
        }
        if (path.startsWith('/njwhd/student/curriculum?week=')) {
          return _jsonResponse({'code': '1', 'data': []});
        }
        if (path == '/njwhd/semesterList') {
          return _jsonResponse({
            'code': '1',
            'data': [
              {'nowXq': '1', 'semesterId': '2025-2026-2'},
            ],
          });
        }
        if (path.startsWith('/njwhd/teacher/courseScheduleExp?')) {
          return _jsonResponse({'code': '1', 'data': []});
        }
        throw StateError('Unexpected request path: $path');
      });
      addTearDown(() {
        dio.httpClientAdapter = originalAdapter;
      });

      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      late CourseSyncResult result;
      late Map<String, List<Course>> cachedCourses;
      late List<SavedCourseSchedule> savedSchedules;
      await tester.runAsync(() async {
        result = await saveClassToLocal('jwxt-token', context);
        cachedCourses = await loadClassFromLocal();
        savedSchedules = await loadSavedCourseSchedules();
      });

      expect(result.success, isTrue);
      expect(cachedCourses['2026-03-16']?.single.name, '软件工程');
      expect(savedSchedules, hasLength(1));
      expect(
        savedSchedules.single.sourceType,
        CourseScheduleSourceType.selfSync,
      );
      expect(savedSchedules.single.semesterId, '2025-2026-2');
      expect(widgetRefreshCalls.map((call) => call.method), [
        'syncCourseTableWidget',
      ]);
    },
  );

  test(
    'saveExperimentRawDataToJson writes raw experiment schedule snapshot for debugging',
    () async {
      SharedPreferences.setMockInitialValues({
        'token': 'jwxt-token',
        'my_client_ticket': '',
      });

      final originalAdapter = dio.httpClientAdapter;
      dio.httpClientAdapter = _FakeCourseHttpClientAdapter((options) {
        final path = options.path;
        if (path == '/njwhd/student/curriculum?week=1') {
          return _jsonResponse({
            'code': '1',
            'data': [
              {
                'date': [
                  {'xqid': 1, 'mxrq': '2026-03-16'},
                ],
                'item': [
                  {
                    'classTime': '10102',
                    'courseName': '软件工程',
                    'teacherName': '张老师',
                    'classWeek': '1-16',
                    'location': '公共201',
                  },
                ],
              },
            ],
          });
        }
        if (path.startsWith('/njwhd/student/curriculum?week=')) {
          return _jsonResponse({'code': '1', 'data': []});
        }
        if (path == '/njwhd/semesterList') {
          return _jsonResponse({
            'code': '1',
            'data': [
              {'nowXq': '1', 'semesterId': '2025-2026-2'},
            ],
          });
        }
        if (path ==
            '/njwhd/teacher/courseScheduleExp?xnxq01id=2025-2026-2&week=1') {
          return _jsonResponse({
            'code': '1',
            'data': [
              {
                'date': [
                  {'xqid': 1, 'mxrq': '2026-03-16'},
                ],
                'courses': [
                  {
                    'teacherName': '李老师',
                    'syxmName': '网络实验',
                    'weekNoteDetail': '105,106',
                    'courseName': '软件工程',
                    'classroomName': '实验楼101',
                    'weekDay': 1,
                    'pcid': 'pcid-1',
                    'kkzc': '1',
                    'startTime': '14:00',
                    'endTIme': '15:40',
                  },
                ],
              },
            ],
          });
        }
        if (path.startsWith('/njwhd/teacher/courseScheduleExp?')) {
          return _jsonResponse({'code': '1', 'data': []});
        }
        throw StateError('Unexpected request path: $path');
      });
      addTearDown(() {
        dio.httpClientAdapter = originalAdapter;
      });

      final getOrgDataWeb = GetOrgDataWeb(token: 'jwxt-token');
      getOrgDataWeb.initData();
      await getOrgDataWeb.getAllWeekExpClass(null);
      await saveExperimentRawDataToJson(getOrgDataWeb.expRawWeeklyResponses);

      final rawFile = File('${tempDirectory.path}/experiment_course_raw.json');
      expect(rawFile.existsSync(), isTrue);

      final rawJson =
          jsonDecode(await rawFile.readAsString()) as Map<String, dynamic>;
      expect(rawJson['semesterId'], '2025-2026-2');

      final weeks = rawJson['weeks'] as Map<String, dynamic>;
      final weekOne = weeks['1'] as Map<String, dynamic>;
      final response = weekOne['response'] as Map<String, dynamic>;
      final data = response['data'] as List<dynamic>;
      final weekData = data.single as Map<String, dynamic>;
      final courses = weekData['courses'] as List<dynamic>;
      final course = courses.single as Map<String, dynamic>;

      expect(course['syxmName'], '网络实验');
      expect(course['startTime'], '14:00');
      expect(course['endTIme'], '15:40');
      expect(course['pcid'], 'pcid-1');
    },
  );
}
