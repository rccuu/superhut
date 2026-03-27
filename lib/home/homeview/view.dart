import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/Functionpage/view.dart';
import 'package:superhut/home/coursetable/view.dart';
import 'package:superhut/home/userpage/view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_logger.dart';
import '../../core/services/app_update_service.dart';
import '../../core/ui/apple_glass.dart';
import '../../pages/Electricitybill/electricity_api.dart';
import '../../pages/Electricitybill/electricity_page.dart';

class HomeviewPage extends StatefulWidget {
  const HomeviewPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomeviewPage> createState() => _HomeviewPageState();
}

class _HomeviewPageState extends State<HomeviewPage> {
  static const int _courseTabIndex = 0;
  static const _pages = [CourseTableView(), FunctionPage(), UserPage()];
  static const _dockItems = [
    _DockItemData(icon: CupertinoIcons.calendar, label: '课表'),
    _DockItemData(icon: CupertinoIcons.square_grid_2x2, label: '功能'),
    _DockItemData(icon: CupertinoIcons.person, label: '我的'),
  ];
  String _currentVersion = '0.0.1'; // 默认版本号
  late int _selectedIndex;
  late final List<bool> _loadedPages;
  int _tabAnimationSeed = 0;
  int _tabAnimationDirection = 1;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _pages.length - 1);
    _loadedPages = List<bool>.filled(_pages.length, false);
    _loadedPages[_selectedIndex] = true;
    if (_selectedIndex != _courseTabIndex) {
      _loadedPages[_courseTabIndex] = true;
    }
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
    final update = await AppUpdateService.fetchUpdate(
      currentVersion: _currentVersion,
    );
    if (!mounted || update == null) {
      return;
    }

    _showUpdateDialog(update);
  }

  void _showUpdateDialog(AppUpdateInfo update) {
    final updateDescription = _buildUpdateDescription(update.notes);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('发现新版本 ${update.displayVersion}'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: SingleChildScrollView(child: Text(updateDescription)),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('稍后再说'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('前往更新'),
              onPressed: () {
                Navigator.of(context).pop();
                _openUpdateRelease(update.releaseUrl);
              },
            ),
          ],
        );
      },
    );
  }

  String _buildUpdateDescription(String releaseNotes) {
    const fallbackText = '工大盒子已发布新版本，可前往 GitHub Release 页面查看更新说明并下载安装。';
    if (releaseNotes.trim().isEmpty) {
      return fallbackText;
    }

    const maxLength = 700;
    if (releaseNotes.length <= maxLength) {
      return releaseNotes;
    }

    return '${releaseNotes.substring(0, maxLength).trimRight()}\n\n……';
  }

  Future<void> _openUpdateRelease(Uri releaseUrl) async {
    final opened = await launchUrl(
      releaseUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开更新链接：$releaseUrl')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final dockBottom = bottomInset > 12 ? bottomInset.toDouble() : 12.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            sizing: StackFit.expand,
            index: _selectedIndex,
            children: List.generate(_pages.length, _buildPageSlot),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: dockBottom,
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: _ClassicTabBar(
                    key: const ValueKey<String>('home-bottom-nav'),
                    items: _dockItems,
                    selectedIndex: _selectedIndex,
                    onSelected: _onTabChange,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageSlot(int index) {
    if (!_loadedPages[index]) {
      return const SizedBox.expand();
    }

    return RepaintBoundary(
      key: ValueKey<String>('home-loaded-tab-$index'),
      child: _AnimatedTabPage(
        isActive: _selectedIndex == index,
        animationSeed: _tabAnimationSeed,
        slideDirection: _tabAnimationDirection,
        pageIndex: index,
        child: KeyedSubtree(
          key: PageStorageKey<String>('home-tab-$index'),
          child: _pages[index],
        ),
      ),
    );
  }

  void _onTabChange(int index) {
    if (_selectedIndex == index) {
      return;
    }

    final previousIndex = _selectedIndex;
    setState(() {
      _tabAnimationDirection = index > previousIndex ? 1 : -1;
      _selectedIndex = index;
      _loadedPages[index] = true;
      _tabAnimationSeed++;
    });
  }
}

class _DockItemData {
  const _DockItemData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _AnimatedTabPage extends StatefulWidget {
  const _AnimatedTabPage({
    required this.child,
    required this.isActive,
    required this.animationSeed,
    required this.slideDirection,
    required this.pageIndex,
  });

  final Widget child;
  final bool isActive;
  final int animationSeed;
  final int slideDirection;
  final int pageIndex;

  @override
  State<_AnimatedTabPage> createState() => _AnimatedTabPageState();
}

class _AnimatedTabPageState extends State<_AnimatedTabPage>
    with SingleTickerProviderStateMixin {
  static const _tabAnimationDuration = Duration(milliseconds: 190);
  static const _tabSlideOffset = 0.055;
  static const _tabStartOpacity = 0.86;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _tabAnimationDuration,
    value: 1,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late Animation<Offset> _slide;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _configureAnimations();
    if (widget.isActive && widget.animationSeed > 0) {
      _controller.value = 0;
      _controller.forward();
    }
  }

  void _configureAnimations() {
    _slide = Tween<Offset>(
      begin: Offset(widget.slideDirection * _tabSlideOffset, 0),
      end: Offset.zero,
    ).animate(_curve);
    _opacity = Tween<double>(begin: _tabStartOpacity, end: 1).animate(_curve);
  }

  @override
  void didUpdateWidget(covariant _AnimatedTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slideDirection != oldWidget.slideDirection ||
        widget.isActive != oldWidget.isActive) {
      _configureAnimations();
    }
    if (widget.isActive && widget.animationSeed != oldWidget.animationSeed) {
      _configureAnimations();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations;
    if (!widget.isActive || disableAnimations == true) {
      return widget.child;
    }

    return ClipRect(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          key: ValueKey<String>('home-tab-slide-${widget.pageIndex}'),
          position: _slide,
          child: widget.child,
        ),
      ),
    );
  }
}

class _ClassicTabBar extends StatelessWidget {
  const _ClassicTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_DockItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final panelRadius = BorderRadius.circular(28);
    final panelGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.white.withValues(alpha: isDark ? 0.16 : 0.28),
        colorScheme.surface.withValues(alpha: isDark ? 0.14 : 0.22),
        Colors.white.withValues(alpha: isDark ? 0.16 : 0.28),
      ],
      stops: const [0, 0.5, 1],
    );
    final activeBackground = colorScheme.primary.withValues(
      alpha: isDark ? 0.22 : 0.12,
    );
    final panelBorder = Colors.white.withValues(alpha: isDark ? 0.10 : 0.24);
    final panelShadow = <_OuterShadowLayer>[
      _OuterShadowLayer(
        color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.18),
        blurRadius: isDark ? 32 : 27,
        offset: Offset(0, isDark ? 14 : 11),
        spreadRadius: -10,
      ),
      _OuterShadowLayer(
        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.10),
        blurRadius: isDark ? 12 : 10,
        offset: const Offset(0, 3),
        spreadRadius: -2,
      ),
    ];

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _OuterOnlyShadowPainter(
                  borderRadius: panelRadius,
                  shadows: panelShadow,
                ),
              ),
            ),
          ),
          GlassPanel(
            style: GlassPanelStyle.floating,
            blur: isDark ? 18 : 24,
            borderRadius: panelRadius,
            gradient: panelGradient,
            borderColor: panelBorder,
            boxShadow: const [],
            padding: EdgeInsets.zero,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: GNav(
                        selectedIndex: selectedIndex,
                        onTabChange: onSelected,
                        gap: 8,
                        rippleColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        haptic: true,
                        backgroundColor: Colors.transparent,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: isDark ? 0.86 : 0.78,
                        ),
                        activeColor: colorScheme.primary,
                        tabBackgroundColor: activeBackground,
                        tabBorderRadius: 18,
                        iconSize: 20,
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        textStyle: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        tabs: items
                            .map(
                              (item) => GButton(
                                key: ValueKey<String>('home-tab-${item.label}'),
                                icon: item.icon,
                                text: item.label,
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: List.generate(items.length, (index) {
                      final item = items[index];
                      return Expanded(
                        child: Semantics(
                          button: true,
                          selected: index == selectedIndex,
                          label: item.label,
                          child: GestureDetector(
                            key: ValueKey<String>(
                              'home-hit-zone-${item.label}',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSelected(index);
                            },
                            child: const SizedBox.expand(),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OuterShadowLayer {
  const _OuterShadowLayer({
    required this.color,
    required this.blurRadius,
    required this.offset,
    required this.spreadRadius,
  });

  final Color color;
  final double blurRadius;
  final Offset offset;
  final double spreadRadius;
}

class _OuterOnlyShadowPainter extends CustomPainter {
  const _OuterOnlyShadowPainter({
    required this.borderRadius,
    required this.shadows,
  });

  final BorderRadius borderRadius;
  final List<_OuterShadowLayer> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final panelRect = Offset.zero & size;
    final panelPath = Path()..addRRect(borderRadius.toRRect(panelRect));
    final layerBounds = Rect.fromLTWH(
      -80,
      -80,
      size.width + 160,
      size.height + 160,
    );

    for (final shadow in shadows) {
      final shadowRect = panelRect
          .inflate(shadow.spreadRadius)
          .shift(shadow.offset);
      final shadowPath = Path()..addRRect(borderRadius.toRRect(shadowRect));
      final shadowPaint =
          Paint()
            ..color = shadow.color
            ..maskFilter = ui.MaskFilter.blur(
              ui.BlurStyle.normal,
              ui.Shadow.convertRadiusToSigma(shadow.blurRadius),
            );
      final clearPaint = Paint()..blendMode = BlendMode.clear;

      canvas.saveLayer(layerBounds, Paint());
      canvas.drawPath(shadowPath, shadowPaint);
      canvas.drawPath(panelPath, clearPaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _OuterOnlyShadowPainter oldDelegate) {
    if (oldDelegate.borderRadius != borderRadius) {
      return true;
    }
    if (oldDelegate.shadows.length != shadows.length) {
      return true;
    }
    for (var i = 0; i < shadows.length; i++) {
      final current = shadows[i];
      final previous = oldDelegate.shadows[i];
      if (current.color != previous.color ||
          current.blurRadius != previous.blurRadius ||
          current.offset != previous.offset ||
          current.spreadRadius != previous.spreadRadius) {
        return true;
      }
    }
    return false;
  }
}
