import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

/// SharedPreferences 中「不再提示」选件的持久化键。
const String rechargeTipDismissedPrefsKey = 'user_page_recharge_tip_dismissed';

enum RechargeTipDialogAction { acknowledged, noMoreTip }

Future<RechargeTipDialogAction?> showRechargeTipDialog(
  BuildContext context,
) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return showDialog<RechargeTipDialogAction>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
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
                Ionicons.wallet_outline,
                color: colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '前往支付宝小程序充值',
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
          children: const [
            _RechargeTipLine(text: '登录密码是每个人身份证后 6 位。'),
            SizedBox(height: 10),
            _RechargeTipLine(
              text: '充值入口在小程序的左上角，返回键的右边。',
            ),
            SizedBox(height: 10),
            _RechargeTipLine(
              text: '进入充值页面若提示「出现异常，请联系运维人员」，'
                  '没有影响，实际测试可以到账；担心的话，可以先充 1 块钱试一下。',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(RechargeTipDialogAction.noMoreTip),
            child: const Text('不再提示'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(RechargeTipDialogAction.acknowledged),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}

class _RechargeTipLine extends StatelessWidget {
  const _RechargeTipLine({required this.text});

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