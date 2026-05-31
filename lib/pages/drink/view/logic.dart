import 'dart:async';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/drink/login/view.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/ui/app_snack_bar.dart';
import '../api/drink_api.dart';
import 'state.dart';

class FunctionDrinkLogic extends GetxController {
  FunctionDrinkLogic({
    DrinkApiClient? drinkApi,
    this.statusPollInterval = const Duration(seconds: 2),
    int requiredAvailablePolls = 3,
    void Function()? redirectToLogin,
  }) : drinkApi = drinkApi ?? DrinkApi(),
       requiredAvailablePolls = requiredAvailablePolls.clamp(1, 10).toInt(),
       _redirectToLogin =
           redirectToLogin ?? (() => Get.off(() => const DrinkLoginPage()));

  final FunctionDrinkState state = FunctionDrinkState();
  final DrinkApiClient drinkApi;
  final Duration statusPollInterval;
  final int requiredAvailablePolls;
  final void Function() _redirectToLogin;
  int _drinkStatusPollGeneration = 0;
  Future<void>? _deviceListLoad;
  final Map<String, Future<bool>> _favoDeviceLoads = <String, Future<bool>>{};
  bool _drinkOperationInFlight = false;
  bool _loginRedirectQueued = false;
  bool _isDisposed = false;

  void _showErrorSnackBar(String title, String message) {
    showAppSnackBar(
      Get.context,
      message: '$title：$message',
      type: AppSnackBarType.error,
    );
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_initialize());
  }

  @override
  void onClose() {
    _isDisposed = true;
    _cancelDeviceStatusPolling();
    state.tokenController.dispose();
    super.onClose();
  }

  Future<void> _initialize() async {
    final isLoggedIn = await checkLogin();
    if (!isLoggedIn) {
      return;
    }
    final token = await drinkApi.getToken();
    if (_isDisposed) {
      return;
    }
    state.tokenController.text = token;
  }

  /// 判断是否需要跳转登录
  Future<bool> checkLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_isDisposed) {
      return false;
    }

    final bool isLogin = prefs.getBool("hui798IsLogin") ?? false;
    if (!isLogin) {
      state.isLoading.value = false;
      _queueLoginRedirect();
      return false;
    }

    await getDeviceList(showLoading: true);
    return !_isDisposed;
  }

  /// 获取喝水设备列表
  Future<void> getDeviceList({
    bool showLoading = false,
    bool showRefreshing = false,
  }) async {
    if (_isDisposed) {
      return;
    }

    final inFlight = _deviceListLoad;
    if (inFlight != null) {
      return inFlight;
    }

    final load = _loadDeviceList(
      showLoading: showLoading,
      showRefreshing: showRefreshing,
    );
    _deviceListLoad = load;
    try {
      await load;
    } finally {
      if (identical(_deviceListLoad, load)) {
        _deviceListLoad = null;
      }
    }
  }

  Future<void> _loadDeviceList({
    required bool showLoading,
    required bool showRefreshing,
  }) async {
    if (_isDisposed) {
      return;
    }

    final String? previousDeviceId =
        state.choiceDevice.value >= 0 &&
                state.choiceDevice.value < state.deviceList.length
            ? state.deviceList[state.choiceDevice.value]["id"]?.toString()
            : null;

    if (showLoading && !state.isLoading.value) {
      state.isLoading.value = true;
    }
    if (showRefreshing) {
      state.isRefreshing.value = true;
    }

    try {
      final List<Map> value = await drinkApi.deviceList();
      if (_isDisposed) {
        return;
      }

      if (value.isNotEmpty && value[0]["name"] == "Account failure") {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool("hui798IsLogin", false);
        if (_isDisposed) {
          return;
        }

        _cancelDeviceStatusPolling();
        state.deviceList.clear();
        _assignChoiceDevice(-1);
        state.drinkStatus.value = false;
        state.isLoading.value = false;
        state.isRefreshing.value = false;
        _queueLoginRedirect();
        return;
      }

      state.deviceList.value = value;

      if (state.deviceList.isEmpty) {
        _cancelDeviceStatusPolling();
        state.drinkStatus.value = false;
        _assignChoiceDevice(-1);
      } else if (previousDeviceId != null) {
        final int preservedIndex = state.deviceList.indexWhere(
          (dynamic device) => device["id"]?.toString() == previousDeviceId,
        );
        _assignChoiceDevice(preservedIndex == -1 ? 0 : preservedIndex);
      } else {
        _assignChoiceDevice(0);
      }
    } catch (error) {
      if (!_isDisposed) {
        _showErrorSnackBar('加载失败', '设备列表获取失败，请稍后重试');
      }
    } finally {
      if (!_isDisposed) {
        state.isLoading.value = false;
        state.isRefreshing.value = false;
      }
    }
  }

  /// 收藏或取消收藏设备
  Future<bool> favoDevice(String id, bool isUnFavo) async {
    final key = '${isUnFavo ? 'unfavo' : 'favo'}:$id';
    final inFlight = _favoDeviceLoads[key];
    if (inFlight != null) {
      return inFlight;
    }

    final load = drinkApi.favoDevice(id: id, isUnFavo: isUnFavo);
    _favoDeviceLoads[key] = load;
    try {
      return await load;
    } finally {
      if (identical(_favoDeviceLoads[key], load)) {
        _favoDeviceLoads.remove(key);
      }
    }
  }

  /// 格式化设备名称
  String formatDeviceName(String name) {
    StringBuffer? buffer;
    var segmentStart = 0;
    for (var index = 0; index < name.length; index++) {
      if (name.codeUnitAt(index) == 0x680B) {
        buffer ??= StringBuffer();
        if (segmentStart < index) {
          buffer.write(name.substring(segmentStart, index));
        }
        buffer.write('-');
        segmentStart = index + 1;
      }
    }
    if (buffer == null) {
      return name;
    }
    if (segmentStart < name.length) {
      buffer.write(name.substring(segmentStart));
    }
    return buffer.toString();
  }

  /// 改变选中的设备值
  void setChoiceDevice(int device) {
    _assignChoiceDevice(device);
  }

  bool _assignChoiceDevice(int device) {
    if (state.choiceDevice.value == device) {
      return false;
    }
    state.choiceDevice.value = device;
    return true;
  }

  void _cancelDeviceStatusPolling() {
    _drinkStatusPollGeneration++;
    state.deviceStatusTimer?.cancel();
    state.deviceStatusTimer = null;
  }

  void _queueLoginRedirect() {
    if (_loginRedirectQueued) {
      return;
    }

    _loginRedirectQueued = true;
    _redirectToLogin();
  }

  String? _selectedDeviceId() {
    final selectedIndex = state.choiceDevice.value;
    if (selectedIndex < 0 || selectedIndex >= state.deviceList.length) {
      return null;
    }

    final device = state.deviceList[selectedIndex];
    if (device is! Map) {
      return null;
    }

    final id = device['id']?.toString();
    if (id == null || id.isEmpty) {
      return null;
    }
    return id;
  }

  void _scheduleDeviceStatusPolling({
    required String deviceId,
    required int generation,
    required int availablePolls,
  }) {
    if (generation != _drinkStatusPollGeneration || !state.drinkStatus.value) {
      return;
    }

    state.deviceStatusTimer?.cancel();
    state.deviceStatusTimer = Timer(statusPollInterval, () {
      unawaited(
        _pollDeviceStatus(
          deviceId: deviceId,
          generation: generation,
          availablePolls: availablePolls,
        ),
      );
    });
  }

  Future<void> _pollDeviceStatus({
    required String deviceId,
    required int generation,
    required int availablePolls,
  }) async {
    if (generation != _drinkStatusPollGeneration || !state.drinkStatus.value) {
      return;
    }

    try {
      final bool isAvailable = await drinkApi.isAvailableDevice(id: deviceId);
      if (generation != _drinkStatusPollGeneration ||
          !state.drinkStatus.value) {
        return;
      }

      final nextAvailablePolls = isAvailable ? availablePolls + 1 : 0;
      if (nextAvailablePolls >= requiredAvailablePolls) {
        state.drinkStatus.value = false;
        _cancelDeviceStatusPolling();
        return;
      }

      _scheduleDeviceStatusPolling(
        deviceId: deviceId,
        generation: generation,
        availablePolls: nextAvailablePolls,
      );
    } catch (_) {
      _scheduleDeviceStatusPolling(
        deviceId: deviceId,
        generation: generation,
        availablePolls: availablePolls,
      );
    }
  }

  /// 开始喝水
  Future<void> startDrink() async {
    if (_drinkOperationInFlight || _isDisposed) {
      return;
    }

    _drinkOperationInFlight = true;
    try {
      final deviceId = _selectedDeviceId();
      if (deviceId == null) {
        _showErrorSnackBar('操作失败', '请先选择设备');
        return;
      }

      final bool value = await drinkApi.startDrink(id: deviceId);
      if (_isDisposed) {
        return;
      }

      if (value) {
        _cancelDeviceStatusPolling();
        state.drinkStatus.value = true;
        unawaited(getDeviceList());
        final generation = _drinkStatusPollGeneration;
        _scheduleDeviceStatusPolling(
          deviceId: deviceId,
          generation: generation,
          availablePolls: 0,
        );
      } else {
        _showErrorSnackBar('操作失败', '设备启动失败，请稍后重试');
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to start drink device',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isDisposed) {
        _showErrorSnackBar('操作失败', '设备启动失败，请稍后重试');
      }
    } finally {
      _drinkOperationInFlight = false;
    }
  }

  /// 结束喝水
  Future<void> endDrink() async {
    if (_drinkOperationInFlight || _isDisposed) {
      return;
    }

    _drinkOperationInFlight = true;
    try {
      final deviceId = _selectedDeviceId();
      if (deviceId == null) {
        _showErrorSnackBar('操作失败', '请先选择设备');
        return;
      }

      final bool value = await drinkApi.endDrink(id: deviceId);
      if (_isDisposed) {
        return;
      }

      if (value) {
        _cancelDeviceStatusPolling();
        state.drinkStatus.value = false;
      } else {
        _showErrorSnackBar('操作失败', '结算失败，请稍后重试');
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to stop drink device',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isDisposed) {
        _showErrorSnackBar('操作失败', '结算失败，请稍后重试');
      }
    } finally {
      _drinkOperationInFlight = false;
    }
  }

  /// 删除相对应的device
  void removeDeviceByName(String name) {
    var writeIndex = 0;
    for (var index = 0; index < state.deviceList.length; index++) {
      final device = state.deviceList[index];
      if (device["name"] == name) {
        continue;
      }
      if (writeIndex != index) {
        state.deviceList[writeIndex] = device;
      }
      writeIndex++;
    }
    if (writeIndex < state.deviceList.length) {
      state.deviceList.removeRange(writeIndex, state.deviceList.length);
    }
    if (state.deviceList.isEmpty) {
      _cancelDeviceStatusPolling();
      state.choiceDevice.value = -1;
      state.drinkStatus.value = false;
    } else if (state.choiceDevice.value >= state.deviceList.length) {
      state.choiceDevice.value = state.deviceList.length - 1;
    }
  }

  /// 设置token
  Future<void> setToken(String token) async {
    await drinkApi.setToken(token: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("hui798IsLogin", true);
    await getDeviceList();
  }
}
