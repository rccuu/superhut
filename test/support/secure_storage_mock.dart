import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class SecureStorageMock {
  SecureStorageMock._();

  static const MethodChannel channel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  static final Map<String, String> _store = <String, String>{};
  static bool _throwOnRead = false;
  static bool _throwOnWrite = false;
  static bool _throwOnDelete = false;

  static void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _handleMethodCall);
  }

  static void reset([Map<String, String> initialValues = const {}]) {
    _store
      ..clear()
      ..addAll(initialValues);
    _throwOnRead = false;
    _throwOnWrite = false;
    _throwOnDelete = false;
  }

  static void setFailures({
    bool read = false,
    bool write = false,
    bool delete = false,
  }) {
    _throwOnRead = read;
    _throwOnWrite = write;
    _throwOnDelete = delete;
  }

  static void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    _store.clear();
  }

  static String? read(String key) => _store[key];

  static Future<Object?> _handleMethodCall(MethodCall call) async {
    final arguments =
        (call.arguments as Map<Object?, Object?>?)?.cast<String, Object?>();
    final key = arguments?['key'] as String?;

    switch (call.method) {
      case 'read':
        if (_throwOnRead) {
          throw PlatformException(code: 'mock-read-failure');
        }
        return key == null ? null : _store[key];
      case 'write':
        if (_throwOnWrite) {
          throw PlatformException(code: 'mock-write-failure');
        }
        if (key != null) {
          _store[key] = arguments?['value'] as String? ?? '';
        }
        return null;
      case 'delete':
        if (_throwOnDelete) {
          throw PlatformException(code: 'mock-delete-failure');
        }
        if (key != null) {
          _store.remove(key);
        }
        return null;
      case 'deleteAll':
        _store.clear();
        return null;
      case 'containsKey':
        return key != null && _store.containsKey(key);
      case 'readAll':
        return Map<String, String>.from(_store);
      case 'isProtectedDataAvailable':
        return true;
      default:
        return null;
    }
  }
}
