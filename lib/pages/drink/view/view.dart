import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

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

  void _showMoreFunctionsBottomSheet() {
    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => DrinkMoreFunctionsSheet(
            onManageDevices: () {
              Navigator.of(sheetContext).pop();
              _showDeviceManagementSheet();
            },
            onAddDevice: () {
              Navigator.of(sheetContext).pop();
              _showAddDeviceOptions();
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

  void _showAddDeviceOptions() {
    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => DrinkAddDeviceOptionsSheet(
            onCancel: () => Navigator.of(sheetContext).pop(),
            onScan: () async {
              Navigator.of(sheetContext).pop();
              await _scanQRCodeAndAddDevice();
            },
          ),
    );
  }

  Future<bool> _scanQRCodeAndAddDevice() async {
    try {
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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('慧生活798'),
        elevation: 0,
        backgroundColor: Colors.transparent,
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
            child: Column(
              children: [
                GetBuilder<FunctionDrinkLogic>(
                  builder: (logic) {
                    return DrinkStatusHeader(
                      drinkStatus: logic.state.drinkStatus.value,
                    );
                  },
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GetBuilder<FunctionDrinkLogic>(
                            builder: (logic) {
                              final String? deviceName =
                                  logic.state.deviceList.isEmpty ||
                                          logic.state.choiceDevice.value == -1
                                      ? null
                                      : logic.formatDeviceName(
                                        logic
                                            .state
                                            .deviceList[logic
                                                .state
                                                .choiceDevice
                                                .value]['name']
                                            .toString(),
                                      );
                              return DrinkCurrentDeviceCard(
                                deviceName: deviceName,
                                onTap: _showDeviceSelectionDialog,
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: GetBuilder<FunctionDrinkLogic>(
                              builder: (logic) {
                                return DrinkActionButton(
                                  drinkStatus: logic.state.drinkStatus.value,
                                  onTap: _handleDrinkToggle,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: DrinkMoreFunctionsButton(
                      onTap: _showMoreFunctionsBottomSheet,
                    ),
                  ),
                ),
              ],
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
