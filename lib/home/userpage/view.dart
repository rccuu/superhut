import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_auth_storage.dart';
import '../../core/services/app_logger.dart';
import '../../core/services/course_sync_service.dart';
import '../../core/ui/app_page_route.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/apple_glass.dart';
import '../../login/unified_login_page.dart';
import '../../pages/score/logic.dart';
import '../../pages/score/scorepage.dart';
import '../../utils/course/coursemain.dart';
import '../../utils/hut_user_api.dart';
import '../../utils/token.dart';
import '../about/view.dart';

typedef UserPageTokenRenewer = Future<bool> Function(BuildContext context);
typedef UserPageTokenLoader = Future<String> Function();
typedef UserPageCourseSyncStarter = Future<bool> Function(String token);
typedef UserPageBalanceLoader = Future<String> Function();
typedef UserPageScoreSummaryLoader = Future<ScoreLoadResult> Function();
typedef UserPageRouteOpener = Future<void> Function(BuildContext context);
typedef UserPageUrlOpener = Future<bool> Function(Uri url);

class _UserPageAccountState {
  const _UserPageAccountState({
    required this.isInitialized,
    required this.hasLinkedCampusAccount,
  });

  const _UserPageAccountState.loading()
    : this(isInitialized: false, hasLinkedCampusAccount: false);

  final bool isInitialized;
  final bool hasLinkedCampusAccount;

  _UserPageAccountState copyWith({
    bool? isInitialized,
    bool? hasLinkedCampusAccount,
  }) {
    return _UserPageAccountState(
      isInitialized: isInitialized ?? this.isInitialized,
      hasLinkedCampusAccount:
          hasLinkedCampusAccount ?? this.hasLinkedCampusAccount,
    );
  }
}

class _UserPageBalanceState {
  const _UserPageBalanceState({required this.value, required this.isLoading});

  const _UserPageBalanceState.initial() : this(value: '--', isLoading: false);

  final String value;
  final bool isLoading;

  _UserPageBalanceState copyWith({String? value, bool? isLoading}) {
    return _UserPageBalanceState(
      value: value ?? this.value,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class UserPage extends StatefulWidget {
  const UserPage({
    super.key,
    this.loadPrefs,
    this.hasLinkedCampusAccount,
    this.renewJwxtToken,
    this.loadJwxtToken,
    this.startCourseSync,
    this.loadBalance,
    this.loadScoreSummary,
    this.openLoginPage,
    this.openAboutPage,
    this.openScorePage,
    this.openRechargePage,
  });

  final Future<SharedPreferences> Function()? loadPrefs;
  final Future<bool> Function()? hasLinkedCampusAccount;
  final UserPageTokenRenewer? renewJwxtToken;
  final UserPageTokenLoader? loadJwxtToken;
  final UserPageCourseSyncStarter? startCourseSync;
  final UserPageBalanceLoader? loadBalance;
  final UserPageScoreSummaryLoader? loadScoreSummary;
  final UserPageRouteOpener? openLoginPage;
  final UserPageRouteOpener? openAboutPage;
  final UserPageRouteOpener? openScorePage;
  final UserPageUrlOpener? openRechargePage;

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  static const String _cachedBalanceKey = 'user_page_cached_balance';
  final hutUserApi = HutUserApi();
  final Uri _url = Uri.parse(
    'alipays://platformapi/startapp?appId=2019030163398604&page=pages/index/index',
  );
  bool _isRefreshingCourse = false;
  bool _isOpeningLoginPage = false;
  bool _isOpeningAboutPage = false;
  bool _isOpeningScorePage = false;
  bool _isOpeningRechargePage = false;
  bool _isLoggingOut = false;
  int _pageDataGeneration = 0;
  int? _balanceRefreshGeneration;
  int? _scoreSummaryRefreshGeneration;
  late final ValueNotifier<Map<String, String>> _profileNotifier =
      ValueNotifier<Map<String, String>>(_defaultProfile());
  late final ValueNotifier<_UserPageAccountState> _accountStateNotifier =
      ValueNotifier<_UserPageAccountState>(
        const _UserPageAccountState.loading(),
      );
  late final ValueNotifier<_UserPageBalanceState> _balanceStateNotifier =
      ValueNotifier<_UserPageBalanceState>(
        const _UserPageBalanceState.initial(),
      );

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

  int _nextPageDataGeneration() {
    return ++_pageDataGeneration;
  }

  bool _isLatestPageDataGeneration(int generation) {
    return mounted && generation == _pageDataGeneration;
  }

  bool get _hasLinkedCampusAccount =>
      _accountStateNotifier.value.hasLinkedCampusAccount;

  bool _hasSameProfileValues(
    Map<String, String> currentProfile,
    Map<String, String> nextProfile,
  ) {
    if (currentProfile.length != nextProfile.length) {
      return false;
    }
    for (final entry in nextProfile.entries) {
      if (currentProfile[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  void _applyProfileIfChanged(Map<String, String> nextProfile) {
    final currentProfile = _profileNotifier.value;
    if (_hasSameProfileValues(currentProfile, nextProfile)) {
      return;
    }
    _profileNotifier.value = nextProfile;
  }

  void _applyAccountStateIfChanged(bool hasLinkedCampusAccount) {
    final currentState = _accountStateNotifier.value;
    if (currentState.isInitialized &&
        currentState.hasLinkedCampusAccount == hasLinkedCampusAccount) {
      return;
    }

    _accountStateNotifier.value = currentState.copyWith(
      isInitialized: true,
      hasLinkedCampusAccount: hasLinkedCampusAccount,
    );
  }

  void _applyBalanceStateIfChanged({String? value, bool? isLoading}) {
    final currentState = _balanceStateNotifier.value;
    final nextState = currentState.copyWith(value: value, isLoading: isLoading);
    if (currentState.value == nextState.value &&
        currentState.isLoading == nextState.isLoading) {
      return;
    }

    _balanceStateNotifier.value = nextState;
  }

  Future<void> _loadPageData() async {
    final generation = _nextPageDataGeneration();
    late final SharedPreferences prefs;
    late final bool hasLinkedCampusAccount;
    try {
      final results = await Future.wait<Object>([
        (widget.loadPrefs ?? SharedPreferences.getInstance)(),
        (widget.hasLinkedCampusAccount ??
            AppAuthStorage.instance.hasLinkedCampusAccount)(),
      ]);
      prefs = results[0] as SharedPreferences;
      hasLinkedCampusAccount = results[1] as bool;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load user page data',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isLatestPageDataGeneration(generation)) {
        return;
      }

      _applyProfileIfChanged(_defaultProfile());
      _applyBalanceStateIfChanged(value: '--', isLoading: false);
      _applyAccountStateIfChanged(false);
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        message: '个人信息加载失败，请稍后重试',
        type: AppSnackBarType.error,
      );
      return;
    }

    if (!_isLatestPageDataGeneration(generation)) {
      return;
    }

    final profile = _profileFromPrefs(prefs);
    final cachedBalance = _normalizeBalance(
      prefs.getString(_cachedBalanceKey) ?? '--',
    );
    _applyProfileIfChanged(profile);
    _applyBalanceStateIfChanged(
      value: hasLinkedCampusAccount ? cachedBalance : '--',
      isLoading: false,
    );
    _applyAccountStateIfChanged(hasLinkedCampusAccount);

    if (hasLinkedCampusAccount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isLatestPageDataGeneration(generation)) {
          return;
        }
        unawaited(_refreshScoreSummaryInBackground(generation: generation));
      });
      await _refreshBalance(
        showStatus: cachedBalance == '--',
        generation: generation,
      );
    }
  }

  @visibleForTesting
  Future<void> debugReloadPageData() => _loadPageData();

  Future<void> _reloadProfileFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final nextProfile = _profileFromPrefs(prefs);
    if (!mounted) {
      return;
    }

    _applyProfileIfChanged(nextProfile);
  }

  void _applyScoreSummaryIfChanged(ScoreLoadResult scoreData) {
    final currentProfile = _profileNotifier.value;
    if (currentProfile['yxzxf'] == scoreData.yxzxf &&
        currentProfile['zxfjd'] == scoreData.zxfjd &&
        currentProfile['pjxfjd'] == scoreData.pjxfjd) {
      return;
    }

    _profileNotifier.value = {
      ...currentProfile,
      'yxzxf': scoreData.yxzxf,
      'zxfjd': scoreData.zxfjd,
      'pjxfjd': scoreData.pjxfjd,
    };
  }

  Future<void> _refreshScoreSummaryInBackground({int? generation}) async {
    final refreshGeneration = generation ?? _pageDataGeneration;
    if (!_hasLinkedCampusAccount ||
        _scoreSummaryRefreshGeneration == refreshGeneration) {
      return;
    }

    _scoreSummaryRefreshGeneration = refreshGeneration;
    try {
      final scoreData = await (widget.loadScoreSummary ?? () => getScore(''))();
      if (!mounted ||
          scoreData.errorMessage != null ||
          refreshGeneration != _pageDataGeneration) {
        return;
      }

      _applyScoreSummaryIfChanged(scoreData);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to refresh score summary on user page',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (_scoreSummaryRefreshGeneration == refreshGeneration) {
        _scoreSummaryRefreshGeneration = null;
      }
    }
  }

  Future<void> _refreshBalance({
    bool showStatus = true,
    int? generation,
  }) async {
    final refreshGeneration = generation ?? _pageDataGeneration;
    if (!_hasLinkedCampusAccount ||
        _balanceRefreshGeneration == refreshGeneration) {
      return;
    }

    _balanceRefreshGeneration = refreshGeneration;
    if (showStatus && mounted) {
      _applyBalanceStateIfChanged(isLoading: true);
    }

    try {
      final value = await (widget.loadBalance ?? hutUserApi.getCardBalance)();
      final normalized = _normalizeBalance(value);
      if (!mounted || refreshGeneration != _pageDataGeneration) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || refreshGeneration != _pageDataGeneration) {
        return;
      }
      await prefs.setString(_cachedBalanceKey, normalized);
      if (!mounted || refreshGeneration != _pageDataGeneration) {
        return;
      }
      _applyBalanceStateIfChanged(value: normalized);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to load card balance on user page',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (_balanceRefreshGeneration == refreshGeneration) {
        _balanceRefreshGeneration = null;
      }
      if (mounted && refreshGeneration == _pageDataGeneration) {
        _applyBalanceStateIfChanged(isLoading: false);
      }
    }
  }

  Future<void> _launchUrl() async {
    if (_isOpeningRechargePage) {
      return;
    }

    _isOpeningRechargePage = true;
    try {
      final openRechargePage =
          widget.openRechargePage ?? (Uri url) => launchUrl(url);
      final opened = await openRechargePage(_url);
      if (!opened && mounted) {
        showAppSnackBar(
          context,
          message: '无法打开充值入口',
          type: AppSnackBarType.error,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to open recharge page from user page',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          message: '无法打开充值入口',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _isOpeningRechargePage = false;
    }
  }

  @override
  void dispose() {
    _accountStateNotifier.dispose();
    _profileNotifier.dispose();
    _balanceStateNotifier.dispose();
    super.dispose();
  }

  Future<void> _openLoginPage() async {
    if (_isOpeningLoginPage) {
      return;
    }

    _isOpeningLoginPage = true;
    try {
      await (widget.openLoginPage ?? _pushLoginPage)(context);
      if (!mounted) {
        return;
      }
      await _loadPageData();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to open login page from user page',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          message: '无法打开登录页面，请稍后重试',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _isOpeningLoginPage = false;
    }
  }

  Future<void> _openAboutPage() async {
    if (_isOpeningAboutPage) {
      return;
    }

    _isOpeningAboutPage = true;
    try {
      await (widget.openAboutPage ?? _pushAboutPage)(context);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to open about page from user page',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          message: '无法打开关于页面，请稍后重试',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _isOpeningAboutPage = false;
    }
  }

  Future<void> _openScorePage() async {
    if (_isOpeningScorePage) {
      return;
    }

    _isOpeningScorePage = true;
    try {
      final renewed = await (widget.renewJwxtToken ?? renewToken)(context);
      if (!mounted) {
        return;
      }
      if (!renewed) {
        return;
      }

      await (widget.openScorePage ?? _pushScorePage)(context);
      if (!mounted) {
        return;
      }
      await _reloadProfileFromPrefs();
      unawaited(_refreshScoreSummaryInBackground());
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to open score page from user page',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          message: '无法打开成绩页面，请稍后重试',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _isOpeningScorePage = false;
    }
  }

  Future<void> _pushLoginPage(BuildContext context) async {
    await Navigator.of(context).push(UnifiedLoginPage.route());
  }

  Future<void> _pushAboutPage(BuildContext context) async {
    await Navigator.of(context).push(AboutPage.route());
  }

  Future<void> _pushScorePage(BuildContext context) async {
    await Navigator.push(
      context,
      buildAppPageRoute(builder: (_) => const ScorePage()),
    );
  }

  Future<void> _refreshCourse() async {
    if (_isRefreshingCourse || CourseSyncService.instance.state.isRunning) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: '课表正在同步，请稍候',
          type: AppSnackBarType.info,
        );
      }
      return;
    }

    _isRefreshingCourse = true;
    try {
      final renewed = await (widget.renewJwxtToken ?? renewToken)(context);
      if (!mounted) {
        return;
      }
      if (!renewed) {
        return;
      }
      final token = await (widget.loadJwxtToken ?? getToken)();
      if (!mounted) {
        return;
      }
      final started = await (widget.startCourseSync ??
          CourseSyncService.instance.startManualSync)(token);
      if (!started && mounted && CourseSyncService.instance.state.isRunning) {
        showAppSnackBar(
          context,
          message: '课表正在同步，请稍候',
          type: AppSnackBarType.info,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to refresh course from user page',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          message: '课表刷新失败，请稍后重试',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _isRefreshingCourse = false;
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) {
      return;
    }

    _isLoggingOut = true;
    final storage = AppAuthStorage.instance;
    final prefs = await SharedPreferences.getInstance();
    await clearCourseSchedules(
      sourceTypes: {
        CourseScheduleSourceType.selfSync,
        CourseScheduleSourceType.migratedLegacy,
      },
    );
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

    return AppGlassPerformanceScope(
      isLite: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppGlassBackground(
          style: AppGlassBackgroundStyle.soft,
          bottomHighlightOpacity: 0,
          lightBottomColor: const Color(0xFFEAF0FA),
          darkBottomColor: const Color(0xFF101826),
          child: SafeArea(
            bottom: false,
            child: ValueListenableBuilder<_UserPageAccountState>(
              valueListenable: _accountStateNotifier,
              builder: (context, accountState, _) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
                  children: [
                    if (!accountState.isInitialized)
                      _buildLoadingShell(theme)
                    else if (!accountState.hasLinkedCampusAccount) ...[
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
                      ValueListenableBuilder<Map<String, String>>(
                        valueListenable: _profileNotifier,
                        builder: (context, profile, _) {
                          return Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  title: '已修学分',
                                  value: profile['yxzxf'] ?? '-',
                                  accent: const Color(0xFF1E8A6F),
                                  icon: Ionicons.ribbon_outline,
                                  onTap: _openScorePage,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildStatCard(
                                  title: '平均绩点',
                                  value: profile['pjxfjd'] ?? '-',
                                  accent: const Color(0xFFE28A2E),
                                  icon: Ionicons.stats_chart_outline,
                                  onTap: _openScorePage,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<_UserPageBalanceState>(
                        valueListenable: _balanceStateNotifier,
                        builder: (context, balanceState, _) {
                          return _buildBalanceCard(
                            theme,
                            balanceState.value,
                            isLoading: balanceState.isLoading,
                          );
                        },
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShell(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GlassPanel(
      style: GlassPanelStyle.hero,
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
      style: GlassPanelStyle.card,
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
      style: GlassPanelStyle.hero,
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
      style: GlassPanelStyle.card,
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
      style: GlassPanelStyle.list,
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
      style: GlassPanelStyle.card,
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
