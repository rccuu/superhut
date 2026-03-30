import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/apple_glass.dart';

class TrustCenterPage extends StatelessWidget {
  const TrustCenterPage({super.key});

  static final Uri _repoUrl = Uri.parse('https://github.com/rccuu/superhut');
  static final Uri _releaseUrl = Uri.parse(
    'https://github.com/rccuu/superhut/releases',
  );
  static final Uri _docUrl = Uri.parse(
    'https://github.com/rccuu/superhut/blob/main/docs/trust-and-privacy.md',
  );

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (context) => const TrustCenterPage(),
    );
  }

  Future<void> _openUrl(BuildContext context, Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法打开链接：$url')));
    }
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
      body: AppGlassBackground(
        style: AppGlassBackgroundStyle.soft,
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(16, topInset + 74, 16, 28),
              children: [
                GlassPanel(
                  style: GlassPanelStyle.hero,
                  blur: useLiteLayout ? 0 : 24,
                  useBackdropFilter: !useLiteLayout,
                  borderRadius: BorderRadius.circular(34),
                  padding: const EdgeInsets.all(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.82),
                      colorScheme.primary.withValues(alpha: 0.18),
                      colorScheme.secondary.withValues(alpha: 0.14),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GlassIconBadge(
                            icon: Ionicons.shield_checkmark_outline,
                            tint: colorScheme.primary,
                            size: 56,
                          ),
                          const Spacer(),
                          _TrustChip(
                            icon: Ionicons.logo_github,
                            label: '公开仓库',
                            tint: colorScheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '信任与隐私',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '给不想先看源码，也想知道工大盒子会连到哪里、会存什么、为什么要权限的同学。',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _TrustChip(
                            icon: Ionicons.cloud_outline,
                            label: '更新来自 GitHub',
                            tint: colorScheme.secondary,
                          ),
                          _TrustChip(
                            icon: Ionicons.phone_portrait_outline,
                            label: '数据默认留在本机',
                            tint: colorScheme.tertiary,
                          ),
                          _TrustChip(
                            icon: Ionicons.globe_outline,
                            label: '无作者私有后端',
                            tint: colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _TrustSectionPanel(
                  icon: Ionicons.checkmark_circle_outline,
                  title: '先看结论',
                  tint: colorScheme.primary,
                  useLiteEffects: useLiteLayout,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TrustBullet(text: '源码、版本发布和应用内更新入口都公开在 GitHub。'),
                      SizedBox(height: 10),
                      _TrustBullet(
                        text: '当前公开代码里，主要业务接口域名是学校系统、校园生活服务提供方和 GitHub。',
                      ),
                      SizedBox(height: 10),
                      _TrustBullet(
                        text: '登录凭证只用于直接请求学校和对应服务接口，不会额外转发到作者自建服务器。',
                      ),
                      SizedBox(height: 10),
                      _TrustBullet(text: '密码优先保存在系统安全存储中，登录态和缓存默认保存在你的设备上。'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _TrustSectionPanel(
                  icon: Ionicons.globe_outline,
                  title: '当前可见的主要联网目标',
                  tint: colorScheme.secondary,
                  useLiteEffects: useLiteLayout,
                  child: const Column(
                    children: [
                      _TrustServiceTile(
                        domain: 'github.com',
                        purpose: '检查 GitHub Releases、打开仓库和更新页面',
                      ),
                      SizedBox(height: 12),
                      _TrustServiceTile(
                        domain: 'mycas.hut.edu.cn / jwxtsj.hut.edu.cn',
                        purpose: '统一认证登录与教务系统相关功能',
                      ),
                      SizedBox(height: 12),
                      _TrustServiceTile(
                        domain: 'portal.hut.edu.cn / v8mobile.hut.edu.cn',
                        purpose: '校园门户、水电、洗浴等生活服务',
                      ),
                      SizedBox(height: 12),
                      _TrustServiceTile(
                        domain: 'authx-service.hut.edu.cn / i.ilife798.com',
                        purpose: '电费认证与饮水设备服务',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _TrustSectionPanel(
                  icon: Ionicons.folder_open_outline,
                  title: '本地会存什么',
                  tint: colorScheme.tertiary,
                  useLiteEffects: useLiteLayout,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TrustBullet(text: '用户名、登录方式、登录态 token / session。'),
                      SizedBox(height: 10),
                      _TrustBullet(text: '课表缓存、小组件数据、个人资料摘要。'),
                      SizedBox(height: 10),
                      _TrustBullet(text: '密码优先走系统安全存储；部分登录态仍使用应用本地存储来维持登录。'),
                      SizedBox(height: 10),
                      _TrustBullet(text: '这些数据默认只保存在本机，不会同步到作者私有服务器。'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _TrustSectionPanel(
                  icon: Ionicons.key_outline,
                  title: '为什么需要这些权限',
                  tint: colorScheme.error,
                  useLiteEffects: useLiteLayout,
                  child: const Column(
                    children: [
                      _TrustPermissionTile(
                        title: '网络权限',
                        description: '访问学校系统、校园生活服务接口，以及 GitHub Releases 更新信息。',
                      ),
                      SizedBox(height: 12),
                      _TrustPermissionTile(
                        title: '相机权限',
                        description: '扫码导入课表或扫描饮水设备二维码，不授予时只影响扫码功能。',
                      ),
                      SizedBox(height: 12),
                      _TrustPermissionTile(
                        title: '位置权限',
                        description: '仅在部分校园生活服务 WebView 页面需要定位能力时请求。',
                      ),
                      SizedBox(height: 12),
                      _TrustPermissionTile(
                        title: '开机启动 / 唤醒 / 网络状态',
                        description: '主要用于 Android 小组件刷新与可用性判断。',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _TrustSectionPanel(
                  icon: Ionicons.search_outline,
                  title: '你可以自己怎么检查',
                  tint: colorScheme.primary,
                  useLiteEffects: useLiteLayout,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _TrustBullet(
                        text: '只从当前仓库公开的 GitHub Release 页面下载安装包。',
                      ),
                      const SizedBox(height: 10),
                      const _TrustBullet(text: '对照仓库源码和构建脚本，确认更新来源是公开的。'),
                      const SizedBox(height: 10),
                      const _TrustBullet(
                        text: '如果遇到看不懂的权限或联网行为，直接提 Issue 让维护者公开解释。',
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _openUrl(context, _repoUrl),
                            icon: const Icon(Ionicons.logo_github, size: 18),
                            label: const Text('打开仓库'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _openUrl(context, _releaseUrl),
                            icon: const Icon(
                              Ionicons.download_outline,
                              size: 18,
                            ),
                            label: const Text('查看发布'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _openUrl(context, _docUrl),
                            icon: const Icon(
                              Ionicons.document_text_outline,
                              size: 18,
                            ),
                            label: const Text('仓库说明'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: topInset + 12,
              left: 16,
              child: GlassPanel(
                style: GlassPanelStyle.floating,
                blur: useLiteLayout ? 0 : 18,
                useBackdropFilter: !useLiteLayout,
                borderRadius: BorderRadius.circular(18),
                padding: EdgeInsets.zero,
                onTap: () => Navigator.of(context).maybePop(),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustSectionPanel extends StatelessWidget {
  const _TrustSectionPanel({
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
    return GlassPanel(
      style: GlassPanelStyle.card,
      blur: useLiteEffects ? 0 : 22,
      useBackdropFilter: !useLiteEffects,
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.all(22),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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

class _TrustChip extends StatelessWidget {
  const _TrustChip({
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

class _TrustBullet extends StatelessWidget {
  const _TrustBullet({required this.text});

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

class _TrustServiceTile extends StatelessWidget {
  const _TrustServiceTile({required this.domain, required this.purpose});

  final String domain;
  final String purpose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.56,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            domain,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            purpose,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustPermissionTile extends StatelessWidget {
  const _TrustPermissionTile({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.56,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Ionicons.key_outline,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
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
                const SizedBox(height: 6),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
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
