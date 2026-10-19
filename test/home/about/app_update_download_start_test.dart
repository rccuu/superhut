import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:superhut/core/services/app_update_download_service.dart';
import 'package:superhut/core/services/app_update_service.dart';
import 'package:superhut/home/about/view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: '工大盒子',
      packageName: 'com.superhut.test',
      version: '1.5.7',
      buildNumber: '1',
      buildSignature: '',
    );
    AppUpdateDownloadService.debugReplaceState(
      const AppUpdateDownloadSnapshot(),
    );
  });

  tearDown(() {
    AppUpdateDownloadService.debugReplaceState(
      const AppUpdateDownloadSnapshot(),
    );
  });

  testWidgets('update dialog starts in-app download when direct url exists', (
    tester,
  ) async {
    final downloadStarts = <AppUpdateInfo>[];
    final downloadUrl = Uri.parse(
      'https://github.com/rccuu/superhut/releases/download/v9.9.9/superhut-v9.9.9+99-arm64-v8a-release.apk',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AboutPage(
          startUpdateDownload: (update) async {
            downloadStarts.add(update);
          },
          checkForUpdate:
              ({required currentVersion}) async => AppUpdateCheckResult(
                status: AppUpdateCheckStatus.available,
                update: AppUpdateInfo(
                  version: Version(9, 9, 9),
                  tagName: 'v9.9.9',
                  releaseUrl: Uri.parse('https://example.com/releases/v9.9.9'),
                  downloadUrl: downloadUrl,
                  downloadFileName:
                      'superhut-v9.9.9+99-arm64-v8a-release.apk',
                  notes: '测试更新说明',
                ),
              ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('检查更新'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('发现新版本 v9.9.9'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '下载安装包'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(downloadStarts, hasLength(1));
    expect(downloadStarts.single.tagName, 'v9.9.9');
    expect(downloadStarts.single.downloadUrl, downloadUrl);
    expect(find.text('发现新版本 v9.9.9'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}