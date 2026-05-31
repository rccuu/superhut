import 'package:dio/dio.dart';
import 'package:superhut/utils/withhttp.dart';

import '../core/services/app_logger.dart';

String currentTerm = '';

class Building {
  final String name;
  final String count;
  final String buildingId;
  final String free;

  Building({
    required this.name,
    required this.count,
    required this.buildingId,
    required this.free,
  });
}

class Room {
  final String name;
  final String seatNumber;
  final List<String> free;

  Room({required this.name, required this.seatNumber, required this.free});
}

class _BuildingListRow {
  const _BuildingListRow({
    required this.data,
    required this.name,
    required this.priority,
  });

  final Map<String, dynamic> data;
  final String name;
  final int priority;
}

class FreeBuildingApi {
  List<Building> buildingList = [];

  int _buildingPriority(String name) {
    final isHexiPublic =
        _containsBuildingNameToken(name, '河西') &&
        (_containsBuildingNameToken(name, '公共') ||
            _containsBuildingNameToken(name, '公教'));
    if (isHexiPublic) {
      return 0;
    }

    final isPublicBuilding =
        _containsBuildingNameToken(name, '公共') ||
        _containsBuildingNameToken(name, '公教');
    if (isPublicBuilding) {
      return 1;
    }

    return 2;
  }

  bool _containsBuildingNameToken(String name, String token) {
    for (var index = 0; index < name.length; index++) {
      if (_startsWithBuildingNameToken(name, index, token)) {
        return true;
      }
    }
    return false;
  }

  bool _startsWithBuildingNameToken(String name, int start, String token) {
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

  Map<String, dynamic> _responseMap(
    dynamic data, {
    required String fallbackMessage,
  }) {
    final map = mapFromResponseData(data);
    if (map == null) {
      throw StateError(fallbackMessage);
    }
    return map;
  }

  Future<void> initData() async {
    await configureDioFromStorage();
  }

  Future<String> getCurrentTerm() async {
    final Response<dynamic> response = await postDioWithCookie(
      '/njwhd/currentTerm',
      {},
    );
    final data = _responseMap(response.data, fallbackMessage: '当前学期响应异常');
    if (data['code']?.toString() != '1') {
      throw buildJwxtStateError(response.data, fallbackMessage: '当前学期加载失败');
    }

    final termList = data['data'] as List? ?? const [];
    final termData =
        termList.isNotEmpty ? mapFromResponseData(termList.first) : null;
    if (termData == null) {
      throw StateError('当前学期数据异常');
    }

    currentTerm = termData['semesterId']?.toString() ?? '';
    if (currentTerm.isEmpty) {
      throw StateError('当前学期标识缺失');
    }
    return currentTerm;
  }

  Future<List<Building>> getBuildingList() async {
    if (currentTerm.isEmpty) {
      await getCurrentTerm();
    }

    final Response<dynamic> response = await postDioWithCookie(
      '/njwhd/student/getIdleClassroom?campusId=&jiaoxueloumc=&zhouci=40&xnxq=$currentTerm&searchType=lylv',
      {},
    );
    final data = _responseMap(response.data, fallbackMessage: '教学楼列表响应异常');
    if (data['code']?.toString() != '1') {
      throw buildJwxtStateError(response.data, fallbackMessage: '教学楼列表加载失败');
    }

    final buildingListData = <_BuildingListRow>[];
    final rawBuildingList = data['data'];
    if (rawBuildingList is List) {
      for (final item in rawBuildingList) {
        if (item is Map) {
          final row = Map<String, dynamic>.from(item);
          final name = row['teachingBuildingName']?.toString() ?? '';
          buildingListData.add(
            _BuildingListRow(
              data: row,
              name: name,
              priority: _buildingPriority(name),
            ),
          );
        }
      }
    }
    buildingListData.sort((left, right) {
      final priorityCompare = left.priority.compareTo(right.priority);
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return left.name.compareTo(right.name);
    });
    buildingList = [];
    for (int i = 0; i < buildingListData.length; i++) {
      final buildingRow = buildingListData[i];
      final tbuilding = buildingRow.data;

      buildingList.add(
        Building(
          name: buildingRow.name,
          count: tbuilding['count']?.toString() ?? '',
          buildingId: tbuilding['buildingId']?.toString() ?? '',
          free: tbuilding['kxs']?.toString() ?? '',
        ),
      );
    }
    return buildingList;
  }
}

class FreeRoomApi {
  List<Room> roomList = [];

  Future<void> _ensureCurrentTermLoaded() async {
    if (currentTerm.isNotEmpty) {
      return;
    }

    final buildingApi = FreeBuildingApi();
    await buildingApi.initData();
    await buildingApi.getCurrentTerm();
  }

  Future<void> initData() async {
    await configureDioFromStorage();
  }

  String processString(String input) {
    if (input.length <= 2) {
      return '';
    }
    return input.substring(1);
  }

  List<String> stringToList(String input) {
    final result = <String>[];
    var tokenStart = 0;
    for (var index = 0; index <= input.length; index++) {
      if (index == input.length || input.codeUnitAt(index) == 0x2c) {
        final tokenLength = index - tokenStart;
        result.add(
          tokenLength <= 2 ? '' : input.substring(tokenStart + 1, index),
        );
        tokenStart = index + 1;
      }
    }
    return result;
  }

  Future<List<Room>> getFreeRoomList(
    String date,
    String nodeId,
    String buildingId,
  ) async {
    await _ensureCurrentTermLoaded();

    final Response<dynamic> response = await postDioWithCookie(
      '/njwhd/student/getIdleClassroom?date=$date&nodeId=$nodeId&buildingId=$buildingId&campusId=&jsmc=&xnxq=$currentTerm&jiaoxueloumc=',
      {},
    );
    final data = mapFromResponseData(response.data);
    if (data == null) {
      throw StateError('空教室列表响应异常');
    }
    if (data['code']?.toString() != '1') {
      throw buildJwxtStateError(response.data, fallbackMessage: '空教室列表加载失败');
    }

    final roomListData = data['data'] as List? ?? const [];
    roomList = [];
    for (var room in roomListData) {
      final roomMap = mapFromResponseData(room);
      if (roomMap == null) {
        continue;
      }
      List<String> freeList = [];
      if ((roomMap['zyjc']?.toString() ?? '').isEmpty) {
        freeList = ['00'];
      } else {
        freeList = stringToList(roomMap['zyjc'].toString());
      }

      roomList.add(
        Room(
          name: roomMap['classroomname']?.toString() ?? '',
          seatNumber: roomMap['seatnumber']?.toString() ?? '',
          free: freeList,
        ),
      );
    }
    if (roomList.isNotEmpty) {
      AppLogger.debug('Loaded free room list for ${roomList.first.name}');
    }
    return roomList;
  }
}
