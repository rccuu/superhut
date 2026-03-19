import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/services/app_auth_storage.dart';

import '../../support/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final storage = AppAuthStorage.instance;

  setUpAll(SecureStorageMock.install);
  tearDownAll(SecureStorageMock.uninstall);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureStorageMock.reset();
  });

  test('migrates legacy JWXT password into secure storage', () async {
    SharedPreferences.setMockInitialValues({
      'password': 'legacy-jwxt-password',
    });

    final password = await storage.readJwxtPassword();
    final prefs = await SharedPreferences.getInstance();

    expect(password, 'legacy-jwxt-password');
    expect(
      SecureStorageMock.read('secure_jwxt_password'),
      'legacy-jwxt-password',
    );
    expect(prefs.getString('password'), isNull);
  });

  test('migrates legacy HUT password into secure storage', () async {
    SharedPreferences.setMockInitialValues({'hutPassword': 'legacy-hut-pass'});

    final password = await storage.readHutPassword();
    final prefs = await SharedPreferences.getInstance();

    expect(password, 'legacy-hut-pass');
    expect(SecureStorageMock.read('secure_hut_password'), 'legacy-hut-pass');
    expect(prefs.getString('hutPassword'), isNull);
  });

  test(
    'saveJwxtCredentials falls back to legacy prefs when secure storage write fails',
    () async {
      SecureStorageMock.setFailures(write: true);

      await storage.saveJwxtCredentials(
        username: 'jwxt-user',
        password: 'jwxt-pass',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(await storage.readJwxtUsername(), 'jwxt-user');
      expect(prefs.getString('password'), 'jwxt-pass');
      expect(SecureStorageMock.read('secure_jwxt_password'), isNull);
      expect(await storage.readJwxtPassword(), 'jwxt-pass');
    },
  );

  test(
    'saveHutCredentials falls back to legacy prefs when secure storage write fails',
    () async {
      SecureStorageMock.setFailures(write: true);

      await storage.saveHutCredentials(
        username: 'hut-user',
        password: 'hut-pass',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(await storage.readHutUsername(), 'hut-user');
      expect(prefs.getString('hutPassword'), 'hut-pass');
      expect(SecureStorageMock.read('secure_hut_password'), isNull);
      expect(await storage.readHutPassword(), 'hut-pass');
    },
  );

  test('persists and reads HUT session helper values', () async {
    await storage.saveHutSession(
      token: 'hut-token',
      refreshToken: 'hut-refresh-token',
      deviceId: 'device-123',
    );

    expect(await storage.readHutToken(), 'hut-token');
    expect(await storage.readHutRefreshToken(), 'hut-refresh-token');
    expect(await storage.readHutDeviceId(), 'device-123');
    expect(await storage.isHutLoggedIn(), isTrue);
  });

  test(
    'clearAllAuthData removes auth state but preserves non-auth prefs',
    () async {
      await storage.setFirstOpen(false);
      await storage.saveLoginType('jwxt');
      await storage.saveJwxtSession(token: 'jwxt-token', cookie: 'jwxt-cookie');
      await storage.saveHutSession(
        token: 'hut-token',
        refreshToken: 'hut-refresh',
        deviceId: 'hut-device',
      );
      await storage.saveJwxtCredentials(
        username: 'jwxt-user',
        password: 'jwxt-pass',
      );
      await storage.saveHutCredentials(
        username: 'hut-user',
        password: 'hut-pass',
      );
      await storage.saveProfile(
        name: 'Super Hut',
        entranceYear: '2023',
        academyName: 'CS',
        clsName: '1',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('yxzxf', '1');
      await prefs.setString('zxfjd', '2');
      await prefs.setString('pjxfjd', '3');
      await prefs.setString('nonAuthKey', 'keep-me');

      await storage.clearAllAuthData();

      expect(await storage.readJwxtToken(), isEmpty);
      expect(await storage.readJwxtCookie(), isEmpty);
      expect(await storage.readHutToken(), isEmpty);
      expect(await storage.readHutRefreshToken(), isEmpty);
      expect(await storage.readHutDeviceId(), isEmpty);
      expect(await storage.readJwxtUsername(), isEmpty);
      expect(await storage.readHutUsername(), isEmpty);
      expect(await storage.readJwxtPassword(), isEmpty);
      expect(await storage.readHutPassword(), isEmpty);
      expect(await storage.readLoginType(), isEmpty);
      expect(await storage.isHutLoggedIn(), isFalse);
      expect(await storage.isFirstOpen(), isFalse);
      expect(prefs.getString('name'), isNull);
      expect(prefs.getString('entranceYear'), isNull);
      expect(prefs.getString('academyName'), isNull);
      expect(prefs.getString('clsName'), isNull);
      expect(prefs.getString('yxzxf'), isNull);
      expect(prefs.getString('zxfjd'), isNull);
      expect(prefs.getString('pjxfjd'), isNull);
      expect(prefs.getString('nonAuthKey'), 'keep-me');
      expect(SecureStorageMock.read('secure_jwxt_password'), isNull);
      expect(SecureStorageMock.read('secure_hut_password'), isNull);
    },
  );
}
