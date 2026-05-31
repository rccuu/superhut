import 'dart:async';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/hut/view.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../../core/services/app_auth_storage.dart';
import '../../core/services/app_logger.dart';
import '../../core/ui/app_snack_bar.dart';
import 'state.dart';

const String hotWaterStartFailureMessage = '设备开启失败，请稍后重试';
const String hotWaterAddDeviceFailureMessage = '添加设备失败，请稍后重试';
const String hotWaterDeleteDeviceFailureMessage = '删除设备失败，请稍后重试';

abstract class HotWaterApiClient {
  Future<Map<String, dynamic>> getHotWaterDevice();

  Future<bool> userLogin({required String username, required String password});

  Future<String> getCardBalance();

  Future<List> checkHotWaterDevice();

  Future<Map> startHotWater({required String device});

  Future<bool> stopHotWater({required String device});

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
  Future<Map> startHotWater({required String device}) {
    return _api.startHotWater(device: device);
  }

  @override
  Future<bool> stopHotWater({required String device}) {
    return _api.stopHotWater(device: device);
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
    HotWaterLoginRedirect? redirectToLogin,
    this.loginRedirectDelay = const Duration(milliseconds: 100),
  }) : hutUserApi = hotWaterApi ?? HutHotWaterApiClient(),
       _storage = authStorage ?? AppHotWaterAuthStorage(),
       _redirectToLogin =
           redirectToLogin ?? (() => Get.off(() => HutLoginPage()));

  final FunctionHotWaterState state = FunctionHotWaterState();
  final HotWaterApiClient hutUserApi;
  final HotWaterAuthStorage _storage;
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
    _assignChoiceDevice(state.deviceList.isNotEmpty ? 0 : -1);
    state.deviceCheckComplete.value = false;
    await Future.wait([_refreshOpenDeviceState(), _refreshBalanceValue()]);
    if (_isDisposed) {
      return;
    }
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
      final value = await hutUserApi.checkHotWaterDevice();
      if (_isDisposed) {
        return;
      }

      AppLogger.debug('Open hot water devices: $value');
      _applyOpenDeviceState(value);
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

  void _applyOpenDeviceState(List value) {
    if (value.isEmpty) {
      state.waterStatus.value = false;
      return;
    }

    final deviceIndex = state.deviceList.indexWhere(
      (element) => element["poscode"] == value.first,
    );
    if (deviceIndex == -1) {
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
      final value = await hutUserApi.startHotWater(
        device: state.deviceList[state.choiceDevice.value]["poscode"],
      );
      if (_isDisposed) {
        return;
      }

      if (value['success'] && value['result'] == "000000") {
        _showStatusSnackBar('操作成功', '设备已开启');
        state.waterStatus.value = true;
      } else {
        _showStatusSnackBar('操作失败', hotWaterStartFailureMessage, isError: true);
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

      if (value) {
        _showStatusSnackBar('操作成功', '设备已关闭');
        state.waterStatus.value = false;
      } else {
        _showStatusSnackBar('操作失败', '设备关闭失败，请稍后重试', isError: true);
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to stop hot water device',
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

  Future<bool> _deleteDevice(String deviceCode) async {
    try {
      final value = await hutUserApi.delWaterDevice(deviceCode);
      if (_isDisposed) {
        return false;
      }

      if (value['result'] == true) {
        _showStatusSnackBar('操作成功', '设备删除成功');
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
