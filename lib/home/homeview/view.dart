import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/Functionpage/view.dart';
import 'package:superhut/home/coursetable/view.dart';
import 'package:superhut/home/userpage/view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_logger.dart';
import '../../core/ui/apple_glass.dart';
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
        child: GlassPanel(
          blur: 24,
          borderRadius: BorderRadius.circular(32),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Ionicons.calendar_outline,
                  label: '课表',
                  isSelected: _selectedIndex == 0,
                  onTap: () => _onTabChange(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NavItem(
                  icon: Ionicons.apps_outline,
                  label: '功能',
                  isSelected: _selectedIndex == 1,
                  onTap: () => _onTabChange(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NavItem(
                  icon: Ionicons.person_outline,
                  label: '我的',
                  isSelected: _selectedIndex == 2,
                  onTap: () => _onTabChange(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTabChange(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _logic.homePageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient:
            isSelected
                ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.72),
                    colorScheme.primary.withValues(alpha: 0.30),
                  ],
                )
                : null,
        color:
            isSelected
                ? null
                : Colors.white.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.04 : 0.12,
                ),
        border: Border.all(
          color:
              isSelected
                  ? Colors.white.withValues(alpha: 0.72)
                  : Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color:
                      isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child:
                      isSelected
                          ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                          )
                          : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
