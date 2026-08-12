import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/utils/hut_user_api.dart';

/// Builds a JWT with the given [payload] for testing [isHutJwtExpired].
/// The signature segment is arbitrary; only the payload is inspected.
String _buildJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  const signature = 'sig';
  return '$header.$body.$signature';
}

void main() {
  test('buildHutSmsInitPath is under /token/passwordless', () {
    expect(buildHutSmsInitPath(), '/token/passwordless/smsInit');
  });

  test('buildHutSmsSendPath puts mobile and nonce in query', () {
    final path = buildHutSmsSendPath(mobile: '13800138000', nonce: 'abc');
    expect(path.startsWith('/token/passwordless/smsSend?'), isTrue);
    expect(path, contains('mobile=13800138000'));
    expect(path, contains('nonce=abc'));
  });

  test('buildHutSmsLoginPath includes required query keys', () {
    final path = buildHutSmsLoginPath(
      mobile: '13800138000',
      smscode: '123456',
      appId: 'com.supwisdom.hut',
      deviceId: 'abcdefghijklmnopqrstuvwx',
      osType: 'android',
      geo: '',
      nonce: 'oUOHnB',
    );
    expect(path, contains('/token/passwordless/smsLogin?'));
    expect(path, contains('mobile=13800138000'));
    expect(path, contains('smscode=123456'));
    expect(path, contains('appId=com.supwisdom.hut'));
    expect(path, contains('deviceId=abcdefghijklmnopqrstuvwx'));
    expect(path, contains('osType=android'));
    expect(path, contains('nonce=oUOHnB'));
    // Official iOS client always sends clientId (default "CLIENT_ID") so the
    // mycas SSO origin check does not reject the request.
    expect(path, contains('clientId=CLIENT_ID'));
  });

  test('buildHutSmsLoginPath allows overriding clientId', () {
    final path = buildHutSmsLoginPath(
      mobile: '13800138000',
      smscode: '123456',
      appId: 'com.supwisdom.hut',
      deviceId: 'abcdefghijklmnopqrstuvwx',
      osType: 'iOS',
      geo: '',
      nonce: 'oUOHnB',
      clientId: 'persisted-client',
    );
    expect(path, contains('clientId=persisted-client'));
    expect(path, contains('osType=iOS'));
  });

  test('parseHutSmsInitResponse reads nonce on code 0', () {
    final result = parseHutSmsInitResponse({
      'code': 0,
      'data': {
        'success': true,
        'message': 'SMS init success',
        'nonce': 'oUOHnB',
      },
    });
    expect(result.success, isTrue);
    expect(result.nonce, 'oUOHnB');
  });

  test('parseHutSmsInitResponse fails without nonce', () {
    final result = parseHutSmsInitResponse({
      'code': 0,
      'data': {'success': true, 'message': 'ok'},
    });
    expect(result.success, isFalse);
    expect(result.nonce, isNull);
  });

  test('parseHutSmsSendResponse fails on non-zero code with message', () {
    final result = parseHutSmsSendResponse({
      'code': 1,
      'message': '发送过于频繁',
      'data': null,
    });
    expect(result.success, isFalse);
    expect(result.message, contains('频繁'));
  });

  test('parseHutSmsSendResponse reads top-level error field', () {
    // Real mycas responses use {"code":-1,"error":"..."} without message.
    final result = parseHutSmsSendResponse({
      'code': -1,
      'error': 'Nonce invalid',
    });
    expect(result.success, isFalse);
    expect(result.message, '验证码已失效，请重新获取');
  });

  test('parseHutSmsLoginTokenData succeeds when idToken present', () {
    final result = parseHutSmsLoginTokenData({
      'code': 0,
      'data': {'idToken': 'tok', 'refreshToken': 'ref'},
    });
    expect(result.success, isTrue);
  });

  test('parseHutSmsLoginTokenData fails when token missing', () {
    final result = parseHutSmsLoginTokenData({
      'code': 0,
      'data': {'refreshToken': 'ref'},
    });
    expect(result.success, isFalse);
  });

  test(
    'hutAuthResultFromTransportError prefers response body over network copy',
    () {
      // HUT passwordless endpoints return business failures as HTTP 4xx/5xx.
      // Dio throws DioException.badResponse; we must surface body text, not
      // the generic "网络异常" that hid successful SMS delivery from the UI.
      final result = hutAuthResultFromTransportError(
        statusCode: 500,
        responseData: {'code': -1, 'error': 'Secure Mobile invalid'},
      );
      expect(result.success, isFalse);
      expect(result.message, contains('安全手机'));
      expect(result.message, isNot(contains('网络')));
    },
  );

  test('hutAuthResultFromTransportError uses Spring message on 400', () {
    final result = hutAuthResultFromTransportError(
      statusCode: 400,
      responseData: {
        'timestamp': '2026-07-28T22:46:22.455+0800',
        'status': 400,
        'error': 'Bad Request',
        'message': 'This Phone Number not equals the Phone Number of send code',
        'path': '/token/passwordless/smsLogin',
      },
    );
    expect(result.success, isFalse);
    expect(result.message, contains('手机号'));
  });

  test(
    'hutAuthResultFromTransportError falls back for pure transport failure',
    () {
      final result = hutAuthResultFromTransportError(
        statusCode: null,
        responseData: null,
      );
      expect(result.success, isFalse);
      expect(result.message, '网络异常，请稍后重试');
    },
  );

  test('hutAuthResultFromTransportError localizes bare Bad request', () {
    // Invalid/expired nonce often comes back as English "Bad request" with no detail.
    final result = hutAuthResultFromTransportError(
      statusCode: 400,
      responseData: {
        'timestamp': '2026-07-29T07:38:48.660+0800',
        'status': 400,
        'error': 'Bad Request',
        'message': 'Bad request',
        'path': '/token/passwordless/smsLogin',
      },
    );
    expect(result.success, isFalse);
    expect(result.message, isNot(equals('Bad request')));
    expect(result.message, contains('验证码'));
  });

  test('hutAuthResultFromTransportError localizes 请求无效', () {
    final result = hutAuthResultFromTransportError(
      statusCode: 400,
      responseData: {
        'status': 400,
        'error': 'Bad Request',
        'message': '请求无效',
        'path': '/token/passwordless/smsLogin',
      },
    );
    expect(result.success, isFalse);
    expect(result.message, contains('验证码'));
  });

  test('parseHutSmsSendResponse keeps nonce from payload when present', () {
    final result = parseHutSmsSendResponse({
      'code': 0,
      'data': {'success': true, 'message': 'ok', 'nonce': 'from-send'},
    });
    expect(result.success, isTrue);
    expect(result.nonce, 'from-send');
  });

  test('hutResponseIndicatesNeedMfa detects flag', () {
    expect(
      hutResponseIndicatesNeedMfa({
        'code': 0,
        'data': {'needMfa': true, 'mfaState': 'xyz'},
      }),
      isTrue,
    );
    expect(
      hutResponseIndicatesNeedMfa({
        'code': 0,
        'data': {'idToken': 't'},
      }),
      isFalse,
    );
  });

  test('isPlausibleHutMobile and normalizeHutMobile', () {
    expect(isPlausibleHutMobile('13800138000'), isTrue);
    expect(isPlausibleHutMobile('138 0013 8000'), isTrue);
    expect(isPlausibleHutMobile('123'), isFalse);
    expect(normalizeHutMobile(' 138 0013 8000 '), '13800138000');
  });

  group('isHutJwtExpired', () {
    test('returns false for a JWT whose exp is in the future', () {
      final futureExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _buildJwt({'exp': futureExp});
      expect(isHutJwtExpired(token), isFalse);
    });

    test('returns true for a JWT whose exp has passed', () {
      final pastExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600;
      final token = _buildJwt({'exp': pastExp});
      expect(isHutJwtExpired(token), isTrue);
    });

    test('respects clockSkew tolerance', () {
      // exp is 30s in the future; with 60s skew it is still considered expired.
      final exp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 30;
      final token = _buildJwt({'exp': exp});
      expect(
        isHutJwtExpired(token, clockSkew: const Duration(seconds: 60)),
        isTrue,
      );
      expect(isHutJwtExpired(token), isFalse);
    });

    test('returns true for a non-JWT string (no dots)', () {
      expect(isHutJwtExpired('not-a-jwt'), isTrue);
      expect(isHutJwtExpired(''), isTrue);
    });

    test('returns true when payload is not valid base64/JSON', () {
      expect(isHutJwtExpired('header.!!!.sig'), isTrue);
    });

    test('returns true when exp is missing', () {
      final token = _buildJwt({'sub': 'no-exp'});
      expect(isHutJwtExpired(token), isTrue);
    });

    test('returns true when exp is non-numeric', () {
      final token = _buildJwt({'exp': 'soon'});
      expect(isHutJwtExpired(token), isTrue);
    });
  });

  group('extractHutJwtSubject', () {
    test('returns the trimmed account from sub', () {
      final token = _buildJwt({'sub': ' 20260001 '});
      expect(extractHutJwtSubject(token), '20260001');
    });

    test('returns null when sub is absent', () {
      final token = _buildJwt({'exp': 9999999999});
      expect(extractHutJwtSubject(token), isNull);
    });

    test('returns null when sub is empty', () {
      final token = _buildJwt({'sub': '   '});
      expect(extractHutJwtSubject(token), isNull);
    });

    test('returns null for a non-JWT string', () {
      expect(extractHutJwtSubject('not-a-jwt'), isNull);
      expect(extractHutJwtSubject(''), isNull);
    });

    test('returns null when the payload is not valid base64/JSON', () {
      expect(extractHutJwtSubject('header.!!!.sig'), isNull);
    });
  });
}
