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
  });

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
    'checkTokenValidity trusts a fresh SMS token without calling userOnlineDetect',
    () async {
      // SMS/passwordless sessions persist no hutUsername. The official client
      // does not re-validate a freshly minted SMS token via userOnlineDetect,
      // and doing so made the CAS bootstrap throw "智慧工大登录状态已失效" right
      // after a successful SMS login. With an empty username, validity must be
      // trusted (the token was just issued) — this must not hit the network,
      // which would fail the test with no overrides if it did.
      final api = HutUserApi();
      await storage.saveHutSession(
        token: 'fresh-sms-token',
        refreshToken: '',
        deviceId: 'abcdefghijklmnopqrstuvwx',
      );
      await storage.saveHutMobile('13800138000');

      expect(await api.checkTokenValidity(), isTrue);
    },
  );
}
