import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/services/app_update_service.dart';

void main() {
  test(
    'checkForUpdate returns invalidVersion without fetching releases',
    () async {
      final result = await AppUpdateService.checkForUpdate(
        currentVersion: 'not-a-version',
      );

      expect(result.status, AppUpdateCheckStatus.invalidVersion);
      expect(result.update, isNull);
      expect(result.errorMessage, isNull);
    },
  );
}
