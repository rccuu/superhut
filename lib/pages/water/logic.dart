import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/hut/view.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../../core/ui/color_scheme_ext.dart';
import '../../core/services/app_auth_storage.dart';
import '../../core/services/app_logger.dart';
import 'state.dart';

class FunctionHotWaterLogic extends GetxController {
  final FunctionHotWaterState state = FunctionHotWaterState();
  final hutUserApi = HutUserApi();
  final AppAuthStorage _storage = AppAuthStorage.instance;

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
    update();
  }

  // Method to save user info to storage
  Future<void> saveUserInfo() async {
    final storageInfo = Map<String, dynamic>.from(_hutUserInfo)
      ..remove('password');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hutUserInfo', storageInfo.toString());
  }

  Future<void> _populateUserInfoFromStorage() async {
    _hutUserInfo["token"] = await _storage.readHutToken();
    _hutUserInfo["deviceId"] = await _storage.readHutDeviceId();
    _hutUserInfo["username"] = await _storage.readHutUsername();
    _hutUserInfo["password"] = await _storage.readHutPassword();
    _hutUserInfo["hutIsLogin"] = await _storage.isHutLoggedIn();
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
    final context = Get.context;
    final colorScheme = context != null ? Theme.of(context).colorScheme : null;
    final backgroundColor =
        isError
            ? colorScheme?.errorContainer
            : isWarning
            ? colorScheme?.warningContainerSoft
            : colorScheme?.successContainerSoft;
    final textColor =
        isError
            ? colorScheme?.onErrorContainer
            : isWarning
            ? colorScheme?.onWarningContainerSoft
            : colorScheme?.onSuccessContainerSoft;

    Get.snackbar(
      title,
      message,
      backgroundColor: backgroundColor,
      colorText: textColor,
      margin: const EdgeInsets.only(top: 30, left: 50, right: 50),
    );
  }

  @override
  void onInit() {
    super.onInit();
    loadUserInfo();
    checkLogin();
    // 初始化时设置设备检查状态为未完成
    state.deviceCheckComplete.value = false;
  }

  /// 判断是否需要跳转登录
  Future<void> checkLogin() async {
    await _populateUserInfoFromStorage();

    if (_hutUserInfo["hutIsLogin"] == false) {
      Future.delayed(const Duration(milliseconds: 100), () {
        Get.off(() => HutLoginPage());
      });
    } else {
      //setHutUserInfo("hutIsLogin", true);
      getDeviceList();
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
    //  bool isV =await hutUserApi.checkTokenValidity();
    // await hutUserApi.userLogin(username: _hutUserInfo["username"], password: _hutUserInfo["password"]);
    // print("LLLLLLLLLLLLLLLLLLLLLLLLLL:$isV");
    // 尝试首次获取设备列表
    await hutUserApi.getHotWaterDevice().then((value) async {
      // print(value);

      if (value["code"] == 500) {
        // 处理登录失效情况：尝试自动重新登录
        if (_hutUserInfo["hutIsLogin"]) {
          bool isLogin = await hutUserApi.userLogin(
            username: _hutUserInfo["username"],
            password: _hutUserInfo["password"],
          );
          if (isLogin) {
            // 重新登录成功后再次获取设备列表
            await hutUserApi.getHotWaterDevice().then((value) async {
              if (value["code"] != 500) {
                // 更新设备列表及关联状态
                state.deviceList.value = value["data"];
                setChoiceDevice(state.deviceList.isNotEmpty ? 0 : -1);
                await checkHotWaterDevice();
                await getBalance();
                update();
              }
            });
            return;
          }
        }
        // 登录失败处理：重置登录状态并清除设备信息
        await _storage.setHutLoginStatus(false);
        setHutUserInfo("hutIsLogin", false);
        state.deviceList.clear();
        setChoiceDevice(-1);
        state.waterStatus.value = false;
        update();
        checkLogin();
      } else {
        // 正常获取到设备列表时更新状态
        state.deviceList.value = value["data"];
        setChoiceDevice(state.deviceList.isNotEmpty ? 0 : -1);
        await checkHotWaterDevice();
        await getBalance();
        update();
      }
    });
  }

  /// 获取余额
  Future<void> getBalance() async {
    try {
      final value = await hutUserApi.getCardBalance();
      state.balance.value = value;
      update();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load hot water card balance',
        error: error,
        stackTrace: stackTrace,
      );
      state.balance.value = '--';
      update();
    }
  }

  /// 检查是否有未关闭的设备
  Future<void> checkHotWaterDevice() async {
    // 开始检查前设置检查状态为未完成
    state.deviceCheckComplete.value = false;
    update();

    await hutUserApi
        .checkHotWaterDevice()
        .then((value) {
          AppLogger.debug('Open hot water devices: $value');
          if (value.isNotEmpty) {
            state.waterStatus.value = true;
            state.choiceDevice.value = state.deviceList.indexWhere(
              (element) => element["poscode"] == value.first,
            );
            _showStatusSnackBar('设备状态提醒', '检测到有设备尚未关闭', isWarning: true);
            update();
          }

          // 设置检查状态为已完成
          state.deviceCheckComplete.value = true;
          update();
        })
        .catchError((error) {
          // 发生错误时也标记为已完成，避免用户无法使用功能
          state.deviceCheckComplete.value = true;
          update();
        });
  }

  /// 改变选中的设备值
  void setChoiceDevice(int device) {
    state.choiceDevice.value = device;
    update();
  }

  /// 开始洗澡
  Future<void> startWater() async {
    state.isLoading.value = true;
    update();

    hutUserApi
        .startHotWater(
          device: state.deviceList[state.choiceDevice.value]["poscode"],
        )
        .then((value) {
          state.isLoading.value = false;
          if (value['success'] && value['result'] == "000000") {
            _showStatusSnackBar('操作成功', '设备已开启');
            state.waterStatus.value = true;
            update();
          } else {
            _showStatusSnackBar(
              '操作失败',
              '设备开启失败：${value['message']}',
              isError: true,
            );
          }
          update();
        })
        .catchError((error) {
          state.isLoading.value = false;
          _showStatusSnackBar('操作失败', '操作失败，请稍后重试', isError: true);
          update();
        });
  }

  /// 结束洗澡
  void endWater() {
    state.isLoading.value = true;
    update();

    hutUserApi
        .stopHotWater(
          device: state.deviceList[state.choiceDevice.value]["poscode"],
        )
        .then((value) {
          state.isLoading.value = false;
          if (value) {
            _showStatusSnackBar('操作成功', '设备已关闭');
            state.waterStatus.value = false;
            update();
          } else {
            _showStatusSnackBar('操作失败', '设备关闭失败，请稍后重试', isError: true);
          }
          update();
        })
        .catchError((error) {
          state.isLoading.value = false;
          _showStatusSnackBar('操作失败', '操作失败，请稍后重试', isError: true);
          update();
        });
  }

  /// 添加热水设备
  /// [deviceCode] 6位设备号
  Future<bool> addDevice(String deviceCode) async {
    if (deviceCode.length != 6 || int.tryParse(deviceCode) == null) {
      _showStatusSnackBar('输入有误', '设备号需为 6 位数字', isWarning: true);
      return false;
    }

    return await hutUserApi.addWaterDevice(deviceCode).then((value) {
      if (value['result']) {
        _showStatusSnackBar('操作成功', '设备添加成功');
        getDeviceList(); // 刷新设备列表
        return true;
      } else {
        _showStatusSnackBar('操作失败', '添加设备失败：${value['msg']}', isError: true);
        return false;
      }
    });
  }

  /// 删除热水设备
  /// [deviceCode] 设备号
  Future<bool> deleteDevice(String deviceCode) async {
    return await hutUserApi.delWaterDevice(deviceCode).then((value) {
      if (value['result']) {
        _showStatusSnackBar('操作成功', '设备删除成功');
        getDeviceList();

        return true;
      } else {
        _showStatusSnackBar('操作失败', '删除设备失败：${value['msg']}', isError: true);
        return false;
      }
    });
  }
}
