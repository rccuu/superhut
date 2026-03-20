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
  static const _pages = [CourseTableView(), FunctionPage(), UserPage()];
  bool _isUpdateAvailable = false;
  String _latestVersion = '';
  String _updateDescription = '';
  bool _isForcedUpdate = false;
  String _downloadUrl = '';
  String _currentVersion = '0.0.1'; // 默认版本号
  final HomeviewLogic _logic = Get.put(HomeviewLogic());
  int _selectedIndex = 0;

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
    try {
      final electricityApi = ElectricityApi();
      final prefs = await SharedPreferences.getInstance();
      final isEnable = prefs.getBool('enableBillWarning') ?? false;
      if (!isEnable) {
        return;
      }
      final checkRoomId = prefs.getString('enableRoomId') ?? '';
      if (checkRoomId.isEmpty) {
        return;
      }

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
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to check electricity warning status',
        error: error,
        stackTrace: stackTrace,
      );
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      extendBody: true,
      body: PageView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _logic.homePageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: GNav(
              selectedIndex: _selectedIndex,
              gap: 10,
              color: colorScheme.onSurfaceVariant,
              activeColor: colorScheme.onPrimary,
              iconSize: 22,
              textStyle: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary,
              ),
              tabBackgroundGradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
              ),
              tabBorderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              duration: const Duration(milliseconds: 220),
              tabs: const [
                GButton(icon: Ionicons.calendar_outline, text: '课表'),
                GButton(icon: Ionicons.apps_outline, text: '功能'),
                GButton(icon: Ionicons.person_outline, text: '我的'),
              ],
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
                _logic.homePageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
