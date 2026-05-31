import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:superhut/pages/hutpages/hutmain_logic.dart';

void main() {
  tearDown(() {
    Get.reset();
  });

  test(
    'concurrent function list loads share a single in-flight request',
    () async {
      final completer = Completer<List>();
      var loadCalls = 0;
      final logic = HutMainLogic(
        loadFunctionList: () {
          loadCalls++;
          return completer.future;
        },
      );

      final firstLoad = logic.getFunList();
      final secondLoad = logic.getFunList();
      await Future<void>.delayed(Duration.zero);

      expect(loadCalls, 1);

      completer.complete([
        {'title': '校园卡'},
      ]);
      final results = await Future.wait([firstLoad, secondLoad]);

      expect(results[0], same(results[1]));
      expect(results[0], [
        {'title': '校园卡'},
      ]);
      expect(logic.state.isLoad.value, isTrue);

      final cached = await logic.getFunList();
      expect(cached, [
        {'title': '校园卡'},
      ]);
      expect(loadCalls, 1);
    },
  );

  test(
    'function list load drops late state update after controller closes',
    () async {
      final completer = Completer<List>();
      var loadCalls = 0;
      final logic = HutMainLogic(
        loadFunctionList: () {
          loadCalls++;
          return completer.future;
        },
      );

      final load = logic.getFunList();
      await Future<void>.delayed(Duration.zero);

      expect(loadCalls, 1);

      logic.onClose();
      completer.complete([
        {'title': '校园卡'},
      ]);
      final result = await load;

      expect(result, [
        {'title': '校园卡'},
      ]);
      expect(logic.funList, isEmpty);
      expect(logic.state.isLoad.value, isFalse);
    },
  );

  test('checkLogin queues only one delayed login redirect', () async {
    var redirectCalls = 0;
    final logic = HutMainLogic(
      isHutLoggedIn: () async => false,
      redirectToLogin: () {
        redirectCalls++;
      },
      loginRedirectDelay: const Duration(milliseconds: 5),
    );
    addTearDown(logic.onClose);

    await logic.checkLogin();
    await logic.checkLogin();

    expect(redirectCalls, 0);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(redirectCalls, 1);
  });

  test('onClose cancels pending login redirect', () async {
    var redirectCalls = 0;
    final logic = HutMainLogic(
      isHutLoggedIn: () async => false,
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

  test('checkLogin drops late login result after controller closes', () async {
    final loginCompleter = Completer<bool>();
    var redirectCalls = 0;
    final logic = HutMainLogic(
      isHutLoggedIn: () => loginCompleter.future,
      redirectToLogin: () {
        redirectCalls++;
      },
      loginRedirectDelay: const Duration(milliseconds: 1),
    );

    final check = logic.checkLogin();
    await Future<void>.delayed(Duration.zero);

    logic.onClose();
    loginCompleter.complete(false);
    await check;
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(redirectCalls, 0);
  });

  test('valid login cancels pending login redirect', () async {
    var isLoggedIn = false;
    var redirectCalls = 0;
    final logic = HutMainLogic(
      isHutLoggedIn: () async => isLoggedIn,
      redirectToLogin: () {
        redirectCalls++;
      },
      loginRedirectDelay: const Duration(milliseconds: 10),
    );
    addTearDown(logic.onClose);

    await logic.checkLogin();
    isLoggedIn = true;
    await logic.checkLogin();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(redirectCalls, 0);
  });
}
