import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
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
  });

  testWidgets('version load failure keeps page usable without exposing error', (
    tester,
  ) async {
    var versionCalls = 0;
    var checkCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AboutPage(
          loadVersion: () async {
            versionCalls++;
            throw Exception('package info unavailable');
          },
          checkForUpdate: ({required currentVersion}) async {
            checkCalls++;
            return const AppUpdateCheckResult(
              status: AppUpdateCheckStatus.upToDate,
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(versionCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('v--'), findsOneWidget);
    expect(find.textContaining('package info unavailable'), findsNothing);

    await tester.tap(find.text('检查更新'));
    await tester.pump();

    expect(checkCalls, 0);
  });

  testWidgets('trust page button ignores duplicate taps while opening', (
    tester,
  ) async {
    final openCompleter = Completer<void>();
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AboutPage(
          openTrustPage: (_) {
            openCalls++;
            return openCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();

    final trustButton = find.text('查看完整说明');
    await tester.ensureVisible(trustButton);
    await tester.pump();

    await tester.tap(trustButton);
    await tester.pump();
    await tester.tap(trustButton);
    await tester.pump();

    expect(openCalls, 1);

    openCompleter.complete();
    await tester.pump();
  });

  testWidgets('trust page button recovers after opener throws', (tester) async {
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AboutPage(
          openTrustPage: (_) async {
            openCalls++;
            throw Exception('trust page unavailable');
          },
        ),
      ),
    );
    await tester.pump();

    final trustButton = find.text('查看完整说明');
    await tester.ensureVisible(trustButton);
    await tester.pump();

    await tester.tap(trustButton);
    await tester.pump();
    await tester.pump();

    expect(openCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开信任说明，请稍后重试'), findsOneWidget);

    await tester.tap(trustButton);
    await tester.pump();
    await tester.pump();

    expect(openCalls, 2);
  });

  testWidgets('support page button ignores duplicate taps while opening', (
    tester,
  ) async {
    final openCompleter = Completer<void>();
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AboutPage(
          openSupportPage: (_) {
            openCalls++;
            return openCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();

    final supportButton = find.text('查看支持方式');
    await tester.scrollUntilVisible(
      supportButton,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    await tester.tap(supportButton);
    await tester.pump();
    await tester.tap(supportButton);
    await tester.pump();

    expect(openCalls, 1);

    openCompleter.complete();
    await tester.pump();
  });

  testWidgets('support page button recovers after opener throws', (
    tester,
  ) async {
    var openCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AboutPage(
          openSupportPage: (_) async {
            openCalls++;
            throw Exception('support page unavailable');
          },
        ),
      ),
    );
    await tester.pump();

    final supportButton = find.text('查看支持方式');
    await tester.scrollUntilVisible(
      supportButton,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.pump();

    await tester.tap(supportButton);
    await tester.pump();
    await tester.pump();

    expect(openCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开支持方式，请稍后重试'), findsOneWidget);

    await tester.tap(supportButton);
    await tester.pump();
    await tester.pump();

    expect(openCalls, 2);
  });

  testWidgets('release link ignores duplicate taps while opening', (
    tester,
  ) async {
    final openCompleter = Completer<bool>();
    final openedUrls = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AboutPage(
          openUrl: (url) {
            openedUrls.add(url);
            return openCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();

    final releaseButton = find.text('打开版本发布');
    await tester.ensureVisible(releaseButton);
    await tester.pump();

    await tester.tap(releaseButton);
    await tester.pump();
    await tester.tap(releaseButton);
    await tester.pump();

    expect(openedUrls, [
      Uri.parse('https://github.com/rccuu/superhut/releases'),
    ]);

    openCompleter.complete(true);
    await tester.pump();

    await tester.tap(releaseButton);
    await tester.pump();

    expect(openedUrls, [
      Uri.parse('https://github.com/rccuu/superhut/releases'),
      Uri.parse('https://github.com/rccuu/superhut/releases'),
    ]);
  });

  testWidgets('release link reports stable message when opener returns false', (
    tester,
  ) async {
    final openedUrls = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AboutPage(
          openUrl: (url) async {
            openedUrls.add(url);
            return false;
          },
        ),
      ),
    );
    await tester.pump();

    final releaseButton = find.text('打开版本发布');
    await tester.ensureVisible(releaseButton);
    await tester.pump();

    await tester.tap(releaseButton);
    await tester.pump();

    final releaseUrl = Uri.parse('https://github.com/rccuu/superhut/releases');
    expect(openedUrls, [releaseUrl]);
    expect(find.text('无法打开链接，请稍后重试'), findsOneWidget);
    expect(find.textContaining(releaseUrl.toString()), findsNothing);
  });

  testWidgets('release link recovers after opener throws', (tester) async {
    final openedUrls = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AboutPage(
          openUrl: (url) async {
            openedUrls.add(url);
            throw Exception('browser unavailable');
          },
        ),
      ),
    );
    await tester.pump();

    final releaseButton = find.text('打开版本发布');
    await tester.ensureVisible(releaseButton);
    await tester.pump();

    await tester.tap(releaseButton);
    await tester.pump();
    await tester.pump();

    final releaseUrl = Uri.parse('https://github.com/rccuu/superhut/releases');
    expect(openedUrls, [releaseUrl]);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开链接，请稍后重试'), findsOneWidget);
    expect(find.textContaining(releaseUrl.toString()), findsNothing);
    expect(find.textContaining('browser unavailable'), findsNothing);

    await tester.tap(releaseButton);
    await tester.pump();
    await tester.pump();

    expect(openedUrls, [releaseUrl, releaseUrl]);
  });

  testWidgets('update dialog opens package download URL when available', (
    tester,
  ) async {
    final openedUrls = <Uri>[];
    final releaseUrl = Uri.parse('https://example.com/releases/v9.9.9');
    final downloadUrl = Uri.parse(
      'https://github.com/rccuu/superhut/releases/download/v9.9.9/superhut-v9.9.9+99-arm64-v8a-release.apk',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AboutPage(
          openUrl: (url) async {
            openedUrls.add(url);
            return true;
          },
          checkForUpdate:
              ({required currentVersion}) async => AppUpdateCheckResult(
                status: AppUpdateCheckStatus.available,
                update: AppUpdateInfo(
                  version: Version(9, 9, 9),
                  tagName: 'v9.9.9',
                  releaseUrl: releaseUrl,
                  downloadUrl: downloadUrl,
                  downloadFileName: 'superhut-v9.9.9+99-arm64-v8a-release.apk',
                  notes: '测试更新说明',
                ),
              ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('检查更新'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('发现新版本 v9.9.9'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '下载安装包'));
    await tester.pump();

    expect(openedUrls, [downloadUrl]);
    expect(find.textContaining(releaseUrl.toString()), findsNothing);
    expect(find.textContaining(downloadUrl.toString()), findsNothing);
  });

  testWidgets('update check ignores duplicate taps while pending', (
    tester,
  ) async {
    final checkCompleter = Completer<AppUpdateCheckResult>();
    final checkedVersions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AboutPage(
          checkForUpdate: ({required currentVersion}) {
            checkedVersions.add(currentVersion);
            return checkCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('检查更新'));
    await tester.pump();
    await tester.tap(find.text('检查中...'));
    await tester.pump();

    expect(checkedVersions, ['1.5.7']);

    checkCompleter.complete(
      const AppUpdateCheckResult(status: AppUpdateCheckStatus.upToDate),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('检查更新'), findsOneWidget);

    await tester.tap(find.text('检查更新'));
    await tester.pump();

    expect(checkedVersions, ['1.5.7', '1.5.7']);
  });

  testWidgets('update check restores button after thrown error and can retry', (
    tester,
  ) async {
    var checkCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AboutPage(
          checkForUpdate: ({required currentVersion}) async {
            checkCalls++;
            throw StateError('network unavailable');
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('检查更新'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(checkCalls, 1);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('检查更新失败，请稍后重试'), findsOneWidget);
    expect(find.textContaining('network unavailable'), findsNothing);

    await tester.tap(find.text('检查更新'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(checkCalls, 2);
  });
}
