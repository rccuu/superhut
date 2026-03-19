import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/widget_refresh_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'com.superhut.rice.superhut/coursetable_widget',
  );

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'refreshCourseTableWidget returns true when the platform call succeeds',
    () async {
      String? invokedMethod;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            invokedMethod = call.method;
            return true;
          });

      final result = await WidgetRefreshService.refreshCourseTableWidget();

      expect(result, isTrue);
      expect(invokedMethod, 'refreshCourseTableWidget');
    },
  );

  test(
    'refreshCourseTableWidget returns false when the platform call fails',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'refresh_failed',
              message: 'refresh failed',
            );
          });

      final result = await WidgetRefreshService.refreshCourseTableWidget();

      expect(result, isFalse);
    },
  );

  test(
    'refreshCourseTableWidget returns false when the platform channel is missing',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw MissingPluginException('missing channel');
          });

      final result = await WidgetRefreshService.refreshCourseTableWidget();

      expect(result, isFalse);
    },
  );
}
