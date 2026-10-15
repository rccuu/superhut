import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:superhut/pages/drink/api/drink_result.dart';

/// 798 接口的线上格式契约。
///
/// 断言全部观察真正交给传输层的 `RequestOptions`：官方服务端不校验签名，
/// 反而会拒绝带了 `sign` 的请求，所以参数集一旦漂移就只能回头抓包排查。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('dev/start carries exactly the official query parameters', () async {
    final adapter = _RecordingAdapter((_) => _json(_ok()));
    final api = _apiWithAdapter(adapter);

    final result = await api.startDrink(id: 'dev-9');

    expect(result.success, isTrue);
    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.uri.scheme, 'https');
    expect(request.uri.host, 'i.ilife798.com');
    expect(request.uri.path, '/api/v1/dev/start');
    expect(request.queryParameters.keys.toSet(), <String>{
      'did',
      'upgrade',
      'ptype',
      'args',
      'rcp',
      'cnt',
    });
    expect(request.queryParameters['did'], 'dev-9');
    expect(request.queryParameters['upgrade'], isTrue);
    expect(request.queryParameters['ptype'], 0);
    // 饮水设备的 args 是空串；官方只在洗衣机、吹风机、触碰开锁上填 JSON。
    expect(request.queryParameters['args'], '');
    expect(request.queryParameters['rcp'], isFalse);
    expect(request.queryParameters['cnt'], 1);

    // 废弃的 stype 与任何签名参数都不能出现，序列化后的 URL 也不行。
    expect(request.queryParameters.containsKey('stype'), isFalse);
    expect(request.queryParameters.containsKey('sign'), isFalse);
    expect(request.uri.queryParameters.keys.toList(), <String>[
      'did',
      'upgrade',
      'ptype',
      'args',
      'rcp',
      'cnt',
    ]);
    expect(request.uri.queryParameters['args'], '');
    expect(
      request.uri.toString(),
      'https://i.ilife798.com/api/v1/dev/start'
      '?did=dev-9&upgrade=true&ptype=0&args=&rcp=false&cnt=1',
    );
  });

  test('dev/end carries only the device id', () async {
    final adapter = _RecordingAdapter((_) => _json(_ok()));
    final api = _apiWithAdapter(adapter);

    await api.endDrink(id: 'dev-9');

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.uri.path, '/api/v1/dev/end');
    expect(request.queryParameters.keys.toSet(), <String>{'did'});
    expect(request.queryParameters['did'], 'dev-9');
    expect(request.queryParameters.containsKey('sign'), isFalse);
  });

  test('acc/login body is exactly openCode, authCode and un', () async {
    final adapter = _RecordingAdapter((_) => _json(_loginAccepted()));
    final api = _apiWithAdapter(adapter);

    final result = await api.userLogin(
      phone: '13800138000',
      messageCode: '123456',
    );

    expect(result.success, isTrue);
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/v1/acc/login');

    final body = request.data as Map<String, dynamic>;
    expect(body.keys.toList(), <String>['openCode', 'authCode', 'un']);
    expect(body['openCode'], '');
    expect(body['authCode'], '123456');
    expect(body['un'], '13800138000');
    // 官方客户端不发送 cid，也不发送任何签名参数。
    expect(body.containsKey('cid'), isFalse);
    expect(body.containsKey('sign'), isFalse);

    // 真正写进请求体的字节也必须只有这三个键。
    expect(jsonDecode(adapter.requestBodies.single), <String, dynamic>{
      'openCode': '',
      'authCode': '123456',
      'un': '13800138000',
    });
    expect(request.uri.queryParameters.containsKey('sign'), isFalse);
  });

  test('acc/login/code body is exactly s, authCode and un', () async {
    final adapter = _RecordingAdapter((_) => _json(_ok()));
    final api = _apiWithAdapter(adapter);

    final result = await api.userMessageCode(
      doubleRandom: '0.5',
      photoCode: '1234',
      phone: '13800138000',
    );

    expect(result.success, isTrue);
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/v1/acc/login/code');

    final body = request.data as Map<String, dynamic>;
    expect(body.keys.toList(), <String>['s', 'authCode', 'un']);
    expect(body['s'], '0.5');
    expect(body['authCode'], '1234');
    expect(body['un'], '13800138000');
    expect(body.containsKey('sign'), isFalse);
    expect(jsonDecode(adapter.requestBodies.single), <String, dynamic>{
      's': '0.5',
      'authCode': '1234',
      'un': '13800138000',
    });
  });

  test(
    'every request sends the two official headers and 15s timeouts',
    () async {
      final adapter = _RecordingAdapter((options) {
        if (options.uri.path == '/api/v1/captcha/') {
          return ResponseBody.fromBytes(
            Uint8List.fromList(<int>[1, 2, 3]),
            200,
            headers: const <String, List<String>>{},
          );
        }
        return _json(
          options.uri.path == '/api/v1/acc/login' ? _loginAccepted() : _ok(),
        );
      });
      final api = _apiWithAdapter(adapter);

      await api.userCaptcha(doubleRandom: '0.5', timestamp: '1700000000000');
      await api.userMessageCode(
        doubleRandom: '0.5',
        photoCode: '1234',
        phone: '13800138000',
      );
      await api.userLogin(phone: '13800138000', messageCode: '123456');
      await api.startDrink(id: 'dev-9');
      await api.endDrink(id: 'dev-9');

      expect(adapter.requests, hasLength(5));
      for (final request in adapter.requests) {
        expect(
          _headerValue(request, 'VersionCode'),
          '3.1.8',
          reason: request.uri.toString(),
        );
        expect(
          _headerValue(request, 'User-Agent'),
          'Android_ilife798_3.1.8',
          reason: request.uri.toString(),
        );
        // 官方客户端不发这些头，服务端也不校验。
        for (final removed in const <String>[
          'applicationtype',
          'accept',
          'accept-encoding',
          'connection',
        ]) {
          expect(
            _headerNames(request).contains(removed),
            isFalse,
            reason: '${request.uri} 仍带着已移除的 $removed 头',
          );
        }
        expect(request.connectTimeout, const Duration(seconds: 15));
        expect(request.receiveTimeout, const Duration(seconds: 15));
      }

      // 喝水请求是鉴权请求，必须带 Authorization。
      expect(_headerValue(adapter.requests[3], 'Authorization'), isNotNull);
      expect(_headerValue(adapter.requests[4], 'Authorization'), isNotNull);
    },
  );

  test(
    'startDrink and endDrink map the server code onto DrinkResult',
    () async {
      final api = _apiWithAdapter(
        _RecordingAdapter(
          (_) => _json(<String, dynamic>{'code': 0, 'msg': ''}),
        ),
      );

      final start = await api.startDrink(id: 'dev-9');
      final end = await api.endDrink(id: 'dev-9');

      expect(start.success, isTrue);
      expect(start.code, 0);
      expect(start.isSessionExpired, isFalse);
      expect(end.success, isTrue);
      expect(end.code, 0);
      expect(end.isSessionExpired, isFalse);
    },
  );

  test('a -99 code is reported as an expired session', () async {
    final api = _apiWithAdapter(
      _RecordingAdapter(
        (_) => _json(<String, dynamic>{'code': -99, 'msg': '登录已过期，请重新登录'}),
      ),
    );

    final start = await api.startDrink(id: 'dev-9');
    final end = await api.endDrink(id: 'dev-9');

    for (final result in <DrinkResult>[start, end]) {
      expect(result.success, isFalse);
      expect(result.code, -99);
      expect(result.isSessionExpired, isTrue);
      expect(result.message, '登录已过期，请重新登录');
    }
  });

  test('a rejection without a message leaves the message null', () async {
    // 服务端用空串表示「没给原因」，此时必须回 null，
    // 调用方才退得回本地文案。
    final api = _apiWithAdapter(
      _RecordingAdapter(
        (_) => _json(<String, dynamic>{'code': 4001, 'msg': ''}),
      ),
    );

    final result = await api.startDrink(id: 'dev-9');

    expect(result.success, isFalse);
    expect(result.code, 4001);
    expect(result.message, isNull);
    expect(result.isSessionExpired, isFalse);
  });

  test(
    'a non-integer code is treated as a request that never completed',
    () async {
      final api = _apiWithAdapter(
        _RecordingAdapter(
          (_) => _json(<String, dynamic>{'code': '4001', 'msg': '设备离线'}),
        ),
      );

      final result = await api.startDrink(id: 'dev-9');

      expect(result.success, isFalse);
      expect(result.code, isNull);
      expect(result.message, '设备离线');
    },
  );

  test('a body that is not a JSON object fails without throwing', () async {
    final api = _apiWithAdapter(
      _RecordingAdapter((_) => _json(<String>['unexpected'])),
    );

    final result = await api.startDrink(id: 'dev-9');

    expect(result.success, isFalse);
    expect(result.code, isNull);
    expect(result.message, isNull);
  });

  test(
    'userMessageCode surfaces the server reason or its own fallback',
    () async {
      final rejected = _apiWithAdapter(
        _RecordingAdapter(
          (_) => _json(<String, dynamic>{'code': 2003, 'msg': '图形验证码错误'}),
        ),
      );
      final noMessage = _apiWithAdapter(
        _RecordingAdapter((_) => _json(<String, dynamic>{'code': 2003})),
      );
      final wrongShape = _apiWithAdapter(
        _RecordingAdapter((_) => _json(<String>['unexpected'])),
      );

      final result = await rejected.userMessageCode(
        doubleRandom: '0.5',
        photoCode: '1234',
        phone: '13800138000',
      );
      expect(result.success, isFalse);
      expect(result.code, 2003);
      expect(result.message, '图形验证码错误');

      final fallback = await noMessage.userMessageCode(
        doubleRandom: '0.5',
        photoCode: '1234',
        phone: '13800138000',
      );
      expect(fallback.success, isFalse);
      expect(fallback.code, 2003);
      expect(fallback.message, '发送失败');

      final shape = await wrongShape.userMessageCode(
        doubleRandom: '0.5',
        photoCode: '1234',
        phone: '13800138000',
      );
      expect(shape.success, isFalse);
      expect(shape.code, isNull);
      expect(shape.message, '服务端返回格式异常');
    },
  );

  test(
    'userLogin rejection keeps the server msg and falls back when empty',
    () async {
      final rejected = _apiWithAdapter(
        _RecordingAdapter(
          (_) => _json(<String, dynamic>{'code': 1002, 'msg': '短信验证码已失效'}),
        ),
      );
      final noMessage = _apiWithAdapter(
        _RecordingAdapter((_) => _json(<String, dynamic>{'code': 1002})),
      );

      final result = await rejected.userLogin(
        phone: '13800138000',
        messageCode: '123456',
      );
      expect(result.success, isFalse);
      expect(result.code, 1002);
      expect(result.message, '短信验证码已失效');

      final fallback = await noMessage.userLogin(
        phone: '13800138000',
        messageCode: '123456',
      );
      expect(fallback.success, isFalse);
      expect(fallback.code, 1002);
      expect(fallback.message, '登录被拒绝');
    },
  );

  test(
    'an accepted login without account data is not blamed on the code',
    () async {
      final api = _apiWithAdapter(
        _RecordingAdapter(
          (_) =>
              _json(<String, dynamic>{'code': 0, 'data': <String, dynamic>{}}),
        ),
      );

      final result = await api.userLogin(
        phone: '13800138000',
        messageCode: '123456',
      );

      expect(result.success, isFalse);
      expect(result.code, isNull);
      expect(result.message, '登录已被接受，但响应缺少账号信息，请反馈此问题');
      expect(result.message, isNot(contains('验证码错误')));
    },
  );

  test('a rejected http status is reported as a network error', () async {
    final api = _apiWithAdapter(
      _RecordingAdapter(
        (_) => _json(<String, dynamic>{'code': 0}, statusCode: 500),
      ),
    );

    final login = await api.userLogin(
      phone: '13800138000',
      messageCode: '123456',
    );
    final send = await api.userMessageCode(
      doubleRandom: '0.5',
      photoCode: '1234',
      phone: '13800138000',
    );

    for (final result in <DrinkResult>[login, send]) {
      expect(result.success, isFalse);
      expect(result.code, isNull);
      expect(result.message, startsWith('网络错误：'));
      expect(result.message, isNot(contains('验证码错误')));
    }
  });

  test('an undecodable response body is reported as a network error', () async {
    final api = _apiWithAdapter(
      _RecordingAdapter(
        (_) => ResponseBody.fromString(
          '<html>gateway busy</html>',
          200,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      ),
    );

    final result = await api.userLogin(
      phone: '13800138000',
      messageCode: '123456',
    );

    expect(result.success, isFalse);
    expect(result.code, isNull);
    expect(result.message, startsWith('网络错误：'));
    expect(result.message, isNot(contains('验证码错误')));
  });
}

Map<String, dynamic> _ok() => <String, dynamic>{'code': 0, 'msg': ''};

Map<String, dynamic> _loginAccepted() => <String, dynamic>{
  'code': 0,
  'data': <String, dynamic>{
    'al': <String, dynamic>{'uid': 'u-1', 'eid': 'e-1', 'token': 'tk-1'},
  },
};

DrinkApi _apiWithAdapter(_RecordingAdapter adapter) {
  final api = DrinkApi.forTesting();
  api.setHttpClientAdapter(adapter);
  return api;
}

/// 大小写无关地取头：Dio 的请求头映射与大小写无关，
/// 断言不该依赖当初拼写的是哪一种。
String? _headerValue(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) {
      return entry.value?.toString();
    }
  }
  return null;
}

Set<String> _headerNames(RequestOptions options) =>
    options.headers.keys.map((key) => key.toLowerCase()).toSet();

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._respond);

  final FutureOr<ResponseBody> Function(RequestOptions options) _respond;
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<String> requestBodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      requestBodies.add(utf8.decode(bytes));
    }
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object? body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
