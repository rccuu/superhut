import '../../utils/roomapi.dart';

bool isGet = false, isRoomGet = false;
List<Building> buildingList = [];
List<Room> roomList = [];
String? buildingLoadErrorMessage;
String? roomLoadErrorMessage;

Future<List<Building>> getBuildingList() async {
  if (isGet) {
    return buildingList;
  }

  try {
    var api = FreeBuildingApi();
    await api.initData();
    await api.getCurrentTerm();
    buildingList = await api.getBuildingList();
    buildingLoadErrorMessage = null;
    isGet = true;
    return buildingList;
  } catch (error) {
    buildingLoadErrorMessage = error.toString().replaceFirst('Bad state: ', '');
    return [];
  }
}

Future<List<Room>> getRoom(
  String date,
  String nodeId,
  String buildingId,
  bool reFlash,
) async {
  try {
    var api = FreeRoomApi();
    await api.initData();
    roomList = await api.getFreeRoomList(date, nodeId, buildingId);
    roomLoadErrorMessage = null;
    return roomList;
  } catch (error) {
    roomLoadErrorMessage = error.toString().replaceFirst('Bad state: ', '');
    return [];
  }
}
