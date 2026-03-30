import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'android manifest declares camera permission for QR schedule import',
    () {
      final manifest = File('android/app/src/main/AndroidManifest.xml');

      expect(manifest.existsSync(), isTrue);
      expect(
        manifest.readAsStringSync(),
        contains('android.permission.CAMERA'),
      );
    },
  );

  test(
    'android manifest registers boot completed for course widget restore',
    () {
      final manifest = File('android/app/src/main/AndroidManifest.xml');

      expect(manifest.existsSync(), isTrue);
      final content = manifest.readAsStringSync();
      expect(content, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      expect(content, contains('android.intent.action.BOOT_COMPLETED'));
    },
  );

  test('android widget config does not keep 30 minute polling', () {
    final widgetInfo = File(
      'android/app/src/main/res/xml/coursetable_widget_info.xml',
    );

    expect(widgetInfo.existsSync(), isTrue);
    final content = widgetInfo.readAsStringSync();
    expect(content, isNot(contains('android:updatePeriodMillis="1800000"')));
  });
}
