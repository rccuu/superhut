import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/drink/login/view.dart';

import '../api/drink_api.dart';
import 'state.dart';

class FunctionDrinkLogic extends GetxController {
  final FunctionDrinkState state = FunctionDrinkState();
  final DrinkApi drinkApi = DrinkApi();

  @override
  void onInit() {
    super.onInit();
    unawaited(_initialize());
  }

  @override
  void onClose() {
    state.deviceStatusTimer?.cancel();
    state.tokenController.dispose();
    super.onClose();
  }

  Future<void> _initialize() async {
    await checkLogin();
    state.tokenController.text = await drinkApi.getToken();
  }

  /// 判断是否需要跳转登录
  Future<void> checkLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isLogin = prefs.getBool("hui798IsLogin") ?? false;
    if (!isLogin) {
      Get.off(const DrinkLoginPage());
      return;
    }

    await getDeviceList();
  }

  /// 获取喝水设备列表
  Future<void> getDeviceList() async {
    final List<Map> value = await drinkApi.deviceList();
    if (value.isNotEmpty && value[0]["name"] == "Account failure") {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool("hui798IsLogin", false);
      state.deviceList.clear();
      setChoiceDevice(-1);
      state.drinkStatus.value = false;
      update();
      Get.off(const DrinkLoginPage());
      return;
    }

    state.deviceList.value = value;
    setChoiceDevice(state.deviceList.isNotEmpty ? 0 : -1);
    update();
  }

  /// 收藏或取消收藏设备
  Future<bool> favoDevice(String id, bool isUnFavo) async {
    return drinkApi.favoDevice(id: id, isUnFavo: isUnFavo);
  }

  /// 格式化设备名称
  String formatDeviceName(String name) {
    if (name.contains("栋")) {
      return name.replaceAll("栋", "-");
    } else {
      return name;
    }
  }

  /// 改变选中的设备值
  void setChoiceDevice(int device) {
    state.choiceDevice.value = device;
    update();
  }

  /// 开始喝水
  Future<void> startDrink() async {
    final String deviceId =
        state.deviceList[state.choiceDevice.value]["id"].toString();
    final bool value = await drinkApi.startDrink(id: deviceId);
    if (value) {
      int count = 0;
      state.drinkStatus.value = true;
      unawaited(getDeviceList());
      state.deviceStatusTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        final bool isAvailable = await drinkApi.isAvailableDevice(id: deviceId);
        if (isAvailable && count > 3) {
          state.drinkStatus.value = false;
          state.deviceStatusTimer?.cancel();
          update();
        } else if (isAvailable) {
          count++;
        }
      });
    } else {
      Get.snackbar(
        '失败',
        '开启失败',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(10),
        borderRadius: 10,
        icon: Icon(Icons.error, color: Colors.white),
      );
    }
    update();
  }

  /// 结束喝水
  Future<void> endDrink() async {
    final String deviceId =
        state.deviceList[state.choiceDevice.value]["id"].toString();
    final bool value = await drinkApi.endDrink(id: deviceId);
    if (value) {
      state.deviceStatusTimer?.cancel();
      state.drinkStatus.value = false;
    } else {
      Get.snackbar(
        '失败',
        '结算失败',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(10),
        borderRadius: 10,
        icon: Icon(Icons.error, color: Colors.white),
      );
    }
    update();
  }

  /// 删除相对应的device
  void removeDeviceByName(String name) {
    state.deviceList.removeWhere((element) => element["name"] == name);
    if (state.deviceList.isEmpty) {
      state.choiceDevice.value = -1;
      state.drinkStatus.value = false;
    } else if (state.choiceDevice.value >= state.deviceList.length) {
      state.choiceDevice.value = state.deviceList.length - 1;
    }
    update();
  }

  /// 设置token
  void setToken(String token) {
    drinkApi.setToken(token: token).then((value) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool("hui798IsLogin", true);
      await getDeviceList();
      update();
    });
  }
}
