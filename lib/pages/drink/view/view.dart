import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/ui/ambient_bubble_field.dart';
import '../../../core/ui/app_bottom_sheet.dart';
import '../../../core/ui/app_loading_indicator.dart';
import '../../../core/ui/app_page_route.dart';
import '../../../core/ui/app_snack_bar.dart';
import 'logic.dart';
import 'widgets/drink_page_widgets.dart';

typedef DrinkCameraPermissionRequester = Future<PermissionStatus> Function();
typedef DrinkQrScannerOpener = Future<String?> Function(BuildContext context);
typedef DrinkBottomSheetPresenter =
    Future<T?> Function<T>({
      required BuildContext context,
      required WidgetBuilder builder,
      bool expand,
      Color? backgroundColor,
    });

class FunctionDrinkPage extends StatefulWidget {
  const FunctionDrinkPage({
    super.key,
    this.logic,
    this.requestCameraPermission,
    this.openQrScanner,
    this.showBottomSheet,
  });

  final FunctionDrinkLogic? logic;
  final DrinkCameraPermissionRequester? requestCameraPermission;
  final DrinkQrScannerOpener? openQrScanner;
  final DrinkBottomSheetPresenter? showBottomSheet;

  @override
  State<FunctionDrinkPage> createState() => _FunctionDrinkPageState();
}

class _FunctionDrinkPageState extends State<FunctionDrinkPage> {
  late final FunctionDrinkLogic logic;
  late final bool _ownsLogic;
  bool _isAddingDevice = false;
  bool _isDeviceSelectionSheetOpen = false;
  bool _isDeviceManagementSheetOpen = false;
  bool _isDeleteConfirmationOpen = false;

  @override
  void initState() {
    super.initState();
    final injectedLogic = widget.logic;
    if (injectedLogic != null) {
      logic = injectedLogic;
      _ownsLogic = false;
    } else {
      logic = Get.put(FunctionDrinkLogic());
      _ownsLogic = true;
    }
  }

  void _showSnackBar(
    String message, {
    AppSnackBarType type = AppSnackBarType.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted) {
      return;
    }

    showAppSnackBar(
      context,
      message: message,
      type: type,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  void _showResultSnackBar({
    required bool success,
    required String successMessage,
    required String failureMessage,
  }) {
    _showSnackBar(
      success ? successMessage : failureMessage,
      type: success ? AppSnackBarType.success : AppSnackBarType.error,
    );
  }

  void _handleDrinkToggle() {
    if (logic.state.choiceDevice.value == -1) {
      _showSnackBar('请先选择设备', type: AppSnackBarType.warning);
      return;
    }

    if (logic.state.drinkStatus.value) {
      logic.endDrink();
    } else {
      logic.startDrink();
    }
  }

  Future<T?> _showDrinkSheet<T>({required WidgetBuilder builder}) {
    final presenter = widget.showBottomSheet ?? showAppAdaptiveBottomSheet;
    return presenter<T>(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  void _showDeviceSelectionDialog() {
    if (_isDeviceSelectionSheetOpen) {
      return;
    }

    _isDeviceSelectionSheetOpen = true;
    final sheet = _showDrinkSheet<void>(
      builder:
          (sheetContext) => Obx(() {
            final devices = logic.state.deviceList;
            final deviceCount = devices.length;

            return DrinkDeviceSelectionSheet(
              devices: devices,
              deviceCount: deviceCount,
              selectedIndex: logic.state.choiceDevice.value,
              formatDeviceName: logic.formatDeviceName,
              onSelectDevice: (index) {
                if (logic.state.drinkStatus.value) {
                  Navigator.of(sheetContext).pop();
                  return;
                }

                logic.setChoiceDevice(index);
                Navigator.of(sheetContext).pop();
              },
            );
          }),
    );
    unawaited(_trackDeviceSelectionSheet(sheet));
  }

  Future<void> _trackDeviceSelectionSheet(Future<void> sheet) async {
    try {
      await sheet;
    } finally {
      _isDeviceSelectionSheetOpen = false;
    }
  }

  Future<void> _confirmDeleteDevice(String deviceName, String deviceId) async {
    if (_isDeleteConfirmationOpen) {
      return;
    }

    _isDeleteConfirmationOpen = true;
    try {
      final shouldDelete =
          await showDialog<bool>(
            context: context,
            builder:
                (dialogContext) => AlertDialog(
                  title: const Text('确认删除'),
                  content: Text('确定要删除设备"$deviceName"吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(dialogContext).colorScheme.error,
                      ),
                      child: const Text('删除'),
                    ),
                  ],
                ),
          ) ??
          false;

      if (!shouldDelete) {
        return;
      }

      final bool removed = await logic.favoDevice(deviceId, true);
      if (!mounted) {
        return;
      }

      if (removed) {
        logic.removeDeviceByName(deviceName);
        _showResultSnackBar(
          success: true,
          successMessage: '设备删除成功',
          failureMessage: '',
        );
      } else {
        _showResultSnackBar(
          success: false,
          successMessage: '',
          failureMessage: '设备删除失败，请稍后重试',
        );
      }
    } catch (_) {
      _showResultSnackBar(
        success: false,
        successMessage: '',
        failureMessage: '设备删除失败，请稍后重试',
      );
    } finally {
      _isDeleteConfirmationOpen = false;
    }
  }

  void _showDeviceManagementSheet() {
    if (_isDeviceManagementSheetOpen) {
      return;
    }

    _isDeviceManagementSheetOpen = true;
    final sheet = _showDrinkSheet<void>(
      builder:
          (sheetContext) => Obx(() {
            final devices = logic.state.deviceList;
            final deviceCount = devices.length;

            return DrinkDeviceManagementSheet(
              devices: devices,
              deviceCount: deviceCount,
              formatDeviceName: logic.formatDeviceName,
              onClose: () => Navigator.of(sheetContext).pop(),
              onAddDevice: () async {
                Navigator.of(sheetContext).pop();
                await _scanQRCodeAndAddDevice();
              },
              onDeleteDevice: (index) {
                if (index < 0 || index >= deviceCount) {
                  return;
                }

                final device = devices[index] as Map;
                _confirmDeleteDevice(
                  logic.formatDeviceName(device['name']?.toString() ?? '未知设备'),
                  device['id']?.toString() ?? '',
                );
              },
            );
          }),
    );
    unawaited(_trackDeviceManagementSheet(sheet));
  }

  Future<void> _trackDeviceManagementSheet(Future<void> sheet) async {
    try {
      await sheet;
    } finally {
      _isDeviceManagementSheetOpen = false;
    }
  }

  Future<bool> _scanQRCodeAndAddDevice() async {
    if (_isAddingDevice) {
      return false;
    }

    _isAddingDevice = true;
    try {
      final PermissionStatus cameraPermission =
          await (widget.requestCameraPermission ?? Permission.camera.request)();
      if (!cameraPermission.isGranted) {
        if (!mounted) {
          return false;
        }

        final bool needsSettings =
            cameraPermission.isPermanentlyDenied ||
            cameraPermission.isRestricted;

        _showSnackBar(
          needsSettings
              ? '相机权限已关闭，请在系统设置中允许工大盒子访问相机后再扫描。'
              : '未授予相机权限，无法扫描设备二维码。',
          type: AppSnackBarType.warning,
          actionLabel: needsSettings ? '去设置' : null,
          onAction: needsSettings ? openAppSettings : null,
        );
        return false;
      }

      if (!mounted) {
        return false;
      }
      final result = await (widget.openQrScanner ?? _openQrScanner)(context);
      if (result == null || result.isEmpty) {
        return false;
      }

      final String enc = _deviceCodeFromQrResult(result);
      final bool isFavo = await logic.favoDevice(enc, false);
      _showResultSnackBar(
        success: isFavo,
        successMessage: '设备添加成功',
        failureMessage: '设备添加失败，请稍后重试',
      );

      if (isFavo) {
        await logic.getDeviceList();
      }
      return isFavo;
    } catch (error) {
      _showResultSnackBar(
        success: false,
        successMessage: '',
        failureMessage: '扫描二维码失败，请稍后重试',
      );
      return false;
    } finally {
      _isAddingDevice = false;
    }
  }

  String _deviceCodeFromQrResult(String result) {
    final slashIndex = result.lastIndexOf('/');
    if (slashIndex == -1) {
      return result;
    }
    return result.substring(slashIndex + 1);
  }

  Future<String?> _openQrScanner(BuildContext context) {
    return Navigator.of(context).push<String>(
      buildAppPageRoute(builder: (_) => const DrinkQrCodeScannerPage()),
    );
  }

  @override
  void dispose() {
    if (_ownsLogic) {
      Get.delete<FunctionDrinkLogic>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading:
            canPop
                ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh
                          .withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      tooltip: '返回',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                )
                : null,
        title: const Text('慧生活798'),
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface,
          letterSpacing: -0.3,
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Obx(() {
            if (logic.state.isRefreshing.value) {
              return const Padding(
                padding: EdgeInsets.only(right: 18),
                child: Center(child: AppLoadingIndicator(size: 20)),
              );
            }

            return IconButton(
              tooltip: '刷新设备',
              onPressed: () => logic.getDeviceList(showRefreshing: true),
              icon: const Icon(Icons.refresh_rounded),
            );
          }),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Obx(
              () => DrinkBackground(drinkStatus: logic.state.drinkStatus.value),
            ),
          ),
          SafeArea(
            child: RepaintBoundary(
              child: Obx(() {
                if (logic.state.isLoading.value) {
                  return const DrinkLoadingState();
                }

                return RefreshIndicator(
                  onRefresh: () => logic.getDeviceList(showRefreshing: true),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Obx(() {
                                final state = logic.state;
                                final selectedIndex = state.choiceDevice.value;
                                final hasDevice =
                                    state.deviceList.isNotEmpty &&
                                    selectedIndex >= 0 &&
                                    selectedIndex < state.deviceList.length;
                                final deviceName =
                                    hasDevice
                                        ? logic.formatDeviceName(
                                          state
                                              .deviceList[selectedIndex]['name']
                                              .toString(),
                                        )
                                        : null;

                                return DrinkStatusHeader(
                                  drinkStatus: state.drinkStatus.value,
                                  deviceCount: state.deviceList.length,
                                  deviceName: deviceName,
                                );
                              }),
                              const SizedBox(height: 18),
                              Obx(() {
                                final state = logic.state;
                                final selectedIndex = state.choiceDevice.value;
                                final hasDevice =
                                    state.deviceList.isNotEmpty &&
                                    selectedIndex >= 0 &&
                                    selectedIndex < state.deviceList.length;
                                final deviceName =
                                    hasDevice
                                        ? logic.formatDeviceName(
                                          state
                                              .deviceList[selectedIndex]['name']
                                              .toString(),
                                        )
                                        : '';

                                if (!hasDevice) {
                                  return DrinkEmptyDeviceCard(
                                    onAddDevice: _scanQRCodeAndAddDevice,
                                  );
                                }

                                return DrinkCurrentDeviceCard(
                                  deviceName: deviceName,
                                  deviceCount: state.deviceList.length,
                                  onTap: _showDeviceSelectionDialog,
                                );
                              }),
                              const SizedBox(height: 14),
                              DrinkQuickActions(
                                onManageDevices: _showDeviceManagementSheet,
                                onAddDevice: _scanQRCodeAndAddDevice,
                              ),
                              const Spacer(),
                              Obx(() {
                                final state = logic.state;
                                final selectedIndex = state.choiceDevice.value;
                                final hasDevice =
                                    state.deviceList.isNotEmpty &&
                                    selectedIndex >= 0 &&
                                    selectedIndex < state.deviceList.length;

                                return DrinkActionButton(
                                  drinkStatus: state.drinkStatus.value,
                                  enabled: hasDevice,
                                  onTap: _handleDrinkToggle,
                                );
                              }),
                              const SizedBox(height: 14),
                              Obx(() {
                                final state = logic.state;
                                final selectedIndex = state.choiceDevice.value;
                                final hasDevice =
                                    state.deviceList.isNotEmpty &&
                                    selectedIndex >= 0 &&
                                    selectedIndex < state.deviceList.length;

                                return Text(
                                  hasDevice
                                      ? '设备可切换，开始用水后会自动检测状态。'
                                      : '添加设备后即可开始用水。',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Positioned.fill(
            child: Obx(
              () => AmbientBubbleField.drink(
                isActive: logic.state.drinkStatus.value,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
