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

  void _showErrorSnackBar(String title, String message) {
    final context = Get.context;
    final colorScheme = context != null ? Theme.of(context).colorScheme : null;

    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: colorScheme?.errorContainer,
      colorText: colorScheme?.onErrorContainer,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
      icon: Icon(
        Icons.error,
        color: colorScheme?.onErrorContainer ?? Colors.white,
      ),
    );
  }

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
    state.isLoading.value = true;
    update();
    await checkLogin();
    state.tokenController.text = await drinkApi.getToken();
    state.isLoading.value = false;
    update();
  }

  /// 判断是否需要跳转登录
  Future<void> checkLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool isLogin = prefs.getBool("hui798IsLogin") ?? false;
    if (!isLogin) {
      state.isLoading.value = false;
      update();
      Get.off(() => const DrinkLoginPage());
      return;
    }

    await getDeviceList(showLoading: true);
  }

  /// 获取喝水设备列表
  Future<void> getDeviceList({
    bool showLoading = false,
    bool showRefreshing = false,
  }) async {
    final String? previousDeviceId =
        state.choiceDevice.value >= 0 &&
                state.choiceDevice.value < state.deviceList.length
            ? state.deviceList[state.choiceDevice.value]["id"]?.toString()
            : null;

    if (showLoading) {
      state.isLoading.value = true;
    }
    if (showRefreshing) {
      state.isRefreshing.value = true;
    }
    update();

    try {
      final List<Map> value = await drinkApi.deviceList();
      if (value.isNotEmpty && value[0]["name"] == "Account failure") {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool("hui798IsLogin", false);
        state.deviceList.clear();
        setChoiceDevice(-1);
        state.drinkStatus.value = false;
        state.isLoading.value = false;
        state.isRefreshing.value = false;
        update();
        Get.off(() => const DrinkLoginPage());
        return;
      }

      state.deviceList.value = value;

      if (state.deviceList.isEmpty) {
        setChoiceDevice(-1);
      } else if (previousDeviceId != null) {
        final int preservedIndex = state.deviceList.indexWhere(
          (dynamic device) => device["id"]?.toString() == previousDeviceId,
        );
        setChoiceDevice(preservedIndex == -1 ? 0 : preservedIndex);
      } else {
        setChoiceDevice(0);
      }
    } catch (error) {
      _showErrorSnackBar('加载失败', '设备列表获取失败，请稍后重试');
    } finally {
      state.isLoading.value = false;
      state.isRefreshing.value = false;
      update();
    }
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
      _showErrorSnackBar('操作失败', '设备启动失败，请稍后重试');
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
      _showErrorSnackBar('操作失败', '结算失败，请稍后重试');
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
