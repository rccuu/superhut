import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:permission_handler/permission_handler.dart';

import 'logic.dart';
import 'widgets/drink_page_widgets.dart';

class FunctionDrinkPage extends StatefulWidget {
  const FunctionDrinkPage({super.key});

  @override
  State<FunctionDrinkPage> createState() => _FunctionDrinkPageState();
}

class _FunctionDrinkPageState extends State<FunctionDrinkPage> {
  final FunctionDrinkLogic logic = Get.put(FunctionDrinkLogic());

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showResultSnackBar({
    required bool success,
    required String successMessage,
    required String failureMessage,
  }) {
    Get.snackbar(
      success ? '操作成功' : '操作失败',
      success ? successMessage : failureMessage,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: success ? Colors.green : Colors.red,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
      icon: Icon(
        success ? Icons.check_circle : Icons.error,
        color: Colors.white,
      ),
    );
  }

  void _handleDrinkToggle() {
    if (logic.state.choiceDevice.value == -1) {
      _showSnackBar('请先选择设备');
      return;
    }

    if (logic.state.drinkStatus.value) {
      logic.endDrink();
    } else {
      logic.startDrink();
    }
  }

  void _showDeviceSelectionDialog() {
    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => GetBuilder<FunctionDrinkLogic>(
            builder: (logic) {
              return DrinkDeviceSelectionSheet(
                devices: List<dynamic>.from(logic.state.deviceList),
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
            },
          ),
    );
  }

  Future<void> _confirmDeleteDevice(String deviceName, String deviceId) async {
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
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
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
  }

  void _showDeviceManagementSheet() {
    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => GetBuilder<FunctionDrinkLogic>(
            builder: (logic) {
              return DrinkDeviceManagementSheet(
                devices: List<dynamic>.from(logic.state.deviceList),
                formatDeviceName: logic.formatDeviceName,
                onClose: () => Navigator.of(sheetContext).pop(),
                onAddDevice: () async {
                  Navigator.of(sheetContext).pop();
                  await _scanQRCodeAndAddDevice();
                },
                onDeleteDevice: (index) {
                  final Map<String, dynamic> device = Map<String, dynamic>.from(
                    logic.state.deviceList[index] as Map,
                  );
                  _confirmDeleteDevice(
                    logic.formatDeviceName(
                      device['name']?.toString() ?? '未知设备',
                    ),
                    device['id']?.toString() ?? '',
                  );
                },
              );
            },
          ),
    );
  }

  Future<bool> _scanQRCodeAndAddDevice() async {
    try {
      final PermissionStatus cameraPermission =
          await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        if (!mounted) {
          return false;
        }

        final bool needsSettings =
            cameraPermission.isPermanentlyDenied ||
            cameraPermission.isRestricted;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              needsSettings
                  ? '相机权限已关闭，请在系统设置中允许工大盒子访问相机后再扫描。'
                  : '未授予相机权限，无法扫描设备二维码。',
            ),
            action:
                needsSettings
                    ? SnackBarAction(label: '去设置', onPressed: openAppSettings)
                    : null,
          ),
        );
        return false;
      }

      final result = await Get.to<String>(() => const DrinkQrCodeScannerPage());
      if (result == null || result.isEmpty) {
        return false;
      }

      final String enc = result.split('/').last;
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
    }
  }

  @override
  void dispose() {
    Get.delete<FunctionDrinkLogic>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();

    String? selectedDeviceName(FunctionDrinkLogic currentLogic) {
      if (currentLogic.state.deviceList.isEmpty ||
          currentLogic.state.choiceDevice.value == -1) {
        return null;
      }

      return currentLogic.formatDeviceName(
        currentLogic
            .state
            .deviceList[currentLogic.state.choiceDevice.value]['name']
            .toString(),
      );
    }

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
          GetBuilder<FunctionDrinkLogic>(
            builder: (logic) {
              if (logic.state.isRefreshing.value) {
                return const Padding(
                  padding: EdgeInsets.only(right: 18),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                );
              }

              return IconButton(
                tooltip: '刷新设备',
                onPressed: () => logic.getDeviceList(showRefreshing: true),
                icon: const Icon(Icons.refresh_rounded),
              );
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: GetBuilder<FunctionDrinkLogic>(
              builder: (logic) {
                return DrinkBackground(
                  drinkStatus: logic.state.drinkStatus.value,
                );
              },
            ),
          ),
          SafeArea(
            child: GetBuilder<FunctionDrinkLogic>(
              builder: (logic) {
                final String? deviceName = selectedDeviceName(logic);
                final bool hasDevice = deviceName != null;

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
                              DrinkStatusHeader(
                                drinkStatus: logic.state.drinkStatus.value,
                                deviceCount: logic.state.deviceList.length,
                                deviceName: deviceName,
                              ),
                              const SizedBox(height: 18),
                              hasDevice
                                  ? DrinkCurrentDeviceCard(
                                    deviceName: deviceName,
                                    deviceCount: logic.state.deviceList.length,
                                    onTap: _showDeviceSelectionDialog,
                                  )
                                  : DrinkEmptyDeviceCard(
                                    onAddDevice: _scanQRCodeAndAddDevice,
                                  ),
                              const SizedBox(height: 14),
                              DrinkQuickActions(
                                onManageDevices: _showDeviceManagementSheet,
                                onAddDevice: _scanQRCodeAndAddDevice,
                              ),
                              const Spacer(),
                              DrinkActionButton(
                                drinkStatus: logic.state.drinkStatus.value,
                                enabled: hasDevice,
                                onTap: _handleDrinkToggle,
                              ),
                              const SizedBox(height: 14),
                              Text(
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
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: GetBuilder<FunctionDrinkLogic>(
              builder: (logic) {
                return DrinkBubbleAnimation(
                  isActive: logic.state.drinkStatus.value,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
