import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/services/app_auth_storage.dart';
import 'package:superhut/utils/hut_user_api.dart';
import 'package:superhut/utils/token.dart' as jwxt_token;

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
}
