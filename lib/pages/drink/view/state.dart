import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class FunctionDrinkState {
  // 设备列表
  RxList deviceList = [].obs;

  // 页面加载状态
  RxBool isLoading = true.obs;

  // 刷新状态
  RxBool isRefreshing = false.obs;

  // 选中的设备值
  RxInt choiceDevice = (-1).obs;

  // 喝水按钮状态
  RxBool drinkStatus = false.obs;

  // 设备状态检测
  Timer? deviceStatusTimer;

  // Token框控制器
  final TextEditingController tokenController = TextEditingController();

  FunctionDrinkState() {
    ///Initialize variables
  }
}
