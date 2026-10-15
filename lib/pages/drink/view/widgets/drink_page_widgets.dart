import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../../../../core/ui/app_animated_container.dart';
import '../../../../core/ui/app_loading_indicator.dart';
import '../../../../core/ui/app_progress_indicator.dart';
import '../../../../core/ui/apple_glass.dart';
import '../../../../core/ui/color_scheme_ext.dart';
import '../../../../core/ui/scanner_line.dart';
import '../../core/drink_home_tokens.dart';

/// 页面结构锚点。widget 测试靠这些 key 取「实际绘制的表面与文字颜色」，
/// 改名或删掉会让验收断言取不到目标，不是可选装饰。
const drinkBackgroundKey = Key('drinkBackground');
const drinkStatusCardKey = Key('statusCard');
const drinkStatusIconChipKey = Key('statusIconChip');
const drinkPrimaryActionKey = Key('primaryAction');
const drinkLayoutToggleKey = Key('layoutToggle');
const drinkReorderToggleKey = Key('reorderToggle');
const drinkReorderHintKey = Key('reorderHint');
const drinkDeviceSectionKey = Key('deviceSection');

Key drinkDeviceTileKey(String id) => Key('deviceTile-$id');

/// 设备项右侧的备注编辑按钮容器：命中区基线就钉在这个 key 上。
Key drinkDeviceEditKey(String id) => Key('deviceEdit-$id');

/// 选中角标的底色容器。角标是选中态的第二语言，测试要能单独取到它的面，
/// 而 find.ancestor 在一串同类型容器里给不出「最内层」的稳定顺序。
Key drinkDeviceCheckMarkerKey(String id) => Key('deviceCheckMarker-$id');

class DrinkBackground extends StatelessWidget {
  const DrinkBackground({super.key, required this.drinkStatus});

  final bool drinkStatus;

  @override
  Widget build(BuildContext context) {
    final palette = DrinkHomePalette.of(context);
    // 空闲态是页面锚点，接水态在其上叠一层水色前景，两者都以本体色收尾。
    return AppAnimatedContainer(
      key: drinkBackgroundKey,
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(gradient: palette.idleBackground),
      foregroundDecoration:
          drinkStatus
              ? BoxDecoration(gradient: palette.activeBackground)
              : null,
    );
  }
}

class DrinkLoadingState extends StatelessWidget {
  const DrinkLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = DrinkHomePalette.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppLoadingIndicator(size: 32, color: palette.brandInk),
          const SizedBox(height: 16),
          Text(
            '正在同步设备信息',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '请稍候片刻',
            style: TextStyle(fontSize: 13, color: palette.inkSecondary),
          ),
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
    final palette = DrinkHomePalette.of(context);
    final bool useLiteEffects = AppGlassPerformanceScope.isLiteOf(context);
    final BorderRadius radius = BorderRadius.circular(DrinkHomeT.radiusCard);
    // 降层级靠字号与字重，不靠透明度：白色 α.85 压在强调面上只有 3.92:1。
    final Color titleColor = drinkStatus ? Colors.white : palette.ink;
    final Color subtleColor = drinkStatus ? Colors.white : palette.inkSecondary;

    return AppAnimatedContainer(
      key: drinkStatusCardKey,
      duration: const Duration(milliseconds: 320),
      width: double.infinity,
      padding: EdgeInsets.all(DrinkHomePalette.isCompact(context) ? 16 : 20),
      decoration: BoxDecoration(
        gradient: drinkStatus ? palette.accentFill : null,
        color: drinkStatus ? null : palette.card,
        borderRadius: radius,
        border: Border.all(
          color: drinkStatus ? Colors.transparent : palette.hairline,
        ),
        boxShadow: [
          BoxShadow(
            color:
                drinkStatus
                    ? DrinkHomeT.accentEnd.withValues(
                      alpha: useLiteEffects ? 0.20 : 0.30,
                    )
                    : palette.ink.withValues(
                      alpha: useLiteEffects ? 0.04 : 0.06,
                    ),
            blurRadius: useLiteEffects ? 12 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                key: drinkStatusIconChipKey,
                decoration: BoxDecoration(
                  color:
                      drinkStatus
                          ? Colors.white.withValues(alpha: 0.18)
                          : palette.tint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    drinkStatus ? Ionicons.water : Ionicons.water_outline,
                    // 图标是非文字元素，底线 3.0：tint 底上要用深一档的品牌墨。
                    color: drinkStatus ? Colors.white : palette.brandInk,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drinkStatus ? '正在接水中' : '准备就绪',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      drinkStatus ? '接完后点击结算' : '选择设备开始接水',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: subtleColor,
                      ),
                    ),
                  ],
                ),
              ),
              _DrinkInfoBadge(
                icon: Ionicons.hardware_chip_outline,
                label: '$deviceCount 台设备',
                onAccent: drinkStatus,
              ),
            ],
          ),
          if (deviceName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Ionicons.location_outline, size: 16, color: subtleColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    deviceName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (drinkStatus) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: AppLinearProgressIndicator(
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DrinkEmptyDeviceCard extends StatelessWidget {
  const DrinkEmptyDeviceCard({super.key, required this.onAddDevice});

  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    final palette = DrinkHomePalette.of(context);
    final bool compact = DrinkHomePalette.isCompact(context);

    // 外层可滚 + 居中：小屏或大字号下这张固定内容的卡顶不住时，
    // 让它能滚而不是把 Column 撑爆。
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(compact ? 20 : 28),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(DrinkHomeT.radiusCard),
            border: Border.all(color: palette.hairline, width: 1),
            boxShadow: [
              BoxShadow(
                color: palette.ink.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Icon(
                    Ionicons.scan_outline,
                    color: palette.brandInk,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '还没有可用设备',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '先扫码收藏宿舍饮水设备，后续就能直接开始用水。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: palette.inkSecondary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAddDevice,
                style: FilledButton.styleFrom(
                  backgroundColor: DrinkHomeT.accentStart,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Ionicons.scan_outline),
                label: const Text('添加设备'),
              ),
            ],
          ),
        ),
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
    final palette = DrinkHomePalette.of(context);

    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onManageDevices,
            icon: const Icon(Ionicons.settings_outline),
            label: const Text('管理设备'),
            style: FilledButton.styleFrom(
              backgroundColor: palette.tint,
              foregroundColor: palette.brandInk,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DrinkHomeT.radiusChip),
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
              backgroundColor: DrinkHomeT.accentStart,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DrinkHomeT.radiusChip),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 「我的设备」标题行：布局切换与排序入口。
class DrinkDeviceSectionHeader extends StatelessWidget {
  const DrinkDeviceSectionHeader({
    super.key,
    required this.isGrid,
    required this.isReordering,
    required this.onToggleLayout,
    required this.onToggleReorder,
  });

  final bool isGrid;
  final bool isReordering;
  final VoidCallback onToggleLayout;
  final VoidCallback onToggleReorder;

  @override
  Widget build(BuildContext context) {
    final palette = DrinkHomePalette.of(context);

    return Row(
      key: drinkDeviceSectionKey,
      children: [
        Expanded(
          child: Text(
            '我的设备',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
        ),
        IconButton(
          key: drinkLayoutToggleKey,
          tooltip: isGrid ? '单列布局' : '双列布局',
          // 排序模式下列表由 ReorderableListView 接管，此时不换布局。
          onPressed: isReordering ? null : onToggleLayout,
          icon: Icon(
            isGrid ? Ionicons.list_outline : Ionicons.grid_outline,
            size: 20,
            color: palette.neutralGlyph,
          ),
        ),
        IconButton(
          key: drinkReorderToggleKey,
          tooltip: isReordering ? '完成排序' : '调整顺序',
          onPressed: onToggleReorder,
          icon: Icon(
            isReordering ? Ionicons.checkmark : Ionicons.swap_vertical_outline,
            size: 20,
            color: isReordering ? palette.brandInk : palette.neutralGlyph,
          ),
        ),
      ],
    );
  }
}

/// 设备列表区：浏览态按布局渲染，排序态用可拖列表。
class DrinkDeviceList extends StatelessWidget {
  const DrinkDeviceList({
    super.key,
    required this.devices,
    required this.selectedIndex,
    required this.isGrid,
    required this.isReordering,
    required this.deviceKeyOf,
    required this.titleOf,
    required this.onSelect,
    required this.onEditNote,
    required this.onReorder,
  });

  final List<dynamic> devices;
  final int selectedIndex;
  final bool isGrid;
  final bool isReordering;
  final String Function(dynamic device) deviceKeyOf;
  final String Function(dynamic device) titleOf;
  final ValueChanged<int> onSelect;
  final void Function(dynamic device) onEditNote;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    if (isReordering) {
      return _DrinkReorderList(
        devices: devices,
        selectedIndex: selectedIndex,
        deviceKeyOf: deviceKeyOf,
        titleOf: titleOf,
        onReorder: onReorder,
      );
    }

    if (isGrid) {
      return GridView.builder(
        padding: const EdgeInsets.only(bottom: 8),
        // 内容不足一屏也要能下拉刷新，所以保留总是可滚的物理效果。
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.4,
        ),
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          final String id = deviceKeyOf(device);
          return _DrinkDeviceTile(
            tileKey: drinkDeviceTileKey(id),
            id: id,
            title: titleOf(device),
            isSelected: index == selectedIndex,
            isGrid: true,
            onTap: () => onSelect(index),
            onEditNote: () => onEditNote(device),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        final String id = deviceKeyOf(device);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _DrinkDeviceTile(
            tileKey: drinkDeviceTileKey(id),
            id: id,
            title: titleOf(device),
            isSelected: index == selectedIndex,
            onTap: () => onSelect(index),
            onEditNote: () => onEditNote(device),
          ),
        );
      },
    );
  }
}

class _DrinkDeviceTile extends StatelessWidget {
  const _DrinkDeviceTile({
    required this.tileKey,
    required this.id,
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.onEditNote,
    this.isGrid = false,
    this.showDragHandle = false,
  });

  final Key tileKey;
  final String id;
  final String title;
  final bool isSelected;
  final bool isGrid;
  final bool showDragHandle;
  final VoidCallback onTap;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context) {
    final palette = DrinkHomePalette.of(context);

    return GestureDetector(
      key: tileKey,
      onTap: onTap,
      onLongPress: onEditNote,
      child: Container(
        // vertical 11：命中面积只增不减，测试把 60.0（选中）/ 57.0（未选）
        // 钉成下限。Container 的装饰描边不参与布局，所以这道护栏比几何推导更严。
        padding:
            isGrid
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: _tileDecoration(palette),
        child: Row(
          children: [
            _tileGlyph(palette),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: isGrid ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isGrid ? 13 : 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: palette.ink,
                ),
              ),
            ),
            if (!showDragHandle && !isGrid && !isSelected) ...[
              const SizedBox(width: 8),
              GestureDetector(
                key: drinkDeviceEditKey(id),
                onTap: onEditNote,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // 静止条目本身就是 card 面，再铺 card 等于隐形，只剩一条描边。
                    color: palette.tint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.hairline, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Ionicons.create_outline,
                      size: 14,
                      color: palette.neutralGlyph,
                    ),
                  ),
                ),
              ),
            ],
            if (isSelected) ...[
              const SizedBox(width: 8),
              _DrinkCheckMarker(
                palette: palette,
                markerKey: drinkDeviceCheckMarkerKey(id),
                compact: isGrid,
              ),
            ],
            if (showDragHandle) ...[
              const SizedBox(width: 8),
              Icon(
                Ionicons.menu_outline,
                size: 20,
                color: palette.neutralGlyph,
              ),
            ],
          ],
        ),
      ),
    );
  }

  BoxDecoration _tileDecoration(DrinkHomePalette palette) {
    return BoxDecoration(
      // 浅色下选中不换填充，由描边 + 勾选 + 抬升两个通道表达；深色仍提亮一档。
      color: palette.tileFill(isSelected: isSelected),
      borderRadius: BorderRadius.circular(DrinkHomeT.radiusTile),
      border: Border.all(
        // 选中描边是非文字指示元素，底线 3.0。
        color: isSelected ? palette.brandInk : palette.hairline,
        width: isSelected ? 1.6 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color:
              isSelected
                  ? DrinkHomeT.accentStart.withValues(alpha: 0.22)
                  : palette.ink.withValues(alpha: 0.06),
          blurRadius: isSelected ? 14 : 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _tileGlyph(DrinkHomePalette palette) {
    final Color glyphColor =
        isSelected ? palette.brandInk : palette.neutralGlyph;
    if (isGrid) {
      return Icon(Ionicons.hardware_chip_outline, size: 18, color: glyphColor);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.tint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Ionicons.hardware_chip_outline,
          size: 20,
          color: glyphColor,
        ),
      ),
    );
  }
}

class _DrinkCheckMarker extends StatelessWidget {
  const _DrinkCheckMarker({
    required this.palette,
    required this.markerKey,
    required this.compact,
  });

  final DrinkHomePalette palette;
  final Key markerKey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Icon(
        Ionicons.checkmark_circle,
        size: 16,
        color: palette.markerFill,
      );
    }

    return DecoratedBox(
      key: markerKey,
      decoration: BoxDecoration(
        color: palette.markerFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(Ionicons.checkmark, size: 14, color: palette.markerInk),
      ),
    );
  }
}

class _DrinkReorderList extends StatelessWidget {
  const _DrinkReorderList({
    required this.devices,
    required this.selectedIndex,
    required this.deviceKeyOf,
    required this.titleOf,
    required this.onReorder,
  });

  final List<dynamic> devices;
  final int selectedIndex;
  final String Function(dynamic device) deviceKeyOf;
  final String Function(dynamic device) titleOf;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final palette = DrinkHomePalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          // 规格要求排序提示落在「和平常浏览不同的一块面」上：card 底 + hairline
          // 描边和静止条目长得一模一样，这里改成品牌色模式条。
          child: DecoratedBox(
            key: drinkReorderHintKey,
            decoration: BoxDecoration(
              gradient: palette.accentFill,
              borderRadius: BorderRadius.circular(DrinkHomeT.radiusChip),
              border: Border.all(color: palette.brandInk, width: 1.2),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                '拖动调整顺序',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            // 关掉默认整行长按手柄：长按整行是写备注的手势，两个手势不能抢同一块区域。
            buildDefaultDragHandles: false,
            itemCount: devices.length,
            onReorder: onReorder,
            itemBuilder: (context, index) {
              final device = devices[index];
              final String id = deviceKeyOf(device);
              return ReorderableDragStartListener(
                key: ValueKey('drinkReorder-$id'),
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _DrinkDeviceTile(
                    tileKey: drinkDeviceTileKey(id),
                    id: id,
                    title: titleOf(device),
                    isSelected: index == selectedIndex,
                    showDragHandle: true,
                    onTap: () {},
                    onEditNote: () {},
                  ),
                ),
              );
            },
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
    required this.onAccent,
  });

  final IconData icon;
  final String label;
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final palette = DrinkHomePalette.of(context);
    final Color foreground = onAccent ? Colors.white : palette.brandInk;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: onAccent ? Colors.white.withValues(alpha: 0.18) : palette.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 主操作按钮。
///
/// 渐变由外层 DecoratedBox 绘制，按钮本身留透明底：这样 FilledButton 的
/// onPressed == null 禁用语义、ripple、focus 和标签布局全部保留。
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
    final palette = DrinkHomePalette.of(context);
    final bool compact = DrinkHomePalette.isCompact(context);
    final BorderRadius radius = BorderRadius.circular(compact ? 22 : 26);
    final Color labelColor = enabled ? Colors.white : palette.disabledInk;

    final decoration =
        !enabled
            ? BoxDecoration(color: palette.disabled, borderRadius: radius)
            : drinkStatus
            ? BoxDecoration(
              color: DrinkHomeT.settle,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: DrinkHomeT.settle.withValues(alpha: 0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            )
            : BoxDecoration(
              gradient: palette.accentFill,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: DrinkHomeT.accentEnd.withValues(alpha: 0.32),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            );

    return DecoratedBox(
      key: drinkPrimaryActionKey,
      decoration: decoration,
      child: SizedBox(
        width: double.infinity,
        height: compact ? 56 : 64,
        child: FilledButton(
          onPressed: enabled ? onTap : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            // 不给 disabledBackgroundColor 的话，M3 默认会给禁用态铺一层
            // onSurface@0.12，正好盖掉外层的中性底与标签配色。
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            padding: EdgeInsets.zero,
            // 圆角必须与外层一致，否则 ripple 会按主题默认的 16 被裁掉一角。
            shape: RoundedRectangleBorder(borderRadius: radius),
          ).copyWith(
            // 强调面上按压波纹要用白色，主题默认的 onSurface 叠色在深色底上几乎是黑的。
            overlayColor: WidgetStatePropertyAll(
              Colors.white.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                drinkStatus ? Ionicons.stop_circle : Ionicons.play_circle,
                size: 26,
                color: labelColor,
              ),
              const SizedBox(width: 12),
              Text(
                drinkStatus ? '结算' : '开始用水',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ],
          ),
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
    final palette = DrinkHomePalette.of(context);

    return Material(
      color: palette.card,
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
    final palette = DrinkHomePalette.of(context);

    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: palette.brandInk,
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
    final palette = DrinkHomePalette.of(context);

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
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: palette.inkSecondary),
                ),
              ],
            ),
          ),
          if (badge != null)
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.tint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.brandInk,
                  ),
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
    final palette = DrinkHomePalette.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.tint,
        borderRadius: BorderRadius.circular(DrinkHomeT.radiusCard),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Icon(icon, color: palette.brandInk, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: palette.inkSecondary,
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
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final palette = DrinkHomePalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(DrinkHomeT.radiusTile),
          border: Border.all(color: palette.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Ionicons.hardware_chip_outline,
                    color: palette.neutralGlyph,
                  ),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class DrinkDeviceManagementSheet extends StatelessWidget {
  const DrinkDeviceManagementSheet({
    super.key,
    required this.devices,
    required this.deviceCount,
    required this.formatDeviceName,
    required this.onClose,
    required this.onAddDevice,
    required this.onDeleteDevice,
  });

  final List<dynamic> devices;
  final int deviceCount;
  final String Function(String name) formatDeviceName;
  final VoidCallback onClose;
  final VoidCallback onAddDevice;
  final ValueChanged<int> onDeleteDevice;

  @override
  Widget build(BuildContext context) {
    final palette = DrinkHomePalette.of(context);
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.42;
    final listHeight = min(maxListHeight, deviceCount * 92.0);

    return DrinkBottomSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DrinkSheetHandle(),
          _DrinkSheetHeader(
            title: '设备管理',
            subtitle: '查看已收藏设备，删除不再使用的设备',
            badge: '$deviceCount 台',
          ),
          if (deviceCount == 0)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _DrinkSheetEmptyCard(
                icon: Ionicons.water_outline,
                title: '还没有收藏设备',
                subtitle: '扫码添加宿舍设备后，后续就能直接在这里管理。',
              ),
            )
          else
            SizedBox(
              height: listHeight,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: false,
                itemCount: deviceCount,
                itemBuilder: (context, index) {
                  final device = devices[index] as Map;
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
                        color: palette.destructive,
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
                    style: FilledButton.styleFrom(
                      backgroundColor: DrinkHomeT.accentStart,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Ionicons.add_circle_outline),
                    label: const Text('添加设备'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onClose,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.brandInk,
                  ),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 设备备注编辑器。
///
/// 控制器由这个 State 自己持有：对话框路由退场时还在重建最后一帧，
/// 由调用方在 `pop` 之后立刻 dispose 会撞上「controller used after dispose」。
class DrinkNoteEditorDialog extends StatefulWidget {
  const DrinkNoteEditorDialog({
    super.key,
    required this.title,
    required this.initialNote,
  });

  final String title;
  final String initialNote;

  static const int noteMaxLength = 20;

  @override
  State<DrinkNoteEditorDialog> createState() => _DrinkNoteEditorDialogState();
}

class _DrinkNoteEditorDialogState extends State<DrinkNoteEditorDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialNote,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = DrinkHomePalette.of(context);

    return AlertDialog(
      backgroundColor: palette.card,
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _controller,
        maxLength: DrinkNoteEditorDialog.noteMaxLength,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '例如：三楼东侧',
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('保存'),
        ),
      ],
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
  final ValueNotifier<bool> _isFlashOnNotifier = ValueNotifier<bool>(false);
  bool _isTogglingFlash = false;
  bool _isScanning = true;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _controller?.dispose();
    _isFlashOnNotifier.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    _scanSubscription = controller.scannedDataStream.listen((scanData) {
      final String? code = scanData.code;
      if (code == null || !mounted || !_isScanning) {
        return;
      }

      _isScanning = false;
      _scanSubscription?.cancel();
      controller.pauseCamera();
      Navigator.of(context).pop(code);
    });
  }

  Future<void> _toggleFlash() async {
    if (_isTogglingFlash) {
      return;
    }

    final controller = _controller;
    if (controller == null) {
      return;
    }

    _isTogglingFlash = true;
    try {
      await controller.toggleFlash();
      final current = await controller.getFlashStatus() ?? false;
      if (!mounted || _isFlashOnNotifier.value == current) {
        return;
      }

      _isFlashOnNotifier.value = current;
    } finally {
      _isTogglingFlash = false;
    }
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
                      fontSize: 17,
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
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: _isFlashOnNotifier,
                          builder: (context, isFlashOn, _) {
                            return _DrinkScannerActionButton(
                              icon:
                                  isFlashOn
                                      ? Ionicons.flash
                                      : Ionicons.flash_outline,
                              label: isFlashOn ? '关闭闪光灯' : '打开闪光灯',
                              onTap: _toggleFlash,
                            );
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
                  child: AppScannerLine(color: colorScheme.primary),
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
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
