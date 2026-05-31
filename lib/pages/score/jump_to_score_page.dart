import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

import '../../core/services/app_logger.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_page_route.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/apple_glass.dart';
import '../../core/ui/color_scheme_ext.dart';
import '../../utils/token.dart';
import 'scorepage.dart';

typedef ScoreLoginRenewer = Future<bool> Function(BuildContext context);

class JumpToScorePage extends StatefulWidget {
  const JumpToScorePage({super.key, this.renewLogin});

  final ScoreLoginRenewer? renewLogin;

  @override
  State<JumpToScorePage> createState() => _JumpToScorePageState();
}

class _JumpToScorePageState extends State<JumpToScorePage> {
  static const Color _scoreAccent = Color(0xFF22966C);

  final ValueNotifier<_ScoreJumpPanelState> _panelState =
      ValueNotifier<_ScoreJumpPanelState>(const _ScoreJumpPanelState.loading());
  bool _isJumpInFlight = false;

  @override
  void initState() {
    super.initState();
    _jumpToScorePage();
  }

  @override
  void dispose() {
    _panelState.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    showAppSnackBar(
      context,
      message: message,
      type: AppSnackBarType.warning,
      icon: Icons.lock_reset_rounded,
    );
  }

  void _showLoadingIfNeeded() {
    if (!mounted || _panelState.value.isLoading) {
      return;
    }

    _panelState.value = const _ScoreJumpPanelState.loading();
  }

  void _showError(String message) {
    final panelState = _panelState.value;
    if (!mounted ||
        (!panelState.isLoading && panelState.errorMessage == message)) {
      return;
    }

    _panelState.value = _ScoreJumpPanelState.error(message);
  }

  void _hideLoadingIfNeeded() {
    if (!mounted || !_panelState.value.isLoading) {
      return;
    }

    _panelState.value = const _ScoreJumpPanelState.error('成绩页面暂时无法打开');
  }

  Future<void> _jumpToScorePage() async {
    if (_isJumpInFlight) {
      return;
    }

    final navigator = Navigator.of(context);
    var didNavigate = false;
    _isJumpInFlight = true;
    _showLoadingIfNeeded();

    try {
      final renewed = await (widget.renewLogin ?? renewToken)(context);
      if (!mounted) {
        return;
      }

      if (!renewed) {
        _showError('教务系统登录状态已失效，请重新登录后重试。');
        _showSnackBar('教务系统登录状态已失效，请重新登录后重试');
        return;
      }

      didNavigate = true;
      navigator.pushReplacement(
        buildAppPageRoute(builder: (_) => const ScorePage()),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to jump to score page',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showError('成绩页面暂时无法打开，请稍后重试。');
        _showSnackBar('成绩页面暂时无法打开，请稍后重试');
      }
    } finally {
      _isJumpInFlight = false;
      if (!didNavigate) {
        _hideLoadingIfNeeded();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        style: AppGlassBackgroundStyle.soft,
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ValueListenableBuilder<_ScoreJumpPanelState>(
                    valueListenable: _panelState,
                    builder: (context, panelState, _) {
                      if (panelState.isLoading) {
                        return _LoadingPanel(accent: _scoreAccent);
                      }

                      return _ErrorPanel(
                        accent: _scoreAccent,
                        message: panelState.errorMessage ?? '成绩页面暂时无法打开',
                        onRetry: _jumpToScorePage,
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: topInset + 12,
              left: 16,
              child: _FeatureBackButton(
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreJumpPanelState {
  const _ScoreJumpPanelState._({
    required this.isLoading,
    required this.errorMessage,
  });

  const _ScoreJumpPanelState.loading()
    : this._(isLoading: true, errorMessage: null);

  const _ScoreJumpPanelState.error(String message)
    : this._(isLoading: false, errorMessage: message);

  final bool isLoading;
  final String? errorMessage;
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.hero,
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.24 : 0.12),
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.12 : 0.05),
          colorScheme.surface.withValues(
            alpha: colorScheme.isDarkMode ? 0.84 : 0.92,
          ),
        ],
      ),
      borderColor: accent.withValues(
        alpha: colorScheme.isDarkMode ? 0.22 : 0.16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassIconBadge(
                icon: Ionicons.analytics_outline,
                tint: accent,
                size: 56,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: colorScheme.isDarkMode ? 0.20 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.18)),
                ),
                child: Text(
                  '校验登录态',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '正在打开成绩页',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '会先刷新教务系统凭据，再进入新版成绩总览。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          const GlassHairlineDivider(),
          const SizedBox(height: 18),
          Row(
            children: [
              AppLoadingIndicator(color: accent, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  '首次进入可能会稍慢一点，请稍候。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.accent,
    required this.message,
    required this.onRetry,
  });

  final Color accent;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.hero,
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: colorScheme.isDarkMode ? 0.12 : 0.78),
          colorScheme.error.withValues(
            alpha: colorScheme.isDarkMode ? 0.14 : 0.06,
          ),
        ],
      ),
      borderColor: colorScheme.error.withValues(alpha: 0.16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassIconBadge(
            icon: Ionicons.alert_circle_outline,
            tint: colorScheme.error,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            '成绩页打开失败',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Ionicons.refresh_outline, size: 18),
              label: const Text('重新尝试'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBackButton extends StatelessWidget {
  const _FeatureBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      style: GlassPanelStyle.floating,
      blur: 16,
      borderRadius: BorderRadius.circular(20),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(
          Ionicons.chevron_back,
          color: Theme.of(context).colorScheme.onSurface,
          size: 22,
        ),
      ),
    );
  }
}
