import 'package:flutter/material.dart';

import '../../core/ui/app_snack_bar.dart';
import '../../utils/hut_user_api.dart';

var api = HutUserApi();
String doubleRandom = "0";
String timestamp = DateTime.timestamp().millisecondsSinceEpoch.toString();
bool first = true;

void loginToHuT(String username, String password, context) {
  api.userLogin(username: username, password: password).then((value) {
    if (value) {
      showAppSnackBar(context, message: '登录成功', type: AppSnackBarType.success);
      Navigator.pop(context);
    } else {
      showAppSnackBar(context, message: '登录失败', type: AppSnackBarType.error);
    }
  });
}
