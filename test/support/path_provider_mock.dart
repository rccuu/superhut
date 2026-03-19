import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class PathProviderMock {
  PathProviderMock._();

  static const MethodChannel channel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  static String _applicationDocumentsPath = '';

  static void install({String applicationDocumentsPath = ''}) {
    _applicationDocumentsPath = applicationDocumentsPath;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _handleMethodCall);
  }

  static void updateApplicationDocumentsPath(String path) {
    _applicationDocumentsPath = path;
  }

  static void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    _applicationDocumentsPath = '';
  }

  static Future<String?> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getApplicationDocumentsDirectory':
      case 'getApplicationSupportDirectory':
      case 'getTemporaryDirectory':
        return _applicationDocumentsPath;
      default:
        return null;
    }
  }
}
