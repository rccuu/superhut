import 'package:flutter_test/flutter_test.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/services/app_update_download_service.dart';
import 'package:superhut/core/services/app_update_service.dart';

AppUpdateInfo _buildUpdate({
  Uri? downloadUrl,
  String? downloadFileName,
  String tagName = 'v9.9.9',
}) {
  return AppUpdateInfo(
    version: Version(9, 9, 9),
    tagName: tagName,
    releaseUrl: Uri.parse('https://example.com/releases/$tagName'),
    downloadUrl: downloadUrl,
    downloadFileName: downloadFileName,
    notes: '测试更新说明',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppUpdateDownloadService.debugReplaceState(
      const AppUpdateDownloadSnapshot(),
    );
  });

  tearDown(() {
    AppUpdateDownloadService.debugReplaceState(
      const AppUpdateDownloadSnapshot(),
    );
  });

  test('startDownload shows failed state when url is missing', () async {
    final update = _buildUpdate(downloadUrl: null);

    await AppUpdateDownloadService.startDownload(update);

    final state = AppUpdateDownloadService.state;
    expect(state.status, AppUpdateDownloadStatus.failed);
    expect(state.errorMessage, appUpdateDownloadFailureMessage);
  });

  test('cancelDownload resets to idle and stops visible banner', () async {
    AppUpdateDownloadService.debugReplaceState(
      AppUpdateDownloadSnapshot(
        status: AppUpdateDownloadStatus.downloading,
        update: _buildUpdate(),
        progress: 0.42,
      ),
    );

    await AppUpdateDownloadService.cancelDownload();

    final state = AppUpdateDownloadService.state;
    expect(state.status, AppUpdateDownloadStatus.idle);
    expect(state.isVisible, isFalse);
  });

  test('failed state reports error message and is visible for retry', () {
    AppUpdateDownloadService.debugReplaceState(
      AppUpdateDownloadSnapshot(
        status: AppUpdateDownloadStatus.failed,
        update: _buildUpdate(),
        errorMessage: appUpdateDownloadFailureMessage,
      ),
    );

    final state = AppUpdateDownloadService.state;
    expect(state.isVisible, isTrue);
    expect(state.isBusy, isFalse);
    expect(state.errorMessage, appUpdateDownloadFailureMessage);
  });

  test('completed snapshot exposes file info for banner display', () {
    AppUpdateDownloadService.debugReplaceState(
      AppUpdateDownloadSnapshot(
        status: AppUpdateDownloadStatus.completed,
        update: _buildUpdate(),
        progress: 1,
        fileName: 'superhut-v9.9.9.apk',
        tempFilePath: '/tmp/superhut_update/superhut-v9.9.9.apk',
      ),
    );

    final state = AppUpdateDownloadService.state;
    expect(state.isVisible, isTrue);
    expect(state.isBusy, isFalse);
    expect(state.progress, 1);
    expect(state.fileName, 'superhut-v9.9.9.apk');
  });

  test('idle snapshot is never visible', () {
    expect(
      const AppUpdateDownloadSnapshot().isVisible,
      isFalse,
    );
    expect(
      const AppUpdateDownloadSnapshot().isBusy,
      isFalse,
    );
  });
}
