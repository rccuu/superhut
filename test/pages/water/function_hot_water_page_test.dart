import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:superhut/core/ui/app_loading_indicator.dart';
import 'package:superhut/pages/water/logic.dart';
import 'package:superhut/pages/water/view.dart';
import 'package:superhut/pages/water/widgets/water_page_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Get.reset();
  });

  testWidgets('hot water control button stays static and tappable', (
    tester,
  ) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HotWaterControlButton(
              isLoading: false,
              deviceCheckComplete: true,
              waterStatus: false,
              hasSelectedDevice: true,
              onTap: () {
                tapCount++;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('开始'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);

    await tester.tap(find.text('开始'));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('device selection sheet ignores duplicate taps while open', (
    tester,
  ) async {
    final sheetCompleter = Completer<void>();
    final logic = FunctionHotWaterLogic(hotWaterApi: _FakeHotWaterApi());
    logic.state.deviceList.value = [
      {'poscode': '100001', 'posname': '一栋热水'},
    ];
    logic.state.choiceDevice.value = 0;
    logic.state.deviceCheckComplete.value = true;
    logic.state.balance.value = '12.34';
    addTearDown(logic.onClose);

    var sheetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FunctionHotWaterPage(
          logic: logic,
          showBottomSheet: <T>({
            required BuildContext context,
            required WidgetBuilder builder,
            bool expand = false,
            Color? backgroundColor,
            Radius? topRadius,
            BoxShadow? shadow,
          }) {
            sheetCalls++;
            return sheetCompleter.future.then<T?>((_) => null);
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('一栋热水').evaluate().isNotEmpty);

    await tester.tap(find.text('一栋热水'));
    await tester.pump();
    await tester.tap(find.text('一栋热水'));
    await tester.pump();

    expect(sheetCalls, 1);

    sheetCompleter.complete();
    await tester.pump();

    await tester.tap(find.text('一栋热水'));
    await tester.pump();

    expect(sheetCalls, 2);
  });

  testWidgets('balance card ignores duplicate taps while recharge is opening', (
    tester,
  ) async {
    final openCompleter = Completer<bool>();
    final logic = FunctionHotWaterLogic(hotWaterApi: _FakeHotWaterApi());
    logic.state.deviceList.value = [
      {'poscode': '100001', 'posname': '一栋热水'},
    ];
    logic.state.choiceDevice.value = 0;
    logic.state.deviceCheckComplete.value = true;
    logic.state.balance.value = '12.34';
    addTearDown(logic.onClose);

    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FunctionHotWaterPage(
          logic: logic,
          openRechargePage: (_) {
            openCalls++;
            return openCompleter.future;
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('校园卡余额').evaluate().isNotEmpty);

    final balanceCard = tester.widget<HotWaterBalanceCard>(
      find.byType(HotWaterBalanceCard),
    );
    balanceCard.onTap();
    balanceCard.onTap();
    await tester.pump();

    expect(openCalls, 1);

    openCompleter.complete(true);
    await tester.pump();
  });

  testWidgets('balance card recovers after recharge opener throws', (
    tester,
  ) async {
    final logic = FunctionHotWaterLogic(hotWaterApi: _FakeHotWaterApi());
    logic.state.deviceList.value = [
      {'poscode': '100001', 'posname': '一栋热水'},
    ];
    logic.state.choiceDevice.value = 0;
    logic.state.deviceCheckComplete.value = true;
    logic.state.balance.value = '12.34';
    addTearDown(logic.onClose);

    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FunctionHotWaterPage(
          logic: logic,
          openRechargePage: (_) async {
            openCalls++;
            throw Exception('recharge unavailable');
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('校园卡余额').evaluate().isNotEmpty);

    final balanceCard = tester.widget<HotWaterBalanceCard>(
      find.byType(HotWaterBalanceCard),
    );
    balanceCard.onTap();
    await tester.pump();
    await tester.pump();

    expect(openCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开校园卡页面'), findsOneWidget);

    balanceCard.onTap();
    await tester.pump();
    await tester.pump();

    expect(openCalls, 2);
  });

  testWidgets('delete confirmation ignores duplicate delete taps while open', (
    tester,
  ) async {
    final logic = FunctionHotWaterLogic(hotWaterApi: _FakeHotWaterApi());
    logic.state.deviceList.value = [
      {'poscode': '100001', 'posname': '一栋热水'},
    ];
    logic.state.choiceDevice.value = 0;
    logic.state.deviceCheckComplete.value = true;
    logic.state.balance.value = '12.34';
    addTearDown(logic.onClose);

    await tester.pumpWidget(
      GetMaterialApp(home: FunctionHotWaterPage(logic: logic)),
    );

    await _pumpUntil(tester, () => find.text('一栋热水').evaluate().isNotEmpty);

    await tester.tap(find.text('一栋热水'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('管理设备'));
    await tester.pumpAndSettle();

    final managementSheet = tester.widget<WaterDeviceManagementSheet>(
      find.byType(WaterDeviceManagementSheet),
    );
    managementSheet.onDeleteDevice(0);
    managementSheet.onDeleteDevice(0);
    await tester.pump();

    expect(find.text('删除设备'), findsOneWidget);
    expect(find.text('确定要删除设备 "一栋热水" 吗？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    managementSheet.onDeleteDevice(0);
    await tester.pump();

    expect(find.text('删除设备'), findsOneWidget);
  });

  testWidgets('delete failure keeps management sheet open for retry', (
    tester,
  ) async {
    const rawDeleteFailure =
        'backend detail: https://campus.example/delete?token=secret-token';
    final logic = FunctionHotWaterLogic(
      hotWaterApi: _FakeHotWaterApi(
        deleteResult: false,
        deleteMessage: rawDeleteFailure,
      ),
    );
    logic.state.deviceList.value = [
      {'poscode': '100001', 'posname': '一栋热水'},
    ];
    logic.state.choiceDevice.value = 0;
    logic.state.deviceCheckComplete.value = true;
    logic.state.balance.value = '12.34';
    addTearDown(logic.onClose);

    await tester.pumpWidget(
      GetMaterialApp(home: FunctionHotWaterPage(logic: logic)),
    );

    await _pumpUntil(tester, () => find.text('一栋热水').evaluate().isNotEmpty);

    await tester.tap(find.text('一栋热水'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('管理设备'));
    await tester.pumpAndSettle();

    var managementSheet = tester.widget<WaterDeviceManagementSheet>(
      find.byType(WaterDeviceManagementSheet),
    );
    managementSheet.onDeleteDevice(0);
    await tester.pump();

    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(WaterDeviceManagementSheet), findsOneWidget);
    expect(find.byType(WaterDeviceSelectionSheet), findsNothing);
    expect(find.text('一栋热水'), findsWidgets);
    expect(
      find.text('操作失败：$hotWaterDeleteDeviceFailureMessage'),
      findsOneWidget,
    );
    expect(find.textContaining(rawDeleteFailure), findsNothing);

    managementSheet = tester.widget<WaterDeviceManagementSheet>(
      find.byType(WaterDeviceManagementSheet),
    );
    managementSheet.onDeleteDevice(0);
    await tester.pump();

    expect(find.text('删除设备'), findsOneWidget);
  });

  testWidgets(
    'add device sheet ignores duplicate submits and restores on fail',
    (tester) async {
      var submitCalls = 0;
      var submittedCode = '';
      var submitCompleter = Completer<bool>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddWaterDeviceSheet(
              onClose: () {},
              onSubmit: (deviceCode) {
                submitCalls++;
                submittedCode = deviceCode;
                return submitCompleter.future;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(submitCalls, 1);
      expect(submittedCode, '123456');
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.text('添加设备'), findsNothing);

      submitCompleter.complete(false);
      await tester.pump();

      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(find.text('添加设备'), findsOneWidget);

      submitCompleter = Completer<bool>();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(submitCalls, 2);
    },
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(milliseconds: 200),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!predicate()) {
    if (stopwatch.elapsed >= timeout) {
      fail('Timed out while waiting for condition.');
    }
    await tester.pump(const Duration(milliseconds: 10));
  }
}

class _FakeHotWaterApi implements HotWaterApiClient {
  const _FakeHotWaterApi({
    this.deleteResult = true,
    this.deleteMessage = '删除失败',
  });

  final bool deleteResult;
  final String deleteMessage;

  @override
  Future<Map> addWaterDevice(String bindCode) async => {'result': true};

  @override
  Future<List> checkHotWaterDevice() async => const [];

  @override
  Future<Map<String, dynamic>> delWaterDevice(String bindCode) async {
    return {'result': deleteResult, 'msg': deleteMessage};
  }

  @override
  Future<String> getCardBalance() async => '12.34';

  @override
  Future<Map<String, dynamic>> getHotWaterDevice() async {
    return {
      'code': 200,
      'data': [
        {'poscode': '100001', 'posname': '一栋热水'},
      ],
    };
  }

  @override
  Future<Map> startHotWater({required String device}) async {
    return {'success': true, 'result': '000000'};
  }

  @override
  Future<bool> stopHotWater({required String device}) async => true;

  @override
  Future<bool> userLogin({
    required String username,
    required String password,
  }) async {
    return false;
  }
}
