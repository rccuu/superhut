import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/freeroom/building_bridge.dart';
import 'package:superhut/utils/roomapi.dart';
import 'package:superhut/utils/withhttp.dart' show dio;

class _FakeFreeRoomHttpClientAdapter implements HttpClientAdapter {
  _FakeFreeRoomHttpClientAdapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  setUp(resetFreeRoomBridgeCacheForTest);
  tearDown(() {
    currentTerm = '';
    resetFreeRoomBridgeCacheForTest();
  });

  test(
    'concurrent building list loads share a single in-flight request',
    () async {
      final completer = Completer<List<Building>>();
      var loadCalls = 0;

      final firstLoad = getBuildingList(
        loadBuildings: () {
          loadCalls++;
          return completer.future;
        },
      );
      final secondLoad = getBuildingList(
        loadBuildings: () {
          loadCalls++;
          return completer.future;
        },
      );
      await Future<void>.delayed(Duration.zero);

      expect(loadCalls, 1);

      final buildings = [
        Building(name: '河西公共楼', count: '12', buildingId: 'b1', free: '6'),
      ];
      completer.complete(buildings);

      final results = await Future.wait([firstLoad, secondLoad]);

      expect(results[0], same(results[1]));
      expect(results[0], buildings);
      expect(isGet, isTrue);
      expect(buildingLoadErrorMessage, isNull);

      final cached = await getBuildingList(
        loadBuildings: () {
          loadCalls++;
          return Future.value(const []);
        },
      );

      expect(cached, buildings);
      expect(loadCalls, 1);
    },
  );

  test('building list load failure uses stable message', () async {
    const rawError =
        '教学楼接口失败: https://hut.example/free-room?token=secret-token';

    final buildings = await getBuildingList(
      loadBuildings: () async {
        throw StateError(rawError);
      },
    );

    expect(buildings, isEmpty);
    expect(buildingLoadErrorMessage, freeRoomBuildingLoadFailureMessage);
    expect(buildingLoadErrorMessage, isNot(contains('secret-token')));
    expect(buildingLoadErrorMessage, isNot(contains('https://hut.example')));
    expect(isGet, isFalse);
  });

  test(
    'FreeBuildingApi parses and prioritizes building list responses',
    () async {
      SharedPreferences.setMockInitialValues({
        'token': 'jwxt-token',
        'my_client_ticket': 'ticket',
      });
      currentTerm = '2025-2026-2';
      final originalAdapter = dio.httpClientAdapter;
      final requestPaths = <String>[];
      dio.httpClientAdapter = _FakeFreeRoomHttpClientAdapter((options) {
        requestPaths.add(options.path);
        if (!options.path.startsWith('/njwhd/student/getIdleClassroom?')) {
          throw StateError('Unexpected request path: ${options.path}');
        }
        return _jsonResponse({
          'code': '1',
          'data': [
            {
              'teachingBuildingName': '综合楼',
              'count': '20',
              'buildingId': 'b3',
              'kxs': '9',
            },
            'ignored',
            {
              'teachingBuildingName': '公共教学楼B',
              'count': '15',
              'buildingId': 'b2',
              'kxs': '7',
            },
            {
              'teachingBuildingName': '河 西 公 共楼',
              'count': '12',
              'buildingId': 'b1',
              'kxs': '6',
            },
          ],
        });
      });
      addTearDown(() {
        dio.httpClientAdapter = originalAdapter;
        currentTerm = '';
      });

      final buildings = await FreeBuildingApi().getBuildingList();

      expect(requestPaths, hasLength(1));
      expect(buildings.map((building) => building.name), [
        '河 西 公 共楼',
        '公共教学楼B',
        '综合楼',
      ]);
      expect(buildings.map((building) => building.buildingId), [
        'b1',
        'b2',
        'b3',
      ]);
      expect(buildings.first.count, '12');
      expect(buildings.first.free, '6');
    },
  );

  test(
    'concurrent matching room loads share a single in-flight request',
    () async {
      final completer = Completer<List<Room>>();
      var loadCalls = 0;
      final calls = <String>[];

      Future<List<Room>> loadRooms(
        String date,
        String nodeId,
        String buildingId,
      ) {
        loadCalls++;
        calls.add('$date/$nodeId/$buildingId');
        return completer.future;
      }

      final firstLoad = getRoom(
        '2026-05-29',
        '0102',
        'b1',
        false,
        loadRooms: loadRooms,
      );
      final secondLoad = getRoom(
        '2026-05-29',
        '0102',
        'b1',
        false,
        loadRooms: loadRooms,
      );
      await Future<void>.delayed(Duration.zero);

      expect(loadCalls, 1);
      expect(calls, ['2026-05-29/0102/b1']);

      final rooms = [
        Room(name: '公共楼101', seatNumber: '80', free: const ['00']),
      ];
      completer.complete(rooms);

      final results = await Future.wait([firstLoad, secondLoad]);

      expect(results[0], same(results[1]));
      expect(results[0], rooms);
      expect(roomList, rooms);
      expect(roomLoadErrorMessage, isNull);
    },
  );

  test('FreeRoomApi parses non-empty room free lesson responses', () async {
    SharedPreferences.setMockInitialValues({
      'token': 'jwxt-token',
      'my_client_ticket': 'ticket',
    });
    currentTerm = '2025-2026-2';
    final originalAdapter = dio.httpClientAdapter;
    final requestPaths = <String>[];
    dio.httpClientAdapter = _FakeFreeRoomHttpClientAdapter((options) {
      requestPaths.add(options.path);
      if (!options.path.startsWith('/njwhd/student/getIdleClassroom?')) {
        throw StateError('Unexpected request path: ${options.path}');
      }
      return _jsonResponse({
        'code': '1',
        'data': [
          {
            'classroomname': '公共楼101',
            'seatnumber': '80',
            'zyjc': 'A01,B03,C12',
          },
          {'classroomname': '公共楼102', 'seatnumber': '60', 'zyjc': ''},
        ],
      });
    });
    addTearDown(() {
      dio.httpClientAdapter = originalAdapter;
      currentTerm = '';
    });

    final rooms = await FreeRoomApi().getFreeRoomList(
      '2026-05-29',
      '0102',
      'b1',
    );

    expect(requestPaths, hasLength(1));
    expect(requestPaths.single, contains('date=2026-05-29'));
    expect(requestPaths.single, contains('nodeId=0102'));
    expect(requestPaths.single, contains('buildingId=b1'));
    expect(rooms, hasLength(2));
    expect(rooms.first.name, '公共楼101');
    expect(rooms.first.seatNumber, '80');
    expect(rooms.first.free, ['01', '03', '12']);
    expect(rooms.last.free, ['00']);
  });

  test('room list load failure uses stable message', () async {
    const rawError =
        '空教室接口失败: https://hut.example/free-room/list?token=secret-token';

    final rooms = await getRoom(
      '2026-05-29',
      '0102',
      'b1',
      false,
      loadRooms: (date, nodeId, buildingId) async {
        throw StateError(rawError);
      },
    );

    expect(rooms, isEmpty);
    expect(roomLoadErrorMessage, freeRoomListLoadFailureMessage);
    expect(roomLoadErrorMessage, isNot(contains('secret-token')));
    expect(roomLoadErrorMessage, isNot(contains('https://hut.example')));
  });

  test('different room queries are not merged', () async {
    var loadCalls = 0;
    final calls = <String>[];

    Future<List<Room>> loadRooms(
      String date,
      String nodeId,
      String buildingId,
    ) async {
      loadCalls++;
      calls.add('$date/$nodeId/$buildingId');
      return [
        Room(name: '公共楼$loadCalls', seatNumber: '80', free: const ['00']),
      ];
    }

    final results = await Future.wait([
      getRoom('2026-05-29', '0102', 'b1', false, loadRooms: loadRooms),
      getRoom('2026-05-29', '0304', 'b1', false, loadRooms: loadRooms),
    ]);

    expect(loadCalls, 2);
    expect(calls, ['2026-05-29/0102/b1', '2026-05-29/0304/b1']);
    expect(results[0].single.name, '公共楼1');
    expect(results[1].single.name, '公共楼2');
  });
}
