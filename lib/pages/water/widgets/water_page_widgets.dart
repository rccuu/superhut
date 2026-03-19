import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class WaterBackground extends StatelessWidget {
  const WaterBackground({super.key, required this.waterStatus});

  final bool waterStatus;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.orange.withAlpha(60),
            Colors.orange.withAlpha(70),
            Colors.transparent,
          ],
          stops: waterStatus ? [0.0, 0.8, 1.0] : [0.0, 0.2, 1.0],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Text(
        waterStatus ? '正在使用热水' : '未开启热水',
        style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('当前设备'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    deviceName ?? '未选择设备',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                ],
              ),
            ],
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
    final isDisabled = isLoading || !deviceCheckComplete;
    final shadowColor =
        isDisabled
            ? Colors.grey.withAlpha(102)
            : waterStatus
            ? Colors.red.withAlpha(153)
            : Colors.orange.withAlpha(102);

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
            colors:
                isDisabled
                    ? [Colors.grey.shade300, Colors.grey.shade400]
                    : waterStatus
                    ? [Colors.orange.shade300, Colors.red.shade400]
                    : [Colors.orange.shade200, Colors.orange.shade400],
          ),
          boxShadow: [
            BoxShadow(color: shadowColor, blurRadius: 15, spreadRadius: 5),
          ],
        ),
        child: Center(
          child:
              isLoading
                  ? _ProgressIndicator(
                    icon: waterStatus ? Icons.stop : Icons.play_arrow,
                  )
                  : !deviceCheckComplete
                  ? const _ProgressIndicator(icon: Icons.search)
                  : Text(
                    waterStatus ? '关闭' : '开启',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
        ),
      ),
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  const _ProgressIndicator({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 4,
          ),
        ),
        Icon(icon, color: Colors.white, size: 30),
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
    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withAlpha(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '校园卡余额: ¥$balance',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              color: Colors.grey,
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
                const Text(
                  '选择设备',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: onManageDevices,
                  icon: const Icon(Icons.settings, color: Colors.orange),
                  label: const Text(
                    '管理设备',
                    style: TextStyle(color: Colors.orange),
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
                  return ListTile(
                    title: Text(
                      device['posname']?.toString() ?? '未知设备',
                      style: const TextStyle(fontSize: 20),
                    ),
                    trailing:
                        selectedIndex == index
                            ? const Icon(
                              Ionicons.checkmark_circle,
                              color: Colors.orange,
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
                const Text(
                  '设备管理',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: onAddDevice,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.orange,
                  ),
                  label: const Text(
                    '添加设备',
                    style: TextStyle(color: Colors.orange),
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
                const Text(
                  '我的设备',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          title: Text(deviceName),
                          subtitle: Text('设备号: $deviceCode'),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
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
                    const Text(
                      '添加新设备',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  '请输入6位设备号码',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _deviceCodeController,
                  decoration: InputDecoration(
                    hintText: '输入6位设备号',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withAlpha(26),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.confirmation_number_outlined,
                      color: Colors.orange,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isSubmitting
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
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
                      color: Colors.white.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              '温馨提示',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text('1. 设备号通常位于设备正门的显示屏中'),
                        Text('2. 设备号为6位数字'),
                        Text('3. 如无法添加，请联系学校管理员'),
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
    );
  }
}

class _EmptyDeviceState extends StatelessWidget {
  const _EmptyDeviceState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.hot_tub, size: 48, color: Colors.grey),
          const SizedBox(height: 10),
          Text(message),
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
