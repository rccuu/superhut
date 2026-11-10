import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/Functionpage/view.dart';
import 'package:superhut/home/coursetable/view.dart';
import 'package:superhut/home/userpage/view.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_auth_storage.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/app_update_download_service.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/course_sync_service.dart';
import '../../core/ui/app_page_route.dart';
import '../../core/ui/app_progress_indicator.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/apple_glass.dart';
import '../../theme/glass/glass_theme.dart';
import '../about/first_open_trust_dialog.dart';
import '../about/trust_page.dart';
import '../../pages/Electricitybill/electricity_api.dart';
import '../../pages/Electricitybill/electricity_page.dart';
import 'widgets/app_update_download_banner.dart';

typedef HomeElectricityApiFactory = ElectricityApiClient Function();
typedef HomeElectricityPageOpener = Future<void> Function(BuildContext context);
typedef HomeUpdateFetcher =
    Future<AppUpdateInfo?> Function({required String currentVersion});
typedef HomeUpdateReleaseOpener = Future<bool> Function(Uri releaseUrl);
typedef HomeCurrentVersionLoader = Future<String> Function();
typedef HomeUpdateStartDownloader = Future<void> Function(AppUpdateInfo update);

class HomeElectricityAlert {
  const HomeElectricityAlert({
    required this.roomCount,
    required this.bill,
    required this.roomName,
  });

  final String roomCount;
  final double bill;
  final String roomName;

  String get description => '当前电费：$roomCount元\n设置电费：$bill元\n房间：$roomName';
}

class HomeElectricityAlertChecker {
  HomeElectricityAlertChecker({
    HomeElectricityApiFactory? electricityApiFactory,
  }) : _electricityApiFactory = electricityApiFactory ?? ElectricityApi.new;

  final HomeElectricityApiFactory _electricityApiFactory;

  Future<HomeElectricityAlert?> check() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnable = prefs.getBool('enableBillWarning') ?? false;
    if (!isEnable) {
      return null;
    }

    final checkRoomId = prefs.getString('enableRoomId') ?? '';
    if (checkRoomId.isEmpty) {
      return null;
    }

    final electricityApi = _electricityApiFactory();
    await electricityApi.onInit();
    await electricityApi.getHistory();
    final nowRoomInfo = await electricityApi.getSingleRoomInfo(checkRoomId);
    final roomCount = nowRoomInfo["eleTail"]?.toString() ?? '';
    final setRoomName = nowRoomInfo["roomName"]?.toString() ?? '';
    final bill = prefs.getDouble('enableBill') ?? 0;
    if (double.tryParse(roomCount) case final roomBalance?
        when roomBalance < bill) {
      return HomeElectricityAlert(
        roomCount: roomCount,
        bill: bill,
        roomName: setRoomName,
      );
    }

    return null;
  }
}

class _HomeTabState {
  const _HomeTabState({
    required this.selectedIndex,
    required this.loadedPages,
    required this.animationSeed,
    required this.animationDirection,
  });

  final int selectedIndex;
  final List<bool> loadedPages;
  final int animationSeed;
  final int animationDirection;

  bool isLoaded(int index) {
    return index >= 0 && index < loadedPages.length && loadedPages[index];
  }
}

class HomeviewPage extends StatefulWidget {
  const HomeviewPage({
    super.key,
    this.initialIndex = 0,
    this.showInitialTrustNotice = false,
    this.checkUpdatesOnStartup = true,
    this.electricityAlertChecker,
    this.openElectricityPage,
    this.loadCurrentVersion,
    this.fetchUpdate,
    this.openUpdateRelease,
    this.startUpdateDownload,
  });

  final int initialIndex;
  final bool showInitialTrustNotice;
  final bool checkUpdatesOnStartup;
  final HomeElectricityAlertChecker? electricityAlertChecker;
  final HomeElectricityPageOpener? openElectricityPage;
  final HomeCurrentVersionLoader? loadCurrentVersion;
  final HomeUpdateFetcher? fetchUpdate;
  final HomeUpdateReleaseOpener? openUpdateRelease;
  final HomeUpdateStartDownloader? startUpdateDownload;

  @override
  State<HomeviewPage> createState() => _HomeviewPageState();
}

class _HomeviewPageState extends State<HomeviewPage> {
  static const int _courseTabIndex = 0;
  static const _tabAnimationDuration = Duration(milliseconds: 150);
  String _currentVersion = '0.0.1'; // 默认版本号
  late final ValueNotifier<_HomeTabState> _tabStateNotifier;
  late final ValueNotifier<bool> _courseTransitionLiteMode;
  late final ValueNotifier<bool> _dockHiddenNotifier;
  late final List<Widget> _pages;
  int _handledCourseSyncEventId = 0;
  bool _hasHandledStartupDialogs = false;
  bool _isOpeningElectricityPageFromAlert = false;
  bool _isOpeningUpdateRelease = false;
  bool _hasLoadedCurrentVersion = false;
  bool _isStartingUpdateDownload = false;

  @override
  void initState() {
    super.initState();
    _courseTransitionLiteMode = ValueNotifier<bool>(false);
    _dockHiddenNotifier = ValueNotifier<bool>(false);
    _pages = <Widget>[
      CourseTableView(transitionLiteModeListenable: _courseTransitionLiteMode),
      const FunctionPage(),
      const UserPage(),
    ];
    final selectedIndex = widget.initialIndex.clamp(0, _pages.length - 1);
    final loadedPages = List<bool>.filled(_pages.length, false);
    loadedPages[selectedIndex] = true;
    if (selectedIndex != _courseTabIndex) {
      loadedPages[_courseTabIndex] = true;
    }
    _tabStateNotifier = ValueNotifier<_HomeTabState>(
      _HomeTabState(
        selectedIndex: selectedIndex,
        loadedPages: List<bool>.unmodifiable(loadedPages),
        animationSeed: 0,
        animationDirection: 1,
      ),
    );
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
    _dockHiddenNotifier.dispose();
    _tabStateNotifier.dispose();
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
    try {
      final versionLoader = widget.loadCurrentVersion;
      if (versionLoader != null) {
        final version = await versionLoader();
        if (!mounted) {
          return;
        }
        _currentVersion = version;
        _hasLoadedCurrentVersion = true;
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      _currentVersion = packageInfo.version;
      _hasLoadedCurrentVersion = true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to read current app version on home startup',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
      if (_hasLoadedCurrentVersion) {
        await _checkVersion();
        if (!mounted) {
          return;
        }
      }
    }
    await checkAlert();
  }

  Future<void> checkAlert() async {
    try {
      final alert =
          await (widget.electricityAlertChecker ??
                  HomeElectricityAlertChecker())
              .check();
      if (!mounted) {
        return;
      }
      if (alert != null) {
        _showAlert(alert.description);
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
                unawaited(
                  _openElectricityPageFromAlert(dialogContext: context),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _openElectricityPageFromAlert({
    required BuildContext dialogContext,
  }) async {
    if (_isOpeningElectricityPageFromAlert) {
      return;
    }

    _isOpeningElectricityPageFromAlert = true;
    try {
      await Navigator.of(dialogContext).maybePop();
      if (!mounted) {
        return;
      }

      final openPage =
          widget.openElectricityPage ??
          (BuildContext context) {
            return Navigator.of(
              context,
            ).push(buildAppPageRoute(builder: (_) => const ElectricityPage()));
          };
      await openPage(context);
    } catch (_) {
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: '打开电费页面失败，请稍后重试',
        type: AppSnackBarType.error,
        icon: CupertinoIcons.exclamationmark_circle_fill,
        duration: const Duration(seconds: 2),
      );
    } finally {
      _isOpeningElectricityPageFromAlert = false;
    }
  }

  Future<void> _checkVersion() async {
    final fetchUpdate = widget.fetchUpdate ?? AppUpdateService.fetchUpdate;
    final AppUpdateInfo? update;
    try {
      update = await fetchUpdate(currentVersion: _currentVersion);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to check app update on home startup',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
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
              child: Text(update.updateActionLabel),
              onPressed: () {
                unawaited(
                  _handleUpdateDialogPrimaryAction(
                    dialogContext: context,
                    update: update,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleUpdateDialogPrimaryAction({
    required BuildContext dialogContext,
    required AppUpdateInfo update,
  }) async {
    if (!update.hasDirectDownload) {
      await _openUpdateReleaseFromDialog(
        dialogContext: dialogContext,
        updateUrl: update.updateUrl,
      );
      return;
    }

    if (_isStartingUpdateDownload) {
      return;
    }
    _isStartingUpdateDownload = true;
    try {
      await Navigator.of(dialogContext).maybePop();
      final downloadStarter = widget.startUpdateDownload;
      await (downloadStarter == null
          ? AppUpdateDownloadService.startDownload(update)
          : downloadStarter(update));
    } finally {
      _isStartingUpdateDownload = false;
    }
  }

  String _buildUpdateDescription(String releaseNotes) {
    const fallbackText = '工大盒子已发布新版本，点击下载安装包即可直接获取对应平台的更新包。';
    if (releaseNotes.trim().isEmpty) {
      return fallbackText;
    }

    const maxLength = 700;
    if (releaseNotes.length <= maxLength) {
      return releaseNotes;
    }

    return '${releaseNotes.substring(0, maxLength).trimRight()}\n\n……';
  }

  Future<void> _openUpdateReleaseFromDialog({
    required BuildContext dialogContext,
    required Uri updateUrl,
  }) async {
    if (_isOpeningUpdateRelease) {
      return;
    }

    _isOpeningUpdateRelease = true;
    try {
      await Navigator.of(dialogContext).maybePop();
      final openRelease = widget.openUpdateRelease ?? _launchUpdateRelease;
      final opened = await openRelease(updateUrl);
      if (!opened && mounted) {
        showAppSnackBar(
          context,
          message: '无法打开下载链接，请稍后重试',
          type: AppSnackBarType.error,
          icon: CupertinoIcons.exclamationmark_circle_fill,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to open update release from home dialog',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }

      showAppSnackBar(
        context,
        message: '无法打开下载链接，请稍后重试',
        type: AppSnackBarType.error,
        icon: CupertinoIcons.exclamationmark_circle_fill,
        duration: const Duration(seconds: 2),
      );
    } finally {
      _isOpeningUpdateRelease = false;
    }
  }

  Future<bool> _launchUpdateRelease(Uri updateUrl) {
    return launchUrl(updateUrl, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      // 滚动驱动 dock 收起/浮现（对齐上游交互：下滚隐藏、上滚浮现）。
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ValueListenableBuilder<_HomeTabState>(
              valueListenable: _tabStateNotifier,
              builder: (context, tabState, child) {
                return _ActiveOnlyIndexedStack(
                  key: const ValueKey<String>('home-tab-stage'),
                  index: tabState.selectedIndex,
                  children: [
                    for (var index = 0; index < _pages.length; index++)
                      _buildPageSlot(index, tabState),
                  ],
                );
              },
            ),
            Positioned(
              top: topInset + 10,
              left: 16,
              right: 16,
              child: const IgnorePointer(child: _CourseSyncOverlay()),
            ),
            Positioned(
              top: topInset + 10,
              left: 16,
              right: 16,
              child: AppUpdateDownloadBanner(
                onOpenRelease: widget.openUpdateRelease ?? _launchUpdateRelease,
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _dockHiddenNotifier,
              builder: (context, hidden, child) {
                return IgnorePointer(
                  ignoring: hidden,
                  child: AnimatedSlide(
                    offset: hidden ? const Offset(0, 0.2) : Offset.zero,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: hidden ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: child,
                    ),
                  ),
                );
              },
              // LiquidGlassTabBar（Impeller 玻璃 pill 档）是全屏自放置
              // overlay：必须作为 Stack 的直接 child 放开一切约束，
              // bottom 间距走它自己的 margin（safe-area 包内自加）。
              // hit-zone 层按同样的几何在 _LiquidGlassDock 内对齐。
              child: _LiquidGlassDock(
                key: const ValueKey<String>('home-bottom-nav'),
                selectedIndex: _tabStateNotifier.value.selectedIndex,
                onSelected: _onTabChange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 纵向滚动驱动：下滚（delta > 2 且 pixels > 48）隐藏 dock，上滚浮现。
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final pixels = notification.metrics.pixels;
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 2 && pixels > 48 && !_dockHiddenNotifier.value) {
        _dockHiddenNotifier.value = true;
      } else if (delta < -2 && _dockHiddenNotifier.value) {
        _dockHiddenNotifier.value = false;
      }
    }
    return false;
  }

  Widget _buildPageSlot(int index, _HomeTabState tabState) {
    if (!tabState.isLoaded(index)) {
      return const SizedBox.expand();
    }

    return RepaintBoundary(
      key: ValueKey<String>('home-loaded-tab-$index'),
      child: _AnimatedTabPage(
        isActive: tabState.selectedIndex == index,
        animationSeed: tabState.animationSeed,
        slideDirection: tabState.animationDirection,
        pageIndex: index,
        transitionNotifier:
            index == _courseTabIndex ? _courseTransitionLiteMode : null,
        child: TickerMode(
          enabled: tabState.selectedIndex == index,
          child: KeyedSubtree(
            key: PageStorageKey<String>('home-tab-$index'),
            child: _pages[index],
          ),
        ),
      ),
    );
  }

  void _onTabChange(int index) {
    // 切换 tab 时恢复 dock 可见（对齐上游 _resetOverlayState）。
    if (_dockHiddenNotifier.value) {
      _dockHiddenNotifier.value = false;
    }
    final tabState = _tabStateNotifier.value;
    if (index < 0 ||
        index >= _pages.length ||
        tabState.selectedIndex == index) {
      return;
    }

    final loadedPages = List<bool>.of(tabState.loadedPages);
    loadedPages[index] = true;
    _tabStateNotifier.value = _HomeTabState(
      selectedIndex: index,
      loadedPages: List<bool>.unmodifiable(loadedPages),
      animationSeed: tabState.animationSeed + 1,
      animationDirection: index > tabState.selectedIndex ? 1 : -1,
    );
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
    transform.translateByDouble(
      childParentData.offset.dx,
      childParentData.offset.dy,
      0,
      1,
    );
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
                          child: AppLinearProgressIndicator(
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
    with TickerProviderStateMixin {
  static const _tabSlideOffset = 0.055;

  AnimationController? _controller;
  CurvedAnimation? _curve;
  Animation<Offset>? _slide;
  // Perf: 只有真正在过渡动画期间才需要 ClipRect+SlideTransition；
  // 动画完成后释放 controller 并退化为直接返回 child，避免常驻 ticker/saveLayer。
  final ValueNotifier<bool> _isTransitioningNotifier = ValueNotifier<bool>(
    false,
  );
  bool _reduceMotion = false;
  bool _hasResolvedMotion = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AppGlassPerformanceScope.shouldReduceMotionOf(context);
    final wasResolved = _hasResolvedMotion;
    final previousReduceMotion = _reduceMotion;
    if (wasResolved && previousReduceMotion == reduceMotion) {
      return;
    }

    _hasResolvedMotion = true;
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      _setTransitionLiteMode(false);
      _setTransitioning(false);
      _disposeTransitionController();
      return;
    }

    if ((!wasResolved || previousReduceMotion) &&
        widget.isActive &&
        widget.animationSeed > 0) {
      _startTransition();
    }
  }

  void _handleAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _setTransitionLiteMode(false);
      _disposeTransitionController();
      _setTransitioning(false);
    }
  }

  void _setTransitionLiteMode(bool value) {
    final notifier = widget.transitionNotifier;
    if (notifier == null || notifier.value == value) {
      return;
    }
    notifier.value = value;
  }

  void _setTransitioning(bool value) {
    if (!mounted || _isTransitioningNotifier.value == value) {
      return;
    }

    _isTransitioningNotifier.value = value;
  }

  void _startTransition() {
    if (_reduceMotion) {
      _setTransitionLiteMode(false);
      _setTransitioning(false);
      _disposeTransitionController();
      return;
    }

    _ensureTransitionController();
    _configureAnimations();
    _setTransitionLiteMode(true);
    _setTransitioning(true);
    _controller!.forward(from: 0);
  }

  void _ensureTransitionController() {
    if (_controller != null) {
      return;
    }

    final controller = AnimationController(
      vsync: this,
      duration: _HomeviewPageState._tabAnimationDuration,
      value: 1,
    )..addStatusListener(_handleAnimationStatusChanged);
    _controller = controller;
    _curve = CurvedAnimation(parent: controller, curve: Curves.easeOutCubic);
  }

  void _disposeTransitionController() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    controller.removeStatusListener(_handleAnimationStatusChanged);
    _curve?.dispose();
    _curve = null;
    _slide = null;
    _controller = null;
    controller.dispose();
  }

  void _configureAnimations() {
    final curve = _curve;
    if (curve == null) {
      return;
    }

    _slide = Tween<Offset>(
      begin: Offset(widget.slideDirection * _tabSlideOffset, 0),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void didUpdateWidget(covariant _AnimatedTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive) {
      _setTransitionLiteMode(false);
      _disposeTransitionController();
      _setTransitioning(false);
      return;
    }

    if (widget.isActive && widget.animationSeed != oldWidget.animationSeed) {
      _startTransition();
      return;
    }

    if (widget.slideDirection != oldWidget.slideDirection ||
        widget.isActive != oldWidget.isActive) {
      _configureAnimations();
    }
  }

  @override
  void dispose() {
    _setTransitionLiteMode(false);
    _disposeTransitionController();
    _isTransitioningNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slide;
    if (!widget.isActive ||
        _reduceMotion ||
        !_isTransitioningNotifier.value ||
        slide == null) {
      return widget.child;
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _isTransitioningNotifier,
      child: widget.child,
      builder: (context, isTransitioning, child) {
        if (!isTransitioning) {
          return child!;
        }

        return ClipRect(
          child: SlideTransition(
            key: ValueKey<String>('home-tab-slide-${widget.pageIndex}'),
            position: slide,
            child: child,
          ),
        );
      },
    );
  }
}

class _LiquidGlassDock extends StatelessWidget {
  const _LiquidGlassDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const List<LiquidGlassTabBarItem> _dockItems = [
    LiquidGlassTabBarItem(
      icon: CupertinoIcons.calendar,
      selectedIcon: CupertinoIcons.calendar,
      label: '课表',
    ),
    LiquidGlassTabBarItem(
      icon: CupertinoIcons.square_grid_2x2,
      selectedIcon: CupertinoIcons.square_grid_2x2_fill,
      label: '功能',
    ),
    LiquidGlassTabBarItem(
      icon: CupertinoIcons.person,
      selectedIcon: CupertinoIcons.person_fill,
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final glass = context.glassTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final dockBottom = (bottomInset > 12 ? bottomInset : 12.0) + 24;
    final tabBarWidth = math.min(screenWidth - 48, 320.0);

    // LiquidGlassTabBar（Impeller 玻璃 pill 档）是全屏自放置 overlay：
    // 直接放开渲染，bottom 间距走 margin（包内叠加 safe-area）。
    // hit-zone 层按 bar 的自放置几何对齐（底部居中、bar 尺寸），
    // 仅提供稳定的语义节点与测试 key（home-hit-zone-*）。整层
    // IgnorePointer：点击必须全部交给 bar 自己的 InkWell/手势层，
    // 否则 pill 的按压/滑动动画与玻璃交互会被拦截失效。
    final hitZones = Positioned(
      left: (screenWidth - tabBarWidth) / 2,
      right: (screenWidth - tabBarWidth) / 2,
      bottom: dockBottom + bottomInset,
      height: 64,
      child: IgnorePointer(
        child: Row(
          children: [
            for (var index = 0; index < _dockItems.length; index++)
              Expanded(
                child: Semantics(
                  key: ValueKey<String>('home-hit-zone-${_dockItems[index].label}'),
                  button: true,
                  selected: index == selectedIndex,
                  label: _dockItems[index].label,
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        LiquidGlassTabBar(
          items: _dockItems,
          selectedIndex: selectedIndex,
          onChanged: onSelected,
          style: glass.tabBarStyle,
          itemStyle: glass.tabItemStyleOf(colorScheme),
          pillStyle: glass.tabPillStyle,
          width: tabBarWidth,
          height: 64,
          margin: EdgeInsets.only(bottom: dockBottom),
        ),
        hitZones,
      ],
    );
  }
}
