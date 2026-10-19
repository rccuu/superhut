import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_logger.dart';
import 'app_update_service.dart';

const String appUpdateDownloadFailureMessage = '更新包下载失败，请稍后重试';
const String _downloadDirectoryName = 'superhut_update';
const String _appUpdateDownloadedTagKey = 'appUpdateDownloadedTag';
const String _appUpdateDownloadedFileNameKey = 'appUpdateDownloadedFileName';

enum AppUpdateDownloadStatus { idle, downloading, completed, failed }

class AppUpdateDownloadSnapshot {
  const AppUpdateDownloadSnapshot({
    this.status = AppUpdateDownloadStatus.idle,
    this.update,
    this.progress = 0,
    this.fileName,
    this.tempFilePath,
    this.errorMessage,
    this.isReused = false,
  });

  final AppUpdateDownloadStatus status;
  final AppUpdateInfo? update;
  final double progress;
  final String? fileName;
  final String? tempFilePath;
  final String? errorMessage;
  final bool isReused;

  bool get isVisible =>
      status == AppUpdateDownloadStatus.downloading ||
      status == AppUpdateDownloadStatus.completed ||
      status == AppUpdateDownloadStatus.failed;

  bool get isBusy => status == AppUpdateDownloadStatus.downloading;

  AppUpdateDownloadSnapshot copyWith({
    AppUpdateDownloadStatus? status,
    AppUpdateInfo? update,
    double? progress,
    String? fileName,
    String? tempFilePath,
    String? errorMessage,
    bool? isReused,
  }) {
    return AppUpdateDownloadSnapshot(
      status: status ?? this.status,
      update: update ?? this.update,
      progress: progress ?? this.progress,
      fileName: fileName ?? this.fileName,
      tempFilePath: tempFilePath ?? this.tempFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
      isReused: isReused ?? this.isReused,
    );
  }
}

class AppUpdatePlatformInstallArguments {
  const AppUpdatePlatformInstallArguments({required this.path});

  final String path;
}

/// 应用内更新下载服务（单例）。
///
/// 复现下载/取消/复用安装包的一整套状态机，供首页顶部横幅和「我的-关于」
/// 页共用；两家入口同时只允许一个下载任务在跑。
abstract final class AppUpdateDownloadService {
  static final MethodChannel _installChannel = MethodChannel(
    'com.superhut.rice.superhut/app_update_install',
  );

  static final ValueNotifier<AppUpdateDownloadSnapshot> stateNotifier =
      ValueNotifier<AppUpdateDownloadSnapshot>(
        const AppUpdateDownloadSnapshot(),
      );

  static CancelToken? _cancelToken;
  static Timer? _autoDismissTimer;
  static Future<void>? _activeTask;

  static AppUpdateDownloadSnapshot get state => stateNotifier.value;

  static Future<File> _downloadFileFor(String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final directory = Directory(
      '${tempDir.path}/$_downloadDirectoryName',
    );
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return File('${directory.path}/$fileName');
  }

  static String _normalizedFileName(String? fileName) {
    final trimmed = fileName?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'superhut-update.apk';
    }
    final cleaned = trimmed.replaceAll(RegExp(r'[/\\]'), '_');
    return cleaned.isEmpty ? 'superhut-update.apk' : cleaned;
  }

  static void _setSnapshot(AppUpdateDownloadSnapshot next) {
    if (identical(stateNotifier.value, next)) {
      return;
    }
    // ignore: invalid_use_of_visible_for_testing_member
    stateNotifier.value = next;
  }

  static void _clearAutoDismissTimer() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }

  /// 用户点击「立即下载」时的入口；同一 tag 已成功下载的安装包直接复用。
  static Future<void> startDownload(AppUpdateInfo update) {
    final runningTask = _activeTask;
    if (runningTask != null) {
      return runningTask;
    }
    final task = _runDownload(update);
    _activeTask = task;
    return task.whenComplete(() {
      _activeTask = null;
    });
  }

  static Future<void> _runDownload(AppUpdateInfo update) async {
    if (!update.hasDirectDownload) {
      _setSnapshot(
        AppUpdateDownloadSnapshot(
          status: AppUpdateDownloadStatus.failed,
          update: update,
          errorMessage: appUpdateDownloadFailureMessage,
        ),
      );
      return;
    }
    final downloadUrl = update.downloadUrl!;
    final fileName = _normalizedFileName(update.downloadFileName);

    try {
      final existing = await _resolveReusableFile(update.tagName, fileName);
      if (existing != null) {
        _setSnapshot(
          AppUpdateDownloadSnapshot(
            status: AppUpdateDownloadStatus.completed,
            update: update,
            progress: 1,
            fileName: fileName,
            tempFilePath: existing.path,
            isReused: true,
          ),
        );
        await _deliverCompletedFile(
          AppUpdatePlatformInstallArguments(path: existing.path),
        );
        _scheduleAutoDismiss();
        return;
      }

      _setSnapshot(
        AppUpdateDownloadSnapshot(
          status: AppUpdateDownloadStatus.downloading,
          update: update,
          progress: 0,
          fileName: fileName,
        ),
      );

      final file = await _downloadFileFor(fileName);
      if (file.existsSync()) {
        // 重试前清理上一次未完成的半截文件。
        file.deleteSync();
      }
      _cancelToken = CancelToken();
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 15);
      dio.options.receiveTimeout = const Duration(seconds: 120);
      await dio.downloadUri(
        downloadUrl,
        file.path,
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {
            'Accept': 'application/octet-stream',
            'User-Agent': 'superhut-app-update',
          },
        ),
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            return;
          }
          final progress = (received / total).clamp(0.0, 1.0);
          _setSnapshot(
            state.copyWith(
              status: AppUpdateDownloadStatus.downloading,
              update: update,
              progress: progress,
            ),
          );
        },
      );

      final downloadedFile = File(file.path);
      if (!downloadedFile.existsSync() || downloadedFile.lengthSync() <= 0) {
        throw StateError('下载的更新包文件不完整');
      }

      await _markDownloadedTag(update.tagName);
      _setSnapshot(
        AppUpdateDownloadSnapshot(
          status: AppUpdateDownloadStatus.completed,
          update: update,
          progress: 1,
          fileName: fileName,
          tempFilePath: downloadedFile.path,
        ),
      );
      await _deliverCompletedFile(
        AppUpdatePlatformInstallArguments(path: downloadedFile.path),
      );
      _scheduleAutoDismiss();
    } on DioException catch (error, stackTrace) {
      if (CancelToken.isCancel(error)) {
        _setSnapshot(
          AppUpdateDownloadSnapshot(update: update),
        );
        return;
      }
      AppLogger.error(
        '更新包下载失败',
        error: error,
        stackTrace: stackTrace,
      );
      _setSnapshot(
        AppUpdateDownloadSnapshot(
          status: AppUpdateDownloadStatus.failed,
          update: update,
          errorMessage: appUpdateDownloadFailureMessage,
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        '更新包下载失败',
        error: error,
        stackTrace: stackTrace,
      );
      _setSnapshot(
        AppUpdateDownloadSnapshot(
          status: AppUpdateDownloadStatus.failed,
          update: update,
          errorMessage: appUpdateDownloadFailureMessage,
        ),
      );
    }
  }

  static Future<void> cancelDownload() async {
    _clearAutoDismissTimer();
    final cancelToken = _cancelToken;
    if (cancelToken != null) {
      cancelToken.cancel();
    }
    _cancelToken = null;
    _setSnapshot(const AppUpdateDownloadSnapshot());
  }

  /// 下载完成后按平台交付安装包：
  /// Android 直接唤起系统安装；iOS 弹出系统分享面板交给 TrollStore 导入；
  /// 其余平台回退打开发布页。
  static Future<void> _deliverCompletedFile(
    AppUpdatePlatformInstallArguments arguments,
  ) async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        await _startPlatformInstall(arguments.path);
        break;
      case TargetPlatform.iOS:
        await _shareCompletedFile(arguments.path);
        break;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        final update = state.update;
        if (update != null) {
          await launchUrl(
            update.releaseUrl,
            mode: LaunchMode.externalApplication,
          );
        }
        break;
    }
  }

  static Future<void> _startPlatformInstall(String path) async {
    try {
      final result = await _installChannel.invokeMethod<Map<dynamic, dynamic>>(
        'installApk',
        {'path': path},
      );
      final outcome = result?['outcome']?.toString();
      if (outcome == null) {
        throw StateError('安装通道未返回结果');
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        '唤起系统安装失败',
        error: error,
        stackTrace: stackTrace,
      );
      _setSnapshot(
        state.copyWith(
          status: AppUpdateDownloadStatus.failed,
          errorMessage: appUpdateDownloadFailureMessage,
        ),
      );
    }
  }

  static Future<void> requestInstallPermissionSettings() async {
    try {
      await _installChannel.invokeMethod<void>('openInstallSettings');
    } catch (error, stackTrace) {
      AppLogger.error(
        '打开安装未知应用设置失败',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Future<void> _shareCompletedFile(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        throw StateError('更新包文件不存在');
      }
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/octet-stream')],
        subject: '工大盒子安装包',
        text: '工大盒子已下载新版本，请使用 TrollStore 导入安装。',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        '分享更新包失败',
        error: error,
        stackTrace: stackTrace,
      );
      _setSnapshot(
        state.copyWith(
          status: AppUpdateDownloadStatus.failed,
          errorMessage: appUpdateDownloadFailureMessage,
        ),
      );
    }
  }

  static Future<File?> _resolveReusableFile(
    String tagName,
    String fileName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final downloadedTag = prefs.getString(_appUpdateDownloadedTagKey) ?? '';
    if (downloadedTag.isEmpty || downloadedTag != tagName) {
      return null;
    }
    final file = await _downloadFileFor(fileName);
    if (!file.existsSync() || file.lengthSync() <= 0) {
      return null;
    }
    return file;
  }

  static Future<void> _markDownloadedTag(String tagName) async {
    final prefs = await SharedPreferences.getInstance();
    final fileName = state.fileName ?? '';
    await prefs.setString(_appUpdateDownloadedTagKey, tagName);
    if (fileName.isNotEmpty) {
      await prefs.setString(_appUpdateDownloadedFileNameKey, fileName);
    }
  }

  static void _scheduleAutoDismiss() {
    _clearAutoDismissTimer();
    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      _setSnapshot(const AppUpdateDownloadSnapshot());
    });
  }

  @visibleForTesting
  static void debugReplaceState(AppUpdateDownloadSnapshot snapshot) {
    _clearAutoDismissTimer();
    _cancelToken = null;
    _setSnapshot(snapshot);
  }
}