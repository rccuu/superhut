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

class FreeBuildingApi {
  List<Building> buildingList = [];

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

    final List<Map<String, dynamic>> buildingListData =
        (data['data'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    buildingList = [];
    for (int i = 0; i < buildingListData.length; i++) {
      var tbuilding = buildingListData[i];

      buildingList.add(
        Building(
          name: tbuilding['teachingBuildingName'],
          count: tbuilding['count'],
          buildingId: tbuilding['buildingId'],
          free: tbuilding['kxs'],
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
      // 如果字符串长度小于等于2，直接返回空字符串或其他适当的值
      return '';
    }
    // 去除第一个字符，并返回最后两个字符
    return input.substring(1, input.length);
  }

  List<String> stringToList(String input) {
    List<String> tempList = input.split(',');
    List<String> result = [];
    for (var i = 0; i < tempList.length; i++) {
      result.add(processString(tempList[i]));
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
