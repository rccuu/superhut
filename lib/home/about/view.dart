import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_update_service.dart';
import '../../core/ui/apple_glass.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

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

  String _version = '--';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(16, topInset + 74, 16, 28),
              children: [
                _AboutHeroCard(
                  version: _version,
                  isCheckingUpdate: _isCheckingUpdate,
                  onCheckUpdates:
                      _isCheckingUpdate || _version == '--'
                          ? null
                          : _checkForUpdates,
                ),
                const SizedBox(height: 16),
                _AboutSectionPanel(
                  icon: Ionicons.logo_github,
                  title: '仓库',
                  tint: colorScheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RepoTile(
                        title: '当前仓库',
                        subtitle: 'rccuu/superhut',
                        url: _forkRepoUrl.toString(),
                        icon: Ionicons.git_branch_outline,
                        accent: colorScheme.primary,
                        onTap: () => _openUrl(_forkRepoUrl),
                      ),
                      const SizedBox(height: 12),
                      _RepoTile(
                        title: '原作仓库',
                        subtitle: 'cc2562/superhut',
                        url: _upstreamRepoUrl.toString(),
                        icon: Ionicons.logo_github,
                        accent: colorScheme.secondary,
                        onTap: () => _openUrl(_upstreamRepoUrl),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _AboutSectionPanel(
                  icon: Ionicons.person_outline,
                  title: '开发者',
                  tint: colorScheme.tertiary,
                  child: _ContributorTile(
                    name: 'CC米饭',
                    role: '原项目作者',
                    accent: colorScheme.tertiary,
                  ),
                ),
              ],
            ),
            Positioned(
              top: topInset + 12,
              left: 16,
              child: _AboutBackButton(
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutHeroCard extends StatelessWidget {
  const _AboutHeroCard({
    required this.version,
    required this.isCheckingUpdate,
    required this.onCheckUpdates,
  });

  final String version;
  final bool isCheckingUpdate;
  final VoidCallback? onCheckUpdates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GlassPanel(
      blur: 24,
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
              icon: isCheckingUpdate
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
    required this.child,
  });

  final IconData icon;
  final String title;
  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GlassPanel(
      blur: 22,
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
  const _AboutBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GlassPanel(
      blur: 18,
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
        border: Border.all(
          color: tint.withValues(alpha: isDark ? 0.24 : 0.18),
        ),
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

class _RepoTile extends StatelessWidget {
  const _RepoTile({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String url;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassPanel(
      blur: 18,
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
  });

  final String name;
  final String role;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.60),
        ),
      ),
      child: Row(
        children: [
          GlassIconBadge(
            icon: Ionicons.person_outline,
            tint: accent,
            size: 44,
          ),
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
