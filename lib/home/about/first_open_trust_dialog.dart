import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

enum FirstOpenTrustDialogAction { continueUse, viewDetails }

Future<FirstOpenTrustDialogAction?> showFirstOpenTrustDialog(
  BuildContext context,
) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return showDialog<FirstOpenTrustDialogAction>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Ionicons.shield_checkmark_outline,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '先把数据怎么处理说清楚',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '工大盒子是第三方开源应用，不是学校官方 App。首次打开时，先把最重要的几件事说明白。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              const _TrustFactLine(
                text: '当前公开代码里，主要连接学校系统、校园生活服务和 GitHub Releases。',
              ),
              const SizedBox(height: 10),
              const _TrustFactLine(text: '密码优先保存在系统安全存储中，登录态和缓存默认保存在本机。'),
              const SizedBox(height: 10),
              const _TrustFactLine(
                text: '你可以随时查看仓库、版本发布和完整说明，不需要先懂 GitHub 才能核实。',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(FirstOpenTrustDialogAction.viewDetails),
              child: const Text('查看完整说明'),
            ),
            FilledButton(
              onPressed:
                  () => Navigator.of(
                    dialogContext,
                  ).pop(FirstOpenTrustDialogAction.continueUse),
              child: const Text('我知道了，继续使用'),
            ),
          ],
        ),
      );
    },
  );
}

class _TrustFactLine extends StatelessWidget {
  const _TrustFactLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(
            Ionicons.checkmark_circle,
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
