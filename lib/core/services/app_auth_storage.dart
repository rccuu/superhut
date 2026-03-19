import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

class AppAuthStorage {
  AppAuthStorage._();

  static final AppAuthStorage instance = AppAuthStorage._();

  static const _jwxtPasswordKey = 'secure_jwxt_password';
  static const _hutPasswordKey = 'secure_hut_password';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> setFirstOpen(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool('isFirstOpen', value);
  }

  Future<bool> isFirstOpen() async {
    final prefs = await _prefs;
    return prefs.getBool('isFirstOpen') ?? true;
  }

  Future<void> saveJwxtSession({
    required String token,
    String cookie = '',
  }) async {
    final prefs = await _prefs;
    await prefs.setString('token', token);
    await prefs.setString('my_client_ticket', cookie);
  }

  Future<String> readJwxtToken() async {
    final prefs = await _prefs;
    return prefs.getString('token') ?? '';
  }

  Future<String> readJwxtCookie() async {
    final prefs = await _prefs;
    return prefs.getString('my_client_ticket') ?? '';
  }

  Future<void> saveLoginType(String value) async {
    final prefs = await _prefs;
    await prefs.setString('loginType', value);
  }

  Future<String> readLoginType() async {
    final prefs = await _prefs;
    return prefs.getString('loginType') ?? '';
  }

  Future<void> saveJwxtCredentials({
    required String username,
    required String password,
  }) async {
    final prefs = await _prefs;
    await prefs.setString('user', username);
    await _writePasswordWithFallback(
      secureKey: _jwxtPasswordKey,
      legacyKey: 'password',
      password: password,
      label: 'JWXT',
    );
  }

  Future<String> readJwxtUsername() async {
    final prefs = await _prefs;
    return prefs.getString('user') ?? '';
  }

  Future<String> readJwxtPassword() {
    return _readPasswordWithMigration(
      legacyKey: 'password',
      secureKey: _jwxtPasswordKey,
    );
  }

  Future<void> saveHutCredentials({
    required String username,
    required String password,
  }) async {
    final prefs = await _prefs;
    await prefs.setString('hutUsername', username);
    await _writePasswordWithFallback(
      secureKey: _hutPasswordKey,
      legacyKey: 'hutPassword',
      password: password,
      label: 'HUT',
    );
  }

  Future<String> readHutUsername() async {
    final prefs = await _prefs;
    return prefs.getString('hutUsername') ?? '';
  }

  Future<String> readHutPassword() {
    return _readPasswordWithMigration(
      legacyKey: 'hutPassword',
      secureKey: _hutPasswordKey,
    );
  }

  Future<void> saveHutSession({
    required String token,
    required String refreshToken,
    required String deviceId,
  }) async {
    final prefs = await _prefs;
    await prefs.setString('hutToken', token);
    await prefs.setString('hutRefreshToken', refreshToken);
    await prefs.setString('deviceId', deviceId);
    await prefs.setBool('hutIsLogin', true);
  }

  Future<String> readHutToken() async {
    final prefs = await _prefs;
    return prefs.getString('hutToken') ?? '';
  }

  Future<String> readHutRefreshToken() async {
    final prefs = await _prefs;
    return prefs.getString('hutRefreshToken') ?? '';
  }

  Future<String> readHutDeviceId() async {
    final prefs = await _prefs;
    return prefs.getString('deviceId') ?? '';
  }

  Future<void> setHutLoginStatus(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool('hutIsLogin', value);
  }

  Future<bool> isHutLoggedIn() async {
    final prefs = await _prefs;
    return prefs.getBool('hutIsLogin') ?? false;
  }

  Future<void> clearAllAuthData() async {
    final prefs = await _prefs;
    const authKeys = <String>[
      'user',
      'password',
      'hutUsername',
      'hutPassword',
      'token',
      'my_client_ticket',
      'hutToken',
      'hutRefreshToken',
      'deviceId',
      'loginType',
      'hutIsLogin',
      'name',
      'entranceYear',
      'academyName',
      'clsName',
      'yxzxf',
      'zxfjd',
      'pjxfjd',
    ];

    for (final key in authKeys) {
      await prefs.remove(key);
    }

    await _deleteSecurePassword(_jwxtPasswordKey, label: 'JWXT');
    await _deleteSecurePassword(_hutPasswordKey, label: 'HUT');
  }

  Future<void> clearJwxtCredentials() async {
    final prefs = await _prefs;
    await prefs.remove('user');
    await prefs.remove('password');
    await prefs.remove('token');
    await prefs.remove('my_client_ticket');
    await _deleteSecurePassword(_jwxtPasswordKey, label: 'JWXT');
  }

  Future<void> clearHutCredentials() async {
    final prefs = await _prefs;
    await prefs.remove('hutUsername');
    await prefs.remove('hutPassword');
    await prefs.remove('hutToken');
    await prefs.remove('hutRefreshToken');
    await prefs.remove('deviceId');
    await prefs.remove('hutIsLogin');
    await _deleteSecurePassword(_hutPasswordKey, label: 'HUT');
  }

  Future<void> saveProfile({
    required String name,
    required String entranceYear,
    required String academyName,
    required String clsName,
  }) async {
    final prefs = await _prefs;
    await prefs.setString('name', name);
    await prefs.setString('entranceYear', entranceYear);
    await prefs.setString('academyName', academyName);
    await prefs.setString('clsName', clsName);
  }

  Future<String> _readPasswordWithMigration({
    required String legacyKey,
    required String secureKey,
  }) async {
    try {
      final secureValue = await _secureStorage.read(key: secureKey);
      if (secureValue != null && secureValue.isNotEmpty) {
        return secureValue;
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to read password from secure storage',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final prefs = await _prefs;
    final legacyValue = prefs.getString(legacyKey) ?? '';
    if (legacyValue.isEmpty) {
      return '';
    }

    try {
      await _secureStorage.write(key: secureKey, value: legacyValue);
      await prefs.remove(legacyKey);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to migrate password into secure storage',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return legacyValue;
  }

  Future<void> _writePasswordWithFallback({
    required String secureKey,
    required String legacyKey,
    required String password,
    required String label,
  }) async {
    final prefs = await _prefs;
    try {
      await _secureStorage.write(key: secureKey, value: password);
      await prefs.remove(legacyKey);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to persist $label password to secure storage; falling back to SharedPreferences',
        error: error,
        stackTrace: stackTrace,
      );
      await prefs.setString(legacyKey, password);
    }
  }

  Future<void> _deleteSecurePassword(
    String secureKey, {
    required String label,
  }) async {
    try {
      await _secureStorage.delete(key: secureKey);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to clear $label password from secure storage',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
