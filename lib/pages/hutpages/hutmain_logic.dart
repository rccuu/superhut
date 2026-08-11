import 'dart:async';

import 'package:get/get.dart';
import 'package:superhut/pages/hutpages/hutmain_state.dart';

import '../../core/services/app_auth_storage.dart';
import '../../login/unified_login_page.dart';
import '../../utils/hut_user_api.dart';

typedef HutFunctionListLogicLoader = Future<List> Function();
typedef HutLoginStatusReader = Future<bool> Function();
typedef HutLoginRedirect = void Function();

class HutMainLogic extends GetxController {
  HutMainLogic({
    HutFunctionListLogicLoader? loadFunctionList,
    HutLoginStatusReader? isHutLoggedIn,
    HutLoginRedirect? redirectToLogin,
    this.loginRedirectDelay = const Duration(milliseconds: 100),
  }) : _loadFunctionList = loadFunctionList ?? HutUserApi().getFunctionList,
       _isHutLoggedIn = isHutLoggedIn ?? AppAuthStorage.instance.isHutLoggedIn,
       _redirectToLogin =
           redirectToLogin ??
           (() => Get.off(() => UnifiedLoginPage(returnToCaller: true)));

  final HutMainState state = HutMainState();
  final HutFunctionListLogicLoader _loadFunctionList;
  final HutLoginStatusReader _isHutLoggedIn;
  final HutLoginRedirect _redirectToLogin;
  final Duration loginRedirectDelay;
  Future<List>? _functionListLoad;
  Timer? _loginRedirectTimer;
  bool _isDisposed = false;
  List funList = [];

  Future<List> getFunList() async {
    if (_isDisposed) {
      return funList;
    }

    if (state.isLoad.value) {
      return funList;
    }

    final inFlight = _functionListLoad;
    if (inFlight != null) {
      return inFlight;
    }

    final load = _loadFunctionList();
    _functionListLoad = load;
    try {
      final loadedFunList = await load;
      if (_isDisposed) {
        return loadedFunList;
      }

      funList = loadedFunList;
      state.isLoad.value = true;
      return funList;
    } finally {
      if (identical(_functionListLoad, load)) {
        _functionListLoad = null;
      }
    }
  }

  /// 判断是否需要跳转登录
  Future<void> checkLogin() async {
    if (_isDisposed) {
      return;
    }

    final bool hsa = await _isHutLoggedIn();
    if (_isDisposed) {
      return;
    }

    if (hsa == false) {
      _queueLoginRedirect();
    } else {
      _loginRedirectTimer?.cancel();
    }
  }

  void _queueLoginRedirect() {
    if (_isDisposed) {
      return;
    }

    if (_loginRedirectTimer?.isActive ?? false) {
      return;
    }

    _loginRedirectTimer = Timer(loginRedirectDelay, _redirectToLogin);
  }

  @override
  void onClose() {
    _isDisposed = true;
    _loginRedirectTimer?.cancel();
    _loginRedirectTimer = null;
    super.onClose();
  }
}
