import 'package:get/get.dart';
import 'package:superhut/pages/hutpages/hutmain_state.dart';

import '../../core/services/app_auth_storage.dart';
import '../../login/hut/view.dart';
import '../../utils/hut_user_api.dart';

class HutMainLogic extends GetxController {
  final HutMainState state = HutMainState();
  final api = HutUserApi();
  final AppAuthStorage _storage = AppAuthStorage.instance;
  List funList = [];

  Future<List> getFunList() async {
    if (state.isLoad.value) {
      return funList;
    }
    funList = await api.getFunctionList();
    state.isLoad.value = true;
    update();
    return funList;
  }

  /// 判断是否需要跳转登录
  Future<void> checkLogin() async {
    final bool hsa = await _storage.isHutLoggedIn();

    if (hsa == false) {
      Future.delayed(const Duration(milliseconds: 100), () {
        Get.off(() => HutLoginPage());
      });
    }
  }
}
