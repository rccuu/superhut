import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/home/homeview/view.dart';
import 'package:superhut/pages/Electricitybill/electricity_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('does not create electricity api when alert is disabled', () async {
    SharedPreferences.setMockInitialValues({'enableBillWarning': false});
    var apiCreations = 0;
    final checker = HomeElectricityAlertChecker(
      electricityApiFactory: () {
        apiCreations++;
        return _FakeElectricityApi();
      },
    );

    final alert = await checker.check();

    expect(alert, isNull);
    expect(apiCreations, 0);
  });

  test(
    'returns alert when current electricity is below configured bill',
    () async {
      SharedPreferences.setMockInitialValues({
        'enableBillWarning': true,
        'enableRoomId': 'room-1',
        'enableBill': 20.0,
      });
      final api = _FakeElectricityApi(
        roomInfo: {'eleTail': '12.50', 'roomName': '一舍101'},
      );
      final checker = HomeElectricityAlertChecker(
        electricityApiFactory: () => api,
      );

      final alert = await checker.check();

      expect(api.onInitCalls, 1);
      expect(api.getHistoryCalls, 1);
      expect(api.getSingleRoomInfoRoomIds, ['room-1']);
      expect(alert, isNotNull);
      expect(alert!.description, '当前电费：12.50元\n设置电费：20.0元\n房间：一舍101');
    },
  );
}

class _FakeElectricityApi implements ElectricityApiClient {
  _FakeElectricityApi({Map? roomInfo})
    : roomInfo = roomInfo ?? const {'eleTail': '30.00', 'roomName': '一舍101'};

  final Map roomInfo;
  int onInitCalls = 0;
  int getHistoryCalls = 0;
  final List<String> getSingleRoomInfoRoomIds = <String>[];

  @override
  Future<void> onInit() async {
    onInitCalls++;
  }

  @override
  Future<Map> getHistory() async {
    getHistoryCalls++;
    return const {};
  }

  @override
  Future<Map> getSingleRoomInfo(String troomid) async {
    getSingleRoomInfoRoomIds.add(troomid);
    return roomInfo;
  }

  @override
  Future<List> getRoomList() async {
    return const [];
  }

  @override
  Future<bool> checkBeforeRecharge(String payRoomId) async {
    return true;
  }

  @override
  Future<Map> createOrder(
    String payRoomId,
    String count,
    String payRoomName,
  ) async {
    return const {};
  }

  @override
  Future<void> finishRecharge(
    String payorderno,
    String count,
    String payRoomName,
  ) async {}
}
