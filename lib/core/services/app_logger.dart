import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(message);
    if (error != null) {
      debugPrint('error: $error');
    }
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }
}
