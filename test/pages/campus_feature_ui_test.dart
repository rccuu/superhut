import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:superhut/core/ui/apple_glass.dart';
import 'package:superhut/main.dart';
import 'package:superhut/pages/ExamSchedule/exam_schedule_bridge.dart';
import 'package:superhut/pages/ExamSchedule/exam_schedule_page.dart';
import 'package:superhut/pages/hutpages/hutmain.dart';
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

  testWidgets('智慧工大使用新版服务总览并支持搜索过滤', (tester) async {
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
        HutMainPage(
          checkLoginOnInit: false,
          loadFunctionList: () async => services,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppGlassBackground), findsOneWidget);
    expect(find.text('服务总览'), findsOneWidget);
    expect(find.text('2 个服务'), findsOneWidget);
    expect(find.text('校园卡'), findsOneWidget);
    expect(find.text('图书馆'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '图书');
    await tester.pumpAndSettle();

    expect(find.text('图书馆'), findsOneWidget);
    expect(find.text('校园卡'), findsNothing);
  });
}
