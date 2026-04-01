import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_update_service.dart';
import '../../core/ui/apple_glass.dart';
import 'support_page.dart';
import 'trust_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  static Route<void> route() {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) {
      return MaterialPageRoute<void>(builder: (context) => const AboutPage());
    }

    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 160),
      reverseTransitionDuration: const Duration(milliseconds: 140),
      pageBuilder:
          (context, animation, secondaryAnimation) => const AboutPage(),
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
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static final Uri _forkRepoUrl = Uri.parse(
    'https://github.com/rccuu/superhut',
  );
  static final Uri _upstreamRepoUrl = Uri.parse(
    'https://github.com/cc2562/superhut',
  );
  static final Uri _releaseUrl = Uri.parse(
    'https://github.com/rccuu/superhut/releases',
  );

  String _version = '--';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVersion();
    });
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }

    setState(() {
      _version = packageInfo.version;
    });
  }

  Future<void> _openUrl(Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开链接：$url')));
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate) {
      return;
    }

    setState(() {
      _isCheckingUpdate = true;
    });

    final result = await AppUpdateService.checkForUpdate(
      currentVersion: _version,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckingUpdate = false;
    });

    switch (result.status) {
      case AppUpdateCheckStatus.available:
        _showUpdateDialog(result.update!);
      case AppUpdateCheckStatus.upToDate:
        _showMessage('当前已是最新版本');
      case AppUpdateCheckStatus.noPublishedRelease:
        _showMessage('当前仓库还没有发布正式版本');
      case AppUpdateCheckStatus.invalidVersion:
        _showMessage('当前版本号格式无效，暂时无法检查更新');
      case AppUpdateCheckStatus.failed:
        _showMessage(result.errorMessage ?? '检查更新失败，请稍后重试');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showUpdateDialog(AppUpdateInfo update) {
    final updateDescription = _buildUpdateDescription(update.notes);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('发现新版本 ${update.displayVersion}'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: SingleChildScrollView(child: Text(updateDescription)),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('稍后再说'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('前往更新'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _openUrl(update.releaseUrl);
              },
            ),
          ],
        );
      },
    );
  }

  String _buildUpdateDescription(String releaseNotes) {
    const fallbackText = '工大盒子已发布新版本，可前往 GitHub Release 页面查看更新说明并下载安装。';
    if (releaseNotes.trim().isEmpty) {
      return fallbackText;
    }

    const maxLength = 700;
    if (releaseNotes.length <= maxLength) {
      return releaseNotes;
    }

    return '${releaseNotes.substring(0, maxLength).trimRight()}\n\n……';
  }

  Future<void> _openTrustPage() async {
    await Navigator.of(context).push(TrustCenterPage.route());
  }

  Future<void> _openSupportPage() async {
    await Navigator.of(context).push(SupportPage.route());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final useLiteLayout =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildPageBackground(
        context,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(16, topInset + 74, 16, 28),
              children: [
                RepaintBoundary(
                  child: _AboutHeroCard(
                    version: _version,
                    isCheckingUpdate: _isCheckingUpdate,
                    useLiteEffects: useLiteLayout,
                    onCheckUpdates:
                        _isCheckingUpdate || _version == '--'
                            ? null
                            : _checkForUpdates,
                  ),
                ),
                const SizedBox(height: 16),
                RepaintBoundary(
                  child: _AboutSectionPanel(
                    icon: Ionicons.shield_checkmark_outline,
                    title: '信任与隐私',
                    tint: colorScheme.secondary,
                    useLiteEffects: useLiteLayout,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AboutFactLine(text: '当前仓库、上游仓库和版本发布页都公开可见。'),
                        const SizedBox(height: 10),
                        _AboutFactLine(text: '应用内更新检查直接读取 GitHub Releases 信息。'),
                        const SizedBox(height: 10),
                        _AboutFactLine(
                          text: '当前公开代码里，主要业务域名是学校系统、服务提供方和 GitHub。',
                        ),
                        const SizedBox(height: 10),
                        _AboutFactLine(text: '密码优先走系统安全存储，登录态和缓存默认保存在本机。'),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _openTrustPage,
                              icon: const Icon(
                                Ionicons.shield_checkmark_outline,
                                size: 18,
                              ),
                              label: const Text('查看完整说明'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _openUrl(_releaseUrl),
                              icon: const Icon(
                                Ionicons.download_outline,
                                size: 18,
                              ),
                              label: const Text('打开版本发布'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                RepaintBoundary(
                  child: _AboutSectionPanel(
                    icon: Ionicons.heart_outline,
                    title: '支持项目',
                    tint: const Color(0xFF199A7A),
                    useLiteEffects: useLiteLayout,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _AboutFactLine(
                          text: '想支持的话，这里有个入口。',
                        ),
                        const SizedBox(height: 18),
                        FilledButton.tonalIcon(
                          onPressed: _openSupportPage,
                          icon: const Icon(Ionicons.heart_outline, size: 18),
                          label: const Text('查看支持方式'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                RepaintBoundary(
                  child: _AboutSectionPanel(
                    icon: Ionicons.logo_github,
                    title: '仓库',
                    tint: colorScheme.primary,
                    useLiteEffects: useLiteLayout,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RepoTile(
                          title: '当前仓库',
                          subtitle: 'rccuu/superhut',
                          url: _forkRepoUrl.toString(),
                          icon: Ionicons.git_branch_outline,
                          accent: colorScheme.primary,
                          useLiteEffects: useLiteLayout,
                          onTap: () => _openUrl(_forkRepoUrl),
                        ),
                        const SizedBox(height: 12),
                        _RepoTile(
                          title: '原作仓库',
                          subtitle: 'cc2562/superhut',
                          url: _upstreamRepoUrl.toString(),
                          icon: Ionicons.logo_github,
                          accent: colorScheme.secondary,
                          useLiteEffects: useLiteLayout,
                          onTap: () => _openUrl(_upstreamRepoUrl),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                RepaintBoundary(
                  child: _AboutSectionPanel(
                    icon: Ionicons.person_outline,
                    title: '开发者',
                    tint: colorScheme.tertiary,
                    useLiteEffects: useLiteLayout,
                    child: _ContributorTile(
                      name: 'CC米饭',
                      role: '原项目作者',
                      accent: colorScheme.tertiary,
                      useLiteEffects: useLiteLayout,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: topInset + 12,
              left: 16,
              child: _AboutBackButton(
                useLiteEffects: useLiteLayout,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageBackground(BuildContext context, {required Widget child}) {
    return AppGlassBackground(
      style: AppGlassBackgroundStyle.soft,
      child: child,
    );
  }
}

class _AboutHeroCard extends StatelessWidget {
  const _AboutHeroCard({
    required this.version,
    required this.isCheckingUpdate,
    required this.useLiteEffects,
    required this.onCheckUpdates,
  });

  final String version;
  final bool isCheckingUpdate;
  final bool useLiteEffects;
  final VoidCallback? onCheckUpdates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GlassPanel(
      style: GlassPanelStyle.hero,
      blur: useLiteEffects ? 0 : 24,
      useBackdropFilter: !useLiteEffects,
      borderRadius: BorderRadius.circular(34),
      padding: const EdgeInsets.all(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.16 : 0.84),
          colorScheme.primary.withValues(alpha: isDark ? 0.28 : 0.20),
          colorScheme.secondary.withValues(alpha: isDark ? 0.20 : 0.16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassIconBadge(
                icon: Icons.auto_awesome_rounded,
                tint: colorScheme.primary,
                size: 56,
              ),
              const Spacer(),
              _AboutPill(
                icon: Ionicons.layers_outline,
                label: 'v$version',
                tint: colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '工大盒子',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCheckUpdates,
              icon:
                  isCheckingUpdate
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Ionicons.refresh_outline, size: 18),
              label: Text(isCheckingUpdate ? '检查中...' : '检查更新'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSectionPanel extends StatelessWidget {
  const _AboutSectionPanel({
    required this.icon,
    required this.title,
    required this.tint,
    required this.useLiteEffects,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Color tint;
  final bool useLiteEffects;
  final Widget child;

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
          tint.withValues(alpha: isDark ? 0.22 : 0.16),
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
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _AboutBackButton extends StatelessWidget {
  const _AboutBackButton({required this.onTap, required this.useLiteEffects});

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

class _AboutPill extends StatelessWidget {
  const _AboutPill({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tint.withValues(alpha: isDark ? 0.24 : 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tint),
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

class _AboutFactLine extends StatelessWidget {
  const _AboutFactLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
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
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _RepoTile extends StatelessWidget {
  const _RepoTile({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.icon,
    required this.accent,
    required this.useLiteEffects,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String url;
  final IconData icon;
  final Color accent;
  final bool useLiteEffects;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassPanel(
      style: GlassPanelStyle.list,
      blur: useLiteEffects ? 0 : 18,
      useBackdropFilter: !useLiteEffects,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.10 : 0.68),
          accent.withValues(alpha: isDark ? 0.18 : 0.12),
        ],
      ),
      borderColor: accent.withValues(alpha: isDark ? 0.18 : 0.14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassIconBadge(icon: icon, tint: accent, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  url,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Ionicons.open_outline, size: 18, color: accent),
        ],
      ),
    );
  }
}

class _ContributorTile extends StatelessWidget {
  const _ContributorTile({
    required this.name,
    required this.role,
    required this.accent,
    required this.useLiteEffects,
  });

  final String name;
  final String role;
  final Color accent;
  final bool useLiteEffects;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            useLiteEffects
                ? theme.colorScheme.surfaceContainerHigh
                : Colors.white.withValues(alpha: isDark ? 0.08 : 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              useLiteEffects
                  ? accent.withValues(alpha: isDark ? 0.18 : 0.14)
                  : Colors.white.withValues(alpha: isDark ? 0.08 : 0.60),
        ),
      ),
      child: Row(
        children: [
          GlassIconBadge(icon: Ionicons.person_outline, tint: accent, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
