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

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          _showSnackBar('教务登录状态已失效，请重新登录后重试');
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
    final colorScheme = Theme.of(context).colorScheme;
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
        title: '宿舍喝水',
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
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.05,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildFeatureCard(items[index]);
          },
        ),
      ),
    );
  }

  Widget _buildFeatureCard(_FunctionFeature item) {
    final theme = Theme.of(context);
    final isLoading = _isLoading(item.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: isLoading ? null : () => item.onTap(),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: item.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: item.accent.withValues(alpha: 0.24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: item.accent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(item.icon, color: Colors.white, size: 22),
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child:
                      isLoading
                          ? SizedBox(
                            key: const ValueKey('loading'),
                            width: 24,
                            height: 24,
                            child: LoadingAnimationWidget.inkDrop(
                              color: item.accent,
                              size: 20,
                            ),
                          )
                          : Icon(
                            key: const ValueKey('arrow'),
                            Ionicons.arrow_forward,
                            size: 18,
                            color: item.accent,
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
