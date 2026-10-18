import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/ui/app_animated_container.dart';
import 'package:superhut/core/ui/app_loading_indicator.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:superhut/pages/drink/api/drink_device_status.dart';
import 'package:superhut/pages/drink/api/drink_result.dart';
import 'package:superhut/pages/drink/core/drink_device.dart';
import 'package:superhut/pages/drink/core/drink_home_tokens.dart';
import 'package:superhut/pages/drink/view/logic.dart';
import 'package:superhut/pages/drink/view/view.dart';
import 'package:superhut/pages/drink/view/widgets/drink_page_widgets.dart';

const List<Map> _twoDevices = [
  {'id': 'tap-1', 'name': '一栋饮水机'},
  {'id': 'tap-2', 'name': '二栋饮水机'},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({'hui798IsLogin': true});
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('drink status header switches between idle and drinking states', (
    tester,
  ) async {
    // 移植后的状态卡是一段绑在结构 key 上的 320ms 隐式过渡：空闲态走实底卡片，
    // 接水态走强调渐变。旧版「完全不带动画」的断言已被
    // performance_boundaries_test 中这两处显式豁免取代。
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
    expect(find.text('选择设备开始接水'), findsOneWidget);
    expect(find.text('2 台设备'), findsOneWidget);
    expect(find.text('一栋饮水机'), findsOneWidget);

    final idleCard = tester.widget<AppAnimatedContainer>(
      find.byKey(drinkStatusCardKey),
    );
    expect(idleCard.duration, const Duration(milliseconds: 320));
    final idleDecoration = idleCard.decoration as BoxDecoration;
    expect(idleDecoration.gradient, isNull);
    expect(idleDecoration.color, DrinkHomeT.cardLight);
    expect(idleDecoration.border, isNotNull);
    expect(idleDecoration.boxShadow, isNotEmpty);
    expect(find.byType(LinearProgressIndicator), findsNothing);

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
    await tester.pumpAndSettle();

    expect(find.text('正在接水中'), findsOneWidget);
    expect(find.text('接完后点击结算'), findsOneWidget);

    final activeCard = tester.widget<AppAnimatedContainer>(
      find.byKey(drinkStatusCardKey),
    );
    expect(activeCard.duration, const Duration(milliseconds: 320));
    final activeDecoration = activeCard.decoration as BoxDecoration;
    expect(activeDecoration.gradient, isNotNull);
    expect(activeDecoration.color, isNull);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('app bar refresh keeps a single refreshing load in flight', (
    tester,
  ) async {
    final pending = Completer<List<Map>>();
    final api = _FakeDrinkApi(
      favoResponse: Future.value(true),
      pendingDeviceList: pending,
    );
    final logic = FunctionDrinkLogic(drinkApi: api, redirectToLogin: () {});
    addTearDown(logic.onClose);

    await tester.pumpWidget(
      GetMaterialApp(home: FunctionDrinkPage(logic: logic)),
    );
    await tester.pump();

    final refreshButton = find.byTooltip('刷新设备');
    expect(refreshButton, findsOneWidget);

    await tester.tap(refreshButton);
    await tester.pump();

    expect(api.deviceListCalls, 1);
    expect(logic.state.isRefreshing.value, isTrue);
    // 刷新期间入口换成指示器；此时再要求重载也只保留一次在途请求。
    expect(find.byTooltip('刷新设备'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(AppLoadingIndicator),
      ),
      findsOneWidget,
    );

    logic.getDeviceList(showRefreshing: true);
    await tester.pump();

    expect(api.deviceListCalls, 1);
    expect(logic.state.isLoading.value, isTrue);
  });

  testWidgets('inline device list selects the tapped tile', (tester) async {
    final logic = _logicWithTwoDevices();
    final selected = <int>[];

    Widget host() => MaterialApp(
      home: Scaffold(
        body: _observeHomeBody(
          logic,
          () => _deviceList(logic, onSelect: selected.add, onEditNote: (_) {}),
        ),
      ),
    );

    await tester.pumpWidget(host());

    expect(find.byKey(drinkDeviceTileKey('tap-1')), findsOneWidget);
    expect(find.byKey(drinkDeviceTileKey('tap-2')), findsOneWidget);
    expect(find.text('一-饮水机'), findsOneWidget);
    expect(find.byKey(drinkDeviceCheckMarkerKey('tap-1')), findsOneWidget);
    expect(find.byKey(drinkDeviceCheckMarkerKey('tap-2')), findsNothing);

    await tester.tap(find.byKey(drinkDeviceTileKey('tap-2')));
    await tester.pump();

    expect(selected, [1]);

    // 页面把回调接回控制器：选中态由 choiceDevice 承载，索引指向具体设备。
    logic.setChoiceDevice(1);
    expect(logic.state.choiceDevice.value, 1);
    expect(drinkDeviceId(logic.state.deviceList[1]), 'tap-2');
    await tester.pump();

    expect(find.byKey(drinkDeviceCheckMarkerKey('tap-1')), findsNothing);
    expect(find.byKey(drinkDeviceCheckMarkerKey('tap-2')), findsOneWidget);

    // 接水中点击其它条目不再改写选中态。
    logic.state.drinkStatus.value = true;
    await tester.tap(find.byKey(drinkDeviceTileKey('tap-1')));
    await tester.pump();
    expect(selected, [1, 0]);

    logic.setChoiceDevice(0);
    expect(logic.state.choiceDevice.value, 1);
  });

  testWidgets('device list exposes the note editor only on idle tiles', (
    tester,
  ) async {
    final logic = _logicWithTwoDevices();
    final edited = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _observeHomeBody(
            logic,
            () => _deviceList(
              logic,
              onSelect: logic.setChoiceDevice,
              onEditNote: (dynamic device) => edited.add(drinkDeviceId(device)),
            ),
          ),
        ),
      ),
    );

    // 未选中的条目带编辑芯片，选中的条目用勾选标记代替它。
    expect(find.byKey(drinkDeviceEditKey('tap-2')), findsOneWidget);
    expect(find.byKey(drinkDeviceEditKey('tap-1')), findsNothing);

    await tester.tap(find.byKey(drinkDeviceEditKey('tap-2')));
    await tester.pump();
    expect(edited, ['tap-2']);

    // 长按整行进入同一个备注编辑器。
    await tester.longPress(find.byKey(drinkDeviceTileKey('tap-1')));
    await tester.pump();
    expect(edited, ['tap-2', 'tap-1']);

    // 写入备注后列表条目立即改显备注（页面同样只靠 refresh 重建）。
    await logic.saveDeviceNote('tap-2', '三楼东侧');
    await tester.pump();

    expect(find.text('三楼东侧'), findsOneWidget);
    expect(find.text('二-饮水机'), findsNothing);
  });

  testWidgets(
    'section header toggles layout and hands the list to reordering',
    (tester) async {
      final logic = _logicWithTwoDevices();
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Obx(
                  () => DrinkDeviceSectionHeader(
                    isGrid: logic.state.layoutMode.value == 'grid',
                    isReordering: logic.state.isReordering.value,
                    onToggleLayout: () {
                      final isGrid = logic.state.layoutMode.value == 'grid';
                      logic.setLayoutMode(isGrid ? 'list' : 'grid');
                    },
                    onToggleReorder: logic.toggleReorderMode,
                  ),
                ),
                Expanded(
                  child: _observeHomeBody(
                    logic,
                    () => _deviceList(
                      logic,
                      onSelect: logic.setChoiceDevice,
                      onEditNote: (_) {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);

      await tester.tap(find.byKey(drinkLayoutToggleKey));
      await tester.pumpAndSettle();

      expect(logic.state.layoutMode.value, 'grid');
      expect(prefs.getString('device_list_layout'), 'grid');
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
      expect(find.byType(ListView), findsNothing);
      expect(find.byKey(drinkDeviceTileKey('tap-2')), findsOneWidget);

      await tester.tap(find.byKey(drinkLayoutToggleKey));
      await tester.pumpAndSettle();

      expect(logic.state.layoutMode.value, 'list');
      expect(prefs.getString('device_list_layout'), 'list');
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(ListView), findsOneWidget);

      await tester.tap(find.byKey(drinkReorderToggleKey));
      await tester.pumpAndSettle();

      expect(logic.state.isReordering.value, isTrue);
      expect(find.byKey(drinkReorderHintKey), findsOneWidget);
      expect(find.text('拖动调整顺序'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
      // 排序模式下列表由拖拽接管，布局切换入口禁用。
      expect(
        tester.widget<IconButton>(find.byKey(drinkLayoutToggleKey)).onPressed,
        isNull,
      );

      final reorderList = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      reorderList.onReorder(0, 2);
      await tester.pumpAndSettle();

      expect(logic.state.deviceList.map(drinkDeviceId).toList(), [
        'tap-2',
        'tap-1',
      ]);
      expect(logic.state.choiceDevice.value, 1);
      expect(prefs.getStringList('device_order'), ['tap-2', 'tap-1']);

      await tester.tap(find.byKey(drinkReorderToggleKey));
      await tester.pumpAndSettle();

      expect(logic.state.isReordering.value, isFalse);
      expect(find.byKey(drinkReorderHintKey), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
    },
  );

  testWidgets('empty state keeps the scan entry and a dead primary action', (
    tester,
  ) async {
    final logic = FunctionDrinkLogic(
      drinkApi: _FakeDrinkApi(favoResponse: Future.value(true)),
      redirectToLogin: () {},
    );
    addTearDown(logic.onClose);
    logic.state.isLoading.value = false;
    logic.state.deviceList.clear();
    logic.state.choiceDevice.value = -1;

    var addCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 520,
            child: Column(
              children: [
                DrinkEmptyDeviceCard(onAddDevice: () => addCalls++),
                DrinkActionButton(
                  drinkStatus: false,
                  enabled: logic.state.deviceList.isNotEmpty,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('还没有可用设备'), findsOneWidget);
    expect(find.text('添加设备'), findsOneWidget);

    await tester.tap(find.text('添加设备'));
    await tester.pump();

    expect(addCalls, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(drinkPrimaryActionKey),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('management sheet lists every device and reports its actions', (
    tester,
  ) async {
    final formatterLogic = FunctionDrinkLogic(
      drinkApi: _FakeDrinkApi(favoResponse: Future.value(true)),
    );
    addTearDown(formatterLogic.onClose);

    var addCalls = 0;
    var closeCalls = 0;
    final deleted = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 520,
            child: DrinkDeviceManagementSheet(
              devices: _twoDevices,
              deviceCount: _twoDevices.length,
              formatDeviceName: formatterLogic.formatDeviceName,
              onClose: () => closeCalls++,
              onAddDevice: () => addCalls++,
              onDeleteDevice: deleted.add,
            ),
          ),
        ),
      ),
    );

    expect(find.text('设备管理'), findsOneWidget);
    expect(find.text('2 台'), findsOneWidget);
    expect(find.text('一-饮水机'), findsOneWidget);
    expect(find.text('二-饮水机'), findsOneWidget);
    expect(find.text('ID: tap-1'), findsOneWidget);

    await tester.tap(find.byTooltip('删除设备').first);
    await tester.tap(find.text('添加设备'));
    await tester.tap(find.text('关闭'));
    await tester.pump();

    expect(deleted, [0]);
    expect(addCalls, 1);
    expect(closeCalls, 1);
  });

  group('in-flight guards for scan, sheets, notes and the primary action', () {
    testWidgets('scan add device ignores duplicate taps while add is pending', (
      tester,
    ) async {
      // 收藏成功后页面只会靠这一次 getDeviceList 把新设备列出来，
      // 所以假接口要在这一刻返回扫码得到的那台设备。
      final favoCompleter = Completer<bool>();
      final api = _FakeDrinkApi(
        favoResponse: favoCompleter.future,
        deviceListResult: <Map>[_twoDevices.first],
      );
      final logic = FunctionDrinkLogic(drinkApi: api, redirectToLogin: () {});
      logic.state.isLoading.value = false;
      logic.state.deviceList.clear();
      logic.state.choiceDevice.value = -1;
      addTearDown(logic.onClose);

      var permissionCalls = 0;
      var scannerCalls = 0;

      await tester.pumpWidget(
        GetMaterialApp(
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
      // 添加成功后新设备直接出现在内联列表里，不再需要选设备弹层。
      await _pumpUntil(tester, () => find.text('一-饮水机').evaluate().isNotEmpty);
      expect(find.byKey(drinkDeviceTileKey('tap-1')), findsOneWidget);
      expect(logic.state.choiceDevice.value, 0);
    });

    testWidgets('device management sheet ignores duplicate taps while open', (
      tester,
    ) async {
      final sheetCompleter = Completer<void>();
      final logic = _logicWithTwoDevices();

      var sheetCalls = 0;

      await tester.pumpWidget(
        GetMaterialApp(
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

    testWidgets(
      'delete confirmation ignores duplicate delete taps while open',
      (tester) async {
        final logic = _logicWithTwoDevices();

        await tester.pumpWidget(
          GetMaterialApp(home: FunctionDrinkPage(logic: logic)),
        );

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
        expect(logic.state.deviceList, hasLength(2));

        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();

        managementSheet = tester.widget<DrinkDeviceManagementSheet>(
          find.byType(DrinkDeviceManagementSheet),
        );
        managementSheet.onDeleteDevice(0);
        await tester.pump();

        expect(find.byType(AlertDialog), findsOneWidget);
      },
    );

    testWidgets('delete confirmation recovers after delete request throws', (
      tester,
    ) async {
      final logic = FunctionDrinkLogic(
        drinkApi: _FakeDrinkApi(
          favoResponse: Future.value(true),
          throwOnFavo: true,
          deviceListResult: _twoDevices,
        ),
        redirectToLogin: () {},
      );
      logic.state.isLoading.value = false;
      logic.state.deviceList.value = List<Map>.of(_twoDevices);
      logic.state.choiceDevice.value = 0;
      addTearDown(logic.onClose);

      await tester.pumpWidget(
        GetMaterialApp(home: FunctionDrinkPage(logic: logic)),
      );

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

      expect(logic.state.deviceList.length, 2);
      expect(tester.takeException(), isNull);
      expect(find.text('设备删除失败，请稍后重试'), findsOneWidget);

      managementSheet = tester.widget<DrinkDeviceManagementSheet>(
        find.byType(DrinkDeviceManagementSheet),
      );
      managementSheet.onDeleteDevice(0);
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('note dialog writes and clears device_note_<id>', (
      tester,
    ) async {
      final logic = _logicWithTwoDevices();
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        GetMaterialApp(home: FunctionDrinkPage(logic: logic)),
      );
      await _pumpUntil(tester, () => find.text('二-饮水机').evaluate().isNotEmpty);

      await tester.tap(find.byKey(drinkDeviceEditKey('tap-2')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('例如：三楼东侧'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '三楼东侧');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(prefs.getString('device_note_tap-2'), '三楼东侧');
      expect(logic.state.deviceNotes['tap-2'], '三楼东侧');
      expect(find.text('三楼东侧'), findsOneWidget);
      // 备注只是换掉条目标题：编辑芯片仍留在每个未选中的静止条目上，
      // 这样写完还能再改再清（与独立 App 一致）。
      expect(find.byKey(drinkDeviceEditKey('tap-2')), findsOneWidget);

      // 取消不落盘。tap-1 是选中条目，右侧是勾选角标而不是编辑芯片，
      // 走长按整行进入同一个编辑器。
      await tester.longPress(find.byKey(drinkDeviceTileKey('tap-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '不要这条');
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(prefs.containsKey('device_note_tap-1'), isFalse);

      // 清空即删除。
      await tester.tap(find.byKey(drinkDeviceEditKey('tap-2')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(prefs.containsKey('device_note_tap-2'), isFalse);
      expect(logic.state.deviceNotes.containsKey('tap-2'), isFalse);
      expect(find.text('二-饮水机'), findsOneWidget);
    });

    testWidgets('long press opens the same note editor', (tester) async {
      final logic = _logicWithTwoDevices();
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        GetMaterialApp(home: FunctionDrinkPage(logic: logic)),
      );
      await _pumpUntil(tester, () => find.text('一-饮水机').evaluate().isNotEmpty);

      await tester.longPress(find.byKey(drinkDeviceTileKey('tap-1')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), '宿舍门口');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(prefs.getString('device_note_tap-1'), '宿舍门口');
      expect(logic.deviceTitle(logic.state.deviceList[0]), '宿舍门口');
    });

    testWidgets('primary action starts drinking and then settles', (
      tester,
    ) async {
      final api = _FakeDrinkApi(
        favoResponse: Future.value(true),
        deviceListResult: _twoDevices,
      );
      final logic = FunctionDrinkLogic(drinkApi: api, redirectToLogin: () {});
      logic.state.isLoading.value = false;
      logic.state.deviceList.value = List<Map>.of(_twoDevices);
      logic.state.choiceDevice.value = 0;
      addTearDown(logic.onClose);

      await tester.pumpWidget(
        GetMaterialApp(home: FunctionDrinkPage(logic: logic)),
      );
      await _pumpUntil(tester, () => find.text('开始用水').evaluate().isNotEmpty);

      await tester.tap(find.byKey(drinkPrimaryActionKey));
      await tester.pumpAndSettle();

      expect(api.startDrinkRequests, ['tap-1']);
      expect(logic.state.drinkStatus.value, isTrue);
      expect(find.text('开始接水'), findsOneWidget);
      expect(find.text('正在接水中'), findsOneWidget);
      expect(find.text('结算'), findsOneWidget);

      // 「开始接水」提示条是 floating 的，正好压在主页按钮上；真人要等它
      // 自己消失才能点结算，测试同样不能让指针事件打在条子上。
      expect(find.byType(SnackBar), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.byKey(drinkPrimaryActionKey));
      await tester.pumpAndSettle();

      expect(api.endDrinkRequests, ['tap-1']);
      expect(logic.state.drinkStatus.value, isFalse);
      expect(find.text('已结算'), findsOneWidget);
      expect(find.text('准备就绪'), findsOneWidget);
      expect(logic.state.deviceStatusTimer, isNull);
    });

    testWidgets('primary action without a selected device stays disabled', (
      tester,
    ) async {
      final api = _FakeDrinkApi(favoResponse: Future.value(true));
      final logic = FunctionDrinkLogic(drinkApi: api, redirectToLogin: () {});
      logic.state.isLoading.value = false;
      logic.state.deviceList.clear();
      logic.state.choiceDevice.value = -1;
      addTearDown(logic.onClose);

      await tester.pumpWidget(
        GetMaterialApp(home: FunctionDrinkPage(logic: logic)),
      );
      await _pumpUntil(tester, () => find.text('开始用水').evaluate().isNotEmpty);

      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(drinkPrimaryActionKey),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.byKey(drinkPrimaryActionKey));
      await tester.pumpAndSettle();

      expect(api.startDrinkRequests, isEmpty);
      expect(logic.state.drinkStatus.value, isFalse);
      expect(find.text('还没有可用设备'), findsOneWidget);
    });
  });
}

/// 页面正文（view.dart 的 Expanded/Obx 组合）会读设备列表本身，备注写入与
/// 重排后的 `refresh()` 因此能重建列表；测试宿主照搬这一读取，避免把
/// DrinkDeviceList 当成一次性构建的静态子树。
Widget _observeHomeBody(FunctionDrinkLogic logic, Widget Function() build) {
  return Obx(() {
    final bool hasDevices = logic.state.deviceList.isNotEmpty;
    if (!hasDevices) {
      return const Center(child: Text('还没有可用设备'));
    }
    return SizedBox(height: 320, child: build());
  });
}

Widget _deviceList(
  FunctionDrinkLogic logic, {
  required ValueChanged<int> onSelect,
  required void Function(dynamic device) onEditNote,
}) {
  return DrinkDeviceList(
    devices: logic.state.deviceList,
    selectedIndex: logic.state.choiceDevice.value,
    isGrid: logic.state.layoutMode.value == 'grid',
    isReordering: logic.state.isReordering.value,
    deviceKeyOf: drinkDeviceId,
    titleOf: logic.deviceTitle,
    onSelect: onSelect,
    onEditNote: onEditNote,
    onReorder: logic.reorderDevices,
  );
}

FunctionDrinkLogic _logicWithTwoDevices() {
  final logic = FunctionDrinkLogic(
    drinkApi: _FakeDrinkApi(
      favoResponse: Future.value(true),
      deviceListResult: _twoDevices,
    ),
    redirectToLogin: () {},
  );
  addTearDown(logic.onClose);
  logic.state.isLoading.value = false;
  logic.state.deviceList.value = List<Map>.of(_twoDevices);
  logic.state.choiceDevice.value = 0;
  return logic;
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
  _FakeDrinkApi({
    required this.favoResponse,
    this.throwOnFavo = false,
    List<Map>? deviceListResult,
    Completer<List<Map>>? pendingDeviceList,
  }) : deviceListResult = deviceListResult ?? const [],
       _pendingDeviceList = pendingDeviceList;

  static const DrinkResult _ok = DrinkResult(success: true, code: 0);

  final Future<bool> favoResponse;
  final bool throwOnFavo;
  final List<Map> deviceListResult;
  final Completer<List<Map>>? _pendingDeviceList;
  int deviceListCalls = 0;
  int favoDeviceCalls = 0;
  final List<String> favoRequestIds = <String>[];
  final List<String> startDrinkRequests = <String>[];
  final List<String> endDrinkRequests = <String>[];

  @override
  Future<List<Map>> deviceList() {
    deviceListCalls++;
    final Completer<List<Map>>? pending = _pendingDeviceList;
    if (pending != null) {
      return pending.future;
    }
    return Future<List<Map>>.value(deviceListResult);
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
  Future<DrinkResult> startDrink({required String id, int? ptype}) async {
    startDrinkRequests.add(id);
    return _ok;
  }

  @override
  Future<DrinkResult> endDrink({required String id}) async {
    endDrinkRequests.add(id);
    return _ok;
  }

  @override
  Future<bool> isAvailableDevice({required String id}) async => false;

  @override
  Future<DeviceStatusResult> deviceStatus({required String id}) async =>
      const DeviceStatusResult(
        success: true,
        code: 0,
        status: DrinkDeviceStatus(deviceStatus: 1, geneStatus: 99),
      );

  @override
  Future<String> resolveQrDevice({required String qrId}) async => '';

  @override
  Future<String> getToken() async => 'token';

  @override
  Future<void> setToken({required String token}) async {}
}
