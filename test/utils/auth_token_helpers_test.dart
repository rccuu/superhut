import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/services/app_auth_storage.dart';
import 'package:superhut/pages/hutpages/hut_service_auth.dart';
import 'package:superhut/utils/hut_user_api.dart';
import 'package:superhut/utils/token.dart' as jwxt_token;

import '../support/secure_storage_mock.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'none'})));
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final storage = AppAuthStorage.instance;

  setUpAll(SecureStorageMock.install);
  tearDownAll(SecureStorageMock.uninstall);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureStorageMock.reset();
    jwxt_token.resetRenewTokenForTest();
  });

  tearDown(jwxt_token.resetRenewTokenForTest);

  test(
    'saveToken updates JWXT token and clears stale cached cookies',
    () async {
      await storage.saveJwxtSession(
        token: 'old-jwxt-token',
        cookie: 'existing-cookie',
      );

      await jwxt_token.saveToken('new-jwxt-token');

      expect(await jwxt_token.getToken(), 'new-jwxt-token');
      expect(await storage.readJwxtCookie(), isEmpty);
    },
  );

  test(
    'HutUserApi.getToken returns the cached HUT token from storage',
    () async {
      final api = HutUserApi();
      await storage.saveHutSession(
        token: 'cached-hut-token',
        refreshToken: 'cached-refresh-token',
        deviceId: 'cached-device-id',
      );

      expect(await api.getToken(), 'cached-hut-token');
    },
  );

  test(
    'HutUserApi.getToken migrates stored portal ticket into idToken',
    () async {
      final api = HutUserApi();
      final ticket = _fakeJwt({
        'idToken': 'embedded-id-token',
        'exp': 2000000000,
      });
      await storage.saveHutSession(
        token: ticket,
        refreshToken: 'cached-refresh-token',
        deviceId: 'cached-device-id',
      );

      expect(await api.getToken(), 'embedded-id-token');
      expect(await storage.readHutToken(), 'embedded-id-token');
      expect(await storage.readHutTicket(), ticket);
      expect(await api.getPortalTicket(), ticket);
    },
  );

  test('HutPortalSession extracts token and ticket from login data', () {
    final ticket = _fakeJwt({'idToken': 'portal-id-token', 'exp': 2000000000});

    final session = HutPortalSession.fromLoginData({
      'idToken': ticket,
      'refreshToken': 'refresh-token',
    });

    expect(session.token, 'portal-id-token');
    expect(session.ticket, ticket);
  });

  test('decodeHutJwtPayload scans signed and unsigned payload segments', () {
    final unsignedTicket = _fakeJwt({
      'idToken': 'unsigned-id-token',
      'exp': 2000000000,
    }).replaceFirst(RegExp(r'\.$'), '');
    final signedTicket =
        '${_fakeJwt({'idToken': 'signed-id-token', 'exp': 2000000000})}sig';

    expect(
      decodeHutJwtPayload(unsignedTicket)?['idToken'],
      'unsigned-id-token',
    );
    expect(decodeHutJwtPayload(signedTicket)?['idToken'], 'signed-id-token');
    expect(decodeHutJwtPayload('header.'), isNull);
    expect(decodeHutJwtPayload('not-a-jwt'), isNull);
  });

  test('describeHutUrlForLog keeps query and fragment values out of logs', () {
    final description = describeHutUrlForLog(
      'https://portal.hut.edu.cn/main.html'
      '?ticket=secret-ticket&redirect=true'
      '&service%20name=secret-service&ticket=second-ticket'
      '#/ServiceDetail?token=secret-token&name=score',
    );

    expect(
      description,
      'portal.hut.edu.cn/main.html queryKeys=[redirect, service name, ticket] '
      'fragment=/ServiceDetail',
    );
    expect(description, isNot(contains('secret-ticket')));
    expect(description, isNot(contains('second-ticket')));
    expect(description, isNot(contains('secret-service')));
    expect(description, isNot(contains('secret-token')));
    expect(description, isNot(contains('score')));
  });

  test('buildHutWebViewHeaders keeps profile specific headers', () {
    final type1Headers = buildHutWebViewHeaders(
      token: 'id-token',
      profile: HutWebViewHeaderProfile.type1,
    );
    final type2Headers = buildHutWebViewHeaders(
      token: 'id-token',
      profile: HutWebViewHeaderProfile.type2,
    );

    expect(type1Headers['User-Agent'], type2Headers['User-Agent']);
    expect(type1Headers['X-Id-Token'], 'id-token');
    expect(type1Headers['x-id-token'], 'id-token');
    expect(type2Headers['X-Id-Token'], 'id-token');
    expect(type2Headers['x-id-token'], 'id-token');

    expect(type1Headers['Cookie'], 'userToken=id-token');
    expect(type1Headers['X-Requested-With'], 'com.supwisdom.hut');
    expect(
      type1Headers['Accept-Language'],
      'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    );
    expect(type1Headers, isNot(contains('priority')));

    expect(type2Headers, isNot(contains('Cookie')));
    expect(type2Headers['x-requested-with'], 'com.supwisdom.hut');
    expect(
      type2Headers['accept-language'],
      'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    );
    expect(type2Headers['priority'], 'u=0, i');
  });

  test('FunctionItem.fromJson accepts current portal field names', () {
    final item = FunctionItem.fromJson({
      'ID': 'service-1',
      'SERVICE_NAME': '成绩查询',
      'SERVICE_PIC_URL': 'https://portal.hut.edu.cn/icon.png',
      'SERVICE_URL': 'https://example.hut.edu.cn/app',
      'SERVICE_TYPE': 2,
      'TOKEN_ACCEPT': [
        {'tokenType': 'header', 'tokenKey': 'X-Id-Token'},
      ],
    });

    expect(item.id, 'service-1');
    expect(item.serviceName, '成绩查询');
    expect(item.servicePicUrl, 'https://portal.hut.edu.cn/icon.png');
    expect(item.serviceUrl, 'https://example.hut.edu.cn/app');
    expect(item.serviceType, '2');
    expect(
      item.tokenAccept,
      '[{"tokenType":"header","tokenKey":"X-Id-Token"}]',
    );
  });

  test('buildHutPortalServiceEntryUrl builds ticket based portal redirect', () {
    final detailUrl = buildHutPortalServiceDetailUrl(
      serviceId: 'service-1',
      serviceName: '成绩查询',
      servicePicUrl: 'https://portal.hut.edu.cn/icon.png',
    );
    final entryUrl = buildHutPortalServiceEntryUrl(
      targetUrl: detailUrl,
      token: 'id-token',
      ticket: 'ticket-token',
    );
    final entryUri = Uri.parse(entryUrl);

    expect(entryUri.host, 'portal.hut.edu.cn');
    expect(entryUri.path, '/main.html');
    expect(entryUri.queryParameters['redirect'], 'true');
    expect(entryUri.queryParameters['ticket'], 'ticket-token');

    final targetUri = Uri.parse(entryUri.queryParameters['path']!);
    expect(targetUri.host, 'portal.hut.edu.cn');
    expect(targetUri.fragment, contains('/ServiceDetail'));
    expect(targetUri.fragment, contains('parentMenuList=service-1'));
  });

  test(
    'buildHutPortalServiceEntryUrl falls back to pure CAS service login',
    () {
      final entryUrl = buildHutPortalServiceEntryUrl(
        targetUrl: 'https://portal.hut.edu.cn/main.html#/ServiceDetail',
        token: 'id-token',
      );
      final entryUri = Uri.parse(entryUrl);

      expect(entryUri.host, 'mycas.hut.edu.cn');
      expect(entryUri.path, '/cas/login');
      expect(entryUri.queryParameters, isNot(contains('idToken')));
      expect(entryUri.queryParameters, isNot(contains('token')));

      final serviceUri = Uri.parse(entryUri.queryParameters['service']!);
      expect(serviceUri.host, 'portal.hut.edu.cn');
      expect(serviceUri.path, '/main.html');
      expect(serviceUri.queryParameters['redirect'], 'true');
    },
  );

  test('normalizeHutPortalUrl upgrades legacy portal entry urls', () {
    expect(
      normalizeHutPortalUrl(
        'https://portal.hut.edu.cn/portal_dist/portal_index.html#/ServiceDetail',
      ),
      'https://portal.hut.edu.cn/main.html#/ServiceDetail',
    );

    final normalizedEntryUrl = normalizeHutPortalUrl(
      'https://portal.hut.edu.cn/portal_dist/portal_index.html'
      '?path=https%3A%2F%2Fportal.hut.edu.cn%2Fportal_dist%2Fportal_index.html%23%2FServiceDetail'
      '&redirect=true&ticket=ticket-token',
    );
    final normalizedEntryUri = Uri.parse(normalizedEntryUrl);
    expect(normalizedEntryUri.path, '/main.html');
    expect(
      Uri.parse(normalizedEntryUri.queryParameters['path']!).path,
      '/main.html',
    );
    expect(normalizedEntryUri.queryParameters['ticket'], 'ticket-token');
  });

  test(
    'parseHutPortalFunctionList keeps labelled groups and folds flat items',
    () {
      final list = parseHutPortalFunctionList({
        'code': 0,
        'data': [
          {
            'label': '教学服务',
            'services': [
              {
                'id': 'service-1',
                'serviceName': '成绩查询',
                'serviceUrl': 'https://portal.hut.edu.cn/score',
                'serviceType': '2',
              },
            ],
          },
          {
            'id': 'service-2',
            'serviceName': '一卡通',
            'serviceUrl': 'https://portal.hut.edu.cn/card',
            'serviceType': '2',
          },
          {
            'children': [
              {
                'id': 'service-3',
                'serviceName': '空教室',
                'serviceUrl': 'https://portal.hut.edu.cn/room',
                'serviceType': '2',
              },
            ],
          },
        ],
      });

      expect(list.map((item) => item['label']), ['教学服务', '全部服务']);
      expect(
        (list.first['services'] as List<FunctionItem>).single.serviceName,
        '成绩查询',
      );
      final flatServices = list.last['services'] as List<FunctionItem>;
      expect(flatServices.map((item) => item.serviceName), ['一卡通', '空教室']);
    },
  );

  test(
    'HutUserApi.refreshToken returns false when credentials are missing',
    () async {
      final api = HutUserApi();

      expect(await api.refreshToken(), isFalse);
    },
  );

  testWidgets('renewToken reuses in-flight JWXT refresh work', (tester) async {
    await storage.saveLoginType('jwxt');
    await storage.saveJwxtCredentials(
      username: 'jwxt-user',
      password: 'jwxt-pass',
    );

    final loginCompleters = [Completer<bool>(), Completer<bool>()];
    var tokenChecks = 0;
    var loginCalls = 0;
    final loginUsers = <String>[];
    final loginPasswords = <String>[];

    jwxt_token.setRenewTokenTestOverrides(
      checkTokenValid: () async {
        tokenChecks++;
        return false;
      },
      loginHut: (userNo, password) {
        loginCalls++;
        loginUsers.add(userNo);
        loginPasswords.add(password);
        return loginCompleters[loginCalls - 1].future;
      },
    );

    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('home'));
          },
        ),
      ),
    );

    final first = jwxt_token.renewToken(pageContext);
    final second = jwxt_token.renewToken(pageContext);
    await tester.pump();

    expect(tokenChecks, 1);
    expect(loginCalls, 1);
    expect(loginUsers, ['jwxt-user']);
    expect(loginPasswords, ['jwxt-pass']);

    loginCompleters[0].complete(true);
    expect(await Future.wait([first, second]), [true, true]);

    final third = jwxt_token.renewToken(pageContext);
    await tester.pump();

    expect(tokenChecks, 2);
    expect(loginCalls, 2);
    expect(loginUsers, ['jwxt-user', 'jwxt-user']);
    expect(loginPasswords, ['jwxt-pass', 'jwxt-pass']);

    loginCompleters[1].complete(true);
    expect(await third, isTrue);
  });

  test('isLikelyHutLoginUrl detects HUT login redirects', () {
    expect(
      isLikelyHutLoginUrl(
        Uri.parse('https://mycas.hut.edu.cn/cas/login?service=test'),
      ),
      isTrue,
    );
    expect(
      isLikelyHutLoginUrl('https://portal.hut.edu.cn/login?redirect=/service'),
      isTrue,
    );
    expect(
      isLikelyHutLoginUrl('https://portal.hut.edu.cn/portal-api/v1/service'),
      isFalse,
    );
    expect(isLikelyHutLoginUrl('https://example.com/login'), isFalse);
  });
}
