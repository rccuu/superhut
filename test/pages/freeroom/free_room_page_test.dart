import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/freeroom/room.dart';
import 'package:superhut/utils/roomapi.dart';

void main() {
  testWidgets('confirming unchanged filters does not reload rooms', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    try {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1100);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var loadCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: FreeRoomPage(
            buildingId: 'b1',
            buildingName: '公共楼',
            loadRooms: (date, nodeId, buildingId) async {
              loadCalls++;
              return [
                Room(
                  name: '公共楼 101（多媒体教室）',
                  seatNumber: '80',
                  free: const ['01', '03', '12', '13', 'bad'],
                ),
              ];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(loadCalls, 1);
      expect(find.text('101'), findsOneWidget);
      expect(find.text('忙碌 3 节'), findsOneWidget);

      await tester.ensureVisible(find.text('日期'));
      await tester.tap(find.text('日期'));
      await tester.pumpAndSettle();

      expect(find.text('选择日期'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '确定'));
      await tester.pumpAndSettle();

      expect(loadCalls, 1);
      expect(find.text('选择日期'), findsNothing);

      await tester.ensureVisible(find.text('大节'));
      await tester.tap(find.text('大节'));
      await tester.pumpAndSettle();

      expect(find.text('选择大节'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '应用'));
      await tester.pumpAndSettle();

      expect(loadCalls, 1);
      expect(find.text('选择大节'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('date picker ignores duplicate taps while open', (tester) async {
    final sheetCompleter = Completer<void>();
    var sheetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: FreeRoomPage(
          buildingId: 'b1',
          buildingName: '公共楼',
          loadRooms: (date, nodeId, buildingId) async {
            return [
              Room(name: '公共楼101', seatNumber: '80', free: const ['00']),
            ];
          },
          showBottomSheet: <T>({
            required BuildContext context,
            required WidgetBuilder builder,
            bool expand = false,
            Color? backgroundColor,
            Color? barrierColor,
            Color? transitionBackgroundColor,
            Radius? topRadius,
            BoxShadow? shadow,
          }) {
            sheetCalls++;
            return sheetCompleter.future.then<T?>((_) => null);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dateSelector = find.text('日期');
    await tester.ensureVisible(dateSelector);
    await tester.tap(dateSelector);
    await tester.pump();
    await tester.tap(dateSelector);
    await tester.pump();

    expect(sheetCalls, 1);

    sheetCompleter.complete();
    await tester.pump();

    await tester.tap(dateSelector);
    await tester.pump();

    expect(sheetCalls, 2);
  });

  testWidgets('lesson picker ignores duplicate taps while open', (
    tester,
  ) async {
    final sheetCompleter = Completer<void>();
    var sheetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: FreeRoomPage(
          buildingId: 'b1',
          buildingName: '公共楼',
          loadRooms: (date, nodeId, buildingId) async {
            return [
              Room(name: '公共楼101', seatNumber: '80', free: const ['00']),
            ];
          },
          showBottomSheet: <T>({
            required BuildContext context,
            required WidgetBuilder builder,
            bool expand = false,
            Color? backgroundColor,
            Color? barrierColor,
            Color? transitionBackgroundColor,
            Radius? topRadius,
            BoxShadow? shadow,
          }) {
            sheetCalls++;
            return sheetCompleter.future.then<T?>((_) => null);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lessonSelector = find.text('大节');
    await tester.ensureVisible(lessonSelector);
    await tester.tap(lessonSelector);
    await tester.pump();
    await tester.tap(lessonSelector);
    await tester.pump();

    expect(sheetCalls, 1);

    sheetCompleter.complete();
    await tester.pump();

    await tester.tap(lessonSelector);
    await tester.pump();

    expect(sheetCalls, 2);
  });

  testWidgets('lesson picker applies changed block and reloads rooms', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    try {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1100);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final requestedNodeIds = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: FreeRoomPage(
            buildingId: 'b1',
            buildingName: '公共楼',
            loadRooms: (date, nodeId, buildingId) async {
              requestedNodeIds.add(nodeId);
              return [
                Room(name: '公共楼101', seatNumber: '80', free: const ['00']),
              ];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(requestedNodeIds, hasLength(1));
      final targetLabel = requestedNodeIds.single == '0102' ? '第二大节' : '第一大节';
      final expectedNodeId =
          requestedNodeIds.single == '0102' ? '0304' : '0102';

      final lessonSelector = find.text('大节');
      await tester.ensureVisible(lessonSelector);
      await tester.tap(lessonSelector);
      await tester.pumpAndSettle();

      await tester.tap(find.text(targetLabel));
      await tester.pump();
      expect(find.text('当前选择：$targetLabel'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '应用'));
      await tester.pumpAndSettle();

      expect(requestedNodeIds, [isNot(expectedNodeId), expectedNodeId]);
      expect(find.text('选择大节'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('room detail sheet ignores duplicate taps while open', (
    tester,
  ) async {
    final sheetCompleter = Completer<void>();
    var sheetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: FreeRoomPage(
          buildingId: 'b1',
          buildingName: '公共楼',
          loadRooms: (date, nodeId, buildingId) async {
            return [
              Room(name: '公共楼101', seatNumber: '80', free: const ['00']),
            ];
          },
          showBottomSheet: <T>({
            required BuildContext context,
            required WidgetBuilder builder,
            bool expand = false,
            Color? backgroundColor,
            Color? barrierColor,
            Color? transitionBackgroundColor,
            Radius? topRadius,
            BoxShadow? shadow,
          }) {
            sheetCalls++;
            return sheetCompleter.future.then<T?>((_) => null);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final room = find.text('101');
    await tester.ensureVisible(room);
    await tester.tap(room);
    await tester.pump();
    await tester.tap(room);
    await tester.pump();

    expect(sheetCalls, 1);

    sheetCompleter.complete();
    await tester.pump();

    await tester.tap(room);
    await tester.pump();

    expect(sheetCalls, 2);
  });
}
