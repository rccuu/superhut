import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/hutpages/hutmain.dart';
import 'package:superhut/utils/hut_user_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('duplicate service taps open a single service route', (
    tester,
  ) async {
    var buildServicePageCalls = 0;
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
        ],
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: HutMainPage(
          checkLoginOnInit: false,
          loadFunctionList: () async => services,
          buildServicePage: (service, servicePicUrl) {
            buildServicePageCalls++;
            return Scaffold(
              appBar: AppBar(title: const Text('服务页面')),
              body: Text('${service.serviceName} $servicePicUrl'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final serviceTile = find.text('校园卡');
    final serviceTileCenter = tester.getCenter(serviceTile);
    await tester.tapAt(serviceTileCenter);
    await tester.tapAt(serviceTileCenter);
    await tester.pumpAndSettle();

    expect(buildServicePageCalls, 1);
    expect(find.text('服务页面'), findsOneWidget);
    expect(find.text('校园卡 '), findsOneWidget);

    Navigator.of(tester.element(find.text('服务页面'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(serviceTile);
    await tester.pumpAndSettle();

    expect(buildServicePageCalls, 2);
  });

  testWidgets('service tap recovers after route push throws', (tester) async {
    var pushCalls = 0;
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
        ],
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: HutMainPage(
          checkLoginOnInit: false,
          loadFunctionList: () async => services,
          buildServicePage:
              (service, servicePicUrl) => const Scaffold(body: Text('服务页面')),
          pushRoute: <T>(context, route) async {
            pushCalls++;
            throw Exception('navigator unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final serviceTile = find.text('校园卡');
    await tester.tapAt(tester.getCenter(serviceTile));
    await tester.pump();
    await tester.pump();

    expect(pushCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开服务页面，请稍后重试'), findsOneWidget);

    await tester.tapAt(tester.getCenter(serviceTile));
    await tester.pump();
    await tester.pump();

    expect(pushCalls, 2);
  });

  testWidgets('service search matches service and category names', (
    tester,
  ) async {
    final services = [
      {
        'label': '生活服务',
        'services': [
          FunctionItem(
            id: 'service-card',
            serviceName: '校园卡',
            servicePicUrl: '',
            serviceUrl: 'https://example.com/card',
            serviceType: '1',
            tokenAccept: '[]',
            iconUrl: '',
          ),
        ],
      },
      {
        'label': '教学服务',
        'services': [
          FunctionItem(
            id: 'service-score',
            serviceName: '成绩查询',
            servicePicUrl: '',
            serviceUrl: 'https://example.com/score',
            serviceType: '1',
            tokenAccept: '[]',
            iconUrl: '',
          ),
        ],
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: HutMainPage(
          checkLoginOnInit: false,
          loadFunctionList: () async => services,
          buildServicePage:
              (service, servicePicUrl) => const Scaffold(body: Text('服务页面')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '成绩');
    await tester.pumpAndSettle();

    expect(find.text('搜索结果'), findsOneWidget);
    expect(find.text('成绩查询'), findsOneWidget);
    expect(find.text('校园卡'), findsNothing);

    await tester.enterText(find.byType(TextField), '教学');
    await tester.pumpAndSettle();

    expect(find.text('成绩查询'), findsOneWidget);
    expect(find.text('校园卡'), findsNothing);
  });
}
