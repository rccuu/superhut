import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/water/logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.reset();
  });

  test(
    'concurrent device refreshes share a single in-flight request',
    () async {
      final deviceCompleter = Completer<Map<String, dynamic>>();
      final api = _FakeHotWaterApi(
        deviceResponses: [deviceCompleter.future],
        openDevices: const [],
        balance: '12.34',
      );
      final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
      final logic = FunctionHotWaterLogic(
        hotWaterApi: api,
        authStorage: storage,
      );
      addTearDown(logic.onClose);

      logic.hutUserInfo['hutIsLogin'] = true;

      final firstLoad = logic.getDeviceList();
      final secondLoad = logic.getDeviceList();
      await Future<void>.delayed(Duration.zero);

      expect(api.getHotWaterDeviceCalls, 1);

      deviceCompleter.complete({
        'code': 200,
        'data': [
          {'poscode': '100001', 'posname': '一栋热水'},
        ],
      });
      await Future.wait([firstLoad, secondLoad]);

      expect(api.getHotWaterDeviceCalls, 1);
      expect(api.checkHotWaterDeviceCalls, 1);
      expect(api.getCardBalanceCalls, 1);
      expect(logic.state.deviceList, hasLength(1));
      expect(logic.state.choiceDevice.value, 0);
      expect(logic.state.balance.value, '12.34');
    },
  );

  test('device refresh applies related reactive state', () async {
    final api = _FakeHotWaterApi(
      deviceResponses: [
        Future.value({
          'code': 200,
          'data': [
            {'poscode': '100001', 'posname': '一栋热水'},
          ],
        }),
      ],
      openDevices: const [],
      balance: '12.34',
    );
    final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
    final logic = FunctionHotWaterLogic(hotWaterApi: api, authStorage: storage);
    addTearDown(logic.onClose);

    logic.hutUserInfo['hutIsLogin'] = true;

    await logic.getDeviceList();

    expect(api.checkHotWaterDeviceCalls, 1);
    expect(api.getCardBalanceCalls, 1);
    expect(logic.state.deviceList, hasLength(1));
    expect(logic.state.choiceDevice.value, 0);
    expect(logic.state.deviceCheckComplete.value, isTrue);
    expect(logic.state.balance.value, '12.34');
  });

  test('device refresh checks open device and balance concurrently', () async {
    final openDeviceCompleter = Completer<List>();
    final balanceCompleter = Completer<String>();
    final api = _FakeHotWaterApi(
      deviceResponses: [
        Future.value({
          'code': 200,
          'data': [
            {'poscode': '100001', 'posname': '一栋热水'},
          ],
        }),
      ],
      openDeviceResponses: [openDeviceCompleter.future],
      balanceResponses: [balanceCompleter.future],
    );
    final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
    final logic = FunctionHotWaterLogic(hotWaterApi: api, authStorage: storage);
    addTearDown(logic.onClose);

    logic.hutUserInfo['hutIsLogin'] = true;

    final refresh = logic.getDeviceList();
    await Future<void>.delayed(Duration.zero);

    expect(api.checkHotWaterDeviceCalls, 1);
    expect(api.getCardBalanceCalls, 1);
    expect(logic.state.deviceCheckComplete.value, isFalse);
    expect(logic.state.balance.value, 'null');

    openDeviceCompleter.complete(const []);
    await Future<void>.delayed(Duration.zero);
    expect(logic.state.deviceCheckComplete.value, isTrue);
    expect(logic.state.balance.value, 'null');

    balanceCompleter.complete('12.34');
    await refresh;

    expect(logic.state.deviceCheckComplete.value, isTrue);
    expect(logic.state.balance.value, '12.34');
  });

  test(
    'open device refresh clears stale running state when no open device remains',
    () async {
      final api = _FakeHotWaterApi(
        deviceResponses: const <Future<Map<String, dynamic>>>[],
        openDevices: const [],
      );
      final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
      final logic = FunctionHotWaterLogic(
        hotWaterApi: api,
        authStorage: storage,
      );
      addTearDown(logic.onClose);

      logic.state.deviceList.value = [
        {'poscode': '100001', 'posname': '一栋热水'},
      ];
      logic.state.choiceDevice.value = 0;
      logic.state.waterStatus.value = true;
      logic.state.deviceCheckComplete.value = true;

      await logic.checkHotWaterDevice();

      expect(api.checkHotWaterDeviceCalls, 1);
      expect(logic.state.waterStatus.value, isFalse);
      expect(logic.state.choiceDevice.value, 0);
      expect(logic.state.deviceCheckComplete.value, isTrue);
    },
  );

  test(
    'open device refresh clears stale running state for unknown open device',
    () async {
      final api = _FakeHotWaterApi(
        deviceResponses: const <Future<Map<String, dynamic>>>[],
        openDevices: const ['999999'],
      );
      final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
      final logic = FunctionHotWaterLogic(
        hotWaterApi: api,
        authStorage: storage,
      );
      addTearDown(logic.onClose);

      logic.state.deviceList.value = [
        {'poscode': '100001', 'posname': '一栋热水'},
      ];
      logic.state.choiceDevice.value = 0;
      logic.state.waterStatus.value = true;
      logic.state.deviceCheckComplete.value = true;

      await logic.checkHotWaterDevice();

      expect(api.checkHotWaterDeviceCalls, 1);
      expect(logic.state.waterStatus.value, isFalse);
      expect(logic.state.choiceDevice.value, 0);
      expect(logic.state.deviceCheckComplete.value, isTrue);
    },
  );

  test('device refresh drops late result after controller closes', () async {
    final deviceCompleter = Completer<Map<String, dynamic>>();
    final api = _FakeHotWaterApi(
      deviceResponses: [deviceCompleter.future],
      openDevices: const ['100001'],
      balance: '12.34',
    );
    final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
    final logic = FunctionHotWaterLogic(hotWaterApi: api, authStorage: storage);

    logic.hutUserInfo['hutIsLogin'] = true;

    final refresh = logic.getDeviceList();
    await Future<void>.delayed(Duration.zero);

    expect(api.getHotWaterDeviceCalls, 1);

    logic.onClose();
    deviceCompleter.complete({
      'code': 200,
      'data': [
        {'poscode': '100001', 'posname': '一栋热水'},
      ],
    });
    await refresh;

    expect(logic.state.deviceList, isEmpty);
    expect(logic.state.choiceDevice.value, -1);
    expect(logic.state.balance.value, 'null');
    expect(logic.state.waterStatus.value, isFalse);
    expect(api.checkHotWaterDeviceCalls, 0);
    expect(api.getCardBalanceCalls, 0);
  });

  test('stale balance refresh does not override latest balance', () async {
    final staleBalanceCompleter = Completer<String>();
    final api = _FakeHotWaterApi(
      deviceResponses: const <Future<Map<String, dynamic>>>[],
      balanceResponses: [staleBalanceCompleter.future, Future.value('20.00')],
    );
    final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
    final logic = FunctionHotWaterLogic(hotWaterApi: api, authStorage: storage);
    addTearDown(logic.onClose);

    final staleRefresh = logic.getBalance();
    await Future<void>.delayed(Duration.zero);
    final latestRefresh = logic.getBalance();
    await latestRefresh;

    expect(logic.state.balance.value, '20.00');

    staleBalanceCompleter.complete('10.00');
    await staleRefresh;

    expect(logic.state.balance.value, '20.00');
    expect(api.getCardBalanceCalls, 2);
  });

  test(
    'invalid login clears state without recursively rechecking login',
    () async {
      final api = _FakeHotWaterApi(
        deviceResponses: [
          Future.value({'code': 500}),
        ],
      );
      final storage = _FakeHotWaterAuthStorage(
        isLoggedIn: true,
        username: '',
        password: '',
        token: 'stale-token',
        deviceId: 'stale-device',
      );
      final logic = FunctionHotWaterLogic(
        hotWaterApi: api,
        authStorage: storage,
      );
      addTearDown(logic.onClose);

      await logic.checkLogin();

      expect(storage.readCalls, 1);
      expect(storage.setLoginStatusCalls, 1);
      expect(api.getHotWaterDeviceCalls, 1);
      expect(api.userLoginCalls, 0);
      expect(logic.hutUserInfo['hutIsLogin'], isFalse);
      expect(logic.state.deviceList, isEmpty);
      expect(logic.state.choiceDevice.value, -1);
      expect(logic.state.waterStatus.value, isFalse);
      expect(logic.state.deviceCheckComplete.value, isTrue);
    },
  );

  test('repeated logged-out checks queue one delayed login redirect', () async {
    final api = _FakeHotWaterApi(
      deviceResponses: const <Future<Map<String, dynamic>>>[],
    );
    final storage = _FakeHotWaterAuthStorage(isLoggedIn: false);
    var redirectCalls = 0;
    final logic = FunctionHotWaterLogic(
      hotWaterApi: api,
      authStorage: storage,
      redirectToLogin: () {
        redirectCalls++;
      },
      loginRedirectDelay: const Duration(milliseconds: 5),
    );
    addTearDown(logic.onClose);

    await logic.checkLogin();
    await logic.checkLogin();

    expect(redirectCalls, 0);
    expect(api.getHotWaterDeviceCalls, 0);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(redirectCalls, 1);
  });

  test('onClose cancels pending login redirect', () async {
    final api = _FakeHotWaterApi(
      deviceResponses: const <Future<Map<String, dynamic>>>[],
    );
    final storage = _FakeHotWaterAuthStorage(isLoggedIn: false);
    var redirectCalls = 0;
    final logic = FunctionHotWaterLogic(
      hotWaterApi: api,
      authStorage: storage,
      redirectToLogin: () {
        redirectCalls++;
      },
      loginRedirectDelay: const Duration(milliseconds: 10),
    );

    await logic.checkLogin();
    logic.onClose();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(redirectCalls, 0);
  });

  test('valid login cancels pending login redirect', () async {
    final api = _FakeHotWaterApi(
      deviceResponses: [
        Future.value({'code': 200, 'data': const <Map<String, String>>[]}),
      ],
      openDevices: const [],
      balance: '12.34',
    );
    final storage = _FakeHotWaterAuthStorage(isLoggedIn: false);
    var redirectCalls = 0;
    final logic = FunctionHotWaterLogic(
      hotWaterApi: api,
      authStorage: storage,
      redirectToLogin: () {
        redirectCalls++;
      },
      loginRedirectDelay: const Duration(milliseconds: 10),
    );
    addTearDown(logic.onClose);

    await logic.checkLogin();
    storage.isLoggedIn = true;
    await logic.checkLogin();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(redirectCalls, 0);
    expect(api.getHotWaterDeviceCalls, 1);
  });

  test(
    'concurrent startWater calls share a single in-flight request',
    () async {
      final startCompleter = Completer<Map>();
      final api = _FakeHotWaterApi(
        deviceResponses: const <Future<Map<String, dynamic>>>[],
        startResponses: [startCompleter.future],
      );
      final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
      final logic = FunctionHotWaterLogic(
        hotWaterApi: api,
        authStorage: storage,
      );
      addTearDown(logic.onClose);

      logic.state.deviceList.value = [
        {'poscode': '100001', 'posname': '一栋热水'},
      ];
      logic.state.choiceDevice.value = 0;

      final firstStart = logic.startWater();
      final secondStart = logic.startWater();
      await Future<void>.delayed(Duration.zero);

      expect(api.startHotWaterCalls, 1);

      startCompleter.complete({'success': true, 'result': '000000'});
      await Future.wait([firstStart, secondStart]);

      expect(api.startHotWaterCalls, 1);
      expect(logic.state.waterStatus.value, isTrue);
      expect(logic.state.isLoading.value, isFalse);
    },
  );

  test('concurrent endWater calls share a single in-flight request', () async {
    final stopCompleter = Completer<bool>();
    final api = _FakeHotWaterApi(
      deviceResponses: const <Future<Map<String, dynamic>>>[],
      stopResponses: [stopCompleter.future],
    );
    final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
    final logic = FunctionHotWaterLogic(hotWaterApi: api, authStorage: storage);
    addTearDown(logic.onClose);

    logic.state.deviceList.value = [
      {'poscode': '100001', 'posname': '一栋热水'},
    ];
    logic.state.choiceDevice.value = 0;
    logic.state.waterStatus.value = true;

    final firstStop = logic.endWater();
    final secondStop = logic.endWater();
    await Future<void>.delayed(Duration.zero);

    expect(api.stopHotWaterCalls, 1);

    stopCompleter.complete(true);
    await Future.wait([firstStop, secondStop]);

    expect(api.stopHotWaterCalls, 1);
    expect(logic.state.waterStatus.value, isFalse);
    expect(logic.state.isLoading.value, isFalse);
  });

  test(
    'concurrent addDevice calls for same code share one in-flight request',
    () async {
      final addCompleter = Completer<Map>();
      final api = _FakeHotWaterApi(
        deviceResponses: const <Future<Map<String, dynamic>>>[],
        addResponses: [addCompleter.future],
        openDevices: const [],
        balance: '12.34',
      );
      final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
      final logic = FunctionHotWaterLogic(
        hotWaterApi: api,
        authStorage: storage,
      );
      addTearDown(logic.onClose);

      final firstAdd = logic.addDevice('123456');
      final secondAdd = logic.addDevice('123456');
      await Future<void>.delayed(Duration.zero);

      expect(api.addWaterDeviceCalls, 1);

      addCompleter.complete({'result': true});
      final results = await Future.wait([firstAdd, secondAdd]);

      expect(results, [true, true]);
      expect(api.addWaterDeviceCalls, 1);
      expect(api.getHotWaterDeviceCalls, 1);
      expect(api.checkHotWaterDeviceCalls, 1);
      expect(api.getCardBalanceCalls, 1);
    },
  );

  test('addDevice converts api errors to false and allows retry', () async {
    final api = _FakeHotWaterApi(
      deviceResponses: const <Future<Map<String, dynamic>>>[],
      addResponses: [
        Future<Map>.error(Exception('add failed')),
        Future.value({'result': false, 'msg': 'still failed'}),
      ],
    );
    final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
    final logic = FunctionHotWaterLogic(hotWaterApi: api, authStorage: storage);
    addTearDown(logic.onClose);

    final firstResult = await logic.addDevice('123456');
    final secondResult = await logic.addDevice('123456');

    expect(firstResult, isFalse);
    expect(secondResult, isFalse);
    expect(api.addWaterDeviceCalls, 2);
    expect(api.getHotWaterDeviceCalls, 0);
  });

  test(
    'concurrent deleteDevice calls for same code share one in-flight request',
    () async {
      final deleteCompleter = Completer<Map<String, dynamic>>();
      final api = _FakeHotWaterApi(
        deviceResponses: const <Future<Map<String, dynamic>>>[],
        deleteResponses: [deleteCompleter.future],
        openDevices: const [],
        balance: '12.34',
      );
      final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
      final logic = FunctionHotWaterLogic(
        hotWaterApi: api,
        authStorage: storage,
      );
      addTearDown(logic.onClose);

      final firstDelete = logic.deleteDevice('123456');
      final secondDelete = logic.deleteDevice('123456');
      await Future<void>.delayed(Duration.zero);

      expect(api.delWaterDeviceCalls, 1);

      deleteCompleter.complete({'result': true});
      final results = await Future.wait([firstDelete, secondDelete]);

      expect(results, [true, true]);
      expect(api.delWaterDeviceCalls, 1);
      expect(api.getHotWaterDeviceCalls, 1);
      expect(api.checkHotWaterDeviceCalls, 1);
      expect(api.getCardBalanceCalls, 1);
    },
  );

  test('deleteDevice converts api errors to false and allows retry', () async {
    final api = _FakeHotWaterApi(
      deviceResponses: const <Future<Map<String, dynamic>>>[],
      deleteResponses: [
        Future<Map<String, dynamic>>.error(Exception('delete failed')),
        Future.value({'result': false, 'msg': 'still failed'}),
      ],
    );
    final storage = _FakeHotWaterAuthStorage(isLoggedIn: true);
    final logic = FunctionHotWaterLogic(hotWaterApi: api, authStorage: storage);
    addTearDown(logic.onClose);

    final firstResult = await logic.deleteDevice('123456');
    final secondResult = await logic.deleteDevice('123456');

    expect(firstResult, isFalse);
    expect(secondResult, isFalse);
    expect(api.delWaterDeviceCalls, 2);
    expect(api.getHotWaterDeviceCalls, 0);
  });
}

class _FakeHotWaterApi implements HotWaterApiClient {
  _FakeHotWaterApi({
    required List<Future<Map<String, dynamic>>> deviceResponses,
    List<Future<List>>? openDeviceResponses,
    List<Future<String>>? balanceResponses,
    List<Future<Map>>? startResponses,
    List<Future<bool>>? stopResponses,
    List<Future<Map>>? addResponses,
    List<Future<Map<String, dynamic>>>? deleteResponses,
    this.openDevices = const [],
    this.balance = '--',
  }) : _deviceResponses = List.of(deviceResponses),
       _openDeviceResponses = List.of(openDeviceResponses ?? const []),
       _balanceResponses = List.of(balanceResponses ?? const []),
       _startResponses = List.of(startResponses ?? const []),
       _stopResponses = List.of(stopResponses ?? const []),
       _addResponses = List.of(addResponses ?? const []),
       _deleteResponses = List.of(deleteResponses ?? const []);

  final List<Future<Map<String, dynamic>>> _deviceResponses;
  final List<Future<List>> _openDeviceResponses;
  final List<Future<String>> _balanceResponses;
  final List<Future<Map>> _startResponses;
  final List<Future<bool>> _stopResponses;
  final List<Future<Map>> _addResponses;
  final List<Future<Map<String, dynamic>>> _deleteResponses;
  final List openDevices;
  final String balance;
  int getHotWaterDeviceCalls = 0;
  int userLoginCalls = 0;
  int checkHotWaterDeviceCalls = 0;
  int getCardBalanceCalls = 0;
  int startHotWaterCalls = 0;
  int stopHotWaterCalls = 0;
  int addWaterDeviceCalls = 0;
  int delWaterDeviceCalls = 0;

  @override
  Future<Map<String, dynamic>> getHotWaterDevice() {
    getHotWaterDeviceCalls++;
    if (_deviceResponses.isEmpty) {
      return Future.value({'code': 200, 'data': const []});
    }
    return _deviceResponses.removeAt(0);
  }

  @override
  Future<bool> userLogin({required String username, required String password}) {
    userLoginCalls++;
    return Future.value(false);
  }

  @override
  Future<String> getCardBalance() {
    getCardBalanceCalls++;
    if (_balanceResponses.isNotEmpty) {
      return _balanceResponses.removeAt(0);
    }
    return Future.value(balance);
  }

  @override
  Future<List> checkHotWaterDevice() {
    checkHotWaterDeviceCalls++;
    if (_openDeviceResponses.isNotEmpty) {
      return _openDeviceResponses.removeAt(0);
    }
    return Future.value(openDevices);
  }

  @override
  Future<Map> startHotWater({required String device}) {
    startHotWaterCalls++;
    if (_startResponses.isNotEmpty) {
      return _startResponses.removeAt(0);
    }
    return Future.value({'success': true, 'result': '000000'});
  }

  @override
  Future<bool> stopHotWater({required String device}) {
    stopHotWaterCalls++;
    if (_stopResponses.isNotEmpty) {
      return _stopResponses.removeAt(0);
    }
    return Future.value(true);
  }

  @override
  Future<Map> addWaterDevice(String bindCode) {
    addWaterDeviceCalls++;
    if (_addResponses.isNotEmpty) {
      return _addResponses.removeAt(0);
    }
    return Future.value({'result': true});
  }

  @override
  Future<Map<String, dynamic>> delWaterDevice(String bindCode) {
    delWaterDeviceCalls++;
    if (_deleteResponses.isNotEmpty) {
      return _deleteResponses.removeAt(0);
    }
    return Future.value({'result': true});
  }
}

class _FakeHotWaterAuthStorage implements HotWaterAuthStorage {
  _FakeHotWaterAuthStorage({
    this.token = '',
    this.deviceId = '',
    this.username = 'hut-user',
    this.password = 'hut-pass',
    this.isLoggedIn = false,
  });

  final String token;
  final String deviceId;
  final String username;
  final String password;
  bool isLoggedIn;
  int readCalls = 0;
  int setLoginStatusCalls = 0;

  @override
  Future<String> readHutToken() async {
    readCalls++;
    return token;
  }

  @override
  Future<String> readHutDeviceId() async {
    return deviceId;
  }

  @override
  Future<String> readHutUsername() async {
    return username;
  }

  @override
  Future<String> readHutPassword() async {
    return password;
  }

  @override
  Future<bool> isHutLoggedIn() async {
    return isLoggedIn;
  }

  @override
  Future<void> setHutLoginStatus(bool value) async {
    setLoginStatusCalls++;
    isLoggedIn = value;
  }
}
