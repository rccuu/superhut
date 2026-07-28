import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pub_semver/pub_semver.dart';

import 'app_logger.dart';

const String appUpdateCheckFailureMessage = '检查更新失败，请稍后重试';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.tagName,
    required this.releaseUrl,
    required this.notes,
    this.downloadUrl,
    this.downloadFileName,
  });

  final Version version;
  final String tagName;
  final Uri releaseUrl;
  final String notes;
  final Uri? downloadUrl;
  final String? downloadFileName;

  String get displayVersion => tagName.isEmpty ? version.toString() : tagName;
  Uri get updateUrl => downloadUrl ?? releaseUrl;
  bool get hasDirectDownload => downloadUrl != null;
  String get updateActionLabel => hasDirectDownload ? '下载安装包' : '打开发布页';
}

enum AppUpdateCheckStatus {
  available,
  upToDate,
  noPublishedRelease,
  invalidVersion,
  failed,
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.status,
    this.update,
    this.errorMessage,
  });

  final AppUpdateCheckStatus status;
  final AppUpdateInfo? update;
  final String? errorMessage;

  bool get hasUpdate =>
      status == AppUpdateCheckStatus.available && update != null;
}

abstract final class AppUpdateService {
  static final Uri _releasesApiUrl = Uri.parse(
    'https://api.github.com/repos/rccuu/superhut/releases?per_page=20',
  );
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      responseType: ResponseType.json,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ),
  );
  static final RegExp _versionPattern = RegExp(
    r'v?(\d+(?:\.\d+){0,2}(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)',
    caseSensitive: false,
  );

  static Future<AppUpdateInfo?> fetchUpdate({
    required String currentVersion,
  }) async {
    final result = await checkForUpdate(currentVersion: currentVersion);
    return result.update;
  }

  static Future<AppUpdateCheckResult> checkForUpdate({
    required String currentVersion,
  }) async {
    final installedVersion = _tryParseVersion(currentVersion);
    if (installedVersion == null) {
      AppLogger.debug('Skipped app update check because version is invalid.');
      return const AppUpdateCheckResult(
        status: AppUpdateCheckStatus.invalidVersion,
      );
    }

    try {
      final response = await _dio.getUri<dynamic>(_releasesApiUrl);
      final releases = response.data;
      if (releases is! List || releases.isEmpty) {
        return const AppUpdateCheckResult(
          status: AppUpdateCheckStatus.noPublishedRelease,
        );
      }

      final latestRelease = _selectNewestRelease(releases);
      if (latestRelease == null) {
        return const AppUpdateCheckResult(
          status: AppUpdateCheckStatus.noPublishedRelease,
        );
      }

      if (latestRelease.version > installedVersion) {
        return AppUpdateCheckResult(
          status: AppUpdateCheckStatus.available,
          update: latestRelease,
        );
      }

      return const AppUpdateCheckResult(status: AppUpdateCheckStatus.upToDate);
    } on DioException catch (error) {
      final diagnosticMessage = error.message ?? error.runtimeType.toString();
      AppLogger.debug(
        'Skipped GitHub release update check: $diagnosticMessage',
      );
      return const AppUpdateCheckResult(
        status: AppUpdateCheckStatus.failed,
        errorMessage: appUpdateCheckFailureMessage,
      );
    } catch (error) {
      AppLogger.debug(
        'Skipped GitHub release update check: ${error.runtimeType}',
      );
      return const AppUpdateCheckResult(
        status: AppUpdateCheckStatus.failed,
        errorMessage: appUpdateCheckFailureMessage,
      );
    }
  }

  static AppUpdateInfo? _selectNewestRelease(List<dynamic> releases) {
    AppUpdateInfo? newestRelease;

    for (final release in releases) {
      if (release is! Map) {
        continue;
      }

      final parsedRelease = _parseRelease(release);
      if (parsedRelease == null) {
        continue;
      }

      if (newestRelease == null ||
          parsedRelease.version > newestRelease.version) {
        newestRelease = parsedRelease;
      }
    }

    return newestRelease;
  }

  static AppUpdateInfo? _parseRelease(Map<dynamic, dynamic> release) {
    if (release['draft'] == true || release['prerelease'] == true) {
      return null;
    }

    final tagName = _stringValue(release['tag_name']);
    if (tagName == null || tagName.isEmpty) {
      return null;
    }

    final releaseUrl = Uri.tryParse(_stringValue(release['html_url']) ?? '');
    if (releaseUrl == null) {
      return null;
    }

    final version = _tryParseVersion(tagName);
    if (version == null || version.isPreRelease) {
      return null;
    }

    final assets = release['assets'];
    final installerAsset =
        assets is List ? _selectInstallerAsset(assets) : null;

    return AppUpdateInfo(
      version: version,
      tagName: tagName,
      releaseUrl: releaseUrl,
      notes: _releaseNotesFromBody(_stringValue(release['body']) ?? ''),
      downloadUrl: installerAsset?.downloadUrl,
      downloadFileName: installerAsset?.name,
    );
  }

  static _ReleaseInstallerAsset? _selectInstallerAsset(List<dynamic> assets) {
    final candidates = <_ReleaseInstallerAsset>[];
    for (final asset in assets) {
      if (asset is! Map) {
        continue;
      }
      final name = _stringValue(asset['name']);
      final downloadUrl = Uri.tryParse(
        _stringValue(asset['browser_download_url']) ?? '',
      );
      if (name == null || name.isEmpty || downloadUrl == null) {
        continue;
      }
      candidates.add(
        _ReleaseInstallerAsset(name: name, downloadUrl: downloadUrl),
      );
    }

    if (candidates.isEmpty) {
      return null;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _firstMatchingAsset(
              candidates,
              (name) => name.endsWith('.apk') && name.contains('arm64-v8a'),
            ) ??
            _firstMatchingAsset(candidates, (name) => name.endsWith('.apk'));
      case TargetPlatform.iOS:
        return _firstMatchingAsset(
              candidates,
              (name) =>
                  name.endsWith('.tipa') && name.contains('trollstore'),
            ) ??
            _firstMatchingAsset(
              candidates,
              (name) =>
                  name.endsWith('.ipa') && name.contains('trollstore'),
            ) ??
            _firstMatchingAsset(
              candidates,
              (name) => name.endsWith('.ipa') && name.contains('unsigned'),
            ) ??
            _firstMatchingAsset(candidates, (name) => name.endsWith('.ipa'));
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return null;
    }
  }

  static _ReleaseInstallerAsset? _firstMatchingAsset(
    List<_ReleaseInstallerAsset> assets,
    bool Function(String lowerCaseName) predicate,
  ) {
    for (final asset in assets) {
      if (predicate(asset.name.toLowerCase())) {
        return asset;
      }
    }
    return null;
  }

  static Version? _tryParseVersion(String input) {
    final match = _versionPattern.firstMatch(input);
    if (match == null) {
      return null;
    }

    final rawVersion = match.group(1)?.trim();
    if (rawVersion == null || rawVersion.isEmpty) {
      return null;
    }

    final suffixStart = _versionSuffixStart(rawVersion);
    final coreVersion = _normalizeVersionCore(rawVersion, suffixStart);
    if (coreVersion == null) {
      return null;
    }
    final suffix = rawVersion.substring(suffixStart);

    try {
      return Version.parse('$coreVersion$suffix');
    } on FormatException {
      return null;
    }
  }

  static int _versionSuffixStart(String rawVersion) {
    for (var index = 0; index < rawVersion.length; index++) {
      final codeUnit = rawVersion.codeUnitAt(index);
      if (codeUnit == 0x2D || codeUnit == 0x2B) {
        return index;
      }
    }
    return rawVersion.length;
  }

  static String? _normalizeVersionCore(String rawVersion, int end) {
    final buffer = StringBuffer();
    var segmentStart = 0;
    var segmentCount = 0;

    for (var index = 0; index <= end; index++) {
      final isSegmentEnd = index == end || rawVersion.codeUnitAt(index) == 0x2E;
      if (!isSegmentEnd) {
        continue;
      }
      if (segmentStart == index) {
        return null;
      }
      if (segmentCount > 0) {
        buffer.writeCharCode(0x2E);
      }
      buffer.write(rawVersion.substring(segmentStart, index));
      segmentCount++;
      if (segmentCount > 3) {
        return null;
      }
      segmentStart = index + 1;
    }

    while (segmentCount < 3) {
      buffer.write('.0');
      segmentCount++;
    }
    return buffer.toString();
  }

  static String _releaseNotesFromBody(String body) {
    return _normalizeWhitespace(body);
  }

  static String? _stringValue(Object? value) {
    if (value is String) {
      return value.trim();
    }
    return null;
  }

  static String _normalizeWhitespace(String text) {
    final buffer = StringBuffer();
    var previousWasHorizontalSpace = false;
    var newlineRun = 0;

    for (var index = 0; index < text.length; index++) {
      final codeUnit = text.codeUnitAt(index);
      if (codeUnit == 0x0D &&
          index + 1 < text.length &&
          text.codeUnitAt(index + 1) == 0x0A) {
        index++;
        if (newlineRun < 2) {
          buffer.writeCharCode(0x0A);
          newlineRun++;
        }
        previousWasHorizontalSpace = false;
        continue;
      }

      if (codeUnit == 0x0A) {
        if (newlineRun < 2) {
          buffer.writeCharCode(codeUnit);
          newlineRun++;
        }
        previousWasHorizontalSpace = false;
        continue;
      }

      if (codeUnit == 0x20 || codeUnit == 0x09) {
        if (!previousWasHorizontalSpace) {
          buffer.writeCharCode(0x20);
          previousWasHorizontalSpace = true;
        }
        newlineRun = 0;
        continue;
      }

      buffer.write(text[index]);
      previousWasHorizontalSpace = false;
      newlineRun = 0;
    }

    return buffer.toString().trim();
  }
}

class _ReleaseInstallerAsset {
  const _ReleaseInstallerAsset({required this.name, required this.downloadUrl});

  final String name;
  final Uri downloadUrl;
}
