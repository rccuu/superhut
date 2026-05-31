import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/ambient_bubble_field.dart';
import '../../core/ui/app_bottom_sheet.dart';
import '../../core/ui/app_snack_bar.dart';
import 'logic.dart';
import 'widgets/water_page_widgets.dart';

typedef HotWaterBottomSheetPresenter =
    Future<T?> Function<T>({
      required BuildContext context,
      required WidgetBuilder builder,
      bool expand,
      Color? backgroundColor,
      Radius? topRadius,
      BoxShadow? shadow,
    });
typedef HotWaterUrlOpener = Future<bool> Function(Uri url);

class FunctionHotWaterPage extends StatefulWidget {
  const FunctionHotWaterPage({
    super.key,
    this.logic,
    this.showBottomSheet,
    this.openRechargePage,
  });

  final FunctionHotWaterLogic? logic;
  final HotWaterBottomSheetPresenter? showBottomSheet;
  final HotWaterUrlOpener? openRechargePage;

  @override
  State<FunctionHotWaterPage> createState() => _FunctionHotWaterPageState();
}

class _FunctionHotWaterPageState extends State<FunctionHotWaterPage> {
  static const Radius _hotWaterSheetTopRadius = Radius.circular(28);
  late final FunctionHotWaterLogic logic;
  late final bool _ownsLogic;
  final Uri _url = Uri.parse(
    'alipays://platformapi/startapp?appId=2019030163398604&page=pages/index/index',
  );
  bool _isDeviceSelectionSheetOpen = false;
  bool _isDeviceManagementSheetOpen = false;
  bool _isAddDeviceSheetOpen = false;
  bool _isOpeningRechargePage = false;
  bool _isDeleteConfirmationOpen = false;

  @override
  void initState() {
    super.initState();
    final injectedLogic = widget.logic;
    if (injectedLogic != null) {
      logic = injectedLogic;
      _ownsLogic = false;
    } else {
      logic = Get.put(FunctionHotWaterLogic());
      _ownsLogic = true;
    }
  }

  Future<void> _launchUrl() async {
    if (_isOpeningRechargePage) {
      return;
    }

    _isOpeningRechargePage = true;
    try {
      final openRechargePage =
          widget.openRechargePage ?? (Uri url) => launchUrl(url);
      if (!await openRechargePage(_url)) {
        _showSnackBar('无法打开校园卡页面', type: AppSnackBarType.error);
      }
    } catch (_) {
      _showSnackBar('无法打开校园卡页面', type: AppSnackBarType.error);
    } finally {
      _isOpeningRechargePage = false;
    }
  }

  void _showSnackBar(
    String message, {
    AppSnackBarType type = AppSnackBarType.info,
  }) {
    if (!mounted) {
      return;
    }

    showAppSnackBar(context, message: message, type: type);
  }

  Color _hotWaterSheetBackgroundColor() {
    return HotWaterPalette.mistSurface(context);
  }

  BoxShadow _hotWaterSheetShadow() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = HotWaterPalette.accentStrong(context);

    return BoxShadow(
      color: accent.withValues(alpha: isDark ? 0.18 : 0.08),
      blurRadius: 24,
      spreadRadius: 1,
      offset: const Offset(0, -3),
    );
  }

  Future<T?> _showHotWaterSheet<T>({required WidgetBuilder builder}) {
    final presenter = widget.showBottomSheet ?? showAppAdaptiveBottomSheet;
    return presenter<T>(
      context: context,
      expand: false,
      backgroundColor: _hotWaterSheetBackgroundColor(),
      topRadius: _hotWaterSheetTopRadius,
      shadow: _hotWaterSheetShadow(),
      builder: builder,
    );
  }

  void _handleWaterToggle() {
    final isDisabled =
        logic.state.isLoading.value || !logic.state.deviceCheckComplete.value;
    if (isDisabled) {
      if (!logic.state.deviceCheckComplete.value &&
          !logic.state.isLoading.value) {
        _showSnackBar('正在检测设备状态，请稍候...');
      }
      return;
    }

    if (logic.state.choiceDevice.value == -1) {
      _showSnackBar('请先选择设备', type: AppSnackBarType.warning);
      return;
    }

    if (logic.state.waterStatus.value) {
      logic.endWater();
    } else {
      logic.startWater();
    }
  }

  void _showDeviceSelectionDialog() {
    if (_isDeviceSelectionSheetOpen) {
      return;
    }

    _isDeviceSelectionSheetOpen = true;
    final sheet = _showHotWaterSheet<void>(
      builder:
          (sheetContext) => Obx(() {
            final devices = logic.state.deviceList;
            final deviceCount = devices.length;

            return WaterDeviceSelectionSheet(
              devices: devices,
              deviceCount: deviceCount,
              selectedIndex: logic.state.choiceDevice.value,
              onManageDevices: () {
                Navigator.of(sheetContext).pop();
                _showDeviceManagementDialog();
              },
              onSelectDevice: (index) {
                if (logic.state.waterStatus.value) {
                  Navigator.of(sheetContext).pop();
                  return;
                }

                logic.setChoiceDevice(index);
                Navigator.of(sheetContext).pop();
              },
            );
          }),
    );
    unawaited(_trackWaterDeviceSelectionSheet(sheet));
  }

  Future<void> _trackWaterDeviceSelectionSheet(Future<void> sheet) async {
    try {
      await sheet;
    } finally {
      _isDeviceSelectionSheetOpen = false;
    }
  }

  Future<void> _confirmDeleteDevice(
    BuildContext sheetContext,
    String deviceName,
    String deviceCode,
  ) async {
    if (_isDeleteConfirmationOpen) {
      return;
    }

    _isDeleteConfirmationOpen = true;
    try {
      final shouldDelete =
          await showDialog<bool>(
            context: sheetContext,
            builder:
                (dialogContext) => AlertDialog(
                  title: const Text('删除设备'),
                  content: Text('确定要删除设备 "$deviceName" 吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(
                        '确定',
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!shouldDelete || !mounted) {
        return;
      }

      final success = await logic.deleteDevice(deviceCode);
      if (!mounted || !success) {
        return;
      }

      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
      _showDeviceSelectionDialog();
    } finally {
      _isDeleteConfirmationOpen = false;
    }
  }

  void _showDeviceManagementDialog() {
    if (_isDeviceManagementSheetOpen) {
      return;
    }

    _isDeviceManagementSheetOpen = true;
    final sheet = _showHotWaterSheet<void>(
      builder:
          (sheetContext) => Obx(() {
            final devices = logic.state.deviceList;
            final deviceCount = devices.length;

            return WaterDeviceManagementSheet(
              devices: devices,
              deviceCount: deviceCount,
              onAddDevice: () {
                Navigator.of(sheetContext).pop();
                _showAddDevicePage();
              },
              onDeleteDevice: (index) {
                if (index < 0 || index >= deviceCount) {
                  return;
                }

                final device = devices[index] as Map;
                _confirmDeleteDevice(
                  sheetContext,
                  device['posname']?.toString() ?? '未知设备',
                  device['poscode']?.toString() ?? '',
                );
              },
            );
          }),
    );
    unawaited(_trackWaterDeviceManagementSheet(sheet));
  }

  Future<void> _trackWaterDeviceManagementSheet(Future<void> sheet) async {
    try {
      await sheet;
    } finally {
      _isDeviceManagementSheetOpen = false;
    }
  }

  void _showAddDevicePage() {
    if (_isAddDeviceSheetOpen) {
      return;
    }

    _isAddDeviceSheetOpen = true;
    final sheet = _showHotWaterSheet<void>(
      builder:
          (sheetContext) => AddWaterDeviceSheet(
            onClose: () => Navigator.of(sheetContext).pop(),
            onSubmit: (deviceCode) async {
              if (deviceCode.isEmpty) {
                _showSnackBar('请输入设备号', type: AppSnackBarType.warning);
                return false;
              }

              final success = await logic.addDevice(deviceCode);
              if (!mounted || !success) {
                return false;
              }

              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
              _showDeviceSelectionDialog();
              return true;
            },
          ),
    );
    unawaited(_trackAddWaterDeviceSheet(sheet));
  }

  Future<void> _trackAddWaterDeviceSheet(Future<void> sheet) async {
    try {
      await sheet;
    } finally {
      _isAddDeviceSheetOpen = false;
    }
  }

  @override
  void dispose() {
    if (_ownsLogic) {
      Get.delete<FunctionHotWaterLogic>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 72,
        toolbarHeight: 68,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: HotWaterBackButton(onTap: () => Navigator.of(context).pop()),
        ),
        title: Text(
          '宿舍热水',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: HotWaterPalette.foreground(context),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Obx(
              () => WaterBackground(waterStatus: logic.state.waterStatus.value),
            ),
          ),
          SafeArea(
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compactHeight = constraints.maxHeight < 680;
                  final minContentHeight =
                      (constraints.maxHeight - 36)
                          .clamp(0.0, double.infinity)
                          .toDouble();
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minContentHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Obx(() {
                            final state = logic.state;
                            final selectedIndex = state.choiceDevice.value;
                            final hasSelectedDevice =
                                state.deviceList.isNotEmpty &&
                                selectedIndex >= 0 &&
                                selectedIndex < state.deviceList.length;

                            return HotWaterStatusHeader(
                              waterStatus: state.waterStatus.value,
                              hasSelectedDevice: hasSelectedDevice,
                            );
                          }),
                          const SizedBox(height: 16),
                          Obx(() {
                            final state = logic.state;
                            final selectedIndex = state.choiceDevice.value;
                            final hasSelectedDevice =
                                state.deviceList.isNotEmpty &&
                                selectedIndex >= 0 &&
                                selectedIndex < state.deviceList.length;
                            final deviceName =
                                hasSelectedDevice
                                    ? state.deviceList[selectedIndex]['posname']
                                        ?.toString()
                                    : null;

                            return HotWaterCurrentDeviceCard(
                              deviceName: deviceName,
                              hasSelectedDevice: hasSelectedDevice,
                              onTap: _showDeviceSelectionDialog,
                            );
                          }),
                          SizedBox(height: compactHeight ? 20 : 28),
                          Obx(() {
                            final state = logic.state;
                            final selectedIndex = state.choiceDevice.value;
                            final hasSelectedDevice =
                                state.deviceList.isNotEmpty &&
                                selectedIndex >= 0 &&
                                selectedIndex < state.deviceList.length;
                            final isLoading = state.isLoading.value;
                            final deviceCheckComplete =
                                state.deviceCheckComplete.value;

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HotWaterControlButton(
                                  isLoading: isLoading,
                                  deviceCheckComplete: deviceCheckComplete,
                                  waterStatus: state.waterStatus.value,
                                  hasSelectedDevice: hasSelectedDevice,
                                  onTap: _handleWaterToggle,
                                ),
                                HotWaterActionHint(
                                  isLoading: isLoading,
                                  deviceCheckComplete: deviceCheckComplete,
                                  hasSelectedDevice: hasSelectedDevice,
                                ),
                              ],
                            );
                          }),
                          SizedBox(height: compactHeight ? 16 : 28),
                          Obx(() {
                            final balance = logic.state.balance.value;
                            if (balance == 'null') {
                              return const SizedBox.shrink();
                            }

                            return HotWaterBalanceCard(
                              balance: balance,
                              onTap: _launchUrl,
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned.fill(
            child: Obx(() {
              final isActive = logic.state.waterStatus.value;
              return AmbientBubbleField.hotWater(
                isActive: isActive,
                color: HotWaterPalette.accentStrong(context, active: isActive),
              );
            }),
          ),
        ],
      ),
    );
  }
}
