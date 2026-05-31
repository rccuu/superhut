import 'dart:async';

import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../core/ui/app_bottom_sheet.dart';
import '../../core/ui/app_loading_indicator.dart';
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

const double _roomGridWideScreenBreakpoint = 760;
const double _roomGridDefaultSpacing = 6;
const double _roomGridCompactSpacing = 4;
// Sliver constraints already exclude outer horizontal padding.
const double _roomGridThreeColumnMinWidth = 288;

String _formatFreeRoomDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatFreeRoomMonthDay(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$month月$day日';
}

String _freeRoomWeekdayLabel(DateTime date) {
  return switch (date.weekday) {
    DateTime.monday => '周一',
    DateTime.tuesday => '周二',
    DateTime.wednesday => '周三',
    DateTime.thursday => '周四',
    DateTime.friday => '周五',
    DateTime.saturday => '周六',
    DateTime.sunday => '周日',
    _ => '',
  };
}

typedef FreeRoomPageLoader =
    Future<List<Room>> Function(String date, String nodeId, String buildingId);
typedef FreeRoomBottomSheetPresenter =
    Future<T?> Function<T>({
      required BuildContext context,
      required WidgetBuilder builder,
      bool expand,
      Color? backgroundColor,
      Color? barrierColor,
      Color? transitionBackgroundColor,
      Radius? topRadius,
      BoxShadow? shadow,
    });

class FreeRoomPage extends StatefulWidget {
  const FreeRoomPage({
    super.key,
    required this.buildingId,
    required this.buildingName,
    this.loadRooms,
    this.showBottomSheet,
  });

  final String buildingId;
  final String buildingName;
  final FreeRoomPageLoader? loadRooms;
  final FreeRoomBottomSheetPresenter? showBottomSheet;

  @override
  State<FreeRoomPage> createState() => _FreeRoomPageState();
}

class _FreeRoomPageState extends State<FreeRoomPage> {
  static const Color _emptyRoomAccent = Color(0xFF3768D6);
  static const int _lessonCount = 12;
  static const List<String> _roomNameCompactTokens = [
    '（多媒体教室）',
    '(多媒体教室)',
    '多媒体教室',
    '（教室）',
    '(教室)',
    '教室',
    '（）',
    '()',
  ];
  static const List<String> _roomNameFallbackTokens = ['多媒体教室'];

  String nodeId = '0102';
  late String date;
  double startLesson = 1;
  double endLesson = 2;
  late final ValueNotifier<Future<List<Room>>> _roomFutureNotifier;
  bool _isDatePickerOpen = false;
  bool _isLessonPickerOpen = false;
  bool _isRoomDetailOpen = false;
  final Map<Room, _RoomCardInfo> _roomCardInfoCache = <Room, _RoomCardInfo>{};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initialQuery = _resolveSuggestedQuery(now);
    date = _formatFreeRoomDateKey(initialQuery.date);
    startLesson = initialQuery.block.startLesson.toDouble();
    endLesson = initialQuery.block.endLesson.toDouble();
    nodeId = _nodeIdForRange(startLesson, endLesson);
    _roomFutureNotifier = ValueNotifier<Future<List<Room>>>(_reloadRooms());
  }

  @override
  void dispose() {
    _roomFutureNotifier.dispose();
    super.dispose();
  }

  Future<List<Room>> _loadRooms() {
    final loader = widget.loadRooms;
    if (loader != null) {
      return loader(date, nodeId, widget.buildingId);
    }
    return getRoom(date, nodeId, widget.buildingId, false);
  }

  Future<List<Room>> _reloadRooms() {
    _roomCardInfoCache.clear();
    return _loadRooms();
  }

  _RoomCardInfo _roomCardInfoFor(Room room) {
    final cached = _roomCardInfoCache[room];
    if (cached != null) {
      return cached;
    }

    final seatLabel =
        room.seatNumber.trim().isEmpty ? '座位未知' : '${room.seatNumber} 座';
    final busyLessons = _busyLessonsForRoom(room);
    final info = _RoomCardInfo(
      compactName: _compactRoomName(room.name),
      seatLabel: seatLabel,
      busySlotCount: busyLessons.length,
      busyLessons: busyLessons,
    );
    _roomCardInfoCache[room] = info;
    return info;
  }

  String _compactRoomName(String name) {
    final compactName =
        _stripRoomNameSegments(
          name,
          removeBuildingName: true,
          removeAsciiSpaces: true,
          tokens: _roomNameCompactTokens,
        ).trim();
    if (compactName.isNotEmpty) {
      return compactName;
    }

    final fallbackName =
        _stripRoomNameSegments(
          name,
          removeBuildingName: false,
          removeAsciiSpaces: false,
          tokens: _roomNameFallbackTokens,
        ).trim();
    return fallbackName.isEmpty ? name : fallbackName;
  }

  String _stripRoomNameSegments(
    String name, {
    required bool removeBuildingName,
    required bool removeAsciiSpaces,
    required List<String> tokens,
  }) {
    final buffer = StringBuffer();
    final buildingName = widget.buildingName;
    for (var index = 0; index < name.length;) {
      if (removeBuildingName &&
          buildingName.isNotEmpty &&
          name.startsWith(buildingName, index)) {
        index += buildingName.length;
        continue;
      }

      final tokenLength = _roomNameTokenLengthAt(name, index, tokens);
      if (tokenLength > 0) {
        index += tokenLength;
        continue;
      }

      final codeUnit = name.codeUnitAt(index);
      if (removeAsciiSpaces && codeUnit == 0x20) {
        index++;
        continue;
      }

      buffer.write(name[index]);
      index++;
    }
    return buffer.toString();
  }

  int _roomNameTokenLengthAt(String name, int start, List<String> tokens) {
    for (final token in tokens) {
      if (name.startsWith(token, start)) {
        return token.length;
      }
    }
    return 0;
  }

  String _formatDateLabel(String value) {
    final parsedDate = DateTime.tryParse(value);
    if (parsedDate == null) {
      return value;
    }

    return '${_formatFreeRoomMonthDay(parsedDate)} · '
        '${_freeRoomWeekdayLabel(parsedDate)}';
  }

  String _lessonRangeLabel() {
    return _selectedBigLessonBlock().displayLabel;
  }

  String _formatDateSheetLabel(DateTime value) {
    return '${value.month}月${value.day}日${_freeRoomWeekdayLabel(value)}';
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
    _BigLessonBlock? latestTimedBlock;
    for (final block in _bigLessonBlocks) {
      final endMinutes = block.endMinutes;
      if (block.startMinutes == null || endMinutes == null) {
        continue;
      }
      latestTimedBlock = block;
      if (minutes <= endMinutes) {
        return block;
      }
    }

    return latestTimedBlock ?? _bigLessonBlocks.last;
  }

  String _nodeIdForRange(double start, double end) {
    return '${start.toStringAsFixed(0).padLeft(2, '0')}${end.toStringAsFixed(0).padLeft(2, '0')}';
  }

  Color _sheetBarrierColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return colorScheme.overlayScrim.withValues(
      alpha: colorScheme.isDarkMode ? 0.18 : 0.10,
    );
  }

  Set<int> _busyLessonsForRoom(Room room) {
    final busyLessons = <int>{};
    for (final rawLesson in room.free) {
      final lesson = _parseBusyLessonKey(rawLesson);
      if (lesson > 0 && lesson <= _lessonCount) {
        busyLessons.add(lesson);
      }
    }
    return busyLessons;
  }

  int _parseBusyLessonKey(String value) {
    if (value.length != 2) {
      return 0;
    }

    final first = value.codeUnitAt(0);
    final second = value.codeUnitAt(1);
    if (first < 0x30 || first > 0x39 || second < 0x30 || second > 0x39) {
      return 0;
    }
    return (first - 0x30) * 10 + second - 0x30;
  }

  Future<T?> _showFreeRoomSheet<T>({
    required WidgetBuilder builder,
    bool expand = false,
    Color? backgroundColor,
    Color? barrierColor,
    Color? transitionBackgroundColor,
  }) {
    final presenter = widget.showBottomSheet ?? showAppAdaptiveBottomSheet;
    return presenter<T>(
      context: context,
      expand: expand,
      backgroundColor: backgroundColor,
      barrierColor: barrierColor,
      transitionBackgroundColor: transitionBackgroundColor,
      builder: builder,
    );
  }

  Future<void> _pickDate() async {
    if (_isDatePickerOpen) {
      return;
    }

    _isDatePickerOpen = true;
    final today = DateUtils.dateOnly(DateTime.now());
    final initialDate = DateTime.tryParse(date) ?? today;
    final DateTime? selectedDate;
    try {
      selectedDate = await _showFreeRoomSheet<DateTime>(
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
            today: today,
            formatLabel: _formatDateSheetLabel,
          );
        },
      );
    } finally {
      _isDatePickerOpen = false;
    }

    if (selectedDate == null || !mounted) {
      return;
    }

    final selectedDateText = _formatFreeRoomDateKey(selectedDate);
    if (selectedDateText == date) {
      return;
    }

    date = selectedDateText;
    _roomFutureNotifier.value = _reloadRooms();
  }

  Future<void> _showLessonPicker() async {
    if (_isLessonPickerOpen) {
      return;
    }

    _isLessonPickerOpen = true;
    final initialBlock = _selectedBigLessonBlock();
    final suggestedBlock = _resolveSuggestedBigLesson(DateTime.now());
    final _BigLessonBlock? result;
    try {
      result = await _showFreeRoomSheet<_BigLessonBlock>(
        backgroundColor: Colors.transparent,
        builder: (context) {
          return _BigLessonSheet(
            accent: _emptyRoomAccent,
            initialBlock: initialBlock,
            suggestedBlock: suggestedBlock,
          );
        },
      );
    } finally {
      _isLessonPickerOpen = false;
    }

    if (result == null || !mounted) {
      return;
    }

    final nextStartLesson = result.startLesson.toDouble();
    final nextEndLesson = result.endLesson.toDouble();
    final nextNodeId = _nodeIdForRange(nextStartLesson, nextEndLesson);
    if (nextNodeId == nodeId) {
      return;
    }

    startLesson = nextStartLesson;
    endLesson = nextEndLesson;
    nodeId = nextNodeId;
    _roomFutureNotifier.value = _reloadRooms();
  }

  void _showRoomDetail(Room room) {
    if (_isRoomDetailOpen) {
      return;
    }

    _isRoomDetailOpen = true;
    final cardInfo = _roomCardInfoFor(room);
    final sheet = _showFreeRoomSheet<void>(
      backgroundColor: Colors.transparent,
      barrierColor: _sheetBarrierColor(context),
      transitionBackgroundColor: Colors.transparent,
      builder: (context) {
        return _RoomDetailSheet(
          room: room,
          compactRoomName: cardInfo.compactName,
          accent: _emptyRoomAccent,
          slotCount: _lessonCount,
          busySlotCount: cardInfo.busySlotCount,
          busyLessons: cardInfo.busyLessons,
        );
      },
    );
    unawaited(_trackRoomDetailSheet(sheet));
  }

  Future<void> _trackRoomDetailSheet(Future<void> sheet) async {
    try {
      await sheet;
    } finally {
      _isRoomDetailOpen = false;
    }
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
        child: ValueListenableBuilder<Future<List<Room>>>(
          valueListenable: _roomFutureNotifier,
          builder: (context, roomFuture, _) {
            return EnhancedFutureBuilder(
              future: roomFuture,
              rememberFutureResult: false,
              whenDone: (List<Room> data) => _buildContent(context, data),
              whenNotDone: _buildLoadingView(context),
            );
          },
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
            const AppLoadingIndicator(size: 34, color: _emptyRoomAccent),
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
                    width >= _roomGridWideScreenBreakpoint
                        ? 4
                        : width >= _roomGridThreeColumnMinWidth
                        ? 3
                        : 2;
                final spacing =
                    crossAxisCount == 3 && width < 312
                        ? _roomGridCompactSpacing
                        : _roomGridDefaultSpacing;
                final childAspectRatio =
                    crossAxisCount == 4
                        ? 1.36
                        : crossAxisCount == 3
                        ? (width < 312 ? 0.84 : 0.90)
                        : 1.12;

                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final room = data[index];
                      final cardInfo = _roomCardInfoFor(room);
                      return _RoomCard(
                        roomName: cardInfo.compactName,
                        seatLabel: cardInfo.seatLabel,
                        busySlotCount: cardInfo.busySlotCount,
                        accent: _emptyRoomAccent,
                        onTap: () => _showRoomDetail(room),
                      );
                    },
                    childCount: data.length,
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

class _RoomCardInfo {
  const _RoomCardInfo({
    required this.compactName,
    required this.seatLabel,
    required this.busySlotCount,
    required this.busyLessons,
  });

  final String compactName;
  final String seatLabel;
  final int busySlotCount;
  final Set<int> busyLessons;
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
    required this.busySlotCount,
    required this.busyLessons,
  });

  final Room room;
  final String compactRoomName;
  final Color accent;
  final int slotCount;
  final int busySlotCount;
  final Set<int> busyLessons;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final freeCount = slotCount - busySlotCount;

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
                        _MiniPill(label: '占用 $busySlotCount 节', accent: accent),
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return _FixedCrossAxisGrid(
                          width: constraints.maxWidth,
                          itemCount: slotCount,
                          crossAxisCount: 4,
                          spacing: 10,
                          childAspectRatio: 1.55,
                          itemBuilder: (context, index) {
                            final lesson = index + 1;
                            final busy = busyLessons.contains(lesson);
                            return _LessonSlotCard(
                              lesson: lesson,
                              busy: busy,
                              accent: accent,
                            );
                          },
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
    required this.today,
    required this.formatLabel,
  });

  final Color accent;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime today;
  final String Function(DateTime value) formatLabel;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  late final ValueNotifier<DateTime> _selectedDateNotifier;

  @override
  void initState() {
    super.initState();
    _selectedDateNotifier = ValueNotifier<DateTime>(
      DateUtils.dateOnly(widget.initialDate),
    );
  }

  @override
  void dispose() {
    _selectedDateNotifier.dispose();
    super.dispose();
  }

  void _selectDate(DateTime value) {
    final nextDate = DateUtils.dateOnly(value);
    if (DateUtils.isSameDay(_selectedDateNotifier.value, nextDate)) {
      return;
    }

    _selectedDateNotifier.value = nextDate;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = widget.today;

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
                    ValueListenableBuilder<DateTime>(
                      valueListenable: _selectedDateNotifier,
                      builder: (context, selectedDate, child) {
                        final isToday = DateUtils.isSameDay(
                          selectedDate,
                          today,
                        );
                        return _RangePresetChip(
                          label: isToday ? '今天' : '回到今天',
                          accent: widget.accent,
                          selected: isToday,
                          onTap: () => _selectDate(today),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ValueListenableBuilder<DateTime>(
                  valueListenable: _selectedDateNotifier,
                  builder: (context, selectedDate, child) {
                    return Text(
                      widget.formatLabel(selectedDate),
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    );
                  },
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
                      child: ValueListenableBuilder<DateTime>(
                        valueListenable: _selectedDateNotifier,
                        builder: (context, selectedDate, child) {
                          return CalendarDatePicker(
                            initialDate: selectedDate,
                            firstDate: widget.firstDate,
                            lastDate: widget.lastDate,
                            currentDate: today,
                            onDateChanged: _selectDate,
                          );
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
                            () => Navigator.of(
                              context,
                            ).pop(_selectedDateNotifier.value),
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
  late final ValueNotifier<_BigLessonBlock> _selectedBlockNotifier;

  @override
  void initState() {
    super.initState();
    _selectedBlockNotifier = ValueNotifier<_BigLessonBlock>(
      widget.initialBlock,
    );
  }

  @override
  void dispose() {
    _selectedBlockNotifier.dispose();
    super.dispose();
  }

  void _selectBlock(_BigLessonBlock block) {
    if (_selectedBlockNotifier.value.index == block.index) {
      return;
    }

    _selectedBlockNotifier.value = block;
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
                          ValueListenableBuilder<_BigLessonBlock>(
                            valueListenable: _selectedBlockNotifier,
                            builder: (context, selectedBlock, child) {
                              return Text(
                                '当前选择：${selectedBlock.displayLabel}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<_BigLessonBlock>(
                  valueListenable: _selectedBlockNotifier,
                  builder: (context, selectedBlock, child) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RangePresetChip(
                          label: '按当前时间',
                          accent: widget.accent,
                          selected:
                              selectedBlock.index ==
                              widget.suggestedBlock.index,
                          onTap: () => _selectBlock(widget.suggestedBlock),
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return _FixedCrossAxisGrid(
                              width: constraints.maxWidth,
                              itemCount: _bigLessonBlocks.length,
                              crossAxisCount: 2,
                              spacing: 8,
                              childAspectRatio: 2.42,
                              itemBuilder: (context, index) {
                                final block = _bigLessonBlocks[index];
                                return _BigLessonOptionCard(
                                  block: block,
                                  accent: widget.accent,
                                  selected: selectedBlock.index == block.index,
                                  onTap: () => _selectBlock(block),
                                );
                              },
                            );
                          },
                        ),
                      ],
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
                            () => Navigator.of(
                              context,
                            ).pop(_selectedBlockNotifier.value),
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
        child: Container(
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

class _FixedCrossAxisGrid extends StatelessWidget {
  const _FixedCrossAxisGrid({
    required this.width,
    required this.itemCount,
    required this.crossAxisCount,
    required this.spacing,
    required this.childAspectRatio,
    required this.itemBuilder,
  });

  final double width;
  final int itemCount;
  final int crossAxisCount;
  final double spacing;
  final double childAspectRatio;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0 ||
        crossAxisCount <= 0 ||
        childAspectRatio <= 0 ||
        !width.isFinite ||
        width <= 0) {
      return const SizedBox.shrink();
    }

    final itemWidth = (width - (crossAxisCount - 1) * spacing) / crossAxisCount;
    final itemHeight = itemWidth / childAspectRatio;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (var index = 0; index < itemCount; index++)
          SizedBox(
            width: itemWidth,
            height: itemHeight,
            child: itemBuilder(context, index),
          ),
      ],
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
        child: Container(
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
      style: GlassPanelStyle.solid,
      blur: 0,
      useBackdropFilter: false,
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
            alpha: colorScheme.isDarkMode ? 0.05 : 0.018,
          ),
          blurRadius: 6,
          offset: const Offset(0, 3),
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
      style: GlassPanelStyle.solid,
      blur: 0,
      useBackdropFilter: false,
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
            alpha: colorScheme.isDarkMode ? 0.04 : 0.014,
          ),
          blurRadius: 6,
          offset: const Offset(0, 3),
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
