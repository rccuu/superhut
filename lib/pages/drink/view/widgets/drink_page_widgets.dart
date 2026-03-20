import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class DrinkBackground extends StatelessWidget {
  const DrinkBackground({super.key, required this.drinkStatus});

  final bool drinkStatus;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.blue.withAlpha(60),
            Colors.blue.withAlpha(70),
            Colors.transparent,
          ],
          stops: drinkStatus ? [0.0, 0.8, 1.0] : [0.0, 0.2, 1.0],
        ),
      ),
    );
  }
}

class DrinkStatusHeader extends StatelessWidget {
  const DrinkStatusHeader({super.key, required this.drinkStatus});

  final bool drinkStatus;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Text(
        drinkStatus ? '正在接水中' : '未开启接水',
        style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class DrinkCurrentDeviceCard extends StatelessWidget {
  const DrinkCurrentDeviceCard({
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
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DrinkActionButton extends StatelessWidget {
  const DrinkActionButton({
    super.key,
    required this.drinkStatus,
    required this.onTap,
  });

  final bool drinkStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.primary,
          ),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(vertical: 15),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        child: Text(
          drinkStatus ? '结算' : '开启用水',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class DrinkMoreFunctionsButton extends StatelessWidget {
  const DrinkMoreFunctionsButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextButton(
      onPressed: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('展开更多功能', style: TextStyle(color: colorScheme.onSurfaceVariant)),
          Icon(Icons.keyboard_arrow_right, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class DrinkBottomSheetScaffold extends StatelessWidget {
  const DrinkBottomSheetScaffold({super.key, required this.child});

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

class DrinkSheetHandle extends StatelessWidget {
  const DrinkSheetHandle({super.key});

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

class DrinkDeviceSelectionSheet extends StatelessWidget {
  const DrinkDeviceSelectionSheet({
    super.key,
    required this.devices,
    required this.selectedIndex,
    required this.formatDeviceName,
    required this.onSelectDevice,
  });

  final List<dynamic> devices;
  final int selectedIndex;
  final String Function(String name) formatDeviceName;
  final ValueChanged<int> onSelectDevice;

  @override
  Widget build(BuildContext context) {
    return DrinkBottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DrinkSheetHandle(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '选择设备',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (devices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: _DrinkEmptyState(
                icon: Icons.device_unknown,
                message: '暂无可用设备，请先添加设备',
              ),
            )
          else
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final Map<String, dynamic> device = Map<String, dynamic>.from(
                    devices[index] as Map,
                  );
                  final String deviceName = formatDeviceName(
                    device['name']?.toString() ?? '未知设备',
                  );
                  return ListTile(
                    title: Text(
                      deviceName,
                      style: const TextStyle(fontSize: 20),
                    ),
                    trailing:
                        selectedIndex == index
                            ? Icon(
                              Ionicons.checkmark_circle,
                              color: Theme.of(context).primaryColor,
                            )
                            : null,
                    onTap: () => onSelectDevice(index),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DrinkMoreFunctionsSheet extends StatelessWidget {
  const DrinkMoreFunctionsSheet({
    super.key,
    required this.onManageDevices,
    required this.onAddDevice,
  });

  final VoidCallback onManageDevices;
  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    return DrinkBottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DrinkSheetHandle(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '更多功能',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Ionicons.grid_outline, color: Colors.blue),
            title: const Text('设备管理'),
            onTap: onManageDevices,
          ),
          ListTile(
            leading: const Icon(
              Ionicons.add_circle_outline,
              color: Colors.blue,
            ),
            title: const Text('添加设备'),
            onTap: onAddDevice,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class DrinkDeviceManagementSheet extends StatelessWidget {
  const DrinkDeviceManagementSheet({
    super.key,
    required this.devices,
    required this.formatDeviceName,
    required this.onClose,
    required this.onDeleteDevice,
  });

  final List<dynamic> devices;
  final String Function(String name) formatDeviceName;
  final VoidCallback onClose;
  final ValueChanged<int> onDeleteDevice;

  @override
  Widget build(BuildContext context) {
    return DrinkBottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DrinkSheetHandle(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '设备管理',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.4,
            child:
                devices.isEmpty
                    ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: _DrinkEmptyState(
                        icon: Ionicons.water_outline,
                        message: '暂无收藏设备，请先添加设备',
                      ),
                    )
                    : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final Map<String, dynamic> device =
                            Map<String, dynamic>.from(devices[index] as Map);
                        final String deviceName = formatDeviceName(
                          device['name']?.toString() ?? '未知设备',
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Card(
                            elevation: 0,
                            color:
                                Theme.of(context).colorScheme.surfaceContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              title: Text(
                                deviceName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                'ID: ${device['id']?.toString() ?? ''}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Ionicons.remove_circle_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => onDeleteDevice(index),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onClose, child: const Text('确认')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DrinkAddDeviceOptionsSheet extends StatelessWidget {
  const DrinkAddDeviceOptionsSheet({
    super.key,
    required this.onScan,
    required this.onCancel,
  });

  final VoidCallback onScan;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return DrinkBottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DrinkSheetHandle(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '添加设备',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Ionicons.information_circle_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '扫描设备上的二维码，添加到您的设备列表',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: onScan,
                  icon: const Icon(Ionicons.scan_outline, size: 24),
                  label: const Text('扫描设备二维码', style: TextStyle(fontSize: 16)),
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onCancel, child: const Text('取消')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DrinkQrCodeScannerPage extends StatefulWidget {
  const DrinkQrCodeScannerPage({super.key});

  @override
  State<DrinkQrCodeScannerPage> createState() => _DrinkQrCodeScannerPageState();
}

class _DrinkQrCodeScannerPageState extends State<DrinkQrCodeScannerPage> {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  final double _scanArea = 300;
  QRViewController? _controller;
  StreamSubscription<Barcode>? _scanSubscription;
  bool _isFlashOn = false;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    _scanSubscription = controller.scannedDataStream.listen((scanData) {
      final String? code = scanData.code;
      if (code == null || !mounted) {
        return;
      }

      _scanSubscription?.cancel();
      controller.pauseCamera();
      Navigator.of(context).pop(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描设备二维码', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          QRView(
            key: _qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.blue,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: _scanArea,
              overlayColor: const Color.fromRGBO(0, 0, 0, 0.7),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Ionicons.information_circle_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '将二维码放入框内，即可自动扫描',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isFlashOn = !_isFlashOn;
                    });
                    _controller?.toggleFlash();
                  },
                  icon: Icon(
                    _isFlashOn
                        ? Ionicons.flashlight
                        : Ionicons.flashlight_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                  label: Text(
                    _isFlashOn ? '关闭闪光灯' : '打开闪光灯',
                    style: const TextStyle(color: Colors.white),
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

class DrinkBubbleAnimation extends StatefulWidget {
  const DrinkBubbleAnimation({super.key, required this.isActive});

  final bool isActive;

  @override
  State<DrinkBubbleAnimation> createState() => _DrinkBubbleAnimationState();
}

class _DrinkBubbleAnimationState extends State<DrinkBubbleAnimation> {
  final List<_DrinkBubbleData> _bubbles = <_DrinkBubbleData>[];
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
  void didUpdateWidget(DrinkBubbleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  void _startAnimation() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) {
        return;
      }

      setState(() {
        if (_bubbles.length < 60) {
          _bubbles.add(
            _DrinkBubbleData(
              id: UniqueKey().toString(),
              x: _random.nextDouble() * MediaQuery.sizeOf(context).width,
              size: _random.nextDouble() * 40 + 15,
              speed: _random.nextDouble() * 1.5 + 0.8,
              horizontalDrift: _random.nextDouble() * 40 - 20,
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

  void _markCompleted(_DrinkBubbleData bubble) {
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
            _AnimatedDrinkBubble(
              key: ValueKey(bubble.id),
              bubble: bubble,
              onComplete: () => _markCompleted(bubble),
            ),
        ],
      ),
    );
  }
}

class _DrinkBubbleData {
  _DrinkBubbleData({
    required this.id,
    required this.x,
    required this.size,
    required this.speed,
    required this.horizontalDrift,
  });

  final String id;
  final double x;
  final double size;
  final double speed;
  final double horizontalDrift;
  bool isCompleted = false;
}

class _AnimatedDrinkBubble extends StatefulWidget {
  const _AnimatedDrinkBubble({
    super.key,
    required this.bubble,
    required this.onComplete,
  });

  final _DrinkBubbleData bubble;
  final VoidCallback onComplete;

  @override
  State<_AnimatedDrinkBubble> createState() => _AnimatedDrinkBubbleState();
}

class _AnimatedDrinkBubbleState extends State<_AnimatedDrinkBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _yAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _horizontalAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(seconds: (4 / widget.bubble.speed).round()),
      vsync: this,
    );
    _yAnimation = Tween<double>(
      begin: 0,
      end: 1000,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _horizontalAnimation = Tween<double>(
      begin: 0,
      end: widget.bubble.horizontalDrift,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward().whenComplete(widget.onComplete);
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
          left: widget.bubble.x + _horizontalAnimation.value,
          bottom: _yAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: widget.bubble.size,
              height: widget.bubble.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.withAlpha(60),
                    Colors.blue.withAlpha(120),
                  ],
                ),
                border: Border.all(color: Colors.blue.withAlpha(80), width: 1),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DrinkEmptyState extends StatelessWidget {
  const _DrinkEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 10),
          Text(message),
        ],
      ),
    );
  }
}
