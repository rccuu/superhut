import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:pub_semver/pub_semver.dart';

import 'app_logger.dart';

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
      final message = error.message ?? error.runtimeType.toString();
      AppLogger.debug('Skipped GitHub release update check: $message');
      return AppUpdateCheckResult(
        status: AppUpdateCheckStatus.failed,
        errorMessage: message,
      );
    } catch (error) {
      final message = error.toString();
      AppLogger.debug('Skipped GitHub release update check: $message');
      return AppUpdateCheckResult(
        status: AppUpdateCheckStatus.failed,
        errorMessage: message,
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

    var suffixStart = rawVersion.length;
    for (final separator in ['-', '+']) {
      final index = rawVersion.indexOf(separator);
      if (index >= 0 && index < suffixStart) {
        suffixStart = index;
      }
    }

    final coreVersion = rawVersion.substring(0, suffixStart);
    final suffix = rawVersion.substring(suffixStart);
    final segments = coreVersion.split('.');
    if (segments.length > 3) {
      return null;
    }
    while (segments.length < 3) {
      segments.add('0');
    }

    try {
      return Version.parse('${segments.join('.')}$suffix');
    } on FormatException {
      return null;
    }
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
      final sections =
          blocks
              .map((element) => _normalizeWhitespace(element.text))
              .where((text) => text.isNotEmpty)
              .toList();
      if (sections.isNotEmpty) {
        return sections.join('\n\n');
      }
    }

    return _normalizeWhitespace(fragment.text ?? '');
  }

  static String _normalizeWhitespace(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }
}
