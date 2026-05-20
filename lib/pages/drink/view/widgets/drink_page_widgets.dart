import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../../../../core/ui/color_scheme_ext.dart';

class DrinkBackground extends StatelessWidget {
  const DrinkBackground({super.key, required this.drinkStatus});

  final bool drinkStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color accent = colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: drinkStatus ? 0.20 : 0.12),
            accent.withValues(alpha: drinkStatus ? 0.10 : 0.04),
            colorScheme.surface,
          ],
          stops: drinkStatus ? const [0.0, 0.45, 1.0] : const [0.0, 0.18, 1.0],
        ),
      ),
    );
  }
}

class DrinkLoadingState extends StatelessWidget {
  const DrinkLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            '正在同步设备信息',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text('请稍候片刻', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class DrinkStatusHeader extends StatelessWidget {
  const DrinkStatusHeader({
    super.key,
    required this.drinkStatus,
    required this.deviceCount,
    required this.deviceName,
  });

  final bool drinkStatus;
  final int deviceCount;
  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = colorScheme.isDarkMode;
    final Color restingCardTop =
        isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.96)
            : const Color(0xFFFFFFFF);
    final Color restingCardBottom =
        isDark
            ? colorScheme.primaryContainer.withValues(alpha: 0.52)
            : const Color(0xFFF2F8FF);
    final Color restingText = colorScheme.onSurface;
    final Color restingSubtleText = colorScheme.onSurfaceVariant;
    final Color emphasisColor =
        drinkStatus ? colorScheme.onPrimary : restingText;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              drinkStatus
                  ? [colorScheme.primary, colorScheme.primaryContainer]
                  : [restingCardTop, restingCardBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              drinkStatus
                  ? colorScheme.onPrimary.withValues(alpha: 0.14)
                  : colorScheme.primary.withValues(alpha: isDark ? 0.28 : 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color:
                drinkStatus
                    ? colorScheme.primary.withValues(alpha: 0.24)
                    : colorScheme.primary.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                      drinkStatus
                          ? colorScheme.onPrimary.withValues(alpha: 0.14)
                          : colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  drinkStatus ? Ionicons.water : Ionicons.water_outline,
                  color:
                      drinkStatus ? colorScheme.onPrimary : colorScheme.primary,
                  size: 24,
                ),
              ),
              const Spacer(),
              _DrinkInfoBadge(
                icon: Ionicons.hardware_chip_outline,
                label: '$deviceCount 台设备',
                highlight: drinkStatus,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            drinkStatus ? '正在接水中' : '准备就绪',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: emphasisColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            drinkStatus ? '水流已开启，结束后记得结算' : '先选择设备，再开始本次用水',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color:
                  drinkStatus
                      ? colorScheme.onPrimary.withValues(alpha: 0.84)
                      : restingSubtleText,
            ),
          ),
          if (deviceName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Ionicons.location_outline,
                  size: 16,
                  color:
                      drinkStatus
                          ? colorScheme.onPrimary.withValues(alpha: 0.82)
                          : restingSubtleText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    deviceName!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: drinkStatus ? colorScheme.onPrimary : restingText,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (drinkStatus) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 6,
                backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.22),
                valueColor: AlwaysStoppedAnimation<Color>(
                  colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DrinkCurrentDeviceCard extends StatelessWidget {
  const DrinkCurrentDeviceCard({
    super.key,
    required this.deviceName,
    required this.deviceCount,
    required this.onTap,
  });

  final String deviceName;
  final int deviceCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDark = colorScheme.isDarkMode;
    final borderRadius = BorderRadius.circular(22);
    final Color cardTop =
        isDark
            ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.96)
            : const Color(0xFFFFFFFF);
    final Color cardBottom =
        isDark
            ? colorScheme.primaryContainer.withValues(alpha: 0.44)
            : const Color(0xFFF3F9FF);
    final Color cardText = colorScheme.onSurface;
    final Color cardSubtleText = colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardTop, cardBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.26 : 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08),
            blurRadius: 20,
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
                  Row(
                    children: [
                      Text(
                        '当前设备',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cardText,
                        ),
                      ),
                      const Spacer(),
                      _DrinkInfoBadge(
                        icon: Ionicons.layers_outline,
                        label: '$deviceCount 台已收藏',
                        highlight: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Ionicons.water_outline,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deviceName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: cardText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '点击切换设备或查看全部收藏设备',
                              style: TextStyle(
                                fontSize: 13,
                                color: cardSubtleText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 18,
                        color: cardSubtleText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DrinkEmptyDeviceCard extends StatelessWidget {
  const DrinkEmptyDeviceCard({super.key, required this.onAddDevice});

  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Ionicons.scan_outline,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '还没有可用设备',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '先扫码收藏宿舍饮水设备，后续就能直接开始用水。',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAddDevice,
            icon: const Icon(Ionicons.scan_outline),
            label: const Text('添加设备'),
          ),
        ],
      ),
    );
  }
}

class DrinkQuickActions extends StatelessWidget {
  const DrinkQuickActions({
    super.key,
    required this.onManageDevices,
    required this.onAddDevice,
  });

  final VoidCallback onManageDevices;
  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color manageBackground = colorScheme.primary.withValues(alpha: 0.14);
    final Color addBackground = colorScheme.primary.withValues(alpha: 0.96);

    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onManageDevices,
            icon: const Icon(Ionicons.settings_outline),
            label: const Text('管理设备'),
            style: FilledButton.styleFrom(
              backgroundColor: manageBackground,
              foregroundColor: colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onAddDevice,
            icon: const Icon(Ionicons.add_circle_outline),
            label: const Text('添加设备'),
            style: FilledButton.styleFrom(
              backgroundColor: addBackground,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DrinkInfoBadge extends StatelessWidget {
  const _DrinkInfoBadge({
    required this.icon,
    required this.label,
    required this.highlight,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:
            highlight
                ? colorScheme.onPrimary.withValues(alpha: 0.16)
                : colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight ? colorScheme.onPrimary : colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlight ? colorScheme.onPrimary : colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class DrinkActionButton extends StatelessWidget {
  const DrinkActionButton({
    super.key,
    required this.drinkStatus,
    required this.enabled,
    required this.onTap,
  });

  final bool drinkStatus;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(
          drinkStatus ? Ionicons.checkmark_circle : Ionicons.water_outline,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          disabledForegroundColor: colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        label: Text(
          drinkStatus ? '结束并结算' : '开始用水',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
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
      clipBehavior: Clip.antiAlias,
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

class _DrinkSheetHeader extends StatelessWidget {
  const _DrinkSheetHeader({
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrinkSheetEmptyCard extends StatelessWidget {
  const _DrinkSheetEmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrinkSheetDeviceCard extends StatelessWidget {
  const _DrinkSheetDeviceCard({
    required this.title,
    required this.subtitle,
    this.selected = false,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        clipBehavior: Clip.antiAlias,
        color:
            selected
                ? colorScheme.primary.withValues(alpha: 0.10)
                : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    selected
                        ? colorScheme.primary.withValues(alpha: 0.40)
                        : colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? colorScheme.primary.withValues(alpha: 0.16)
                            : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Ionicons.hardware_chip_outline,
                    color:
                        selected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                trailing ??
                    Icon(
                      selected
                          ? Ionicons.checkmark_circle
                          : Ionicons.chevron_forward,
                      color:
                          selected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                    ),
              ],
            ),
          ),
        ),
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
          _DrinkSheetHeader(
            title: '选择设备',
            subtitle: '选择本次要使用的饮水设备',
            badge: '${devices.length} 台',
          ),
          if (devices.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _DrinkSheetEmptyCard(
                icon: Icons.device_unknown,
                title: '暂无可用设备',
                subtitle: '先添加设备，之后就可以在这里快速切换。',
              ),
            )
          else
            ConstrainedBox(
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
                  final bool isSelected = selectedIndex == index;

                  return _DrinkSheetDeviceCard(
                    title: deviceName,
                    subtitle: 'ID: ${device['id']?.toString() ?? ''}',
                    selected: isSelected,
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

class DrinkDeviceManagementSheet extends StatelessWidget {
  const DrinkDeviceManagementSheet({
    super.key,
    required this.devices,
    required this.formatDeviceName,
    required this.onClose,
    required this.onAddDevice,
    required this.onDeleteDevice,
  });

  final List<dynamic> devices;
  final String Function(String name) formatDeviceName;
  final VoidCallback onClose;
  final VoidCallback onAddDevice;
  final ValueChanged<int> onDeleteDevice;

  @override
  Widget build(BuildContext context) {
    return DrinkBottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DrinkSheetHandle(),
          _DrinkSheetHeader(
            title: '设备管理',
            subtitle: '查看已收藏设备，删除不再使用的设备',
            badge: '${devices.length} 台',
          ),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.42,
            child:
                devices.isEmpty
                    ? const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _DrinkSheetEmptyCard(
                        icon: Ionicons.water_outline,
                        title: '还没有收藏设备',
                        subtitle: '扫码添加宿舍设备后，后续就能直接在这里管理。',
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
                        return _DrinkSheetDeviceCard(
                          title: deviceName,
                          subtitle: 'ID: ${device['id']?.toString() ?? ''}',
                          trailing: IconButton(
                            tooltip: '删除设备',
                            icon: Icon(
                              Ionicons.trash_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            onPressed: () => onDeleteDevice(index),
                          ),
                        );
                      },
                    ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAddDevice,
                    icon: const Icon(Ionicons.add_circle_outline),
                    label: const Text('添加设备'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(onPressed: onClose, child: const Text('关闭')),
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
  QRViewController? _controller;
  StreamSubscription<Barcode>? _scanSubscription;
  bool _isFlashOn = false;
  bool _isScanning = true;

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
      if (code == null || !mounted || !_isScanning) {
        return;
      }

      setState(() {
        _isScanning = false;
      });
      _scanSubscription?.cancel();
      controller.pauseCamera();
      Navigator.of(context).pop(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double cutOutSize = MediaQuery.sizeOf(context).width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          QRView(
            key: _qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: colorScheme.primary,
              borderRadius: 16,
              borderLength: 32,
              borderWidth: 4,
              cutOutSize: cutOutSize,
              overlayColor: colorScheme.overlayScrimStrong,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Ionicons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const Text(
                    '扫描设备二维码',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, colorScheme.overlayScrimStrong],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Ionicons.information_circle_outline,
                            color: Colors.white.withValues(alpha: 0.92),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '将设备二维码放入框内自动扫描',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DrinkScannerActionButton(
                          icon:
                              _isFlashOn
                                  ? Ionicons.flash
                                  : Ionicons.flash_outline,
                          label: _isFlashOn ? '关闭闪光灯' : '打开闪光灯',
                          onTap: () {
                            setState(() {
                              _isFlashOn = !_isFlashOn;
                            });
                            _controller?.toggleFlash();
                          },
                        ),
                        const SizedBox(width: 32),
                        _DrinkScannerActionButton(
                          icon: Ionicons.camera_reverse_outline,
                          label: '切换摄像头',
                          onTap: () {
                            _controller?.flipCamera();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isScanning)
            Positioned.fill(
              child: Center(
                child: SizedBox(
                  width: cutOutSize,
                  height: cutOutSize,
                  child: _DrinkScannerLine(color: colorScheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrinkScannerActionButton extends StatelessWidget {
  const _DrinkScannerActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrinkScannerLine extends StatefulWidget {
  const _DrinkScannerLine({required this.color});

  final Color color;

  @override
  State<_DrinkScannerLine> createState() => _DrinkScannerLineState();
}

class _DrinkScannerLineState extends State<_DrinkScannerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _DrinkScannerLinePainter(
            progress: _animation.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _DrinkScannerLinePainter extends CustomPainter {
  const _DrinkScannerLinePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              color.withValues(alpha: 0.78),
              color,
              color.withValues(alpha: 0.78),
              Colors.transparent,
            ],
            stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, size.width, 4));

    final double y = size.height * progress;
    canvas.drawRect(Rect.fromLTWH(0, y, size.width, 3), paint);
  }

  @override
  bool shouldRepaint(covariant _DrinkScannerLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class DrinkBubbleAnimation extends StatefulWidget {
  const DrinkBubbleAnimation({
    super.key,
    required this.isActive,
    required this.color,
  });

  final bool isActive;
  final Color color;

  @override
  State<DrinkBubbleAnimation> createState() => _DrinkBubbleAnimationState();
}

class _DrinkBubbleAnimationState extends State<DrinkBubbleAnimation>
    with SingleTickerProviderStateMixin {
  static const List<_DrinkBubbleSpec> _bubbleSpecs = [
    _DrinkBubbleSpec(xFactor: 0.08, size: 24, speed: 0.54, drift: 18, phase: 0),
    _DrinkBubbleSpec(
      xFactor: 0.18,
      size: 34,
      speed: 0.48,
      drift: -22,
      phase: 0.18,
    ),
    _DrinkBubbleSpec(
      xFactor: 0.31,
      size: 18,
      speed: 0.62,
      drift: 12,
      phase: 0.36,
    ),
    _DrinkBubbleSpec(
      xFactor: 0.44,
      size: 30,
      speed: 0.42,
      drift: -16,
      phase: 0.52,
    ),
    _DrinkBubbleSpec(
      xFactor: 0.58,
      size: 22,
      speed: 0.58,
      drift: 20,
      phase: 0.70,
    ),
    _DrinkBubbleSpec(
      xFactor: 0.72,
      size: 38,
      speed: 0.38,
      drift: -14,
      phase: 0.10,
    ),
    _DrinkBubbleSpec(
      xFactor: 0.86,
      size: 26,
      speed: 0.50,
      drift: 16,
      phase: 0.82,
    ),
    _DrinkBubbleSpec(
      xFactor: 0.95,
      size: 16,
      speed: 0.66,
      drift: -10,
      phase: 0.44,
    ),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(DrinkBubbleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              isComplex: true,
              willChange: true,
              painter: _DrinkBubblePainter(
                progress: _controller.value,
                color: widget.color,
                bubbles: _bubbleSpecs,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DrinkBubbleSpec {
  const _DrinkBubbleSpec({
    required this.xFactor,
    required this.size,
    required this.speed,
    required this.drift,
    required this.phase,
  });

  final double xFactor;
  final double size;
  final double speed;
  final double drift;
  final double phase;
}

class _DrinkBubblePainter extends CustomPainter {
  const _DrinkBubblePainter({
    required this.progress,
    required this.color,
    required this.bubbles,
  });

  final double progress;
  final Color color;
  final List<_DrinkBubbleSpec> bubbles;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final travel = size.height + 140;

    for (final bubble in bubbles) {
      final cycle = (progress * bubble.speed + bubble.phase) % 1.0;
      final fadeIn = (cycle / 0.14).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - cycle) / 0.26).clamp(0.0, 1.0);
      final opacity = fadeIn < fadeOut ? fadeIn : fadeOut;
      if (opacity <= 0.01) {
        continue;
      }

      final wave = sin((cycle + bubble.phase) * pi * 2);
      final x = size.width * bubble.xFactor + wave * bubble.drift;
      final y = size.height + bubble.size - cycle * travel;
      final radius = bubble.size / 2;
      final center = Offset(x, y);

      fillPaint.color = color.withValues(alpha: opacity * 0.22);
      strokePaint.color = color.withValues(alpha: opacity * 0.34);
      canvas.drawCircle(center, radius, fillPaint);
      canvas.drawCircle(center, radius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DrinkBubblePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.bubbles != bubbles;
  }
}
