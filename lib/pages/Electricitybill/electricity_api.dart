import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../../core/services/app_auth_storage.dart';
import '../../core/services/app_logger.dart';

class ElectricityApi {
  final HutUserApi hutApi = HutUserApi();
  final AppAuthStorage _storage = AppAuthStorage.instance;
  late List<String> openids;
  late String openid, jsessionId;
  late String token;
  late String username;
  final dio = Dio();

  //基础电费信息设置
  late String factorycode, areaid, roomid, buildingid;

  Map<String, dynamic> _mapFromData(
    dynamic data, {
    required String errorMessage,
  }) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw StateError(errorMessage);
  }

  String _requiredString(
    Map<String, dynamic> data,
    String key, {
    required String errorMessage,
  }) {
    final value = data[key]?.toString() ?? '';
    if (value.isEmpty || value == 'null') {
      throw StateError(errorMessage);
    }
    return value;
  }

  //初始化API
  Future<void> onInit() async {
    openids = await hutApi.getOpenid();
    if (openids.length < 2) {
      throw StateError('未获取到电费服务身份信息，请重新登录后重试');
    }

    openid = openids[0];
    token = await _storage.readHutToken();
    jsessionId = openids[1];
    await getUserInfo();
    configureHutDio();
    AppLogger.debug('Electricity openid: ${openids[0]}');
  }

  Future<void> configureHutDio() async {
    // Update default configs.
    dio.options.baseUrl = 'https://v8mobile.hut.edu.cn';
    dio.options.connectTimeout = Duration(seconds: 5);
    dio.options.receiveTimeout = Duration(seconds: 3);
    dio.options.followRedirects = false;
    dio.options.headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Accept-Encoding': 'gzip, deflate, br',
      'Cookie':
          "userToken=$token; Domain=v8mobile.hut.edu.cn; Path=/; JSESSIONID=$jsessionId",
    };
  }

  Future<Response<dynamic>> postDio(
    String path,
    Map<String, dynamic> postData,
  ) async {
    final response = await dio.post(path, data: postData);
    return response;
  }

  Future<int> getUserInfo() async {
    final userDio = Dio();
    userDio.options.baseUrl = 'https://authx-service.hut.edu.cn';
    userDio.options.connectTimeout = Duration(seconds: 5);
    userDio.options.receiveTimeout = Duration(seconds: 3);
    userDio.options.followRedirects = false;
    userDio.options.headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36 Edg/91.0.864.64',
      'Accept': 'application/json, text/javascript, */*; q=0.01',
      'Accept-Encoding': 'gzip, deflate, br',
      'X-Id-Token': token,
    };
    final Response<dynamic> response = await userDio.get(
      '/personal/api/v1/personal/me/user',
    );
    final data = _mapFromData(response.data, errorMessage: '用户信息响应异常');
    final user = _mapFromData(data['data'], errorMessage: '用户信息缺失');
    username = _requiredString(user, 'username', errorMessage: '用户学号缺失');
    return 1;
  }

  //获取历史记录
  Future<Map> getHistory() async {
    Response response;
    response = await postDio(
      '/myaccount/querywechatUserLastInfo?openid=$openid',
      {"idserial": username, "openid": openid},
    );
    final data = _mapFromData(response.data, errorMessage: '历史房间响应异常');
    final history = _mapFromData(data['resultData'], errorMessage: '未找到历史房间信息');
    final elelastBindStr = _requiredString(
      history,
      'elelastbind',
      errorMessage: '历史房间信息缺失',
    );
    final elelastbind = _mapFromData(
      jsonDecode(elelastBindStr),
      errorMessage: '历史房间信息格式异常',
    );
    factorycode = _requiredString(
      elelastbind,
      'factorycode',
      errorMessage: '历史房间缺少 factorycode',
    );
    areaid = _requiredString(
      elelastbind,
      'areaid',
      errorMessage: '历史房间缺少 areaid',
    );
    roomid = _requiredString(
      elelastbind,
      'roomid',
      errorMessage: '历史房间缺少 roomid',
    );
    buildingid = _requiredString(
      elelastbind,
      'buildingid',
      errorMessage: '历史房间缺少 buildingid',
    );
    return {
      "factorycode": factorycode,
      "areaid": areaid,
      "roomid": roomid,
      "buildingid": buildingid,
    };
  }

  //获取当个房间信息
  Future<Map> getSingleRoomInfo(String troomid) async {
    final Response<dynamic> response =
        await postDio('/channel/queryRoomDetail?openid=$openid', {
          "areaid": areaid,
          "buildingid": buildingid,
          "factorycode": factorycode,
          "roomid": troomid,
        });
    final data = _mapFromData(response.data, errorMessage: '房间详情响应异常');
    final roomInfo = _mapFromData(data['resultData'], errorMessage: '房间详情缺失');
    final String eleTail = _requiredString(
      roomInfo,
      'eledetail',
      errorMessage: '房间剩余电量缺失',
    );
    final String roomName = _requiredString(
      roomInfo,
      'accname',
      errorMessage: '房间名称缺失',
    );
    return {"roomName": roomName, "eleTail": eleTail};
  }

  //获取所有房间列表
  Future<List> getRoomList() async {
    final Response<dynamic> response = await postDio(
      '/channel/getAllAccountInfo?openid=$openid',
      {"areaid": areaid, "buildingid": buildingid, "factorycode": factorycode},
    );
    final data = _mapFromData(response.data, errorMessage: '房间列表响应异常');
    final roomListA = _mapFromData(data['resultData'], errorMessage: '房间列表缺失');
    final roomList = roomListA['jsonArr'];
    if (roomList is! List) {
      throw StateError('房间列表数据异常');
    }
    return roomList;
  }

  //充值前检测
  Future<bool> checkBeforeRecharge(String payRoomId) async {
    Response response;
    response = await postDio('/myaccount/userlastbind?openid=$openid', {
      "payinfo": {"elepayWay": "6"},
      "eleinfo": {
        "buildingid": buildingid,
        "areaid": areaid,
        "roomid": payRoomId,
        "factorycode": factorycode,
      },
      "idserial": username,
    });
    final data = _mapFromData(response.data, errorMessage: '充值校验响应异常');
    if (data['success'] == true) {
      return true;
    } else {
      return false;
    }
  }

  //创建订单
  Future<Map> createOrder(
    String payRoomId,
    String count,
    String payRoomName,
  ) async {
    final Response<dynamic> response =
        await postDio('/elepay/createPreThirdTrade?openid=$openid', {
          "payamt": count,
          "openid": openid,
          "idserial": username,
          "factorycode": factorycode,
          "buildingid": buildingid,
          "areaid": areaid,
          "roomid": payRoomId,
          "roomvalue": payRoomName,
          "paytype": "6",
        });
    final data = _mapFromData(response.data, errorMessage: '创建订单响应异常');
    final resultData = _mapFromData(
      data['resultData'],
      errorMessage: '创建订单结果缺失',
    );
    final String payorderno = _requiredString(
      resultData,
      'payorderno',
      errorMessage: '订单号缺失',
    );
    final String txdate = _requiredString(
      resultData,
      'txdate',
      errorMessage: '订单时间缺失',
    );
    return {"payorderno": payorderno, "txdate": txdate, "code": 'true'};
  }

  //完成充值
  Future<void> finishRecharge(
    String payorderno,
    String count,
    String payRoomName,
  ) async {
    final Response<dynamic> response =
        await postDio('/elepay/consumeFromYktToEle?openid=$openid', {
          "paytxamt": count,
          "payWay": "6",
          "openid": openid,
          "idserial": username,
          "payorderno": payorderno,
          "factorycode": factorycode,
          "roomname": payRoomName,
        });
    final data = _mapFromData(response.data, errorMessage: '充值结果响应异常');
    AppLogger.debug('Electricity recharge result: ${data['message']}');
  }
}
