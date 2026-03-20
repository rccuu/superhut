import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/freeroom/room.dart';

import '../../utils/roomapi.dart';
import 'building_bridge.dart';

class BuildingPage extends StatefulWidget {
  const BuildingPage({super.key});

  @override
  State<BuildingPage> createState() => _BuildingPageState();
}

class _BuildingPageState extends State<BuildingPage> {
  static const List<String> _campusOrder = ['河西校区', '河东校区', '其他'];

  String _campusLabel(String name) {
    final normalized = name.replaceAll(' ', '');
    if (normalized.contains('河西')) {
      return '河西校区';
    }
    if (normalized.contains('河东')) {
      return '河东校区';
    }
    return '其他';
  }

  String _compactBuildingName(String name) {
    final compactName =
        name
            .replaceFirst(RegExp(r'^[\s\-—–]+'), '')
            .replaceFirst(RegExp(r'^(河西|河东)校区'), '')
            .replaceFirst(RegExp(r'^(河西|河东)'), '')
            .replaceFirst(RegExp(r'^[\s\-—–]+'), '')
            .trim();
    return compactName.isEmpty ? name : compactName;
  }

  List<MapEntry<String, List<Building>>> _groupBuildings(List<Building> data) {
    final grouped = <String, List<Building>>{};
    for (final building in data) {
      final campus = _campusLabel(building.name);
      grouped.putIfAbsent(campus, () => <Building>[]).add(building);
    }

    return _campusOrder
        .where((campus) => grouped[campus]?.isNotEmpty ?? false)
        .map((campus) => MapEntry(campus, grouped[campus]!))
        .toList();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getBuildingList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('选择教学楼')),
      body: EnhancedFutureBuilder(
        future: getBuildingList(),
        rememberFutureResult: true,
        whenDone: (data) {
          if (buildingLoadErrorMessage != null) {
            return Center(child: Text(buildingLoadErrorMessage!));
          }
          if (data.isEmpty) {
            return Center(child: Text('当前暂无可用教学楼数据'));
          }

          final groupedBuildings = _groupBuildings(data);

          return ListView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            children:
                groupedBuildings.expand((group) {
                  final campus = group.key;
                  final buildings = group.value;
                  return [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Text(
                        campus,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ...buildings.map((building) {
                      final displayName = _compactBuildingName(building.name);
                      return Card.filled(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => FreeRoomPage(
                                      buildingId: building.buildingId,
                                      buildingName: displayName,
                                    ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Flex(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              direction: Axis.horizontal,
                              children: [
                                Expanded(
                                  flex: 10,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Chip(
                                            label: Text(
                                              '总教室数:${building.count}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            backgroundColor:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 0,
                                              horizontal: 0,
                                            ),
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
                    }),
                  ];
                }).toList(),
          );
        },
        whenNotDone: Center(
          child: LoadingAnimationWidget.inkDrop(
            color: Theme.of(context).primaryColor,
            size: 40,
          ),
        ),
      ),
    );
  }
}
