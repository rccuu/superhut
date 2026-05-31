import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/ui/app_loading_indicator.dart';
import 'package:superhut/pages/Electricitybill/electricity_api.dart';
import 'package:superhut/pages/Electricitybill/electricity_page.dart';

void main() {
  testWidgets('initial room future is reused across parent rebuilds', (
    tester,
  ) async {
    final api = _FakeElectricityApi(
      roomInfoResponses: [
        Future.value({'roomName': '一舍101', 'eleTail': '30.00'}),
      ],
    );
    final balanceClient = _FakeElectricityBalanceClient(
      responses: [Future.value('100.00')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ElectricityPage(
          electricityApi: api,
          balanceClient: balanceClient,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('一舍101'));

    await tester.pumpWidget(
      MaterialApp(
        home: ElectricityPage(
          electricityApi: api,
          balanceClient: balanceClient,
        ),
      ),
    );
    await tester.pump();

    expect(api.onInitCalls, 1);
    expect(api.getHistoryCalls, 1);
    expect(api.getSingleRoomInfoCalls, 1);
  });

  testWidgets('initial room load failure hides raw error details', (
    tester,
  ) async {
    const rawError =
        '房间详情失败: https://v8mobile.hut.edu.cn/channel/queryRoomDetail?token=secret-token';
    final roomInfoCompleter = Completer<Map>();
    final api = _FakeElectricityApi(
      roomInfoResponses: [roomInfoCompleter.future],
    );
    final balanceClient = _FakeElectricityBalanceClient(
      responses: [Future.value('100.00')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ElectricityPage(
          electricityApi: api,
          balanceClient: balanceClient,
        ),
      ),
    );
    for (var i = 0; i < 10 && api.getSingleRoomInfoCalls == 0; i++) {
      await tester.pump();
    }
    roomInfoCompleter.completeError(StateError(rawError));
    await _pumpUntilFound(tester, find.text(electricityRoomLoadFailureMessage));

    expect(find.text(electricityRoomLoadFailureMessage), findsOneWidget);
    expect(find.textContaining('secret-token'), findsNothing);
    expect(find.textContaining('https://v8mobile.hut.edu.cn'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recharge applies refreshed room and balance together', (
    tester,
  ) async {
    final roomRefreshCompleter = Completer<Map>();
    final balanceRefreshCompleter = Completer<String>();
    final api = _FakeElectricityApi(
      roomInfoResponses: [
        Future.value({'roomName': '一舍101', 'eleTail': '30.00'}),
        roomRefreshCompleter.future,
      ],
    );
    final balanceClient = _FakeElectricityBalanceClient(
      responses: [Future.value('100.00'), balanceRefreshCompleter.future],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ElectricityPage(
          electricityApi: api,
          balanceClient: balanceClient,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('30.00'));
    await _pumpUntilFound(tester, find.text('100.00'));

    await tester.enterText(find.byType(TextField).first, '5');
    await tester.tap(find.widgetWithText(FilledButton, '充值'));
    await tester.pump();
    await _waitUntil(() => api.createOrderCalls == 1);

    balanceRefreshCompleter.complete('95.00');
    await tester.pump();

    expect(find.text('30.00'), findsOneWidget);
    expect(find.text('100.00'), findsOneWidget);
    expect(find.text('95.00'), findsNothing);

    roomRefreshCompleter.complete({'roomName': '一舍101', 'eleTail': '35.00'});
    await tester.pump();
    await tester.pump();

    expect(find.text('35.00'), findsOneWidget);
    expect(find.text('95.00'), findsOneWidget);
    expect(api.checkBeforeRechargeCalls, 1);
    expect(api.createOrderCalls, 1);
    expect(api.getSingleRoomInfoCalls, 2);
    expect(balanceClient.calls, 2);
  });

  testWidgets('stale balance refresh does not override latest balance', (
    tester,
  ) async {
    final staleBalanceCompleter = Completer<String>();
    final api = _FakeElectricityApi(
      roomInfoResponses: [
        Future.value({'roomName': '一舍101', 'eleTail': '30.00'}),
      ],
    );
    final balanceClient = _FakeElectricityBalanceClient(
      responses: [
        Future.value('100.00'),
        staleBalanceCompleter.future,
        Future.value('80.00'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ElectricityPage(
          electricityApi: api,
          balanceClient: balanceClient,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('一舍101'));
    await _pumpUntilFound(tester, find.text('100.00'));

    final dynamic pageState = tester.state(find.byType(ElectricityPage));
    final staleRefresh = pageState.getBalance() as Future<void>;
    await tester.pump();
    final latestRefresh = pageState.getBalance() as Future<void>;
    await latestRefresh;
    await tester.pump();

    expect(find.text('80.00'), findsOneWidget);

    staleBalanceCompleter.complete('60.00');
    await staleRefresh;
    await tester.pump();

    expect(find.text('80.00'), findsOneWidget);
    expect(find.text('60.00'), findsNothing);
    expect(balanceClient.calls, 3);
  });

  testWidgets('recharge ignores duplicate taps while charge is pending', (
    tester,
  ) async {
    final rechargeCheckCompleter = Completer<bool>();
    final api = _FakeElectricityApi(
      roomInfoResponses: [
        Future.value({'roomName': '一舍101', 'eleTail': '30.00'}),
        Future.value({'roomName': '一舍101', 'eleTail': '25.00'}),
      ],
      checkBeforeRecharge: (_) => rechargeCheckCompleter.future,
    );
    final balanceClient = _FakeElectricityBalanceClient(
      responses: [Future.value('100.00'), Future.value('95.00')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ElectricityPage(
          electricityApi: api,
          balanceClient: balanceClient,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('30.00'));
    await _pumpUntilFound(tester, find.text('100.00'));

    await tester.enterText(find.byType(TextField).first, '5');

    final rechargeButton = find.byType(FilledButton).first;
    final onPressed = tester.widget<FilledButton>(rechargeButton).onPressed;
    onPressed?.call();
    onPressed?.call();
    await tester.pump();

    expect(api.checkBeforeRechargeCalls, 1);
    expect(api.createOrderCalls, 0);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(rechargeButton).onPressed, isNull);

    rechargeCheckCompleter.complete(true);
    for (var i = 0; i < 5 && api.createOrderCalls == 0; i++) {
      await tester.pump();
    }

    expect(api.checkBeforeRechargeCalls, 1);
    expect(api.createOrderCalls, 1);
    expect(find.byType(AppLoadingIndicator), findsNothing);
  });

  testWidgets('room picker shows local loading state while room list loads', (
    tester,
  ) async {
    final roomListCompleter = Completer<List<dynamic>>();
    final api = _FakeElectricityApi(
      roomInfoResponses: [
        Future.value({'roomName': '一舍101', 'eleTail': '30.00'}),
      ],
      roomListResponses: [roomListCompleter.future],
    );
    final balanceClient = _FakeElectricityBalanceClient(
      responses: [Future.value('100.00')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ElectricityPage(
          electricityApi: api,
          balanceClient: balanceClient,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('一舍101'));

    final roomPicker = find.text('更改充值房间');
    await tester.tap(roomPicker);
    await tester.pump();

    expect(api.getRoomListCalls, 1);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);

    await tester.tap(roomPicker);
    await tester.pump();
    expect(api.getRoomListCalls, 1);

    roomListCompleter.complete([
      {'acname': '一舍101', 'acguid': 'room-1'},
      {'acname': '二舍202', 'acguid': 'room-2'},
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(AppLoadingIndicator), findsNothing);
    expect(find.text('二舍202'), findsOneWidget);
  });

  testWidgets('room list is reused across repeated picker openings', (
    tester,
  ) async {
    final api = _FakeElectricityApi(
      roomInfoResponses: [
        Future.value({'roomName': '一舍101', 'eleTail': '30.00'}),
      ],
      roomListResponses: [
        Future.value([
          {'acname': '一舍101', 'acguid': 'room-1'},
          {'acname': '二舍202', 'acguid': 'room-2'},
        ]),
      ],
    );
    final balanceClient = _FakeElectricityBalanceClient(
      responses: [Future.value('100.00')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ElectricityPage(
          electricityApi: api,
          balanceClient: balanceClient,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('一舍101'));

    await tester.tap(find.text('更改充值房间'));
    await tester.pumpAndSettle();
    expect(find.text('二舍202'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('更改充值房间'));
    await tester.pumpAndSettle();

    expect(api.getRoomListCalls, 1);
    expect(find.text('二舍202'), findsOneWidget);
  });

  testWidgets('room picker sheet ignores duplicate taps while open', (
    tester,
  ) async {
    final sheetCompleter = Completer<void>();
    final api = _FakeElectricityApi(
      roomInfoResponses: [
        Future.value({'roomName': '一舍101', 'eleTail': '30.00'}),
      ],
      roomListResponses: [
        Future.value([
          {'acname': '一舍101', 'acguid': 'room-1'},
          {'acname': '二舍202', 'acguid': 'room-2'},
        ]),
      ],
    );
    final balanceClient = _FakeElectricityBalanceClient(
      responses: [Future.value('100.00')],
    );
    var sheetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ElectricityPage(
          electricityApi: api,
          balanceClient: balanceClient,
          showBottomSheet: <T>({
            required BuildContext context,
            required WidgetBuilder builder,
            bool expand = false,
            Color? backgroundColor,
            Color? barrierColor,
            Color? transitionBackgroundColor,
            Radius? topRadius,
            BoxShadow? shadow,
          }) {
            sheetCalls++;
            return sheetCompleter.future.then<T?>((_) => null);
          },
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('一舍101'));

    final roomPicker = find.text('更改充值房间');
    await tester.ensureVisible(roomPicker);
    await tester.tap(roomPicker);
    await _waitUntil(() => sheetCalls == 1);
    await tester.pump();

    await tester.tap(roomPicker);
    await tester.pump();

    expect(sheetCalls, 1);
    expect(api.getRoomListCalls, 1);

    sheetCompleter.complete();
    await tester.pump();

    await tester.tap(roomPicker);
    await tester.pump();

    expect(sheetCalls, 2);
    expect(api.getRoomListCalls, 1);
  });

  testWidgets('stale room detail responses do not override latest room', (
    tester,
  ) async {
    final staleRoomCompleter = Completer<Map>();
    final api = _FakeElectricityApi(
      roomInfoResponses: [
        Future.value({'roomName': '一舍101', 'eleTail': '30.00'}),
        staleRoomCompleter.future,
        Future.value({'roomName': '三舍303', 'eleTail': '18.00'}),
      ],
    );
    final balanceClient = _FakeElectricityBalanceClient(
      responses: [Future.value('100.00')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ElectricityPage(
          electricityApi: api,
          balanceClient: balanceClient,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('一舍101'));

    final dynamic pageState = tester.state(find.byType(ElectricityPage));
    final firstLoad = pageState.getNewRoomInfo('room-2') as Future<bool>;
    await tester.pump();

    final secondLoad = pageState.getNewRoomInfo('room-3') as Future<bool>;
    await secondLoad;
    await tester.pump();

    expect(find.text('三舍303'), findsOneWidget);
    expect(find.text('18.00'), findsOneWidget);

    staleRoomCompleter.complete({'roomName': '二舍202', 'eleTail': '8.00'});
    final firstResult = await firstLoad;
    await tester.pump();

    expect(firstResult, isFalse);
    expect(find.text('三舍303'), findsOneWidget);
    expect(find.text('18.00'), findsOneWidget);
    expect(find.text('二舍202'), findsNothing);
    expect(find.text('8.00'), findsNothing);
    expect(api.requestedRoomIds, ['room-1', 'room-2', 'room-3']);
  });

  testWidgets('alert sheet ignores duplicate taps while settings are loading', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final prefsCompleter = Completer<SharedPreferences>();
    var prefsLoadCalls = 0;
    final api = _FakeElectricityApi(
      roomInfoResponses: [
        Future.value({'roomName': '一舍101', 'eleTail': '30.00'}),
      ],
    );
    final balanceClient = _FakeElectricityBalanceClient(
      responses: [Future.value('100.00')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ElectricityPage(
          electricityApi: api,
          balanceClient: balanceClient,
          loadPrefs: () {
            prefsLoadCalls++;
            return prefsCompleter.future;
          },
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('一舍101'));

    final alertTile = find.widgetWithText(ListTile, '电费预警');
    await tester.ensureVisible(alertTile);
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, -80));
    await tester.pump();
    await tester.tap(alertTile);
    await tester.tap(alertTile);
    await tester.pump();

    expect(prefsLoadCalls, 1);
    expect(find.text('输入预警金额'), findsNothing);

    prefsCompleter.complete(prefs);
    await tester.pumpAndSettle();

    expect(prefsLoadCalls, 1);
    expect(find.text('输入预警金额'), findsOneWidget);
  });

  testWidgets('alert save ignores duplicate taps while saving settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final savePrefsCompleter = Completer<SharedPreferences>();
    var prefsLoadCalls = 0;
    final api = _FakeElectricityApi(
      roomInfoResponses: [
        Future.value({'roomName': '一舍101', 'eleTail': '30.00'}),
      ],
    );
    final balanceClient = _FakeElectricityBalanceClient(
      responses: [Future.value('100.00')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ElectricityPage(
          electricityApi: api,
          balanceClient: balanceClient,
          loadPrefs: () {
            prefsLoadCalls++;
            if (prefsLoadCalls == 1) {
              return Future.value(prefs);
            }
            return savePrefsCompleter.future;
          },
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('一舍101'));

    final alertTile = find.widgetWithText(ListTile, '电费预警');
    await tester.ensureVisible(alertTile);
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, -80));
    await tester.pump();
    await tester.tap(alertTile);
    await _pumpUntilFound(tester, find.text('输入预警金额'));

    await tester.enterText(find.byType(TextField).last, '12');

    final saveButton = find.widgetWithText(FilledButton, '设置预警');
    final onPressed = tester.widget<FilledButton>(saveButton).onPressed;
    onPressed?.call();
    onPressed?.call();
    await tester.pump();

    expect(prefsLoadCalls, 2);

    savePrefsCompleter.complete(prefs);
    await _pumpUntilGone(tester, find.text('输入预警金额'));

    expect(prefs.getBool('enableBillWarning'), isTrue);
    expect(prefs.getString('enableRoomId'), 'room-1');
    expect(prefs.getDouble('enableBill'), 12);
    expect(find.text('输入预警金额'), findsNothing);
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60 && finder.evaluate().isNotEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(milliseconds: 100),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!predicate()) {
    if (stopwatch.elapsed >= timeout) {
      fail('Timed out while waiting for condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

class _FakeElectricityApi implements ElectricityApiClient {
  _FakeElectricityApi({
    required List<Future<Map>> roomInfoResponses,
    List<Future<List>> roomListResponses = const [],
    Future<bool> Function(String payRoomId)? checkBeforeRecharge,
  }) : _roomInfoResponses = List.of(roomInfoResponses),
       _roomListResponses = List.of(roomListResponses),
       _checkBeforeRecharge = checkBeforeRecharge;

  final List<Future<Map>> _roomInfoResponses;
  final List<Future<List>> _roomListResponses;
  final Future<bool> Function(String payRoomId)? _checkBeforeRecharge;
  int onInitCalls = 0;
  int getHistoryCalls = 0;
  int getSingleRoomInfoCalls = 0;
  int getRoomListCalls = 0;
  int checkBeforeRechargeCalls = 0;
  int createOrderCalls = 0;
  final List<String> requestedRoomIds = <String>[];

  @override
  Future<void> onInit() async {
    onInitCalls++;
  }

  @override
  Future<Map> getHistory() async {
    getHistoryCalls++;
    return {
      'factorycode': 'factory',
      'areaid': 'area',
      'roomid': 'room-1',
      'buildingid': 'building',
    };
  }

  @override
  Future<Map> getSingleRoomInfo(String troomid) {
    getSingleRoomInfoCalls++;
    requestedRoomIds.add(troomid);
    if (_roomInfoResponses.isEmpty) {
      return Future.value({'roomName': '一舍101', 'eleTail': '30.00'});
    }
    return _roomInfoResponses.removeAt(0);
  }

  @override
  Future<List> getRoomList() async {
    getRoomListCalls++;
    if (_roomListResponses.isEmpty) {
      return const [];
    }
    return _roomListResponses.removeAt(0);
  }

  @override
  Future<bool> checkBeforeRecharge(String payRoomId) {
    checkBeforeRechargeCalls++;
    final checkBeforeRecharge = _checkBeforeRecharge;
    if (checkBeforeRecharge != null) {
      return checkBeforeRecharge(payRoomId);
    }
    return Future.value(true);
  }

  @override
  Future<Map> createOrder(
    String payRoomId,
    String count,
    String payRoomName,
  ) async {
    createOrderCalls++;
    return {'payorderno': 'order-1', 'txdate': '2026-05-29', 'code': 'true'};
  }

  @override
  Future<void> finishRecharge(
    String payorderno,
    String count,
    String payRoomName,
  ) async {}
}

class _FakeElectricityBalanceClient implements ElectricityBalanceClient {
  _FakeElectricityBalanceClient({required List<Future<String>> responses})
    : _responses = List.of(responses);

  final List<Future<String>> _responses;
  int calls = 0;

  @override
  Future<String> getCardBalance() {
    calls++;
    if (_responses.isEmpty) {
      return Future.value('100.00');
    }
    return _responses.removeAt(0);
  }
}
