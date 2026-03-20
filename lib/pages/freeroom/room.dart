import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:superhut/pages/freeroom/building_bridge.dart';

import '../../utils/roomapi.dart';

class FreeRoomPage extends StatefulWidget {
  final String buildingId, buildingName;

  const FreeRoomPage({
    super.key,
    required this.buildingId,
    required this.buildingName,
  });

  @override
  State<FreeRoomPage> createState() => _FreeRoomPageState();
}

class _FreeRoomPageState extends State<FreeRoomPage> {
  int count = 12;
  String nodeId = "0102";
  String date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  double startLesson = 1.0; // 默认起始节次
  double endLesson = 2.0; // 默认结束节次

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

  void _showRoomDetail(Room room) {
    showCupertinoModalBottomSheet(
      expand: false,
      context: context,
      builder:
          (context) => Material(
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  height: 350,
                  child: ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      Text(
                        room.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      Flex(
                        direction: Axis.horizontal,
                        children: List.generate(count, (indexs) {
                          final slot = (indexs + 1).toString().padLeft(2, '0');
                          final isBooked = room.free.contains(slot);
                          return Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    isBooked
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.only(
                                  topLeft:
                                      indexs == 0
                                          ? const Radius.circular(10)
                                          : Radius.zero,
                                  bottomLeft:
                                      indexs == 0
                                          ? const Radius.circular(10)
                                          : Radius.zero,
                                  topRight:
                                      indexs == count - 1
                                          ? const Radius.circular(10)
                                          : Radius.zero,
                                  bottomRight:
                                      indexs == count - 1
                                          ? const Radius.circular(10)
                                          : Radius.zero,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${indexs + 1}',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text('不空闲'),
                          const SizedBox(width: 10),
                          Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text('空闲'),
                        ],
                      ),
                      ListTile(
                        leading: const Icon(Ionicons.location_outline),
                        title: Text(room.name),
                      ),
                      ListTile(
                        leading: const Icon(Ionicons.happy_outline),
                        title: Text('座位数：${room.seatNumber}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(widget.buildingName)),
      body: EnhancedFutureBuilder(
        future: getRoom(date, nodeId, widget.buildingId, false),
        rememberFutureResult: false,
        whenDone: (data) {
          return Flex(
            direction: Axis.vertical,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 10, right: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  //  direction: Axis.horizontal,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text('日期'),
                          TextButton(
                            onPressed: () async {
                              var result = await showDatePicker(
                                locale: Locale('zh'),
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(
                                  DateTime.now().year - 2,
                                  DateTime.now().month,
                                  DateTime.now().day,
                                ),
                                lastDate: DateTime(
                                  DateTime.now().year + 2,
                                  DateTime.now().month,
                                  DateTime.now().day,
                                ),
                              );
                              if (result != null) {
                                setState(() {
                                  date = DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(result);
                                });
                              }
                            },
                            child: Text(
                              DateFormat(
                                'yyyy年MM月dd日',
                              ).format(DateTime.parse(date)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Text('节次'),
                          TextButton(
                            onPressed: () async {
                              showCupertinoModalBottomSheet(
                                context: context,
                                builder: (context) {
                                  return Material(
                                    child: StatefulBuilder(
                                      builder: (context, setState) {
                                        return Stack(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(20),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '选择节次范围',
                                                    style:
                                                        Theme.of(
                                                          context,
                                                        ).textTheme.titleLarge,
                                                  ),
                                                  SizedBox(height: 10),
                                                  RangeSlider(
                                                    values: RangeValues(
                                                      startLesson,
                                                      endLesson,
                                                    ),
                                                    min: 1.0,
                                                    max: 12.0,
                                                    divisions: 11,
                                                    labels: RangeLabels(
                                                      startLesson
                                                          .round()
                                                          .toString(),
                                                      endLesson
                                                          .round()
                                                          .toString(),
                                                    ),
                                                    onChanged: (
                                                      RangeValues values,
                                                    ) {
                                                      setState(() {
                                                        startLesson =
                                                            values.start;
                                                        endLesson = values.end;
                                                      });
                                                    },
                                                    onChangeEnd: (
                                                      RangeValues values,
                                                    ) {
                                                      setState(() {
                                                        startLesson =
                                                            values.start;
                                                        endLesson = values.end;
                                                        nodeId =
                                                            '${startLesson.toStringAsFixed(0).padLeft(2, '0')}${endLesson.toStringAsFixed(0).padLeft(2, '0')}';
                                                      });
                                                    },
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text('第1节'),
                                                      Text('第12节'),
                                                    ],
                                                  ),
                                                  SizedBox(height: 50),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  );
                                },
                              ).then((value) {
                                setState(() {
                                  startLesson = startLesson;
                                  endLesson = endLesson;
                                  nodeId =
                                      '${startLesson.toStringAsFixed(0).padLeft(2, '0')}${endLesson.toStringAsFixed(0).padLeft(2, '0')}';
                                });
                              });
                            },
                            child: Text(
                              '${startLesson.round()}-${endLesson.round()}节', // 动态更新为用户选择的范围
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    roomLoadErrorMessage != null
                        ? Center(child: Text(roomLoadErrorMessage!))
                        : data.isEmpty
                        ? Center(child: Text('当前条件下暂无空教室'))
                        : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.08,
                              ),
                          itemCount: data.length,
                          itemBuilder: (context, index) {
                            final room = data[index];
                            return Card.filled(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _showRoomDetail(room),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _compactRoomName(room.name),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${room.seatNumber}座',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
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
