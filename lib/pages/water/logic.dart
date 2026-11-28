import 'dart:async';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/unified_login_page.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../../core/services/app_auth_storage.dart';
import '../../core/services/app_logger.dart';
import '../../core/ui/app_snack_bar.dart';
import 'default_device_store.dart';
import 'state.dart';

const String hotWaterStartFailureMessage = '设备开启失败，请稍后重试';
const String hotWaterStopFailureMessage = '设备关闭失败，请稍后重试';
const String hotWaterAddDeviceFailureMessage = '添加设备失败，请稍后重试';

/// 关阀未确认时的服务端兜底提示。
/// 第四轮活体事件证实：关阀接口可能长时间故障（开阀正常），期间用户无法主动
/// 停止计费；`maxtimelimit=30 分钟` 终端到点自动关阀与 `maxfarelimit` 金额上限
/// 由服务端强制（第一轮 openparam + 设备列表字段），客户端不可覆盖。
const String hotWaterCloseFallbackHint = '水阀将在最长 30 分钟由服务端自动关闭，请留意余额扣费';

/// 重复开阀的确定性拒绝码（第二轮 F-04 实测：已开阀再开返回 CORE35104
/// 「网络或设备通讯异常」，与 i18n 表声称的 CORE35107 不符）。不加入自动重试。
const String _kWaterAlreadyOpenResultCode = 'CORE35104';

/// 失败提示优先透传服务端返回的具体 `message`
/// （如「无卡开阀失败,当前设备忙,请稍候再试」），服务端未给出 message 时回退
/// 通用文案。逆向结论见 docs/water_hot_reverse_findings.md：官方 H5 每种
/// 错误码都有专属提示，通用文案会让用户无法判断该不该重试。
String hotWaterFailureMessage(Map<String, dynamic> value, String fallback) {
  final message = value['message']?.toString().trim() ?? '';
  if (message.isEmpty || message == 'null') {
    return fallback;
  }
  return message;
}
const String hotWaterDeleteDeviceFailureMessage = '删除设备失败，请稍后重试';
const String hotWaterDefaultDeviceFailureMessage = '默认设备设置失败，请稍后重试';

abstract class HotWaterApiClient {
  Future<Map<String, dynamic>> getHotWaterDevice();

  Future<bool> userLogin({required String username, required String password});

  Future<String> getCardBalance();

  Future<List> checkHotWaterDevice();

  /// 未关阀记录明细（含补关所需的开阀记录 id）。
  Future<List<Map<String, String>>> getOpenValveRecords();

  Future<Map<String, dynamic>> startHotWater({required String device});

  Future<Map<String, dynamic>> stopHotWater({
    required String device,
    String openappid = '',
  });

  Future<Map> addWaterDevice(String bindCode);

  Future<Map<String, dynamic>> delWaterDevice(String bindCode);
}

class HutHotWaterApiClient implements HotWaterApiClient {
  HutHotWaterApiClient([HutUserApi? api]) : _api = api ?? HutUserApi();

  final HutUserApi _api;

  @override
  Future<Map<String, dynamic>> getHotWaterDevice() {
    return _api.getHotWaterDevice();
  }

  @override
  Future<bool> userLogin({required String username, required String password}) {
    return _api.userLogin(username: username, password: password);
  }

  @override
  Future<String> getCardBalance() {
    return _api.getCardBalance();
  }

  @override
  Future<List> checkHotWaterDevice() {
    return _api.checkHotWaterDevice();
  }

  @override
  Future<List<Map<String, String>>> getOpenValveRecords() {
    return _api.getOpenValveRecords();
  }

  @override
  Future<Map<String, dynamic>> startHotWater({required String device}) {
    return _api.startHotWater(device: device);
  }

  @override
  Future<Map<String, dynamic>> stopHotWater({
    required String device,
    String openappid = '',
  }) {
    return _api.stopHotWater(device: device, openappid: openappid);
  }

  @override
  Future<Map> addWaterDevice(String bindCode) {
    return _api.addWaterDevice(bindCode);
  }

  @override
  Future<Map<String, dynamic>> delWaterDevice(String bindCode) {
    return _api.delWaterDevice(bindCode);
  }
}

abstract class HotWaterAuthStorage {
  Future<String> readHutToken();

  Future<String> readHutDeviceId();

  Future<String> readHutUsername();

  Future<String> readHutPassword();

  Future<bool> isHutLoggedIn();

  Future<void> setHutLoginStatus(bool value);
}

typedef HotWaterLoginRedirect = void Function();

class AppHotWaterAuthStorage implements HotWaterAuthStorage {
  AppHotWaterAuthStorage([AppAuthStorage? storage])
    : _storage = storage ?? AppAuthStorage.instance;

  final AppAuthStorage _storage;

  @override
  Future<String> readHutToken() {
    return _storage.readHutToken();
  }

  @override
  Future<String> readHutDeviceId() {
    return _storage.readHutDeviceId();
  }

  @override
  Future<String> readHutUsername() {
    return _storage.readHutUsername();
  }

  @override
  Future<String> readHutPassword() {
    return _storage.readHutPassword();
  }

  @override
  Future<bool> isHutLoggedIn() {
    return _storage.isHutLoggedIn();
  }

  @override
  Future<void> setHutLoginStatus(bool value) {
    return _storage.setHutLoginStatus(value);
  }
}

class FunctionHotWaterLogic extends GetxController {
  FunctionHotWaterLogic({
    HotWaterApiClient? hotWaterApi,
    HotWaterAuthStorage? authStorage,
    HotWaterDevicePreferenceStore? devicePreferenceStore,
    HotWaterLoginRedirect? redirectToLogin,
    this.loginRedirectDelay = const Duration(milliseconds: 100),
  }) : hutUserApi = hotWaterApi ?? HutHotWaterApiClient(),
       _storage = authStorage ?? AppHotWaterAuthStorage(),
       _devicePreferenceStore =
           devicePreferenceStore ??
           SharedPreferencesHotWaterDevicePreferenceStore(),
       _redirectToLogin =
           redirectToLogin ??
           (() => Get.off(() => UnifiedLoginPage(returnToCaller: true)));

  final FunctionHotWaterState state = FunctionHotWaterState();
  final HotWaterApiClient hutUserApi;
  final HotWaterAuthStorage _storage;
  final HotWaterDevicePreferenceStore _devicePreferenceStore;
  final HotWaterLoginRedirect _redirectToLogin;
  final Duration loginRedirectDelay;
  Future<void>? _deviceListLoad;
  final Map<String, Future<bool>> _deviceMutationLoads =
      <String, Future<bool>>{};
  Timer? _loginRedirectTimer;
  bool _loginRedirectQueued = false;
  bool _waterOperationInFlight = false;
  bool _isDisposed = false;
  int _balanceRefreshGeneration = 0;

  // Local storage for user information
  final Map<String, dynamic> _hutUserInfo = {
    "hutIsLogin": false,
    "username": "",
    "password": "",
    "token": "",
    "deviceId": "",
  };

  // Local method to access user info
  Map<String, dynamic> get hutUserInfo => _hutUserInfo;

  // Local method to update user info
  void setHutUserInfo(String key, dynamic value) {
    _hutUserInfo[key] = value;
    // Persist to storage if needed
    saveUserInfo();
  }

  // Method to save user info to storage
  Future<void> saveUserInfo() async {
    final storageInfo = Map<String, dynamic>.from(_hutUserInfo)
      ..remove('password');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hutUserInfo', storageInfo.toString());
  }

  Future<void> _populateUserInfoFromStorage() async {
    final results = await Future.wait<Object>([
      _storage.readHutToken(),
      _storage.readHutDeviceId(),
      _storage.readHutUsername(),
      _storage.readHutPassword(),
      _storage.isHutLoggedIn(),
    ]);
    if (_isDisposed) {
      return;
    }

    _hutUserInfo["token"] = results[0] as String;
    _hutUserInfo["deviceId"] = results[1] as String;
    _hutUserInfo["username"] = results[2] as String;
    _hutUserInfo["password"] = results[3] as String;
    _hutUserInfo["hutIsLogin"] = results[4] as bool;
  }

  Future<void> loadUserInfo() async {
    try {
      await _populateUserInfoFromStorage();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Error loading HUT user info',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _showStatusSnackBar(
    String title,
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    showAppSnackBar(
      Get.context,
      message: '$title：$message',
      type:
          isError
              ? AppSnackBarType.error
              : isWarning
              ? AppSnackBarType.warning
              : AppSnackBarType.success,
    );
  }

  @override
  void onInit() {
    super.onInit();
    // 初始化时设置设备检查状态为未完成
    state.deviceCheckComplete.value = false;
    unawaited(checkLogin());
  }

  /// 判断是否需要跳转登录
  Future<void> checkLogin() async {
    await loadUserInfo();
    if (_isDisposed) {
      return;
    }

    if (_hutUserInfo["hutIsLogin"] == false) {
      _queueLoginRedirect();
    } else {
      _cancelLoginRedirect();
      await getDeviceList();
    }
  }

  void _queueLoginRedirect() {
    if (_isDisposed) {
      return;
    }

    if (_loginRedirectQueued || (_loginRedirectTimer?.isActive ?? false)) {
      return;
    }

    _loginRedirectQueued = true;
    _loginRedirectTimer = Timer(loginRedirectDelay, _redirectToLogin);
  }

  void _cancelLoginRedirect() {
    _loginRedirectTimer?.cancel();
    _loginRedirectTimer = null;
    _loginRedirectQueued = false;
  }

  @override
  void onClose() {
    _isDisposed = true;
    _balanceRefreshGeneration++;
    _cancelLoginRedirect();
    super.onClose();
  }

  Future<void> _clearInvalidLoginState() async {
    await _storage.setHutLoginStatus(false);
    if (_isDisposed) {
      return;
    }

    _hutUserInfo["hutIsLogin"] = false;
    unawaited(saveUserInfo());
    state.deviceList.clear();
    _assignChoiceDevice(-1);
    state.waterStatus.value = false;
    state.deviceCheckComplete.value = true;
    _queueLoginRedirect();
  }

  Future<void> _applyDeviceList(Map<String, dynamic> value) async {
    if (_isDisposed) {
      return;
    }

    final rawDevices = value["data"];
    state.deviceList.value = rawDevices is List ? rawDevices : [];
    await _applyDefaultDeviceSelection();
    if (_isDisposed) {
      return;
    }

    state.deviceCheckComplete.value = false;
    await Future.wait([_refreshOpenDeviceState(), _refreshBalanceValue()]);
    if (_isDisposed) {
      return;
    }
  }

  /// 按默认设备解析本次要选中的设备。
  ///
  /// 默认设备按设备号匹配，不依赖列表下标：设备列表顺序由服务端下发，
  /// 跨会话可能变化。默认设备已解绑（不在列表中）时回退到第一台设备。
  Future<void> _applyDefaultDeviceSelection() async {
    if (state.deviceList.isEmpty) {
      state.defaultDeviceCode.value = '';
      _assignChoiceDevice(-1);
      return;
    }

    final savedCode = await _devicePreferenceStore.readDefaultDeviceCode();
    if (_isDisposed) {
      return;
    }

    if (savedCode.isEmpty) {
      state.defaultDeviceCode.value = '';
      _assignChoiceDevice(0);
      return;
    }

    final index = _deviceIndexForCode(savedCode);
    if (index == -1) {
      // 默认设备不在当前列表（已被学校侧解绑）：回退到第一台设备。
      // 偏好本身保留，设备重新绑定后仍能自动选中。
      state.defaultDeviceCode.value = '';
      _assignChoiceDevice(0);
      return;
    }

    state.defaultDeviceCode.value = savedCode;
    _assignChoiceDevice(index);
  }

  int _deviceIndexForCode(String deviceCode) {
    for (var index = 0; index < state.deviceList.length; index++) {
      final device = state.deviceList[index];
      if (device is Map && device["poscode"]?.toString() == deviceCode) {
        return index;
      }
    }
    return -1;
  }

  /// 获取喝水设备列表
  ///
  /// 此函数负责从服务器获取用户的热水设备列表，并处理登录状态和设备信息更新。
  /// 如果设备列表获取失败（code为500），则尝试重新登录并重新获取设备信息。
  /// 若登录失败或设备列表为空，则重置相关状态并检查登录状态。
  ///
  /// 返回: 无返回值，通过状态管理更新UI。
  Future<void> getDeviceList() async {
    if (_isDisposed) {
      return;
    }

    final inFlight = _deviceListLoad;
    if (inFlight != null) {
      return inFlight;
    }

    final load = _loadDeviceList();
    _deviceListLoad = load;
    try {
      await load;
    } finally {
      if (identical(_deviceListLoad, load)) {
        _deviceListLoad = null;
      }
    }
  }

  Future<void> _loadDeviceList() async {
    if (_isDisposed) {
      return;
    }

    var value = await hutUserApi.getHotWaterDevice();
    if (_isDisposed) {
      return;
    }

    if (value["code"] == 500) {
      final username = _hutUserInfo["username"]?.toString() ?? '';
      final password = _hutUserInfo["password"]?.toString() ?? '';
      final canRetryLogin =
          _hutUserInfo["hutIsLogin"] == true &&
          username.isNotEmpty &&
          password.isNotEmpty;

      if (canRetryLogin) {
        final isLogin = await hutUserApi.userLogin(
          username: username,
          password: password,
        );
        if (_isDisposed) {
          return;
        }

        if (isLogin) {
          value = await hutUserApi.getHotWaterDevice();
          if (_isDisposed) {
            return;
          }
        }
      }
    }

    if (value["code"] == 500) {
      await _clearInvalidLoginState();
      return;
    }

    await _applyDeviceList(value);
  }

  /// 获取余额
  Future<void> getBalance() async {
    await _refreshBalanceValue();
  }

  Future<void> _refreshBalanceValue() async {
    if (_isDisposed) {
      return;
    }

    final generation = ++_balanceRefreshGeneration;
    try {
      final value = await hutUserApi.getCardBalance();
      if (!_isDisposed && generation == _balanceRefreshGeneration) {
        state.balance.value = value;
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load hot water card balance',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isDisposed && generation == _balanceRefreshGeneration) {
        state.balance.value = '--';
      }
    }
  }

  /// 检查是否有未关闭的设备
  Future<void> checkHotWaterDevice() async {
    if (_isDisposed) {
      return;
    }

    // 开始检查前设置检查状态为未完成
    state.deviceCheckComplete.value = false;
    await _refreshOpenDeviceState();
  }

  Future<void> _refreshOpenDeviceState() async {
    if (_isDisposed) {
      return;
    }

    try {
      final records = await hutUserApi.getOpenValveRecords();
      if (_isDisposed) {
        return;
      }

      AppLogger.debug('Open hot water devices: $records');
      _applyOpenDeviceState(records);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to check open hot water devices',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      // 发生错误时也标记为已完成，避免用户无法使用功能
      if (!_isDisposed) {
        state.deviceCheckComplete.value = true;
      }
    }
  }

  void _applyOpenDeviceState(List<Map<String, String>> records) {
    state.openValveRecords.assignAll(records);
    if (records.isEmpty) {
      state.waterStatus.value = false;
      return;
    }

    final poscode = records.first['poscode'];
    if (poscode == null) {
      state.waterStatus.value = false;
      return;
    }
    final deviceIndex = state.deviceList.indexWhere(
      (element) => element["poscode"] == poscode,
    );
    if (deviceIndex == -1) {
      // 未关阀设备不在常用列表中：主开关不误报"使用中"（旧状态照常清理），
      // 由补关 banner 展示明细（设备号 + 开始时间）供用户直接补关。
      state.waterStatus.value = false;
      return;
    }

    state.waterStatus.value = true;
    _assignChoiceDevice(deviceIndex);
    _showStatusSnackBar('设备状态提醒', '检测到有设备尚未关闭', isWarning: true);
  }

  /// 改变选中的设备值
  void setChoiceDevice(int device) {
    _assignChoiceDevice(device);
  }

  /// 把某台设备设为默认（固定）设备。
  ///
  /// 显式操作，与「本次选择」相互独立：只改默认设备，不改当前选中项。
  /// 传入的索引已是默认设备时，改为取消默认。
  Future<void> toggleDefaultDevice(int device) async {
    if (device < 0 || device >= state.deviceList.length) {
      return;
    }

    final deviceCode = _deviceCodeAt(device);
    if (deviceCode.isEmpty) {
      return;
    }

    if (state.defaultDeviceCode.value == deviceCode) {
      await clearDefaultDevice();
      return;
    }

    try {
      await _devicePreferenceStore.writeDefaultDeviceCode(deviceCode);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to persist hot water default device',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isDisposed) {
        _showStatusSnackBar('操作失败', hotWaterDefaultDeviceFailureMessage, isError: true);
      }
      return;
    }

    if (_isDisposed) {
      return;
    }
    state.defaultDeviceCode.value = deviceCode;
  }

  /// 取消默认（固定）设备。
  Future<void> clearDefaultDevice() async {
    try {
      await _devicePreferenceStore.writeDefaultDeviceCode('');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to clear hot water default device',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isDisposed) {
        _showStatusSnackBar('操作失败', hotWaterDefaultDeviceFailureMessage, isError: true);
      }
      return;
    }

    if (_isDisposed) {
      return;
    }
    state.defaultDeviceCode.value = '';
  }

  /// 设备号（poscode）；设备数据不完整时返回空串。
  String _deviceCodeAt(int index) {
    final device = state.deviceList[index];
    if (device is! Map) {
      return '';
    }
    return device["poscode"]?.toString() ?? '';
  }

  bool _assignChoiceDevice(int device) {
    if (state.choiceDevice.value == device) {
      return false;
    }
    state.choiceDevice.value = device;
    return true;
  }

  /// 开始洗澡
  Future<void> startWater() async {
    if (_waterOperationInFlight) {
      return;
    }

    _waterOperationInFlight = true;
    state.isLoading.value = true;

    try {
      final deviceCode =
          state.deviceList[state.choiceDevice.value]["poscode"]?.toString() ??
          '';
      final value = await hutUserApi.startHotWater(device: deviceCode);
      if (_isDisposed) {
        return;
      }

      if (value['success'] == true && value['result'] == "000000") {
        _showStatusSnackBar('操作成功', '设备已开启');
        state.waterStatus.value = true;
      } else if (value['result'] == _kWaterAlreadyOpenResultCode) {
        // 服务端把"已开阀"的确定性拒绝归类为 CORE35104（网络异常文案），
        // 直接透传会误导用户重试。复查未关阀记录，确认已开则按已在用水处理。
        final alreadyOpen = await _isDeviceAlreadyOpen(deviceCode);
        if (_isDisposed) {
          return;
        }
        if (alreadyOpen) {
          _showStatusSnackBar('设备状态提醒', '设备已在用水中', isWarning: true);
          state.waterStatus.value = true;
        } else {
          _showStatusSnackBar(
            '操作失败',
            hotWaterFailureMessage(value, hotWaterStartFailureMessage),
            isError: true,
          );
        }
      } else {
        _showStatusSnackBar(
          '操作失败',
          hotWaterFailureMessage(value, hotWaterStartFailureMessage),
          isError: true,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to start hot water device',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isDisposed) {
        _showStatusSnackBar('操作失败', '操作失败，请稍后重试', isError: true);
      }
    } finally {
      if (!_isDisposed) {
        _waterOperationInFlight = false;
        state.isLoading.value = false;
      }
    }
  }

  /// 复查未关阀记录，判断 [deviceCode] 是否已在用水。
  Future<bool> _isDeviceAlreadyOpen(String deviceCode) async {
    if (deviceCode.isEmpty) {
      return false;
    }
    try {
      final records = await hutUserApi.getOpenValveRecords();
      return records.any((record) => record['poscode'] == deviceCode);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to recheck open valve records',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// 结束洗澡
  Future<void> endWater() async {
    if (_waterOperationInFlight) {
      return;
    }

    _waterOperationInFlight = true;
    state.isLoading.value = true;

    try {
      final value = await hutUserApi.stopHotWater(
        device: state.deviceList[state.choiceDevice.value]["poscode"],
      );
      if (_isDisposed) {
        return;
      }

      if (value['success'] == true && value['result'] == "000000") {
        _showStatusSnackBar('操作成功', '设备已关闭');
        state.waterStatus.value = false;
        // 关阀成功后刷新未关阀记录，保持补关 banner 与状态一致
        await _refreshOpenDeviceState();
      } else {
        _showStatusSnackBar(
          '操作失败',
          '${hotWaterFailureMessage(value, hotWaterStopFailureMessage)}；'
          '$hotWaterCloseFallbackHint',
          isError: true,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to stop hot water device',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isDisposed) {
        _showStatusSnackBar(
          '操作失败',
          '操作失败，请稍后重试；$hotWaterCloseFallbackHint',
          isError: true,
        );
      }
    } finally {
      if (!_isDisposed) {
        _waterOperationInFlight = false;
        state.isLoading.value = false;
      }
    }
  }

  /// 补关未关阀记录（openappid=开阀记录 id，官方 waterOpenClose 补关路径语义）。
  /// [index] 为 [FunctionHotWaterState.openValveRecords] 下标。
  Future<void> closeUnclosedDevice(int index) async {
    if (index < 0 || index >= state.openValveRecords.length) {
      return;
    }
    final record = state.openValveRecords[index];
    final device = record['poscode'] ?? '';
    final openappid = record['recordId'] ?? '';
    if (device.isEmpty || openappid.isEmpty || _waterOperationInFlight) {
      return;
    }

    _waterOperationInFlight = true;
    state.isLoading.value = true;

    try {
      final value = await hutUserApi.stopHotWater(
        device: device,
        openappid: openappid,
      );
      if (_isDisposed) {
        return;
      }

      if (value['success'] == true && value['result'] == "000000") {
        _showStatusSnackBar('操作成功', '设备 $device 已关闭');
        await _refreshOpenDeviceState();
      } else {
        _showStatusSnackBar(
          '操作失败',
          '${hotWaterFailureMessage(value, hotWaterStopFailureMessage)}；'
          '$hotWaterCloseFallbackHint',
          isError: true,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to close unclosed hot water device',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isDisposed) {
        _showStatusSnackBar(
          '操作失败',
          '操作失败，请稍后重试；$hotWaterCloseFallbackHint',
          isError: true,
        );
      }
    } finally {
      if (!_isDisposed) {
        _waterOperationInFlight = false;
        state.isLoading.value = false;
      }
    }
  }

  /// 添加热水设备
  /// [deviceCode] 6位设备号
  Future<bool> addDevice(String deviceCode) async {
    if (deviceCode.length != 6 || int.tryParse(deviceCode) == null) {
      _showStatusSnackBar('输入有误', '设备号需为 6 位数字', isWarning: true);
      return false;
    }

    final key = 'add:$deviceCode';
    final inFlight = _deviceMutationLoads[key];
    if (inFlight != null) {
      return inFlight;
    }

    final load = _addDevice(deviceCode);
    _deviceMutationLoads[key] = load;
    try {
      return await load;
    } finally {
      if (identical(_deviceMutationLoads[key], load)) {
        _deviceMutationLoads.remove(key);
      }
    }
  }

  Future<bool> _addDevice(String deviceCode) async {
    try {
      final value = await hutUserApi.addWaterDevice(deviceCode);
      if (_isDisposed) {
        return false;
      }

      if (value['result'] == true) {
        _showStatusSnackBar('操作成功', '设备添加成功');
        await getDeviceList(); // 刷新设备列表
        return true;
      } else {
        _showStatusSnackBar(
          '操作失败',
          hotWaterAddDeviceFailureMessage,
          isError: true,
        );
        return false;
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to add hot water device',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isDisposed) {
        _showStatusSnackBar('操作失败', '添加设备失败，请稍后重试', isError: true);
      }
      return false;
    }
  }

  /// 删除热水设备
  /// [deviceCode] 设备号
  Future<bool> deleteDevice(String deviceCode) async {
    final key = 'delete:$deviceCode';
    final inFlight = _deviceMutationLoads[key];
    if (inFlight != null) {
      return inFlight;
    }

    final load = _deleteDevice(deviceCode);
    _deviceMutationLoads[key] = load;
    try {
      return await load;
    } finally {
      if (identical(_deviceMutationLoads[key], load)) {
        _deviceMutationLoads.remove(key);
      }
    }
  }

  /// 被删除的设备正是默认设备时，清掉本机默认偏好。
  Future<void> _clearDefaultDeviceIfMatches(String deviceCode) async {
    if (deviceCode.isEmpty || state.defaultDeviceCode.value != deviceCode) {
      return;
    }
    await clearDefaultDevice();
  }

  Future<bool> _deleteDevice(String deviceCode) async {
    try {
      final value = await hutUserApi.delWaterDevice(deviceCode);
      if (_isDisposed) {
        return false;
      }

      if (value['result'] == true) {
        _showStatusSnackBar('操作成功', '设备删除成功');
        await _clearDefaultDeviceIfMatches(deviceCode);
        await getDeviceList();

        return true;
      } else {
        _showStatusSnackBar(
          '操作失败',
          hotWaterDeleteDeviceFailureMessage,
          isError: true,
        );
        return false;
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to delete hot water device',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isDisposed) {
        _showStatusSnackBar('操作失败', '删除设备失败，请稍后重试', isError: true);
      }
      return false;
    }
  }
}
