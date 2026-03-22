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
  static const Radius _hotWaterSheetTopRadius = Radius.circular(28);
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
      backgroundColor: _hotWaterSheetBackgroundColor(),
      topRadius: _hotWaterSheetTopRadius,
      shadow: _hotWaterSheetShadow(),
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
      backgroundColor: _hotWaterSheetBackgroundColor(),
      topRadius: _hotWaterSheetTopRadius,
      shadow: _hotWaterSheetShadow(),
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
      backgroundColor: _hotWaterSheetBackgroundColor(),
      topRadius: _hotWaterSheetTopRadius,
      shadow: _hotWaterSheetShadow(),
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
      body: GetBuilder<FunctionHotWaterLogic>(
        builder: (logic) {
          final state = logic.state;
          final bool hasSelectedDevice =
              state.deviceList.isNotEmpty && state.choiceDevice.value >= 0;
          final String? deviceName =
              hasSelectedDevice
                  ? state.deviceList[state.choiceDevice.value]['posname']
                      ?.toString()
                  : null;

          return Stack(
            children: [
              Positioned.fill(
                child: WaterBackground(waterStatus: state.waterStatus.value),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      HotWaterStatusHeader(
                        waterStatus: state.waterStatus.value,
                        hasSelectedDevice: hasSelectedDevice,
                      ),
                      const SizedBox(height: 16),
                      HotWaterCurrentDeviceCard(
                        deviceName: deviceName,
                        hasSelectedDevice: hasSelectedDevice,
                        onTap: _showDeviceSelectionDialog,
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HotWaterControlButton(
                              isLoading: state.isLoading.value,
                              deviceCheckComplete:
                                  state.deviceCheckComplete.value,
                              waterStatus: state.waterStatus.value,
                              hasSelectedDevice: hasSelectedDevice,
                              onTap: _handleWaterToggle,
                            ),
                            HotWaterActionHint(
                              isLoading: state.isLoading.value,
                              deviceCheckComplete:
                                  state.deviceCheckComplete.value,
                              hasSelectedDevice: hasSelectedDevice,
                            ),
                          ],
                        ),
                      ),
                      if (state.balance.value != 'null')
                        HotWaterBalanceCard(
                          balance: state.balance.value,
                          onTap: _launchUrl,
                        ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: BubbleAnimation(
                  isActive: state.waterStatus.value,
                  color: HotWaterPalette.accentStrong(
                    context,
                    active: state.waterStatus.value,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
