import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/freeroom/building.dart';
import 'package:superhut/utils/roomapi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('duplicate building taps open a single room route', (
    tester,
  ) async {
    var buildRoomPageCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: BuildingPage(
          loadBuildings:
              () async => [
                Building(
                  name: '河西公共楼',
                  count: '12',
                  buildingId: 'b1',
                  free: '6',
                ),
              ],
          buildRoomPage: (building, displayName) {
            buildRoomPageCalls++;
            return Scaffold(
              appBar: AppBar(title: const Text('空教室列表')),
              body: Text('${building.buildingId} $displayName'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buildingTile = find.text('公共楼');
    final buildingTileCenter = tester.getCenter(buildingTile);
    await tester.tapAt(buildingTileCenter);
    await tester.tapAt(buildingTileCenter);
    await tester.pumpAndSettle();

    expect(buildRoomPageCalls, 1);
    expect(find.text('空教室列表'), findsOneWidget);
    expect(find.text('b1 公共楼'), findsOneWidget);

    Navigator.of(tester.element(find.text('空教室列表'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(buildingTile);
    await tester.pumpAndSettle();

    expect(buildRoomPageCalls, 2);
  });

  testWidgets('spaced campus names stay in campus groups', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BuildingPage(
          loadBuildings:
              () async => [
                Building(
                  name: '河 西 公 共楼',
                  count: '12',
                  buildingId: 'b1',
                  free: '6',
                ),
                Building(
                  name: '河 东 综合楼',
                  count: '9',
                  buildingId: 'b2',
                  free: '4',
                ),
              ],
          buildRoomPage:
              (building, displayName) => const Scaffold(body: Text('空教室列表')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('河西校区'), findsOneWidget);
    expect(find.text('河东校区'), findsOneWidget);
    expect(find.text('其他'), findsNothing);
    expect(find.text('河 西 公 共楼'), findsOneWidget);
    expect(find.text('河 东 综合楼'), findsOneWidget);
  });

  testWidgets('building tap recovers after route push throws', (tester) async {
    var pushCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: BuildingPage(
          loadBuildings:
              () async => [
                Building(
                  name: '河西公共楼',
                  count: '12',
                  buildingId: 'b1',
                  free: '6',
                ),
              ],
          buildRoomPage:
              (building, displayName) => const Scaffold(body: Text('空教室列表')),
          pushRoute: <T>(context, route) async {
            pushCalls++;
            throw Exception('navigator unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buildingTile = find.text('公共楼');
    await tester.tapAt(tester.getCenter(buildingTile));
    await tester.pump();
    await tester.pump();

    expect(pushCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开空教室列表，请稍后重试'), findsOneWidget);

    await tester.tapAt(tester.getCenter(buildingTile));
    await tester.pump();
    await tester.pump();

    expect(pushCalls, 2);
  });
}
