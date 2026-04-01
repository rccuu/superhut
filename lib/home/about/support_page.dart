import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/ui/apple_glass.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  static Route<void> route() {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) {
      return MaterialPageRoute<void>(builder: (context) => const SupportPage());
    }

    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder:
          (context, animation, secondaryAnimation) => const SupportPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<SupportPage> createState() => _SupportPageState();
}

enum _SupportNetwork { trc20, bsc }

class _SupportNetworkSpec {
  const _SupportNetworkSpec({
    required this.network,
    required this.shortLabel,
    required this.fullLabel,
    required this.address,
    required this.accent,
    required this.helperText,
  });

  final _SupportNetwork network;
  final String shortLabel;
  final String fullLabel;
  final String address;
  final Color accent;
  final String helperText;
}

class _SupportPageState extends State<SupportPage> {
  static const AssetImage _usdtLogo = AssetImage(
    'assets/support/usdt_logo.png',
  );
  static const Map<_SupportNetwork, _SupportNetworkSpec> _networkSpecs = {
    _SupportNetwork.trc20: _SupportNetworkSpec(
      network: _SupportNetwork.trc20,
      shortLabel: 'TRC20',
      fullLabel: 'TRC20 (TRON)',
      address: 'TNvVV3XgpDbnfT8kAVB5Pwe7UYVCfqekDT',
      accent: Color(0xFFE85D5A),
      helperText: '仅向当前 TRC20 地址转入 USDT。转错链、转入其他币种或 NFT 无法找回。',
    ),
    _SupportNetwork.bsc: _SupportNetworkSpec(
      network: _SupportNetwork.bsc,
      shortLabel: 'BSC',
      fullLabel: 'BSC (BEP-20)',
      address: '0xca48641aad9c37f74d2999686799deaee95b6105',
      accent: Color(0xFF1B9E83),
      helperText: '仅向当前 BSC(BEP-20) 地址转入 USDT。转错链、转入其他币种或 NFT 无法找回。',
    ),
  };

  _SupportNetwork _selectedNetwork = _SupportNetwork.trc20;

  _SupportNetworkSpec get _currentSpec => _networkSpecs[_selectedNetwork]!;

  Future<void> _copyCurrentAddress() async {
    final spec = _currentSpec;
    await Clipboard.setData(ClipboardData(text: spec.address));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${spec.fullLabel} 地址已复制到剪贴板')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final useLiteLayout =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final qrPanelWidth =
        (MediaQuery.sizeOf(context).width - 76).clamp(240.0, 360.0).toDouble();
    final spec = _currentSpec;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        style: AppGlassBackgroundStyle.soft,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(16, topInset + 74, 16, 28),
              children: [
                _SupportSectionPanel(
                  icon: Ionicons.git_branch_outline,
                  title: '收款网络',
                  tint: spec.accent,
                  useLiteEffects: useLiteLayout,
                  trailing: _SupportChip(
                    icon: Icons.attach_money_rounded,
                    label: 'USDT',
                    tint: spec.accent,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _networkSpecs.values
                            .map((item) {
                              final isSelected =
                                  item.network == _selectedNetwork;
                              return _SupportNetworkButton(
                                key: ValueKey(
                                  'support-network-${item.network.name}',
                                ),
                                label:
                                    item.network == _SupportNetwork.trc20
                                        ? item.shortLabel
                                        : item.fullLabel,
                                accent: item.accent,
                                selected: isSelected,
                                onTap: () {
                                  if (_selectedNetwork == item.network) {
                                    return;
                                  }
                                  setState(() {
                                    _selectedNetwork = item.network;
                                  });
                                },
                              );
                            })
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Container(
                          width: qrPanelWidth,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.82),
                                spec.accent.withValues(alpha: 0.10),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: spec.accent.withValues(alpha: 0.16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(
                                  alpha: 0.10,
                                ),
                                blurRadius: 24,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: ColoredBox(
                              color: Colors.white,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: _SupportGeneratedQr(
                                  key: ValueKey(spec.network.name),
                                  spec: spec,
                                  size: qrPanelWidth - 32,
                                  embeddedLogo: _usdtLogo,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SupportAddressCard(
                        spec: spec,
                        onCopy: _copyCurrentAddress,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SupportSectionPanel(
                  icon: Ionicons.alert_circle_outline,
                  title: '转账前请确认',
                  tint: colorScheme.error,
                  useLiteEffects: useLiteLayout,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SupportBullet(
                        text: '仅向当前选中的 ${spec.fullLabel} 地址转入 USDT。',
                      ),
                      const SizedBox(height: 10),
                      const _SupportBullet(text: '如果网络、币种或地址填错，链上资产通常无法撤回。'),
                      const SizedBox(height: 10),
                      _SupportBullet(text: spec.helperText),
                      const SizedBox(height: 10),
                      const _SupportBullet(
                        text: '如果你只是想表达支持，也欢迎继续使用、反馈问题或提交改进建议。',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: topInset + 12,
              left: 16,
              child: _SupportBackButton(
                useLiteEffects: useLiteLayout,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportSectionPanel extends StatelessWidget {
  const _SupportSectionPanel({
    required this.icon,
    required this.title,
    required this.tint,
    required this.useLiteEffects,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Color tint;
  final bool useLiteEffects;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GlassPanel(
      style: GlassPanelStyle.card,
      blur: useLiteEffects ? 0 : 22,
      useBackdropFilter: !useLiteEffects,
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.all(22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.14 : 0.78),
          tint.withValues(alpha: isDark ? 0.22 : 0.14),
          colorScheme.surface.withValues(alpha: isDark ? 0.10 : 0.24),
        ],
      ),
      borderColor: tint.withValues(alpha: isDark ? 0.16 : 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassIconBadge(icon: icon, tint: tint, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SupportGeneratedQr extends StatelessWidget {
  const _SupportGeneratedQr({
    super.key,
    required this.spec,
    required this.size,
    required this.embeddedLogo,
  });

  final _SupportNetworkSpec spec;
  final double size;
  final ImageProvider embeddedLogo;

  @override
  Widget build(BuildContext context) {
    final logoSize = (size * 0.16).clamp(36.0, 60.0).toDouble();
    final qrPadding = (size * 0.06).clamp(12.0, 20.0).toDouble();

    return SizedBox.square(
      dimension: size,
      child: QrImageView(
        key: ValueKey('support-qr-${spec.network.name}'),
        data: spec.address,
        size: size,
        padding: EdgeInsets.all(qrPadding),
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        embeddedImage: embeddedLogo,
        embeddedImageStyle: QrEmbeddedImageStyle(size: Size.square(logoSize)),
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _SupportChip extends StatelessWidget {
  const _SupportChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: isDark ? 0.22 : 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tint),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: tint,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportNetworkButton extends StatelessWidget {
  const _SupportNetworkButton({
    super.key,
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:
                selected
                    ? accent.withValues(alpha: 0.14)
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.56,
                    ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected
                      ? accent.withValues(alpha: 0.32)
                      : theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.46,
                      ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                size: 16,
                color: selected ? accent : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? accent : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportAddressCard extends StatelessWidget {
  const _SupportAddressCard({required this.spec, required this.onCopy});

  final _SupportNetworkSpec spec;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.60,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: spec.accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: spec.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  spec.fullLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: spec.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '收款地址',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SelectableText(
            spec.address,
            key: const ValueKey('support-address-value'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.45,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            spec.helperText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('support-copy-button'),
                onPressed: onCopy,
                icon: const Icon(Ionicons.copy_outline, size: 18),
                label: const Text('复制地址'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportBullet extends StatelessWidget {
  const _SupportBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(
            Ionicons.checkmark_circle,
            size: 16,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportBackButton extends StatelessWidget {
  const _SupportBackButton({required this.onTap, required this.useLiteEffects});

  final VoidCallback onTap;
  final bool useLiteEffects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GlassPanel(
      style: GlassPanelStyle.floating,
      blur: useLiteEffects ? 0 : 18,
      useBackdropFilter: !useLiteEffects,
      borderRadius: BorderRadius.circular(18),
      padding: EdgeInsets.zero,
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.12 : 0.80),
          colorScheme.surface.withValues(alpha: isDark ? 0.12 : 0.34),
        ],
      ),
      child: SizedBox(
        width: 46,
        height: 46,
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
