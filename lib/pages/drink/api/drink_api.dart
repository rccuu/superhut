import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/drink/api/drink_device_status.dart';
import 'package:superhut/pages/drink/api/drink_result.dart';

abstract class DrinkApiClient {
  Future<List<Map>> deviceList();

  Future<bool> favoDevice({required String id, required bool isUnFavo});

  Future<DrinkResult> startDrink({required String id, int ptype});

  Future<DrinkResult> endDrink({required String id});

  Future<bool> isAvailableDevice({required String id});

  Future<DeviceStatusResult> deviceStatus({required String id});

  Future<String> resolveQrDevice({required String qrId});

  Future<String> getToken();

  Future<void> setToken({required String token});
}

abstract class DrinkLoginApiClient {
  Future<Uint8List> userCaptcha({
    required String doubleRandom,
    required String timestamp,
  });

  Future<DrinkResult> userMessageCode({
    required String doubleRandom,
    required String photoCode,
    required String phone,
  });

  Future<DrinkResult> userLogin({
    required String phone,
    required String messageCode,
  });
}

class DrinkApi implements DrinkApiClient, DrinkLoginApiClient {
  DrinkApi._privateConstructor() {
    _ensureTokenInitialized();
  }

  /// 仅供测试使用的生成式构造。
  ///
  /// Dart 里工厂构造不能作为超类构造器，子类必须重定向到一个生成式构造；
  /// 测试也用它取得与单例隔离的实例，避免共享 Token 与初始化时序。
  @visibleForTesting
  DrinkApi.forTesting() {
    _ensureTokenInitialized();
  }

  static final DrinkApi _instance = DrinkApi._privateConstructor();

  factory DrinkApi() {
    return _instance;
  }

  static const String _baseUrl = 'https://i.ilife798.com/api/v1';

  /// 客户端版本，同时用于 VersionCode 与 User-Agent。与官方 App 一致。
  static const String _clientVersion = '3.1.8';

  /// 支付类型。91 为钱包支付（默认），21 为支付宝免密支付；取值经官方
  /// 客户端运行时实测（上游 cc2562/superhut `61c5e076`）。旧静态值 0 的
  /// 支付语义未确证，不再使用。
  static const int walletPaymentType = 91;
  static const int alipayPaymentType = 21;

  /// 接水次数。官方默认值，集中定义便于按实测调整。
  static const int _drinkCount = 1;

  /// 请求头与官方客户端对齐：只发 VersionCode 与 User-Agent，
  /// Authorization 由 [_authOptions] 按请求注入。历史上还发送
  /// ApplicationType、Accept、Accept-Encoding、Connection，
  /// 官方客户端不使用这些头，服务端也不校验，故不发。
  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: const {
        'VersionCode': _clientVersion,
        'User-Agent': 'Android_ilife798_$_clientVersion',
      },
    ),
  );

  final Map<String, dynamic> _token = {"uid": "", "eid": "", "token": ""};
  Future<void>? _tokenInitialized;

  /// 替换底层 HTTP adapter，仅供测试注入。
  @visibleForTesting
  void setHttpClientAdapter(HttpClientAdapter adapter) {
    _dio.httpClientAdapter = adapter;
  }

  /// 单例的懒构造入口：取用实例即开始读取本地凭据，
  /// 后续鉴权请求都要等它完成，避免带上空 Authorization。
  void _ensureTokenInitialized() {
    _tokenInitialized ??= _initToken();
  }

  Future<Options> _authOptions() async {
    await _tokenInitialized;
    return Options(headers: {'Authorization': _token['token']});
  }

  /// 初始化Token
  ///
  /// 本地存储损坏时保持未登录状态，不能让返回的 Future 变成失败 Future
  /// 拖垮所有认证请求。
  Future<void> _initToken() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? userInfoDataStr = prefs.getString("drink798UsrApiToken");
      if (userInfoDataStr == null) {
        await prefs.setString("drink798UsrApiToken", jsonEncode(_token));
        return;
      }

      final dynamic decoded = jsonDecode(userInfoDataStr);
      if (decoded is! Map) {
        // 不是 JSON 对象：清掉坏数据，等待重新登录覆盖
        await prefs.remove("drink798UsrApiToken");
        return;
      }

      for (final entry in decoded.entries) {
        _token[entry.key.toString()] = entry.value;
      }
    } catch (_) {
      // jsonDecode 失败等异常按未登录处理，坏数据会在下次登录时被覆盖
    }
  }

  /// 获取慧生活798登录验证码
  @override
  Future<Uint8List> userCaptcha({
    required String doubleRandom,
    required String timestamp,
  }) async {
    Options options = Options(responseType: ResponseType.bytes);
    String url = "$_baseUrl/captcha/";
    Map<String, dynamic> params = {"s": doubleRandom, "r": timestamp};
    Response response = await _dio.get(
      url,
      queryParameters: params,
      options: options,
    );
    return response.data;
  }

  /// 获取短信验证码
  ///
  /// 与 [userLogin] 一样区分「服务端拒绝」和「请求未完成」，
  /// 避免把网络异常说成「图形验证码错误」。
  @override
  Future<DrinkResult> userMessageCode({
    required String doubleRandom,
    required String photoCode,
    required String phone,
  }) async {
    String url = "$_baseUrl/acc/login/code";
    Map<String, dynamic> data = {
      "s": doubleRandom,
      "authCode": photoCode,
      "un": phone,
    };

    try {
      Response response = await _dio.post(url, data: data);
      final result = response.data;
      if (result is! Map) {
        return const DrinkResult(success: false, message: '服务端返回格式异常');
      }
      if (result['code'] == 0) {
        return const DrinkResult(success: true, code: 0);
      }
      return DrinkResult(
        success: false,
        code: result['code'] is int ? result['code'] : null,
        message: _messageOf(result['msg'], fallback: '发送失败'),
      );
    } on DioException catch (e) {
      return DrinkResult(success: false, message: '网络错误：${e.message}');
    } catch (e) {
      return DrinkResult(success: false, message: '请求失败：$e');
    }
  }

  /// 开始登录
  ///
  /// 返回值区分三种失败，避免把解析失败或网络异常一律说成「验证码错误」：
  /// - [DrinkResult.success] 为真：登录成功
  /// - [DrinkResult.code] 非 null：服务端明确拒绝，[DrinkResult.message] 是其原因
  /// - [DrinkResult.code] 为 null：请求未完成或响应无法解析，[DrinkResult.message]
  ///   为具体的技术原因
  @override
  Future<DrinkResult> userLogin({
    required String phone,
    required String messageCode,
  }) async {
    String url = "$_baseUrl/acc/login";
    // 参数集与官方一致：openCode、un、authCode。曾多传 cid，官方不发送该参数。
    Map<String, dynamic> data = {
      "openCode": "",
      "authCode": messageCode,
      "un": phone,
    };

    try {
      Response response = await _dio.post(url, data: data);
      final result = response.data;

      if (result is! Map) {
        return const DrinkResult(success: false, message: '服务端返回格式异常');
      }

      final code = result['code'];
      if (code != 0) {
        return DrinkResult(
          success: false,
          code: code is int ? code : null,
          message: _messageOf(result['msg'], fallback: '登录被拒绝'),
        );
      }

      // code == 0 即登录成功。凭据字段缺失属于响应形状问题，
      // 不能反过来说成「验证码错误」——那会掩盖真实故障。
      final payload = result['data'];
      final account = payload is Map ? payload['al'] : null;
      if (account is! Map) {
        return const DrinkResult(
          success: false,
          message: '登录已被接受，但响应缺少账号信息，请反馈此问题',
        );
      }

      await _saveLoginToken({
        "uid": account['uid'] ?? "",
        "eid": account['eid'] ?? "",
        "token": account['token'] ?? "",
      });
      return const DrinkResult(success: true, code: 0);
    } on DioException catch (e) {
      return DrinkResult(success: false, message: '网络错误：${e.message}');
    } catch (e) {
      return DrinkResult(success: false, message: '解析响应失败：$e');
    }
  }

  Future<void> _saveLoginToken(Map<String, dynamic> tokenData) async {
    // 防止启动时尚未读完旧 Token，随后覆盖刚保存的新 Token。
    await _tokenInitialized;
    _token["uid"] = tokenData["uid"] ?? "";
    _token["eid"] = tokenData["eid"] ?? "";
    _token["token"] = tokenData["token"] ?? "";

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("drink798UsrApiToken", jsonEncode(_token));
    await prefs.setBool("hui798IsLogin", true);
  }

  /// 获取设备列表
  @override
  Future<List<Map>> deviceList() async {
    String url = "$_baseUrl/ui/app/master";
    Options options = await _authOptions();

    Response response = await _dio.get(url, options: options);
    final result = response.data;
    if (result["data"]["account"] == null) {
      return [
        {"id": "404", "name": "Account failure"},
      ];
    }

    if (result["data"]["favos"] == null) {
      return [];
    }

    final List favos = result["data"]["favos"];
    final devices = <Map>[];
    for (var index = favos.length - 1; index >= 0; index--) {
      final device = favos[index];
      devices.add({"id": device["id"], "name": device["name"]});
    }
    return devices;
  }

  /// 收藏或取消收藏设备
  ///
  /// `remove` 以 `1`/`0` 上线（上游实测形状）；布尔 `true`/`false` 的
  /// 形式未实测过。
  @override
  Future<bool> favoDevice({required String id, required bool isUnFavo}) async {
    String url = "$_baseUrl/dev/favo";
    Options options = await _authOptions();

    Map<String, dynamic> params = {"did": id, "remove": isUnFavo ? 1 : 0};

    Response response = await _dio.get(
      url,
      queryParameters: params,
      options: options,
    );
    return response.data["code"] == 0;
  }

  /// 开始喝水
  ///
  /// 业务参数与官方一致：did、upgrade、ptype、args、rcp、cnt。
  /// [ptype] 缺省钱包支付（91）；钱包被拒时由调用方回退支付宝（21）。
  /// args 对饮水设备为空串（官方仅在洗衣机、吹风机、触碰开锁三类设备填 JSON）。
  @override
  Future<DrinkResult> startDrink({required String id, int? ptype}) async {
    String url = "$_baseUrl/dev/start";
    Options options = await _authOptions();

    Map<String, dynamic> params = {
      "did": id,
      "upgrade": true,
      "ptype": ptype ?? walletPaymentType,
      "args": "",
      "rcp": false,
      "cnt": _drinkCount,
    };

    Response response = await _dio.get(
      url,
      queryParameters: params,
      options: options,
    );
    return _toResult(response.data);
  }

  /// 结束喝水
  ///
  /// `rcp=false` 与官方客户端一致（上游实测形状）。
  @override
  Future<DrinkResult> endDrink({required String id}) async {
    String url = "$_baseUrl/dev/end";
    Options options = await _authOptions();

    Map<String, dynamic> params = {"did": id, "rcp": false};

    Response response = await _dio.get(
      url,
      queryParameters: params,
      options: options,
    );
    return _toResult(response.data);
  }

  /// 检测设备状态（三态），见 [DrinkDeviceStatus]。
  ///
  /// 请求形状对齐官方客户端：`did` + `more=false`，不带 `promo`
  /// （上游实测形状）。
  @override
  Future<DeviceStatusResult> deviceStatus({required String id}) async {
    String url = "$_baseUrl/ui/app/dev/status";
    Options options = await _authOptions();

    Map<String, dynamic> params = {"did": id, "more": false};

    try {
      Response response = await _dio.get(
        url,
        queryParameters: params,
        options: options,
      );
      final result = response.data;
      if (result is! Map || result['code'] != 0) {
        final code = result is Map && result['code'] is int
            ? result['code'] as int
            : null;
        final message = result is Map && result['msg'] is String
            ? result['msg'] as String
            : null;
        return DeviceStatusResult(
          success: false,
          code: code,
          message: _messageOf(message, fallback: null),
        );
      }
      return DeviceStatusResult(
        success: true,
        code: 0,
        status: DrinkDeviceStatus.fromJson(result['data']),
      );
    } on DioException catch (e) {
      return DeviceStatusResult(success: false, message: '网络错误：${e.message}');
    } catch (_) {
      return const DeviceStatusResult(success: false);
    }
  }

  /// 扫码解析设备：用二维码末段经 `qr/use` 换取真实设备 ID（官方扫码入口
  /// 走同一接口）。
  ///
  /// 返回解析出的设备 ID；无法解析时为空串，调用方可回退二维码末段。
  /// [qrId] 为空时直接返回空串，不发起请求。
  @override
  Future<String> resolveQrDevice({required String qrId}) async {
    if (qrId.isEmpty) {
      return '';
    }

    String url = "$_baseUrl/qr/use";
    Options options = await _authOptions();

    try {
      Response response = await _dio.get(
        url,
        queryParameters: {"id": qrId},
        options: options,
      );
      final result = response.data;
      if (result is! Map || result['code'] != 0) {
        return '';
      }
      final dynamic payload = result['data'];
      final dynamic dev = payload is Map ? payload['dev'] : null;
      if (dev is! Map) {
        return '';
      }
      return _messageOf(dev['id']?.toString(), fallback: '') ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 检测设备是否可用（链路在线且业务状态空闲）。
  ///
  /// 出错时按「仍在使用」处理（返回 false），避免网络抖动导致提前自动结算。
  @override
  Future<bool> isAvailableDevice({required String id}) async {
    final result = await deviceStatus(id: id);
    if (!result.success || result.status == null) {
      return false;
    }
    return result.status!.isAvailable;
  }

  /// 获取Token
  @override
  Future<String> getToken() async {
    await _tokenInitialized;
    return _token["token"];
  }

  /// 设置Token
  @override
  Future<void> setToken({required String token}) async {
    await _saveTokenOnly(token);
  }

  Future<void> _saveTokenOnly(String token) async {
    await _tokenInitialized;
    _token["token"] = token;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("drink798UsrApiToken", jsonEncode(_token));
  }

  /// 把服务端响应转为 [DrinkResult]。
  ///
  /// 响应形状为 `{"code": <int>, "msg": <string>}`。
  DrinkResult _toResult(dynamic data) {
    if (data is! Map) {
      return const DrinkResult(success: false);
    }
    final code = data['code'];
    return DrinkResult(
      success: code == 0,
      code: code is int ? code : null,
      message: _messageOf(data['msg'], fallback: null),
    );
  }

  static String? _messageOf(dynamic value, {required String? fallback}) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return fallback;
  }
}
