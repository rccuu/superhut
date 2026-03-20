import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

import 'logic.dart';
import 'widgets/water_page_widgets.dart';

class FunctionHotWaterPage extends StatefulWidget {
  const FunctionHotWaterPage({super.key});

  @override
  State<FunctionHotWaterPage> createState() => _FunctionHotWaterPageState();
}

class _FunctionHotWaterPageState extends State<FunctionHotWaterPage> {
  final FunctionHotWaterLogic logic = Get.put(FunctionHotWaterLogic());
  final Uri _url = Uri.parse(
    'alipays://platformapi/startapp?appId=2019030163398604&page=pages/index/index',
  );

  Future<void> _launchUrl() async {
    if (!await launchUrl(_url)) {
      _showSnackBar('无法打开校园卡页面');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      _showSnackBar('请先选择设备');
      return;
    }

    if (logic.state.waterStatus.value) {
      logic.endWater();
    } else {
      logic.startWater();
    }
  }

  void _showDeviceSelectionDialog() {
    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => GetBuilder<FunctionHotWaterLogic>(
            builder: (logic) {
              return WaterDeviceSelectionSheet(
                devices: List<dynamic>.from(logic.state.deviceList),
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
            },
          ),
    );
  }

  Future<void> _confirmDeleteDevice(
    BuildContext sheetContext,
    String deviceName,
    String deviceCode,
  ) async {
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
                    child: const Text(
                      '确定',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;

    if (!shouldDelete || !mounted) {
      return;
    }

    await logic.deleteDevice(deviceCode);
    if (!mounted) {
      return;
    }

    if (sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
    _showDeviceSelectionDialog();
  }

  void _showDeviceManagementDialog() {
    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => GetBuilder<FunctionHotWaterLogic>(
            builder: (logic) {
              return WaterDeviceManagementSheet(
                devices: List<dynamic>.from(logic.state.deviceList),
                onAddDevice: () {
                  Navigator.of(sheetContext).pop();
                  _showAddDevicePage();
                },
                onDeleteDevice: (index) {
                  final Map<String, dynamic> device = Map<String, dynamic>.from(
                    logic.state.deviceList[index] as Map,
                  );
                  _confirmDeleteDevice(
                    sheetContext,
                    device['posname']?.toString() ?? '未知设备',
                    device['poscode']?.toString() ?? '',
                  );
                },
              );
            },
          ),
    );
  }

  void _showAddDevicePage() {
    showCupertinoModalBottomSheet(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => AddWaterDeviceSheet(
            onClose: () => Navigator.of(sheetContext).pop(),
            onSubmit: (deviceCode) async {
              if (deviceCode.isEmpty) {
                _showSnackBar('请输入设备号');
                return;
              }

              final success = await logic.addDevice(deviceCode);
              if (!mounted || !success) {
                return;
              }

              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
              _showDeviceSelectionDialog();
            },
          ),
    );
  }

  @override
  void dispose() {
    Get.delete<FunctionHotWaterLogic>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('宿舍热水'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: GetBuilder<FunctionHotWaterLogic>(
              builder: (logic) {
                return WaterBackground(
                  waterStatus: logic.state.waterStatus.value,
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                GetBuilder<FunctionHotWaterLogic>(
                  builder: (logic) {
                    return HotWaterStatusHeader(
                      waterStatus: logic.state.waterStatus.value,
                    );
                  },
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: GetBuilder<FunctionHotWaterLogic>(
                      builder: (logic) {
                        final String? deviceName =
                            logic.state.deviceList.isEmpty ||
                                    logic.state.choiceDevice.value == -1
                                ? null
                                : logic
                                    .state
                                    .deviceList[logic
                                        .state
                                        .choiceDevice
                                        .value]['posname']
                                    ?.toString();
                        return HotWaterCurrentDeviceCard(
                          deviceName: deviceName,
                          onTap: _showDeviceSelectionDialog,
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: GetBuilder<FunctionHotWaterLogic>(
                      builder: (logic) {
                        return HotWaterControlButton(
                          isLoading: logic.state.isLoading.value,
                          deviceCheckComplete:
                              logic.state.deviceCheckComplete.value,
                          waterStatus: logic.state.waterStatus.value,
                          onTap: _handleWaterToggle,
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 30,
                    left: 20,
                    right: 20,
                  ),
                  child: GetBuilder<FunctionHotWaterLogic>(
                    builder: (logic) {
                      if (logic.state.balance.value == 'null') {
                        return const SizedBox.shrink();
                      }

                      return HotWaterBalanceCard(
                        balance: logic.state.balance.value,
                        onTap: _launchUrl,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: GetBuilder<FunctionHotWaterLogic>(
              builder: (logic) {
                return BubbleAnimation(
                  isActive: logic.state.waterStatus.value,
                  color: Colors.orange,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
