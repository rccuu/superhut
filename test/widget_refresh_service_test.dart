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
    'syncCourseTableWidget passes payload to the platform channel',
    () async {
      String? invokedMethod;
      dynamic invokedArguments;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            invokedMethod = call.method;
            invokedArguments = call.arguments;
            return true;
          });

      final result = await WidgetRefreshService.syncCourseTableWidget(
        payloadJson: '{"date":"2026-03-27"}',
      );

      expect(result, isTrue);
      expect(invokedMethod, 'syncCourseTableWidget');
      expect(invokedArguments, {'payloadJson': '{"date":"2026-03-27"}'});
    },
  );

  test(
    'syncCourseTableWidget returns false when the platform call fails',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(
              code: 'sync_failed',
              message: 'sync failed',
            );
          });

      final result = await WidgetRefreshService.syncCourseTableWidget(
        payloadJson: '{}',
      );

      expect(result, isFalse);
    },
  );

  test('refreshCourseTableWidget delegates to syncCourseTableWidget', () async {
    String? invokedMethod;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          invokedMethod = call.method;
          return true;
        });

    final result = await WidgetRefreshService.refreshCourseTableWidget();

    expect(result, isTrue);
    expect(invokedMethod, 'syncCourseTableWidget');
  });

  test(
    'syncCourseTableWidget returns false when the platform channel is missing',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw MissingPluginException('missing channel');
          });

      final result = await WidgetRefreshService.syncCourseTableWidget(
        payloadJson: '{}',
      );

      expect(result, isFalse);
    },
  );
}
