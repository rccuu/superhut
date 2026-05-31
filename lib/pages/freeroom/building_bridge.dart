import '../../utils/roomapi.dart';

bool isGet = false, isRoomGet = false;
List<Building> buildingList = [];
List<Room> roomList = [];
String? buildingLoadErrorMessage;
String? roomLoadErrorMessage;
Future<List<Building>>? _buildingListLoad;
final Map<_RoomQuery, Future<List<Room>>> _roomLoads = {};

typedef FreeRoomBuildingLoader = Future<List<Building>> Function();
typedef FreeRoomLoader =
    Future<List<Room>> Function(String date, String nodeId, String buildingId);

const freeRoomBuildingLoadFailureMessage = '教学楼加载失败，请稍后重试';
const freeRoomListLoadFailureMessage = '空教室加载失败，请稍后重试';

Future<List<Building>> getBuildingList({
  FreeRoomBuildingLoader? loadBuildings,
}) async {
  if (isGet) {
    return buildingList;
  }

  final inFlight = _buildingListLoad;
  if (inFlight != null) {
    return inFlight;
  }

  final load = _loadBuildingList(loadBuildings);
  _buildingListLoad = load;
  try {
    return await load;
  } finally {
    if (identical(_buildingListLoad, load)) {
      _buildingListLoad = null;
    }
  }
}

Future<List<Building>> _loadBuildingList(
  FreeRoomBuildingLoader? loadBuildings,
) async {
  try {
    buildingList =
        loadBuildings == null
            ? await _loadBuildingsFromApi()
            : await loadBuildings();
    buildingLoadErrorMessage = null;
    isGet = true;
    return buildingList;
  } catch (error) {
    buildingLoadErrorMessage = freeRoomBuildingLoadFailureMessage;
    return [];
  }
}

Future<List<Building>> _loadBuildingsFromApi() async {
  var api = FreeBuildingApi();
  await api.initData();
  await api.getCurrentTerm();
  return api.getBuildingList();
}

Future<List<Room>> getRoom(
  String date,
  String nodeId,
  String buildingId,
  bool reFlash, {
  FreeRoomLoader? loadRooms,
}) async {
  final query = _RoomQuery(date: date, nodeId: nodeId, buildingId: buildingId);
  if (!reFlash) {
    final inFlight = _roomLoads[query];
    if (inFlight != null) {
      return inFlight;
    }
  }

  final load = _loadRoomList(query, loadRooms);
  if (!reFlash) {
    _roomLoads[query] = load;
  }
  try {
    return await load;
  } finally {
    if (identical(_roomLoads[query], load)) {
      _roomLoads.remove(query);
    }
  }
}

Future<List<Room>> _loadRoomList(
  _RoomQuery query,
  FreeRoomLoader? loadRooms,
) async {
  try {
    roomList =
        loadRooms == null
            ? await _loadRoomsFromApi(query)
            : await loadRooms(query.date, query.nodeId, query.buildingId);
    roomLoadErrorMessage = null;
    return roomList;
  } catch (error) {
    roomLoadErrorMessage = freeRoomListLoadFailureMessage;
    return [];
  }
}

Future<List<Room>> _loadRoomsFromApi(_RoomQuery query) async {
  var api = FreeRoomApi();
  await api.initData();
  return api.getFreeRoomList(query.date, query.nodeId, query.buildingId);
}

void resetFreeRoomBridgeCacheForTest() {
  isGet = false;
  isRoomGet = false;
  buildingList = [];
  roomList = [];
  buildingLoadErrorMessage = null;
  roomLoadErrorMessage = null;
  _buildingListLoad = null;
  _roomLoads.clear();
}

class _RoomQuery {
  const _RoomQuery({
    required this.date,
    required this.nodeId,
    required this.buildingId,
  });

  final String date;
  final String nodeId;
  final String buildingId;

  @override
  bool operator ==(Object other) {
    return other is _RoomQuery &&
        other.date == date &&
        other.nodeId == nodeId &&
        other.buildingId == buildingId;
  }

  @override
  int get hashCode => Object.hash(date, nodeId, buildingId);
}
