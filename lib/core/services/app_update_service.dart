import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:pub_semver/pub_semver.dart';

import 'app_logger.dart';

const String appUpdateCheckFailureMessage = '检查更新失败，请稍后重试';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.tagName,
    required this.releaseUrl,
    required this.notes,
  });

  final Version version;
  final String tagName;
  final Uri releaseUrl;
  final String notes;

  String get displayVersion => tagName.isEmpty ? version.toString() : tagName;
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
  static final Uri _releasesFeedUrl = Uri.parse(
    'https://github.com/rccuu/superhut/releases.atom',
  );
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      responseType: ResponseType.plain,
      headers: const {
        'Accept':
            'application/atom+xml,application/xml,text/xml;q=0.9,*/*;q=0.8',
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
      final response = await _dio.getUri<String>(_releasesFeedUrl);
      final feedXml = response.data?.trim();
      if (feedXml == null || feedXml.isEmpty) {
        return const AppUpdateCheckResult(
          status: AppUpdateCheckStatus.noPublishedRelease,
        );
      }

      final latestRelease = _selectNewestRelease(feedXml);
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

  static AppUpdateInfo? _selectNewestRelease(String feedXml) {
    final document = parse(feedXml);
    AppUpdateInfo? newestRelease;

    for (final entry in document.getElementsByTagName('entry')) {
      final parsedRelease = _parseReleaseEntry(entry);
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

  static AppUpdateInfo? _parseReleaseEntry(Element entry) {
    final releaseUrl = _extractReleaseUrl(entry);
    if (releaseUrl == null) {
      return null;
    }

    final tagName = _extractTagName(releaseUrl);
    if (tagName == null || tagName.isEmpty) {
      return null;
    }

    final version = _tryParseVersion(tagName);
    if (version == null || version.isPreRelease) {
      return null;
    }

    final notes = _extractNotes(entry);
    return AppUpdateInfo(
      version: version,
      tagName: tagName,
      releaseUrl: releaseUrl,
      notes: notes,
    );
  }

  static Uri? _extractReleaseUrl(Element entry) {
    for (final link in entry.getElementsByTagName('link')) {
      if (link.attributes['rel'] != 'alternate') {
        continue;
      }

      final href = link.attributes['href'];
      if (href == null || href.isEmpty) {
        continue;
      }

      return Uri.tryParse(href);
    }

    return null;
  }

  static String? _extractTagName(Uri releaseUrl) {
    final pathSegments = releaseUrl.pathSegments;
    if (pathSegments.length < 5) {
      return null;
    }
    if (pathSegments[2] != 'releases' || pathSegments[3] != 'tag') {
      return null;
    }

    return Uri.decodeComponent(pathSegments[4]).trim();
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

  static String _extractNotes(Element entry) {
    final contentElements = entry.getElementsByTagName('content');
    if (contentElements.isEmpty) {
      return '';
    }

    final encodedHtml = contentElements.first.text.trim();
    if (encodedHtml.isEmpty) {
      return '';
    }

    final decodedHtml = parseFragment(encodedHtml).text;
    final fragment = parseFragment(decodedHtml);
    final blocks = fragment.querySelectorAll(
      'h1, h2, h3, h4, h5, h6, p, li, pre, blockquote',
    );

    if (blocks.isNotEmpty) {
      final sections = <String>[];
      for (final block in blocks) {
        final section = _normalizeWhitespace(block.text);
        if (section.isNotEmpty) {
          sections.add(section);
        }
      }
      if (sections.isNotEmpty) {
        return sections.join('\n\n');
      }
    }

    return _normalizeWhitespace(fragment.text ?? '');
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
