import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';

/// 冷启动时的 Token 读取时序。
///
/// 独立 App 的旧实现在单例构造后立刻发请求，Authorization 还是空串，
/// 服务端因此回 -99，用户必须再登录一次。这里钉住「第一个鉴权请求就带上
/// 本地已保存的 Token」这一修复结果。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tokenKey = 'drink798UsrApiToken';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'the first auth request carries the token saved before startup',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        tokenKey: jsonEncode(<String, String>{
          'uid': 'u-1',
          'eid': 'e-1',
          'token': 'saved-token',
        }),
      });

      final adapter = _RecordingAdapter();
      // 构造后不做任何等待就发请求，模拟冷启动的第一屏。
      final api = DrinkApi.forTesting()..setHttpClientAdapter(adapter);
      final result = await api.startDrink(id: 'dev-9');

      expect(result.success, isTrue);
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.headers['Authorization'], 'saved-token');
      expect(await api.getToken(), 'saved-token');
    },
  );

  test(
    'every auth request after startup keeps carrying the saved token',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        tokenKey: jsonEncode(<String, String>{
          'uid': 'u-1',
          'eid': 'e-1',
          'token': 'saved-token',
        }),
      });

      final adapter = _RecordingAdapter();
      final api = DrinkApi.forTesting()..setHttpClientAdapter(adapter);

      await api.startDrink(id: 'dev-9');
      await api.endDrink(id: 'dev-9');

      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.map((r) => r.headers['Authorization']), <String>[
        'saved-token',
        'saved-token',
      ]);
    },
  );

  test(
    'a corrupted non-object token is logged out, dropped from prefs',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        tokenKey: '["not","an","object"]',
      });

      final adapter = _RecordingAdapter();
      final api = DrinkApi.forTesting()..setHttpClientAdapter(adapter);

      await expectLater(api.startDrink(id: 'dev-9'), completes);

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.headers['Authorization'], isEmpty);
      expect(await api.getToken(), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(tokenKey), isNull);
    },
  );

  test('local JSON that cannot be parsed never breaks a request', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      tokenKey: '{"uid": ',
    });

    final adapter = _RecordingAdapter();
    final api = DrinkApi.forTesting()..setHttpClientAdapter(adapter);

    await expectLater(api.startDrink(id: 'dev-9'), completes);
    expect(adapter.requests.single.headers['Authorization'], isEmpty);
    expect(await api.getToken(), isEmpty);

    // 坏数据留在本地也没关系：下一次保存会整体覆盖它。
    await api.setToken(token: 'fresh-token');
    final prefs = await SharedPreferences.getInstance();
    expect(
      (jsonDecode(prefs.getString(tokenKey)!) as Map<String, dynamic>)['token'],
      'fresh-token',
    );
  });

  test(
    'a token saved right after startup is not clobbered by the late read',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        tokenKey: jsonEncode(<String, String>{
          'uid': 'old-uid',
          'eid': 'old-eid',
          'token': 'stale-token',
        }),
      });

      final adapter = _RecordingAdapter();
      final api = DrinkApi.forTesting()..setHttpClientAdapter(adapter);

      // 启动时的初次读取还没回来就先保存，保存必须排在读取之后落地。
      await api.setToken(token: 'fresh-token');

      expect(await api.getToken(), 'fresh-token');
      final prefs = await SharedPreferences.getInstance();
      final stored =
          jsonDecode(prefs.getString(tokenKey)!) as Map<String, dynamic>;
      expect(stored['token'], 'fresh-token');
      expect(stored['uid'], 'old-uid');

      await api.startDrink(id: 'dev-9');
      expect(adapter.requests.single.headers['Authorization'], 'fresh-token');
    },
  );

  test(
    'a successful login persists the token for the next auth request',
    () async {
      final adapter = _RecordingAdapter();
      final api = DrinkApi.forTesting()..setHttpClientAdapter(adapter);

      final login = await api.userLogin(
        phone: '13800138000',
        messageCode: '123456',
      );
      expect(login.success, isTrue);

      expect(await api.getToken(), 'tk-1');
      await api.startDrink(id: 'dev-9');
      expect(adapter.requests.last.headers['Authorization'], 'tk-1');

      final prefs = await SharedPreferences.getInstance();
      final stored =
          jsonDecode(prefs.getString(tokenKey)!) as Map<String, dynamic>;
      expect(stored['uid'], 'u-1');
      expect(stored['eid'], 'e-1');
      expect(stored['token'], 'tk-1');
      expect(prefs.getBool('hui798IsLogin'), isTrue);
    },
  );

  test(
    'a cold start without stored credentials sends an empty token',
    () async {
      final adapter = _RecordingAdapter();
      final api = DrinkApi.forTesting()..setHttpClientAdapter(adapter);

      await api.startDrink(id: 'dev-9');

      expect(adapter.requests.single.headers['Authorization'], isEmpty);
      expect(await api.getToken(), isEmpty);

      // 没有本地凭据时会写入一份空的默认结构，供后续登录覆盖。
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString(tokenKey)!), <String, String>{
        'uid': '',
        'eid': '',
        'token': '',
      });
    },
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.uri.path;
    final body =
        path == '/api/v1/acc/login'
            ? <String, dynamic>{
              'code': 0,
              'data': <String, dynamic>{
                'al': <String, dynamic>{
                  'uid': 'u-1',
                  'eid': 'e-1',
                  'token': 'tk-1',
                },
              },
            }
            : <String, dynamic>{'code': 0, 'msg': ''};

    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
