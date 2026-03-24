import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

import '../../core/ui/apple_glass.dart';
import '../../core/ui/color_scheme_ext.dart';
import '../../utils/roomapi.dart';
import 'building_bridge.dart';

const List<_BigLessonBlock> _bigLessonBlocks = [
  _BigLessonBlock(
    index: 1,
    startLesson: 1,
    endLesson: 2,
    timeLabel: '08:00 - 09:40',
    startMinutes: 8 * 60,
    endMinutes: 9 * 60 + 40,
  ),
  _BigLessonBlock(
    index: 2,
    startLesson: 3,
    endLesson: 4,
    timeLabel: '10:00 - 11:40',
    startMinutes: 10 * 60,
    endMinutes: 11 * 60 + 40,
  ),
  _BigLessonBlock(
    index: 3,
    startLesson: 5,
    endLesson: 6,
    timeLabel: '14:00 - 15:40',
    startMinutes: 14 * 60,
    endMinutes: 15 * 60 + 40,
  ),
  _BigLessonBlock(
    index: 4,
    startLesson: 7,
    endLesson: 8,
    timeLabel: '16:00 - 17:40',
    startMinutes: 16 * 60,
    endMinutes: 17 * 60 + 40,
  ),
  _BigLessonBlock(
    index: 5,
    startLesson: 9,
    endLesson: 10,
    timeLabel: '19:00 - 20:40',
    startMinutes: 19 * 60,
    endMinutes: 20 * 60 + 40,
  ),
];

class FreeRoomPage extends StatefulWidget {
  const FreeRoomPage({
    super.key,
    required this.buildingId,
    required this.buildingName,
  });

  final String buildingId;
  final String buildingName;

  @override
  State<FreeRoomPage> createState() => _FreeRoomPageState();
}

class _FreeRoomPageState extends State<FreeRoomPage> {
  static const Color _emptyRoomAccent = Color(0xFF3768D6);
  static const int _lessonCount = 12;

  String nodeId = '0102';
  String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  double startLesson = 1;
  double endLesson = 2;
  late Future<List<Room>> _roomFuture;

  @override
  void initState() {
    super.initState();
    final initialQuery = _resolveSuggestedQuery(DateTime.now());
    date = DateFormat('yyyy-MM-dd').format(initialQuery.date);
    startLesson = initialQuery.block.startLesson.toDouble();
    endLesson = initialQuery.block.endLesson.toDouble();
    nodeId = _nodeIdForRange(startLesson, endLesson);
    _roomFuture = _loadRooms();
  }

  Future<List<Room>> _loadRooms() {
    return getRoom(date, nodeId, widget.buildingId, false);
  }

  String _compactRoomName(String name) {
    final compactName =
        name
            .replaceAll(widget.buildingName, '')
            .replaceAll('（多媒体教室）', '')
            .replaceAll('(多媒体教室)', '')
            .replaceAll('多媒体教室', '')
            .replaceAll('（教室）', '')
            .replaceAll('(教室)', '')
            .replaceAll('教室', '')
            .replaceAll('（）', '')
            .replaceAll('()', '')
            .replaceAll(' ', '')
            .trim();
    if (compactName.isNotEmpty) {
      return compactName;
    }

    final fallbackName = name.replaceAll('多媒体教室', '').trim();
    return fallbackName.isEmpty ? name : fallbackName;
  }

  String _formatDateLabel(String value) {
    final parsedDate = DateTime.tryParse(value);
    if (parsedDate == null) {
      return value;
    }

    final weekday = switch (parsedDate.weekday) {
      DateTime.monday => '周一',
      DateTime.tuesday => '周二',
      DateTime.wednesday => '周三',
      DateTime.thursday => '周四',
      DateTime.friday => '周五',
      DateTime.saturday => '周六',
      DateTime.sunday => '周日',
      _ => '',
    };
    return '${DateFormat('MM月dd日').format(parsedDate)} · $weekday';
  }

  String _lessonRangeLabel() {
    return _selectedBigLessonBlock().displayLabel;
  }

  String _formatDateSheetLabel(DateTime value) {
    final weekday = switch (value.weekday) {
      DateTime.monday => '周一',
      DateTime.tuesday => '周二',
      DateTime.wednesday => '周三',
      DateTime.thursday => '周四',
      DateTime.friday => '周五',
      DateTime.saturday => '周六',
      DateTime.sunday => '周日',
      _ => '',
    };
    return '${value.month}月${value.day}日$weekday';
  }

  _BigLessonBlock _selectedBigLessonBlock() {
    final start = startLesson.round();
    final end = endLesson.round();
    for (final block in _bigLessonBlocks) {
      if (block.startLesson == start && block.endLesson == end) {
        return block;
      }
    }

    final normalizedIndex = ((start - 1) ~/ 2).clamp(
      0,
      _bigLessonBlocks.length - 1,
    );
    return _bigLessonBlocks[normalizedIndex];
  }

  ({DateTime date, _BigLessonBlock block}) _resolveSuggestedQuery(
    DateTime now,
  ) {
    return (
      date: DateUtils.dateOnly(now),
      block: _resolveSuggestedBigLesson(now),
    );
  }

  _BigLessonBlock _resolveSuggestedBigLesson(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    final timedBlocks =
        _bigLessonBlocks
            .where(
              (block) => block.startMinutes != null && block.endMinutes != null,
            )
            .toList();

    for (final block in timedBlocks) {
      if (minutes <= block.endMinutes!) {
        return block;
      }
    }

    return timedBlocks.last;
  }

  String _nodeIdForRange(double start, double end) {
    return '${start.toStringAsFixed(0).padLeft(2, '0')}${end.toStringAsFixed(0).padLeft(2, '0')}';
  }

  Color _sheetRouteBackground(BuildContext context) {
    return Colors.transparent;
  }

  Color _sheetBarrierColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return colorScheme.overlayScrim.withValues(
      alpha: colorScheme.isDarkMode ? 0.18 : 0.10,
    );
  }

  Color _sheetTransitionBackground(BuildContext context) {
    return Colors.transparent;
  }

  int _busySlotCount(Room room) {
    return List<int>.generate(
      _lessonCount,
      (index) => index + 1,
    ).where((lesson) => _isSlotBusy(room, lesson)).length;
  }

  bool _isSlotBusy(Room room, int lesson) {
    return room.free.contains(lesson.toString().padLeft(2, '0'));
  }

  Future<void> _pickDate() async {
    final initialDate = DateTime.tryParse(date) ?? DateTime.now();
    final selectedDate = await showCupertinoModalBottomSheet<DateTime>(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _DatePickerSheet(
          accent: _emptyRoomAccent,
          initialDate: initialDate,
          firstDate: DateTime(
            initialDate.year - 2,
            initialDate.month,
            initialDate.day,
          ),
          lastDate: DateTime(
            initialDate.year + 2,
            initialDate.month,
            initialDate.day,
          ),
          formatLabel: _formatDateSheetLabel,
        );
      },
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      date = DateFormat('yyyy-MM-dd').format(selectedDate);
      _roomFuture = _loadRooms();
    });
  }

  Future<void> _showLessonPicker() async {
    final result = await showCupertinoModalBottomSheet<_BigLessonBlock>(
      context: context,
      expand: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _BigLessonSheet(
          accent: _emptyRoomAccent,
          initialBlock: _selectedBigLessonBlock(),
          suggestedBlock: _resolveSuggestedBigLesson(DateTime.now()),
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      startLesson = result.startLesson.toDouble();
      endLesson = result.endLesson.toDouble();
      nodeId = _nodeIdForRange(startLesson, endLesson);
      _roomFuture = _loadRooms();
    });
  }

  void _showRoomDetail(Room room) {
    showCupertinoModalBottomSheet<void>(
      context: context,
      expand: false,
      backgroundColor: _sheetRouteBackground(context),
      barrierColor: _sheetBarrierColor(context),
      transitionBackgroundColor: _sheetTransitionBackground(context),
      builder: (context) {
        return _RoomDetailSheet(
          room: room,
          compactRoomName: _compactRoomName(room.name),
          accent: _emptyRoomAccent,
          slotCount: _lessonCount,
          isSlotBusy: (lesson) => _isSlotBusy(room, lesson),
        );
      },
    );
  }

  SliverAppBar _buildTopBar(BuildContext context, {int? roomCount}) {
    return SliverAppBar(
      floating: true,
      snap: true,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      forceMaterialTransparency: true,
      toolbarHeight: 60,
      leadingWidth: 58,
      titleSpacing: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
        child: _FeatureBackButton(
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          widget.buildingName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      actions:
          roomCount == null
              ? null
              : [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: 12,
                    top: 6,
                    bottom: 6,
                  ),
                  child: _HeaderCountPill(
                    count: roomCount,
                    accent: _emptyRoomAccent,
                  ),
                ),
              ],
    );
  }

  Widget _buildLoadingView(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        _buildTopBar(context),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 20),
            child: _buildLoadingState(context),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        style: AppGlassBackgroundStyle.soft,
        lightBottomColor: const Color(0xFFF0F5FF),
        darkBottomColor: const Color(0xFF0F1826),
        child: EnhancedFutureBuilder(
          future: _roomFuture,
          rememberFutureResult: false,
          whenDone: (List<Room> data) => _buildContent(context, data),
          whenNotDone: _buildLoadingView(context),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: GlassPanel(
        style: GlassPanelStyle.hero,
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.78),
            _emptyRoomAccent.withValues(alpha: 0.10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoadingAnimationWidget.inkDrop(color: _emptyRoomAccent, size: 42),
            const SizedBox(height: 16),
            Text(
              '正在整理空教室结果',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '会根据日期和节次筛选当前教学楼',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Room> data) {
    final roomItems = data
        .map(
          (room) => _RoomGridItem(
            room: room,
            compactRoomName: _compactRoomName(room.name),
            seatLabel:
                room.seatNumber.trim().isEmpty
                    ? '座位未知'
                    : '${room.seatNumber} 座',
            busySlotCount: _busySlotCount(room),
          ),
        )
        .toList(growable: false);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        _buildTopBar(context, roomCount: data.length),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
          sliver: SliverToBoxAdapter(
            child: _FilterPanel(
              accent: _emptyRoomAccent,
              dateLabel: _formatDateLabel(date),
              lessonLabel: _lessonRangeLabel(),
              onPickDate: _pickDate,
              onPickLesson: _showLessonPicker,
            ),
          ),
        ),
        if (roomLoadErrorMessage != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            sliver: SliverToBoxAdapter(
              child: _FeatureEmptyState(
                icon: Ionicons.alert_circle_outline,
                accent: Theme.of(context).colorScheme.error,
                title: '空教室加载失败',
                subtitle: roomLoadErrorMessage!,
              ),
            ),
          )
        else if (data.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            sliver: SliverToBoxAdapter(
              child: _FeatureEmptyState(
                icon: Ionicons.business_outline,
                accent: _emptyRoomAccent,
                title: '当前条件下暂无空教室',
                subtitle: '可以试试切换日期或扩大节次范围，再重新查看。',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final crossAxisCount =
                    width >= 760
                        ? 4
                        : width >= 360
                        ? 3
                        : 2;
                final childAspectRatio =
                    width >= 760
                        ? 1.36
                        : width >= 360
                        ? 1.00
                        : 1.18;

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: childAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = roomItems[index];
                      return _RoomCard(
                        roomName: item.compactRoomName,
                        seatLabel: item.seatLabel,
                        busySlotCount: item.busySlotCount,
                        accent: _emptyRoomAccent,
                        onTap: () => _showRoomDetail(item.room),
                      );
                    },
                    childCount: roomItems.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    addSemanticIndexes: false,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.accent,
    required this.dateLabel,
    required this.lessonLabel,
    required this.onPickDate,
    required this.onPickLesson,
  });

  final Color accent;
  final String dateLabel;
  final String lessonLabel;
  final VoidCallback onPickDate;
  final VoidCallback onPickLesson;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: colorScheme.isDarkMode ? 0.14 : 0.82),
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.08 : 0.05),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 340;
              if (isCompact) {
                return Column(
                  children: [
                    _SelectorTile(
                      accent: accent,
                      icon: Ionicons.calendar_outline,
                      title: '日期',
                      value: dateLabel,
                      onTap: onPickDate,
                    ),
                    const SizedBox(height: 6),
                    _SelectorTile(
                      accent: accent,
                      icon: Ionicons.time_outline,
                      title: '大节',
                      value: lessonLabel,
                      onTap: onPickLesson,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _SelectorTile(
                      accent: accent,
                      icon: Ionicons.calendar_outline,
                      title: '日期',
                      value: dateLabel,
                      onTap: onPickDate,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _SelectorTile(
                      accent: accent,
                      icon: Ionicons.time_outline,
                      title: '大节',
                      value: lessonLabel,
                      onTap: onPickLesson,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SelectorTile extends StatelessWidget {
  const _SelectorTile({
    required this.accent,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      borderColor: accent.withValues(alpha: 0.12),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.surface.withValues(
            alpha: colorScheme.isDarkMode ? 0.94 : 0.92,
          ),
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.16 : 0.08),
        ],
      ),
      onTap: onTap,
      child: Row(
        children: [
          GlassIconBadge(icon: icon, tint: accent, size: 26),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Ionicons.chevron_forward_outline,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.roomName,
    required this.seatLabel,
    required this.busySlotCount,
    required this.accent,
    required this.onTap,
  });

  final String roomName;
  final String seatLabel;
  final int busySlotCount;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.solid,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      borderColor: accent.withValues(
        alpha: colorScheme.isDarkMode ? 0.18 : 0.14,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.surfaceContainerHighest.withValues(
            alpha: colorScheme.isDarkMode ? 0.92 : 0.98,
          ),
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.18 : 0.10),
        ],
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Ionicons.business_outline, color: accent, size: 13),
              ),
              const Spacer(),
              Icon(
                Ionicons.chevron_forward_outline,
                color: colorScheme.onSurfaceVariant,
                size: 14,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            roomName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              height: 1.0,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CompactRoomPill(label: seatLabel, accent: accent),
              const SizedBox(height: 4),
              _CompactRoomPill(label: '忙碌 $busySlotCount 节', accent: accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomDetailSheet extends StatelessWidget {
  const _RoomDetailSheet({
    required this.room,
    required this.compactRoomName,
    required this.accent,
    required this.slotCount,
    required this.isSlotBusy,
  });

  final Room room;
  final String compactRoomName;
  final Color accent;
  final int slotCount;
  final bool Function(int lesson) isSlotBusy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final busyCount =
        List<int>.generate(
          slotCount,
          (index) => index + 1,
        ).where(isSlotBusy).length;
    final freeCount = slotCount - busyCount;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoomSheetCard(
                accent: accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.88,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        GlassIconBadge(
                          icon: Ionicons.business_outline,
                          tint: accent,
                          size: 52,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                compactRoomName,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                room.name,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _MiniPill(
                          label:
                              room.seatNumber.trim().isEmpty
                                  ? '座位未知'
                                  : '${room.seatNumber} 座',
                          accent: accent,
                        ),
                        _MiniPill(label: '空闲 $freeCount 节', accent: accent),
                        _MiniPill(label: '占用 $busyCount 节', accent: accent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _RoomSheetCard(
                accent: accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '全天节次状态',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '单独查看全天每一节的占用情况，减少翻页判断成本。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: slotCount,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.55,
                          ),
                      itemBuilder: (context, index) {
                        final lesson = index + 1;
                        final busy = isSlotBusy(lesson);
                        return _LessonSlotCard(
                          lesson: lesson,
                          busy: busy,
                          accent: accent,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _LegendDot(
                          color: accent.withValues(
                            alpha: colorScheme.isDarkMode ? 0.70 : 0.86,
                          ),
                          label: '占用',
                        ),
                        const SizedBox(width: 14),
                        _LegendDot(
                          color: Colors.white.withValues(
                            alpha: colorScheme.isDarkMode ? 0.12 : 0.70,
                          ),
                          label: '空闲',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({
    required this.accent,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.formatLabel,
  });

  final Color accent;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String Function(DateTime value) formatLabel;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(widget.initialDate);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final isToday = DateUtils.isSameDay(_selectedDate, today);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GlassPanel(
            borderRadius: BorderRadius.circular(32),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.floatingSurfaceStrong,
                widget.accent.withValues(
                  alpha: colorScheme.isDarkMode ? 0.12 : 0.06,
                ),
              ],
            ),
            borderColor: widget.accent.withValues(alpha: 0.16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    GlassIconBadge(
                      icon: Ionicons.calendar_outline,
                      tint: widget.accent,
                      size: 50,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '选择日期',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '查询当天当前教学楼的空教室',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    _RangePresetChip(
                      label: isToday ? '今天' : '回到今天',
                      accent: widget.accent,
                      selected: isToday,
                      onTap: () {
                        setState(() {
                          _selectedDate = today;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  widget.formatLabel(_selectedDate),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(
                            alpha: colorScheme.isDarkMode ? 0.10 : 0.80,
                          ),
                          widget.accent.withValues(
                            alpha: colorScheme.isDarkMode ? 0.08 : 0.05,
                          ),
                        ],
                      ),
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.12),
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: colorScheme.copyWith(
                          primary: widget.accent,
                          onPrimary: Colors.white,
                          surface: Colors.transparent,
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: widget.accent,
                            textStyle: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      child: CalendarDatePicker(
                        initialDate: _selectedDate,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        currentDate: today,
                        onDateChanged: (value) {
                          setState(() {
                            _selectedDate = DateUtils.dateOnly(value);
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            () => Navigator.of(context).pop(_selectedDate),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigLessonSheet extends StatefulWidget {
  const _BigLessonSheet({
    required this.accent,
    required this.initialBlock,
    required this.suggestedBlock,
  });

  final Color accent;
  final _BigLessonBlock initialBlock;
  final _BigLessonBlock suggestedBlock;

  @override
  State<_BigLessonSheet> createState() => _BigLessonSheetState();
}

class _BigLessonSheetState extends State<_BigLessonSheet> {
  late _BigLessonBlock _selectedBlock;

  @override
  void initState() {
    super.initState();
    _selectedBlock = widget.initialBlock;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: GlassPanel(
            borderRadius: BorderRadius.circular(32),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.floatingSurfaceStrong,
                widget.accent.withValues(
                  alpha: colorScheme.isDarkMode ? 0.12 : 0.06,
                ),
              ],
            ),
            borderColor: widget.accent.withValues(alpha: 0.16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    GlassIconBadge(
                      icon: Ionicons.time_outline,
                      tint: widget.accent,
                      size: 50,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '选择大节',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '当前选择：${_selectedBlock.displayLabel}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _RangePresetChip(
                  label: '按当前时间',
                  accent: widget.accent,
                  selected: _selectedBlock.index == widget.suggestedBlock.index,
                  onTap: () {
                    setState(() {
                      _selectedBlock = widget.suggestedBlock;
                    });
                  },
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _bigLessonBlocks.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.42,
                  ),
                  itemBuilder: (context, index) {
                    final block = _bigLessonBlocks[index];
                    return _BigLessonOptionCard(
                      block: block,
                      accent: widget.accent,
                      selected: _selectedBlock.index == block.index,
                      onTap: () {
                        setState(() {
                          _selectedBlock = block;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            () => Navigator.of(context).pop(_selectedBlock),
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('应用'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RangePresetChip extends StatelessWidget {
  const _RangePresetChip({
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:
                selected
                    ? accent.withValues(
                      alpha: colorScheme.isDarkMode ? 0.24 : 0.14,
                    )
                    : Colors.white.withValues(
                      alpha: colorScheme.isDarkMode ? 0.08 : 0.52,
                    ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected
                      ? accent.withValues(alpha: 0.28)
                      : colorScheme.outlineVariant.withValues(alpha: 0.72),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? accent : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _BigLessonOptionCard extends StatelessWidget {
  const _BigLessonOptionCard({
    required this.block,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final _BigLessonBlock block;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            gradient:
                selected
                    ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(
                          alpha: colorScheme.isDarkMode ? 0.28 : 0.18,
                        ),
                        accent.withValues(
                          alpha: colorScheme.isDarkMode ? 0.16 : 0.08,
                        ),
                      ],
                    )
                    : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(
                          alpha: colorScheme.isDarkMode ? 0.08 : 0.56,
                        ),
                        accent.withValues(
                          alpha: colorScheme.isDarkMode ? 0.06 : 0.03,
                        ),
                      ],
                    ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color:
                  selected
                      ? accent.withValues(alpha: 0.28)
                      : colorScheme.outlineVariant.withValues(alpha: 0.58),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                block.displayLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? accent : colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                block.lessonLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomSheetCard extends StatelessWidget {
  const _RoomSheetCard({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sheetBase = colorScheme.surfaceContainerHighest;
    final sheetRaised = colorScheme.surfaceContainerHigh;

    return GlassPanel(
      style: GlassPanelStyle.solid,
      useBackdropFilter: false,
      blur: 0,
      borderRadius: BorderRadius.circular(32),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          sheetBase.withValues(alpha: colorScheme.isDarkMode ? 0.90 : 0.92),
          Color.alphaBlend(
            accent.withValues(alpha: colorScheme.isDarkMode ? 0.10 : 0.05),
            sheetRaised.withValues(alpha: colorScheme.isDarkMode ? 0.86 : 0.88),
          ),
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.06 : 0.02),
        ],
      ),
      borderColor: accent.withValues(
        alpha: colorScheme.isDarkMode ? 0.14 : 0.08,
      ),
      child: child,
    );
  }
}

class _LessonSlotCard extends StatelessWidget {
  const _LessonSlotCard({
    required this.lesson,
    required this.busy,
    required this.accent,
  });

  final int lesson;
  final bool busy;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            busy
                ? Color.alphaBlend(
                  accent.withValues(
                    alpha: colorScheme.isDarkMode ? 0.24 : 0.16,
                  ),
                  colorScheme.surfaceContainerHighest.withValues(
                    alpha: colorScheme.isDarkMode ? 0.92 : 0.96,
                  ),
                )
                : colorScheme.surfaceContainerHighest.withValues(
                  alpha: colorScheme.isDarkMode ? 0.82 : 0.94,
                ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              busy
                  ? accent.withValues(
                    alpha: colorScheme.isDarkMode ? 0.28 : 0.22,
                  )
                  : colorScheme.outlineVariant.withValues(alpha: 0.74),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$lesson',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: busy ? accent : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              busy ? '占用' : '空闲',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: busy ? accent : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigLessonBlock {
  const _BigLessonBlock({
    required this.index,
    required this.startLesson,
    required this.endLesson,
    required this.timeLabel,
    this.startMinutes,
    this.endMinutes,
  });

  final int index;
  final int startLesson;
  final int endLesson;
  final String timeLabel;
  final int? startMinutes;
  final int? endMinutes;

  String get displayLabel => '第${_chineseIndex(index)}大节';

  String get lessonLabel => '$startLesson-$endLesson节';

  static String _chineseIndex(int index) {
    const labels = ['一', '二', '三', '四', '五', '六'];
    return labels[index - 1];
  }
}

class _RoomGridItem {
  const _RoomGridItem({
    required this.room,
    required this.compactRoomName,
    required this.seatLabel,
    required this.busySlotCount,
  });

  final Room room;
  final String compactRoomName;
  final String seatLabel;
  final int busySlotCount;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: colorScheme.isDarkMode ? 0.82 : 0.90,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: colorScheme.isDarkMode ? 0.18 : 0.12),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CompactRoomPill extends StatelessWidget {
  const _CompactRoomPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: colorScheme.isDarkMode ? 0.10 : 0.56,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _FeatureEmptyState extends StatelessWidget {
  const _FeatureEmptyState({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      style: GlassPanelStyle.hero,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(
            alpha: Theme.of(context).colorScheme.isDarkMode ? 0.12 : 0.78,
          ),
          accent.withValues(
            alpha: Theme.of(context).colorScheme.isDarkMode ? 0.10 : 0.06,
          ),
        ],
      ),
      borderColor: accent.withValues(alpha: 0.14),
      child: Column(
        children: [
          GlassIconBadge(icon: icon, tint: accent, size: 54),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBackButton extends StatelessWidget {
  const _FeatureBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.floating,
      blur: 18,
      borderRadius: BorderRadius.circular(18),
      padding: EdgeInsets.zero,
      borderColor: Colors.white.withValues(
        alpha: colorScheme.isDarkMode ? 0.14 : 0.32,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: colorScheme.isDarkMode ? 0.08 : 0.20),
          colorScheme.surface.withValues(
            alpha: colorScheme.isDarkMode ? 0.04 : 0.10,
          ),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: colorScheme.shadow.withValues(
            alpha: colorScheme.isDarkMode ? 0.10 : 0.04,
          ),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          Ionicons.chevron_back,
          color: Theme.of(context).colorScheme.onSurface,
          size: 22,
        ),
      ),
    );
  }
}

class _HeaderCountPill extends StatelessWidget {
  const _HeaderCountPill({required this.count, required this.accent});

  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.floating,
      blur: 18,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderColor: Colors.white.withValues(
        alpha: colorScheme.isDarkMode ? 0.12 : 0.30,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: colorScheme.isDarkMode ? 0.08 : 0.18),
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.12 : 0.06),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: colorScheme.shadow.withValues(
            alpha: colorScheme.isDarkMode ? 0.08 : 0.03,
          ),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
      child: Text(
        '$count 间',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: accent,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.1,
          fontSize: 13,
        ),
      ),
    );
  }
}
