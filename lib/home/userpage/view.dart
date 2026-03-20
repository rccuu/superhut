import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bridge/get_course_page.dart';
import '../../core/services/app_auth_storage.dart';
import '../../core/services/app_logger.dart';
import '../../core/ui/apple_glass.dart';
import '../../login/unified_login_page.dart';
import '../../pages/score/scorepage.dart';
import '../../utils/hut_user_api.dart';
import '../../utils/token.dart';
import '../about/view.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final hutUserApi = HutUserApi();
  final Uri _url = Uri.parse(
    'alipays://platformapi/startapp?appId=2019030163398604&page=pages/index/index',
  );

  String balance = "--";

  @override
  void initState() {
    super.initState();
    getBalance();
  }

  Future<void> getBalance() async {
    try {
      final value = await hutUserApi.getCardBalance();
      if (!mounted) {
        return;
      }
      setState(() {
        balance = value.isEmpty ? '--' : value;
      });
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load card balance on user page',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        balance = '--';
      });
    }
  }

  Future<void> _launchUrl() async {
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }

  Future<Map<String, String>> getBaseData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "name": prefs.getString('name') ?? "同学",
      "entranceYear": prefs.getString('entranceYear') ?? "--",
      "academyName": prefs.getString('academyName') ?? "未绑定学院",
      "clsName": prefs.getString('clsName') ?? "未绑定班级",
      "yxzxf": prefs.getString('yxzxf') ?? "-",
      "zxfjd": prefs.getString('zxfjd') ?? "-",
      "pjxfjd": prefs.getString('pjxfjd') ?? "-",
    };
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openScorePage() async {
    final renewed = await renewToken(context);
    if (!mounted) {
      return;
    }
    if (!renewed) {
      _showSnackBar('成绩页登录状态已失效，请重新登录后重试');
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScorePage()),
    );
  }

  Future<void> _refreshCourse() async {
    final renewed = await renewToken(context);
    if (!mounted) {
      return;
    }
    if (!renewed) {
      _showSnackBar('课表刷新失败，请重新登录后重试');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const Getcoursepage(renew: true)),
    );
  }

  Future<void> _logout() async {
    final storage = AppAuthStorage.instance;
    await storage.clearAllAuthData();
    await storage.setFirstOpen(false);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const UnifiedLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        child: EnhancedFutureBuilder(
          future: getBaseData(),
          rememberFutureResult: true,
          whenDone: (data) {
            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: '已修学分',
                          value: data['yxzxf'] ?? '-',
                          accent: const Color(0xFF1E8A6F),
                          icon: Ionicons.ribbon_outline,
                          onTap: _openScorePage,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildStatCard(
                          title: '平均绩点',
                          value: data['pjxfjd'] ?? '-',
                          accent: const Color(0xFFE28A2E),
                          icon: Ionicons.stats_chart_outline,
                          onTap: _openScorePage,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildBalanceCard(theme),
                  const SizedBox(height: 16),
                  _buildActionPanel(
                    children: [
                      _buildActionTile(
                        icon: Ionicons.refresh_outline,
                        title: '刷新课表',
                        subtitle: '重新同步本地课表',
                        onTap: _refreshCourse,
                      ),
                      _buildDivider(),
                      _buildActionTile(
                        icon: Ionicons.information_circle_outline,
                        title: '关于软件',
                        subtitle: '查看版本和项目说明',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AboutPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDangerTile(),
                ],
              ),
            );
          },
          whenNotDone: Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required VoidCallback onTap,
    required String title,
    required String value,
    required Color accent,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return GlassPanel(
      blur: 18,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -14,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.18),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassIconBadge(icon: icon, tint: accent, size: 48),
              const SizedBox(height: 18),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(value, style: theme.textTheme.headlineMedium),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GlassPanel(
      blur: 22,
      borderRadius: BorderRadius.circular(32),
      padding: const EdgeInsets.all(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.14 : 0.74),
          colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.16),
          colorScheme.secondary.withValues(alpha: isDark ? 0.14 : 0.14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '校园卡余额',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.80),
                ),
              ),
              const Spacer(),
              Icon(
                Ionicons.wallet_outline,
                color: colorScheme.primary.withValues(alpha: 0.78),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                balance,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'CNY',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: _launchUrl,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(
                alpha: isDark ? 0.10 : 0.54,
              ),
              foregroundColor: colorScheme.primary,
            ),
            icon: const Icon(Ionicons.flash_outline, size: 18),
            label: const Text('前往充值'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel({required List<Widget> children}) {
    return GlassPanel(
      blur: 18,
      borderRadius: BorderRadius.circular(28),
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Future<void> Function() onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: () => onTap(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: GlassIconBadge(icon: icon, tint: colorScheme.primary, size: 44),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(
        Ionicons.chevron_forward_outline,
        size: 18,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildDivider() {
    return const GlassHairlineDivider(horizontal: 18);
  }

  Widget _buildDangerTile() {
    return GlassPanel(
      blur: 18,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(18),
      onTap: _logout,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(
            alpha:
                Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.70,
          ),
          const Color(0xFFD85B66).withValues(alpha: 0.12),
        ],
      ),
      borderColor: const Color(0xFFD85B66).withValues(alpha: 0.18),
      child: Row(
        children: [
          const GlassIconBadge(
            icon: Ionicons.log_out_outline,
            tint: Color(0xFFD85B66),
            size: 46,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('退出登录', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '清除当前账号会话并回到登录页。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Ionicons.chevron_forward_outline,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
