import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:superhut/core/ui/apple_glass.dart';
import 'package:superhut/main.dart';
import 'package:superhut/pages/ExamSchedule/exam_schedule_bridge.dart';
import 'package:superhut/pages/ExamSchedule/exam_schedule_page.dart';
import 'package:superhut/pages/hutpages/hutmain.dart';
import 'package:superhut/pages/hutpages/hutmain_logic.dart';
import 'package:superhut/utils/hut_user_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Get.reset();
  });

  Widget app(Widget child) {
    return GetMaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: child,
    );
  }

  testWidgets('考试安排使用新版玻璃背景和考试总览', (tester) async {
    await tester.pumpWidget(
      app(
        ExamSchedulePage(
          loadExamSchedule:
              () async => const ExamScheduleResult(
                schedules: [
                  {
                    'courseName': '高等数学',
                    'examinationPlace': '公共楼 101',
                    'time': '2099-06-10 09:00-11:00',
                    'courseNumber': 'MATH001',
                  },
                ],
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppGlassBackground), findsOneWidget);
    expect(find.text('考试总览'), findsOneWidget);
    expect(find.text('1 门考试'), findsOneWidget);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('MATH001'), findsOneWidget);
  });

  testWidgets('考试安排日期解析保留倒计时展示', (tester) async {
    await tester.pumpWidget(
      app(
        ExamSchedulePage(
          loadExamSchedule:
              () async => const ExamScheduleResult(
                schedules: [
                  {
                    'courseName': '数据结构',
                    'examinationPlace': '公共楼 201',
                    'time': '2099-06-10 14:00-16:00',
                    'courseNumber': 'CS001',
                  },
                ],
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('数据结构 · 还有'), findsOneWidget);
    expect(find.textContaining('还有'), findsAtLeastNWidgets(2));
    expect(find.text('日期未知'), findsNothing);
  });

  testWidgets('考试安排父级重建不会重复加载首屏请求', (tester) async {
    var loadCalls = 0;

    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setHostState) {
            return Stack(
              children: [
                ExamSchedulePage(
                  loadExamSchedule: () async {
                    loadCalls++;
                    return const ExamScheduleResult(
                      schedules: [
                        {
                          'courseName': '大学英语',
                          'examinationPlace': '公共楼 102',
                          'time': '2099-06-11 09:00-11:00',
                          'courseNumber': 'EN001',
                        },
                      ],
                    );
                  },
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: TextButton(
                    key: const ValueKey('exam-schedule-host-rebuild'),
                    onPressed: () => setHostState(() {}),
                    child: const Text('rebuild'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loadCalls, 1);
    expect(find.text('大学英语'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exam-schedule-host-rebuild')));
    await tester.pumpAndSettle();

    expect(loadCalls, 1);
    expect(find.text('大学英语'), findsOneWidget);
  });

  testWidgets('智慧工大使用新版服务总览并支持搜索过滤', (tester) async {
    var loadCalls = 0;
    final services = [
      {
        'label': '常用服务',
        'services': [
          FunctionItem(
            id: 'service-a',
            serviceName: '校园卡',
            servicePicUrl: '',
            serviceUrl: 'https://example.com/card',
            serviceType: '1',
            tokenAccept: '[]',
            iconUrl: '',
          ),
          FunctionItem(
            id: 'service-b',
            serviceName: '图书馆',
            servicePicUrl: '',
            serviceUrl: 'https://example.com/library',
            serviceType: '2',
            tokenAccept: '[]',
            iconUrl: '',
          ),
        ],
      },
    ];

    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setHostState) {
            return Stack(
              children: [
                HutMainPage(
                  checkLoginOnInit: false,
                  loadFunctionList: () async {
                    loadCalls++;
                    return services;
                  },
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: TextButton(
                    key: const ValueKey('hut-main-host-rebuild'),
                    onPressed: () => setHostState(() {}),
                    child: const Text('rebuild'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loadCalls, 1);
    expect(Get.isRegistered<HutMainLogic>(), isFalse);
    expect(find.byType(AppGlassBackground), findsOneWidget);
    expect(find.text('服务总览'), findsOneWidget);
    expect(find.text('2 个服务'), findsOneWidget);
    expect(find.text('校园卡'), findsOneWidget);
    expect(find.text('图书馆'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hut-main-host-rebuild')));
    await tester.pumpAndSettle();

    expect(loadCalls, 1);

    await tester.enterText(find.byType(TextField), '图书');
    await tester.pumpAndSettle();

    expect(find.text('图书馆'), findsOneWidget);
    expect(find.text('校园卡'), findsNothing);
  });
}
