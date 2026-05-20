import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/hutpages/hutmain_logic.dart';
import 'package:superhut/pages/hutpages/type1/type1webview.dart';
import 'package:superhut/pages/hutpages/type2/type2webview.dart';
import 'package:superhut/utils/hut_user_api.dart';

import '../../core/ui/apple_glass.dart';
import '../../core/ui/color_scheme_ext.dart';

typedef HutFunctionListLoader = Future<List> Function();

class HutMainPage extends StatefulWidget {
  const HutMainPage({
    super.key,
    this.loadFunctionList,
    this.checkLoginOnInit = true,
  });

  final HutFunctionListLoader? loadFunctionList;
  final bool checkLoginOnInit;

  @override
  State<HutMainPage> createState() => _HutMainPageState();
}

class _HutMainPageState extends State<HutMainPage> with WidgetsBindingObserver {
  static const Color _hutAccent = Color(0xFFCC6D2C);
  static const Set<String> _hiddenServiceIds = {
    '8aaa866184af29a50185527fddf70dac',
    '8aaa84f692e5ae560193f24790e76752',
  };

  final logic = Get.put(HutMainLogic());
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  late Future<List> _functionListFuture;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _functionListFuture = _loadFunctionList();
    if (widget.checkLoginOnInit) {
      logic.checkLogin();
    }
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _unfocusSearchField();
    }
  }

  Future<List> _loadFunctionList() {
    return widget.loadFunctionList?.call() ?? logic.getFunList();
  }

  void _unfocusSearchField() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppGlassPerformanceScope(
      isLite: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppGlassBackground(
          style: AppGlassBackgroundStyle.soft,
          lightBottomColor: const Color(0xFFFFF3EA),
          darkBottomColor: const Color(0xFF20150F),
          child: GestureDetector(
            onTap: _unfocusSearchField,
            child: EnhancedFutureBuilder(
              future: _functionListFuture,
              rememberFutureResult: true,
              whenDone: (data) => _buildContent(context, data),
              whenNotDone: _buildLoadingView(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Center(
          child: GlassPanel(
            style: GlassPanelStyle.hero,
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.78),
                _hutAccent.withValues(alpha: 0.10),
              ],
            ),
            borderColor: _hutAccent.withValues(alpha: 0.14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.inkDrop(color: _hutAccent, size: 42),
                const SizedBox(height: 16),
                Text(
                  '正在加载智慧工大服务',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '为你同步可用的校园服务入口',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: topInset + 12,
          left: 16,
          child: _FeatureBackButton(
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, List data) {
    final topInset = MediaQuery.paddingOf(context).top;
    final categories = _normalizeCategories(data);
    final allServices = _flattenServices(categories);
    final searchableServices =
        allServices.where((item) => item.service.serviceType != '4').toList();
    final visibleServices =
        _searchText.isEmpty
            ? allServices
            : searchableServices.where((item) {
              final keyword = _searchText.toLowerCase();
              return item.service.serviceName.toLowerCase().contains(keyword) ||
                  item.category.toLowerCase().contains(keyword);
            }).toList();

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16, topInset + 76, 16, 28),
          children: [
            _HutOverviewCard(
              accent: _hutAccent,
              serviceCount: allServices.length,
              categoryCount: categories.length,
            ),
            const SizedBox(height: 14),
            _SearchPanel(
              accent: _hutAccent,
              controller: _searchController,
              focusNode: _searchFocusNode,
              searchText: _searchText,
            ),
            const SizedBox(height: 16),
            if (_searchText.isNotEmpty)
              _buildSearchResultList(context, visibleServices)
            else if (categories.isEmpty)
              const _FeatureEmptyState(
                icon: Ionicons.apps_outline,
                accent: _hutAccent,
                title: '暂无智慧工大服务',
                subtitle: '当前账号暂未获取到可展示的服务入口，稍后再试一次。',
              )
            else
              ...categories.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _ServiceCategoryPanel(
                    accent: _accentForCategory(category.label),
                    category: category,
                    onOpenService: _openService,
                  ),
                );
              }),
          ],
        ),
        Positioned(
          top: topInset + 12,
          left: 16,
          child: _FeatureBackButton(
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        Positioned(
          top: topInset + 13,
          left: 78,
          right: 16,
          child: Text(
            '智慧工大',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultList(
    BuildContext context,
    List<_ServiceWithCategory> services,
  ) {
    if (services.isEmpty) {
      return _FeatureEmptyState(
        icon: Ionicons.search_outline,
        accent: _hutAccent,
        title: '没有找到相关服务',
        subtitle: '未找到与“$_searchText”匹配的智慧工大功能。',
      );
    }

    return _ServiceCategoryPanel(
      accent: _hutAccent,
      category: _ServiceCategory(label: '搜索结果', services: services),
      onOpenService: _openService,
    );
  }

  List<_ServiceCategory> _normalizeCategories(List data) {
    final categories = <_ServiceCategory>[];
    for (final item in data) {
      if (item is! Map) {
        continue;
      }

      final label = item['label']?.toString().trim() ?? '';
      final rawServices = item['services'];
      if (rawServices is! List) {
        continue;
      }

      final services =
          rawServices
              .whereType<FunctionItem>()
              .where(_isVisibleService)
              .toList();
      if (services.isEmpty) {
        continue;
      }

      categories.add(
        _ServiceCategory(
          label: label.isEmpty ? '全部服务' : label,
          services:
              services
                  .map(
                    (service) => _ServiceWithCategory(
                      category: label.isEmpty ? '全部服务' : label,
                      service: service,
                    ),
                  )
                  .toList(),
        ),
      );
    }
    return categories;
  }

  List<_ServiceWithCategory> _flattenServices(
    List<_ServiceCategory> categories,
  ) {
    return categories.expand((category) => category.services).toList();
  }

  bool _isVisibleService(FunctionItem service) {
    return !_hiddenServiceIds.contains(service.id);
  }

  Color _accentForCategory(String label) {
    if (label.contains('教学') || label.contains('教务')) {
      return const Color(0xFF3768D6);
    }
    if (label.contains('生活') || label.contains('校园')) {
      return const Color(0xFF2C8A7D);
    }
    if (label.contains('办公') || label.contains('服务')) {
      return const Color(0xFFB6569C);
    }
    return _hutAccent;
  }

  void _openService(FunctionItem service) {
    final servicePicUrl =
        service.servicePicUrl.isNotEmpty
            ? service.servicePicUrl
            : service.iconUrl;
    if (service.serviceType == '1') {
      Get.to(
        () => Type1Webview(
          serviceId: '',
          serviceUrl: service.serviceUrl,
          serviceName: service.serviceName,
          servicePicUrl: servicePicUrl,
        ),
      );
      return;
    }

    if (service.serviceType == '2' ||
        service.serviceType == '4' ||
        service.serviceType == '5') {
      Get.to(
        () => Type2Webview(
          serviceId: service.serviceType == '5' ? service.id : '',
          serviceUrl: service.serviceUrl,
          serviceName: service.serviceName,
          serviceType: service.serviceType,
          tokenAccept: service.tokenAccept,
          servicePicUrl: servicePicUrl,
        ),
      );
    }
  }
}

class _ServiceCategory {
  const _ServiceCategory({required this.label, required this.services});

  final String label;
  final List<_ServiceWithCategory> services;
}

class _ServiceWithCategory {
  const _ServiceWithCategory({required this.category, required this.service});

  final String category;
  final FunctionItem service;
}

class _HutOverviewCard extends StatelessWidget {
  const _HutOverviewCard({
    required this.accent,
    required this.serviceCount,
    required this.categoryCount,
  });

  final Color accent;
  final int serviceCount;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.hero,
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: colorScheme.isDarkMode ? 0.14 : 0.84),
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.10 : 0.05),
        ],
      ),
      borderColor: accent.withValues(alpha: 0.14),
      child: Row(
        children: [
          GlassIconBadge(icon: Ionicons.phone_portrait_outline, tint: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '服务总览',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  categoryCount == 0 ? '等待智慧工大返回服务目录' : '$categoryCount 个分类已整理',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(
                alpha: colorScheme.isDarkMode ? 0.20 : 0.12,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$serviceCount 个服务',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.accent,
    required this.controller,
    required this.focusNode,
    required this.searchText,
  });

  final Color accent;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String searchText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.floating,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.floatingSurfaceStrong,
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.08 : 0.04),
        ],
      ),
      borderColor: accent.withValues(alpha: 0.12),
      child: TextField(
        autofocus: false,
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          filled: false,
          hintText: '搜索智慧工大服务',
          prefixIcon: Icon(Ionicons.search_outline, color: accent),
          suffixIcon:
              searchText.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Ionicons.close_circle_outline),
                    onPressed: controller.clear,
                  )
                  : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _ServiceCategoryPanel extends StatelessWidget {
  const _ServiceCategoryPanel({
    required this.accent,
    required this.category,
    required this.onOpenService,
  });

  final Color accent;
  final _ServiceCategory category;
  final ValueChanged<FunctionItem> onOpenService;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.card,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: colorScheme.isDarkMode ? 0.12 : 0.80),
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.08 : 0.04),
        ],
      ),
      borderColor: accent.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlassIconBadge(
                icon: Ionicons.grid_outline,
                tint: accent,
                size: 38,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              _CountPill(
                label: '${category.services.length} 个',
                accent: accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...category.services.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _ServiceTile(
                accent: accent,
                service: item.service,
                categoryLabel: item.category,
                onTap: () => onOpenService(item.service),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.accent,
    required this.service,
    required this.categoryLabel,
    required this.onTap,
  });

  final Color accent;
  final FunctionItem service;
  final String categoryLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassPanel(
      style: GlassPanelStyle.list,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
      borderColor: accent.withValues(
        alpha: colorScheme.isDarkMode ? 0.14 : 0.10,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.floatingSurfaceStrong,
          accent.withValues(alpha: colorScheme.isDarkMode ? 0.08 : 0.035),
        ],
      ),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(
                alpha: colorScheme.isDarkMode ? 0.20 : 0.12,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_iconForService(service), color: accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _serviceTypeLabel(service.serviceType, categoryLabel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Ionicons.chevron_forward,
            color: colorScheme.onSurfaceVariant,
            size: 18,
          ),
        ],
      ),
    );
  }

  IconData _iconForService(FunctionItem service) {
    if (service.serviceName.contains('卡')) {
      return Ionicons.card_outline;
    }
    if (service.serviceName.contains('图书')) {
      return Ionicons.library_outline;
    }
    if (service.serviceName.contains('课') ||
        service.serviceName.contains('教务')) {
      return Ionicons.school_outline;
    }
    return Ionicons.apps_outline;
  }

  String _serviceTypeLabel(String serviceType, String categoryLabel) {
    final typeLabel = switch (serviceType) {
      '1' => '网页服务',
      '2' => '认证服务',
      '5' => '应用服务',
      _ => '校园服务',
    };
    return '$categoryLabel · $typeLabel';
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: colorScheme.isDarkMode ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FeatureEmptyState extends StatelessWidget {
  const _FeatureEmptyState({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      style: GlassPanelStyle.hero,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(
            alpha: Theme.of(context).colorScheme.isDarkMode ? 0.12 : 0.78,
          ),
          accent.withValues(
            alpha: Theme.of(context).colorScheme.isDarkMode ? 0.10 : 0.06,
          ),
        ],
      ),
      borderColor: accent.withValues(alpha: 0.14),
      child: Column(
        children: [
          GlassIconBadge(icon: icon, tint: accent, size: 54),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBackButton extends StatelessWidget {
  const _FeatureBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      style: GlassPanelStyle.floating,
      blur: 16,
      borderRadius: BorderRadius.circular(20),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(
          Ionicons.chevron_back,
          color: Theme.of(context).colorScheme.onSurface,
          size: 22,
        ),
      ),
    );
  }
}
