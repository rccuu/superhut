import 'package:flutter/material.dart';

import 'color_scheme_ext.dart';

enum AppSnackBarType { info, success, warning, error }

ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showAppSnackBar(
  BuildContext? context, {
  required String message,
  AppSnackBarType type = AppSnackBarType.info,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
  EdgeInsets margin = const EdgeInsets.fromLTRB(16, 0, 16, 72),
  bool clearPrevious = true,
}) {
  if (context == null) {
    return null;
  }

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return null;
  }

  if (clearPrevious) {
    messenger.clearSnackBars();
  }

  return messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: margin,
      padding: EdgeInsets.zero,
      duration: duration,
      content: AppSnackBarContent(
        message: message,
        type: type,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    ),
  );
}

class AppSnackBarContent extends StatelessWidget {
  const AppSnackBarContent({
    super.key,
    required this.message,
    this.type = AppSnackBarType.info,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppSnackBarType type;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = _AppSnackBarPalette.resolve(colorScheme, type);
    final effectiveIcon = icon ?? palette.icon;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(
              alpha: colorScheme.isDarkMode ? 0.28 : 0.14,
            ),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Icon(effectiveIcon, size: 18, color: palette.accent),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
                  onAction?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.labelLarge,
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppSnackBarPalette {
  const _AppSnackBarPalette({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.border,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final Color accent;
  final Color border;
  final IconData icon;

  static _AppSnackBarPalette resolve(
    ColorScheme colorScheme,
    AppSnackBarType type,
  ) {
    return switch (type) {
      AppSnackBarType.success => _AppSnackBarPalette(
        background: colorScheme.successContainerSoft,
        foreground: colorScheme.onSuccessContainerSoft,
        accent: colorScheme.success,
        border: colorScheme.success.withValues(alpha: 0.24),
        icon: Icons.check_circle_rounded,
      ),
      AppSnackBarType.warning => _AppSnackBarPalette(
        background: colorScheme.warningContainerSoft,
        foreground: colorScheme.onWarningContainerSoft,
        accent: colorScheme.warning,
        border: colorScheme.warning.withValues(alpha: 0.24),
        icon: Icons.error_rounded,
      ),
      AppSnackBarType.error => _AppSnackBarPalette(
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
        accent: colorScheme.error,
        border: colorScheme.error.withValues(alpha: 0.26),
        icon: Icons.error_rounded,
      ),
      AppSnackBarType.info => _AppSnackBarPalette(
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
        accent: colorScheme.primary,
        border: colorScheme.primary.withValues(alpha: 0.22),
        icon: Icons.info_rounded,
      ),
    };
  }
}
