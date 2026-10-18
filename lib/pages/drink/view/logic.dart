import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/drink/login/view.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/ui/app_snack_bar.dart';
import '../api/drink_api.dart';
import '../api/drink_device_status.dart';
import '../api/drink_result.dart';
import '../core/drink_device.dart';
import '../core/drink_failure_prompt.dart';
import 'state.dart';

/// 本地存储键。顺序与布局是设备列表的三个可持久化状态。
const String _deviceOrderKey = 'device_order';
const String _deviceLayoutKey = 'device_list_layout';
const String _deviceNoteKeyPrefix = 'device_note_';

class FunctionDrinkLogic extends GetxController {
  FunctionDrinkLogic({
    DrinkApiClient? drinkApi,
    this.statusPollInterval = const Duration(seconds: 2),
    int requiredAvailablePolls = 3,
    this.pollCeiling = const Duration(minutes: 30),
    void Function()? redirectToLogin,
  }) : drinkApi = drinkApi ?? DrinkApi(),
       requiredAvailablePolls = requiredAvailablePolls.clamp(1, 10).toInt(),
       _redirectToLogin =
           redirectToLogin ?? (() => Get.off(() => const DrinkLoginPage()));

  final FunctionDrinkState state = FunctionDrinkState();
  final DrinkApiClient drinkApi;
  final Duration statusPollInterval;
  final int requiredAvailablePolls;

  /// 状态轮询上限：自开始起经过该时长后自动停止，防止异常情况下
  /// 定时器长期驻留。与代际计数叠加，不替换。
  final Duration pollCeiling;
  final void Function() _redirectToLogin;

  /// 轮询起点。仅供测试拨动（`debugPollStartedAtOverride`），生产代码为 null。
  DateTime? _debugPollStartedAtOverride;
  int _drinkStatusPollGeneration = 0;
  Future<void>? _deviceListLoad;
  final Map<String, Future<bool>> _favoDeviceLoads = <String, Future<bool>>{};
  bool _drinkOperationInFlight = false;
  bool _loginRedirectQueued = false;
  bool _isDisposed = false;

  /// 在途期间又有人要求重载。不能直接丢掉：扫码添加后就靠这一次补跑
  /// 把新设备列出来。
  bool _reloadQueued = false;

  SharedPreferences? _prefs;

  void _showErrorSnackBar(String title, String message) {
    showAppSnackBar(
      Get.context,
      message: '$title：$message',
      type: AppSnackBarType.error,
    );
  }

  void _showPrompt(DrinkPrompt prompt) {
    showAppSnackBar(Get.context, message: prompt.text, type: prompt.type);
  }

  void _showSuccess(String message) {
    showAppSnackBar(
      Get.context,
      message: message,
      type: AppSnackBarType.success,
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
    final SharedPreferences prefs = await _preferences();
    if (_isDisposed) {
      return;
    }
    final String? savedLayout = prefs.getString(_deviceLayoutKey);
    if (savedLayout == 'list' || savedLayout == 'grid') {
      state.layoutMode.value = savedLayout!;
    }

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

  Future<SharedPreferences> _preferences() async {
    return _prefs ??= await SharedPreferences.getInstance();
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
      // 在途时不并发第二个请求，但记下这次要求：当前请求的结果可能早于
      // 刚添加的设备，不补跑就会漏掉新条目。
      _reloadQueued = true;
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

    if (_reloadQueued) {
      _reloadQueued = false;
      return getDeviceList();
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
            ? drinkDeviceId(state.deviceList[state.choiceDevice.value])
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

        // 这条分支直接 return，末尾的补跑不会执行；标记不清掉，
        // 下次进页面加载完就会多发一整轮请求。
        _reloadQueued = false;
        _cancelDeviceStatusPolling();
        state.deviceList.clear();
        _assignChoiceDevice(-1);
        state.drinkStatus.value = false;
        state.isLoading.value = false;
        state.isRefreshing.value = false;
        _queueLoginRedirect();
        return;
      }

      final List<Map> ordered = await _withSavedOrder(value);
      state.deviceList.value = ordered;
      await _loadDeviceNotes(ordered);
      if (_isDisposed) {
        return;
      }

      if (state.deviceList.isEmpty) {
        _cancelDeviceStatusPolling();
        state.drinkStatus.value = false;
        _assignChoiceDevice(-1);
      } else if (previousDeviceId != null) {
        final int preservedIndex = state.deviceList.indexWhere(
          (dynamic device) => drinkDeviceId(device) == previousDeviceId,
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

  /// 按本地保存的顺序重排，已下架的设备自然被忽略，新增设备排在末尾。
  Future<List<Map>> _withSavedOrder(List<Map> devices) async {
    final SharedPreferences prefs = await _preferences();
    final List<String> savedOrder = prefs.getStringList(_deviceOrderKey) ?? [];
    return applyDrinkDeviceOrder(devices, savedOrder);
  }

  Future<void> _loadDeviceNotes(List<Map> devices) async {
    final SharedPreferences prefs = await _preferences();
    final Map<String, String> notes = <String, String>{};
    for (final device in devices) {
      final String id = drinkDeviceId(device);
      if (id.isEmpty) {
        continue;
      }
      final String? note = prefs.getString('$_deviceNoteKeyPrefix$id');
      if (note != null && note.isNotEmpty) {
        notes[id] = note;
      }
    }
    state.deviceNotes.assignAll(notes);
  }

  /// 保存设备备注；空备注等于清除。
  Future<void> saveDeviceNote(String deviceId, String note) async {
    if (deviceId.isEmpty) {
      return;
    }

    final SharedPreferences prefs = await _preferences();
    final String key = '$_deviceNoteKeyPrefix$deviceId';
    if (note.isEmpty) {
      await prefs.remove(key);
      state.deviceNotes.remove(deviceId);
      // 标题是在 Obx 里算好的，这里再通知一次列表，读列表的订阅者才会重画。
      state.deviceList.refresh();
      return;
    }

    await prefs.setString(key, note);
    state.deviceNotes[deviceId] = note;
    state.deviceList.refresh();
  }

  /// 设备标题：有备注显示备注，否则显示格式化后的设备名。
  String deviceTitle(dynamic device) {
    final String name = formatDeviceName(drinkDeviceName(device));
    final String? note = state.deviceNotes[drinkDeviceId(device)];
    if (note != null && note.isNotEmpty) {
      return note;
    }
    return name;
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

  /// 扫码添加设备：二维码末段先经 `qr/use` 换取真实设备 ID，再收藏。
  ///
  /// 解析出设备 ID 时以该 ID 收藏；`qr/use` 无法解析（响应无设备、服务端
  /// 拒绝或网络异常）时回退二维码末段收藏，尽量保持添加能力；末段为空
  /// 时既不解析也不收藏，直接按失败处理。
  Future<bool> addDeviceByQrCode(String rawCode) async {
    final int slashIndex = rawCode.lastIndexOf('/');
    final String tail = slashIndex == -1 ? rawCode : rawCode.substring(
      slashIndex + 1,
    );
    if (tail.isEmpty) {
      return false;
    }

    String deviceId = tail;
    try {
      final String resolved = await drinkApi.resolveQrDevice(qrId: tail);
      if (resolved.isNotEmpty) {
        deviceId = resolved;
      }
    } catch (_) {
      // 解析失败回退二维码末段收藏。
    }
    return favoDevice(deviceId, false);
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
    if (state.drinkStatus.value) {
      _showPrompt(_refuseWhileDrinking());
      return;
    }
    _assignChoiceDevice(device);
  }

  bool _assignChoiceDevice(int device) {
    if (state.choiceDevice.value == device) {
      return false;
    }

    state.choiceDevice.value = device;
    return true;
  }

  /// 切换列表布局：'list' | 'grid'
  Future<void> setLayoutMode(String mode) async {
    if (mode != 'list' && mode != 'grid') {
      return;
    }
    if (state.layoutMode.value == mode) {
      return;
    }

    state.layoutMode.value = mode;
    final SharedPreferences prefs = await _preferences();
    await prefs.setString(_deviceLayoutKey, mode);
  }

  /// 进入 / 退出拖拽排序模式
  void toggleReorderMode() {
    if (state.drinkStatus.value) {
      _showPrompt(_refuseWhileDrinking());
      return;
    }
    if (state.deviceList.isEmpty) {
      return;
    }

    state.isReordering.value = !state.isReordering.value;
  }

  /// 拖拽重排（ReorderableListView 回调）
  void reorderDevices(int oldIndex, int newIndex) {
    final int count = state.deviceList.length;
    if (oldIndex < 0 || oldIndex >= count) {
      return;
    }

    var target = newIndex;
    if (target > oldIndex) {
      target -= 1;
    }
    if (target < 0 || target >= count) {
      return;
    }

    final String selectedId = _selectedDeviceId() ?? '';
    final dynamic item = state.deviceList.removeAt(oldIndex);
    state.deviceList.insert(target, item);

    if (selectedId.isNotEmpty) {
      _assignChoiceDevice(
        state.deviceList.indexWhere(
          (dynamic device) => drinkDeviceId(device) == selectedId,
        ),
      );
    }

    unawaited(_saveDeviceOrder());
  }

  Future<void> _saveDeviceOrder() async {
    final SharedPreferences prefs = await _preferences();
    final List<String> ids =
        state.deviceList
            .map(drinkDeviceId)
            .where((String id) => id.isNotEmpty)
            .toList();
    await prefs.setStringList(_deviceOrderKey, ids);
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

  DrinkPrompt _refuseWhileDrinking() {
    return const DrinkPrompt(
      title: '提示',
      message: '正在接水中，请先结算',
      type: AppSnackBarType.info,
    );
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

    final id = drinkDeviceId(device);
    if (id.isEmpty) {
      return null;
    }
    return id;
  }

  void _scheduleDeviceStatusPolling({
    required String deviceId,
    required int generation,
    required int availablePolls,
    DateTime? startedAt,
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
          startedAt: startedAt,
        ),
      );
    });
  }

  Future<void> _pollDeviceStatus({
    required String deviceId,
    required int generation,
    required int availablePolls,
    DateTime? startedAt,
  }) async {
    if (generation != _drinkStatusPollGeneration || !state.drinkStatus.value) {
      return;
    }

    // 轮询上限：自开始起超过 [pollCeiling] 后静默停止，不弹提示。
    final DateTime pollStart =
        startedAt ?? _debugPollStartedAtOverride ?? DateTime.now();
    if (DateTime.now().difference(pollStart) >= pollCeiling) {
      _cancelDeviceStatusPolling();
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
        startedAt: startedAt,
      );
    } catch (_) {
      _scheduleDeviceStatusPolling(
        deviceId: deviceId,
        generation: generation,
        availablePolls: availablePolls,
        startedAt: startedAt,
      );
    }
  }

  /// 测试专用：拨动轮询起点，模拟「轮询已经跑了很久」。
  @visibleForTesting
  void debugPollStartedAtOverride(DateTime? value) {
    _debugPollStartedAtOverride = value;
  }

  /// 开始喝水
  ///
  /// 流程：设备状态预检（离线/禁用拦截、占用中转结算态）→ 钱包支付
  /// （91）→ 被拒且非登录过期时回退支付宝（21）一次。
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

      // 预检：状态查询本身失败时不拦截（开始请求自己会暴露错误）。
      final DeviceStatusResult precheck = await drinkApi.deviceStatus(
        id: deviceId,
      );
      if (_isDisposed) {
        return;
      }
      if (precheck.success && precheck.status != null) {
        final DrinkDeviceStatus status = precheck.status!;
        if (status.isOffline) {
          _showErrorSnackBar('设备离线', '设备当前不在线，请稍后再试');
          return;
        }
        if (status.isDisabled) {
          _showErrorSnackBar('设备禁用', '设备已被禁用，请联系管理员');
          return;
        }
        if (!status.isAvailable) {
          // 设备正在运行（可能之前开过水）：同步为可结算状态并开始轮询，
          // 用户点结算即可结束那一单；不再重发开始请求。
          _cancelDeviceStatusPolling();
          state.drinkStatus.value = true;
          _showPrompt(
            const DrinkPrompt(
              title: '设备使用中',
              message: '设备正在使用中，可点击结算结束本次使用',
              type: AppSnackBarType.info,
            ),
          );
          final generation = _drinkStatusPollGeneration;
          _scheduleDeviceStatusPolling(
            deviceId: deviceId,
            generation: generation,
            availablePolls: 0,
            startedAt: DateTime.now(),
          );
          return;
        }
      }

      final DrinkResult walletResult = await drinkApi.startDrink(
        id: deviceId,
        ptype: DrinkApi.walletPaymentType,
      );
      if (_isDisposed) {
        return;
      }
      // 服务端拒绝且非登录过期时回退支付宝免密（21）再试一次；
      // 请求抛错则直接按失败呈现，回退只针对明确拒绝。
      DrinkResult result = walletResult;
      if (!walletResult.success &&
          !walletResult.isSessionExpired &&
          walletResult.code != null) {
        result = await drinkApi.startDrink(
          id: deviceId,
          ptype: DrinkApi.alipayPaymentType,
        );
        if (_isDisposed) {
          return;
        }
      }

      if (result.success) {
        _cancelDeviceStatusPolling();
        state.drinkStatus.value = true;
        _showSuccess('开始接水');
        unawaited(getDeviceList());
        final generation = _drinkStatusPollGeneration;
        _scheduleDeviceStatusPolling(
          deviceId: deviceId,
          generation: generation,
          availablePolls: 0,
          startedAt: DateTime.now(),
        );
      } else {
        // 透出服务端原因，登录态过期单独引导重新登录。
        _showPrompt(drinkFailurePrompt(result, fallback: '设备无响应，请检查设备状态'));
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

      final DrinkResult result = await drinkApi.endDrink(id: deviceId);

      // 先停轮询、退接水态，再看结果：结算失败时也不能让页面卡在
      // 「正在接水」并把后续失败都归到同一台设备上。
      _cancelDeviceStatusPolling();
      state.drinkStatus.value = false;

      if (_isDisposed) {
        return;
      }

      if (result.success) {
        _showSuccess('已结算');
      } else {
        _showPrompt(drinkFailurePrompt(result, fallback: '结算可能未成功，请检查'));
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to stop drink device',
        error: error,
        stackTrace: stackTrace,
      );
      state.drinkStatus.value = false;
      _cancelDeviceStatusPolling();
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
    unawaited(_saveDeviceOrder());
  }

  /// 设置token
  Future<void> setToken(String token) async {
    await drinkApi.setToken(token: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("hui798IsLogin", true);
    await getDeviceList();
  }
}
