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

  test('saveHutMobile then readHutMobile roundtrip', () async {
    await storage.saveHutMobile('13800138000');
    expect(await storage.readHutMobile(), '13800138000');
  });

  test('clearHutCredentials removes hutMobile', () async {
    await storage.saveHutMobile('13800138000');
    await storage.saveHutSession(token: 't', refreshToken: 'r', deviceId: 'd');
    await storage.clearHutCredentials();
    expect(await storage.readHutMobile(), isEmpty);
  });

  test('clearAllAuthData removes hutMobile', () async {
    await storage.saveHutMobile('13800138000');
    await storage.clearAllAuthData();
    expect(await storage.readHutMobile(), isEmpty);
  });
}
