import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../../core/ui/color_scheme_ext.dart';

class WaterBackground extends StatelessWidget {
  const WaterBackground({super.key, required this.waterStatus});

  final bool waterStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color accent = colorScheme.warning;
    final Color warmSurface = colorScheme.warningContainerSoft;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: waterStatus ? 0.18 : 0.12),
            warmSurface.withValues(alpha: waterStatus ? 0.34 : 0.18),
            colorScheme.surface,
          ],
          stops: waterStatus ? const [0.0, 0.42, 1.0] : const [0.0, 0.18, 1.0],
        ),
      ),
    );
  }
}

class HotWaterStatusHeader extends StatelessWidget {
  const HotWaterStatusHeader({super.key, required this.waterStatus});

  final bool waterStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = colorScheme.isDarkMode;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              waterStatus
                  ? [colorScheme.warning, colorScheme.error]
                  : [
                    colorScheme.surfaceContainerHigh.withValues(
                      alpha: isDark ? 0.96 : 1,
                    ),
                    colorScheme.warningContainerSoft.withValues(
                      alpha: isDark ? 0.72 : 1,
                    ),
                  ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              waterStatus
                  ? colorScheme.onError.withValues(alpha: 0.12)
                  : colorScheme.warning.withValues(alpha: isDark ? 0.26 : 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color:
                waterStatus
                    ? colorScheme.warning.withValues(alpha: 0.20)
                    : colorScheme.warning.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color:
                  waterStatus
                      ? colorScheme.onError.withValues(alpha: 0.14)
                      : colorScheme.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              waterStatus ? Ionicons.flame : Ionicons.water_outline,
              color: waterStatus ? colorScheme.onError : colorScheme.warning,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  waterStatus ? '正在使用热水' : '准备洗澡',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color:
                        waterStatus
                            ? colorScheme.onError
                            : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  waterStatus ? '热水已开启，结束后记得及时关闭。' : '先确认设备状态，再开始本次热水使用。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color:
                        waterStatus
                            ? colorScheme.onError.withValues(alpha: 0.84)
                            : colorScheme.onSurfaceVariant,
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

class HotWaterCurrentDeviceCard extends StatelessWidget {
  const HotWaterCurrentDeviceCard({
    super.key,
    required this.deviceName,
    required this.onTap,
  });

  final String? deviceName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = colorScheme.isDarkMode;
    final borderRadius = BorderRadius.circular(22);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surfaceContainerHigh.withValues(
                alpha: isDark ? 0.94 : 1,
              ),
              colorScheme.warningContainerSoft.withValues(
                alpha: isDark ? 0.64 : 1,
              ),
            ],
          ),
          borderRadius: borderRadius,
          border: Border.all(
            color: colorScheme.warning.withValues(alpha: isDark ? 0.24 : 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.warning.withValues(
                alpha: isDark ? 0.14 : 0.08,
              ),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: borderRadius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前设备',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colorScheme.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Ionicons.sparkles_outline,
                            color: colorScheme.warning,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            deviceName ?? '未选择设备',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HotWaterControlButton extends StatelessWidget {
  const HotWaterControlButton({
    super.key,
    required this.isLoading,
    required this.deviceCheckComplete,
    required this.waterStatus,
    required this.onTap,
  });

  final bool isLoading;
  final bool deviceCheckComplete;
  final bool waterStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = isLoading || !deviceCheckComplete;
    final Color startColor =
        isDisabled
            ? colorScheme.surfaceContainerHighest
            : waterStatus
            ? colorScheme.warning
            : colorScheme.warning;
    final Color endColor =
        isDisabled
            ? colorScheme.surfaceContainerHigh
            : waterStatus
            ? colorScheme.error
            : colorScheme.tertiary;
    final Color foreground =
        isDisabled
            ? colorScheme.onSurfaceVariant
            : ThemeData.estimateBrightnessForColor(endColor) == Brightness.dark
            ? Colors.white
            : const Color(0xFF2D1B00);
    final shadowColor =
        isDisabled
            ? colorScheme.shadow.withValues(alpha: 0.18)
            : endColor.withValues(alpha: 0.28);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [startColor, endColor],
          ),
          boxShadow: [
            BoxShadow(color: shadowColor, blurRadius: 15, spreadRadius: 5),
          ],
          border: Border.all(
            color:
                isDisabled
                    ? colorScheme.outlineVariant.withValues(alpha: 0.72)
                    : foreground.withValues(alpha: 0.12),
          ),
        ),
        child: Center(
          child:
              isLoading
                  ? _ProgressIndicator(
                    icon: waterStatus ? Icons.stop : Icons.play_arrow,
                    color: foreground,
                  )
                  : !deviceCheckComplete
                  ? _ProgressIndicator(icon: Icons.search, color: foreground)
                  : Text(
                    waterStatus ? '关闭' : '开启',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: foreground,
                    ),
                  ),
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(strokeWidth: 4),
        ),
        Icon(icon, color: color, size: 30),
      ],
    );
  }
}

class HotWaterBalanceCard extends StatelessWidget {
  const HotWaterBalanceCard({
    super.key,
    required this.balance,
    required this.onTap,
  });

  final String balance;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: colorScheme.floatingSurface,
          border: Border.all(color: colorScheme.subtleBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: colorScheme.warning,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '校园卡余额: ¥$balance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              color: colorScheme.onSurfaceVariant,
              onPressed: () {
                onTap();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class WaterDeviceSelectionSheet extends StatelessWidget {
  const WaterDeviceSelectionSheet({
    super.key,
    required this.devices,
    required this.selectedIndex,
    required this.onManageDevices,
    required this.onSelectDevice,
  });

  final List<dynamic> devices;
  final int selectedIndex;
  final VoidCallback onManageDevices;
  final ValueChanged<int> onSelectDevice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return WaterBottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WaterSheetHandle(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '选择设备',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton.icon(
                  onPressed: onManageDevices,
                  icon: Icon(Icons.settings, color: colorScheme.warning),
                  label: Text(
                    '管理设备',
                    style: TextStyle(color: colorScheme.warning),
                  ),
                ),
              ],
            ),
          ),
          if (devices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: _EmptyDeviceState(message: '暂无可用设备，请先添加设备'),
            )
          else
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final Map<String, dynamic> device = Map<String, dynamic>.from(
                    devices[index] as Map,
                  );
                  final bool isSelected = selectedIndex == index;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    tileColor:
                        isSelected
                            ? colorScheme.warningContainerSoft
                            : colorScheme.surfaceContainer,
                    title: Text(
                      device['posname']?.toString() ?? '未知设备',
                      style: TextStyle(
                        fontSize: 20,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    trailing:
                        isSelected
                            ? Icon(
                              Ionicons.checkmark_circle,
                              color: colorScheme.warning,
                            )
                            : null,
                    onTap: () => onSelectDevice(index),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class WaterDeviceManagementSheet extends StatelessWidget {
  const WaterDeviceManagementSheet({
    super.key,
    required this.devices,
    required this.onAddDevice,
    required this.onDeleteDevice,
  });

  final List<dynamic> devices;
  final VoidCallback onAddDevice;
  final ValueChanged<int> onDeleteDevice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return WaterBottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WaterSheetHandle(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '设备管理',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton.icon(
                  onPressed: onAddDevice,
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: colorScheme.warning,
                  ),
                  label: Text(
                    '添加设备',
                    style: TextStyle(color: colorScheme.warning),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的设备',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                if (devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: _EmptyDeviceState(message: '暂无设备，请先添加设备'),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.3,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final Map<String, dynamic> device =
                            Map<String, dynamic>.from(devices[index] as Map);
                        final deviceName =
                            device['posname']?.toString() ?? '未知设备';
                        final deviceCode =
                            device['poscode']?.toString() ?? '未知设备号';
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          tileColor: colorScheme.surfaceContainer,
                          title: Text(
                            deviceName,
                            style: TextStyle(color: colorScheme.onSurface),
                          ),
                          subtitle: Text(
                            '设备号: $deviceCode',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: colorScheme.error,
                            ),
                            onPressed: () => onDeleteDevice(index),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class AddWaterDeviceSheet extends StatefulWidget {
  const AddWaterDeviceSheet({
    super.key,
    required this.onClose,
    required this.onSubmit,
  });

  final VoidCallback onClose;
  final Future<void> Function(String deviceCode) onSubmit;

  @override
  State<AddWaterDeviceSheet> createState() => _AddWaterDeviceSheetState();
}

class _AddWaterDeviceSheetState extends State<AddWaterDeviceSheet> {
  final TextEditingController _deviceCodeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _deviceCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onSubmit(_deviceCodeController.text.trim());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return WaterBottomSheetScaffold(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '添加新设备',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '请输入6位设备号码',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _deviceCodeController,
                  decoration: InputDecoration(
                    hintText: '输入6位设备号',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    prefixIcon: Icon(
                      Icons.confirmation_number_outlined,
                      color: colorScheme.warning,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: TextStyle(fontSize: 18, color: colorScheme.onSurface),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _handleSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.warning,
                      foregroundColor:
                          ThemeData.estimateBrightnessForColor(
                                    colorScheme.warning,
                                  ) ==
                                  Brightness.dark
                              ? Colors.white
                              : const Color(0xFF2D1B00),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isSubmitting
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text(
                              '添加设备',
                              style: TextStyle(fontSize: 18),
                            ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.warningContainerSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.warning.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.warning,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '温馨提示',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onWarningContainerSoft,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. 设备号通常位于设备正门的显示屏中',
                          style: TextStyle(
                            color: colorScheme.onWarningContainerSoft,
                          ),
                        ),
                        Text(
                          '2. 设备号为6位数字',
                          style: TextStyle(
                            color: colorScheme.onWarningContainerSoft,
                          ),
                        ),
                        Text(
                          '3. 如无法添加，请联系学校管理员',
                          style: TextStyle(
                            color: colorScheme.onWarningContainerSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WaterBottomSheetScaffold extends StatelessWidget {
  const WaterBottomSheetScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(15),
        topRight: Radius.circular(15),
      ),
      child: SafeArea(child: child),
    );
  }
}

class WaterSheetHandle extends StatelessWidget {
  const WaterSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _EmptyDeviceState extends StatelessWidget {
  const _EmptyDeviceState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        children: [
          Icon(Icons.hot_tub, size: 48, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class BubbleAnimation extends StatefulWidget {
  const BubbleAnimation({
    super.key,
    required this.isActive,
    this.color = Colors.blue,
  });

  final bool isActive;
  final Color color;

  @override
  State<BubbleAnimation> createState() => _BubbleAnimationState();
}

class _BubbleAnimationState extends State<BubbleAnimation> {
  final List<_BubbleData> _bubbles = <_BubbleData>[];
  final Random _random = Random();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(BubbleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startAnimation();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopAnimation();
    }
  }

  void _startAnimation() {
    _timer?.cancel();
    _bubbles.clear();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (_bubbles.length < 15) {
          _bubbles.add(
            _BubbleData(
              id: UniqueKey().toString(),
              color: widget.color,
              size: _random.nextDouble() * 20 + 5,
              position: Offset(
                _random.nextDouble() * MediaQuery.sizeOf(context).width,
                MediaQuery.sizeOf(context).height + 20,
              ),
              destination: Offset(
                _random.nextDouble() * MediaQuery.sizeOf(context).width,
                _random.nextDouble() * 200,
              ),
              duration: Duration(seconds: _random.nextInt(6) + 4),
            ),
          );
        }
        _bubbles.removeWhere((bubble) => bubble.isCompleted);
      });
    });
  }

  void _stopAnimation() {
    _timer?.cancel();
    if (!mounted) {
      return;
    }

    setState(() {
      _bubbles.clear();
    });
  }

  void _markBubbleCompleted(_BubbleData bubble) {
    if (!mounted) {
      return;
    }

    setState(() {
      bubble.isCompleted = true;
      _bubbles.removeWhere((item) => item.isCompleted);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final bubble in _bubbles)
            _AnimatedBubble(
              key: ValueKey(bubble.id),
              bubble: bubble,
              onCompleted: () => _markBubbleCompleted(bubble),
            ),
        ],
      ),
    );
  }
}

class _BubbleData {
  _BubbleData({
    required this.id,
    required this.color,
    required this.size,
    required this.position,
    required this.destination,
    required this.duration,
  });

  final String id;
  final Color color;
  final double size;
  final Offset position;
  final Offset destination;
  final Duration duration;
  bool isCompleted = false;
}

class _AnimatedBubble extends StatefulWidget {
  const _AnimatedBubble({
    super.key,
    required this.bubble,
    required this.onCompleted,
  });

  final _BubbleData bubble;
  final VoidCallback onCompleted;

  @override
  State<_AnimatedBubble> createState() => _AnimatedBubbleState();
}

class _AnimatedBubbleState extends State<_AnimatedBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _positionAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.bubble.duration,
    );
    _positionAnimation = Tween<Offset>(
      begin: widget.bubble.position,
      end: widget.bubble.destination,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward().whenComplete(widget.onCompleted);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: widget.bubble.size,
              height: widget.bubble.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.bubble.color.withAlpha(102),
                border: Border.all(
                  color: widget.bubble.color.withAlpha(153),
                  width: 1,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
