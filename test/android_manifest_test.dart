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
}
