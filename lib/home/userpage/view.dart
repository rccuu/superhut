import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bridge/get_course_page.dart';
import '../../core/services/app_auth_storage.dart';
import '../../core/services/app_logger.dart';
import '../../core/ui/apple_glass.dart';
import '../../login/unified_login_page.dart';
import '../../pages/score/logic.dart';
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
  static const String _cachedBalanceKey = 'user_page_cached_balance';
  final hutUserApi = HutUserApi();
  final Uri _url = Uri.parse(
    'alipays://platformapi/startapp?appId=2019030163398604&page=pages/index/index',
  );
  bool _isInitialized = false;
  bool _hasLinkedCampusAccount = false;
  bool _isLoadingBalance = false;
  bool _isRefreshingBalance = false;
  bool _isRefreshingScoreSummary = false;
  String _balance = '--';
  Map<String, String> _profile = _defaultProfile();

  @override
  void initState() {
    super.initState();
    _loadPageData();
  }

  static Map<String, String> _defaultProfile() {
    return {
      'name': '同学',
      'entranceYear': '--',
      'academyName': '未绑定学院',
      'clsName': '未绑定班级',
      'yxzxf': '-',
      'zxfjd': '-',
      'pjxfjd': '-',
    };
  }

  Map<String, String> _profileFromPrefs(SharedPreferences prefs) {
    return {
      'name': prefs.getString('name') ?? '同学',
      'entranceYear': prefs.getString('entranceYear') ?? '--',
      'academyName': prefs.getString('academyName') ?? '未绑定学院',
      'clsName': prefs.getString('clsName') ?? '未绑定班级',
      'yxzxf': prefs.getString('yxzxf') ?? '-',
      'zxfjd': prefs.getString('zxfjd') ?? '-',
      'pjxfjd': prefs.getString('pjxfjd') ?? '-',
    };
  }

  String _normalizeBalance(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'null') {
      return '--';
    }
    return trimmed;
  }

  Future<void> _loadPageData() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = AppAuthStorage.instance;
    final hasLinkedCampusAccount = await storage.hasLinkedCampusAccount();
    final profile = _profileFromPrefs(prefs);
    final cachedBalance = _normalizeBalance(
      prefs.getString(_cachedBalanceKey) ?? '--',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isInitialized = true;
      _hasLinkedCampusAccount = hasLinkedCampusAccount;
      _profile = profile;
      _balance = hasLinkedCampusAccount ? cachedBalance : '--';
      _isLoadingBalance = false;
    });

    if (hasLinkedCampusAccount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_refreshScoreSummaryInBackground());
      });
      await _refreshBalance(showStatus: cachedBalance == '--');
    }
  }

  Future<void> _reloadProfileFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final nextProfile = _profileFromPrefs(prefs);
    if (!mounted) {
      return;
    }

    setState(() {
      _profile = nextProfile;
    });
  }

  Future<void> _refreshScoreSummaryInBackground() async {
    if (!_hasLinkedCampusAccount || _isRefreshingScoreSummary) {
      return;
    }

    _isRefreshingScoreSummary = true;
    try {
      final scoreData = await getScore('');
      if (!mounted || scoreData.errorMessage != null) {
        return;
      }

      setState(() {
        _profile = {
          ..._profile,
          'yxzxf': scoreData.yxzxf,
          'zxfjd': scoreData.zxfjd,
          'pjxfjd': scoreData.pjxfjd,
        };
      });
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to refresh score summary on user page',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isRefreshingScoreSummary = false;
    }
  }

  Future<void> _refreshBalance({bool showStatus = true}) async {
    if (!_hasLinkedCampusAccount || _isRefreshingBalance) {
      return;
    }

    _isRefreshingBalance = true;
    if (showStatus && mounted) {
      setState(() {
        _isLoadingBalance = true;
      });
    }

    try {
      final value = await hutUserApi.getCardBalance();
      final normalized = _normalizeBalance(value);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedBalanceKey, normalized);
      if (!mounted) {
        return;
      }
      setState(() {
        _balance = normalized;
      });
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load card balance on user page',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isRefreshingBalance = false;
      if (mounted) {
        setState(() {
          _isLoadingBalance = false;
        });
      }
    }
  }

  Future<void> _launchUrl() async {
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }

  Future<void> _openLoginPage() async {
    await Navigator.of(context).push(UnifiedLoginPage.route());
    await _loadPageData();
  }

  Future<void> _openAboutPage() async {
    await Navigator.of(context).push(AboutPage.route());
  }

  Future<void> _openScorePage() async {
    final renewed = await renewToken(context);
    if (!mounted) {
      return;
    }
    if (!renewed) {
      await _openLoginPage();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScorePage()),
    );
    await _reloadProfileFromPrefs();
    unawaited(_refreshScoreSummaryInBackground());
  }

  Future<void> _refreshCourse() async {
    final renewed = await renewToken(context);
    if (!mounted) {
      return;
    }
    if (!renewed) {
      await _openLoginPage();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const Getcoursepage(renew: true)),
    );
  }

  Future<void> _logout() async {
    final storage = AppAuthStorage.instance;
    final prefs = await SharedPreferences.getInstance();
    await storage.clearAllAuthData();
    await storage.setFirstOpen(false);
    await prefs.remove(_cachedBalanceKey);
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushAndRemoveUntil(UnifiedLoginPage.route(), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppGlassBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              if (!_isInitialized)
                _buildLoadingShell(theme)
              else if (!_hasLinkedCampusAccount) ...[
                _buildGuestCard(theme),
                const SizedBox(height: 16),
                _buildActionPanel(
                  children: [
                    _buildActionTile(
                      icon: Ionicons.information_circle_outline,
                      title: '关于工大盒子',
                      subtitle: '查看版本信息、开源说明与更新入口',
                      onTap: _openAboutPage,
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: '已修学分',
                        value: _profile['yxzxf'] ?? '-',
                        accent: const Color(0xFF1E8A6F),
                        icon: Ionicons.ribbon_outline,
                        onTap: _openScorePage,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildStatCard(
                        title: '平均绩点',
                        value: _profile['pjxfjd'] ?? '-',
                        accent: const Color(0xFFE28A2E),
                        icon: Ionicons.stats_chart_outline,
                        onTap: _openScorePage,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildBalanceCard(
                  theme,
                  _balance,
                  isLoading: _isLoadingBalance,
                ),
                const SizedBox(height: 16),
                _buildActionPanel(
                  children: [
                    _buildActionTile(
                      icon: Ionicons.refresh_outline,
                      title: '刷新课表',
                      subtitle: '需要时再手动同步本地课表',
                      onTap: _refreshCourse,
                    ),
                    _buildDivider(),
                    _buildActionTile(
                      icon: Ionicons.information_circle_outline,
                      title: '关于工大盒子',
                      subtitle: '查看版本信息、开源说明与更新入口',
                      onTap: _openAboutPage,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDangerTile(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShell(ThemeData theme) {
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
          Colors.white.withValues(alpha: isDark ? 0.14 : 0.80),
          colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.14),
          colorScheme.secondary.withValues(alpha: isDark ? 0.16 : 0.12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '正在读取个人信息',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '页面会先显示本地内容，再后台刷新需要联网的数据。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 28,
            color: accent,
            shadows: [
              Shadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
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
    );
  }

  Widget _buildGuestCard(ThemeData theme) {
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
          Colors.white.withValues(alpha: isDark ? 0.16 : 0.82),
          colorScheme.primary.withValues(alpha: isDark ? 0.26 : 0.18),
          colorScheme.secondary.withValues(alpha: isDark ? 0.20 : 0.15),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassIconBadge(
                icon: Ionicons.person_outline,
                tint: colorScheme.primary,
                size: 54,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.48),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.72),
                  ),
                ),
                child: Text(
                  '游客模式',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '当前未登录',
            style: theme.textTheme.headlineMedium?.copyWith(
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '无需登录可直接使用：慧生活798。课表、成绩、考试安排、评教、空教室查询等校园功能，需要登录校园账号后才能使用。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _GuestFeatureChip(
                icon: Ionicons.water_outline,
                label: '无需登录：慧生活798',
              ),
              _GuestFeatureChip(icon: Ionicons.apps_outline, label: '登录后：其他功能'),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openLoginPage,
              icon: const Icon(Icons.login_rounded),
              label: const Text('登录校园账号'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(
    ThemeData theme,
    String balance, {
    required bool isLoading,
  }) {
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
              if (isLoading)
                Text(
                  '更新中',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
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
                  '清除当前登录状态；无需登录的功能仍然可以继续使用。',
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

class _GuestFeatureChip extends StatelessWidget {
  const _GuestFeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.52),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.72),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
