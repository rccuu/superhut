import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:superhut/pages/Commentary/commentary_batch_page.dart';
import 'package:superhut/pages/Electricitybill/electricity_page.dart';
import 'package:superhut/pages/ExamSchedule/exam_schedule_page.dart';
import 'package:superhut/pages/drink/view/view.dart';
import 'package:superhut/pages/freeroom/building.dart';
import 'package:superhut/pages/hutpages/hutmain.dart';
import 'package:superhut/pages/water/view.dart';

import '../../core/services/app_logger.dart';
import '../../core/ui/app_loading_indicator.dart';
import '../../core/ui/app_page_route.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/apple_glass.dart';
import '../../pages/score/scorepage.dart';
import '../../utils/token.dart';

typedef FunctionPageTokenRenewer = Future<bool> Function(BuildContext context);
typedef FunctionPageNavigator =
    Future<void> Function(BuildContext context, Widget page);

class FunctionPage extends StatefulWidget {
  const FunctionPage({super.key, this.renewJwxtToken, this.openPage});

  final FunctionPageTokenRenewer? renewJwxtToken;
  final FunctionPageNavigator? openPage;

  @override
  State<FunctionPage> createState() => _FunctionPageState();
}

class _FunctionPageState extends State<FunctionPage> {
  static final List<_FunctionFeature> _features =
      List<_FunctionFeature>.unmodifiable([
        _FunctionFeature(
          id: 'empty_room',
          title: '空教室查询',
          icon: Ionicons.school_outline,
          accent: Color(0xFF3768D6),
          page: BuildingPage(),
          requiresJwxtToken: true,
        ),
        _FunctionFeature(
          id: 'score',
          title: '成绩查询',
          icon: Ionicons.document_text_outline,
          accent: Color(0xFF22966C),
          page: ScorePage(),
          requiresJwxtToken: true,
        ),
        _FunctionFeature(
          id: 'exam',
          title: '考试安排',
          icon: Ionicons.ribbon_outline,
          accent: Color(0xFFE28A2E),
          page: ExamSchedulePage(),
          requiresJwxtToken: true,
        ),
        _FunctionFeature(
          id: 'commentary',
          title: '学生评教',
          icon: Ionicons.checkbox_outline,
          accent: Color(0xFFB6569C),
          page: CommentaryBatchPage(),
          requiresJwxtToken: true,
        ),
        _FunctionFeature(
          id: 'drink',
          title: '慧生活798',
          icon: Ionicons.water_outline,
          accent: Color(0xFF1D9DB7),
          page: FunctionDrinkPage(),
        ),
        _FunctionFeature(
          id: 'hot_water',
          title: '洗澡',
          icon: Ionicons.sparkles_outline,
          accent: Color(0xFF7A63D8),
          page: FunctionHotWaterPage(),
        ),
        _FunctionFeature(
          id: 'electricity',
          title: '电费充值',
          icon: Ionicons.flash_outline,
          accent: Color(0xFF819B23),
          page: ElectricityPage(),
        ),
        _FunctionFeature(
          id: 'hut_main',
          title: '智慧工大',
          icon: Ionicons.phone_portrait_outline,
          accent: Color(0xFFCC6D2C),
          page: HutMainPage(),
        ),
      ]);

  final Map<String, ValueNotifier<bool>> _loadingNotifiers =
      <String, ValueNotifier<bool>>{};
  String? _activeProtectedPageLoadId;
  String? _activePagePushId;

  ValueNotifier<bool> _loadingNotifierFor(String functionId) {
    return _loadingNotifiers.putIfAbsent(
      functionId,
      () => ValueNotifier<bool>(false),
    );
  }

  void _setLoading(String functionId, bool isLoading) {
    final notifier = _loadingNotifierFor(functionId);
    if (notifier.value == isLoading) {
      return;
    }
    notifier.value = isLoading;
  }

  Future<void> _openProtectedPage({
    required String functionId,
    required Widget page,
  }) async {
    if (_activeProtectedPageLoadId != null || _activePagePushId != null) {
      return;
    }

    _activeProtectedPageLoadId = functionId;
    _setLoading(functionId, true);
    try {
      final isReady = await (widget.renewJwxtToken ?? renewToken)(context);
      if (!isReady || !mounted) {
        return;
      }
      await _pushPage(
        functionId: functionId,
        page: page,
        fromProtectedFlow: true,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to prepare protected function page',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          message: '无法打开该功能，请稍后重试',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _activeProtectedPageLoadId = null;
      if (mounted) {
        _setLoading(functionId, false);
      }
    }
  }

  Future<void> _pushPage({
    required String functionId,
    required Widget page,
    bool fromProtectedFlow = false,
  }) async {
    if (_activePagePushId != null ||
        (!fromProtectedFlow && _activeProtectedPageLoadId != null)) {
      return;
    }

    _activePagePushId = functionId;
    try {
      final openPage =
          widget.openPage ??
          (BuildContext context, Widget page) {
            return Navigator.of(
              context,
            ).push(buildAppPageRoute(builder: (_) => page));
          };
      await openPage(context, page);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to open function page',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showAppSnackBar(
          context,
          message: '无法打开该功能，请稍后重试',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      _activePagePushId = null;
    }
  }

  Future<void> _handleFeatureTap(_FunctionFeature item) {
    if (item.requiresJwxtToken) {
      return _openProtectedPage(functionId: item.id, page: item.page);
    }
    return _pushPage(functionId: item.id, page: item.page);
  }

  @override
  void dispose() {
    for (final notifier in _loadingNotifiers.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final bool isWide = width >= 700;
                final int crossAxisCount = isWide ? 3 : 2;
                final double childAspectRatio =
                    isWide
                        ? 1.14
                        : width >= 430
                        ? 1.10
                        : 1.04;

                return GridView.builder(
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: _features.length,
                  itemBuilder: (context, index) {
                    return _buildFeatureCard(_features[index]);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(_FunctionFeature item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final useLiteCards = AppGlassPerformanceScope.isLiteOf(context);
    const foreground = Colors.white;

    return ValueListenableBuilder<bool>(
      valueListenable: _loadingNotifierFor(item.id),
      builder: (context, isLoading, _) {
        return Material(
          color: Colors.transparent,
          child: GlassPanel(
            style: GlassPanelStyle.card,
            blur: useLiteCards ? 0 : 18,
            useBackdropFilter: !useLiteCards,
            borderRadius: BorderRadius.circular(26),
            padding: const EdgeInsets.all(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                item.lightAccent.withValues(alpha: isDark ? 0.82 : 0.74),
                item.deepAccent.withValues(alpha: isDark ? 0.74 : 0.70),
              ],
            ),
            borderColor: Colors.white.withValues(alpha: isDark ? 0.12 : 0.24),
            onTap: isLoading ? null : () => _handleFeatureTap(item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  color: foreground,
                  size: 26,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.18 : 0.10,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    letterSpacing: -0.4,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.10 : 0.14,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: isDark ? 0.08 : 0.18,
                          ),
                        ),
                      ),
                      child: Text(
                        '进入',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isLoading)
                      AppLoadingIndicator(
                        size: 18,
                        color: foreground.withValues(alpha: 0.92),
                      )
                    else
                      Icon(
                        Ionicons.arrow_forward,
                        size: 18,
                        color: foreground.withValues(alpha: 0.92),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FunctionFeature {
  _FunctionFeature({
    required this.id,
    required this.title,
    required this.icon,
    required this.accent,
    required this.page,
    this.requiresJwxtToken = false,
  }) : lightAccent = _shiftAccent(accent, lightnessDelta: 0.10),
       deepAccent = _shiftAccent(accent, lightnessDelta: -0.05);

  final String id;
  final String title;
  final IconData icon;
  final Color accent;
  final Color lightAccent;
  final Color deepAccent;
  final Widget page;
  final bool requiresJwxtToken;

  static Color _shiftAccent(Color color, {required double lightnessDelta}) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
        .toColor();
  }
}
