import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:superhut/pages/drink/view/logic.dart';
import 'package:superhut/pages/drink/view/view.dart';
import 'package:superhut/pages/drink/view/widgets/drink_page_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('drink status header stays static across states', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DrinkStatusHeader(
            drinkStatus: false,
            deviceCount: 2,
            deviceName: '一栋饮水机',
          ),
        ),
      ),
    );

    expect(find.text('准备就绪'), findsOneWidget);
    expect(find.text('2 台设备'), findsOneWidget);
    expect(find.text('一栋饮水机'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DrinkStatusHeader(
            drinkStatus: true,
            deviceCount: 2,
            deviceName: '一栋饮水机',
          ),
        ),
      ),
    );

    expect(find.text('正在接水中'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('scan add device ignores duplicate taps while add is pending', (
    tester,
  ) async {
    final favoCompleter = Completer<bool>();
    final api = _FakeDrinkApi(favoResponse: favoCompleter.future);
    final logic = FunctionDrinkLogic(drinkApi: api, redirectToLogin: () {});
    logic.state.isLoading.value = false;
    logic.state.deviceList.clear();
    logic.state.choiceDevice.value = -1;
    addTearDown(logic.onClose);

    var permissionCalls = 0;
    var scannerCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FunctionDrinkPage(
          logic: logic,
          requestCameraPermission: () async {
            permissionCalls++;
            return PermissionStatus.granted;
          },
          openQrScanner: (_) async {
            scannerCalls++;
            return 'https://i.ilife798.com/device/tap-1';
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('添加设备').evaluate().isNotEmpty);

    final addButton = find.text('添加设备').first;
    await tester.tap(addButton);
    await _pumpUntil(tester, () => api.favoDeviceCalls == 1);

    await tester.tap(addButton);
    await tester.pump();

    expect(permissionCalls, 1);
    expect(scannerCalls, 1);
    expect(api.favoDeviceCalls, 1);
    expect(api.favoRequestIds, ['tap-1']);

    favoCompleter.complete(true);
    await tester.pump();
    await tester.pump();

    expect(api.deviceListCalls, 1);
  });

  testWidgets('device selection sheet ignores duplicate taps while open', (
    tester,
  ) async {
    final sheetCompleter = Completer<void>();
    final logic = FunctionDrinkLogic(
      drinkApi: _FakeDrinkApi(favoResponse: Future.value(true)),
      redirectToLogin: () {},
    );
    logic.state.isLoading.value = false;
    logic.state.deviceList.value = [
      {'id': 'tap-1', 'name': '一栋饮水机'},
    ];
    logic.state.choiceDevice.value = 0;
    addTearDown(logic.onClose);

    var sheetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FunctionDrinkPage(
          logic: logic,
          showBottomSheet: <T>({
            required BuildContext context,
            required WidgetBuilder builder,
            bool expand = false,
            Color? backgroundColor,
          }) {
            sheetCalls++;
            return sheetCompleter.future.then<T?>((_) => null);
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('一-饮水机').evaluate().isNotEmpty);

    final deviceCard = find.byType(DrinkCurrentDeviceCard);
    await tester.tap(deviceCard);
    await tester.pump();
    await tester.tap(deviceCard);
    await tester.pump();

    expect(sheetCalls, 1);

    sheetCompleter.complete();
    await tester.pump();

    await tester.tap(deviceCard);
    await tester.pump();

    expect(sheetCalls, 2);
  });

  testWidgets('device management sheet ignores duplicate taps while open', (
    tester,
  ) async {
    final sheetCompleter = Completer<void>();
    final logic = FunctionDrinkLogic(
      drinkApi: _FakeDrinkApi(favoResponse: Future.value(true)),
      redirectToLogin: () {},
    );
    logic.state.isLoading.value = false;
    logic.state.deviceList.value = [
      {'id': 'tap-1', 'name': '一栋饮水机'},
    ];
    logic.state.choiceDevice.value = 0;
    addTearDown(logic.onClose);

    var sheetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FunctionDrinkPage(
          logic: logic,
          showBottomSheet: <T>({
            required BuildContext context,
            required WidgetBuilder builder,
            bool expand = false,
            Color? backgroundColor,
          }) {
            sheetCalls++;
            return sheetCompleter.future.then<T?>((_) => null);
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('管理设备').evaluate().isNotEmpty);

    final manageButton = find.text('管理设备');
    await tester.ensureVisible(manageButton);
    await tester.tap(manageButton);
    await tester.pump();
    await tester.tap(manageButton);
    await tester.pump();

    expect(sheetCalls, 1);

    sheetCompleter.complete();
    await tester.pump();

    await tester.tap(manageButton);
    await tester.pump();

    expect(sheetCalls, 2);
  });

  testWidgets('delete confirmation ignores duplicate delete taps while open', (
    tester,
  ) async {
    final logic = FunctionDrinkLogic(
      drinkApi: _FakeDrinkApi(favoResponse: Future.value(true)),
      redirectToLogin: () {},
    );
    logic.state.isLoading.value = false;
    logic.state.deviceList.value = [
      {'id': 'tap-1', 'name': '一栋饮水机'},
    ];
    logic.state.choiceDevice.value = 0;
    addTearDown(logic.onClose);

    await tester.pumpWidget(MaterialApp(home: FunctionDrinkPage(logic: logic)));

    await _pumpUntil(tester, () => find.text('管理设备').evaluate().isNotEmpty);

    await tester.tap(find.text('管理设备'));
    await tester.pumpAndSettle();

    var managementSheet = tester.widget<DrinkDeviceManagementSheet>(
      find.byType(DrinkDeviceManagementSheet),
    );
    managementSheet.onDeleteDevice(0);
    managementSheet.onDeleteDevice(0);
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('确认删除'), findsOneWidget);
    expect(find.text('确定要删除设备"一-饮水机"吗？'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    managementSheet = tester.widget<DrinkDeviceManagementSheet>(
      find.byType(DrinkDeviceManagementSheet),
    );
    managementSheet.onDeleteDevice(0);
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('delete confirmation recovers after delete request throws', (
    tester,
  ) async {
    final logic = FunctionDrinkLogic(
      drinkApi: _FakeDrinkApi(
        favoResponse: Future.value(true),
        throwOnFavo: true,
      ),
      redirectToLogin: () {},
    );
    logic.state.isLoading.value = false;
    logic.state.deviceList.value = [
      {'id': 'tap-1', 'name': '一栋饮水机'},
    ];
    logic.state.choiceDevice.value = 0;
    addTearDown(logic.onClose);

    await tester.pumpWidget(MaterialApp(home: FunctionDrinkPage(logic: logic)));

    await _pumpUntil(tester, () => find.text('管理设备').evaluate().isNotEmpty);

    await tester.tap(find.text('管理设备'));
    await tester.pumpAndSettle();

    var managementSheet = tester.widget<DrinkDeviceManagementSheet>(
      find.byType(DrinkDeviceManagementSheet),
    );
    managementSheet.onDeleteDevice(0);
    await tester.pump();

    await tester.tap(find.text('删除'));
    await tester.pump();
    await tester.pump();

    expect(logic.state.deviceList.length, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('设备删除失败，请稍后重试'), findsOneWidget);

    managementSheet = tester.widget<DrinkDeviceManagementSheet>(
      find.byType(DrinkDeviceManagementSheet),
    );
    managementSheet.onDeleteDevice(0);
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
  });
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

class _FakeDrinkApi implements DrinkApiClient {
  _FakeDrinkApi({required this.favoResponse, this.throwOnFavo = false});

  final Future<bool> favoResponse;
  final bool throwOnFavo;
  int deviceListCalls = 0;
  int favoDeviceCalls = 0;
  final List<String> favoRequestIds = <String>[];

  @override
  Future<List<Map>> deviceList() async {
    deviceListCalls++;
    return [
      {'id': 'tap-1', 'name': '一栋饮水机'},
    ];
  }

  @override
  Future<bool> favoDevice({required String id, required bool isUnFavo}) {
    favoDeviceCalls++;
    favoRequestIds.add(id);
    if (throwOnFavo) {
      return Future<bool>.error(Exception('favo failed'));
    }
    return favoResponse;
  }

  @override
  Future<bool> startDrink({required String id}) async => true;

  @override
  Future<bool> endDrink({required String id}) async => true;

  @override
  Future<bool> isAvailableDevice({required String id}) async => false;

  @override
  Future<String> getToken() async => 'token';

  @override
  Future<void> setToken({required String token}) async {}
}
