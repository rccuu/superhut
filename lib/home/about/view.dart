import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_update_service.dart';

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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('关于工大盒子')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('工大盒子', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  '工大盒子是一款面向湖南工业大学学生的校园工具应用，帮助你更便捷地查看课表、成绩与常用校园服务。',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Ionicons.layers_outline, size: 18),
                    const SizedBox(width: 8),
                    Text('当前版本：$_version', style: theme.textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed:
                        _isCheckingUpdate || _version == '--'
                            ? null
                            : _checkForUpdates,
                    icon:
                        _isCheckingUpdate
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Ionicons.refresh_outline, size: 18),
                    label: Text(_isCheckingUpdate ? '检查中...' : '检查更新'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('项目说明', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  '当前项目基于原作仓库 fork 后进行二次开发与维护。为避免来源混淆，下面同时保留二次开发仓库与原作仓库地址。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _RepoTile(
                  title: '二次开发仓库',
                  subtitle: 'rccuu/superhut',
                  url: _forkRepoUrl.toString(),
                  icon: Ionicons.git_branch_outline,
                  onTap: () => _openUrl(_forkRepoUrl),
                ),
                const SizedBox(height: 12),
                _RepoTile(
                  title: '原作仓库',
                  subtitle: 'cc2562/superhut',
                  url: _upstreamRepoUrl.toString(),
                  icon: Ionicons.logo_github,
                  onTap: () => _openUrl(_upstreamRepoUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('开发者', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Ionicons.person_outline,
                    color: colorScheme.primary,
                  ),
                  title: const Text('CC米饭'),
                  subtitle: const Text('原项目作者'),
                ),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  '感谢开源社区的持续贡献，也感谢原项目为后续二次开发提供基础。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}

class _RepoTile extends StatelessWidget {
  const _RepoTile({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String url;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Text(
                    url,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Ionicons.open_outline, size: 18),
          ],
        ),
      ),
    );
  }
}
