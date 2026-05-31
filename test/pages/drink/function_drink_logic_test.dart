import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:superhut/pages/drink/view/logic.dart';

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
    'concurrent device refreshes share a single in-flight request',
    () async {
      final deviceListCompleter = Completer<List<Map>>();
      final api = _FakeDrinkApi(
        deviceListResponses: [deviceListCompleter.future],
        availabilityResults: const [],
      );
      final logic = FunctionDrinkLogic(drinkApi: api);
      addTearDown(logic.onClose);

      final firstLoad = logic.getDeviceList(showRefreshing: true);
      final secondLoad = logic.getDeviceList(showRefreshing: true);
      await Future<void>.delayed(Duration.zero);

      expect(api.deviceListCalls, 1);

      deviceListCompleter.complete([
        {'id': 'tap-1', 'name': '一栋饮水机'},
      ]);
      await Future.wait([firstLoad, secondLoad]);

      expect(api.deviceListCalls, 1);
      expect(logic.state.deviceList, hasLength(1));
      expect(logic.state.choiceDevice.value, 0);
      expect(logic.state.isRefreshing.value, isFalse);
    },
  );

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
      final startCompleter = Completer<bool>();
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

      startCompleter.complete(true);
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
        Future<bool>.error(Exception('start unavailable')),
        Future<bool>.value(true),
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
    final endCompleter = Completer<bool>();
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

    endCompleter.complete(true);
    await Future.wait([firstEnd, secondEnd]);

    expect(api.endDrinkCalls, 1);
    expect(logic.state.drinkStatus.value, isFalse);
  });

  test('endDrink converts api errors to retryable failures', () async {
    final api = _FakeDrinkApi(
      availabilityResults: const [],
      endDrinkResponses: [
        Future<bool>.error(Exception('end unavailable')),
        Future<bool>.value(true),
      ],
    );
    final logic = FunctionDrinkLogic(drinkApi: api);
    addTearDown(logic.onClose);

    logic.state.deviceList.value = [
      {'id': 'tap-1', 'name': '一栋饮水机'},
    ];
    logic.state.choiceDevice.value = 0;
    logic.state.drinkStatus.value = true;

    await logic.endDrink();

    expect(api.endDrinkCalls, 1);
    expect(logic.state.drinkStatus.value, isTrue);

    await logic.endDrink();

    expect(api.endDrinkCalls, 2);
    expect(logic.state.drinkStatus.value, isFalse);
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

class _FakeDrinkApi implements DrinkApiClient {
  _FakeDrinkApi({
    List<Map>? deviceListResult,
    List<Future<List<Map>>>? deviceListResponses,
    required List<bool> availabilityResults,
    this.availabilityDelay = Duration.zero,
    List<Future<bool>>? favoResponses,
    List<Future<bool>>? startDrinkResponses,
    List<Future<bool>>? endDrinkResponses,
    Future<String>? tokenResponse,
  }) : deviceListResult = deviceListResult ?? const [],
       _deviceListResponses = List.of(deviceListResponses ?? const []),
       _availabilityResults = List<bool>.from(availabilityResults),
       _favoResponses = List.of(favoResponses ?? const []),
       _startDrinkResponses = List.of(startDrinkResponses ?? const []),
       _endDrinkResponses = List.of(endDrinkResponses ?? const []),
       _tokenResponse = tokenResponse;

  final List<Map> deviceListResult;
  final List<Future<List<Map>>> _deviceListResponses;
  final List<bool> _availabilityResults;
  final List<Future<bool>> _favoResponses;
  final List<Future<bool>> _startDrinkResponses;
  final List<Future<bool>> _endDrinkResponses;
  final Future<String>? _tokenResponse;
  final Duration availabilityDelay;
  int deviceListCalls = 0;
  int favoDeviceCalls = 0;
  int startDrinkCalls = 0;
  int endDrinkCalls = 0;
  int availabilityCalls = 0;
  int getTokenCalls = 0;
  int setTokenCalls = 0;
  String? lastToken;
  final List<String> favoRequestKeys = <String>[];
  int _activeAvailabilityRequests = 0;
  int maxConcurrentAvailabilityRequests = 0;

  @override
  Future<List<Map>> deviceList() async {
    deviceListCalls++;
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
  Future<bool> startDrink({required String id}) async {
    startDrinkCalls++;
    if (_startDrinkResponses.isNotEmpty) {
      return _startDrinkResponses.removeAt(0);
    }
    return true;
  }

  @override
  Future<bool> endDrink({required String id}) async {
    endDrinkCalls++;
    if (_endDrinkResponses.isNotEmpty) {
      return _endDrinkResponses.removeAt(0);
    }
    return true;
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
