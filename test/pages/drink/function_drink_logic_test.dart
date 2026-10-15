import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:superhut/pages/drink/api/drink_result.dart';
import 'package:superhut/pages/drink/core/drink_device.dart';
import 'package:superhut/pages/drink/view/logic.dart';

const String _orderKey = 'device_order';
const String _layoutKey = 'device_list_layout';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({'hui798IsLogin': true});
  });

  tearDown(() {
    Get.reset();
  });

  test(
    'concurrent device refreshes send one request while in flight and replay '
    'the queued reload once',
    () async {
      // A13：在途期间不并发第二个请求，但不能丢掉这次重载要求，
      // 因此总共是 2 次（旧行为只有 1 次）。
      final firstResponse = Completer<List<Map>>();
      final api = _FakeDrinkApi(
        deviceListResponses: [
          firstResponse.future,
          Future.value([
            {'id': 'tap-1', 'name': '一栋饮水机'},
          ]),
        ],
        availabilityResults: const [],
      );
      final logic = FunctionDrinkLogic(drinkApi: api);
      addTearDown(logic.onClose);

      final firstLoad = logic.getDeviceList(showRefreshing: true);
      final secondLoad = logic.getDeviceList(showRefreshing: true);
      await Future<void>.delayed(Duration.zero);

      expect(api.deviceListCalls, 1);
      expect(logic.state.isRefreshing.value, isTrue);

      firstResponse.complete([
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ]);
      await _waitUntil(
        () => api.deviceListCalls == 2,
        timeout: const Duration(milliseconds: 200),
      );
      await Future.wait([firstLoad, secondLoad]);

      expect(api.deviceListCalls, 2);
      expect(logic.state.deviceList, hasLength(1));
      expect(logic.state.choiceDevice.value, 0);
      expect(logic.state.isRefreshing.value, isFalse);
    },
  );

  test(
    'replayed reload surfaces a device added during the in-flight refresh',
    () async {
      final firstResponse = Completer<List<Map>>();
      final api = _FakeDrinkApi(
        deviceListResponses: [
          firstResponse.future,
          Future.value([
            {'id': 'tap-1', 'name': '一栋饮水机'},
            {'id': 'tap-2', 'name': '二栋饮水机'},
          ]),
        ],
        availabilityResults: const [],
      );
      final logic = FunctionDrinkLogic(drinkApi: api);
      addTearDown(logic.onClose);

      final firstLoad = logic.getDeviceList();
      // 扫码添加成功后立刻又要求刷新：这一次不能因为在途而被丢弃。
      logic.getDeviceList();
      await Future<void>.delayed(Duration.zero);

      expect(api.deviceListCalls, 1);

      firstResponse.complete([
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ]);
      await firstLoad;

      expect(api.deviceListCalls, 2);
      expect(logic.state.deviceList.map(drinkDeviceId).toList(), [
        'tap-1',
        'tap-2',
      ]);
      expect(logic.state.isLoading.value, isFalse);
      expect(logic.state.isRefreshing.value, isFalse);
    },
  );

  test('account failure does not replay the queued reload', () async {
    final firstResponse = Completer<List<Map>>();
    final api = _FakeDrinkApi(
      deviceListResponses: [
        firstResponse.future,
        Future.value([
          {'id': '404', 'name': 'Account failure'},
        ]),
      ],
      availabilityResults: const [],
    );
    var loginRedirects = 0;
    final logic = FunctionDrinkLogic(
      drinkApi: api,
      redirectToLogin: () {
        loginRedirects++;
      },
    );
    addTearDown(logic.onClose);

    final firstLoad = logic.getDeviceList();
    logic.getDeviceList();
    await Future<void>.delayed(Duration.zero);
    expect(api.deviceListCalls, 1);

    firstResponse.complete([
      {'id': '404', 'name': 'Account failure'},
    ]);
    await firstLoad;

    expect(api.deviceListCalls, 1);
    expect(loginRedirects, 1);
    expect(logic.state.deviceList, isEmpty);
    expect(logic.state.choiceDevice.value, -1);
    expect(logic.state.isLoading.value, isFalse);
    expect(logic.state.isRefreshing.value, isFalse);
  });

  test(
    'device refresh exposes loading state through reactive fields',
    () async {
      final deviceListCompleter = Completer<List<Map>>();
      final api = _FakeDrinkApi(
        deviceListResponses: [deviceListCompleter.future],
        availabilityResults: const [],
      );
      final logic = FunctionDrinkLogic(drinkApi: api);
      addTearDown(logic.onClose);

      final refresh = logic.getDeviceList(showLoading: true);
      await Future<void>.delayed(Duration.zero);

      expect(api.deviceListCalls, 1);
      expect(logic.state.isLoading.value, isTrue);
      expect(logic.state.isRefreshing.value, isFalse);
      expect(logic.state.deviceList, isEmpty);

      deviceListCompleter.complete([
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ]);
      await refresh;

      expect(logic.state.deviceList, hasLength(1));
      expect(logic.state.choiceDevice.value, 0);
      expect(logic.state.isLoading.value, isFalse);
    },
  );

  test('device refresh drops late result after controller closes', () async {
    final deviceListCompleter = Completer<List<Map>>();
    final api = _FakeDrinkApi(
      deviceListResponses: [deviceListCompleter.future],
      availabilityResults: const [],
    );
    final logic = FunctionDrinkLogic(drinkApi: api);

    final refresh = logic.getDeviceList(showRefreshing: true);
    await Future<void>.delayed(Duration.zero);

    expect(api.deviceListCalls, 1);
    expect(logic.state.isRefreshing.value, isTrue);

    logic.onClose();
    deviceListCompleter.complete([
      {'id': 'tap-1', 'name': '一栋饮水机'},
    ]);
    await refresh;

    expect(logic.state.deviceList, isEmpty);
    expect(logic.state.choiceDevice.value, -1);
    expect(logic.state.isRefreshing.value, isTrue);
  });

  test('initialize skips token request when device load closes late', () async {
    final deviceListCompleter = Completer<List<Map>>();
    final api = _FakeDrinkApi(
      deviceListResponses: [deviceListCompleter.future],
      availabilityResults: const [],
    );
    final logic = FunctionDrinkLogic(drinkApi: api);

    logic.onInit();
    await _waitUntil(
      () => api.deviceListCalls == 1,
      timeout: const Duration(milliseconds: 100),
    );

    logic.onClose();
    deviceListCompleter.complete([
      {'id': 'tap-1', 'name': '一栋饮水机'},
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(api.getTokenCalls, 0);
  });

  test('checkLogin stops before token work when not logged in', () async {
    SharedPreferences.setMockInitialValues({'hui798IsLogin': false});
    final api = _FakeDrinkApi(availabilityResults: const []);
    var loginRedirects = 0;
    final logic = FunctionDrinkLogic(
      drinkApi: api,
      redirectToLogin: () {
        loginRedirects++;
      },
    );
    addTearDown(logic.onClose);

    final isLoggedIn = await logic.checkLogin();

    expect(isLoggedIn, isFalse);
    expect(loginRedirects, 1);
    expect(api.deviceListCalls, 0);
    expect(api.getTokenCalls, 0);
    expect(logic.state.isLoading.value, isFalse);
  });

  test('initialize skips late token write after controller closes', () async {
    final tokenCompleter = Completer<String>();
    final api = _FakeDrinkApi(
      deviceListResult: const [],
      availabilityResults: const [],
      tokenResponse: tokenCompleter.future,
    );
    final logic = FunctionDrinkLogic(drinkApi: api);

    logic.onInit();
    await _waitUntil(
      () => api.getTokenCalls == 1,
      timeout: const Duration(milliseconds: 100),
    );

    logic.onClose();
    tokenCompleter.complete('late-token');
    await Future<void>.delayed(Duration.zero);

    expect(api.getTokenCalls, 1);
  });

  test('repeated logged-out checks queue one login redirect', () async {
    SharedPreferences.setMockInitialValues({'hui798IsLogin': false});
    final api = _FakeDrinkApi(availabilityResults: const []);
    var loginRedirects = 0;
    final logic = FunctionDrinkLogic(
      drinkApi: api,
      redirectToLogin: () {
        loginRedirects++;
      },
    );
    addTearDown(logic.onClose);

    final firstCheck = await logic.checkLogin();
    final secondCheck = await logic.checkLogin();

    expect(firstCheck, isFalse);
    expect(secondCheck, isFalse);
    expect(loginRedirects, 1);
    expect(api.deviceListCalls, 0);
  });

  test('account failure queues one login redirect', () async {
    final api = _FakeDrinkApi(
      deviceListResult: const [
        {'id': '404', 'name': 'Account failure'},
      ],
      availabilityResults: const [],
    );
    var loginRedirects = 0;
    final logic = FunctionDrinkLogic(
      drinkApi: api,
      redirectToLogin: () {
        loginRedirects++;
      },
    );
    addTearDown(logic.onClose);

    await logic.getDeviceList(showLoading: true);
    await logic.getDeviceList(showLoading: true);
    final prefs = await SharedPreferences.getInstance();

    expect(api.deviceListCalls, 2);
    expect(loginRedirects, 1);
    expect(prefs.getBool('hui798IsLogin'), isFalse);
    expect(logic.state.deviceList, isEmpty);
    expect(logic.state.choiceDevice.value, -1);
    expect(logic.state.drinkStatus.value, isFalse);
  });

  test('setToken saves login state and refreshes devices once', () async {
    SharedPreferences.setMockInitialValues({'hui798IsLogin': false});
    final api = _FakeDrinkApi(
      deviceListResult: [
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ],
      availabilityResults: const [],
    );
    final logic = FunctionDrinkLogic(drinkApi: api);
    addTearDown(logic.onClose);

    await logic.setToken('fresh-token');
    final prefs = await SharedPreferences.getInstance();

    expect(api.setTokenCalls, 1);
    expect(api.lastToken, 'fresh-token');
    expect(api.deviceListCalls, 1);
    expect(prefs.getBool('hui798IsLogin'), isTrue);
    expect(logic.state.deviceList, hasLength(1));
    expect(logic.state.choiceDevice.value, 0);
    expect(logic.state.isLoading.value, isFalse);
  });

  test(
    'concurrent favoDevice calls for same action share one in-flight request',
    () async {
      final favoCompleter = Completer<bool>();
      final api = _FakeDrinkApi(
        availabilityResults: const [],
        favoResponses: [favoCompleter.future],
      );
      final logic = FunctionDrinkLogic(drinkApi: api);
      addTearDown(logic.onClose);

      final firstFavo = logic.favoDevice('tap-1', false);
      final secondFavo = logic.favoDevice('tap-1', false);
      await Future<void>.delayed(Duration.zero);

      expect(api.favoDeviceCalls, 1);
      expect(api.favoRequestKeys, ['favo:tap-1']);

      favoCompleter.complete(true);
      final results = await Future.wait([firstFavo, secondFavo]);

      expect(results, [true, true]);
      expect(api.favoDeviceCalls, 1);
    },
  );

  test('favoDevice keeps favorite and unfavorite requests separate', () async {
    final favoCompleter = Completer<bool>();
    final unfavoCompleter = Completer<bool>();
    final api = _FakeDrinkApi(
      availabilityResults: const [],
      favoResponses: [favoCompleter.future, unfavoCompleter.future],
    );
    final logic = FunctionDrinkLogic(drinkApi: api);
    addTearDown(logic.onClose);

    final favo = logic.favoDevice('tap-1', false);
    final unfavo = logic.favoDevice('tap-1', true);
    await Future<void>.delayed(Duration.zero);

    expect(api.favoDeviceCalls, 2);
    expect(api.favoRequestKeys, ['favo:tap-1', 'unfavo:tap-1']);

    favoCompleter.complete(true);
    unfavoCompleter.complete(false);
    final results = await Future.wait([favo, unfavo]);

    expect(results, [true, false]);
    expect(api.favoDeviceCalls, 2);
  });

  test('removeDeviceByName compacts devices and clamps selected index', () {
    final logic = FunctionDrinkLogic(
      drinkApi: _FakeDrinkApi(availabilityResults: const []),
    );
    addTearDown(logic.onClose);

    logic.state.deviceList.value = [
      {'id': 'tap-1', 'name': '一栋饮水机'},
      {'id': 'tap-2', 'name': '二栋饮水机'},
      {'id': 'tap-3', 'name': '二栋饮水机'},
      {'id': 'tap-4', 'name': '三栋饮水机'},
    ];
    logic.state.choiceDevice.value = 3;
    logic.state.drinkStatus.value = true;

    logic.removeDeviceByName('二栋饮水机');

    expect(logic.state.deviceList, [
      {'id': 'tap-1', 'name': '一栋饮水机'},
      {'id': 'tap-4', 'name': '三栋饮水机'},
    ]);
    expect(logic.state.choiceDevice.value, 1);
    expect(logic.state.drinkStatus.value, isTrue);

    logic.removeDeviceByName('一栋饮水机');
    logic.removeDeviceByName('三栋饮水机');

    expect(logic.state.deviceList, isEmpty);
    expect(logic.state.choiceDevice.value, -1);
    expect(logic.state.drinkStatus.value, isFalse);
  });

  test(
    'formatDeviceName scans building marker without changing plain names',
    () {
      final logic = FunctionDrinkLogic(
        drinkApi: _FakeDrinkApi(availabilityResults: const []),
      );
      addTearDown(logic.onClose);

      final plainName = '饮水机A';

      expect(logic.formatDeviceName(plainName), same(plainName));
      expect(logic.formatDeviceName('一栋饮水机'), '一-饮水机');
      expect(logic.formatDeviceName('一栋二栋饮水机'), '一-二-饮水机');
      expect(logic.formatDeviceName('栋'), '-');
    },
  );

  test(
    'status polling is serial and stops after stable availability',
    () async {
      final api = _FakeDrinkApi(
        deviceListResult: [
          {'id': 'tap-1', 'name': '一栋饮水机'},
        ],
        availabilityResults: [false, true, true],
        availabilityDelay: const Duration(milliseconds: 2),
      );
      final logic = FunctionDrinkLogic(
        drinkApi: api,
        statusPollInterval: const Duration(milliseconds: 1),
        requiredAvailablePolls: 2,
      );
      addTearDown(logic.onClose);

      logic.state.deviceList.value = [
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ];
      logic.state.choiceDevice.value = 0;

      await logic.startDrink();

      expect(api.startDrinkCalls, 1);
      expect(logic.state.drinkStatus.value, isTrue);
      expect(api.maxConcurrentAvailabilityRequests, 0);

      await _waitUntil(
        () => !logic.state.drinkStatus.value,
        timeout: const Duration(milliseconds: 80),
      );

      expect(api.availabilityCalls, 3);
      expect(logic.state.drinkStatus.value, isFalse);
      expect(api.maxConcurrentAvailabilityRequests, 1);

      await _pumpTimers(const Duration(milliseconds: 8));
      expect(api.availabilityCalls, 3);
    },
  );

  test('endDrink cancels pending status polling', () async {
    final api = _FakeDrinkApi(
      deviceListResult: [
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ],
      availabilityResults: [false, false, false],
    );
    final logic = FunctionDrinkLogic(
      drinkApi: api,
      statusPollInterval: const Duration(milliseconds: 4),
    );
    addTearDown(logic.onClose);

    logic.state.deviceList.value = [
      {'id': 'tap-1', 'name': '一栋饮水机'},
    ];
    logic.state.choiceDevice.value = 0;

    await logic.startDrink();
    expect(logic.state.drinkStatus.value, isTrue);

    await logic.endDrink();
    expect(api.endDrinkCalls, 1);
    expect(logic.state.drinkStatus.value, isFalse);

    await _pumpTimers(const Duration(milliseconds: 10));
    expect(api.availabilityCalls, 0);
  });

  test(
    'concurrent startDrink calls share a single in-flight request',
    () async {
      final startCompleter = Completer<DrinkResult>();
      final api = _FakeDrinkApi(
        deviceListResult: [
          {'id': 'tap-1', 'name': '一栋饮水机'},
        ],
        availabilityResults: const [],
        startDrinkResponses: [startCompleter.future],
      );
      final logic = FunctionDrinkLogic(drinkApi: api);
      addTearDown(logic.onClose);

      logic.state.deviceList.value = [
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ];
      logic.state.choiceDevice.value = 0;

      final firstStart = logic.startDrink();
      final secondStart = logic.startDrink();
      await Future<void>.delayed(Duration.zero);

      expect(api.startDrinkCalls, 1);

      startCompleter.complete(const DrinkResult(success: true, code: 0));
      await Future.wait([firstStart, secondStart]);
      await Future<void>.delayed(Duration.zero);

      expect(api.startDrinkCalls, 1);
      expect(logic.state.drinkStatus.value, isTrue);
    },
  );

  test('startDrink converts api errors to retryable failures', () async {
    final api = _FakeDrinkApi(
      deviceListResult: [
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ],
      availabilityResults: const [],
      startDrinkResponses: [
        Future<DrinkResult>.error(Exception('start unavailable')),
        Future.value(const DrinkResult(success: true, code: 0)),
      ],
    );
    final logic = FunctionDrinkLogic(drinkApi: api);
    addTearDown(logic.onClose);

    logic.state.deviceList.value = [
      {'id': 'tap-1', 'name': '一栋饮水机'},
    ];
    logic.state.choiceDevice.value = 0;

    await logic.startDrink();

    expect(api.startDrinkCalls, 1);
    expect(logic.state.drinkStatus.value, isFalse);

    await logic.startDrink();

    expect(api.startDrinkCalls, 2);
    expect(logic.state.drinkStatus.value, isTrue);
  });

  test(
    'drink operations ignore invalid selected device without api request',
    () async {
      final api = _FakeDrinkApi(availabilityResults: const []);
      final logic = FunctionDrinkLogic(drinkApi: api);
      addTearDown(logic.onClose);

      logic.state.deviceList.value = [
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ];
      logic.state.choiceDevice.value = 1;

      await logic.startDrink();

      expect(api.startDrinkCalls, 0);
      expect(logic.state.drinkStatus.value, isFalse);

      logic.state.drinkStatus.value = true;
      logic.state.choiceDevice.value = -1;

      await logic.endDrink();

      expect(api.endDrinkCalls, 0);
      expect(logic.state.drinkStatus.value, isTrue);
    },
  );

  test('concurrent endDrink calls share a single in-flight request', () async {
    final endCompleter = Completer<DrinkResult>();
    final api = _FakeDrinkApi(
      availabilityResults: const [],
      endDrinkResponses: [endCompleter.future],
    );
    final logic = FunctionDrinkLogic(drinkApi: api);
    addTearDown(logic.onClose);

    logic.state.deviceList.value = [
      {'id': 'tap-1', 'name': '一栋饮水机'},
    ];
    logic.state.choiceDevice.value = 0;
    logic.state.drinkStatus.value = true;

    final firstEnd = logic.endDrink();
    final secondEnd = logic.endDrink();
    await Future<void>.delayed(Duration.zero);

    expect(api.endDrinkCalls, 1);

    endCompleter.complete(const DrinkResult(success: true, code: 0));
    await Future.wait([firstEnd, secondEnd]);

    expect(api.endDrinkCalls, 1);
    expect(logic.state.drinkStatus.value, isFalse);
  });

  test('endDrink converts api errors to retryable failures', () async {
    final api = _FakeDrinkApi(
      availabilityResults: const [],
      endDrinkResponses: [
        Future<DrinkResult>.error(Exception('end unavailable')),
        Future.value(const DrinkResult(success: true, code: 0)),
      ],
    );
    final logic = FunctionDrinkLogic(drinkApi: api);
    addTearDown(logic.onClose);

    logic.state.deviceList.value = [
      {'id': 'tap-1', 'name': '一栋饮水机'},
    ];
    logic.state.choiceDevice.value = 0;
    logic.state.drinkStatus.value = true;

    // 结算请求异常同样要退出接水态：不能让页面卡在「正在接水」。
    await logic.endDrink();

    expect(api.endDrinkCalls, 1);
    expect(logic.state.drinkStatus.value, isFalse);

    await logic.endDrink();

    expect(api.endDrinkCalls, 2);
    expect(logic.state.drinkStatus.value, isFalse);
  });

  test(
    'failed settle leaves the page out of the drinking state and stops polling',
    () async {
      final api = _FakeDrinkApi(
        availabilityResults: const [],
        endDrinkResponses: [
          Future.value(
            const DrinkResult(success: false, code: 500, message: '结算超时'),
          ),
        ],
      );
      final logic = FunctionDrinkLogic(
        drinkApi: api,
        statusPollInterval: const Duration(milliseconds: 2),
      );
      addTearDown(logic.onClose);

      logic.state.deviceList.value = [
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ];
      logic.state.choiceDevice.value = 0;
      logic.state.drinkStatus.value = true;

      await logic.endDrink();
      await _pumpTimers(const Duration(milliseconds: 10));

      expect(api.endDrinkCalls, 1);
      expect(api.endDrinkRequests, ['tap-1']);
      expect(logic.state.drinkStatus.value, isFalse);
      expect(logic.state.deviceStatusTimer, isNull);
      expect(api.availabilityCalls, 0);
    },
  );

  test(
    'failed start keeps the drinking state off and never polls status',
    () async {
      final api = _FakeDrinkApi(
        availabilityResults: const [],
        startDrinkResponses: [
          Future.value(const DrinkResult(success: false, code: -99)),
        ],
      );
      final logic = FunctionDrinkLogic(
        drinkApi: api,
        statusPollInterval: const Duration(milliseconds: 2),
      );
      addTearDown(logic.onClose);

      logic.state.deviceList.value = [
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ];
      logic.state.choiceDevice.value = 0;

      await logic.startDrink();
      await _pumpTimers(const Duration(milliseconds: 10));

      expect(api.startDrinkRequests, ['tap-1']);
      expect(logic.state.drinkStatus.value, isFalse);
      expect(logic.state.deviceStatusTimer, isNull);
      expect(api.availabilityCalls, 0);
    },
  );

  group('device order', () {
    test('applyDrinkDeviceOrder follows the saved order for known ids', () {
      final devices = <Map>[
        {'id': 'tap-1', 'name': '一栋饮水机'},
        {'id': 'tap-2', 'name': '二栋饮水机'},
        {'id': 'tap-3', 'name': '三栋饮水机'},
      ];

      final ordered = applyDrinkDeviceOrder(devices, ['tap-3', 'tap-1']);

      expect(ordered.map(drinkDeviceId).toList(), [
        'tap-3',
        'tap-1',
        'tap-2',
      ], reason: '已知名按保存顺序在前，未知名保持原有相对顺序追加');
    });

    test('applyDrinkDeviceOrder ignores saved ids that are gone', () {
      final devices = <Map>[
        {'id': 'tap-1', 'name': '一栋饮水机'},
        {'id': 'tap-2', 'name': '二栋饮水机'},
      ];

      final ordered = applyDrinkDeviceOrder(devices, [
        'tap-offline',
        'tap-2',
        'tap-1',
      ]);

      expect(ordered.map(drinkDeviceId).toList(), ['tap-2', 'tap-1']);
    });

    test('applyDrinkDeviceOrder repeats each saved id only once', () {
      final devices = <Map>[
        {'id': 'tap-1', 'name': '一栋饮水机'},
        {'id': 'tap-2', 'name': '二栋饮水机'},
        {'id': 'tap-3', 'name': '三栋饮水机'},
      ];

      final ordered = applyDrinkDeviceOrder(devices, [
        'tap-2',
        'tap-2',
        'tap-1',
      ]);

      expect(ordered.map(drinkDeviceId).toList(), ['tap-2', 'tap-1', 'tap-3']);
    });

    test(
      'applyDrinkDeviceOrder drops id-less rows once a saved order exists',
      () {
        // 顺序以 id 为键，没有 id 的行无法参与排序；当前实现在存在保存顺序时
        // 把它们排除在外（无保存顺序时原样返回）。此处钉住现状，改动需评审。
        final devices = <Map>[
          {'id': 'tap-1', 'name': '一栋饮水机'},
          {'name': '缺少 id 的设备'},
        ];

        expect(
          applyDrinkDeviceOrder(devices, const []).map(drinkDeviceId).toList(),
          ['tap-1', ''],
        );
        expect(
          applyDrinkDeviceOrder(devices, ['tap-1']).map(drinkDeviceId).toList(),
          ['tap-1'],
        );
      },
    );

    test(
      'applyDrinkDeviceOrder with an empty saved order leaves the list as is',
      () {
        final devices = <Map>[
          {'id': 'tap-1', 'name': '一栋饮水机'},
          {'id': 'tap-2', 'name': '二栋饮水机'},
        ];

        expect(applyDrinkDeviceOrder(devices, const []), devices);
        expect(applyDrinkDeviceOrder(const <Map>[], const ['tap-1']), isEmpty);
      },
    );

    test('drinkDeviceId and drinkDeviceName tolerate non-map rows', () {
      expect(drinkDeviceId('not a device'), '');
      expect(drinkDeviceName('not a device'), '未知设备');
      expect(drinkDeviceId({'id': 12, 'name': null}), '12');
      expect(drinkDeviceName({'id': '12'}), '未知设备');
    });

    test(
      'reorderDevices reorders, keeps selection by id and persists order',
      () async {
        final logic = FunctionDrinkLogic(
          drinkApi: _FakeDrinkApi(availabilityResults: const []),
        );
        addTearDown(logic.onClose);
        logic.state.deviceList.value = [
          {'id': 'tap-1', 'name': '一栋饮水机'},
          {'id': 'tap-2', 'name': '二栋饮水机'},
          {'id': 'tap-3', 'name': '三栋饮水机'},
        ];
        logic.state.choiceDevice.value = 0;

        // ReorderableListView 约定：向下移动时 newIndex 含被拖条目原位。
        logic.reorderDevices(0, 3);

        expect(logic.state.deviceList.map(drinkDeviceId).toList(), [
          'tap-2',
          'tap-3',
          'tap-1',
        ]);
        expect(logic.state.choiceDevice.value, 2, reason: '重排后选中的仍是同一台设备');

        final prefs = await SharedPreferences.getInstance();
        await _waitUntil(
          () => prefs.getStringList(_orderKey) != null,
          timeout: const Duration(milliseconds: 200),
        );
        expect(prefs.getStringList(_orderKey), ['tap-2', 'tap-3', 'tap-1']);
      },
    );

    test('reorderDevices ignores out-of-range indexes', () async {
      final logic = FunctionDrinkLogic(
        drinkApi: _FakeDrinkApi(availabilityResults: const []),
      );
      addTearDown(logic.onClose);
      logic.state.deviceList.value = [
        {'id': 'tap-1', 'name': '一栋饮水机'},
        {'id': 'tap-2', 'name': '二栋饮水机'},
      ];
      logic.state.choiceDevice.value = 0;

      logic.reorderDevices(-1, 1);
      logic.reorderDevices(0, 9);
      logic.reorderDevices(5, 1);

      expect(logic.state.deviceList.map(drinkDeviceId).toList(), [
        'tap-1',
        'tap-2',
      ]);
      expect(logic.state.choiceDevice.value, 0);
    });

    test('saved order round-trips through a reload', () async {
      final api = _FakeDrinkApi(
        deviceListResult: [
          {'id': 'tap-1', 'name': '一栋饮水机'},
          {'id': 'tap-2', 'name': '二栋饮水机'},
          {'id': 'tap-3', 'name': '三栋饮水机'},
        ],
        availabilityResults: const [],
      );
      final logic = FunctionDrinkLogic(drinkApi: api);
      addTearDown(logic.onClose);
      logic.state.deviceList.value = List.of(api.deviceListResult);
      logic.state.choiceDevice.value = 0;

      logic.reorderDevices(2, 0);
      final prefs = await SharedPreferences.getInstance();
      await _waitUntil(
        () => prefs.getStringList(_orderKey) != null,
        timeout: const Duration(milliseconds: 200),
      );
      expect(prefs.getStringList(_orderKey), ['tap-3', 'tap-1', 'tap-2']);

      // 重新进入页面：由本地保存的顺序恢复，而不是服务端顺序。
      final reloaded = FunctionDrinkLogic(drinkApi: api);
      addTearDown(reloaded.onClose);
      await reloaded.getDeviceList();

      expect(reloaded.state.deviceList.map(drinkDeviceId).toList(), [
        'tap-3',
        'tap-1',
        'tap-2',
      ]);
      expect(reloaded.state.choiceDevice.value, 0);
    });

    test(
      'selection survives a reload that shuffles the server order',
      () async {
        final api = _FakeDrinkApi(
          deviceListResponses: [
            Future.value([
              {'id': 'tap-1', 'name': '一栋饮水机'},
              {'id': 'tap-2', 'name': '二栋饮水机'},
              {'id': 'tap-3', 'name': '三栋饮水机'},
            ]),
            Future.value([
              {'id': 'tap-3', 'name': '三栋饮水机'},
              {'id': 'tap-1', 'name': '一栋饮水机'},
              {'id': 'tap-2', 'name': '二栋饮水机'},
            ]),
          ],
          availabilityResults: const [],
        );
        final logic = FunctionDrinkLogic(drinkApi: api);
        addTearDown(logic.onClose);

        await logic.getDeviceList();
        logic.state.choiceDevice.value = 2;
        expect(drinkDeviceId(logic.state.deviceList[2]), 'tap-3');

        await logic.getDeviceList();

        expect(
          drinkDeviceId(logic.state.deviceList[logic.state.choiceDevice.value]),
          'tap-3',
        );
        expect(logic.state.choiceDevice.value, 0);
      },
    );

    test('removeDeviceByName persists the remaining order', () async {
      final logic = FunctionDrinkLogic(
        drinkApi: _FakeDrinkApi(availabilityResults: const []),
      );
      addTearDown(logic.onClose);
      logic.state.deviceList.value = [
        {'id': 'tap-1', 'name': '一栋饮水机'},
        {'id': 'tap-2', 'name': '二栋饮水机'},
      ];
      logic.state.choiceDevice.value = 0;

      logic.removeDeviceByName('二栋饮水机');

      final prefs = await SharedPreferences.getInstance();
      await _waitUntil(
        () => prefs.getStringList(_orderKey)?.contains('tap-2') == false,
        timeout: const Duration(milliseconds: 200),
      );
      expect(prefs.getStringList(_orderKey), ['tap-1']);
    });
  });

  group('layout mode', () {
    test(
      'setLayoutMode persists valid modes and ignores invalid ones',
      () async {
        final logic = FunctionDrinkLogic(
          drinkApi: _FakeDrinkApi(availabilityResults: const []),
        );
        addTearDown(logic.onClose);
        final prefs = await SharedPreferences.getInstance();

        await logic.setLayoutMode('grid');
        expect(logic.state.layoutMode.value, 'grid');
        expect(prefs.getString(_layoutKey), 'grid');

        await logic.setLayoutMode('rows');
        expect(logic.state.layoutMode.value, 'grid');
        expect(prefs.getString(_layoutKey), 'grid');

        await logic.setLayoutMode('list');
        expect(logic.state.layoutMode.value, 'list');
        expect(prefs.getString(_layoutKey), 'list');

        // 同值写入直接返回，不再重复落盘。
        final beforeWrites = prefs.getString(_layoutKey);
        await logic.setLayoutMode('list');
        expect(beforeWrites, 'list');
        expect(prefs.getString(_layoutKey), 'list');
      },
    );

    test('initialize restores the saved layout', () async {
      SharedPreferences.setMockInitialValues({
        'hui798IsLogin': true,
        _layoutKey: 'grid',
      });
      final logic = FunctionDrinkLogic(
        drinkApi: _FakeDrinkApi(
          deviceListResult: _savedDevices,
          availabilityResults: const [],
        ),
      );
      addTearDown(logic.onClose);

      logic.onInit();
      await _waitUntil(
        () => logic.state.deviceList.isNotEmpty,
        timeout: const Duration(milliseconds: 200),
      );

      expect(logic.state.layoutMode.value, 'grid');
    });

    test(
      'initialize ignores a saved layout that is not list or grid',
      () async {
        SharedPreferences.setMockInitialValues({
          'hui798IsLogin': true,
          _layoutKey: 'rows',
        });
        final logic = FunctionDrinkLogic(
          drinkApi: _FakeDrinkApi(
            deviceListResult: _savedDevices,
            availabilityResults: const [],
          ),
        );
        addTearDown(logic.onClose);

        logic.onInit();
        await _waitUntil(
          () => logic.state.deviceList.isNotEmpty,
          timeout: const Duration(milliseconds: 200),
        );

        expect(logic.state.layoutMode.value, 'list');
      },
    );
  });

  group('device notes', () {
    test(
      'saveDeviceNote writes and clears the note shown by deviceTitle',
      () async {
        final logic = FunctionDrinkLogic(
          drinkApi: _FakeDrinkApi(availabilityResults: const []),
        );
        addTearDown(logic.onClose);
        logic.state.deviceList.value = [
          {'id': 'tap-1', 'name': '一栋饮水机'},
        ];
        final prefs = await SharedPreferences.getInstance();

        expect(logic.deviceTitle(logic.state.deviceList[0]), '一-饮水机');

        await logic.saveDeviceNote('tap-1', '三楼东侧');

        expect(prefs.getString('device_note_tap-1'), '三楼东侧');
        expect(logic.state.deviceNotes['tap-1'], '三楼东侧');
        expect(logic.deviceTitle(logic.state.deviceList[0]), '三楼东侧');

        await logic.saveDeviceNote('tap-1', '');

        expect(prefs.containsKey('device_note_tap-1'), isFalse);
        expect(logic.state.deviceNotes.containsKey('tap-1'), isFalse);
        expect(logic.deviceTitle(logic.state.deviceList[0]), '一-饮水机');

        // 空 id 不写入任何键。
        await logic.saveDeviceNote('', '无效备注');
        expect(prefs.getString('device_note_'), isNull);
      },
    );

    test('reload restores saved notes and ignores empty ones', () async {
      SharedPreferences.setMockInitialValues({
        'hui798IsLogin': true,
        'device_note_tap-1': '三楼东侧',
        'device_note_tap-2': '',
      });
      final logic = FunctionDrinkLogic(
        drinkApi: _FakeDrinkApi(
          deviceListResult: const [
            {'id': 'tap-1', 'name': '一栋饮水机'},
            {'id': 'tap-2', 'name': '二栋饮水机'},
          ],
          availabilityResults: const [],
        ),
      );
      addTearDown(logic.onClose);

      await logic.getDeviceList();

      expect(logic.state.deviceNotes, {'tap-1': '三楼东侧'});
      expect(logic.deviceTitle(logic.state.deviceList[0]), '三楼东侧');
      expect(logic.deviceTitle(logic.state.deviceList[1]), '二-饮水机');
    });
  });

  group('guards while drinking', () {
    test('setChoiceDevice refuses to switch devices while drinking', () async {
      final logic = FunctionDrinkLogic(
        drinkApi: _FakeDrinkApi(availabilityResults: const []),
      );
      addTearDown(logic.onClose);
      logic.state.deviceList.value = [
        {'id': 'tap-1', 'name': '一栋饮水机'},
        {'id': 'tap-2', 'name': '二栋饮水机'},
      ];
      logic.state.choiceDevice.value = 0;
      logic.state.drinkStatus.value = true;

      logic.setChoiceDevice(1);
      expect(logic.state.choiceDevice.value, 0);

      logic.state.drinkStatus.value = false;
      logic.setChoiceDevice(1);
      expect(logic.state.choiceDevice.value, 1);
    });

    test('toggleReorderMode refuses while drinking and no-ops when empty', () {
      final logic = FunctionDrinkLogic(
        drinkApi: _FakeDrinkApi(availabilityResults: const []),
      );
      addTearDown(logic.onClose);
      logic.state.deviceList.value = [
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ];

      logic.state.drinkStatus.value = true;
      logic.toggleReorderMode();
      expect(logic.state.isReordering.value, isFalse);

      logic.state.drinkStatus.value = false;
      logic.toggleReorderMode();
      expect(logic.state.isReordering.value, isTrue);
      logic.toggleReorderMode();
      expect(logic.state.isReordering.value, isFalse);

      logic.state.deviceList.clear();
      logic.toggleReorderMode();
      expect(logic.state.isReordering.value, isFalse);
    });
  });

  group('prompts surfaced to the user', () {
    testWidgets(
      'startDrink failure explains session, server reason and fallback',
      (tester) async {
        await _pumpPromptHost(tester);

        final sessionExpired = _drinkLogicWithDevice(
          _fakeApi(
            startDrinkResponses: [
              Future.value(const DrinkResult(success: false, code: -99)),
            ],
          ),
        );
        await sessionExpired.startDrink();
        await tester.pump();
        expect(find.text('登录已过期：请重新登录后再试'), findsOneWidget);
        expect(sessionExpired.state.drinkStatus.value, isFalse);

        final serverReason = _drinkLogicWithDevice(
          _fakeApi(
            startDrinkResponses: [
              Future.value(
                const DrinkResult(success: false, code: 402, message: '余额不足'),
              ),
            ],
          ),
        );
        await serverReason.startDrink();
        await tester.pump();
        expect(find.text('操作失败：余额不足'), findsOneWidget);
        expect(serverReason.state.drinkStatus.value, isFalse);

        final missingMessage = _drinkLogicWithDevice(
          _fakeApi(
            startDrinkResponses: [
              Future.value(const DrinkResult(success: false, code: 500)),
            ],
          ),
        );
        await missingMessage.startDrink();
        await tester.pump();
        expect(find.text('操作失败：设备无响应，请检查设备状态'), findsOneWidget);
        expect(missingMessage.state.drinkStatus.value, isFalse);

        final succeeded = _drinkLogicWithDevice(_fakeApi());
        await succeeded.startDrink();
        await tester.pump();
        expect(find.text('开始接水'), findsOneWidget);
        expect(succeeded.state.drinkStatus.value, isTrue);
        expect(succeeded.state.deviceList, hasLength(1));
        // 收尾：结算一次以停掉已排定的状态轮询，不给测试留下挂起的定时器。
        await succeeded.endDrink();
        expect(succeeded.state.drinkStatus.value, isFalse);
        expect(succeeded.state.deviceStatusTimer, isNull);
      },
    );

    testWidgets(
      'endDrink failure explains session, server reason and fallback',
      (tester) async {
        await _pumpPromptHost(tester);

        final sessionExpired = _drinkLogicWithDevice(
          _fakeApi(
            endDrinkResponses: [
              Future.value(const DrinkResult(success: false, code: -99)),
            ],
          ),
        );
        sessionExpired.state.drinkStatus.value = true;
        await sessionExpired.endDrink();
        await tester.pump();
        expect(find.text('登录已过期：请重新登录后再试'), findsOneWidget);
        expect(sessionExpired.state.drinkStatus.value, isFalse);

        final serverReason = _drinkLogicWithDevice(
          _fakeApi(
            endDrinkResponses: [
              Future.value(
                const DrinkResult(success: false, code: 409, message: '设备正在结算'),
              ),
            ],
          ),
        );
        serverReason.state.drinkStatus.value = true;
        await serverReason.endDrink();
        await tester.pump();
        expect(find.text('操作失败：设备正在结算'), findsOneWidget);
        expect(serverReason.state.drinkStatus.value, isFalse);

        final missingMessage = _drinkLogicWithDevice(
          _fakeApi(
            endDrinkResponses: [
              Future.value(const DrinkResult(success: false)),
            ],
          ),
        );
        missingMessage.state.drinkStatus.value = true;
        await missingMessage.endDrink();
        await tester.pump();
        expect(find.text('操作失败：结算可能未成功，请检查'), findsOneWidget);
        expect(missingMessage.state.drinkStatus.value, isFalse);

        final succeeded = _drinkLogicWithDevice(_fakeApi());
        succeeded.state.drinkStatus.value = true;
        await succeeded.endDrink();
        await tester.pump();
        expect(find.text('已结算'), findsOneWidget);
        expect(succeeded.state.drinkStatus.value, isFalse);
      },
    );

    testWidgets('switching devices while drinking shows the refusal prompt', (
      tester,
    ) async {
      await _pumpPromptHost(tester);
      final logic = _drinkLogicWithDevice(_fakeApi());
      logic.state.deviceList.value = [
        {'id': 'tap-1', 'name': '一栋饮水机'},
        {'id': 'tap-2', 'name': '二栋饮水机'},
      ];
      logic.state.choiceDevice.value = 0;
      logic.state.drinkStatus.value = true;

      logic.setChoiceDevice(1);
      await tester.pump();

      expect(find.text('提示：正在接水中，请先结算'), findsOneWidget);
      expect(logic.state.choiceDevice.value, 0);
    });

    testWidgets(
      'entering reorder mode while drinking shows the refusal prompt',
      (tester) async {
        await _pumpPromptHost(tester);
        final logic = _drinkLogicWithDevice(_fakeApi());
        logic.state.deviceList.value = [
          {'id': 'tap-1', 'name': '一栋饮水机'},
          {'id': 'tap-2', 'name': '二栋饮水机'},
        ];
        logic.state.choiceDevice.value = 0;
        logic.state.drinkStatus.value = true;

        logic.toggleReorderMode();
        await tester.pump();

        expect(
          find.text('提示：正在接水中，请先结算'),
          findsOneWidget,
          reason: '接水中不能进入排序模式',
        );
        expect(logic.state.isReordering.value, isFalse);

        logic.state.drinkStatus.value = false;
        logic.toggleReorderMode();
        expect(logic.state.isReordering.value, isTrue);
      },
    );

    testWidgets('device list failure keeps the loaded devices for retry', (
      tester,
    ) async {
      await _pumpPromptHost(tester);
      final api = _FakeDrinkApi(
        deviceListResult: _savedDevices,
        deviceListErrorFromCall: 2,
        availabilityResults: const [],
      );
      final logic = FunctionDrinkLogic(drinkApi: api);
      addTearDown(logic.onClose);

      await logic.getDeviceList();
      expect(logic.state.deviceList, hasLength(1));

      await logic.getDeviceList();
      await tester.pump();

      expect(find.text('加载失败：设备列表获取失败，请稍后重试'), findsOneWidget);
      expect(logic.state.deviceList, hasLength(1));
      expect(logic.state.choiceDevice.value, 0);
      expect(logic.state.isLoading.value, isFalse);
      expect(logic.state.isRefreshing.value, isFalse);
    });
  });
}

Future<void> _pumpTimers(Duration duration) async {
  await Future<void>.delayed(duration);
}

Future<void> _waitUntil(
  bool Function() predicate, {
  required Duration timeout,
}) async {
  final stopwatch = Stopwatch()..start();
  while (!predicate()) {
    if (stopwatch.elapsed >= timeout) {
      fail('Timed out while waiting for condition.');
    }
    await _pumpTimers(const Duration(milliseconds: 1));
  }
}

/// 消息条需要一个可用的 `Get.context`，这些用例因此挂在最小的 GetMaterialApp 上。
Future<void> _pumpPromptHost(WidgetTester tester) async {
  await tester.pumpWidget(
    GetMaterialApp(
      home: const Scaffold(
        body: Center(child: SizedBox(width: 10, height: 10)),
      ),
    ),
  );
  await tester.pump();
}

const List<Map> _savedDevices = [
  {'id': 'tap-1', 'name': '一栋饮水机'},
];

/// 提示用例只需要一个能返回设备与成功结果的最小假接口。
_FakeDrinkApi _fakeApi({
  List<Future<DrinkResult>>? startDrinkResponses,
  List<Future<DrinkResult>>? endDrinkResponses,
}) {
  return _FakeDrinkApi(
    deviceListResult: _savedDevices,
    availabilityResults: const [],
    startDrinkResponses: startDrinkResponses,
    endDrinkResponses: endDrinkResponses,
  );
}

FunctionDrinkLogic _drinkLogicWithDevice(_FakeDrinkApi api) {
  final logic = FunctionDrinkLogic(drinkApi: api);
  addTearDown(logic.onClose);
  logic.state.deviceList.value = List<Map>.of(_savedDevices);
  logic.state.choiceDevice.value = 0;
  return logic;
}

class _FakeDrinkApi implements DrinkApiClient {
  _FakeDrinkApi({
    List<Map>? deviceListResult,
    List<Future<List<Map>>>? deviceListResponses,
    required List<bool> availabilityResults,
    this.availabilityDelay = Duration.zero,
    List<Future<bool>>? favoResponses,
    List<Future<DrinkResult>>? startDrinkResponses,
    List<Future<DrinkResult>>? endDrinkResponses,
    Future<String>? tokenResponse,
    this.deviceListErrorFromCall = 0,
  }) : deviceListResult = deviceListResult ?? const [],
       _deviceListResponses = List.of(deviceListResponses ?? const []),
       _availabilityResults = List<bool>.from(availabilityResults),
       _favoResponses = List.of(favoResponses ?? const []),
       _startDrinkResponses = List.of(startDrinkResponses ?? const []),
       _endDrinkResponses = List.of(endDrinkResponses ?? const []),
       _tokenResponse = tokenResponse;

  static const DrinkResult _ok = DrinkResult(success: true, code: 0);

  final List<Map> deviceListResult;
  final List<Future<List<Map>>> _deviceListResponses;
  final List<bool> _availabilityResults;
  final List<Future<bool>> _favoResponses;
  final List<Future<DrinkResult>> _startDrinkResponses;
  final List<Future<DrinkResult>> _endDrinkResponses;
  final Future<String>? _tokenResponse;
  final Duration availabilityDelay;

  /// 从第几次调用开始让设备列表请求失败（0 表示不失败）。
  final int deviceListErrorFromCall;
  int deviceListCalls = 0;
  int favoDeviceCalls = 0;
  int startDrinkCalls = 0;
  int endDrinkCalls = 0;
  int availabilityCalls = 0;
  int getTokenCalls = 0;
  int setTokenCalls = 0;
  String? lastToken;
  final List<String> favoRequestKeys = <String>[];
  final List<String> startDrinkRequests = <String>[];
  final List<String> endDrinkRequests = <String>[];
  int _activeAvailabilityRequests = 0;
  int maxConcurrentAvailabilityRequests = 0;

  @override
  Future<List<Map>> deviceList() async {
    deviceListCalls++;
    if (deviceListErrorFromCall > 0 &&
        deviceListCalls >= deviceListErrorFromCall) {
      throw Exception('device list request failed');
    }
    if (_deviceListResponses.isNotEmpty) {
      return _deviceListResponses.removeAt(0);
    }
    return deviceListResult;
  }

  @override
  Future<bool> favoDevice({required String id, required bool isUnFavo}) async {
    favoDeviceCalls++;
    favoRequestKeys.add('${isUnFavo ? 'unfavo' : 'favo'}:$id');
    if (_favoResponses.isNotEmpty) {
      return _favoResponses.removeAt(0);
    }
    return true;
  }

  @override
  Future<DrinkResult> startDrink({required String id}) async {
    startDrinkCalls++;
    startDrinkRequests.add(id);
    if (_startDrinkResponses.isNotEmpty) {
      return _startDrinkResponses.removeAt(0);
    }
    return _ok;
  }

  @override
  Future<DrinkResult> endDrink({required String id}) async {
    endDrinkCalls++;
    endDrinkRequests.add(id);
    if (_endDrinkResponses.isNotEmpty) {
      return _endDrinkResponses.removeAt(0);
    }
    return _ok;
  }

  @override
  Future<bool> isAvailableDevice({required String id}) async {
    availabilityCalls++;
    _activeAvailabilityRequests++;
    maxConcurrentAvailabilityRequests =
        maxConcurrentAvailabilityRequests < _activeAvailabilityRequests
            ? _activeAvailabilityRequests
            : maxConcurrentAvailabilityRequests;

    try {
      if (availabilityDelay > Duration.zero) {
        await Future<void>.delayed(availabilityDelay);
      }
      if (_availabilityResults.isEmpty) {
        return false;
      }
      return _availabilityResults.removeAt(0);
    } finally {
      _activeAvailabilityRequests--;
    }
  }

  @override
  Future<String> getToken() {
    getTokenCalls++;
    return _tokenResponse ?? Future.value('token');
  }

  @override
  Future<void> setToken({required String token}) async {
    setTokenCalls++;
    lastToken = token;
  }
}
