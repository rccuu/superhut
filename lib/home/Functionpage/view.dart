import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/Commentary/commentary_batch_page.dart';
import 'package:superhut/pages/Electricitybill/electricity_page.dart';
import 'package:superhut/pages/ExamSchedule/exam_schedule_page.dart';
import 'package:superhut/pages/drink/view/view.dart';
import 'package:superhut/pages/freeroom/building.dart';
import 'package:superhut/pages/hutpages/hutmain.dart';
import 'package:superhut/pages/water/view.dart';

import '../../core/ui/apple_glass.dart';
import '../../login/unified_login_page.dart';
import '../../pages/score/scorepage.dart';
import '../../utils/token.dart';

class FunctionPage extends StatefulWidget {
  const FunctionPage({super.key});

  @override
  State<FunctionPage> createState() => _FunctionPageState();
}

class _FunctionPageState extends State<FunctionPage> {
  final Set<String> _loadingFunctions = <String>{};

  void _setLoading(String functionId, bool isLoading) {
    setState(() {
      if (isLoading) {
        _loadingFunctions.add(functionId);
      } else {
        _loadingFunctions.remove(functionId);
      }
    });
  }

  bool _isLoading(String functionId) {
    return _loadingFunctions.contains(functionId);
  }

  Future<void> _openProtectedPage({
    required String functionId,
    required Widget page,
  }) async {
    _setLoading(functionId, true);
    try {
      final isReady = await renewToken(context);
      if (!isReady || !mounted) {
        if (mounted) {
          await Navigator.of(context).push(UnifiedLoginPage.route());
        }
        return;
      }
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => page));
    } finally {
      if (mounted) {
        _setLoading(functionId, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _FunctionFeature(
        id: 'empty_room',
        title: '空教室查询',
        icon: Ionicons.school_outline,
        accent: const Color(0xFF3768D6),
        onTap: () async {
          await _openProtectedPage(
            functionId: 'empty_room',
            page: const BuildingPage(),
          );
        },
      ),
      _FunctionFeature(
        id: 'score',
        title: '成绩查询',
        icon: Ionicons.document_text_outline,
        accent: const Color(0xFF22966C),
        onTap: () async {
          await _openProtectedPage(
            functionId: 'score',
            page: const ScorePage(),
          );
        },
      ),
      _FunctionFeature(
        id: 'exam',
        title: '考试安排',
        icon: Ionicons.ribbon_outline,
        accent: const Color(0xFFE28A2E),
        onTap: () async {
          await _openProtectedPage(
            functionId: 'exam',
            page: const ExamSchedulePage(),
          );
        },
      ),
      _FunctionFeature(
        id: 'commentary',
        title: '学生评教',
        icon: Ionicons.checkbox_outline,
        accent: const Color(0xFFB6569C),
        onTap: () async {
          await _openProtectedPage(
            functionId: 'commentary',
            page: const CommentaryBatchPage(),
          );
        },
      ),
      _FunctionFeature(
        id: 'drink',
        title: '慧生活798',
        icon: Ionicons.water_outline,
        accent: const Color(0xFF1D9DB7),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FunctionDrinkPage()),
          );
        },
      ),
      _FunctionFeature(
        id: 'hot_water',
        title: '洗澡',
        icon: Ionicons.sparkles_outline,
        accent: const Color(0xFF7A63D8),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FunctionHotWaterPage(),
            ),
          );
        },
      ),
      _FunctionFeature(
        id: 'electricity',
        title: '电费充值',
        icon: Ionicons.flash_outline,
        accent: const Color(0xFF819B23),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ElectricityPage()),
          );
        },
      ),
      _FunctionFeature(
        id: 'hut_main',
        title: '智慧工大',
        icon: Ionicons.phone_portrait_outline,
        accent: const Color(0xFFCC6D2C),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HutMainPage()),
          );
        },
      ),
    ];

    return Scaffold(
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _buildFeatureCard(items[index]);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(_FunctionFeature item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLoading = _isLoading(item.id);
    final useLiteCards =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final lightColor = _shiftAccent(item.accent, lightnessDelta: 0.10);
    final deepColor = _shiftAccent(item.accent, lightnessDelta: -0.05);
    const foreground = Colors.white;

    return RepaintBoundary(
      child: Material(
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
              lightColor.withValues(alpha: isDark ? 0.82 : 0.74),
              deepColor.withValues(alpha: isDark ? 0.74 : 0.70),
            ],
          ),
          borderColor: Colors.white.withValues(alpha: isDark ? 0.12 : 0.24),
          onTap: isLoading ? null : () => item.onTap(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.icon,
                color: foreground,
                size: 26,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child:
                        isLoading
                            ? SizedBox(
                              key: const ValueKey('loading'),
                              width: 24,
                              height: 24,
                              child: LoadingAnimationWidget.inkDrop(
                                color: foreground,
                                size: 20,
                              ),
                            )
                            : Icon(
                              key: const ValueKey('arrow'),
                              Ionicons.arrow_forward,
                              size: 18,
                              color: foreground.withValues(alpha: 0.92),
                            ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _shiftAccent(Color color, {required double lightnessDelta}) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
        .toColor();
  }
}

class _FunctionFeature {
  const _FunctionFeature({
    required this.id,
    required this.title,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color accent;
  final Future<void> Function() onTap;
}
