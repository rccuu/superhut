import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/app_update_download_service.dart';
import '../../../core/ui/app_progress_indicator.dart';
import '../../../core/ui/app_snack_bar.dart';
import '../../../core/ui/color_scheme_ext.dart';

typedef AppUpdateBannerRetryHandler = Future<void> Function();
typedef AppUpdateBannerOpenReleaseHandler = Future<bool> Function(Uri url);

/// 首页顶部应用内更新下载进度横幅。
///
/// 只在下载/完成/失败时出现；不可见时退化为 SizedBox.shrink，不占布局。
/// 默认不拦截页面点击；只有横幅内置的取消/重试/发布页按钮可交互。
class AppUpdateDownloadBanner extends StatelessWidget {
  const AppUpdateDownloadBanner({
    super.key,
    this.onRetry,
    this.onOpenRelease,
  });

  final AppUpdateBannerRetryHandler? onRetry;
  final AppUpdateBannerOpenReleaseHandler? onOpenRelease;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUpdateDownloadSnapshot>(
      valueListenable: AppUpdateDownloadService.stateNotifier,
      builder: (context, snapshot, _) {
        if (!snapshot.isVisible) {
          return const SizedBox.shrink();
        }
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = colorScheme.isDarkMode;
        final isFailure = snapshot.status == AppUpdateDownloadStatus.failed;
        final isCompleted =
            snapshot.status == AppUpdateDownloadStatus.completed;
        final String title;
        if (isFailure) {
          title = '更新包下载失败';
        } else if (isCompleted) {
          title = snapshot.isReused ? '更新包已就绪' : '更新包下载完成';
        } else {
          title = '正在下载更新包';
        }
        final double? progressPercent;
        if (!isFailure) {
          progressPercent = snapshot.progress > 0
              ? snapshot.progress * 100
              : null;
        } else {
          progressPercent = null;
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: RepaintBoundary(
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.primary.withValues(
                        alpha: isDark ? 0.28 : 0.14,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isFailure
                                  ? CupertinoIcons.exclamationmark_circle
                                  : isCompleted
                                  ? CupertinoIcons.check_mark_circled
                                  : Ionicons.download_outline,
                              size: 18,
                              color:
                                  isFailure
                                      ? colorScheme.error
                                      : colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (!isCompleted && !isFailure && progressPercent != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  '${progressPercent.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (!isCompleted && !isFailure)
                              _BannerAction(
                                label: '取消',
                                onTap: () {
                                  unawaited(
                                    AppUpdateDownloadService.cancelDownload(),
                                  );
                                },
                              ),
                            if (isFailure) ...[
                              _BannerAction(
                                label: '重试',
                                onTap: () {
                                  final update = snapshot.update;
                                  if (update != null) {
                                    unawaited(
                                      AppUpdateDownloadService.startDownload(
                                        update,
                                      ),
                                    );
                                  }
                                },
                              ),
                              _BannerAction(
                                label: '发布页',
                                onTap: () {
                                  final update = snapshot.update;
                                  if (update == null) {
                                    return;
                                  }
                                  unawaited(
                                    _openUpdateRelease(
                                      context,
                                      update.releaseUrl,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: AppLinearProgressIndicator(
                            minHeight: 6,
                            value: isFailure ? null : snapshot.progress,
                            color:
                                isFailure
                                    ? colorScheme.error
                                    : colorScheme.primary,
                            backgroundColor: colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                          ),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(height: 2),
                          if (snapshot.tempFilePath != null &&
                              snapshot.tempFilePath!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                snapshot.fileName ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openUpdateRelease(
    BuildContext context,
    Uri url,
  ) async {
    final opener = onOpenRelease;
    final opened = opener != null ? await opener(url) : null;
    if (opened == null) {
      // 未注入打开器时默认回退系统浏览器。
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        showAppSnackBar(
          context,
          message: '无法打开下载链接，请稍后重试',
          type: AppSnackBarType.error,
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }
    if (!opened && context.mounted) {
      showAppSnackBar(
        context,
        message: '无法打开下载链接，请稍后重试',
        type: AppSnackBarType.error,
        duration: const Duration(seconds: 2),
      );
    }
  }
}

class _BannerAction extends StatelessWidget {
  const _BannerAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}