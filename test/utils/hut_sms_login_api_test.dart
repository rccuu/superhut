import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/services/app_auth_storage.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../support/secure_storage_mock.dart';

String _buildJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  const signature = 'sig';
  return '$header.$body.$signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = AppAuthStorage.instance;

  setUpAll(SecureStorageMock.install);
  tearDownAll(SecureStorageMock.uninstall);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureStorageMock.reset();
  });

  test('completeSmsLoginFromResponseData saves the RAW smsLogin idToken', () async {
    final api = HutUserApi();
    // Official SMS success handler (sub_100079334) stores data.idToken VERBATIM
    // into kToken — no federatedBinding, no JWT decoding. We must persist the
    // exact token mycas issued so checkTokenValidity / CAS accept it.
    const rawIdToken = 'raw-id-token-from-smsLogin';
    final result = await api.completeSmsLoginFromResponseData(
      responseData: {
        'code': 0,
        'data': {
          'idToken': rawIdToken,
          'refreshToken': 'sms-refresh',
          'ticket': '',
        },
      },
      mobile: '13800138000',
      deviceId: 'abcdefghijklmnopqrstuvwx',
    );

    expect(result.success, isTrue);
    expect(await storage.readHutToken(), rawIdToken);
    expect(await storage.readHutRefreshToken(), 'sms-refresh');
    expect(await storage.readHutDeviceId(), 'abcdefghijklmnopqrstuvwx');
    expect(await storage.readLoginType(), 'hut');
    expect(await storage.readHutMobile(), '13800138000');
    // 验证码登录不写密码凭据
    expect(await storage.readHutUsername(), isEmpty);
    // Non-JWT idToken carries no `sub` → no hutAccount is persisted.
    expect(await storage.readHutAccount(), isEmpty);
  });

  test(
    'completeSmsLoginFromResponseData persists hutAccount from the JWT sub',
    () async {
      final futureExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _buildJwt({'sub': '20260001', 'exp': futureExp});
      final api = HutUserApi();
      final result = await api.completeSmsLoginFromResponseData(
        responseData: {
          'code': 0,
          'data': {'idToken': token, 'refreshToken': 'ref', 'ticket': ''},
        },
        mobile: '13800138000',
        deviceId: 'abcdefghijklmnopqrstuvwx',
      );

      expect(result.success, isTrue);
      expect(await storage.readHutToken(), token);
      expect(await storage.readHutAccount(), '20260001');
    },
  );

  test(
    'completeSmsLoginFromResponseData stores a JWT idToken verbatim, not decoded',
    () async {
      // If data.idToken is a JWT whose payload embeds a different idToken, we
      // must persist the RAW outer JWT — not the decoded inner token. Decoding
      // would persist a token mycas never issued, so checkTokenValidity / CAS
      // reject it as "登录状态已失效".
      final api = HutUserApi();
      const rawIdToken =
          'eyJhbGciOiJub25lIn0.eyJpZFRva2VuIjoiZW1iZWRkZWQtaW5ub2NlbnQifQ.';
      final result = await api.completeSmsLoginFromResponseData(
        responseData: {
          'code': 0,
          'data': {'idToken': rawIdToken, 'refreshToken': '', 'ticket': ''},
        },
        mobile: '13800138000',
        deviceId: 'abcdefghijklmnopqrstuvwx',
      );
      expect(result.success, isTrue);
      expect(await storage.readHutToken(), rawIdToken);
      expect(await storage.readHutToken(), isNot('embedded-innocent'));
    },
  );

  test('completeSmsLoginFromResponseData fails without token', () async {
    final api = HutUserApi();
    final result = await api.completeSmsLoginFromResponseData(
      responseData: {'code': 0, 'data': {}},
      mobile: '13800138000',
      deviceId: 'abcdefghijklmnopqrstuvwx',
    );
    expect(result.success, isFalse);
    expect(await storage.readHutToken(), isEmpty);
  });

  test(
    'checkTokenValidity asks the online validator for a fresh SMS token using hutAccount',
    () async {
      // SMS sessions persist hutAccount (the JWT `sub`) so userOnlineDetect has
      // an account to validate against — mirroring the official client. A fresh,
      // unexpired token clears the local fail-fast gate and reaches the online
      // validator with the persisted account.
      final futureExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _buildJwt({'sub': '20260001', 'exp': futureExp});
      await storage.saveHutSession(
        token: token,
        refreshToken: '',
        deviceId: 'sms-device',
      );
      await storage.saveHutAuthMethod(kHutAuthMethodSms);
      await storage.saveHutAccount('20260001');

      String? seenToken;
      String? seenAccount;
      String? seenDeviceId;
      final api = HutUserApi(
        onlineTokenValidator: ({
          required token,
          required account,
          required deviceId,
        }) async {
          seenToken = token;
          seenAccount = account;
          seenDeviceId = deviceId;
          return true;
        },
      );

      expect(await api.checkTokenValidity(), isTrue);
      expect(seenToken, token);
      expect(seenAccount, '20260001');
      expect(seenDeviceId, 'sms-device');
    },
  );

  test(
    'checkTokenValidity migrates a legacy SMS session by extracting sub',
    () async {
      // A session persisted before hutAccount/hutAuthMethod existed: no stored
      // account, no marker, no username — inferred SMS, and hutAccount is
      // bootstrapped from the JWT `sub` before the online check.
      final futureExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _buildJwt({'sub': 'legacy-account', 'exp': futureExp});
      await storage.saveHutSession(
        token: token,
        refreshToken: '',
        deviceId: 'legacy-device',
      );

      String? seenAccount;
      final api = HutUserApi(
        onlineTokenValidator: ({
          required token,
          required account,
          required deviceId,
        }) async {
          seenAccount = account;
          return false;
        },
      );

      expect(await api.checkTokenValidity(), isFalse);
      expect(seenAccount, 'legacy-account');
      expect(await storage.readHutAccount(), 'legacy-account');
    },
  );

  group('SMS session account switch and token expiry', () {
    test('SMS login clears old password credentials and marks auth method',
        () async {
      // Simulate a prior password login.
      await storage.saveHutCredentials(
        username: 'olduser',
        password: 'oldpass',
      );
      await storage.saveHutAuthMethod(kHutAuthMethodPassword);

      final api = HutUserApi();
      final result = await api.completeSmsLoginFromResponseData(
        responseData: {
          'code': 0,
          'data': {'idToken': 'new-id', 'refreshToken': 'new-ref'},
        },
        mobile: '13800138000',
        deviceId: 'abcdefghijklmnopqrstuvwx',
      );

      expect(result.success, isTrue);
      expect(await storage.readHutToken(), 'new-id');
      expect(await storage.readHutMobile(), '13800138000');
      // Old password credentials cleared + explicit SMS marker.
      expect(await storage.readHutUsername(), isEmpty);
      expect(await storage.readHutPassword(), isEmpty);
      expect(await storage.readHutAuthMethod(), kHutAuthMethodSms);
    });

    test('checkTokenValidity returns false for an expired SMS JWT', () async {
      final api = HutUserApi();
      final pastExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600;
      await storage.saveHutSession(
        token: _buildJwt({'exp': pastExp}),
        refreshToken: '',
        deviceId: 'abcdefghijklmnopqrstuvwx',
      );
      await storage.saveHutAuthMethod(kHutAuthMethodSms);

      expect(await api.checkTokenValidity(), isFalse);
    });

    test('checkTokenValidity returns false for a corrupted SMS token',
        () async {
      final api = HutUserApi();
      await storage.saveHutSession(
        token: 'not-a-jwt',
        refreshToken: '',
        deviceId: 'abcdefghijklmnopqrstuvwx',
      );
      await storage.saveHutAuthMethod(kHutAuthMethodSms);

      expect(await api.checkTokenValidity(), isFalse);
    });
  });

  group('refreshToken SMS branch', () {
    test('returns true and keeps state for a valid SMS token', () async {
      final futureExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final token = _buildJwt({'sub': '20260001', 'exp': futureExp});
      await storage.saveHutSession(
        token: token,
        refreshToken: 'ref',
        deviceId: 'abcdefghijklmnopqrstuvwx',
      );
      await storage.saveHutMobile('13800138000');
      await storage.saveHutAuthMethod(kHutAuthMethodSms);

      final api = HutUserApi(
        onlineTokenValidator: ({
          required token,
          required account,
          required deviceId,
        }) async => true,
      );

      expect(await api.refreshToken(), isTrue);
      expect(await storage.readHutToken(), isNotEmpty);
      expect(await storage.readHutAuthMethod(), kHutAuthMethodSms);
    });

    test('returns false and clears state (keeping mobile) when token invalid',
        () async {
      final api = HutUserApi();
      await storage.saveHutSession(
        token: 'corrupted',
        refreshToken: 'ref',
        deviceId: 'abcdefghijklmnopqrstuvwx',
      );
      await storage.saveHutMobile('13800138000');
      await storage.saveHutAuthMethod(kHutAuthMethodSms);

      expect(await api.refreshToken(), isFalse);
      expect(await storage.readHutToken(), isEmpty);
      expect(await storage.readHutAuthMethod(), isEmpty);
      expect(await storage.isHutLoggedIn(), isFalse);
      // Mobile preserved so the user can re-request a code without retyping.
      expect(await storage.readHutMobile(), '13800138000');
    });
  });
}
