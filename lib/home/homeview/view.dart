import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:ionicons/ionicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/Functionpage/view.dart';
import 'package:superhut/home/coursetable/view.dart';
import 'package:superhut/home/userpage/view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_logger.dart';
import '../../pages/Electricitybill/electricity_api.dart';
import '../../pages/Electricitybill/electricity_page.dart';
import 'logic.dart';

class HomeviewPage extends StatefulWidget {
  const HomeviewPage({super.key});

  @override
  State<HomeviewPage> createState() => _HomeviewPageState();
}

class _HomeviewPageState extends State<HomeviewPage>
    with AutomaticKeepAliveClientMixin {
  bool _isUpdateAvailable = false;
  String _latestVersion = '';
  String _updateDescription = '';
  bool _isForcedUpdate = false;
  String _downloadUrl = '';
  String _currentVersion = '0.0.1'; // 默认版本号
  final HomeviewLogic _logic = Get.put(HomeviewLogic());

  @override
  void initState() {
    super.initState();
    _getCurrentVersion().then((_) {
      _checkVersion();
    });
    checkAlert();
  }

  Future<void> _getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    setState(() {
      _currentVersion = packageInfo.version;
    });
  }

  void checkAlert() async {
    final electricityApi = ElectricityApi();
    final prefs = await SharedPreferences.getInstance();
    final isEnable = prefs.getBool('enableBillWarning') ?? false;
    if (!isEnable) {
      return;
    }
    final checkRoomId = prefs.getString('enableRoomId') ?? '';
    await electricityApi.onInit();
    await electricityApi.getHistory();
    final nowRoomInfo = await electricityApi.getSingleRoomInfo(checkRoomId);
    final roomCount = nowRoomInfo["eleTail"];
    final setRoomName = nowRoomInfo["roomName"];
    final bill = prefs.getDouble('enableBill') ?? 0;
    if (!mounted) {
      return;
    }
    if (double.tryParse(roomCount) case final roomBalance?
        when roomBalance < bill) {
      _showAlert('当前电费：$roomCount元\n设置电费：$bill元\n房间：$setRoomName');
    }
  }

  void _showAlert(String showDescription) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('电费达到预警值'),
          content: Text(showDescription),
          actions: <Widget>[
            TextButton(
              child: Text('我知道了'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('立即充值'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ElectricityPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkVersion() async {
    final dio = Dio();
    try {
      final response = await dio.get(
        'https://super.ccrice.com/api/check_version.php?version=$_currentVersion',
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) {
        return;
      }
      setState(() {
        _isUpdateAvailable = !(data['is_latest'] as bool? ?? true);
        _latestVersion = data['latest_version']?.toString() ?? '';
        _updateDescription = data['description']?.toString() ?? '';
        _isForcedUpdate = data['is_forced'] as bool? ?? false;
        _downloadUrl = data['download_url']?.toString() ?? '';
      });

      if (_isUpdateAvailable) {
        _showUpdateDialog();
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to check app version',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: !_isForcedUpdate,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('新版本可用: $_latestVersion'),
          content: Text(_updateDescription),
          actions: <Widget>[
            if (!_isForcedUpdate)
              TextButton(
                child: Text('稍后更新'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            TextButton(
              child: Text('立即更新'),
              onPressed: () {
                launchUrl(Uri.parse(_downloadUrl));
                if (_isForcedUpdate) {
                  SystemNavigator.pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: PageView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _logic.homePageController,
        children: const [CourseTableView(), FunctionPage(), UserPage()],
      ),
      bottomSheet: Container(
        color: Colors.transparent,
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.only(
          left: 15,
          right: 15,
          bottom: 20,
          top: 10,
        ),
        child: GNav(
          gap: 10,
          color: Theme.of(context).primaryColorDark,
          activeColor: Theme.of(context).primaryColor,
          iconSize: 24,
          tabBackgroundColor: Theme.of(context).primaryColor.withAlpha(20),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          duration: const Duration(milliseconds: 200),
          tabs: [
            GButton(icon: Ionicons.calendar_outline, text: '课表'),
            GButton(icon: Ionicons.apps_outline, text: '功能'),
            GButton(icon: Ionicons.person_outline, text: '我'),
          ],
          onTabChange: (index) {
            _logic.homePageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            );
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
