import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/Functionpage/view.dart';
import 'package:superhut/home/coursetable/view.dart';
import 'package:superhut/home/userpage/view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_auth_storage.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/course_sync_service.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/apple_glass.dart';
import '../about/first_open_trust_dialog.dart';
import '../about/trust_page.dart';
import '../../pages/Electricitybill/electricity_api.dart';
import '../../pages/Electricitybill/electricity_page.dart';

class HomeviewPage extends StatefulWidget {
  const HomeviewPage({
    super.key,
    this.initialIndex = 0,
    this.showInitialTrustNotice = false,
    this.checkUpdatesOnStartup = true,
  });

  final int initialIndex;
  final bool showInitialTrustNotice;
  final bool checkUpdatesOnStartup;

  @override
  State<HomeviewPage> createState() => _HomeviewPageState();
}

class _HomeviewPageState extends State<HomeviewPage> {
  static const int _courseTabIndex = 0;
  static const _tabAnimationDuration = Duration(milliseconds: 150);
  static const _dockItems = [
    _DockItemData(icon: CupertinoIcons.calendar, label: '课表'),
    _DockItemData(icon: CupertinoIcons.square_grid_2x2, label: '功能'),
    _DockItemData(icon: CupertinoIcons.person, label: '我的'),
  ];
  String _currentVersion = '0.0.1'; // 默认版本号
  late int _selectedIndex;
  late final List<bool> _loadedPages;
  late final ValueNotifier<bool> _courseTransitionLiteMode;
  late final List<Widget> _pages;
  int _tabAnimationSeed = 0;
  int _tabAnimationDirection = 1;
  int _handledCourseSyncEventId = 0;
  bool _hasHandledStartupDialogs = false;

  @override
  void initState() {
    super.initState();
    _courseTransitionLiteMode = ValueNotifier<bool>(false);
    _pages = <Widget>[
      CourseTableView(transitionLiteModeListenable: _courseTransitionLiteMode),
      const FunctionPage(),
      const UserPage(),
    ];
    _selectedIndex = widget.initialIndex.clamp(0, _pages.length - 1);
    _loadedPages = List<bool>.filled(_pages.length, false);
    _loadedPages[_selectedIndex] = true;
    if (_selectedIndex != _courseTabIndex) {
      _loadedPages[_courseTabIndex] = true;
    }
    CourseSyncService.instance.stateListenable.addListener(
      _handleCourseSyncStateChanged,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runStartupDialogs());
    });
  }

  @override
  void dispose() {
    CourseSyncService.instance.stateListenable.removeListener(
      _handleCourseSyncStateChanged,
    );
    _courseTransitionLiteMode.dispose();
    super.dispose();
  }

  void _handleCourseSyncStateChanged() {
    if (!mounted) {
      return;
    }

    final snapshot = CourseSyncService.instance.state;
    if (snapshot.eventId <= 0 ||
        snapshot.eventId == _handledCourseSyncEventId) {
      return;
    }
    _handledCourseSyncEventId = snapshot.eventId;

    if (snapshot.status == CourseSyncTaskStatus.success ||
        snapshot.status == CourseSyncTaskStatus.failure) {
      final isSuccess = snapshot.status == CourseSyncTaskStatus.success;
      showAppSnackBar(
        context,
        message: snapshot.message,
        type: isSuccess ? AppSnackBarType.success : AppSnackBarType.error,
        icon:
            isSuccess
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.exclamationmark_circle_fill,
        duration: const Duration(seconds: 2),
      );
    }
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

  Future<void> _runStartupDialogs() async {
    if (_hasHandledStartupDialogs || !mounted) {
      return;
    }
    _hasHandledStartupDialogs = true;

    if (widget.showInitialTrustNotice) {
      final action = await showFirstOpenTrustDialog(context);
      await AppAuthStorage.instance.setHasSeenTrustNotice(true);
      if (!mounted) {
        return;
      }
      if (action == FirstOpenTrustDialogAction.viewDetails) {
        await Navigator.of(context).push(TrustCenterPage.route());
      }
    }

    if (widget.checkUpdatesOnStartup) {
      await _getCurrentVersion();
      if (!mounted) {
        return;
      }
      await _checkVersion();
      if (!mounted) {
        return;
      }
    }
    await checkAlert();
  }

  Future<void> checkAlert() async {
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

    final ignoredVersion =
        await AppAuthStorage.instance.readIgnoredUpdateVersion();
    if (!mounted || ignoredVersion == update.tagName) {
      return;
    }

    await _showUpdateDialog(update);
  }

  Future<void> _showUpdateDialog(AppUpdateInfo update) {
    final updateDescription = _buildUpdateDescription(update.notes);

    return showDialog<void>(
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
              child: Text('忽略此版本'),
              onPressed: () async {
                await AppAuthStorage.instance.saveIgnoredUpdateVersion(
                  update.tagName,
                );
                if (!context.mounted) {
                  return;
                }
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
      showAppSnackBar(
        context,
        message: '无法打开更新链接：$releaseUrl',
        type: AppSnackBarType.error,
        icon: CupertinoIcons.exclamationmark_circle_fill,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final dockBottom = bottomInset > 12 ? bottomInset.toDouble() : 12.0;
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _ActiveOnlyIndexedStack(
            key: const ValueKey<String>('home-tab-stage'),
            index: _selectedIndex,
            children: List.generate(_pages.length, _buildPageSlot),
          ),
          Positioned(
            top: topInset + 10,
            left: 16,
            right: 16,
            child: const IgnorePointer(child: _CourseSyncOverlay()),
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
        transitionNotifier:
            index == _courseTabIndex ? _courseTransitionLiteMode : null,
        child: TickerMode(
          enabled: _selectedIndex == index,
          child: KeyedSubtree(
            key: PageStorageKey<String>('home-tab-$index'),
            child: _pages[index],
          ),
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

class _ActiveOnlyIndexedStack extends MultiChildRenderObjectWidget {
  const _ActiveOnlyIndexedStack({
    super.key,
    required this.index,
    required super.children,
  });

  final int index;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderActiveOnlyIndexedStack(index: index);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderActiveOnlyIndexedStack renderObject,
  ) {
    renderObject.index = index;
  }

  @override
  MultiChildRenderObjectElement createElement() {
    return _ActiveOnlyIndexedStackElement(this);
  }
}

class _ActiveOnlyIndexedStackElement extends MultiChildRenderObjectElement {
  _ActiveOnlyIndexedStackElement(_ActiveOnlyIndexedStack super.widget);

  @override
  _ActiveOnlyIndexedStack get widget => super.widget as _ActiveOnlyIndexedStack;

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final index = widget.index;
    if (index >= 0 && index < children.length) {
      visitor(children.elementAt(index));
    }
  }
}

class _RenderActiveOnlyIndexedStack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, StackParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, StackParentData> {
  _RenderActiveOnlyIndexedStack({required int index}) : _index = index;

  int get index => _index;
  int _index;
  set index(int value) {
    if (_index == value) {
      return;
    }
    _index = value;
    markNeedsLayout();
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  RenderBox? _activeChild() {
    if (index < 0) {
      return null;
    }

    RenderBox? child = firstChild;
    for (
      var childIndex = 0;
      child != null && childIndex < index;
      childIndex++
    ) {
      child = childAfter(child);
    }
    return child;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! StackParentData) {
      child.parentData = StackParentData();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
      return constraints.biggest;
    }
    return constraints.smallest;
  }

  @override
  void performLayout() {
    final previousSize = hasSize ? size : null;
    size = constraints.biggest;
    assert(size.isFinite, '首页 Tab 容器需要来自 Scaffold/Stack 的有界尺寸。');
    final childConstraints = BoxConstraints.tight(size);
    final shouldRefreshAllChildren = previousSize != size;

    var childIndex = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final childParentData = child.parentData! as StackParentData;
      final shouldLayoutChild =
          childIndex == index || !child.hasSize || shouldRefreshAllChildren;
      if (shouldLayoutChild) {
        child.layout(childConstraints);
      }
      childParentData.offset = Offset.zero;
      child = childParentData.nextSibling;
      childIndex++;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = _activeChild();
    if (child == null || !child.hasSize) {
      return false;
    }

    final childParentData = child.parentData! as StackParentData;
    return result.addWithPaintOffset(
      offset: childParentData.offset,
      position: position,
      hitTest: (result, transformed) {
        assert(transformed == position - childParentData.offset);
        return child.hitTest(result, position: transformed);
      },
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = _activeChild();
    if (child == null || !child.hasSize) {
      return;
    }

    final childParentData = child.parentData! as StackParentData;
    context.paintChild(child, offset + childParentData.offset);
  }

  @override
  bool paintsChild(RenderBox child) {
    return child == _activeChild();
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (!paintsChild(child)) {
      return;
    }

    final childParentData = child.parentData! as StackParentData;
    transform.translate(childParentData.offset.dx, childParentData.offset.dy);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final child = _activeChild();
    if (child != null) {
      visitor(child);
    }
  }
}

class _CourseSyncOverlay extends StatelessWidget {
  const _CourseSyncOverlay();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CourseSyncTaskSnapshot>(
      valueListenable: CourseSyncService.instance.stateListenable,
      builder: (context, snapshot, _) {
        final visible = snapshot.isVisible;
        // Perf: 99% 的时间这个 overlay 都不可见，但旧实现仍然走完
        // AnimatedSlide + AnimatedOpacity 两个隐式动画 widget。
        // 不可见时直接返回 SizedBox.shrink，连 build 都不要走。
        if (!visible) {
          return const SizedBox.shrink();
        }
        final colorScheme = Theme.of(context).colorScheme;
        final bool isFailure = snapshot.status == CourseSyncTaskStatus.failure;
        final bool isSuccess = snapshot.status == CourseSyncTaskStatus.success;
        final Color accentColor =
            isFailure
                ? colorScheme.error
                : isSuccess
                ? colorScheme.primary
                : colorScheme.primary;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: RepaintBoundary(
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isFailure
                                  ? CupertinoIcons.exclamationmark_circle
                                  : isSuccess
                                  ? CupertinoIcons.check_mark_circled
                                  : CupertinoIcons.arrow_2_circlepath,
                              size: 18,
                              color: accentColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                snapshot.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (snapshot.status ==
                                    CourseSyncTaskStatus.running &&
                                snapshot.currentWeek != null &&
                                snapshot.totalWeeks != null)
                              Text(
                                '${snapshot.currentWeek}/${snapshot.totalWeeks}',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                  fontFeatures: const [
                                    ui.FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            value:
                                snapshot.status == CourseSyncTaskStatus.failure
                                    ? null
                                    : snapshot.progress,
                            color: accentColor,
                            backgroundColor: accentColor.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
    this.transitionNotifier,
  });

  final Widget child;
  final bool isActive;
  final int animationSeed;
  final int slideDirection;
  final int pageIndex;
  final ValueNotifier<bool>? transitionNotifier;

  @override
  State<_AnimatedTabPage> createState() => _AnimatedTabPageState();
}

class _AnimatedTabPageState extends State<_AnimatedTabPage>
    with SingleTickerProviderStateMixin {
  static const _tabSlideOffset = 0.055;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _HomeviewPageState._tabAnimationDuration,
    value: 1,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late Animation<Offset> _slide;
  // Perf: 只有真正在过渡动画期间才需要 ClipRect+SlideTransition；
  // 动画完成后退化为直接返回 child，避免常驻 saveLayer。
  bool _isTransitioning = false;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleAnimationStatusChanged);
    _configureAnimations();
    if (widget.isActive && widget.animationSeed > 0) {
      _startTransition();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations == true;
    if (_disableAnimations == disableAnimations) {
      return;
    }

    _disableAnimations = disableAnimations;
    if (disableAnimations) {
      _setTransitionLiteMode(false);
      _isTransitioning = false;
      _controller.value = 1;
    }
  }

  void _handleAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _setTransitionLiteMode(false);
      if (_isTransitioning && mounted) {
        setState(() {
          _isTransitioning = false;
        });
      }
    }
  }

  void _setTransitionLiteMode(bool value) {
    final notifier = widget.transitionNotifier;
    if (notifier == null || notifier.value == value) {
      return;
    }
    notifier.value = value;
  }

  void _startTransition() {
    if (_disableAnimations) {
      _setTransitionLiteMode(false);
      _isTransitioning = false;
      _controller.value = 1;
      return;
    }

    _setTransitionLiteMode(true);
    if (!_isTransitioning) {
      _isTransitioning = true;
    }
    _controller.forward(from: 0);
  }

  void _configureAnimations() {
    _slide = Tween<Offset>(
      begin: Offset(widget.slideDirection * _tabSlideOffset, 0),
      end: Offset.zero,
    ).animate(_curve);
  }

  @override
  void didUpdateWidget(covariant _AnimatedTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slideDirection != oldWidget.slideDirection ||
        widget.isActive != oldWidget.isActive) {
      _configureAnimations();
    }
    if (!widget.isActive) {
      _setTransitionLiteMode(false);
    }
    if (widget.isActive && widget.animationSeed != oldWidget.animationSeed) {
      _configureAnimations();
      _startTransition();
    }
  }

  @override
  void dispose() {
    _setTransitionLiteMode(false);
    _controller.removeStatusListener(_handleAnimationStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive || _disableAnimations || !_isTransitioning) {
      return widget.child;
    }

    return ClipRect(
      child: SlideTransition(
        key: ValueKey<String>('home-tab-slide-${widget.pageIndex}'),
        position: _slide,
        child: widget.child,
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
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations;
    // Perf: TabBar 是常驻浮层，且页面切换时下层内容会随 SlideTransition
    // 移动 —— 一旦它开启 BackdropFilter，每帧都要重新采样，是头号掉帧元凶。
    // 改为读 AppGlassPerformanceScope：lite 模式（Android / 切换动画期间）
    // 直接关掉 BackdropFilter，把 surface 透明度上提到 0.78 保持视觉浮岛感。
    final useLiteEffects = AppGlassPerformanceScope.isLiteOf(context);
    final panelRadius = BorderRadius.circular(28);
    final panelGradient =
        useLiteEffects
            ? LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.10 : 0.84),
                colorScheme.surface.withValues(alpha: isDark ? 0.34 : 0.78),
                Colors.white.withValues(alpha: isDark ? 0.10 : 0.84),
              ],
              stops: const [0, 0.5, 1],
            )
            : LinearGradient(
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
    // Perf: 双层 BoxShadow 在长方形区域上的成本接近一次小型模糊。
    // lite 模式下合并为一层，并把 blurRadius 从 27/32 降到 16/20。
    final panelShadow =
        useLiteEffects
            ? <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
                blurRadius: isDark ? 20 : 16,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ]
            : <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.18),
                blurRadius: isDark ? 32 : 27,
                offset: Offset(0, isDark ? 14 : 11),
                spreadRadius: -10,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.10),
                blurRadius: isDark ? 12 : 10,
                offset: const Offset(0, 3),
                spreadRadius: -2,
              ),
            ];
    final navAnimationDuration =
        disableAnimations == true
            ? Duration.zero
            : useLiteEffects
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 180);

    return RepaintBoundary(
      child: GlassPanel(
        key: const ValueKey<String>('home-bottom-nav-panel-stable'),
        style: GlassPanelStyle.floating,
        blur: isDark ? 18 : 24,
        useBackdropFilter: !useLiteEffects,
        borderRadius: panelRadius,
        gradient: panelGradient,
        borderColor: panelBorder,
        boxShadow: panelShadow,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                    duration: navAnimationDuration,
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
                        key: ValueKey<String>('home-hit-zone-${item.label}'),
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
    );
  }
}
