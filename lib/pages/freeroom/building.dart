import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../core/services/app_logger.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_page_route.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/apple_glass.dart';
import '../../core/ui/color_scheme_ext.dart';
import '../../utils/roomapi.dart';
import 'building_bridge.dart';
import 'room.dart';

typedef FreeRoomPageBuilder =
    Widget Function(Building building, String displayName);
typedef FreeRoomRoutePusher =
    Future<T?> Function<T>(BuildContext context, Route<T> route);

class BuildingPage extends StatefulWidget {
  const BuildingPage({
    super.key,
    this.loadBuildings,
    this.buildRoomPage,
    this.pushRoute,
  });

  final FreeRoomBuildingLoader? loadBuildings;
  final FreeRoomPageBuilder? buildRoomPage;
  final FreeRoomRoutePusher? pushRoute;

  @override
  State<BuildingPage> createState() => _BuildingPageState();
}

class _BuildingPageState extends State<BuildingPage> {
  static const Color _emptyRoomAccent = Color(0xFF3768D6);
  static const List<String> _campusOrder = ['河西校区', '河东校区', '其他'];
  static const List<String> _campusFullPrefixes = ['河西校区', '河东校区'];
  static const List<String> _campusShortPrefixes = ['河西', '河东'];
  late Future<List<Building>> _buildingFuture;
  List<Building>? _buildingDirectorySource;
  _BuildingDirectory? _cachedBuildingDirectory;
  bool _isOpeningBuilding = false;

  @override
  void initState() {
    super.initState();
    _buildingFuture = _loadBuildings();
  }

  Future<List<Building>> _loadBuildings() {
    return getBuildingList(loadBuildings: widget.loadBuildings);
  }

  String _campusLabel(String name) {
    if (_containsCampusToken(name, '河西')) {
      return '河西校区';
    }
    if (_containsCampusToken(name, '河东')) {
      return '河东校区';
    }
    return '其他';
  }

  bool _containsCampusToken(String name, String token) {
    for (var index = 0; index < name.length; index++) {
      if (_startsWithCampusToken(name, index, token)) {
        return true;
      }
    }
    return false;
  }

  bool _startsWithCampusToken(String name, int start, String token) {
    var nameIndex = start;
    var tokenIndex = 0;
    while (nameIndex < name.length && tokenIndex < token.length) {
      final nameCodeUnit = name.codeUnitAt(nameIndex);
      if (nameCodeUnit == 0x20) {
        nameIndex++;
        continue;
      }
      if (nameCodeUnit != token.codeUnitAt(tokenIndex)) {
        return false;
      }
      nameIndex++;
      tokenIndex++;
    }
    return tokenIndex == token.length;
  }

  String _compactBuildingName(String name) {
    var start = _buildingNameContentStart(name, 0);
    start = _stripBuildingNamePrefix(name, start, _campusFullPrefixes);
    start = _stripBuildingNamePrefix(name, start, _campusShortPrefixes);
    start = _buildingNameContentStart(name, start);
    final compactName = name.substring(start).trim();
    return compactName.isEmpty ? name : compactName;
  }

  int _stripBuildingNamePrefix(String value, int start, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (value.startsWith(prefix, start)) {
        return start + prefix.length;
      }
    }
    return start;
  }

  int _buildingNameContentStart(String value, int start) {
    for (var index = start; index < value.length; index++) {
      final codeUnit = value.codeUnitAt(index);
      if (!_isBuildingNameSeparator(codeUnit)) {
        return index;
      }
    }
    return value.length;
  }

  bool _isBuildingNameSeparator(int codeUnit) {
    return codeUnit <= 0x20 ||
        codeUnit == 0x3000 ||
        codeUnit == 0x2D ||
        codeUnit == 0x2013 ||
        codeUnit == 0x2014;
  }

  _BuildingDirectory _buildingDirectoryFor(List<Building> data) {
    final cachedDirectory = _cachedBuildingDirectory;
    if (cachedDirectory != null && identical(_buildingDirectorySource, data)) {
      return cachedDirectory;
    }

    final directory = _buildBuildingDirectory(data);
    _buildingDirectorySource = data;
    _cachedBuildingDirectory = directory;
    return directory;
  }

  _BuildingDirectory _buildBuildingDirectory(List<Building> data) {
    final grouped = <String, List<_BuildingGridItem>>{};
    final allDisplayNames = <String>[];
    final allRoomCountLabels = <String>[];
    var totalClassrooms = 0;

    for (final building in data) {
      final campus = _campusLabel(building.name);
      final displayName = _compactBuildingName(building.name);
      final roomCountLabel = '${building.count}间';
      final freeLabel =
          building.free.trim().isEmpty ? '空闲数未知' : '空闲${building.free}间';
      totalClassrooms += int.tryParse(building.count) ?? 0;
      allDisplayNames.add(displayName);
      allRoomCountLabels.add(roomCountLabel);
      grouped
          .putIfAbsent(campus, () => <_BuildingGridItem>[])
          .add(
            _BuildingGridItem(
              building: building,
              displayName: displayName,
              roomCountLabel: roomCountLabel,
              freeLabel: freeLabel,
            ),
          );
    }

    final groups = <_CampusBuildingGroup>[];
    for (final campus in _campusOrder) {
      final buildings = grouped[campus];
      if (buildings == null || buildings.isEmpty) {
        continue;
      }
      groups.add(
        _CampusBuildingGroup(
          campus: campus,
          buildings: List<_BuildingGridItem>.unmodifiable(buildings),
        ),
      );
    }

    return _BuildingDirectory(
      groups: List<_CampusBuildingGroup>.unmodifiable(groups),
      totalClassrooms: totalClassrooms,
      allDisplayNames: List<String>.unmodifiable(allDisplayNames),
      allRoomCountLabels: List<String>.unmodifiable(allRoomCountLabels),
    );
  }

  Color _campusAccent(String campus) {
    return switch (campus) {
      '河西校区' => _emptyRoomAccent,
      '河东校区' => const Color(0xFF2C8A7D),
      _ => const Color(0xFFE28A2E),
    };
  }

  Widget _buildRoomPage(Building building, String displayName) {
    final builder = widget.buildRoomPage;
    if (builder != null) {
      return builder(building, displayName);
    }

    return FreeRoomPage(
      buildingId: building.buildingId,
      buildingName: displayName,
    );
  }

  Future<void> _openBuilding(Building building, String displayName) async {
    if (_isOpeningBuilding) {
      return;
    }

    _isOpeningBuilding = true;
    try {
      final pusher = widget.pushRoute ?? _pushRoute;
      await pusher<void>(
        context,
        buildAppPageRoute<void>(
          builder: (_) => _buildRoomPage(building, displayName),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to open free room building',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          message: '无法打开空教室列表，请稍后重试',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _isOpeningBuilding = false;
    }
  }

  Future<T?> _pushRoute<T>(BuildContext context, Route<T> route) {
    return Navigator.of(context).push<T>(route);
  }

  @override
  Widget build(BuildContext context) {
    return AppGlassPerformanceScope(
      isLite: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppGlassBackground(
          style: AppGlassBackgroundStyle.soft,
          lightBottomColor: const Color(0xFFF0F5FF),
          darkBottomColor: const Color(0xFF0F1826),
          child: EnhancedFutureBuilder(
            future: _buildingFuture,
            rememberFutureResult: true,
            whenDone: (List<Building> data) => _buildContent(context, data),
            whenNotDone: _buildLoadingView(context),
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildTopBar(BuildContext context) {
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
          '教学楼列表',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
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
              '正在整理教学楼清单',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '为你按校区归类空教室入口',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Building> data) {
    final directory = _buildingDirectoryFor(data);

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        // Perf: 一次性计算字体大小并缓存。之前是每个 _CampusSection 内部的
        // LayoutBuilder 都跑一遍 _resolveBuildingTitleFontSize（12×N 次
        // TextPainter.layout()），现在整个列表只算一次。
        final availableWidth = outerConstraints.maxWidth - 32 - 32;
        final crossAxisCount = availableWidth >= 720 ? 3 : 2;
        final titleFontSize = _resolveBuildingTitleFontSize(
          context,
          availableWidth: availableWidth,
          crossAxisCount: crossAxisCount,
          displayNames: directory.allDisplayNames,
          roomCountLabels: directory.allRoomCountLabels,
        );

        return CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildTopBar(context),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _CampusHeroCard(
                  accent: _emptyRoomAccent,
                  totalClassrooms: directory.totalClassrooms,
                ),
              ),
            ),
            if (buildingLoadErrorMessage != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _FeatureEmptyState(
                    icon: Ionicons.alert_circle_outline,
                    accent: Theme.of(context).colorScheme.error,
                    title: '教学楼加载失败',
                    subtitle: buildingLoadErrorMessage!,
                  ),
                ),
              )
            else if (data.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: _FeatureEmptyState(
                    icon: Ionicons.school_outline,
                    accent: _emptyRoomAccent,
                    title: '暂无可用教学楼数据',
                    subtitle: '当前没有拿到教学楼列表，稍后再试一次。',
                  ),
                ),
              )
            else
              for (final group in directory.groups)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _CampusSection(
                      campus: group.campus,
                      accent: _campusAccent(group.campus),
                      buildings: group.buildings,
                      cachedTitleFontSize: titleFontSize,
                      onOpenBuilding: _openBuilding,
                    ),
                  ),
                ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        );
      },
    );
  }
}

class _CampusHeroCard extends StatelessWidget {
  const _CampusHeroCard({required this.accent, required this.totalClassrooms});

  final Color accent;
  final int totalClassrooms;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.hero,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.26 : 0.14),
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.12 : 0.05),
          colorScheme.surface.withValues(
            alpha: colorScheme.isDarkMode ? 0.84 : 0.92,
          ),
        ],
      ),
      borderColor: accent.withValues(
        alpha: colorScheme.isDarkMode ? 0.24 : 0.16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassIconBadge(
                icon: Ionicons.grid_outline,
                tint: accent,
                size: 38,
              ),
              const SizedBox(width: 10),
              Text(
                '总教室数',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Text(
                '$totalClassrooms',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BuildingDirectory {
  const _BuildingDirectory({
    required this.groups,
    required this.totalClassrooms,
    required this.allDisplayNames,
    required this.allRoomCountLabels,
  });

  final List<_CampusBuildingGroup> groups;
  final int totalClassrooms;
  final List<String> allDisplayNames;
  final List<String> allRoomCountLabels;
}

class _CampusBuildingGroup {
  const _CampusBuildingGroup({required this.campus, required this.buildings});

  final String campus;
  final List<_BuildingGridItem> buildings;
}

class _BuildingGridItem {
  const _BuildingGridItem({
    required this.building,
    required this.displayName,
    required this.roomCountLabel,
    required this.freeLabel,
  });

  final Building building;
  final String displayName;
  final String roomCountLabel;
  final String freeLabel;
}

class _CampusSection extends StatelessWidget {
  const _CampusSection({
    required this.campus,
    required this.accent,
    required this.buildings,
    required this.cachedTitleFontSize,
    required this.onOpenBuilding,
  });

  final String campus;
  final Color accent;
  final List<_BuildingGridItem> buildings;
  // Perf: 字体大小计算结果由父级一次性计算并缓存传入，避免
  // LayoutBuilder 每次 rebuild 都跑 12×N 次 TextPainter.layout()。
  final double cachedTitleFontSize;
  final Future<void> Function(Building building, String displayName)
  onOpenBuilding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.card,
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: colorScheme.isDarkMode ? 0.12 : 0.80),
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.08 : 0.04),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 720 ? 3 : 2;
          final childAspectRatio = width >= 720 ? 1.34 : 1.20;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GlassIconBadge(
                    icon: Ionicons.location_outline,
                    tint: accent,
                    size: 36,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      campus,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(
                        alpha: colorScheme.isDarkMode ? 0.18 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${buildings.length} 栋',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _CampusBuildingGrid(
                width: width,
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                buildings: buildings,
                accent: accent,
                titleFontSize: cachedTitleFontSize,
                onOpenBuilding: onOpenBuilding,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CampusBuildingGrid extends StatelessWidget {
  const _CampusBuildingGrid({
    required this.width,
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.buildings,
    required this.accent,
    required this.titleFontSize,
    required this.onOpenBuilding,
  });

  static const double _spacing = 12;

  final double width;
  final int crossAxisCount;
  final double childAspectRatio;
  final List<_BuildingGridItem> buildings;
  final Color accent;
  final double titleFontSize;
  final Future<void> Function(Building building, String displayName)
  onOpenBuilding;

  @override
  Widget build(BuildContext context) {
    if (buildings.isEmpty ||
        crossAxisCount <= 0 ||
        childAspectRatio <= 0 ||
        !width.isFinite ||
        width <= 0) {
      return const SizedBox.shrink();
    }

    final itemWidth =
        (width - (crossAxisCount - 1) * _spacing) / crossAxisCount;
    final itemHeight = itemWidth / childAspectRatio;

    return Wrap(
      spacing: _spacing,
      runSpacing: _spacing,
      children: [
        for (final item in buildings)
          SizedBox(
            width: itemWidth,
            height: itemHeight,
            child: _BuildingCard(
              item: item,
              accent: accent,
              titleFontSize: titleFontSize,
              onOpenBuilding: onOpenBuilding,
            ),
          ),
      ],
    );
  }
}

double _resolveBuildingTitleFontSize(
  BuildContext context, {
  required double availableWidth,
  required int crossAxisCount,
  required List<String> displayNames,
  required List<String> roomCountLabels,
}) {
  if (displayNames.isEmpty) {
    return 16.8;
  }

  final titleBaseStyle =
      Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -0.2,
      ) ??
      const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        height: 1.0,
        letterSpacing: -0.2,
      );
  final pillTextStyle =
      Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.0,
      ) ??
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 1.0);
  final cardWidth =
      (availableWidth - (crossAxisCount - 1) * 12) / crossAxisCount;
  final titleAvailableWidth =
      cardWidth - 24 - 6 - _maxTextWidth(roomCountLabels, pillTextStyle) - 22;

  for (double fontSize = 18.0; fontSize >= 15.6; fontSize -= 0.2) {
    final titleStyle = titleBaseStyle.copyWith(fontSize: fontSize);
    if (_maxTextWidth(displayNames, titleStyle) <= titleAvailableWidth) {
      return double.parse(fontSize.toStringAsFixed(1));
    }
  }

  return 15.6;
}

double _maxTextWidth(List<String> texts, TextStyle style) {
  double maxWidth = 0;
  for (final text in texts) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    if (painter.width > maxWidth) {
      maxWidth = painter.width;
    }
  }
  return maxWidth;
}

class _BuildingCard extends StatelessWidget {
  const _BuildingCard({
    required this.item,
    required this.accent,
    required this.titleFontSize,
    required this.onOpenBuilding,
  });

  final _BuildingGridItem item;
  final Color accent;
  final double titleFontSize;
  final Future<void> Function(Building building, String displayName)
  onOpenBuilding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(24);

    return DecoratedBox(
      decoration: BoxDecoration(
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
        borderRadius: borderRadius,
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(
              alpha: colorScheme.isDarkMode ? 0.06 : 0.025,
            ),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onOpenBuilding(item.building, item.displayName),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Ionicons.business_outline,
                          color: accent,
                          size: 17,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Ionicons.chevron_forward_outline,
                        color: colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: titleFontSize,
                            height: 1.0,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _BuildingInfoPill(
                        label: item.roomCountLabel,
                        accent: accent,
                        emphasized: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _BuildingInfoPill(label: item.freeLabel, accent: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BuildingInfoPill extends StatelessWidget {
  const _BuildingInfoPill({
    required this.label,
    required this.accent,
    this.emphasized = false,
  });

  final String label;
  final Color accent;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final emphasizedBackground = Color.alphaBlend(
      accent.withValues(alpha: colorScheme.isDarkMode ? 0.28 : 0.16),
      colorScheme.surface,
    );
    final emphasizedTextColor =
        accent.computeLuminance() > 0.34
            ? colorScheme.onSurface
            : accent.withValues(alpha: colorScheme.isDarkMode ? 0.96 : 0.90);
    final normalBackground = Colors.white.withValues(
      alpha: colorScheme.isDarkMode ? 0.12 : 0.62,
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: emphasized ? 10 : 11,
        vertical: emphasized ? 6 : 6,
      ),
      decoration: BoxDecoration(
        color: emphasized ? emphasizedBackground : normalBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(
            alpha:
                emphasized
                    ? (colorScheme.isDarkMode ? 0.24 : 0.13)
                    : (colorScheme.isDarkMode ? 0.12 : 0.09),
          ),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (emphasized
                ? Theme.of(context).textTheme.labelMedium
                : Theme.of(context).textTheme.labelSmall)
            ?.copyWith(
              color:
                  emphasized
                      ? emphasizedTextColor
                      : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              height: 1.0,
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
    return GlassPanel(
      style: GlassPanelStyle.floating,
      blur: 16,
      borderRadius: BorderRadius.circular(20),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(
          Ionicons.chevron_back,
          color: Theme.of(context).colorScheme.onSurface,
          size: 22,
        ),
      ),
    );
  }
}
