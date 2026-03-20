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
    'saveCourseDataToJson writes cache for app and widget readers',
    () async {
      final courseData = <String, List<Course>>{
        '2026-03-19': [
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

      expect(appFile.existsSync(), isTrue);
      expect(widgetFile.existsSync(), isTrue);

      final appJson =
          jsonDecode(await appFile.readAsString()) as Map<String, dynamic>;
      final widgetJson =
          jsonDecode(await widgetFile.readAsString()) as Map<String, dynamic>;
      final loadedCourseData = await loadClassFromLocal();

      expect((appJson['2026-03-19'] as List).single['name'], '软件工程');
      expect((widgetJson['2026-03-19'] as List).single['location'], '公共201');
      expect(loadedCourseData['2026-03-19']?.single.name, '软件工程');
      expect(loadedCourseData['2026-03-19']?.single.teacherName, '张老师');
      expect(widgetRefreshCalls.map((call) => call.method).toList(), [
        'refreshCourseTableWidget',
      ]);
    },
  );

  test(
    'loadClassFromLocal returns empty data when cache file is missing',
    () async {
      expect(await loadClassFromLocal(), isEmpty);
    },
  );

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
      await tester.runAsync(() async {
        result = await saveClassToLocal('jwxt-token', context);
        cachedCourses = await loadClassFromLocal();
      });

      expect(result.success, isTrue);
      expect(cachedCourses['2026-03-16']?.single.name, '软件工程');
      expect(widgetRefreshCalls.map((call) => call.method), [
        'refreshCourseTableWidget',
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
