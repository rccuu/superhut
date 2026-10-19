import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:superhut/core/services/app_update_download_service.dart';
import 'package:superhut/core/services/app_update_service.dart';
import 'package:superhut/home/homeview/widgets/app_update_download_banner.dart';

AppUpdateInfo _failedUpdate() {
  return AppUpdateInfo(
    version: Version(9, 9, 9),
    tagName: 'v9.9.9',
    releaseUrl: Uri.parse('https://example.com/releases/v9.9.9'),
    downloadUrl: Uri.parse(
      'https://github.com/rccuu/superhut/releases/download/v9.9.9/superhut.apk',
    ),
    downloadFileName: 'superhut.apk',
    notes: '测试更新说明',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppUpdateDownloadService.debugReplaceState(
      const AppUpdateDownloadSnapshot(),
    );
  });

  tearDown(() {
    AppUpdateDownloadService.debugReplaceState(
      const AppUpdateDownloadSnapshot(),
    );
  });

  testWidgets('banner release button uses injected opener when provided', (
    tester,
  ) async {
    final openedUrls = <Uri>[];
    AppUpdateDownloadService.debugReplaceState(
      AppUpdateDownloadSnapshot(
        status: AppUpdateDownloadStatus.failed,
        update: _failedUpdate(),
        errorMessage: appUpdateDownloadFailureMessage,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const SizedBox.expand(),
              Positioned(
                top: 10,
                left: 16,
                right: 16,
                child: AppUpdateDownloadBanner(
                  onOpenRelease: (url) async {
                    openedUrls.add(url);
                    return true;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('发布页'));
    await tester.pump();
    await tester.pump();

    expect(openedUrls, [
      Uri.parse('https://example.com/releases/v9.9.9'),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner release button falls back to launching url', (
    tester,
  ) async {
    AppUpdateDownloadService.debugReplaceState(
      AppUpdateDownloadSnapshot(
        status: AppUpdateDownloadStatus.failed,
        update: _failedUpdate(),
        errorMessage: appUpdateDownloadFailureMessage,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const Stack(
            children: [
              SizedBox.expand(),
              Positioned(
                top: 10,
                left: 16,
                right: 16,
                child: AppUpdateDownloadBanner(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('发布页'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}