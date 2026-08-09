import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/services/app_auth_storage.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../support/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = AppAuthStorage.instance;

  setUpAll(SecureStorageMock.install);
  tearDownAll(SecureStorageMock.uninstall);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureStorageMock.reset();
  });

  test('completeSmsLoginFromResponseData saves the federatedBinding token', () async {
    final api = HutUserApi();
    // smsLogin returns an INTERMEDIATE idToken; the persisted token must come
    // from the federatedBinding response, not the smsLogin response.
    final result = await api.completeSmsLoginFromResponseData(
      responseData: {
        'code': 0,
        'data': {
          'idToken': 'intermediate-id-token',
          'refreshToken': 'sms-refresh',
          'ticket': '',
        },
      },
      mobile: '13800138000',
      deviceId: 'abcdefghijklmnopqrstuvwx',
      nonce: 'init-nonce',
      federatedBinding: ({required idToken, required nonce}) async {
        expect(idToken, 'intermediate-id-token');
        expect(nonce, 'init-nonce');
        return (
          result: null,
          data: {
            'idToken': 'final-id-token',
            'refreshToken': 'final-refresh',
            'ticket': '',
          },
        );
      },
    );

    expect(result.success, isTrue);
    expect(await storage.readHutToken(), 'final-id-token');
    expect(await storage.readHutRefreshToken(), 'final-refresh');
    expect(await storage.readHutDeviceId(), 'abcdefghijklmnopqrstuvwx');
    expect(await storage.readLoginType(), 'hut');
    expect(await storage.readHutMobile(), '13800138000');
    // 验证码登录不写密码凭据
    expect(await storage.readHutUsername(), isEmpty);
  });

  test('completeSmsLoginFromResponseData surfaces federatedBinding failure', () async {
    final api = HutUserApi();
    final result = await api.completeSmsLoginFromResponseData(
      responseData: {
        'code': 0,
        'data': {'idToken': 'intermediate-id-token', 'refreshToken': '', 'ticket': ''},
      },
      mobile: '13800138000',
      deviceId: 'abcdefghijklmnopqrstuvwx',
      federatedBinding: ({required idToken, required nonce}) async {
        return (
          result: const HutAuthResult(success: false, message: '绑定失败'),
          data: null,
        );
      },
    );
    expect(result.success, isFalse);
    expect(result.message, contains('绑定失败'));
    expect(await storage.readHutToken(), isEmpty);
  });

  test(
    'completeSmsLoginFromResponseData passes the RAW smsLogin idToken to federatedBinding',
    () async {
      // smsLogin may return data.idToken as a JWT whose payload embeds a
      // different idToken. federatedBinding must receive the RAW outer token
      // mycas issued for this session, not a decoded/transformed variant —
      // otherwise mycas rejects it as "exception.federated.login.state.invalid".
      final api = HutUserApi();
      // A JWT with an embedded idToken in its payload.
      const rawIdToken =
          'eyJhbGciOiJub25lIn0.eyJpZFRva2VuIjoiZW1iZWRkZWQtaW5ub2NlbnQifQ.';
      String? receivedToken;
      await api.completeSmsLoginFromResponseData(
        responseData: {
          'code': 0,
          'data': {'idToken': rawIdToken, 'refreshToken': '', 'ticket': ''},
        },
        mobile: '13800138000',
        deviceId: 'abcdefghijklmnopqrstuvwx',
        federatedBinding: ({required idToken, required nonce}) async {
          receivedToken = idToken;
          return (
            result: const HutAuthResult(success: false, message: 'stop'),
            data: null,
          );
        },
      );
      expect(receivedToken, rawIdToken);
      expect(receivedToken, isNot('embedded-innocent'));
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

  test('buildHutFederatedBindingPath is under /token/federation', () {
    expect(buildHutFederatedBindingPath(), '/token/federation/federatedBinding');
  });
}
