import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final libDirectory = Directory('lib');

  String normalizedPath(File file) => file.path.replaceAll('\\', '/');

  Iterable<File> dartFiles() {
    return libDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
  }

  Set<String> pathsContaining(
    String pattern, {
    Set<String> allowlist = const {},
  }) {
    return dartFiles()
        .where((file) => !allowlist.contains(normalizedPath(file)))
        .where((file) => file.readAsStringSync().contains(pattern))
        .map(normalizedPath)
        .toSet();
  }

  Set<String> pathsMatching(
    RegExp pattern, {
    Set<String> allowlist = const {},
  }) {
    return dartFiles()
        .where((file) => !allowlist.contains(normalizedPath(file)))
        .where((file) => pattern.hasMatch(file.readAsStringSync()))
        .map(normalizedPath)
        .toSet();
  }

  test('page layer uses the adaptive bottom sheet helper', () {
    const allowedFiles = {'lib/core/ui/app_bottom_sheet.dart'};

    expect(
      pathsContaining(
        'package:modal_bottom_sheet/modal_bottom_sheet.dart',
        allowlist: allowedFiles,
      ),
      isEmpty,
      reason: '页面层不应直接依赖第三方 Cupertino 弹层包。',
    );
    expect(
      pathsContaining('showCupertinoModalBottomSheet', allowlist: allowedFiles),
      isEmpty,
      reason: '页面层应通过 showAppAdaptiveBottomSheet 统一弹层策略。',
    );
    expect(
      pathsContaining('showModalBottomSheet', allowlist: allowedFiles),
      isEmpty,
      reason: '页面层应通过 showAppAdaptiveBottomSheet 统一 Android 弹层策略。',
    );
  });

  test('page routes are built through the shared route helper', () {
    const allowedDirectRouteFiles = {
      // 登录、认证、短信验证码等承载页保留平台默认路由，避免认证链路副作用。
      'lib/login/hut_cas_login_page.dart',
      'lib/login/unified_login_page.dart',
      'lib/pages/drink/login/command.dart',
      'lib/pages/drink/view/logic.dart',
      'lib/pages/hutpages/hut_service_auth.dart',
      'lib/pages/hutpages/hutmain_logic.dart',
      'lib/pages/water/logic.dart',
      'lib/core/ui/app_page_route.dart',
    };

    expect(
      pathsContaining(
        'PageRouteBuilder',
        allowlist: {'lib/core/ui/app_page_route.dart'},
      ),
      isEmpty,
      reason: '页面层应通过 buildAppPageRoute 统一 Android 轻量转场。',
    );
    expect(
      pathsContaining('MaterialPageRoute(', allowlist: allowedDirectRouteFiles),
      isEmpty,
      reason: '普通页面应通过 buildAppPageRoute，认证/登录承载页除外。',
    );
    expect(
      pathsMatching(
        RegExp(r'\bGet\.(to|off|offAll)\s*\('),
        allowlist: allowedDirectRouteFiles,
      ),
      isEmpty,
      reason: '普通页面不应绕过共享轻量路由，认证/登录跳转除外。',
    );
  });

  test('shared page transition avoids opacity compositing on Android', () {
    final appPageRoute =
        File('lib/core/ui/app_page_route.dart').readAsStringSync();
    final transitionMethod = RegExp(
      r'class AppLightRouteTransition extends StatelessWidget \{[\s\S]*?\n\}',
    ).firstMatch(appPageRoute)?.group(0);

    expect(transitionMethod, isNotNull);
    expect(
      transitionMethod,
      isNot(contains('FadeTransition(')),
      reason: '轻量路由转场不应再叠加整屏透明度动画。',
    );
    expect(
      transitionMethod,
      contains('SlideTransition('),
      reason: '轻量路由转场保留位移即可，避免回退到纯透明度过渡。',
    );
  });

  test(
    'drink and hot water controllers rely on reactive state without controller updates',
    () {
      final drinkLogic =
          File('lib/pages/drink/view/logic.dart').readAsStringSync();
      final hotWaterLogic =
          File('lib/pages/water/logic.dart').readAsStringSync();
      final drinkView =
          File('lib/pages/drink/view/view.dart').readAsStringSync();
      final hotWaterView = File('lib/pages/water/view.dart').readAsStringSync();

      expect(
        drinkLogic,
        isNot(contains('update();')),
        reason: '饮水控制器页面只依赖 Obx/Rx 状态，不应额外触发 GetxController.update。',
      );
      expect(
        hotWaterLogic,
        isNot(contains('update();')),
        reason: '热水控制器页面只依赖 Obx/Rx 状态，不应额外触发 GetxController.update。',
      );
      expect(drinkView, contains('Obx('));
      expect(hotWaterView, contains('Obx('));
      expect(drinkView, isNot(contains('GetBuilder')));
      expect(hotWaterView, isNot(contains('GetBuilder')));
    },
  );

  test('high-frequency animations stay behind shared wrappers', () {
    const allowedFiles = {
      'lib/core/ui/app_animated_container.dart',
      'lib/core/ui/app_animated_switcher.dart',
      'lib/core/ui/app_progress_indicator.dart',
      'lib/core/ui/app_loading_indicator.dart',
    };

    final guardedPatterns = {
      RegExp(r'\bAnimatedContainer\s*\('): 'AppAnimatedContainer',
      RegExp(r'\bAnimatedSwitcher\s*\('): 'AppAnimatedSwitcher',
      RegExp(r'\bLinearProgressIndicator\s*\('): 'AppLinearProgressIndicator',
      RegExp(r'\bCupertinoActivityIndicator\s*\('): 'AppLoadingIndicator',
    };

    for (final entry in guardedPatterns.entries) {
      expect(
        pathsMatching(entry.key, allowlist: allowedFiles),
        isEmpty,
        reason: '页面层应通过 ${entry.value} 统一减少动态/轻量策略。',
      );
    }
  });

  test('app loading indicator skips repaint boundary when static', () {
    final loadingIndicator =
        File('lib/core/ui/app_loading_indicator.dart').readAsStringSync();
    final buildMethod = RegExp(
      r'Widget build\(BuildContext context\) \{[\s\S]*?\n  \}',
    ).firstMatch(loadingIndicator)?.group(0);

    expect(buildMethod, isNotNull);
    expect(buildMethod, contains('final effectiveAnimating ='));
    expect(buildMethod, contains('animating: effectiveAnimating'));
    expect(
      buildMethod,
      contains('if (!effectiveAnimating) {\n      return indicator;\n    }'),
      reason: '共享加载控件静止时不需要 repaint 边界层，避免 lite/reduce-motion 模式下额外建层。',
    );
    expect(
      buildMethod,
      contains('return RepaintBoundary(child: indicator);'),
      reason: '只有真实旋转的加载器需要隔离 repaint。',
    );
  });

  test('app linear progress skips repaint boundary when static', () {
    final progressIndicator =
        File('lib/core/ui/app_progress_indicator.dart').readAsStringSync();
    final buildMethod = RegExp(
      r'Widget build\(BuildContext context\) \{[\s\S]*?\n  \}',
    ).firstMatch(progressIndicator)?.group(0);

    expect(buildMethod, isNotNull);
    expect(buildMethod, contains('final effectiveValue ='));
    expect(buildMethod, contains('value: effectiveValue'));
    expect(
      buildMethod,
      contains('if (effectiveValue != null) {\n      return indicator;\n    }'),
      reason: '线性进度条在 determinate/lite/reduce-motion 静态值下不需要额外 repaint 边界层。',
    );
    expect(
      buildMethod,
      contains('return RepaintBoundary('),
      reason: '只有 indeterminate 进度动画需要隔离 repaint。',
    );
  });

  test('drink full screen background does not animate gradient repaint', () {
    final drinkView = File('lib/pages/drink/view/view.dart').readAsStringSync();
    final drinkWidgets =
        File(
          'lib/pages/drink/view/widgets/drink_page_widgets.dart',
        ).readAsStringSync();
    final backgroundClass = RegExp(
      r'class DrinkBackground extends StatelessWidget[\s\S]*?\nclass DrinkLoadingState',
    ).firstMatch(drinkWidgets)?.group(0);
    final backgroundLayer = RegExp(
      r'Positioned\.fill\(\s*child: Obx\(\s*\(\) => DrinkBackground\(\s*drinkStatus: logic\.state\.drinkStatus\.value\s*\),\s*\),\s*\),',
    ).firstMatch(drinkView)?.group(0);

    expect(backgroundClass, isNotNull);
    expect(
      backgroundClass,
      contains('return DecoratedBox(decoration: decoration);'),
    );
    expect(
      backgroundClass,
      isNot(contains('AppAnimatedContainer')),
      reason: '饮水页全屏渐变背景不应参与长时长隐式动画，避免状态变化时整屏重绘。',
    );
    expect(backgroundClass, isNot(contains('Duration(milliseconds: 800)')));
    expect(backgroundLayer, isNotNull);
    expect(
      backgroundLayer,
      isNot(contains('RepaintBoundary(')),
      reason: '饮水页静态渐变背景不应额外建 repaint 边界；气泡动画由 AmbientBubbleField 自身隔离。',
    );
    expect(
      drinkView,
      contains('child: RepaintBoundary(\n              child: Obx(() {'),
      reason: '饮水页前景内容层仍应与气泡动画层隔离。',
    );
  });

  test('hot water full screen background avoids extra repaint boundary', () {
    final waterView = File('lib/pages/water/view.dart').readAsStringSync();
    final waterWidgets =
        File(
          'lib/pages/water/widgets/water_page_widgets.dart',
        ).readAsStringSync();
    final backgroundClass = RegExp(
      r'class WaterBackground extends StatelessWidget[\s\S]*?\nclass HotWaterStatusHeader',
    ).firstMatch(waterWidgets)?.group(0);
    final backgroundLayer = RegExp(
      r'Positioned\.fill\(\s*child: Obx\(\s*\(\) => WaterBackground\(\s*waterStatus: logic\.state\.waterStatus\.value\s*\),\s*\),\s*\),',
    ).firstMatch(waterView)?.group(0);

    expect(backgroundClass, isNotNull);
    expect(backgroundClass, contains('return Stack('));
    expect(
      backgroundClass,
      isNot(contains('AppAnimatedContainer')),
      reason: '热水页全屏背景应直接切换最终样式，不应通过隐式动画重绘整屏背景。',
    );
    expect(backgroundLayer, isNotNull);
    expect(
      backgroundLayer,
      isNot(contains('RepaintBoundary(')),
      reason: '热水页静态背景不应额外建 repaint 边界；气泡动画由 AmbientBubbleField 自身隔离。',
    );
    expect(
      waterView,
      contains('child: RepaintBoundary(\n              child: LayoutBuilder('),
      reason: '热水页前景内容层仍应与气泡动画层隔离。',
    );
  });

  test('drink status header avoids implicit container animation', () {
    final drinkWidgets =
        File(
          'lib/pages/drink/view/widgets/drink_page_widgets.dart',
        ).readAsStringSync();
    final statusHeaderClass = RegExp(
      r'class DrinkStatusHeader extends StatelessWidget \{[\s\S]*?\n\}\n\nclass DrinkCurrentDeviceCard',
    ).firstMatch(drinkWidgets)?.group(0);

    expect(statusHeaderClass, isNotNull);
    expect(statusHeaderClass, contains('return Container('));
    expect(
      statusHeaderClass,
      isNot(contains('AppAnimatedContainer(')),
      reason: '饮水状态卡片包含整卡渐变和阴影，状态切换应直接落到最终样式，避免隐式动画重绘整张卡片。',
    );
    expect(statusHeaderClass, isNot(contains('AnimatedContainer(')));
  });

  test('ambient bubble field avoids unused painter work while animating', () {
    final ambientBubbleField =
        File('lib/core/ui/ambient_bubble_field.dart').readAsStringSync();
    final stateClass = RegExp(
      r'class _AmbientBubbleFieldState extends State<AmbientBubbleField>[\s\S]*?\nclass AmbientBubbleSpec',
    ).firstMatch(ambientBubbleField)?.group(0);
    final painterClass = RegExp(
      r'class AmbientBubblePainter extends CustomPainter \{[\s\S]*?\n\}',
    ).firstMatch(ambientBubbleField)?.group(0);

    expect(stateClass, isNotNull);
    expect(
      stateClass,
      contains('with TickerProviderStateMixin'),
      reason:
          '气泡背景会在轻量/完整模式切换时销毁并重建 controller，不能使用只允许创建一次 ticker 的 SingleTickerProviderStateMixin。',
    );
    expect(
      stateClass,
      contains(
        'final controller = _shouldAnimate ? _effectiveController : null;',
      ),
      reason: '气泡背景 build 应只读取一次 controller，并交给 painter repaint 驱动。',
    );
    expect(stateClass, contains('animation: animation,'));
    expect(stateClass, contains('isComplex: controller != null'));
    expect(stateClass, contains('willChange: controller != null'));
    expect(
      stateClass,
      contains('painter: _buildPainter(controller)'),
      reason: '动画分支应把 controller 交给 painter，不应每帧构造新的 CustomPaint。',
    );
    expect(
      stateClass,
      contains(
        'AmbientBubblePainter _buildPainter(Animation<double>? animation)',
      ),
      reason: '静态降级分支仍应复用同一 painter 构造路径。',
    );
    expect(
      stateClass,
      isNot(contains('AnimatedBuilder(')),
      reason: '气泡背景动画帧应只触发 CustomPainter repaint，不应每帧重建 CustomPaint。',
    );
    expect(stateClass, isNot(contains('_effectiveController.value')));
    expect(stateClass, isNot(contains('final painter = AmbientBubblePainter')));
    expect(stateClass, isNot(contains('with SingleTickerProviderStateMixin')));
    expect(painterClass, isNotNull);
    expect(painterClass, contains('super(repaint: animation)'));
    expect(
      painterClass,
      contains('final effectiveProgress = animation?.value ?? progress;'),
    );
    expect(
      painterClass,
      contains('oldDelegate.animation != animation'),
      reason: '气泡 painter 应在 animation 引用切换时重建静态/动态绘制配置。',
    );
  });

  test('water bubble backgrounds use shared ambient presets', () {
    final ambientBubbleField =
        File('lib/core/ui/ambient_bubble_field.dart').readAsStringSync();
    final waterView = File('lib/pages/water/view.dart').readAsStringSync();
    final drinkView = File('lib/pages/drink/view/view.dart').readAsStringSync();
    final waterWidgets =
        File(
          'lib/pages/water/widgets/water_page_widgets.dart',
        ).readAsStringSync();
    final drinkWidgets =
        File(
          'lib/pages/drink/view/widgets/drink_page_widgets.dart',
        ).readAsStringSync();

    expect(ambientBubbleField, contains('const AmbientBubbleField.hotWater'));
    expect(ambientBubbleField, contains('const AmbientBubbleField.drink'));
    expect(
      ambientBubbleField,
      contains('abstract final class AmbientBubblePresets'),
    );
    expect(waterView, contains('AmbientBubbleField.hotWater('));
    expect(drinkView, contains('AmbientBubbleField.drink('));
    expect(waterWidgets, isNot(contains('class BubbleAnimation')));
    expect(drinkWidgets, isNot(contains('class DrinkBubbleAnimation')));
  });

  test('hot water control button avoids implicit container animation', () {
    final waterWidgets =
        File(
          'lib/pages/water/widgets/water_page_widgets.dart',
        ).readAsStringSync();
    final controlButtonClass = RegExp(
      r'class HotWaterControlButton extends StatelessWidget \{[\s\S]*?\n\}\n\nclass HotWaterActionHint',
    ).firstMatch(waterWidgets)?.group(0);

    expect(controlButtonClass, isNotNull);
    expect(controlButtonClass, contains('child: Container('));
    expect(
      controlButtonClass,
      isNot(contains('AppAnimatedContainer(')),
      reason: '热水大圆形控制按钮包含多层渐变和阴影，状态变化应直接切换最终样式，避免隐式动画触发高成本重绘。',
    );
    expect(controlButtonClass, isNot(contains('AnimatedContainer(')));
  });

  test('scanner line reuses animation reference while painting frames', () {
    final scannerLine =
        File('lib/core/ui/scanner_line.dart').readAsStringSync();
    final stateClass = RegExp(
      r'class _AppScannerLineState extends State<AppScannerLine>[\s\S]*?\nclass AppScannerLinePainter',
    ).firstMatch(scannerLine)?.group(0);

    expect(stateClass, isNotNull);
    expect(
      stateClass,
      contains('with TickerProviderStateMixin'),
      reason:
          '扫描线会在轻量/完整模式切换时销毁并重建 controller，不能使用只允许创建一次 ticker 的 SingleTickerProviderStateMixin。',
    );
    expect(
      stateClass,
      contains(
        'final animation = _shouldAnimate ? _effectiveAnimation : null;',
      ),
      reason: '扫描线 build 应只读取一次动画对象，并交给 painter repaint 驱动。',
    );
    expect(stateClass, contains('painter: AppScannerLinePainter('));
    expect(stateClass, contains('animation: animation,'));
    expect(stateClass, contains('willChange: animation != null'));
    expect(
      stateClass,
      isNot(contains('AnimatedBuilder(')),
      reason: '扫描线动画帧应只触发 CustomPainter repaint，不应每帧重建 CustomPaint。',
    );
    expect(
      stateClass,
      isNot(contains('progress: _effectiveAnimation.value')),
      reason: '扫描线 build 内不应重复读取 _effectiveAnimation。',
    );
    expect(stateClass, isNot(contains('with SingleTickerProviderStateMixin')));
  });

  test('glass custom shadow resolution avoids mapped list allocation', () {
    final appleGlass = File('lib/core/ui/apple_glass.dart').readAsStringSync();
    final shadowResolver = RegExp(
      r'List<BoxShadow> _resolveGlassBoxShadow\([\s\S]*?\nclass GlassIconBadge',
    ).firstMatch(appleGlass)?.group(0);

    expect(shadowResolver, isNotNull);
    expect(
      shadowResolver,
      contains('List<BoxShadow>.filled('),
      reason: '共享玻璃组件的自定义阴影在多个页面 build 中复用，应直接按下标写入固定长度列表。',
    );
    expect(
      shadowResolver,
      contains('for (var index = 0; index < shadows.length; index++)'),
    );
    expect(shadowResolver, contains('return resolvedShadows;'));
    expect(shadowResolver, isNot(contains('.map(')));
    expect(shadowResolver, isNot(contains('.toList(')));
  });

  test('glass panel skips redundant margin container by default', () {
    final appleGlass = File('lib/core/ui/apple_glass.dart').readAsStringSync();
    final glassPanelClass = RegExp(
      r'class GlassPanel extends StatelessWidget \{[\s\S]*?\n\}\n\nList<BoxShadow> _resolveGlassBoxShadow',
    ).firstMatch(appleGlass)?.group(0);

    expect(glassPanelClass, isNotNull);
    expect(
      glassPanelClass,
      contains('if (margin == null) {\n      return decoratedBody;\n    }'),
      reason: 'GlassPanel 大量默认调用没有 margin，应直接返回面板主体，避免共享卡片热路径多一层 Container。',
    );
    expect(glassPanelClass, contains('return Padding(padding: margin!'));
    expect(glassPanelClass, isNot(contains('Container(margin: margin')));
  });

  test('app update notes parsing avoids unnecessary string allocations', () {
    final updateService =
        File('lib/core/services/app_update_service.dart').readAsStringSync();
    final tryParseVersionMethod = RegExp(
      r'static Version\? _tryParseVersion\(String input\) \{[\s\S]*?\n  static int _versionSuffixStart',
    ).firstMatch(updateService)?.group(0);
    final versionSuffixStartMethod = RegExp(
      r'static int _versionSuffixStart\(String rawVersion\) \{[\s\S]*?\n  static String\? _normalizeVersionCore',
    ).firstMatch(updateService)?.group(0);
    final normalizeVersionCoreMethod = RegExp(
      r'static String\? _normalizeVersionCore\(String rawVersion, int end\) \{[\s\S]*?\n  static String _releaseNotesFromBody',
    ).firstMatch(updateService)?.group(0);
    final releaseNotesMethod = RegExp(
      r'static String _releaseNotesFromBody\(String body\) \{[\s\S]*?\n  static String\? _stringValue',
    ).firstMatch(updateService)?.group(0);
    final normalizeWhitespaceMethod = RegExp(
      r'static String _normalizeWhitespace\(String text\) \{[\s\S]*?\n  \}\n\}',
    ).firstMatch(updateService)?.group(0);

    expect(tryParseVersionMethod, isNotNull);
    expect(
      tryParseVersionMethod,
      contains('final suffixStart = _versionSuffixStart(rawVersion);'),
    );
    expect(
      tryParseVersionMethod,
      contains(
        'final coreVersion = _normalizeVersionCore(rawVersion, suffixStart);',
      ),
    );
    expect(
      tryParseVersionMethod,
      contains("Version.parse('\$coreVersion\$suffix')"),
    );
    expect(tryParseVersionMethod, isNot(contains('.split(')));
    expect(tryParseVersionMethod, isNot(contains('.join(')));

    expect(versionSuffixStartMethod, isNotNull);
    expect(
      versionSuffixStartMethod,
      contains('for (var index = 0; index < rawVersion.length; index++)'),
    );
    expect(versionSuffixStartMethod, contains('rawVersion.codeUnitAt(index)'));
    expect(
      versionSuffixStartMethod,
      contains('codeUnit == 0x2D || codeUnit == 0x2B'),
    );

    expect(normalizeVersionCoreMethod, isNotNull);
    expect(
      normalizeVersionCoreMethod,
      contains('final buffer = StringBuffer();'),
    );
    expect(
      normalizeVersionCoreMethod,
      contains('for (var index = 0; index <= end; index++)'),
      reason: '更新检查版本号解析应扫描核心版本段，避免 split/join 为启动检查制造临时列表。',
    );
    expect(
      normalizeVersionCoreMethod,
      contains('rawVersion.codeUnitAt(index) == 0x2E'),
    );
    expect(
      normalizeVersionCoreMethod,
      contains('buffer.write(rawVersion.substring(segmentStart, index));'),
    );
    expect(normalizeVersionCoreMethod, contains("buffer.write('.0');"));
    expect(normalizeVersionCoreMethod, isNot(contains('.split(')));
    expect(normalizeVersionCoreMethod, isNot(contains('.join(')));

    expect(releaseNotesMethod, isNotNull);
    expect(
      releaseNotesMethod,
      contains('return _normalizeWhitespace(body);'),
      reason: 'GitHub Release body 已是文本内容，应直接走单次扫描清洗。',
    );
    expect(releaseNotesMethod, isNot(contains('replaceAll')));
    expect(releaseNotesMethod, isNot(contains('.split(')));
    expect(releaseNotesMethod, isNot(contains('.map(')));
    expect(releaseNotesMethod, isNot(contains('.where(')));
    expect(releaseNotesMethod, isNot(contains('.toList(')));

    expect(normalizeWhitespaceMethod, isNotNull);
    expect(
      normalizeWhitespaceMethod,
      contains('final buffer = StringBuffer();'),
    );
    expect(normalizeWhitespaceMethod, contains('text.codeUnitAt(index)'));
    expect(normalizeWhitespaceMethod, contains('buffer.writeCharCode(0x0A)'));
    expect(normalizeWhitespaceMethod, contains('buffer.writeCharCode(0x20)'));
    expect(normalizeWhitespaceMethod, contains('buffer.write(text[index]);'));
    expect(normalizeWhitespaceMethod, contains('buffer.toString().trim();'));
    expect(
      normalizeWhitespaceMethod,
      isNot(contains('replaceAll')),
      reason: '更新说明空白清洗应单次扫描，不应重新创建正则并生成临时字符串链。',
    );
  });

  test('app update failure result uses stable message', () {
    final updateService =
        File('lib/core/services/app_update_service.dart').readAsStringSync();
    final checkForUpdateMethod = RegExp(
      r'static Future<AppUpdateCheckResult> checkForUpdate\([\s\S]*?\n  static AppUpdateInfo\? _selectNewestRelease',
    ).firstMatch(updateService)?.group(0);

    expect(
      updateService,
      contains("const String appUpdateCheckFailureMessage = '检查更新失败，请稍后重试';"),
    );
    expect(checkForUpdateMethod, isNotNull);
    expect(
      checkForUpdateMethod,
      contains('errorMessage: appUpdateCheckFailureMessage,'),
      reason: '更新检查服务的失败结果可能被多个页面复用，应在服务边界返回稳定文案。',
    );
    expect(
      checkForUpdateMethod,
      isNot(contains('errorMessage: message')),
      reason: '失败结果不应对外承载 DioException.message 或底层异常字符串。',
    );
    expect(
      checkForUpdateMethod,
      isNot(contains('errorMessage: diagnosticMessage')),
    );
    expect(
      checkForUpdateMethod,
      isNot(contains('final message = error.toString();')),
    );
  });

  test('page feedback uses the shared snackbar helper', () {
    const allowedFiles = {'lib/core/ui/app_snack_bar.dart'};
    final snackBarHelper =
        File('lib/core/ui/app_snack_bar.dart').readAsStringSync();
    final showSnackBarMethod = RegExp(
      r'ScaffoldFeatureController<SnackBar, SnackBarClosedReason>\? showAppSnackBar\([\s\S]*?\n\}\n\nFuture<void> _clearSnackBarRecordWhenClosed',
    ).firstMatch(snackBarHelper)?.group(0);
    final clearSnackBarRecordMethod = RegExp(
      r'Future<void> _clearSnackBarRecordWhenClosed\([\s\S]*?\n\}\n\nclass _AppSnackBarRecord',
    ).firstMatch(snackBarHelper)?.group(0);

    expect(
      pathsMatching(RegExp(r'\bSnackBar\s*\('), allowlist: allowedFiles),
      isEmpty,
      reason: '页面层应通过 showAppSnackBar 统一提示样式、去重和动画策略。',
    );
    expect(
      pathsMatching(
        RegExp(r'\bScaffoldMessenger\.(of|maybeOf)\s*\('),
        allowlist: allowedFiles,
      ),
      isEmpty,
      reason: '页面层不应直接操作 ScaffoldMessenger 提示队列。',
    );
    expect(
      pathsMatching(RegExp(r'\.showSnackBar\s*\('), allowlist: allowedFiles),
      isEmpty,
      reason: '页面层不应绕过 showAppSnackBar 直接排队 SnackBar。',
    );
    expect(
      pathsMatching(RegExp(r'\bGet\.snackbar\s*\('), allowlist: allowedFiles),
      isEmpty,
      reason: '页面层应避免引入第二套提示通道。',
    );

    expect(showSnackBarMethod, isNotNull);
    expect(
      showSnackBarMethod,
      contains('unawaited(_clearSnackBarRecordWhenClosed(messenger, record));'),
      reason: '共享提示去重记录清理应集中到 async helper。',
    );
    expect(
      showSnackBarMethod,
      isNot(contains('controller.closed.whenComplete')),
      reason: '共享提示去重记录不应通过 whenComplete 回调链清理。',
    );

    expect(clearSnackBarRecordMethod, isNotNull);
    expect(clearSnackBarRecordMethod, contains('try {'));
    expect(
      clearSnackBarRecordMethod,
      contains('await record.controller.closed;'),
    );
    expect(clearSnackBarRecordMethod, contains('} finally {'));
    expect(
      clearSnackBarRecordMethod,
      contains('_appSnackBarRecords[messenger] = null;'),
      reason: 'Snackbar 正常关闭或异常完成时都必须释放去重记录。',
    );
    expect(clearSnackBarRecordMethod, isNot(contains('.whenComplete(')));
  });

  test('expensive page futures are cached outside build methods', () {
    final guardedPatterns = {
      RegExp(r'future:\s*getHisRoomInfo\s*\('): '电费页首屏房间信息',
      RegExp(r'future:\s*getTimeList\s*\('): '成绩页首屏成绩信息',
      RegExp(r'future:\s*_getBatches\s*\('): '评教批次列表',
      RegExp(r'future:\s*_getCommentaryItems\s*\('): '评教课程列表',
      RegExp(r'future:\s*_getOptionList\s*\('): '评教题目列表',
      RegExp(r'future:\s*_command\.getImageCaptcha\s*\('): '饮水登录图形验证码',
      RegExp(r'future:\s*getSchedule\s*\('): '考试安排首屏信息',
    };

    for (final entry in guardedPatterns.entries) {
      expect(
        pathsMatching(entry.key),
        isEmpty,
        reason: '${entry.value}不应在 build 中直接创建 Future，避免父级 rebuild 触发重复请求。',
      );
    }
  });

  test('commentary question page caches question options once', () {
    final commentaryApi =
        File('lib/pages/Commentary/commentary_api.dart').readAsStringSync();
    final questionPage =
        File(
          'lib/pages/Commentary/commentary_question_page.dart',
        ).readAsStringSync();
    final getQuestionsMethod = RegExp(
      r'Future<List<CommentaryPayload>> getCommentaryQuestions\([\s\S]*?\nFuture<String> submitCommentary',
    ).firstMatch(commentaryApi)?.group(0);
    final payloadListMethod = RegExp(
      r'List<CommentaryPayload> _toPayloadList\(Object\? rawList\) \{[\s\S]*?\nString _stringValue',
    ).firstMatch(commentaryApi)?.group(0);
    final loadMethod = RegExp(
      r'Future<List<CommentaryPayload>> _getOptionList\(\) async \{[\s\S]*?\n  List<QuestionOption> _extractQuestionOptions',
    ).firstMatch(questionPage)?.group(0);
    final extractMethod = RegExp(
      r'List<QuestionOption> _extractQuestionOptions\(CommentaryPayload question\) \{[\s\S]*?\n  void _selectOption',
    ).firstMatch(questionPage)?.group(0);
    final selectMethod = RegExp(
      r'void _selectOption\([\s\S]*?\n  List<CommentarySubmissionItem> _getUserSelections',
    ).firstMatch(questionPage)?.group(0);
    final userSelectionMethod = RegExp(
      r'List<CommentarySubmissionItem> _getUserSelections\(\) \{[\s\S]*?\n  List<CommentarySubmissionItem> _buildAutoSelections',
    ).firstMatch(questionPage)?.group(0);
    final autoSelectionMethod = RegExp(
      r'List<CommentarySubmissionItem> _buildAutoSelections\(\) \{[\s\S]*?\n  Future<void> _submitSelections',
    ).firstMatch(questionPage)?.group(0);
    final submitMethod = RegExp(
      r'Future<void> _submitSelections\([\s\S]*?\n  Future<void> _handleAutoSubmit',
    ).firstMatch(questionPage)?.group(0);
    final submitSetterMethod = RegExp(
      r'void _setSubmitting\(bool isSubmitting\) \{[\s\S]*?\n  Future<void> _submitSelections',
    ).firstMatch(questionPage)?.group(0);
    final buildMethod = RegExp(
      r'Widget build\(BuildContext context\) \{[\s\S]*?\n\}',
    ).firstMatch(questionPage)?.group(0);

    expect(
      questionPage,
      contains('List<List<QuestionOption>> _questionOptions'),
      reason: '评教题目页应缓存每题选项，避免渲染和提交时重复过滤原始 optionList。',
    );
    expect(
      questionPage,
      contains('List<ValueNotifier<int>>? _questionSelectionNotifiers'),
      reason: '评教题目页每题选择态应局部通知，避免选项切换触发整页重建。',
    );
    expect(
      questionPage,
      contains('final ValueNotifier<bool> _isSubmitting'),
      reason: '评教提交态只影响顶部和底部按钮，不应 setState 重建整页题目列表。',
    );
    expect(questionPage, contains('_isSubmitting.dispose();'));

    expect(loadMethod, isNotNull);
    expect(
      loadMethod,
      contains('for (final question in allOptionList)'),
      reason: '评教题目加载完成时应单次扫描题目并建立选择态和选项缓存。',
    );
    expect(loadMethod, contains('_extractQuestionOptions(question)'));
    expect(
      loadMethod,
      contains('questionSelectionNotifiers.add(ValueNotifier<int>(-1))'),
    );
    expect(loadMethod, contains('_questionOptions ='));
    expect(loadMethod, isNot(contains('allOptionList.map')));

    expect(extractMethod, isNotNull);
    expect(extractMethod, contains('for (final option in optionList)'));
    expect(extractMethod, isNot(contains('whereType<QuestionOption>')));

    expect(selectMethod, isNotNull);
    expect(
      selectMethod,
      contains('if (selectionNotifier.value == optionIndex)'),
      reason: '重复选择已选评教选项时应在通知前短路。',
    );
    expect(
      selectMethod,
      contains(
        'final selectionNotifier = questionSelectionNotifiers[questionIndex];',
      ),
    );
    expect(selectMethod, contains('selectionNotifier.value = optionIndex;'));
    expect(
      selectMethod,
      isNot(contains('setState(()')),
      reason: '评教单选切换应只通知当前题目选项区域，不应触发整页重建。',
    );
    expect(
      selectMethod,
      isNot(contains('optionCount')),
      reason: '评教单选切换不应依赖外部 optionCount 全量清空选项。',
    );
    expect(
      selectMethod,
      isNot(contains('for (var i = 0; i <')),
      reason: '评教单选切换只需更新旧选项和新选项，避免每次全量写入整组选项。',
    );

    expect(userSelectionMethod, isNotNull);
    expect(
      userSelectionMethod,
      contains('final options = _questionOptions[i];'),
    );
    expect(userSelectionMethod, isNot(contains('_extractQuestionOptions')));

    expect(autoSelectionMethod, isNotNull);
    expect(
      autoSelectionMethod,
      contains('final options = _questionOptions[i];'),
    );
    expect(autoSelectionMethod, isNot(contains('_extractQuestionOptions')));

    expect(submitMethod, isNotNull);
    expect(
      questionPage,
      contains("const commentarySubmitFailureMessage = '提交失败';"),
      reason: '评教提交失败应使用稳定文案，避免展示后端 errorMessage、URL 或 token。',
    );
    expect(submitSetterMethod, isNotNull);
    expect(
      submitSetterMethod,
      contains('!mounted || _isSubmitting.value == isSubmitting'),
      reason: '提交态不变或页面已卸载时不应通知按钮重建。',
    );
    expect(submitSetterMethod, contains('_isSubmitting.value = isSubmitting;'));
    expect(submitSetterMethod, isNot(contains('setState(')));

    expect(submitMethod, contains('if (_isSubmitting.value)'));
    expect(submitMethod, contains('_setSubmitting(true);'));
    expect(submitMethod, contains('_setSubmitting(false);'));
    expect(submitMethod, contains('commentarySubmitFailureMessage'));
    expect(submitMethod, isNot(contains('_showSnackBar(result')));
    expect(
      submitMethod,
      isNot(contains('setState(')),
      reason: '提交 loading 切换应只重建按钮区域，不应整页 setState。',
    );

    expect(buildMethod, isNotNull);
    expect(buildMethod, contains('final questionOptions = _questionOptions;'));
    expect(buildMethod, contains('final options = questionOptions[index];'));
    expect(questionPage, contains('ValueListenableBuilder<int>'));
    expect(questionPage, contains('valueListenable: selectionNotifier'));
    expect(questionPage, contains('ValueListenableBuilder<bool>'));
    expect(questionPage, contains('valueListenable: _isSubmitting'));
    expect(
      buildMethod,
      isNot(contains('List<CommentaryPayload>.from')),
      reason: '评教题目完成态 build 不应复制题目列表。',
    );
    expect(buildMethod, isNot(contains('_extractQuestionOptions')));

    expect(getQuestionsMethod, isNotNull);
    expect(
      getQuestionsMethod,
      contains('final questionList = <QuestionOption>[];'),
      reason: '评教接口解析题目选项应一次构造结果列表，避免 map/toList 链式临时对象。',
    );
    expect(
      getQuestionsMethod,
      contains('for (final commentaryQuestion in commentaryQuestions)'),
    );
    expect(getQuestionsMethod, contains('questionList.add('));
    expect(getQuestionsMethod, isNot(contains('commentaryQuestions.map')));
    expect(getQuestionsMethod, isNot(contains('.toList()')));

    expect(payloadListMethod, isNotNull);
    expect(
      payloadListMethod,
      contains('final payloads = <CommentaryPayload>[];'),
      reason: '评教 payload 解析应一次构造结果列表，避免 whereType/map/toList 链式临时对象。',
    );
    expect(payloadListMethod, contains('for (final item in rawList)'));
    expect(payloadListMethod, contains('if (item is Map)'));
    expect(
      payloadListMethod,
      contains('payloads.add(Map<String, dynamic>.from(item));'),
    );
    expect(payloadListMethod, contains('return payloads;'));
    expect(payloadListMethod, isNot(contains('whereType')));
    expect(payloadListMethod, isNot(contains('.map(')));
    expect(payloadListMethod, isNot(contains('.toList()')));
  });

  test('commentary list pages avoid copying completed payload lists', () {
    final batchPage =
        File(
          'lib/pages/Commentary/commentary_batch_page.dart',
        ).readAsStringSync();
    final courseListPage =
        File(
          'lib/pages/Commentary/commentary_course_list_page.dart',
        ).readAsStringSync();
    final batchBuildMethod = RegExp(
      r'Widget build\(BuildContext context\) \{[\s\S]*?\n\}',
    ).firstMatch(batchPage)?.group(0);
    final courseListBuildMethod = RegExp(
      r'Widget build\(BuildContext context\) \{[\s\S]*?\n\}',
    ).firstMatch(courseListPage)?.group(0);
    final courseListReloadMethod = RegExp(
      r'void _reloadCommentaryItems\(\) \{[\s\S]*?\n  Widget _buildQuestionPage',
    ).firstMatch(courseListPage)?.group(0);

    expect(batchBuildMethod, isNotNull);
    expect(
      batchBuildMethod,
      contains('whenDone: (List<CommentaryPayload> batchesList)'),
      reason: '评教批次页 Future 已声明 payload 类型，完成态 build 不应再复制转换列表。',
    );
    expect(batchBuildMethod, contains('itemCount: batchesList.length'));
    expect(batchBuildMethod, contains('final batch = batchesList[index];'));
    expect(
      batchBuildMethod,
      contains('addRepaintBoundaries: false'),
      reason: '评教批次通常是短静态列表，不应为每个批次卡片额外创建 repaint boundary。',
    );
    expect(batchBuildMethod, isNot(contains('List<CommentaryPayload>.from')));
    expect(batchBuildMethod, isNot(contains('typedBatchesList')));

    expect(courseListBuildMethod, isNotNull);
    expect(
      courseListPage,
      contains('_commentaryItemsFutureNotifier ='),
      reason: '评教课程列表 Future 应由局部 notifier 持有，提交刷新时只重建列表 body。',
    );
    expect(
      courseListPage,
      contains('ValueNotifier<Future<List<CommentaryPayload>>>'),
    );
    expect(
      courseListPage,
      contains('_commentaryItemsFutureNotifier.dispose();'),
    );
    expect(courseListReloadMethod, isNotNull);
    expect(
      courseListReloadMethod,
      contains('_commentaryItemsFutureNotifier.value = _getCommentaryItems();'),
      reason: '评教提交返回后只应刷新课程列表 Future，不应重建整页 Scaffold/AppBar。',
    );
    expect(
      courseListReloadMethod,
      isNot(contains('setState(')),
      reason: '评教课程列表刷新 Future 不应整页 setState。',
    );
    expect(
      courseListBuildMethod,
      contains('valueListenable: _commentaryItemsFutureNotifier'),
      reason: '评教课程列表 body 应通过 ValueListenableBuilder 局部响应 Future 替换。',
    );
    expect(courseListBuildMethod, contains('future: commentaryItemsFuture'));
    expect(
      courseListBuildMethod,
      contains('whenDone: (List<CommentaryPayload> commentaryList)'),
      reason: '评教课程页 Future 已声明 payload 类型，完成态 build 不应再复制转换列表。',
    );
    expect(courseListBuildMethod, contains('itemCount: commentaryList.length'));
    expect(
      courseListBuildMethod,
      contains('final commentary = commentaryList[index];'),
    );
    expect(
      courseListBuildMethod,
      contains('addRepaintBoundaries: false'),
      reason: '评教课程列表是评教流程内的静态卡片列表，不应为每个课程卡片额外创建 repaint boundary。',
    );
    expect(
      courseListBuildMethod,
      isNot(contains('List<CommentaryPayload>.from')),
    );
    expect(courseListBuildMethod, isNot(contains('typedCommentaryList')));
  });

  test('electricity room picker reuses normalized room items', () {
    final electricityPage =
        File(
          'lib/pages/Electricitybill/electricity_page.dart',
        ).readAsStringSync();
    final roomPickerMethod = RegExp(
      r'Future<void> _showAllRoomBottomSheet\(List<dynamic> roomList\) async \{[\s\S]*?\n  //显示预警设置',
    ).firstMatch(electricityPage)?.group(0);
    final handleRoomPickerMethod = RegExp(
      r'Future<void> _handleRoomPickerPressed\(\) async \{[\s\S]*?\n  Future<void> _saveAlertSettings',
    ).firstMatch(electricityPage)?.group(0);
    final itemCacheMethod = RegExp(
      r'List<_RoomPickerItem> _roomPickerItemsFor\(List<dynamic> roomList\) \{[\s\S]*?\n  List<_RoomPickerItem> _buildRoomPickerItems',
    ).firstMatch(electricityPage)?.group(0);
    final buildItemsMethod = RegExp(
      r'List<_RoomPickerItem> _buildRoomPickerItems\(List<dynamic> roomList\) \{[\s\S]*?\n  List<_RoomPickerItem> _filterRoomPickerItems',
    ).firstMatch(electricityPage)?.group(0);
    final filterItemsMethod = RegExp(
      r'List<_RoomPickerItem> _filterRoomPickerItems\([\s\S]*?\n  AppSnackBarType _resolveSnackBarType',
    ).firstMatch(electricityPage)?.group(0);

    expect(electricityPage, contains('class _RoomPickerItem'));
    expect(
      electricityPage,
      contains('List<_RoomPickerItem>? _cachedRoomPickerItems;'),
    );

    expect(handleRoomPickerMethod, isNotNull);
    expect(
      handleRoomPickerMethod,
      contains('final cachedRoomList = _roomListCache;'),
      reason: '房间列表缓存命中时应直接打开弹层，避免入口按钮重复切 loading。',
    );
    expect(
      handleRoomPickerMethod,
      contains('unawaited(_showAllRoomBottomSheet(cachedRoomList));'),
    );
    expect(handleRoomPickerMethod, contains('_setRoomLoading(true);'));
    expect(
      handleRoomPickerMethod!.indexOf('final cachedRoomList = _roomListCache;'),
      lessThan(handleRoomPickerMethod.indexOf('_setRoomLoading(true);')),
      reason: '缓存判断应早于 loading notifier，避免已缓存时仍切换入口按钮状态。',
    );
    expect(
      handleRoomPickerMethod,
      isNot(contains('setState(')),
      reason: '房间选择入口 loading 应走局部 notifier，不应触发整页重建。',
    );

    expect(roomPickerMethod, isNotNull);
    expect(
      roomPickerMethod,
      contains('final roomItems = _roomPickerItemsFor(roomList);'),
      reason: '电费房间选择弹层应复用预处理后的房间项。',
    );
    expect(
      roomPickerMethod,
      contains(
        'final filteredRoomItemsNotifier = ValueNotifier<List<_RoomPickerItem>>',
      ),
      reason: '电费房间搜索结果应局部通知列表，避免每次输入重建整个底部弹层。',
    );
    expect(
      roomPickerMethod,
      contains('valueListenable: filteredRoomItemsNotifier'),
    );
    expect(
      roomPickerMethod,
      contains('if (nextSearchQuery == normalizedSearchQuery)'),
      reason: '搜索词归一化后未变化时不应触发弹层 rebuild。',
    );
    expect(
      roomPickerMethod,
      contains('filteredRoomItemsNotifier.value ='),
      reason: '搜索词变化时只更新房间列表 notifier。',
    );
    expect(
      roomPickerMethod,
      contains('filteredRoomItemsNotifier.dispose();'),
      reason: '局部 notifier 应在弹层关闭后释放。',
    );
    expect(
      roomPickerMethod,
      isNot(contains('StatefulBuilder')),
      reason: '房间搜索不应通过 StatefulBuilder.setState 重建整个底部弹层。',
    );
    expect(roomPickerMethod, isNot(contains('setState(')));
    expect(
      roomPickerMethod,
      isNot(contains('whereType')),
      reason: '电费房间选择弹层 builder 不应每次 rebuild 重新筛选原始 Map。',
    );
    expect(roomPickerMethod, isNot(contains('.where(')));
    expect(roomPickerMethod, isNot(contains('.toList()')));

    expect(itemCacheMethod, isNotNull);
    expect(
      itemCacheMethod,
      contains('identical(_roomPickerItemsSource, roomList)'),
      reason: '同一房间列表的搜索字段预处理结果应复用。',
    );

    expect(buildItemsMethod, isNotNull);
    expect(
      buildItemsMethod,
      contains('for (final rawRoom in roomList)'),
      reason: '房间列表预处理应单次扫描并缓存显示字段和小写搜索字段。',
    );
    expect(buildItemsMethod, contains('normalizedName: name.toLowerCase()'));
    expect(buildItemsMethod, contains('normalizedId: id.toLowerCase()'));

    expect(filterItemsMethod, isNotNull);
    expect(
      filterItemsMethod,
      contains('for (final room in roomItems)'),
      reason: '搜索过滤应扫描轻量 item，不应反复读取原始 Map 字段。',
    );
    expect(filterItemsMethod, isNot(contains('rawRoom')));
  });

  test('electricity amount input reuses formatter and scans text', () {
    final electricityPage =
        File(
          'lib/pages/Electricitybill/electricity_page.dart',
        ).readAsStringSync();
    final stateClass = RegExp(
      r'class _ElectricityPageState extends State<ElectricityPage> \{[\s\S]*?\n  String setRoomName',
    ).firstMatch(electricityPage)?.group(0);
    final paymentInputSection = RegExp(
      r'TextField\([\s\S]*?inputFormatters: _amountInputFormatters,[\s\S]*?decoration: InputDecoration',
    ).firstMatch(electricityPage)?.group(0);
    final precisionMethod = RegExp(
      r'bool _hasValidAmountPrecision\(String value\) \{[\s\S]*?\n\}',
    ).firstMatch(electricityPage)?.group(0);
    final editablePrefixMethod = RegExp(
      r'bool _isEditableAmountPrefix\(String value\) \{[\s\S]*?\n\}',
    ).firstMatch(electricityPage)?.group(0);
    final formatterClass = RegExp(
      r'class DecimalTextInputFormatter extends TextInputFormatter \{[\s\S]*?\n\}',
    ).firstMatch(electricityPage)?.group(0);

    expect(stateClass, isNotNull);
    expect(
      stateClass,
      contains('static const List<TextInputFormatter> _amountInputFormatters'),
      reason: '电费充值输入 formatter 应静态复用，避免每次弹层 build 创建对象。',
    );
    expect(
      stateClass,
      contains('<TextInputFormatter>[DecimalTextInputFormatter()]'),
    );

    expect(paymentInputSection, isNotNull);
    expect(paymentInputSection, isNot(contains('FilteringTextInputFormatter')));
    expect(paymentInputSection, isNot(contains('RegExp')));

    expect(precisionMethod, isNotNull);
    expect(precisionMethod, contains('value.codeUnitAt(index)'));
    expect(precisionMethod, contains('decimalDigits > 2'));
    expect(precisionMethod, contains('integerDigits > 0'));
    expect(precisionMethod, isNot(contains('RegExp')));

    expect(editablePrefixMethod, isNotNull);
    expect(editablePrefixMethod, contains('value.codeUnitAt(index)'));
    expect(editablePrefixMethod, contains('decimalDigits > 2'));
    expect(editablePrefixMethod, isNot(contains('RegExp')));

    expect(formatterClass, isNotNull);
    expect(formatterClass, contains('const DecimalTextInputFormatter();'));
    expect(formatterClass, contains('_isEditableAmountPrefix(newValue.text)'));
    expect(formatterClass, isNot(contains('stringMatch')));
    expect(formatterClass, isNot(contains('RegExp')));
  });

  test('electricity data refresh skips unchanged rebuilds', () {
    final electricityPage =
        File(
          'lib/pages/Electricitybill/electricity_page.dart',
        ).readAsStringSync();
    final applyBalanceMethod = RegExp(
      r'bool _applyBalance\(String cardBalance\) \{[\s\S]*?\n  bool _hasSameRoomInfo',
    ).firstMatch(electricityPage)?.group(0);
    final sameRoomInfoMethod = RegExp(
      r'bool _hasSameRoomInfo\(String roomId, Map<String, dynamic> roomInfo\) \{[\s\S]*?\n  bool _applyRoomInfo',
    ).firstMatch(electricityPage)?.group(0);
    final applyRoomInfoMethod = RegExp(
      r'bool _applyRoomInfo\(String roomId, Map<String, dynamic> roomInfo\) \{[\s\S]*?\n  bool _applyRoomLoadError',
    ).firstMatch(electricityPage)?.group(0);
    final applyRoomLoadErrorMethod = RegExp(
      r'bool _applyRoomLoadError\(String message\) \{[\s\S]*?\n  int _nextRoomInfoGeneration',
    ).firstMatch(electricityPage)?.group(0);
    final getBalanceMethod = RegExp(
      r'Future<void> getBalance\(\) async \{[\s\S]*?\n  Future<void> _refreshRoomAndBalance',
    ).firstMatch(electricityPage)?.group(0);
    final refreshRoomAndBalanceMethod = RegExp(
      r'Future<void> _refreshRoomAndBalance\(String roomId\) async \{[\s\S]*?\n  Future<bool> getHisRoomInfo',
    ).firstMatch(electricityPage)?.group(0);
    final getHisRoomInfoMethod = RegExp(
      r'Future<bool> getHisRoomInfo\(\) async \{[\s\S]*?\n  Future<bool> getNewRoomInfo',
    ).firstMatch(electricityPage)?.group(0);
    final getNewRoomInfoMethod = RegExp(
      r'Future<bool> getNewRoomInfo\(String roomId\) async \{[\s\S]*?\n  Future<List<dynamic>> getRoomList',
    ).firstMatch(electricityPage)?.group(0);
    final chargePressedMethod = RegExp(
      r'Future<void> _handleChargePressed\(\) async \{[\s\S]*?\n  Future<void> _handleRoomPickerPressed',
    ).firstMatch(electricityPage)?.group(0);
    final roomPickerPressedMethod = RegExp(
      r'Future<void> _handleRoomPickerPressed\(\) async \{[\s\S]*?\n  void _setRoomLoading',
    ).firstMatch(electricityPage)?.group(0);
    final roomLoadingSetterMethod = RegExp(
      r'void _setRoomLoading\(bool value\) \{[\s\S]*?\n  void _setChargeLoading',
    ).firstMatch(electricityPage)?.group(0);
    final chargeLoadingSetterMethod = RegExp(
      r'void _setChargeLoading\(bool value\) \{[\s\S]*?\n  Future<void> _saveAlertSettings',
    ).firstMatch(electricityPage)?.group(0);

    expect(applyBalanceMethod, isNotNull);
    expect(
      applyBalanceMethod,
      contains('if (_balanceNotifier.value == cardBalance)'),
      reason: '校园卡余额相同时应跳过状态写入。',
    );
    expect(applyBalanceMethod, contains('return false;'));
    expect(
      applyBalanceMethod,
      contains('_balanceNotifier.value = cardBalance;'),
    );
    expect(applyBalanceMethod, contains('return true;'));

    expect(
      electricityPage,
      contains(
        'late final ValueNotifier<_ElectricityRoomInfoViewState> _roomInfoNotifier',
      ),
      reason: '当前房间卡片应由局部 notifier 刷新，不应通过整页 setState 更新。',
    );
    expect(electricityPage, contains('_roomInfoNotifier.dispose();'));
    expect(
      electricityPage,
      contains('ValueListenableBuilder<_ElectricityRoomInfoViewState>'),
    );
    expect(electricityPage, contains('class _ElectricityRoomInfoViewState'));

    expect(sameRoomInfoMethod, isNotNull);
    expect(sameRoomInfoMethod, contains('nowRoomId == roomId'));
    expect(
      sameRoomInfoMethod,
      contains("setRoomName == roomInfo['roomName'].toString()"),
    );
    expect(
      sameRoomInfoMethod,
      contains("roomCount == roomInfo['eleTail'].toString()"),
    );
    expect(sameRoomInfoMethod, contains('roomLoadErrorMessage == null'));

    expect(applyRoomInfoMethod, isNotNull);
    expect(
      applyRoomInfoMethod,
      contains('if (_hasSameRoomInfo(roomId, roomInfo))'),
      reason: '房间号、房名、电量和错误态都未变化时不应写状态。',
    );
    expect(applyRoomInfoMethod, contains('return false;'));
    expect(applyRoomInfoMethod, contains('return true;'));
    expect(
      applyRoomInfoMethod,
      contains('_roomInfoNotifier.value = _ElectricityRoomInfoViewState('),
      reason: '房间信息变化应只通知当前房间卡片。',
    );
    expect(applyRoomInfoMethod, contains('roomName: setRoomName,'));
    expect(applyRoomInfoMethod, contains('roomCount: roomCount,'));
    expect(applyRoomInfoMethod, isNot(contains('setState(')));

    expect(applyRoomLoadErrorMethod, isNotNull);
    expect(
      applyRoomLoadErrorMethod,
      contains('if (roomLoadErrorMessage == message)'),
      reason: '重复房间加载错误不应再次通知当前房间卡片。',
    );
    expect(
      applyRoomLoadErrorMethod,
      contains('roomLoadErrorMessage = message;'),
    );
    expect(
      applyRoomLoadErrorMethod,
      contains('_roomInfoNotifier.value = _ElectricityRoomInfoViewState('),
    );
    expect(applyRoomLoadErrorMethod, contains('errorMessage: message,'));
    expect(applyRoomLoadErrorMethod, isNot(contains('setState(')));

    expect(getBalanceMethod, isNotNull);
    final getBalanceText = getBalanceMethod!;
    expect(
      getBalanceText,
      contains('_applyBalance(cardBalance);'),
      reason: '余额刷新应直接走局部 notifier，不应再包一层整页 setState。',
    );
    expect(
      getBalanceText,
      isNot(contains('setState(() {')),
      reason: '余额刷新应直接走局部 notifier，不应重建整页。',
    );

    expect(refreshRoomAndBalanceMethod, isNotNull);
    final refreshRoomAndBalanceText = refreshRoomAndBalanceMethod!;
    expect(
      refreshRoomAndBalanceText,
      contains('final hasRoomChange ='),
      reason: '充值后合并刷新应先判断房间信息是否真实变化。',
    );
    expect(refreshRoomAndBalanceText, contains('final hasBalanceChange ='));
    expect(
      refreshRoomAndBalanceText,
      contains('if (!hasRoomChange && !hasBalanceChange)'),
      reason: '房间和余额都未变化时不应重建电费页。',
    );
    expect(
      refreshRoomAndBalanceText,
      contains(
        'shouldApplyRoom ? Map<String, dynamic>.from(results[0] as Map) : null',
      ),
      reason: '旧房间刷新结果已经失效时不应再复制旧 Map，只保留仍有效的余额刷新。',
    );
    expect(
      refreshRoomAndBalanceText.indexOf(
        'final shouldApplyRoom = _isLatestRoomInfoGeneration(roomGeneration);',
      ),
      lessThan(
        refreshRoomAndBalanceText.indexOf(
          'Map<String, dynamic>.from(results[0] as Map)',
        ),
      ),
      reason: '房间刷新 generation 检查应早于房间结果 Map 复制。',
    );
    expect(
      refreshRoomAndBalanceText,
      contains('roomInfo != null && !_hasSameRoomInfo(roomId, roomInfo)'),
    );
    expect(refreshRoomAndBalanceText, contains('if (hasRoomChange)'));
    expect(refreshRoomAndBalanceText, contains('if (hasBalanceChange)'));
    expect(
      refreshRoomAndBalanceText,
      isNot(contains('setState(')),
      reason: '充值后房间信息刷新应走局部房间卡片 notifier。',
    );

    expect(getHisRoomInfoMethod, isNotNull);
    expect(
      electricityPage,
      contains("const electricityRoomLoadFailureMessage = '房间信息加载失败，请稍后重试';"),
      reason: '电费首屏房间加载失败应使用稳定文案，避免展示底层异常、URL 或 token。',
    );
    expect(
      getHisRoomInfoMethod,
      contains('_applyRoomLoadError(electricityRoomLoadFailureMessage);'),
    );
    expect(
      getHisRoomInfoMethod,
      isNot(contains('roomLoadErrorMessage = error.toString()')),
      reason: '首屏房间加载失败不应把底层异常直接展示到页面。',
    );
    expect(
      getHisRoomInfoMethod,
      isNot(contains("replaceFirst('Bad state: '")),
      reason: '裁剪异常前缀仍是在展示底层错误，应改为受控文案。',
    );
    expect(
      getHisRoomInfoMethod,
      isNot(contains('setState(')),
      reason: '首屏房间信息落地应走局部房间卡片 notifier。',
    );

    expect(getNewRoomInfoMethod, isNotNull);
    final getNewRoomInfoText = getNewRoomInfoMethod!;
    expect(
      getNewRoomInfoText.indexOf('if (_hasSameRoomInfo(roomId, roomInfo))'),
      lessThan(getNewRoomInfoText.indexOf('_applyRoomInfo(roomId, roomInfo);')),
      reason: '重新选择同一房间且数据未变化时应在通知房间卡片前短路。',
    );
    expect(getNewRoomInfoText, isNot(contains('setState(')));

    expect(chargePressedMethod, isNotNull);
    expect(
      chargePressedMethod,
      contains('_isChargeLoadingNotifier.value'),
      reason: '充值 pending 态应由局部 notifier 管理，不应依赖整页状态字段。',
    );
    expect(chargePressedMethod, contains('_setChargeLoading(true);'));
    expect(chargePressedMethod, contains('_setChargeLoading(false);'));
    expect(
      chargePressedMethod,
      isNot(contains('setState(() {')),
      reason: '充值按钮 loading 不应通过整页 setState 更新。',
    );

    expect(roomPickerPressedMethod, isNotNull);
    expect(
      roomPickerPressedMethod,
      contains('_isRoomLoadingNotifier.value'),
      reason: '房间选择按钮 pending 态应由局部 notifier 管理，不应依赖整页状态字段。',
    );
    expect(roomPickerPressedMethod, contains('_setRoomLoading(true);'));
    expect(roomPickerPressedMethod, contains('_setRoomLoading(false);'));
    expect(
      roomPickerPressedMethod,
      isNot(contains('setState(() {')),
      reason: '房间选择按钮 loading 不应通过整页 setState 更新。',
    );

    expect(roomLoadingSetterMethod, isNotNull);
    expect(
      roomLoadingSetterMethod,
      contains('!mounted || _isRoomLoadingNotifier.value == value'),
    );
    expect(roomLoadingSetterMethod, isNot(contains('setState(')));

    expect(chargeLoadingSetterMethod, isNotNull);
    expect(
      chargeLoadingSetterMethod,
      contains('!mounted || _isChargeLoadingNotifier.value == value'),
    );
    expect(chargeLoadingSetterMethod, isNot(contains('setState(')));
  });

  test('exam schedule reuses today and scans nearest exam once', () {
    final examPage =
        File(
          'lib/pages/ExamSchedule/exam_schedule_page.dart',
        ).readAsStringSync();
    final examBridge =
        File(
          'lib/pages/ExamSchedule/exam_schedule_bridge.dart',
        ).readAsStringSync();
    final getScheduleMethod = RegExp(
      r'Future<ExamScheduleResult> getSchedule\(\) async \{[\s\S]*?\n\}',
    ).firstMatch(examBridge)?.group(0);
    final scaffoldMethod = RegExp(
      r'Widget _buildScaffold\(BuildContext context, ExamScheduleResult result\) \{[\s\S]*?\n  DateTime _todayDate',
    ).firstMatch(examPage)?.group(0);
    final syncCardInfoCacheMethod = RegExp(
      r'void _syncExamScheduleCardInfoCache\([\s\S]*?\n  bool _isSameDate',
    ).firstMatch(examPage)?.group(0);
    final cardInfoMethod = RegExp(
      r'_ExamScheduleCardInfo _examScheduleCardInfoFor\([\s\S]*?\n  DateTime _todayDate',
    ).firstMatch(examPage)?.group(0);
    final nearestExamMethod = RegExp(
      r'String _nearestExamText\([\s\S]*?\n  DateTime\? _parseExamDate',
    ).firstMatch(examPage)?.group(0);
    final parseExamDateMethod = RegExp(
      r'DateTime\? _parseExamDate\(String input, \{required int fallbackYear\}\) \{[\s\S]*?\n  int\? _daysLeft',
    ).firstMatch(examPage)?.group(0);
    final parseExamDateSegmentMethod = RegExp(
      r'int\? _parseExamDateSegment\(String input, int start, int end\) \{[\s\S]*?\n  int\? _daysLeft',
    ).firstMatch(examPage)?.group(0);
    final daysLeftMethod = RegExp(
      r'int\? _daysLeft\(DateTime\? examDate, DateTime today\) \{[\s\S]*?\n  String _daysLeftText',
    ).firstMatch(examPage)?.group(0);
    final daysLeftTextMethod = RegExp(
      r'String _daysLeftText\(int\? daysLeft\) \{[\s\S]*?\n  Color _daysLeftColor',
    ).firstMatch(examPage)?.group(0);
    final daysLeftColorMethod = RegExp(
      r'Color _daysLeftColor\(int\? daysLeft, BuildContext context\) \{[\s\S]*?\n  \}\n\}',
    ).firstMatch(examPage)?.group(0);

    expect(scaffoldMethod, isNotNull);
    expect(
      scaffoldMethod,
      contains('final today = _todayDate();'),
      reason: '考试安排完成态 build 应只生成一次 today，再传给总览和列表。',
    );
    expect(scaffoldMethod, contains('_nearestExamText(schedules, today)'));
    expect(
      scaffoldMethod,
      contains('_syncExamScheduleCardInfoCache(schedules, today);'),
      reason: '考试列表派生字段缓存应随本次完成态数据源和日期同步。',
    );
    expect(
      scaffoldMethod,
      contains('final cardInfo = _examScheduleCardInfoFor'),
    );
    expect(
      scaffoldMethod,
      contains('SliverChildBuilderDelegate'),
      reason: '考试列表应按可见行懒构建，不应一次性生成所有考试卡片。',
    );
    expect(scaffoldMethod, contains('final schedule = schedules[index];'));
    expect(scaffoldMethod, contains('childCount: schedules.length'));
    expect(
      scaffoldMethod,
      contains('addAutomaticKeepAlives: false'),
      reason: '考试卡片是静态展示项，不应为每个可见考试行维护 keep-alive 状态。',
    );
    expect(
      scaffoldMethod,
      contains('addRepaintBoundaries: false'),
      reason: '考试列表卡片没有项内独立动画，不应为每个考试卡片额外创建 repaint boundary。',
    );
    expect(
      scaffoldMethod,
      isNot(contains('schedules.map')),
      reason: '考试安排完成态 build 不应通过 map 一次性物化考试卡片。',
    );
    expect(
      scaffoldMethod,
      isNot(contains('DateTime.now()')),
      reason: '考试安排完成态 build 不应在多个 helper 中重复读取当前时间。',
    );

    expect(examPage, contains('class _ExamScheduleCardInfo'));
    expect(
      examPage,
      contains('final int? daysLeft;'),
      reason: '考试卡片颜色应复用派生天数，避免从展示文案反向解析数字。',
    );
    expect(
      examPage,
      contains('final Map<Map<String, dynamic>, _ExamScheduleCardInfo>'),
      reason: '考试卡片只应为已构建的行懒缓存派生字段。',
    );
    expect(
      examPage,
      contains('_examScheduleCardInfoCache'),
      reason: '考试卡片只应为已构建的行懒缓存派生字段。',
    );
    expect(syncCardInfoCacheMethod, isNotNull);
    expect(
      syncCardInfoCacheMethod,
      contains('identical(_examScheduleCardInfoSource, schedules)'),
      reason: '同一批考试数据源重复 build 时不应清空卡片派生字段缓存。',
    );
    expect(syncCardInfoCacheMethod, contains('_isSameDate(cachedDate, today)'));
    expect(
      syncCardInfoCacheMethod,
      contains('_examScheduleCardInfoCache.clear();'),
    );
    expect(cardInfoMethod, isNotNull);
    expect(
      cardInfoMethod,
      contains('final cached = _examScheduleCardInfoCache[schedule];'),
    );
    expect(cardInfoMethod, contains('if (cached != null)'));
    expect(
      cardInfoMethod,
      contains('_parseExamDate(time, fallbackYear: today.year)'),
    );
    expect(
      cardInfoMethod,
      contains('final daysLeft = _daysLeft(examDate, today);'),
    );
    expect(cardInfoMethod, contains('daysLeftText: _daysLeftText(daysLeft)'));
    expect(cardInfoMethod, contains('daysLeft: daysLeft'));
    expect(
      cardInfoMethod,
      contains('_examScheduleCardInfoCache[schedule] = info;'),
    );

    expect(nearestExamMethod, isNotNull);
    expect(
      nearestExamMethod,
      contains('for (final schedule in schedules)'),
      reason: '最近考试只需要单次扫描，不应先物化列表再排序。',
    );
    expect(nearestExamMethod, isNot(contains('.map(')));
    expect(nearestExamMethod, isNot(contains('.where(')));
    expect(nearestExamMethod, isNot(contains('.toList()')));
    expect(nearestExamMethod, isNot(contains('..sort(')));

    expect(getScheduleMethod, isNotNull);
    expect(
      getScheduleMethod,
      contains('final schedules = <Map<String, dynamic>>[];'),
      reason: '考试安排接口解析应一次构造结果列表，避免 whereType/map/toList 链式临时对象。',
    );
    expect(getScheduleMethod, contains("final rawSchedules = data['data'];"));
    expect(getScheduleMethod, contains('if (rawSchedules is List)'));
    expect(getScheduleMethod, contains('for (final item in rawSchedules)'));
    expect(getScheduleMethod, contains('if (item is Map)'));
    expect(
      getScheduleMethod,
      contains('schedules.add(Map<String, dynamic>.from(item));'),
    );
    expect(getScheduleMethod, isNot(contains('.whereType')));
    expect(getScheduleMethod, isNot(contains('.map(')));
    expect(getScheduleMethod, isNot(contains('.toList()')));

    expect(parseExamDateMethod, isNotNull);
    expect(
      parseExamDateMethod,
      contains('fallbackYear'),
      reason: '解析异常年份应复用本次 build 的 today.year。',
    );
    expect(
      parseExamDateMethod,
      isNot(contains('DateTime.now()')),
      reason: '日期解析不应自行读取当前时间。',
    );
    expect(
      parseExamDateMethod,
      contains('for (var index = 0; index <= 10; index++)'),
      reason: '考试日期解析在卡片派生和最近考试扫描中重复调用，应扫描固定日期前缀，避免 split 列表。',
    );
    expect(parseExamDateMethod, contains('input.codeUnitAt(index) == 0x2D'));
    expect(
      parseExamDateMethod,
      contains('_parseExamDateSegment(input, segmentStart, index)'),
    );
    expect(parseExamDateMethod, isNot(contains('.split(')));
    expect(parseExamDateSegmentMethod, isNotNull);
    expect(parseExamDateSegmentMethod, contains('codeUnit < 0x30'));
    expect(parseExamDateSegmentMethod, contains('codeUnit > 0x39'));
    expect(
      parseExamDateSegmentMethod,
      contains('value = value * 10 + codeUnit - 0x30;'),
    );

    expect(daysLeftMethod, isNotNull);
    expect(
      daysLeftMethod,
      contains('examDate?.difference(today).inDays'),
      reason: '剩余天数应作为派生整数缓存，展示文案和颜色共用同一份计算结果。',
    );
    expect(
      daysLeftMethod,
      isNot(contains('DateTime.now()')),
      reason: '剩余天数计算应复用调用方传入的 today。',
    );
    expect(daysLeftTextMethod, isNotNull);
    expect(daysLeftTextMethod, contains("return '还有\$daysLeft天';"));
    expect(daysLeftColorMethod, isNotNull);
    expect(
      daysLeftColorMethod,
      contains('if (daysLeft == null)'),
      reason: '日期未知时应使用稳定的弱化色，而不是解析展示文案。',
    );
    expect(daysLeftColorMethod, contains('if (daysLeft == 0)'));
    expect(daysLeftColorMethod, contains('if (daysLeft > 0)'));
    expect(daysLeftColorMethod, contains('daysLeft <= 3'));
    expect(
      daysLeftColorMethod,
      isNot(contains('RegExp')),
      reason: '考试卡片颜色不应在 build 热路径通过正则解析展示文案。',
    );
    expect(
      daysLeftColorMethod,
      isNot(contains('replaceAll')),
      reason: '考试卡片颜色不应在 build 热路径创建临时字符串解析天数。',
    );
  });

  test('free room page keeps local formatting and grid work lazy', () {
    final freeRoomPage =
        File('lib/pages/freeroom/room.dart').readAsStringSync();
    final suggestedLessonMethod = RegExp(
      r'_BigLessonBlock _resolveSuggestedBigLesson\(DateTime now\) \{[\s\S]*?\n  String _nodeIdForRange',
    ).firstMatch(freeRoomPage)?.group(0);
    final pickDateMethod = RegExp(
      r'Future<void> _pickDate\(\) async \{[\s\S]*?\n  Future<void> _showLessonPicker',
    ).firstMatch(freeRoomPage)?.group(0);
    final lessonPickerMethod = RegExp(
      r'Future<void> _showLessonPicker\(\) async \{[\s\S]*?\n  void _showRoomDetail',
    ).firstMatch(freeRoomPage)?.group(0);
    final showRoomDetailMethod = RegExp(
      r'void _showRoomDetail\(Room room\) \{[\s\S]*?\n  Future<void> _trackRoomDetailSheet',
    ).firstMatch(freeRoomPage)?.group(0);
    final trackRoomDetailMethod = RegExp(
      r'Future<void> _trackRoomDetailSheet\(Future<void> sheet\) async \{[\s\S]*?\n  SliverAppBar _buildTopBar',
    ).firstMatch(freeRoomPage)?.group(0);
    final busyLessonsForRoomMethod = RegExp(
      r'Set<int> _busyLessonsForRoom\(Room room\) \{[\s\S]*?\n  int _parseBusyLessonKey',
    ).firstMatch(freeRoomPage)?.group(0);
    final parseBusyLessonKeyMethod = RegExp(
      r'int _parseBusyLessonKey\(String value\) \{[\s\S]*?\n  Future<T\?> _showFreeRoomSheet',
    ).firstMatch(freeRoomPage)?.group(0);
    final reloadRoomsMethod = RegExp(
      r'Future<List<Room>> _reloadRooms\(\) \{[\s\S]*?\n  _RoomCardInfo _roomCardInfoFor',
    ).firstMatch(freeRoomPage)?.group(0);
    final roomCardInfoMethod = RegExp(
      r'_RoomCardInfo _roomCardInfoFor\(Room room\) \{[\s\S]*?\n  String _compactRoomName',
    ).firstMatch(freeRoomPage)?.group(0);
    final compactRoomNameMethod = RegExp(
      r'String _compactRoomName\(String name\) \{[\s\S]*?\n  String _stripRoomNameSegments',
    ).firstMatch(freeRoomPage)?.group(0);
    final stripRoomNameSegmentsMethod = RegExp(
      r'String _stripRoomNameSegments\([\s\S]*?\n  int _roomNameTokenLengthAt',
    ).firstMatch(freeRoomPage)?.group(0);
    final buildContentMethod = RegExp(
      r'Widget _buildContent\(BuildContext context, List<Room> data\) \{[\s\S]*?\nclass _FilterPanel',
    ).firstMatch(freeRoomPage)?.group(0);
    final datePickerSheetClass = RegExp(
      r'class _DatePickerSheet extends StatefulWidget \{[\s\S]*?\nclass _BigLessonSheet',
    ).firstMatch(freeRoomPage)?.group(0);
    final bigLessonSheetClass = RegExp(
      r'class _BigLessonSheet extends StatefulWidget \{[\s\S]*?\nclass _RangePresetChip',
    ).firstMatch(freeRoomPage)?.group(0);
    final roomDetailSheetClass = RegExp(
      r'class _RoomDetailSheet extends StatelessWidget \{[\s\S]*?\nclass _DatePickerSheet',
    ).firstMatch(freeRoomPage)?.group(0);
    final fixedCrossAxisGridClass = RegExp(
      r'class _FixedCrossAxisGrid extends StatelessWidget \{[\s\S]*?\nclass _BigLessonOptionCard',
    ).firstMatch(freeRoomPage)?.group(0);

    expect(
      freeRoomPage,
      isNot(contains("package:intl/intl.dart")),
      reason: '空教室页固定日期格式不应依赖 intl DateFormat 创建格式化器。',
    );
    expect(
      freeRoomPage,
      isNot(contains('DateFormat(')),
      reason: '空教室页日期 key 和日期标签应使用轻量本地 helper。',
    );
    expect(
      freeRoomPage,
      contains('String _formatFreeRoomDateKey(DateTime date)'),
    );
    expect(
      freeRoomPage,
      contains('String _formatFreeRoomMonthDay(DateTime date)'),
    );
    expect(
      freeRoomPage,
      contains(
        'late final ValueNotifier<Future<List<Room>>> _roomFutureNotifier',
      ),
      reason: '空教室日期/大节变化只应刷新房间 Future，不应 setState 重建整页背景。',
    );
    expect(freeRoomPage, contains('_roomFutureNotifier.dispose();'));
    expect(
      freeRoomPage,
      contains('ValueListenableBuilder<Future<List<Room>>>'),
    );

    expect(suggestedLessonMethod, isNotNull);
    expect(
      suggestedLessonMethod,
      contains('for (final block in _bigLessonBlocks)'),
      reason: '建议大节只需单次扫描配置，不应先过滤并物化列表。',
    );
    expect(suggestedLessonMethod, isNot(contains('.where(')));
    expect(suggestedLessonMethod, isNot(contains('.toList()')));

    expect(pickDateMethod, isNotNull);
    expect(
      pickDateMethod,
      contains('final today = DateUtils.dateOnly(DateTime.now());'),
      reason: '日期弹层应在打开时固定 today，避免弹层 build 期间反复读取当前时间。',
    );
    expect(pickDateMethod, contains('DateTime.tryParse(date) ?? today'));
    expect(pickDateMethod, contains('today: today,'));
    expect(
      pickDateMethod,
      contains('_roomFutureNotifier.value = _reloadRooms();'),
      reason: '日期变化后应只通知房间查询 Future，避免整页 setState。',
    );
    expect(pickDateMethod, isNot(contains('setState(')));

    expect(lessonPickerMethod, isNotNull);
    expect(
      lessonPickerMethod,
      contains('final initialBlock = _selectedBigLessonBlock();'),
      reason: '大节弹层初始项应在打开时固定，避免 builder 重建时重复读取页面状态。',
    );
    expect(
      lessonPickerMethod,
      contains(
        'final suggestedBlock = _resolveSuggestedBigLesson(DateTime.now());',
      ),
      reason: '建议大节应在打开弹层时计算一次。',
    );
    expect(lessonPickerMethod, contains('initialBlock: initialBlock,'));
    expect(lessonPickerMethod, contains('suggestedBlock: suggestedBlock,'));
    expect(
      lessonPickerMethod,
      contains('_roomFutureNotifier.value = _reloadRooms();'),
      reason: '大节变化后应只通知房间查询 Future，避免整页 setState。',
    );
    expect(lessonPickerMethod, isNot(contains('setState(')));
    expect(
      lessonPickerMethod,
      isNot(contains('suggestedBlock: _resolveSuggestedBigLesson')),
      reason: '大节弹层 builder 不应在重建时重复计算建议大节。',
    );

    expect(showRoomDetailMethod, isNotNull);
    expect(showRoomDetailMethod, contains('_isRoomDetailOpen = true;'));
    expect(
      showRoomDetailMethod,
      contains('final cardInfo = _roomCardInfoFor(room);'),
      reason: '空教室详情弹层打开时应复用卡片派生信息，避免 builder 重建时重复清洗房间名。',
    );
    expect(
      showRoomDetailMethod,
      contains('unawaited(_trackRoomDetailSheet(sheet));'),
      reason: '空教室详情弹层关闭后的打开标记清理应集中到 async helper。',
    );
    expect(
      showRoomDetailMethod,
      isNot(contains('sheet.whenComplete')),
      reason: '空教室详情弹层打开标记不应通过 whenComplete 回调链清理。',
    );
    expect(trackRoomDetailMethod, isNotNull);
    expect(trackRoomDetailMethod, contains('try {'));
    expect(trackRoomDetailMethod, contains('await sheet;'));
    expect(trackRoomDetailMethod, contains('} finally {'));
    expect(
      trackRoomDetailMethod,
      contains('_isRoomDetailOpen = false;'),
      reason: '空教室详情弹层无论正常关闭还是异常完成，都必须释放打开标记。',
    );
    expect(trackRoomDetailMethod, isNot(contains('.whenComplete(')));

    expect(datePickerSheetClass, isNotNull);
    expect(datePickerSheetClass, contains('final DateTime today;'));
    expect(datePickerSheetClass, contains('final today = widget.today;'));
    expect(
      datePickerSheetClass,
      contains('late final ValueNotifier<DateTime> _selectedDateNotifier;'),
      reason: '日期弹层选择态应使用局部 notifier，避免切换日期时重建整张弹层。',
    );
    expect(
      datePickerSheetClass,
      contains('_selectedDateNotifier.dispose();'),
      reason: '日期弹层局部 notifier 应随弹层释放。',
    );
    expect(
      datePickerSheetClass,
      contains('void _selectDate(DateTime value)'),
      reason: '日期弹层选择应集中到 helper，避免多个入口重复写 setState。',
    );
    expect(
      datePickerSheetClass,
      contains(
        'if (DateUtils.isSameDay(_selectedDateNotifier.value, nextDate))',
      ),
      reason: '日期未变化时不应触发弹层局部 rebuild。',
    );
    expect(
      datePickerSheetClass,
      contains('_selectedDateNotifier.value = nextDate;'),
    );
    expect(
      datePickerSheetClass,
      contains('ValueListenableBuilder<DateTime>'),
      reason: '日期弹层切换时应只刷新当前日期文本、今天快捷项和日历区域。',
    );
    expect(datePickerSheetClass, contains('onTap: () => _selectDate(today)'));
    expect(datePickerSheetClass, contains('onDateChanged: _selectDate'));
    expect(
      datePickerSheetClass,
      contains('pop(_selectedDateNotifier.value)'),
      reason: '确认按钮应读取局部 notifier 当前值。',
    );
    expect(
      datePickerSheetClass,
      isNot(contains('setState(()')),
      reason: '日期弹层切换选项不应触发整张弹层 setState。',
    );
    expect(
      datePickerSheetClass,
      isNot(contains('DateTime.now()')),
      reason: '日期弹层 build 应复用打开时传入的 today。',
    );

    expect(bigLessonSheetClass, isNotNull);
    expect(
      bigLessonSheetClass,
      contains(
        'late final ValueNotifier<_BigLessonBlock> _selectedBlockNotifier;',
      ),
      reason: '大节弹层选择态应使用局部 notifier，避免切换选项时重建整张弹层。',
    );
    expect(
      bigLessonSheetClass,
      contains('_selectedBlockNotifier.dispose();'),
      reason: '大节弹层局部 notifier 应随弹层释放。',
    );
    expect(
      bigLessonSheetClass,
      contains('void _selectBlock(_BigLessonBlock block)'),
      reason: '大节弹层选择应集中到 helper，避免多个入口重复写 setState。',
    );
    expect(
      bigLessonSheetClass,
      contains('if (_selectedBlockNotifier.value.index == block.index)'),
      reason: '大节未变化时不应触发弹层局部 rebuild。',
    );
    expect(
      bigLessonSheetClass,
      contains('_selectedBlockNotifier.value = block;'),
    );
    expect(
      bigLessonSheetClass,
      contains('ValueListenableBuilder<_BigLessonBlock>'),
      reason: '大节弹层切换时应只刷新当前选择文本和选项区域。',
    );
    expect(
      bigLessonSheetClass,
      isNot(contains('setState(()')),
      reason: '大节弹层切换选项不应触发整张弹层 setState。',
    );
    expect(
      bigLessonSheetClass,
      contains('onTap: () => _selectBlock(widget.suggestedBlock)'),
    );
    expect(bigLessonSheetClass, contains('onTap: () => _selectBlock(block)'));

    expect(busyLessonsForRoomMethod, isNotNull);
    expect(
      busyLessonsForRoomMethod,
      contains('final busyLessons = <int>{};'),
      reason: '空教室房间占用节次应按 Room 预解析成集合，供卡片和详情复用。',
    );
    expect(
      busyLessonsForRoomMethod,
      contains('for (final rawLesson in room.free)'),
    );
    expect(
      busyLessonsForRoomMethod,
      contains('final lesson = _parseBusyLessonKey(rawLesson);'),
    );
    expect(busyLessonsForRoomMethod, contains('busyLessons.add(lesson);'));
    expect(busyLessonsForRoomMethod, isNot(contains('room.free.contains')));
    expect(busyLessonsForRoomMethod, isNot(contains('padLeft')));
    expect(busyLessonsForRoomMethod, isNot(contains('List<int>.generate')));
    expect(busyLessonsForRoomMethod, isNot(contains('.where(')));

    expect(parseBusyLessonKeyMethod, isNotNull);
    expect(parseBusyLessonKeyMethod, contains('value.codeUnitAt(0)'));
    expect(parseBusyLessonKeyMethod, contains('value.codeUnitAt(1)'));
    expect(
      parseBusyLessonKeyMethod,
      contains('return (first - 0x30) * 10 + second - 0x30;'),
    );
    expect(parseBusyLessonKeyMethod, isNot(contains('int.tryParse')));
    expect(parseBusyLessonKeyMethod, isNot(contains('padLeft')));

    expect(freeRoomPage, contains('class _RoomCardInfo'));
    expect(
      freeRoomPage,
      contains('final Map<Room, _RoomCardInfo> _roomCardInfoCache'),
      reason: '空教室可见卡片字段应按 Room 懒缓存，避免滑动和重建时重复清洗房间名与扫描节次。',
    );
    expect(reloadRoomsMethod, isNotNull);
    expect(
      reloadRoomsMethod,
      contains('_roomCardInfoCache.clear();'),
      reason: '日期或大节改变后应清空旧房间卡片派生缓存。',
    );
    expect(reloadRoomsMethod, contains('return _loadRooms();'));

    expect(roomCardInfoMethod, isNotNull);
    expect(
      roomCardInfoMethod,
      contains('final cached = _roomCardInfoCache[room];'),
    );
    expect(roomCardInfoMethod, contains('if (cached != null)'));
    expect(
      roomCardInfoMethod,
      contains('compactName: _compactRoomName(room.name)'),
    );
    expect(
      roomCardInfoMethod,
      contains('final busyLessons = _busyLessonsForRoom(room);'),
    );
    expect(roomCardInfoMethod, contains('busySlotCount: busyLessons.length'));
    expect(roomCardInfoMethod, contains('busyLessons: busyLessons'));
    expect(roomCardInfoMethod, contains('_roomCardInfoCache[room] = info;'));

    expect(compactRoomNameMethod, isNotNull);
    expect(compactRoomNameMethod, contains('_stripRoomNameSegments('));
    expect(compactRoomNameMethod, contains('tokens: _roomNameCompactTokens'));
    expect(compactRoomNameMethod, contains('tokens: _roomNameFallbackTokens'));
    expect(compactRoomNameMethod, isNot(contains('replaceAll')));
    expect(compactRoomNameMethod, isNot(contains('replaceFirst')));

    expect(stripRoomNameSegmentsMethod, isNotNull);
    expect(
      stripRoomNameSegmentsMethod,
      contains('for (var index = 0; index < name.length;)'),
      reason: '空教室房间名压缩应单次扫描输入，避免对每个房间串行 replaceAll。',
    );
    expect(
      stripRoomNameSegmentsMethod,
      contains('name.startsWith(buildingName, index)'),
    );
    expect(
      stripRoomNameSegmentsMethod,
      contains(
        'final tokenLength = _roomNameTokenLengthAt(name, index, tokens);',
      ),
    );
    expect(stripRoomNameSegmentsMethod, contains('buffer.write(name[index]);'));
    expect(stripRoomNameSegmentsMethod, isNot(contains('replaceAll')));
    expect(stripRoomNameSegmentsMethod, isNot(contains('replaceFirst')));
    expect(stripRoomNameSegmentsMethod, isNot(contains('RegExp')));

    expect(buildContentMethod, isNotNull);
    expect(
      buildContentMethod,
      contains('final room = data[index];'),
      reason: '空教室网格应按 Sliver 可见项懒计算卡片字段。',
    );
    expect(
      buildContentMethod,
      contains('final cardInfo = _roomCardInfoFor(room);'),
    );
    expect(
      buildContentMethod,
      isNot(contains('_compactRoomName(room.name)')),
      reason: '房间名压缩结果应复用懒缓存，不应在每次卡片 build 中重复字符串清洗。',
    );
    expect(
      buildContentMethod,
      isNot(contains('_busySlotCount(room)')),
      reason: '忙碌节次统计应复用懒缓存，不应在每次卡片 build 中重复扫描全天节次。',
    );
    expect(
      buildContentMethod,
      isNot(contains('room.free.contains')),
      reason: '空教室网格卡片不应在 build 中按节次反复做字符串列表查找。',
    );
    expect(buildContentMethod, contains('childCount: data.length'));
    expect(
      buildContentMethod,
      isNot(contains('final roomItems =')),
      reason: '空教室网格不应在首屏 build 时预构造整页 roomItems。',
    );
    expect(
      freeRoomPage,
      isNot(contains('class _RoomGridItem')),
      reason: '移除整页预构造后不应保留 roomItems 中间模型。',
    );
    expect(fixedCrossAxisGridClass, isNotNull);
    expect(
      fixedCrossAxisGridClass,
      contains('child: itemBuilder(context, index)'),
      reason: '空教室固定小网格应直接挂载静态格子，避免额外包装层。',
    );
    expect(
      fixedCrossAxisGridClass,
      isNot(contains('RepaintBoundary(')),
      reason: '空教室固定小网格项没有独立动画，不应为每个格子创建 repaint 边界。',
    );

    expect(roomDetailSheetClass, isNotNull);
    expect(roomDetailSheetClass, contains('final Set<int> busyLessons;'));
    expect(
      roomDetailSheetClass,
      contains('final freeCount = slotCount - busySlotCount;'),
    );
    expect(
      roomDetailSheetClass,
      contains('final busy = busyLessons.contains(lesson);'),
    );
    expect(roomDetailSheetClass, isNot(contains('room.free.contains')));
    expect(roomDetailSheetClass, isNot(contains('padLeft')));
    expect(roomDetailSheetClass, isNot(contains('_countFreeRoomBusySlots')));
  });

  test('building page caches derived directory data', () {
    final buildingPage =
        File('lib/pages/freeroom/building.dart').readAsStringSync();
    final buildContentMethod = RegExp(
      r'Widget _buildContent\(BuildContext context, List<Building> data\) \{[\s\S]*?\nclass _CampusHeroCard',
    ).firstMatch(buildingPage)?.group(0);
    final directoryCacheMethod = RegExp(
      r'_BuildingDirectory _buildingDirectoryFor\(List<Building> data\) \{[\s\S]*?\n  _BuildingDirectory _buildBuildingDirectory',
    ).firstMatch(buildingPage)?.group(0);
    final campusLabelMethod = RegExp(
      r'String _campusLabel\(String name\) \{[\s\S]*?\n  bool _containsCampusToken',
    ).firstMatch(buildingPage)?.group(0);
    final containsCampusTokenMethod = RegExp(
      r'bool _containsCampusToken\(String name, String token\) \{[\s\S]*?\n  bool _startsWithCampusToken',
    ).firstMatch(buildingPage)?.group(0);
    final startsWithCampusTokenMethod = RegExp(
      r'bool _startsWithCampusToken\(String name, int start, String token\) \{[\s\S]*?\n  String _compactBuildingName',
    ).firstMatch(buildingPage)?.group(0);
    final compactBuildingNameMethod = RegExp(
      r'String _compactBuildingName\(String name\) \{[\s\S]*?\n  _BuildingDirectory _buildingDirectoryFor',
    ).firstMatch(buildingPage)?.group(0);
    final buildDirectoryMethod = RegExp(
      r'_BuildingDirectory _buildBuildingDirectory\(List<Building> data\) \{[\s\S]*?\n  Color _campusAccent',
    ).firstMatch(buildingPage)?.group(0);
    final gridClass = RegExp(
      r'class _CampusBuildingGrid extends StatelessWidget \{[\s\S]*?\ndouble _resolveBuildingTitleFontSize',
    ).firstMatch(buildingPage)?.group(0);
    final cardClass = RegExp(
      r'class _BuildingCard extends StatelessWidget \{[\s\S]*?\nclass _BuildingInfoPill',
    ).firstMatch(buildingPage)?.group(0);

    expect(buildingPage, contains('class _BuildingDirectory'));
    expect(
      buildingPage,
      contains('_BuildingDirectory? _cachedBuildingDirectory;'),
    );

    expect(buildContentMethod, isNotNull);
    expect(
      buildContentMethod,
      contains('final directory = _buildingDirectoryFor(data);'),
    );
    expect(
      buildContentMethod,
      isNot(contains('_groupBuildings')),
      reason: '教学楼完成态 build 不应重复按校区分组。',
    );
    expect(
      buildContentMethod,
      isNot(contains('_totalClassrooms')),
      reason: '教学楼完成态 build 不应重复统计教室总数。',
    );
    expect(
      buildContentMethod,
      isNot(contains('data.map(')),
      reason: '教学楼完成态 build 不应重复派生显示名和教室数标签。',
    );
    expect(buildContentMethod, isNot(contains('.toList()')));

    expect(directoryCacheMethod, isNotNull);
    expect(
      directoryCacheMethod,
      contains('identical(_buildingDirectorySource, data)'),
      reason: '同一教学楼数据源的目录派生结果应复用。',
    );
    expect(campusLabelMethod, isNotNull);
    expect(campusLabelMethod, contains("_containsCampusToken(name, '河西')"));
    expect(campusLabelMethod, contains("_containsCampusToken(name, '河东')"));
    expect(campusLabelMethod, isNot(contains('replaceAll')));
    expect(containsCampusTokenMethod, isNotNull);
    expect(
      containsCampusTokenMethod,
      contains('for (var index = 0; index < name.length; index++)'),
      reason: '教学楼页校区归类应扫描名称 token，避免为每栋楼创建去空格副本。',
    );
    expect(startsWithCampusTokenMethod, isNotNull);
    expect(startsWithCampusTokenMethod, contains('name.codeUnitAt(nameIndex)'));
    expect(startsWithCampusTokenMethod, contains('if (nameCodeUnit == 0x20)'));
    expect(compactBuildingNameMethod, isNotNull);
    expect(
      compactBuildingNameMethod,
      contains('_buildingNameContentStart(name, 0)'),
      reason: '教学楼名称压缩应使用轻量字符扫描，不应为每个楼栋创建正则。',
    );
    expect(compactBuildingNameMethod, contains('_stripBuildingNamePrefix'));
    expect(compactBuildingNameMethod, contains('value.codeUnitAt(index)'));
    expect(
      compactBuildingNameMethod,
      isNot(contains('RegExp')),
      reason: '教学楼目录派生会逐项压缩名称，不应在该路径重复创建 RegExp。',
    );
    expect(
      compactBuildingNameMethod,
      isNot(contains('replaceFirst')),
      reason: '教学楼名称压缩应避免连续 replaceFirst 产生临时字符串。',
    );

    expect(buildDirectoryMethod, isNotNull);
    expect(
      buildDirectoryMethod,
      contains('for (final building in data)'),
      reason: '教学楼目录应单次扫描并同时产出分组、统计和卡片字段。',
    );
    expect(buildDirectoryMethod, contains('_BuildingGridItem'));

    expect(gridClass, isNotNull);
    expect(
      gridClass,
      isNot(contains('compactBuildingName(building.name)')),
      reason: '教学楼网格不应在每次 build 时重复压缩楼名。',
    );
    expect(
      gridClass,
      contains('child: _BuildingCard('),
      reason: '教学楼网格应直接挂载静态卡片，避免额外包装层。',
    );
    expect(
      gridClass,
      isNot(contains('RepaintBoundary(')),
      reason: '教学楼网格项没有常驻独立动画，不应为每栋楼创建 repaint 边界。',
    );

    expect(cardClass, isNotNull);
    expect(cardClass, contains('final _BuildingGridItem item;'));
    expect(
      cardClass,
      isNot(contains("final roomCountLabel = '\${building.count}间';")),
      reason: '教学楼卡片不应在每次 build 时重复拼接教室数标签。',
    );
    expect(
      cardClass,
      isNot(contains('final freeLabel =')),
      reason: '教学楼卡片不应在每次 build 时重复拼接空闲数标签。',
    );
  });

  test('free room bridge failures use stable messages', () {
    final buildingBridge =
        File('lib/pages/freeroom/building_bridge.dart').readAsStringSync();
    final loadBuildingMethod = RegExp(
      r'Future<List<Building>> _loadBuildingList\([\s\S]*?\nFuture<List<Building>> _loadBuildingsFromApi',
    ).firstMatch(buildingBridge)?.group(0);
    final loadRoomMethod = RegExp(
      r'Future<List<Room>> _loadRoomList\([\s\S]*?\nFuture<List<Room>> _loadRoomsFromApi',
    ).firstMatch(buildingBridge)?.group(0);

    expect(
      buildingBridge,
      contains("const freeRoomBuildingLoadFailureMessage = '教学楼加载失败，请稍后重试';"),
      reason: '教学楼加载失败应使用稳定文案，避免展示底层异常、URL 或 token。',
    );
    expect(
      buildingBridge,
      contains("const freeRoomListLoadFailureMessage = '空教室加载失败，请稍后重试';"),
      reason: '空教室列表加载失败应使用稳定文案，避免展示底层异常、URL 或 token。',
    );

    expect(loadBuildingMethod, isNotNull);
    expect(
      loadBuildingMethod,
      contains(
        'buildingLoadErrorMessage = freeRoomBuildingLoadFailureMessage;',
      ),
    );
    expect(
      loadBuildingMethod,
      isNot(contains('buildingLoadErrorMessage = error.toString()')),
      reason: '教学楼加载失败不应把底层异常直接展示到页面。',
    );
    expect(loadBuildingMethod, isNot(contains("replaceFirst('Bad state: '")));

    expect(loadRoomMethod, isNotNull);
    expect(
      loadRoomMethod,
      contains('roomLoadErrorMessage = freeRoomListLoadFailureMessage;'),
    );
    expect(
      loadRoomMethod,
      isNot(contains('roomLoadErrorMessage = error.toString()')),
      reason: '空教室列表加载失败不应把底层异常直接展示到页面。',
    );
    expect(loadRoomMethod, isNot(contains("replaceFirst('Bad state: '")));
  });

  test('free room building api parses building rows without mapped chains', () {
    final roomApi = File('lib/utils/roomapi.dart').readAsStringSync();
    final priorityMethod = RegExp(
      r'int _buildingPriority\(String name\) \{[\s\S]*?\n  bool _containsBuildingNameToken',
    ).firstMatch(roomApi)?.group(0);
    final containsTokenMethod = RegExp(
      r'bool _containsBuildingNameToken\(String name, String token\) \{[\s\S]*?\n  bool _startsWithBuildingNameToken',
    ).firstMatch(roomApi)?.group(0);
    final startsWithTokenMethod = RegExp(
      r'bool _startsWithBuildingNameToken\(String name, int start, String token\) \{[\s\S]*?\n  Map<String, dynamic> _responseMap',
    ).firstMatch(roomApi)?.group(0);
    final getBuildingListMethod = RegExp(
      r'Future<List<Building>> getBuildingList\(\) async \{[\s\S]*?\n  \}',
    ).firstMatch(roomApi)?.group(0);

    expect(roomApi, contains('class _BuildingListRow'));
    expect(roomApi, contains('final int priority;'));

    expect(priorityMethod, isNotNull);
    expect(priorityMethod, contains("_containsBuildingNameToken(name, '河西')"));
    expect(priorityMethod, contains("_containsBuildingNameToken(name, '公共')"));
    expect(priorityMethod, contains("_containsBuildingNameToken(name, '公教')"));
    expect(priorityMethod, isNot(contains('replaceAll')));
    expect(priorityMethod, isNot(contains('RegExp')));

    expect(containsTokenMethod, isNotNull);
    expect(
      containsTokenMethod,
      contains('for (var index = 0; index < name.length; index++)'),
      reason: '教学楼名称 token 匹配应扫描输入，不应先生成去空格副本。',
    );
    expect(containsTokenMethod, isNot(contains('replaceAll')));

    expect(startsWithTokenMethod, isNotNull);
    expect(
      startsWithTokenMethod,
      contains('final nameCodeUnit = name.codeUnitAt(nameIndex);'),
    );
    expect(startsWithTokenMethod, contains('if (nameCodeUnit == 0x20)'));
    expect(startsWithTokenMethod, contains('token.codeUnitAt(tokenIndex)'));
    expect(startsWithTokenMethod, isNot(contains('replaceAll')));

    expect(getBuildingListMethod, isNotNull);
    expect(
      getBuildingListMethod,
      contains('final buildingListData = <_BuildingListRow>[];'),
      reason: '教学楼接口解析应一次循环复制有效 Map 并预计算排序字段，避免排序比较器重复清洗楼名。',
    );
    expect(
      getBuildingListMethod,
      contains("final rawBuildingList = data['data'];"),
    );
    expect(getBuildingListMethod, contains('if (rawBuildingList is List)'));
    expect(
      getBuildingListMethod,
      contains('for (final item in rawBuildingList)'),
    );
    expect(getBuildingListMethod, contains('if (item is Map)'));
    expect(
      getBuildingListMethod,
      contains('final row = Map<String, dynamic>.from(item);'),
    );
    expect(
      getBuildingListMethod,
      contains("final name = row['teachingBuildingName']?.toString() ?? '';"),
    );
    expect(
      getBuildingListMethod,
      contains('priority: _buildingPriority(name)'),
    );
    expect(
      getBuildingListMethod,
      contains(
        'final priorityCompare = left.priority.compareTo(right.priority);',
      ),
    );
    expect(
      getBuildingListMethod,
      contains('return left.name.compareTo(right.name);'),
    );
    expect(getBuildingListMethod, isNot(contains('_buildingPriority(left')));
    expect(getBuildingListMethod, isNot(contains('_buildingPriority(right')));
    expect(getBuildingListMethod, isNot(contains('replaceAll')));
    expect(getBuildingListMethod, isNot(contains('whereType')));
    expect(getBuildingListMethod, isNot(contains('.map(')));
    expect(getBuildingListMethod, isNot(contains('.toList()')));
  });

  test('free room api parses room lesson tokens without split chains', () {
    final roomApi = File('lib/utils/roomapi.dart').readAsStringSync();
    final stringToListMethod = RegExp(
      r'List<String> stringToList\(String input\) \{[\s\S]*?\n  Future<List<Room>> getFreeRoomList',
    ).firstMatch(roomApi)?.group(0);

    expect(stringToListMethod, isNotNull);
    expect(
      stringToListMethod,
      contains('for (var index = 0; index <= input.length; index++)'),
      reason: '空教室节次 token 解析应扫描逗号分隔内容，避免为每个房间额外生成 split 列表。',
    );
    expect(stringToListMethod, contains('input.codeUnitAt(index) == 0x2c'));
    expect(
      stringToListMethod,
      contains('input.substring(tokenStart + 1, index)'),
    );
    expect(stringToListMethod, isNot(contains('.split(')));
    expect(stringToListMethod, isNot(contains('.map(')));
    expect(stringToListMethod, isNot(contains('.toList()')));
  });

  test('score semester refresh keeps content and selector state local', () {
    final scorePage = File('lib/pages/score/scorepage.dart').readAsStringSync();
    final refreshMethod = RegExp(
      r'Future<void> _refreshScoresForSelection[\s\S]*?\n  Future<ScoreLoadResult> _loadScoreForSemester',
    ).firstMatch(scorePage)?.group(0);
    final syncContentMethod = RegExp(
      r'void _syncScoreContentState\(\) \{[\s\S]*?\n  void _syncSelectionState',
    ).firstMatch(scorePage)?.group(0);
    final initialLoadMethod = RegExp(
      r'Future<void> getTimeList\(\) async \{[\s\S]*?\n  String _formatSemesterLabel',
    ).firstMatch(scorePage)?.group(0);
    final buildScaffoldMethod = RegExp(
      r'Widget _buildScaffold\(BuildContext context\) \{[\s\S]*?\nclass _ScoreLoadKey',
    ).firstMatch(scorePage)?.group(0);

    expect(
      scorePage,
      contains(
        'final ValueNotifier<_ScoreSelectionState> _selectionStateNotifier',
      ),
      reason: '成绩页学期选择器的 label/loading 应局部刷新，避免切换未缓存学期时先重建整页。',
    );
    expect(
      scorePage,
      contains('final ValueNotifier<_ScoreContentState> _contentStateNotifier'),
      reason: '成绩页课程列表和总览应局部刷新，避免切学期时重建整页背景和固定按钮。',
    );
    expect(scorePage, contains('_selectionStateNotifier.dispose();'));
    expect(scorePage, contains('_contentStateNotifier.dispose();'));
    expect(scorePage, contains('class _ScoreSelectionState'));
    expect(scorePage, contains('other is _ScoreSelectionState'));
    expect(scorePage, contains('class _ScoreContentState'));
    expect(scorePage, contains('other is _ScoreContentState'));
    expect(scorePage, contains('listEquals(other.scoreList, scoreList)'));

    expect(syncContentMethod, isNotNull);
    expect(
      syncContentMethod,
      contains('_contentStateNotifier.value == nextState'),
      reason: '成绩内容状态相同时不应通知列表区域重建。',
    );
    expect(
      syncContentMethod,
      contains('_contentStateNotifier.value = nextState;'),
    );
    expect(syncContentMethod, isNot(contains('setState(')));

    expect(refreshMethod, isNotNull);
    final refreshMethodText = refreshMethod!;
    final sameSelectionGuardIndex = refreshMethodText.indexOf(
      'if (semesterId == selectedId)',
    );
    final generationIndex = refreshMethodText.indexOf(
      'final generation = ++_selectionRefreshGeneration;',
    );
    final cachedLookupIndex = refreshMethodText.indexOf(
      'final cached = _scoreCache[semesterId];',
    );
    expect(sameSelectionGuardIndex, isNot(-1));
    expect(generationIndex, isNot(-1));
    expect(cachedLookupIndex, isNot(-1));
    expect(
      sameSelectionGuardIndex,
      lessThan(generationIndex),
      reason: '重复选择当前学期时不应推进刷新 generation 或触发后续 setState。',
    );
    expect(
      sameSelectionGuardIndex,
      lessThan(cachedLookupIndex),
      reason: '同一学期的缓存命中也不应重新赋值并重建成绩页。',
    );
    expect(
      refreshMethodText,
      isNot(contains('_setScoreData(scoreData')),
      reason: '学期切换完成时应直接同步内容 notifier，不应绕回整页状态入口。',
    );
    expect(
      refreshMethodText,
      contains(
        'selectedId = semesterId;\n    _isRefreshingSelection = true;\n    _syncSelectionState();',
      ),
      reason: '未缓存学期开始刷新时只通知右上角学期选择器，不应先整页 setState。',
    );
    expect(
      refreshMethodText,
      isNot(
        contains(
          'setState(() {\n      selectedId = semesterId;\n      _isRefreshingSelection = true;',
        ),
      ),
      reason: '学期切换 pending 态不应为了按钮 label/loading 触发整页重建。',
    );
    expect(
      refreshMethodText,
      contains('_syncSelectionState();'),
      reason: '缓存命中、失败和成功落数据后都应同步选择器局部状态。',
    );
    expect(
      refreshMethodText,
      contains('_syncScoreContentState();'),
      reason: '缓存命中、失败和成功落数据后都应同步成绩内容局部状态。',
    );
    expect(
      refreshMethodText,
      isNot(contains('setState(')),
      reason: '成绩学期刷新不应重建整页 Scaffold/背景/固定按钮。',
    );

    expect(buildScaffoldMethod, isNotNull);
    expect(
      buildScaffoldMethod,
      contains('ValueListenableBuilder<_ScoreContentState>'),
      reason: '成绩总览和列表应监听内容局部状态。',
    );
    expect(
      buildScaffoldMethod,
      contains('valueListenable: _contentStateNotifier'),
    );
    expect(
      buildScaffoldMethod,
      contains('_buildScoreContentScrollView('),
      reason: '成绩内容区域应从 Scaffold 中拆出，避免内容变动重建固定按钮。',
    );
    expect(buildScaffoldMethod, contains('contentState.selectedId'));
    expect(buildScaffoldMethod, contains('contentState.scoreList'));
    expect(buildScaffoldMethod, contains('contentState.errorMessage'));
    expect(
      buildScaffoldMethod,
      contains('ValueListenableBuilder<_ScoreSelectionState>'),
      reason: '右上角学期选择器应监听局部选择状态。',
    );
    expect(
      buildScaffoldMethod,
      contains('valueListenable: _selectionStateNotifier'),
    );
    expect(buildScaffoldMethod, contains('selectionState.selectedId'));
    expect(buildScaffoldMethod, contains('selectionState.isRefreshing'));

    expect(initialLoadMethod, isNotNull);
    final initialLoadText = initialLoadMethod!;
    final scoreLoadIndex = initialLoadText.indexOf(
      "final scoreData = await _loadScoreForSemester('all');",
    );
    final successAssignIndex = initialLoadText.indexOf(
      "_assignScoreData(scoreData, semesterId: 'all');",
      scoreLoadIndex,
    );
    final successContentSyncIndex = initialLoadText.indexOf(
      '_syncScoreContentState();',
      successAssignIndex,
    );
    expect(scoreLoadIndex, isNot(-1));
    expect(successAssignIndex, isNot(-1));
    expect(successContentSyncIndex, isNot(-1));
    expect(
      initialLoadText,
      isNot(contains('setState(')),
      reason: '成绩页首屏数据落地应只同步局部内容和选择器状态，不应整页 setState。',
    );
    expect(
      scoreLoadIndex,
      lessThan(successAssignIndex),
      reason: '首屏成功路径应先加载全部成绩，再写入学期和成绩状态。',
    );
    expect(
      successAssignIndex,
      lessThan(successContentSyncIndex),
      reason: '首屏成功路径写入成绩数据后再通知内容区域刷新。',
    );
  });

  test('score jump page keeps loading and error state local', () {
    final jumpToScorePage =
        File('lib/pages/score/jump_to_score_page.dart').readAsStringSync();
    final loadingHelper = RegExp(
      r'void _showLoadingIfNeeded\(\) \{[\s\S]*?\n  void _showError',
    ).firstMatch(jumpToScorePage)?.group(0);
    final errorHelper = RegExp(
      r'void _showError\(String message\) \{[\s\S]*?\n  void _hideLoadingIfNeeded',
    ).firstMatch(jumpToScorePage)?.group(0);
    final hideLoadingHelper = RegExp(
      r'void _hideLoadingIfNeeded\(\) \{[\s\S]*?\n  Future<void> _jumpToScorePage',
    ).firstMatch(jumpToScorePage)?.group(0);
    final jumpMethod = RegExp(
      r'Future<void> _jumpToScorePage\(\) async \{[\s\S]*?\n  @override',
    ).firstMatch(jumpToScorePage)?.group(0);

    expect(
      jumpToScorePage,
      contains('final ValueNotifier<_ScoreJumpPanelState> _panelState'),
      reason: '成绩跳转页 loading/error 只影响中间面板，不应整页 setState。',
    );
    expect(
      jumpToScorePage,
      contains('ValueListenableBuilder<_ScoreJumpPanelState>'),
    );
    expect(jumpToScorePage, contains('_panelState.dispose();'));
    expect(jumpToScorePage, contains('class _ScoreJumpPanelState'));

    expect(loadingHelper, isNotNull);
    expect(
      loadingHelper,
      contains('_panelState.value.isLoading'),
      reason: '成绩跳转页初始状态已是 loading，进入页时不应重复通知同一状态。',
    );
    expect(
      loadingHelper,
      contains('_panelState.value = const _ScoreJumpPanelState.loading();'),
    );
    expect(loadingHelper, isNot(contains('setState(')));

    expect(errorHelper, isNotNull);
    expect(
      errorHelper,
      contains('panelState.errorMessage == message'),
      reason: '成绩跳转页重复落同一错误时不应再次通知重建错误面板。',
    );
    expect(
      errorHelper,
      contains('_panelState.value = _ScoreJumpPanelState.error(message);'),
    );
    expect(errorHelper, isNot(contains('setState(')));

    expect(hideLoadingHelper, isNotNull);
    expect(
      hideLoadingHelper,
      contains('if (!mounted || !_panelState.value.isLoading)'),
      reason: '成绩跳转页收尾时只有仍在 loading 才需要通知面板。',
    );
    expect(
      hideLoadingHelper,
      contains("_ScoreJumpPanelState.error('成绩页面暂时无法打开')"),
    );
    expect(hideLoadingHelper, isNot(contains('setState(')));

    expect(jumpMethod, isNotNull);
    expect(jumpMethod, contains('_showLoadingIfNeeded();'));
    expect(jumpMethod, contains("_showError('教务系统登录状态已失效，请重新登录后重试。');"));
    expect(jumpMethod, contains("_showError('成绩页面暂时无法打开，请稍后重试。');"));
    expect(jumpMethod, contains('_hideLoadingIfNeeded();'));
    expect(
      jumpMethod,
      isNot(contains('_errorMessage = null;\n      });')),
      reason: '登录态校验入口应通过 helper 按需恢复 loading，不应无条件重建首帧。',
    );
    expect(
      jumpMethod,
      isNot(contains('_errorMessage = ')),
      reason: '成绩跳转页错误状态应集中走 _showError，避免分支里重复 setState。',
    );
    expect(
      jumpMethod,
      isNot(contains('setState(')),
      reason: '成绩跳转页异步跳转流程不应整页 setState。',
    );
  });

  test('course sync bridge keeps loading and error state local', () {
    final getCoursePage =
        File('lib/bridge/get_course_page.dart').readAsStringSync();
    final loadMethod = RegExp(
      r'Future<void> _loadClass\(\) async \{[\s\S]*?\n  void _showLoadingIfNeeded',
    ).firstMatch(getCoursePage)?.group(0);
    final loadingHelper = RegExp(
      r'void _showLoadingIfNeeded\(\) \{[\s\S]*?\n  void _showError',
    ).firstMatch(getCoursePage)?.group(0);
    final errorHelper = RegExp(
      r'void _showError\(String message\) \{[\s\S]*?\n  void _hideLoadingIfNeeded',
    ).firstMatch(getCoursePage)?.group(0);
    final hideLoadingHelper = RegExp(
      r'void _hideLoadingIfNeeded\(\) \{[\s\S]*?\n  void _goToHome',
    ).firstMatch(getCoursePage)?.group(0);

    expect(
      getCoursePage,
      contains('final ValueNotifier<_CourseSyncPanelState> _panelState'),
      reason: '课表同步入口 loading/error 只影响中间内容，不应整页 setState。',
    );
    expect(
      getCoursePage,
      contains('ValueListenableBuilder<_CourseSyncPanelState>'),
    );
    expect(getCoursePage, contains('_panelState.dispose();'));
    expect(getCoursePage, contains('class _CourseSyncPanelState'));

    expect(loadMethod, isNotNull);
    expect(
      loadMethod,
      contains('_showLoadingIfNeeded();'),
      reason: '课表同步入口初始状态已是 loading，应通过 helper 按需恢复 loading。',
    );
    expect(loadMethod, contains('_showError(result.message);'));
    expect(loadMethod, contains('_hideLoadingIfNeeded();'));
    expect(
      loadMethod,
      isNot(contains('setState(()')),
      reason: '课表同步入口异步主流程不应散落 setState，避免初始化和失败路径重复重建。',
    );

    expect(loadingHelper, isNotNull);
    expect(
      loadingHelper,
      contains('_panelState.value.isLoading'),
      reason: '课表同步入口首帧已是 loading，进入页时不应重复通知同一状态。',
    );
    expect(
      loadingHelper,
      contains('_panelState.value = const _CourseSyncPanelState.loading();'),
    );
    expect(loadingHelper, isNot(contains('setState(')));

    expect(errorHelper, isNotNull);
    expect(
      errorHelper,
      contains('panelState.errorMessage == message'),
      reason: '相同错误状态不应重复通知并重建入口内容。',
    );
    expect(
      errorHelper,
      contains('_panelState.value = _CourseSyncPanelState.error(message);'),
    );
    expect(errorHelper, isNot(contains('setState(')));

    expect(hideLoadingHelper, isNotNull);
    expect(
      hideLoadingHelper,
      contains('if (!mounted || !_panelState.value.isLoading)'),
    );
    expect(
      hideLoadingHelper,
      contains("_CourseSyncPanelState.error('发生未知错误')"),
    );
    expect(hideLoadingHelper, isNot(contains('setState(')));
  });

  test('score course list builds visible rows lazily', () {
    final scorePage = File('lib/pages/score/scorepage.dart').readAsStringSync();
    final scaffoldMethod = RegExp(
      r'Widget _buildScaffold\(BuildContext context\) \{[\s\S]*?\nclass _ScoreLoadKey',
    ).firstMatch(scorePage)?.group(0);
    final numericFractionMethod = RegExp(
      r'double\? _numericFraction\(String text\) \{[\s\S]*?\n  _ScorePalette _paletteForScore',
    ).firstMatch(scorePage)?.group(0);

    expect(scaffoldMethod, isNotNull);
    expect(
      scaffoldMethod,
      contains('SliverChildBuilderDelegate'),
      reason: '成绩课程列表应按可见行懒构建，不应一次性生成所有课程卡片。',
    );
    expect(scaffoldMethod, contains('final score = scoreList[index];'));
    expect(scaffoldMethod, contains('childCount: scoreList.length'));
    expect(
      scaffoldMethod,
      contains('addAutomaticKeepAlives: false'),
      reason: '成绩课程卡片是静态展示项，不应为每个可见课程行维护 keep-alive 状态。',
    );
    expect(
      scaffoldMethod,
      contains('addRepaintBoundaries: false'),
      reason: '成绩课程列表没有项内独立动画，不应为每个课程卡片额外创建 repaint boundary。',
    );
    expect(
      scaffoldMethod,
      isNot(contains('scoreList.map')),
      reason: '成绩页完成态 build 不应通过 map 一次性物化课程卡片。',
    );

    expect(numericFractionMethod, isNotNull);
    expect(
      numericFractionMethod,
      contains('text.codeUnitAt(index)'),
      reason: '成绩列表可见行会按需计算分数分档，应直接扫描字符。',
    );
    expect(numericFractionMethod, contains('writeCharCode(codeUnit)'));
    expect(
      numericFractionMethod,
      isNot(contains('RegExp')),
      reason: '成绩列表滚动路径不应为每个可见成绩重复创建正则。',
    );
    expect(numericFractionMethod, isNot(contains('replaceAll')));
  });

  test('score detail sheet avoids mapped detail rows', () {
    final scorePage = File('lib/pages/score/scorepage.dart').readAsStringSync();
    final showScoreDetailMethod = RegExp(
      r'void _showScoreDetail\(Score score\) \{[\s\S]*?\n  Future<void> _trackScoreDetailSheet',
    ).firstMatch(scorePage)?.group(0);
    final trackScoreDetailMethod = RegExp(
      r'Future<void> _trackScoreDetailSheet\(Future<void> sheet\) async \{[\s\S]*?\n  Future<void> _showSemesterPicker',
    ).firstMatch(scorePage)?.group(0);
    final detailSheetClass = RegExp(
      r'class _ScoreDetailSheet extends StatelessWidget \{[\s\S]*?\nclass _DetailRow',
    ).firstMatch(scorePage)?.group(0);

    expect(showScoreDetailMethod, isNotNull);
    expect(showScoreDetailMethod, contains('_isScoreDetailOpen = true;'));
    expect(
      showScoreDetailMethod,
      contains('unawaited(_trackScoreDetailSheet(sheet));'),
      reason: '成绩详情弹层关闭后的打开标记清理应集中到 async helper。',
    );
    expect(
      showScoreDetailMethod,
      isNot(contains('sheet.whenComplete')),
      reason: '成绩详情弹层打开标记不应通过 whenComplete 回调链清理。',
    );
    expect(trackScoreDetailMethod, isNotNull);
    expect(trackScoreDetailMethod, contains('try {'));
    expect(trackScoreDetailMethod, contains('await sheet;'));
    expect(trackScoreDetailMethod, contains('} finally {'));
    expect(
      trackScoreDetailMethod,
      contains('_isScoreDetailOpen = false;'),
      reason: '成绩详情弹层无论正常关闭还是异常完成，都必须释放打开标记。',
    );
    expect(trackScoreDetailMethod, isNot(contains('.whenComplete(')));

    expect(detailSheetClass, isNotNull);
    expect(
      detailSheetClass,
      contains('for (final item in detailItems)'),
      reason: '成绩详情弹层应直接构建详情行，避免 map iterable 在弹层 build 中产生临时对象。',
    );
    expect(detailSheetClass, isNot(contains('detailItems.map')));
    expect(detailSheetClass, isNot(contains('.toList()')));
  });

  test('score semester picker avoids prebuilding option records', () {
    final scorePage = File('lib/pages/score/scorepage.dart').readAsStringSync();
    final formatSemesterLabelMethod = RegExp(
      r'String _formatSemesterLabel\(String value\) \{[\s\S]*?\n  String _compactSemesterLabel',
    ).firstMatch(scorePage)?.group(0);
    final compactSemesterLabelMethod = RegExp(
      r'String _compactSemesterLabel\(String value\) \{[\s\S]*?\n  \(\{String startYear, String endYear, String term\}\)\? _parseSemesterLabelParts',
    ).firstMatch(scorePage)?.group(0);
    final parseSemesterLabelPartsMethod = RegExp(
      r'\(\{String startYear, String endYear, String term\}\)\?\n_parseSemesterLabelPartsStatic\(String value\) \{[\s\S]*?\n\nclass ScorePage',
    ).firstMatch(scorePage)?.group(0);
    final pickerClass = RegExp(
      r'class _SemesterPickerSheet extends StatelessWidget \{[\s\S]*?\nclass _SemesterOptionTile',
    ).firstMatch(scorePage)?.group(0);

    expect(formatSemesterLabelMethod, isNotNull);
    expect(
      formatSemesterLabelMethod,
      contains('final parts = _parseSemesterLabelParts(value);'),
    );
    expect(formatSemesterLabelMethod, isNot(contains('.split(')));
    expect(compactSemesterLabelMethod, isNotNull);
    expect(
      compactSemesterLabelMethod,
      contains('final parts = _parseSemesterLabelParts(value);'),
    );
    expect(compactSemesterLabelMethod, contains("return '全部学期';"));
    expect(compactSemesterLabelMethod, isNot(contains('.split(')));
    expect(parseSemesterLabelPartsMethod, isNotNull);
    expect(
      parseSemesterLabelPartsMethod,
      contains('for (var index = 0; index < value.length; index++)'),
      reason: '成绩学期标签会在标题和选择弹层中重复格式化，应扫描分隔符，避免 split 产生临时列表。',
    );
    expect(
      parseSemesterLabelPartsMethod,
      contains('value.codeUnitAt(index) != 0x2D'),
    );
    expect(parseSemesterLabelPartsMethod, contains('var firstDash = -1;'));
    expect(parseSemesterLabelPartsMethod, contains('var secondDash = -1;'));
    expect(parseSemesterLabelPartsMethod, isNot(contains('.split(')));

    expect(pickerClass, isNotNull);
    expect(
      pickerClass,
      contains('final itemCount = semesterIds.length + 1;'),
      reason: '成绩学期选择弹层应按数量计算高度，不应先生成全部选项记录。',
    );
    expect(pickerClass, contains('itemCount: itemCount'));
    expect(
      pickerClass,
      contains("index == 0 ? 'all' : semesterIds[index - 1]"),
    );
    expect(pickerClass, contains('formatSemesterLabel(itemId)'));
    expect(
      pickerClass,
      contains('addRepaintBoundaries: false'),
      reason: '成绩学期选择弹层是短选项列表，不应为每个选项额外创建 repaint boundary。',
    );
    expect(
      pickerClass,
      isNot(contains('semesterIds.map')),
      reason: '成绩学期选择弹层不应打开时预先 map 全部学期项。',
    );
    expect(pickerClass, isNot(contains('final items =')));
  });

  test('score semester probing does not overwrite cached summary', () {
    final scorePage = File('lib/pages/score/scorepage.dart').readAsStringSync();
    final loadMethod = RegExp(
      r'Future<ScoreLoadResult> _loadScoreForSemester[\s\S]*?\n  Future<ScoreLoadResult> _loadAndCacheScoreForSemester',
    ).firstMatch(scorePage)?.group(0);
    final cacheMethod = RegExp(
      r'Future<ScoreLoadResult> _loadAndCacheScoreForSemester[\s\S]*?\n  @visibleForTesting',
    ).firstMatch(scorePage)?.group(0);
    final probeKeepMethod = RegExp(
      r'Future<bool> _probeSemesterKeep\(String id, \{int maxRetries = 2\}\) async \{[\s\S]*?\n  Future<List<String>> _probeSemesters',
    ).firstMatch(scorePage)?.group(0);
    final probeMethod = RegExp(
      r'Future<void> _probeAvailableSemesters\(List<String> semesterIds\) async \{[\s\S]*?\n  Future<void> getTimeList',
    ).firstMatch(scorePage)?.group(0);

    expect(loadMethod, isNotNull);
    expect(
      loadMethod,
      contains('_loadAndCacheScoreForSemester('),
      reason: '成绩加载缓存写入应集中到可检查 mounted 的 helper。',
    );
    expect(
      loadMethod,
      isNot(contains('.then((scoreData)')),
      reason: '成绩加载不应通过未检查 mounted 的 then 回调写入页面缓存。',
    );

    expect(cacheMethod, isNotNull);
    expect(
      cacheMethod,
      contains('if (mounted)'),
      reason: '成绩页卸载后，旧请求结果不应继续写入页面缓存。',
    );
    expect(cacheMethod, contains('_scoreCache[semesterId] = scoreData;'));

    // 旧的串行整体回退（_filterSemestersWithScores + return semesterIds）已删除，
    // 改为并发 _probeSemesterKeep 叶子节点：每次探测用 persistSummary: false，
    // 单学期异常重试到 maxRetries 后保留（return true），不冒泡、不清空列表。
    expect(
      scorePage,
      isNot(contains('_filterSemestersWithScores')),
      reason: '旧串行探测方法应已被并发管线替换。',
    );
    expect(probeKeepMethod, isNotNull);
    expect(
      probeKeepMethod,
      contains('persistSummary: false'),
      reason: '后台探测各学期是否有成绩时不应覆盖“我的”页使用的绩点/学分摘要缓存。',
    );
    expect(
      probeKeepMethod,
      contains('try {'),
      reason: '后台学期探测由 unawaited 触发，单个学期加载异常不应冒泡成未处理异步错误。',
    );
    expect(probeKeepMethod, contains('catch (error, stackTrace)'));
    expect(
      probeKeepMethod,
      contains(
        "AppLogger.error(\n          'Failed to probe score data for semester \$id (attempt \$attempt)'",
      ),
    );
    expect(
      probeKeepMethod,
      contains('if (attempt == maxRetries) return true;'),
      reason: '重试耗尽时应保留该学期，避免异常导致学期入口被清空。',
    );
    expect(
      probeKeepMethod,
      contains('if (!mounted) return true;'),
      reason: '后台学期探测在页面关闭后应停止继续重试。',
    );

    expect(probeMethod, isNotNull);
    expect(
      probeMethod,
      contains('listEquals(semesterId, filteredSemesterIds)'),
      reason: '后台学期探测结果和当前列表一致时不应通知成绩内容区域重建。',
    );
    expect(
      probeMethod!.indexOf('listEquals(semesterId, filteredSemesterIds)'),
      lessThan(probeMethod.indexOf('_syncScoreContentState();')),
      reason: '成绩页同值学期列表短路必须早于内容状态通知。',
    );
    expect(
      probeMethod,
      contains(
        "final cachedAllScoreData = shouldResetSelection ? _scoreCache['all'] : null;",
      ),
      reason: '后台探测需要重置到全部学期时，应先复用已缓存的全部成绩，避免拆成两次重建。',
    );
    expect(
      probeMethod,
      contains("_assignScoreData(cachedAllScoreData, semesterId: 'all');"),
      reason: '命中全部成绩缓存时，应一次性写入学期列表、选中项和成绩数据后再通知内容区域。',
    );
    expect(
      probeMethod,
      contains('_syncScoreContentState();'),
      reason: '后台探测需要更新成绩内容时应走内容局部 notifier。',
    );
    expect(
      probeMethod,
      isNot(contains('setState(')),
      reason: '后台学期探测不应重建整页成绩 Scaffold。',
    );
    expect(
      probeMethod,
      contains("if (!mounted || selectedId != 'all')"),
      reason: '等待全部成绩期间如果用户切换到其他学期，后台探测不应再覆盖用户选择。',
    );
  });

  test('drink login command keeps captcha state per page instance', () {
    final command =
        File('lib/pages/drink/login/command.dart').readAsStringSync();
    final loginView =
        File('lib/pages/drink/login/view.dart').readAsStringSync();
    final smsLoginView =
        File('lib/pages/drink/login/loginpart2.dart').readAsStringSync();
    final resetMethod = RegExp(
      r'void _reset\(\) \{[\s\S]*?\n  Future<Uint8List> getImageCaptcha',
    ).firstMatch(command)?.group(0);
    final captchaMethod = RegExp(
      r'Future<Uint8List> getImageCaptcha\(\) \{[\s\S]*?\n  void to2Login',
    ).firstMatch(command)?.group(0);
    final captchaRunnerMethod = RegExp(
      r'Future<Uint8List> _runImageCaptchaLoad\(\{[\s\S]*?\n  Future<Uint8List> _loadImageCaptcha',
    ).firstMatch(command)?.group(0);
    final loadCaptchaMethod = RegExp(
      r'Future<Uint8List> _loadImageCaptcha\(\{[\s\S]*?\n  void to2Login',
    ).firstMatch(command)?.group(0);
    final toSmsLoginMethod = RegExp(
      r'void to2Login\(BuildContext context, String phoneNumber, String imageCode\) \{[\s\S]*?\n  Future<void> sendMessageCode',
    ).firstMatch(command)?.group(0);
    final sendMessageCodeMethod = RegExp(
      r'Future<void> sendMessageCode\([\s\S]*?\n  Future<void> _sendMessageCode',
    ).firstMatch(command)?.group(0);
    final messageCodeRunnerMethod = RegExp(
      r'Future<void> _runMessageCodeSend\([\s\S]*?\n  Future<void> _sendMessageCode',
    ).firstMatch(command)?.group(0);
    final loginMethod = RegExp(
      r'Future<void> login\(String phoneNumber, String code, BuildContext context\) \{[\s\S]*?\n  Future<void> _login',
    ).firstMatch(command)?.group(0);
    final loginRunnerMethod = RegExp(
      r'Future<void> _runLoginSubmit\([\s\S]*?\n  Future<void> _login',
    ).firstMatch(command)?.group(0);
    final captchaBuilderSection = RegExp(
      r'EnhancedFutureBuilder\([\s\S]*?\n              \),',
    ).firstMatch(loginView)?.group(0);
    final pageLoadCaptchaMethod = RegExp(
      r'Future<Uint8List> _loadCaptcha\(\) async \{[\s\S]*?\n  void _refreshCaptcha',
    ).firstMatch(loginView)?.group(0);
    final refreshCaptchaMethod = RegExp(
      r'void _refreshCaptcha\(\) \{[\s\S]*?\n  Future<void> _sendMessageCode',
    ).firstMatch(loginView)?.group(0);
    final firstStepLoginState = RegExp(
      r'class _DrinkLoginPageState extends State<DrinkLoginPage> \{[\s\S]*?\n\}',
    ).firstMatch(loginView)?.group(0);
    final setSendingMethod = RegExp(
      r'void _setSending\(bool isSending\) \{[\s\S]*?\n  \}',
    ).firstMatch(loginView)?.group(0);
    final smsLoginState = RegExp(
      r'class _DrinkLoginPage2State extends State<DrinkLoginPage2> \{[\s\S]*?\n\}',
    ).firstMatch(smsLoginView)?.group(0);

    expect(
      command,
      isNot(contains('factory DrinkLoginCommand()')),
      reason: '验证码随机数、时间戳和首帧状态不应通过单例在多个登录页之间共享。',
    );
    expect(
      command,
      isNot(contains('static final DrinkLoginCommand _instance')),
      reason: '饮水登录命令应是页面级实例，避免页面销毁或刷新污染其他流程。',
    );
    expect(command, contains('int _captchaGeneration = 0;'));
    expect(resetMethod, isNotNull);
    expect(
      resetMethod,
      contains('_captchaGeneration++;'),
      reason: '刷新或释放饮水登录命令时应让旧验证码请求失效。',
    );
    expect(captchaMethod, isNotNull);
    expect(
      captchaMethod,
      contains('final captchaGeneration = _captchaGeneration;'),
      reason: '验证码请求发出时应捕获 generation，避免旧请求覆盖刷新后的状态。',
    );
    expect(
      captchaMethod,
      contains('_runImageCaptchaLoad('),
      reason: '验证码加载应通过 try/finally helper 统一清理 in-flight 状态。',
    );
    expect(captchaMethod, contains('final inFlight = _captchaLoad;'));
    expect(captchaMethod, contains('return inFlight;'));
    expect(captchaMethod, isNot(contains('.then(')));
    expect(captchaMethod, isNot(contains('.whenComplete(')));
    expect(captchaRunnerMethod, isNotNull);
    expect(captchaRunnerMethod, contains('try {'));
    expect(captchaRunnerMethod, contains('return await _loadImageCaptcha('));
    expect(captchaRunnerMethod, contains('} finally {'));
    expect(
      captchaRunnerMethod,
      contains('if (identical(_captchaLoad, currentLoad()))'),
      reason: '只有当前仍是同一批验证码 Future 时，才允许清空验证码加载标记。',
    );
    expect(captchaRunnerMethod, contains('_captchaLoad = null;'));
    expect(captchaRunnerMethod, isNot(contains('.whenComplete(')));
    expect(loadCaptchaMethod, isNotNull);
    expect(
      loadCaptchaMethod,
      contains('if (captchaGeneration == _captchaGeneration)'),
      reason: '旧验证码请求返回后不应把新一轮验证码状态标记为已消费。',
    );
    expect(toSmsLoginMethod, isNotNull);
    expect(
      toSmsLoginMethod,
      contains('command: this,'),
      reason: '短信验证页应复用第一步登录命令，避免验证码上下文、防重状态和测试注入断开。',
    );
    expect(sendMessageCodeMethod, isNotNull);
    expect(
      sendMessageCodeMethod,
      contains('final inFlight = _messageCodeSend;'),
    );
    expect(sendMessageCodeMethod, contains('return inFlight;'));
    expect(sendMessageCodeMethod, contains('_runMessageCodeSend('));
    expect(sendMessageCodeMethod, isNot(contains('.whenComplete(')));
    expect(messageCodeRunnerMethod, isNotNull);
    expect(messageCodeRunnerMethod, contains('try {'));
    expect(messageCodeRunnerMethod, contains('await _sendMessageCode('));
    expect(messageCodeRunnerMethod, contains('} finally {'));
    expect(
      messageCodeRunnerMethod,
      contains('if (identical(_messageCodeSend, currentSend()))'),
      reason: '短信验证码请求完成后只应清理当前批次的发送 Future。',
    );
    expect(messageCodeRunnerMethod, contains('_messageCodeSend = null;'));
    expect(messageCodeRunnerMethod, isNot(contains('.whenComplete(')));
    expect(loginMethod, isNotNull);
    expect(loginMethod, contains('final inFlight = _loginSubmit;'));
    expect(loginMethod, contains('return inFlight;'));
    expect(loginMethod, contains('_runLoginSubmit('));
    expect(loginMethod, isNot(contains('.whenComplete(')));
    expect(loginRunnerMethod, isNotNull);
    expect(loginRunnerMethod, contains('try {'));
    expect(loginRunnerMethod, contains('await _login('));
    expect(loginRunnerMethod, contains('} finally {'));
    expect(
      loginRunnerMethod,
      contains('if (identical(_loginSubmit, currentSubmit()))'),
      reason: '短信登录提交完成后只应清理当前批次的提交 Future。',
    );
    expect(loginRunnerMethod, contains('_loginSubmit = null;'));
    expect(loginRunnerMethod, isNot(contains('.whenComplete(')));
    expect(captchaBuilderSection, isNotNull);
    expect(
      captchaBuilderSection,
      contains('future: captchaFuture'),
      reason: '饮水登录页应使用页面持有的验证码 Future，避免 build 期间重复请求。',
    );
    expect(
      captchaBuilderSection,
      contains('rememberFutureResult: false'),
      reason:
          '验证码刷新时应使用新的 _captchaFuture，不应让 EnhancedFutureBuilder 缓存旧 Future。',
    );
    expect(
      captchaBuilderSection,
      contains('whenError:'),
      reason: '验证码加载失败应显示受控重试占位，不能回退到一直 loading 或展示异常。',
    );
    expect(pageLoadCaptchaMethod, isNotNull);
    expect(pageLoadCaptchaMethod, contains('_isCaptchaLoading = true;'));
    expect(pageLoadCaptchaMethod, contains('try {'));
    expect(
      pageLoadCaptchaMethod,
      contains('return await _command.getImageCaptcha();'),
      reason: '饮水登录页应继续通过页面持有的验证码 Future 加载图片。',
    );
    expect(pageLoadCaptchaMethod, contains('} finally {'));
    expect(pageLoadCaptchaMethod, contains('_isCaptchaLoading = false;'));
    expect(
      pageLoadCaptchaMethod,
      isNot(contains('.whenComplete(')),
      reason: '验证码 loading 标记清理应走 try/finally，避免回调链里分散页面状态。',
    );
    expect(refreshCaptchaMethod, isNotNull);
    expect(
      refreshCaptchaMethod,
      contains('_captchaFutureNotifier.value = _loadCaptcha();'),
      reason: '刷新验证码只应通知验证码区域，不应重建整页登录表单。',
    );
    expect(
      refreshCaptchaMethod,
      isNot(contains('setState(')),
      reason: '刷新验证码不应触发整页 setState。',
    );
    expect(loginView, contains("isLoading ? '正在加载验证码' : '验证码加载失败，点击重试'"));

    expect(firstStepLoginState, isNotNull);
    expect(
      firstStepLoginState,
      contains(
        'late final ValueNotifier<Future<Uint8List>> _captchaFutureNotifier;',
      ),
      reason: '饮水登录验证码 Future 应由局部 notifier 持有，刷新时只重建验证码图块。',
    );
    expect(
      firstStepLoginState,
      contains('ValueNotifier<Future<Uint8List>>(_loadCaptcha())'),
    );
    expect(firstStepLoginState, contains('_captchaFutureNotifier.dispose();'));
    expect(
      firstStepLoginState,
      contains('valueListenable: _captchaFutureNotifier'),
    );
    expect(
      firstStepLoginState,
      contains(
        'final ValueNotifier<bool> _isSending = ValueNotifier<bool>(false);',
      ),
      reason: '饮水登录首步发送验证码 pending 态只影响发送按钮，不应 setState 重建整页。',
    );
    expect(firstStepLoginState, contains('_isSending.dispose();'));
    expect(firstStepLoginState, contains('if (_isSending.value)'));
    expect(
      firstStepLoginState,
      contains('valueListenable: _isSending'),
      reason: '发送验证码按钮应通过 ValueListenableBuilder 局部刷新 loading/禁用状态。',
    );
    expect(setSendingMethod, isNotNull);
    expect(
      setSendingMethod,
      contains('!mounted || _isSending.value == isSending'),
      reason: '发送态不变或页面已卸载时不应通知按钮重建。',
    );
    expect(
      setSendingMethod,
      isNot(contains('setState(')),
      reason: '发送验证码 pending 态应局部刷新，不应整页 setState。',
    );
    expect(
      firstStepLoginState,
      isNot(contains('setState(')),
      reason: '饮水登录首步的验证码刷新和发送态都应局部通知，不应整页 setState。',
    );

    expect(smsLoginState, isNotNull);
    expect(
      smsLoginState,
      contains(
        'final ValueNotifier<bool> _isSubmitting = ValueNotifier<bool>(false);',
      ),
      reason: '短信登录提交态只影响提交按钮，不应 setState 重建整页短信验证内容。',
    );
    expect(
      smsLoginState,
      contains(
        'final ValueNotifier<bool> _isReturningForCode = ValueNotifier<bool>(false);',
      ),
      reason: '返回重取验证码的 pending 态只影响返回按钮，不应 setState 重建整页。',
    );
    expect(smsLoginState, contains('_isSubmitting.dispose();'));
    expect(smsLoginState, contains('_isReturningForCode.dispose();'));
    expect(smsLoginState, contains('if (_isSubmitting.value)'));
    expect(smsLoginState, contains('if (_isReturningForCode.value)'));
    expect(
      smsLoginState,
      contains('!mounted || _isSubmitting.value == isSubmitting'),
      reason: '短信提交态不变或页面已卸载时不应通知按钮重建。',
    );
    expect(
      smsLoginState,
      contains('!mounted || _isReturningForCode.value == isReturningForCode'),
      reason: '返回验证码 pending 态不变或页面已卸载时不应通知按钮重建。',
    );
    expect(smsLoginState, contains('valueListenable: _isSubmitting'));
    expect(smsLoginState, contains('valueListenable: _isReturningForCode'));
    expect(
      smsLoginState,
      isNot(contains('setState(')),
      reason: '短信验证页按钮 pending 态应局部刷新，不应整页 setState。',
    );
  });

  test('drink device refresh drops late results after close', () {
    final drinkApi =
        File('lib/pages/drink/api/drink_api.dart').readAsStringSync();
    final drinkView = File('lib/pages/drink/view/view.dart').readAsStringSync();
    final drinkWidgets =
        File(
          'lib/pages/drink/view/widgets/drink_page_widgets.dart',
        ).readAsStringSync();
    final logic = File('lib/pages/drink/view/logic.dart').readAsStringSync();
    final initTokenMethod = RegExp(
      r'Future<void> _initToken\(\) async \{[\s\S]*?\n  \}\n\n  /// 获取慧生活798登录验证码',
    ).firstMatch(drinkApi)?.group(0);
    final deviceListMethod = RegExp(
      r'Future<List<Map>> deviceList\(\) async \{[\s\S]*?\n  /// 收藏或取消收藏设备',
    ).firstMatch(drinkApi)?.group(0);
    final showDeviceSelectionMethod = RegExp(
      r'void _showDeviceSelectionDialog\(\) \{[\s\S]*?\n  Future<void> _confirmDeleteDevice',
    ).firstMatch(drinkView)?.group(0);
    final trackDeviceSelectionMethod = RegExp(
      r'Future<void> _trackDeviceSelectionSheet\(Future<void> sheet\) async \{[\s\S]*?\n  Future<void> _confirmDeleteDevice',
    ).firstMatch(drinkView)?.group(0);
    final showDeviceManagementMethod = RegExp(
      r'void _showDeviceManagementSheet\(\) \{[\s\S]*?\n  Future<bool> _scanQRCodeAndAddDevice',
    ).firstMatch(drinkView)?.group(0);
    final trackDeviceManagementMethod = RegExp(
      r'Future<void> _trackDeviceManagementSheet\(Future<void> sheet\) async \{[\s\S]*?\n  Future<bool> _scanQRCodeAndAddDevice',
    ).firstMatch(drinkView)?.group(0);
    final scanQrCodeAndAddDeviceMethod = RegExp(
      r'Future<bool> _scanQRCodeAndAddDevice\(\) async \{[\s\S]*?\n  String _deviceCodeFromQrResult',
    ).firstMatch(drinkView)?.group(0);
    final deviceCodeFromQrResultMethod = RegExp(
      r'String _deviceCodeFromQrResult\(String result\) \{[\s\S]*?\n  Future<String\?> _openQrScanner',
    ).firstMatch(drinkView)?.group(0);
    final deviceSelectionSheetClass = RegExp(
      r'class DrinkDeviceSelectionSheet extends StatelessWidget \{[\s\S]*?\nclass DrinkDeviceManagementSheet',
    ).firstMatch(drinkWidgets)?.group(0);
    final deviceManagementSheetClass = RegExp(
      r'class DrinkDeviceManagementSheet extends StatelessWidget \{[\s\S]*?\nclass DrinkQrCodeScannerPage',
    ).firstMatch(drinkWidgets)?.group(0);
    final qrScannerPageClass = RegExp(
      r'class DrinkQrCodeScannerPage extends StatefulWidget \{[\s\S]*?\nclass _DrinkScannerActionButton',
    ).firstMatch(drinkWidgets)?.group(0);
    final checkLoginMethod = RegExp(
      r'Future<bool> checkLogin\(\) async \{[\s\S]*?\n  /// 获取喝水设备列表',
    ).firstMatch(logic)?.group(0);
    final getDeviceListMethod = RegExp(
      r'Future<void> getDeviceList\(\{[\s\S]*?\n  Future<void> _loadDeviceList',
    ).firstMatch(logic)?.group(0);
    final loadDeviceListMethod = RegExp(
      r'Future<void> _loadDeviceList\(\{[\s\S]*?\n  /// 收藏或取消收藏设备',
    ).firstMatch(logic)?.group(0);
    final formatDeviceNameMethod = RegExp(
      r'String formatDeviceName\(String name\) \{[\s\S]*?\n  /// 改变选中的设备值',
    ).firstMatch(logic)?.group(0);
    final selectedDeviceMethod = RegExp(
      r'String\? _selectedDeviceId\(\) \{[\s\S]*?\n  void _scheduleDeviceStatusPolling',
    ).firstMatch(logic)?.group(0);
    final startDrinkMethod = RegExp(
      r'Future<void> startDrink\(\) async \{[\s\S]*?\n  /// 结束喝水',
    ).firstMatch(logic)?.group(0);
    final endDrinkMethod = RegExp(
      r'Future<void> endDrink\(\) async \{[\s\S]*?\n  /// 删除相对应的device',
    ).firstMatch(logic)?.group(0);
    final removeDeviceMethod = RegExp(
      r'void removeDeviceByName\(String name\) \{[\s\S]*?\n  /// 设置token',
    ).firstMatch(logic)?.group(0);

    expect(initTokenMethod, isNotNull);
    expect(
      initTokenMethod,
      contains('for (final entry in map.entries)'),
      reason: '饮水 token 本地初始化在启动路径执行，应直接遍历 entries，避免 forEach 闭包分配。',
    );
    expect(initTokenMethod, contains('_token[entry.key] = entry.value;'));
    expect(initTokenMethod, isNot(contains('.forEach(')));

    expect(checkLoginMethod, isNotNull);
    expect(
      checkLoginMethod,
      contains('if (_isDisposed)'),
      reason: '饮水页关闭后不应继续登录检查或触发后续 token 请求。',
    );
    expect(
      checkLoginMethod,
      contains('return !_isDisposed;'),
      reason: '设备列表加载期间页面关闭时，初始化流程不应继续读取 token。',
    );

    expect(getDeviceListMethod, isNotNull);
    expect(
      getDeviceListMethod,
      contains('if (_isDisposed)'),
      reason: '饮水页关闭后不应再创建新的设备列表请求。',
    );

    expect(loadDeviceListMethod, isNotNull);
    expect(
      loadDeviceListMethod,
      contains('if (_isDisposed)'),
      reason: '饮水设备列表旧请求完成后应先检查页面是否已关闭。',
    );
    expect(
      loadDeviceListMethod,
      contains('final List<Map> value = await drinkApi.deviceList();'),
    );
    expect(
      loadDeviceListMethod!.indexOf('if (_isDisposed)'),
      lessThan(loadDeviceListMethod.indexOf('drinkApi.deviceList()')),
      reason: '发起设备列表请求前应先丢弃已关闭页面的刷新入口。',
    );
    expect(
      loadDeviceListMethod.indexOf(
        'if (_isDisposed)',
        loadDeviceListMethod.indexOf('drinkApi.deviceList()'),
      ),
      isNot(-1),
      reason: '设备列表请求返回后应再次丢弃关闭页面的旧结果。',
    );
    expect(
      loadDeviceListMethod,
      contains('if (!_isDisposed)'),
      reason: 'finally 和错误提示在页面关闭后不应继续 update 或弹提示。',
    );

    expect(selectedDeviceMethod, isNotNull);
    expect(
      selectedDeviceMethod,
      contains('selectedIndex < 0 || selectedIndex >= state.deviceList.length'),
      reason: '饮水开始/结束前应显式检查选中设备下标，避免用 RangeError 兜底控制流。',
    );
    expect(
      selectedDeviceMethod,
      contains('final device = state.deviceList[selectedIndex];'),
    );
    expect(selectedDeviceMethod, contains('if (device is! Map)'));
    expect(
      selectedDeviceMethod,
      contains("final id = device['id']?.toString();"),
    );
    expect(selectedDeviceMethod, contains('id == null || id.isEmpty'));

    expect(startDrinkMethod, isNotNull);
    expect(startDrinkMethod, contains('final deviceId = _selectedDeviceId();'));
    expect(startDrinkMethod, contains('if (deviceId == null)'));
    expect(
      startDrinkMethod,
      isNot(contains('state.deviceList[state.choiceDevice.value]')),
      reason: '饮水启动不应直接索引过期选中设备。',
    );

    expect(endDrinkMethod, isNotNull);
    expect(endDrinkMethod, contains('final deviceId = _selectedDeviceId();'));
    expect(endDrinkMethod, contains('if (deviceId == null)'));
    expect(
      endDrinkMethod,
      isNot(contains('state.deviceList[state.choiceDevice.value]')),
      reason: '饮水结算不应直接索引过期选中设备。',
    );

    expect(deviceListMethod, isNotNull);
    expect(
      deviceListMethod,
      contains('final devices = <Map>[];'),
      reason: '饮水设备刷新解析应一次构造结果列表，避免 map/toList/reversed/toList 链式临时对象。',
    );
    expect(
      deviceListMethod,
      contains('for (var index = favos.length - 1; index >= 0; index--)'),
      reason: '设备列表仍需保持原来的反向显示顺序，但应通过一次反向循环完成。',
    );
    expect(deviceListMethod, contains('return devices;'));
    expect(deviceListMethod, isNot(contains('.map(')));
    expect(deviceListMethod, isNot(contains('.reversed')));
    expect(deviceListMethod, isNot(contains('.toList()')));

    expect(formatDeviceNameMethod, isNotNull);
    expect(formatDeviceNameMethod, contains('StringBuffer? buffer;'));
    expect(
      formatDeviceNameMethod,
      contains('for (var index = 0; index < name.length; index++)'),
      reason: '饮水设备名格式化会在列表和卡片 build 路径多次调用，应扫描字符并懒创建输出缓冲。',
    );
    expect(
      formatDeviceNameMethod,
      contains('name.codeUnitAt(index) == 0x680B'),
    );
    expect(
      formatDeviceNameMethod,
      contains('if (buffer == null) {\n      return name;\n    }'),
      reason: '无“栋”的设备名应直接返回原字符串，避免无变化时仍生成新字符串。',
    );
    expect(formatDeviceNameMethod, isNot(contains('replaceAll')));

    expect(removeDeviceMethod, isNotNull);
    expect(
      removeDeviceMethod,
      contains('var writeIndex = 0;'),
      reason: '饮水设备删除应原地压缩列表，避免 removeWhere 闭包。',
    );
    expect(
      removeDeviceMethod,
      contains('for (var index = 0; index < state.deviceList.length; index++)'),
    );
    expect(
      removeDeviceMethod,
      contains(
        'state.deviceList.removeRange(writeIndex, state.deviceList.length)',
      ),
    );
    expect(removeDeviceMethod, isNot(contains('removeWhere')));

    expect(showDeviceSelectionMethod, isNotNull);
    expect(
      showDeviceSelectionMethod,
      contains('_isDeviceSelectionSheetOpen = true;'),
    );
    expect(
      showDeviceSelectionMethod,
      contains('final devices = logic.state.deviceList;'),
      reason: '饮水设备选择弹层应直接复用响应式设备列表，避免 Obx 重建时复制整表。',
    );
    expect(
      showDeviceSelectionMethod,
      contains('final deviceCount = devices.length;'),
    );
    expect(showDeviceSelectionMethod, contains('deviceCount: deviceCount,'));
    expect(
      showDeviceSelectionMethod,
      isNot(contains('List<dynamic>.from(logic.state.deviceList)')),
    );
    expect(
      showDeviceSelectionMethod,
      contains('unawaited(_trackDeviceSelectionSheet(sheet));'),
      reason: '设备选择弹层关闭后的打开标记清理应集中到 async helper。',
    );
    expect(
      showDeviceSelectionMethod,
      isNot(contains('sheet.whenComplete')),
      reason: '设备选择弹层打开标记不应通过 whenComplete 回调链清理。',
    );
    expect(trackDeviceSelectionMethod, isNotNull);
    expect(trackDeviceSelectionMethod, contains('try {'));
    expect(trackDeviceSelectionMethod, contains('await sheet;'));
    expect(trackDeviceSelectionMethod, contains('} finally {'));
    expect(
      trackDeviceSelectionMethod,
      contains('_isDeviceSelectionSheetOpen = false;'),
      reason: '设备选择弹层无论正常关闭还是异常完成，都必须释放打开标记。',
    );
    expect(trackDeviceSelectionMethod, isNot(contains('.whenComplete(')));

    expect(showDeviceManagementMethod, isNotNull);
    expect(
      showDeviceManagementMethod,
      contains('_isDeviceManagementSheetOpen = true;'),
    );
    expect(
      showDeviceManagementMethod,
      contains('final devices = logic.state.deviceList;'),
      reason: '饮水设备管理弹层应直接复用响应式设备列表，避免 Obx 重建时复制整表。',
    );
    expect(
      showDeviceManagementMethod,
      contains('final deviceCount = devices.length;'),
    );
    expect(showDeviceManagementMethod, contains('deviceCount: deviceCount,'));
    expect(showDeviceManagementMethod, contains('index >= deviceCount'));
    expect(
      showDeviceManagementMethod,
      contains('final device = devices[index] as Map;'),
    );
    expect(
      showDeviceManagementMethod,
      isNot(contains('List<dynamic>.from(logic.state.deviceList)')),
    );
    expect(
      showDeviceManagementMethod,
      isNot(contains('Map<String, dynamic>.from(')),
    );
    expect(
      showDeviceManagementMethod,
      contains('unawaited(_trackDeviceManagementSheet(sheet));'),
      reason: '设备管理弹层关闭后的打开标记清理应集中到 async helper。',
    );
    expect(
      showDeviceManagementMethod,
      isNot(contains('sheet.whenComplete')),
      reason: '设备管理弹层打开标记不应通过 whenComplete 回调链清理。',
    );
    expect(trackDeviceManagementMethod, isNotNull);
    expect(trackDeviceManagementMethod, contains('try {'));
    expect(trackDeviceManagementMethod, contains('await sheet;'));
    expect(trackDeviceManagementMethod, contains('} finally {'));
    expect(
      trackDeviceManagementMethod,
      contains('_isDeviceManagementSheetOpen = false;'),
      reason: '设备管理弹层无论正常关闭还是异常完成，都必须释放打开标记。',
    );
    expect(trackDeviceManagementMethod, isNot(contains('.whenComplete(')));

    expect(scanQrCodeAndAddDeviceMethod, isNotNull);
    expect(
      scanQrCodeAndAddDeviceMethod,
      contains('final String enc = _deviceCodeFromQrResult(result);'),
      reason: '扫码添加设备应集中提取设备码，避免在异步流程中散落字符串处理。',
    );
    expect(scanQrCodeAndAddDeviceMethod, isNot(contains(".split('/')")));
    expect(deviceCodeFromQrResultMethod, isNotNull);
    expect(
      deviceCodeFromQrResultMethod,
      contains("final slashIndex = result.lastIndexOf('/');"),
      reason: '二维码结果通常是 URL，应从尾部定位最后一个斜杠，避免 split 物化所有路径段。',
    );
    expect(deviceCodeFromQrResultMethod, contains('return result;'));
    expect(
      deviceCodeFromQrResultMethod,
      contains('return result.substring(slashIndex + 1);'),
    );
    expect(deviceCodeFromQrResultMethod, isNot(contains('.split(')));

    expect(qrScannerPageClass, isNotNull);
    expect(
      qrScannerPageClass,
      contains('bool _isTogglingFlash = false;'),
      reason: '饮水扫码页闪光灯切换应防重复，避免快速连点堆叠相机命令。',
    );
    expect(
      qrScannerPageClass,
      contains(
        'final ValueNotifier<bool> _isFlashOnNotifier = ValueNotifier<bool>(false);',
      ),
      reason: '饮水扫码页闪光灯图标只应局部刷新，避免重建 QRView。',
    );
    expect(
      qrScannerPageClass,
      contains('_isFlashOnNotifier.dispose();'),
      reason: '闪光灯局部状态应随扫码页释放。',
    );
    expect(qrScannerPageClass, contains('ValueListenableBuilder<bool>'));
    expect(qrScannerPageClass, contains('valueListenable: _isFlashOnNotifier'));
    expect(qrScannerPageClass, contains('Future<void> _toggleFlash() async'));
    expect(qrScannerPageClass, contains('if (_isTogglingFlash)'));
    expect(qrScannerPageClass, contains('_isTogglingFlash = true;'));
    expect(qrScannerPageClass, contains('await controller.toggleFlash();'));
    expect(
      qrScannerPageClass,
      contains('final current = await controller.getFlashStatus() ?? false;'),
      reason: '闪光灯按钮状态应以相机返回的真实状态为准。',
    );
    expect(
      qrScannerPageClass,
      contains('if (!mounted || _isFlashOnNotifier.value == current)'),
      reason: '页面销毁或闪光灯状态未变化时不应触发局部 rebuild。',
    );
    expect(qrScannerPageClass, contains('_isFlashOnNotifier.value = current;'));
    expect(
      qrScannerPageClass,
      isNot(contains('setState(')),
      reason: '闪光灯图标变化不应 setState 重建饮水扫码页相机视图。',
    );
    expect(qrScannerPageClass, contains('_isTogglingFlash = false;'));
    expect(qrScannerPageClass, contains('onTap: _toggleFlash'));
    expect(qrScannerPageClass, contains('_isScanning = false;'));
    expect(
      qrScannerPageClass,
      contains('Navigator.of(context).pop(code);'),
      reason: '扫码成功后页面会立即返回结果。',
    );
    final qrScannerPageText = qrScannerPageClass!;
    final qrScanSuccessIndex = qrScannerPageText.indexOf(
      '_isScanning = false;',
    );
    final qrScanPopIndex = qrScannerPageText.indexOf(
      'Navigator.of(context).pop(code);',
    );
    final qrScanSetStateIndex = qrScannerPageText.indexOf(
      'setState(()',
      qrScanSuccessIndex,
    );
    expect(qrScanSuccessIndex, isNot(-1));
    expect(qrScanPopIndex, greaterThan(qrScanSuccessIndex));
    expect(
      qrScanSetStateIndex == -1 || qrScanSetStateIndex > qrScanPopIndex,
      isTrue,
      reason: '扫码成功只需本地标志防重复处理，不应在即将 pop 的路径里重建扫码页。',
    );
    expect(
      qrScannerPageClass,
      isNot(contains('_isFlashOn = !_isFlashOn')),
      reason: '不应乐观翻转本地状态，否则可能与真实相机状态不一致。',
    );

    expect(deviceSelectionSheetClass, isNotNull);
    expect(deviceSelectionSheetClass, contains('required this.deviceCount'));
    expect(deviceSelectionSheetClass, contains('final int deviceCount;'));
    expect(
      deviceSelectionSheetClass,
      contains('final listHeight = min(maxListHeight, deviceCount * 92.0);'),
    );
    expect(deviceSelectionSheetClass, contains("badge: '\$deviceCount 台'"));
    expect(deviceSelectionSheetClass, contains('if (deviceCount == 0)'));
    expect(deviceSelectionSheetClass, contains('itemCount: deviceCount'));
    expect(
      deviceSelectionSheetClass,
      contains('addRepaintBoundaries: false'),
      reason: '饮水设备选择弹层是小型静态列表，不应为每个设备项自动创建 repaint 边界。',
    );
    expect(
      deviceSelectionSheetClass,
      contains('final device = devices[index] as Map;'),
    );
    expect(
      deviceSelectionSheetClass,
      isNot(contains('Map<String, dynamic>.from(')),
    );

    expect(deviceManagementSheetClass, isNotNull);
    expect(deviceManagementSheetClass, contains('required this.deviceCount'));
    expect(deviceManagementSheetClass, contains('final int deviceCount;'));
    expect(
      deviceManagementSheetClass,
      contains('final listHeight = min(maxListHeight, deviceCount * 92.0);'),
    );
    expect(deviceManagementSheetClass, contains("badge: '\$deviceCount 台'"));
    expect(deviceManagementSheetClass, contains('if (deviceCount == 0)'));
    expect(deviceManagementSheetClass, contains('itemCount: deviceCount'));
    expect(
      deviceManagementSheetClass,
      contains('addRepaintBoundaries: false'),
      reason: '饮水设备管理弹层是小型静态列表，不应为每个设备项自动创建 repaint 边界。',
    );
    expect(
      deviceManagementSheetClass,
      contains('final device = devices[index] as Map;'),
    );
    expect(
      deviceManagementSheetClass,
      isNot(contains('Map<String, dynamic>.from(')),
    );
  });

  test('hut auth id generators avoid mapped iterable chains', () {
    final hutAuthApi =
        File(
          'lib/utils/hut_user_api/hut_user_api_auth.dart',
        ).readAsStringSync();
    final deviceIdMethod = RegExp(
      r'String generateDeviceIdAlphabet\(\) \{[\s\S]*?\n  String generateUuidV4',
    ).firstMatch(hutAuthApi)?.group(0);
    final uuidMethod = RegExp(
      r'String generateUuidV4\(\) \{[\s\S]*?\n  String generateJSessionId',
    ).firstMatch(hutAuthApi)?.group(0);
    final jSessionIdMethod = RegExp(
      r'String generateJSessionId\(\) \{[\s\S]*?\n  String _hexBytes',
    ).firstMatch(hutAuthApi)?.group(0);
    final hexBytesMethod = RegExp(
      r'String _hexBytes\(Uint8List bytes, String digits\) \{[\s\S]*?\n  Future<String> getFingerprint',
    ).firstMatch(hutAuthApi)?.group(0);

    expect(
      hutAuthApi,
      contains("static const _hexLowerDigits = '0123456789abcdef';"),
    );
    expect(
      hutAuthApi,
      contains("static const _hexUpperDigits = '0123456789ABCDEF';"),
    );

    expect(deviceIdMethod, isNotNull);
    expect(deviceIdMethod, contains('final buffer = StringBuffer();'));
    expect(
      deviceIdMethod,
      contains('for (var index = 0; index < 24; index++)'),
      reason: '设备 ID 固定长度生成应使用显式循环，避免 List.generate 闭包。',
    );
    expect(
      deviceIdMethod,
      contains('buffer.write(chars[random.nextInt(chars.length)]);'),
    );
    expect(deviceIdMethod, contains('return buffer.toString();'));
    expect(deviceIdMethod, isNot(contains('List.generate')));
    expect(deviceIdMethod, isNot(contains('.join(')));

    expect(uuidMethod, isNotNull);
    expect(uuidMethod, contains('final bytes = Uint8List(16);'));
    expect(
      uuidMethod,
      contains('for (var index = 0; index < bytes.length; index++)'),
    );
    expect(uuidMethod, contains('bytes[6] = (bytes[6] & 0x0F) | 0x40;'));
    expect(uuidMethod, contains('bytes[8] = (bytes[8] & 0x3F) | 0x80;'));
    expect(uuidMethod, contains('return _hexBytes(bytes, _hexLowerDigits);'));
    expect(uuidMethod, isNot(contains('List<int>.generate')));
    expect(uuidMethod, isNot(contains('.map(')));
    expect(uuidMethod, isNot(contains('toRadixString')));

    expect(jSessionIdMethod, isNotNull);
    expect(jSessionIdMethod, contains('final bytes = Uint8List(16);'));
    expect(
      jSessionIdMethod,
      contains('return _hexBytes(bytes, _hexUpperDigits);'),
    );
    expect(jSessionIdMethod, isNot(contains('.map(')));
    expect(jSessionIdMethod, isNot(contains('toRadixString')));

    expect(hexBytesMethod, isNotNull);
    expect(hexBytesMethod, contains('final buffer = StringBuffer();'));
    expect(hexBytesMethod, contains('final byte = bytes[index];'));
    expect(hexBytesMethod, contains('write(digits[byte >> 4])'));
    expect(hexBytesMethod, contains('write(digits[byte & 0x0F])'));
    expect(hexBytesMethod, isNot(contains('toRadixString')));
  });

  test('hut jwt payload decoding avoids split segment lists', () {
    final hutSupportApi =
        File(
          'lib/utils/hut_user_api/hut_user_api_support.dart',
        ).readAsStringSync();
    final decodePayloadMethod = RegExp(
      r'Map<String, dynamic>\? decodeHutJwtPayload\(String token\) \{[\s\S]*?\n\}',
    ).firstMatch(hutSupportApi)?.group(0);

    expect(decodePayloadMethod, isNotNull);
    expect(decodePayloadMethod, contains('final trimmedToken = token.trim();'));
    expect(
      decodePayloadMethod,
      contains("final headerEnd = trimmedToken.indexOf('.');"),
    );
    expect(
      decodePayloadMethod,
      contains("final payloadEnd = trimmedToken.indexOf('.', payloadStart);"),
    );
    expect(
      decodePayloadMethod,
      contains('trimmedToken.substring('),
      reason: 'JWT payload 解析只需要中间段，应扫描点号边界，避免 split 物化所有段。',
    );
    expect(decodePayloadMethod, isNot(contains('.split(')));
  });

  test('hut portal URL normalization avoids query forEach closures', () {
    final hutSupportApi =
        File(
          'lib/utils/hut_user_api/hut_user_api_support.dart',
        ).readAsStringSync();
    final normalizeMethod = RegExp(
      r'String normalizeHutPortalUrl\(String url\) \{[\s\S]*?\n\}\n\nString _replaceLegacyPortalIndexPath',
    ).firstMatch(hutSupportApi)?.group(0);

    expect(normalizeMethod, isNotNull);
    expect(
      normalizeMethod,
      contains('for (final entry in uri.queryParameters.entries)'),
      reason: '门户 URL 规范化只需扫描 query entries，避免 forEach 闭包。',
    );
    expect(normalizeMethod, contains('final value = entry.value;'));
    expect(
      normalizeMethod,
      contains('normalizedQueryParameters[entry.key] = normalizedValue;'),
    );
    expect(normalizeMethod, isNot(contains('.forEach(')));
  });

  test('hut url log description avoids parsed query and fragment lists', () {
    final hutSupportApi =
        File(
          'lib/utils/hut_user_api/hut_user_api_support.dart',
        ).readAsStringSync();
    final sortedQueryKeysMethod = RegExp(
      r'List<String> _sortedHutUrlQueryKeys\(String query\) \{[\s\S]*?\n\}\n\nString describeHutUrlForLog',
    ).firstMatch(hutSupportApi)?.group(0);
    final describeMethod = RegExp(
      r'String describeHutUrlForLog\(String url\) \{[\s\S]*?\n\}\n\n/// Utility',
    ).firstMatch(hutSupportApi)?.group(0);

    expect(sortedQueryKeysMethod, isNotNull);
    expect(sortedQueryKeysMethod, contains('final keys = <String>[];'));
    expect(sortedQueryKeysMethod, contains('final seenKeys = <String>{};'));
    expect(
      sortedQueryKeysMethod,
      contains('for (var index = 0; index <= query.length; index++)'),
    );
    expect(
      sortedQueryKeysMethod,
      contains('query.codeUnitAt(index) == 0x26'),
      reason: 'WebView URL 日志只需要 query key，应扫描 & 分隔段，避免解析并保存 query 值。',
    );
    expect(
      sortedQueryKeysMethod,
      contains('Uri.decodeQueryComponent(query.substring(keyStart, keyEnd))'),
    );
    expect(sortedQueryKeysMethod, contains('keys.sort();'));
    expect(sortedQueryKeysMethod, isNot(contains('queryParameters')));
    expect(sortedQueryKeysMethod, isNot(contains('.toList(')));
    expect(sortedQueryKeysMethod, isNot(contains('.split(')));

    expect(describeMethod, isNotNull);
    expect(
      describeMethod,
      contains('final keys = _sortedHutUrlQueryKeys(uri.query);'),
    );
    expect(
      describeMethod,
      contains("final queryStart = uri.fragment.indexOf('?');"),
    );
    expect(
      describeMethod,
      contains('uri.fragment.substring(0, queryStart)'),
      reason: 'WebView URL 日志只需要 fragment 路径，应扫描问号位置，避免 split 物化片段列表。',
    );
    expect(describeMethod, isNot(contains('queryParameters')));
    expect(describeMethod, isNot(contains('.toList(')));
    expect(describeMethod, isNot(contains(".split('?')")));
  });

  test('hot water refresh drops late results after close', () {
    final logic = File('lib/pages/water/logic.dart').readAsStringSync();
    final hutWaterApi =
        File(
          'lib/utils/hut_user_api/hut_user_api_water.dart',
        ).readAsStringSync();
    final hutSessionApi =
        File(
          'lib/utils/hut_user_api/hut_user_api_session.dart',
        ).readAsStringSync();
    final waterView = File('lib/pages/water/view.dart').readAsStringSync();
    final waterWidgets =
        File(
          'lib/pages/water/widgets/water_page_widgets.dart',
        ).readAsStringSync();
    final checkLoginMethod = RegExp(
      r'Future<void> checkLogin\(\) async \{[\s\S]*?\n  void _queueLoginRedirect',
    ).firstMatch(logic)?.group(0);
    final getDeviceListMethod = RegExp(
      r'Future<void> getDeviceList\(\) async \{[\s\S]*?\n  Future<void> _loadDeviceList',
    ).firstMatch(logic)?.group(0);
    final loadDeviceListMethod = RegExp(
      r'Future<void> _loadDeviceList\(\) async \{[\s\S]*?\n  /// 获取余额',
    ).firstMatch(logic)?.group(0);
    final applyDeviceListMethod = RegExp(
      r'Future<void> _applyDeviceList\(Map<String, dynamic> value\) async \{[\s\S]*?\n  /// 获取喝水设备列表',
    ).firstMatch(logic)?.group(0);
    final openDeviceMethod = RegExp(
      r'Future<void> _refreshOpenDeviceState\(\) async \{[\s\S]*?\n  /// 改变选中的设备值',
    ).firstMatch(logic)?.group(0);
    final applyOpenDeviceStateMethod = RegExp(
      r'void _applyOpenDeviceState\(List value\) \{[\s\S]*?\n  /// 改变选中的设备值',
    ).firstMatch(logic)?.group(0);
    final hotWaterDeviceMethod = RegExp(
      r'Future<Map<String, dynamic>> getHotWaterDevice\(\) async \{[\s\S]*?\n  Future<List> checkHotWaterDevice',
    ).firstMatch(hutWaterApi)?.group(0);
    final hotWaterBalanceMethod = RegExp(
      r'Future<String> getCardBalance\(\) async \{[\s\S]*?\n  \}\n\}',
    ).firstMatch(hutWaterApi)?.group(0);
    final openIdMethod = RegExp(
      r'Future<List<String>> getOpenid\(\) async \{[\s\S]*?\n  @override',
    ).firstMatch(hutSessionApi)?.group(0);
    final extractJSessionIdMethod = RegExp(
      r'String _extractJSessionId\(List<String> setCookieHeader\) \{[\s\S]*?\n\}',
    ).firstMatch(hutSessionApi)?.group(0);
    final extractOpenIdFromLocationMethod = RegExp(
      r'String _extractOpenIdFromLocation\(String location\) \{[\s\S]*?\n\}',
    ).firstMatch(hutSessionApi)?.group(0);
    final showWaterDeviceSelectionMethod = RegExp(
      r'void _showDeviceSelectionDialog\(\) \{[\s\S]*?\n  Future<void> _confirmDeleteDevice',
    ).firstMatch(waterView)?.group(0);
    final trackWaterDeviceSelectionMethod = RegExp(
      r'Future<void> _trackWaterDeviceSelectionSheet\(Future<void> sheet\) async \{[\s\S]*?\n  Future<void> _confirmDeleteDevice',
    ).firstMatch(waterView)?.group(0);
    final showWaterDeviceManagementMethod = RegExp(
      r'void _showDeviceManagementDialog\(\) \{[\s\S]*?\n  void _showAddDevicePage',
    ).firstMatch(waterView)?.group(0);
    final trackWaterDeviceManagementMethod = RegExp(
      r'Future<void> _trackWaterDeviceManagementSheet\(Future<void> sheet\) async \{[\s\S]*?\n  void _showAddDevicePage',
    ).firstMatch(waterView)?.group(0);
    final showAddDeviceMethod = RegExp(
      r'void _showAddDevicePage\(\) \{[\s\S]*?\n  @override\n  void dispose',
    ).firstMatch(waterView)?.group(0);
    final trackAddWaterDeviceMethod = RegExp(
      r'Future<void> _trackAddWaterDeviceSheet\(Future<void> sheet\) async \{[\s\S]*?\n  @override\n  void dispose',
    ).firstMatch(waterView)?.group(0);
    final waterDeviceSelectionSheetClass = RegExp(
      r'class WaterDeviceSelectionSheet extends StatelessWidget \{[\s\S]*?\nclass WaterDeviceManagementSheet',
    ).firstMatch(waterWidgets)?.group(0);
    final waterDeviceManagementSheetClass = RegExp(
      r'class WaterDeviceManagementSheet extends StatelessWidget \{[\s\S]*?\nclass AddWaterDeviceSheet',
    ).firstMatch(waterWidgets)?.group(0);
    final addWaterDeviceSheetClass = RegExp(
      r'class AddWaterDeviceSheet extends StatefulWidget \{[\s\S]*?\nclass _AddWaterDeviceSheetState',
    ).firstMatch(waterWidgets)?.group(0);
    final addWaterDeviceSheetState = RegExp(
      r'class _AddWaterDeviceSheetState extends State<AddWaterDeviceSheet> \{[\s\S]*?\nclass WaterBottomSheetScaffold',
    ).firstMatch(waterWidgets)?.group(0);

    expect(logic, contains('bool _isDisposed = false;'));
    expect(logic, contains('_isDisposed = true;'));
    expect(
      logic,
      contains('_balanceRefreshGeneration++;'),
      reason: '热水页关闭时应让正在返回的余额刷新失效。',
    );

    expect(checkLoginMethod, isNotNull);
    expect(
      checkLoginMethod,
      contains('if (_isDisposed)'),
      reason: '热水页关闭后不应继续登录检查或排登录跳转。',
    );

    expect(getDeviceListMethod, isNotNull);
    expect(
      getDeviceListMethod,
      contains('if (_isDisposed)'),
      reason: '热水页关闭后不应再创建新的设备列表请求。',
    );

    expect(loadDeviceListMethod, isNotNull);
    expect(
      loadDeviceListMethod,
      contains('var value = await hutUserApi.getHotWaterDevice();'),
    );
    expect(
      loadDeviceListMethod!.indexOf('if (_isDisposed)'),
      lessThan(loadDeviceListMethod.indexOf('getHotWaterDevice()')),
      reason: '发起热水设备列表请求前应先丢弃已关闭页面的刷新入口。',
    );
    expect(
      loadDeviceListMethod.indexOf(
        'if (_isDisposed)',
        loadDeviceListMethod.indexOf('getHotWaterDevice()'),
      ),
      isNot(-1),
      reason: '热水设备列表请求返回后应再次丢弃关闭页面的旧结果。',
    );

    expect(applyDeviceListMethod, isNotNull);
    expect(
      applyDeviceListMethod,
      contains('if (_isDisposed)'),
      reason: '热水设备列表应用前后都应检查页面是否已关闭。',
    );
    expect(
      applyDeviceListMethod,
      contains(
        'await Future.wait([_refreshOpenDeviceState(), _refreshBalanceValue()]);',
      ),
    );

    expect(openDeviceMethod, isNotNull);
    expect(
      openDeviceMethod,
      contains('if (_isDisposed)'),
      reason: '未关热水设备检查返回后不应在关闭页面上改状态或弹提示。',
    );
    expect(
      openDeviceMethod,
      contains('if (!_isDisposed)'),
      reason: '未关设备检查 finally 不应在页面关闭后继续写完成态。',
    );
    expect(
      openDeviceMethod,
      contains('_applyOpenDeviceState(value);'),
      reason: '未关设备状态应用应集中处理空列表和未知设备，避免状态残留。',
    );
    expect(
      openDeviceMethod,
      isNot(contains('state.choiceDevice.value = state.deviceList.indexWhere')),
      reason: '未关设备匹配失败时不应把 choiceDevice 直接写成 -1 并留下旧运行态。',
    );

    expect(applyOpenDeviceStateMethod, isNotNull);
    expect(applyOpenDeviceStateMethod, contains('if (value.isEmpty)'));
    expect(
      applyOpenDeviceStateMethod,
      contains('state.waterStatus.value = false;'),
      reason: '未关设备列表为空或无法匹配本地设备时应清掉旧运行态。',
    );
    expect(
      applyOpenDeviceStateMethod,
      contains('final deviceIndex = state.deviceList.indexWhere'),
    );
    expect(applyOpenDeviceStateMethod, contains('if (deviceIndex == -1)'));
    expect(
      applyOpenDeviceStateMethod,
      contains('_assignChoiceDevice(deviceIndex);'),
      reason: '匹配到运行中设备时应复用选择写入短路，避免同值通知。',
    );

    expect(hotWaterDeviceMethod, isNotNull);
    expect(
      hotWaterDeviceMethod,
      contains("final rawDevices = data['resultData']['data'];"),
      reason: '热水设备列表解析应一次反向循环构造结果，避免 reversed/toList 链式临时对象。',
    );
    expect(hotWaterDeviceMethod, contains('final devices = <dynamic>[];'));
    expect(hotWaterDeviceMethod, contains('if (rawDevices is List)'));
    expect(
      hotWaterDeviceMethod,
      contains('for (var index = rawDevices.length - 1; index >= 0; index--)'),
    );
    expect(hotWaterDeviceMethod, contains('devices.add(rawDevices[index]);'));
    expect(hotWaterDeviceMethod, contains("'data': devices"));
    expect(hotWaterDeviceMethod, isNot(contains('.reversed')));
    expect(hotWaterDeviceMethod, isNot(contains('.toList()')));
    expect(
      hutWaterApi,
      isNot(contains('.then((value)')),
      reason: '热水底层 API 包装应使用 async/await 直线控制流，避免额外回调链和分散状态处理。',
    );

    expect(hotWaterBalanceMethod, isNotNull);
    expect(
      hotWaterBalanceMethod,
      contains("for (final element in doc.getElementsByTagName('span'))"),
      reason: '热水余额解析只需要第一个余额 span，不应先过滤并物化列表。',
    );
    expect(
      hotWaterBalanceMethod,
      contains("element.attributes['name'] == 'showbalanceid'"),
    );
    expect(
      hotWaterBalanceMethod,
      contains("return element.text.replaceAll('主钱包余额:￥', '');"),
    );
    expect(hotWaterBalanceMethod, isNot(contains('.where(')));
    expect(hotWaterBalanceMethod, isNot(contains('.toList()')));

    expect(openIdMethod, isNotNull);
    expect(openIdMethod, contains('final response = await _request.get('));
    expect(
      openIdMethod,
      contains('final jSessionId = _extractJSessionId(setCookieHeader);'),
      reason: 'JSESSIONID 提取应集中扫描 cookie 头，避免 split/replaceFirst 链式临时字符串。',
    );
    expect(
      openIdMethod,
      contains('final openid = _extractOpenIdFromLocation(location);'),
      reason: 'openid 提取应集中处理标准 URI 和兜底跳转地址解析。',
    );
    expect(
      openIdMethod,
      isNot(contains('.then((value)')),
      reason: 'openid 会话初始化属于热水链路前置请求，也应保持 async/await 直线控制流。',
    );
    expect(openIdMethod, isNot(contains('.split(')));
    expect(openIdMethod, isNot(contains('replaceFirst(')));

    expect(extractJSessionIdMethod, isNotNull);
    expect(extractJSessionIdMethod, contains("const prefix = 'JSESSIONID=';"));
    expect(
      extractJSessionIdMethod,
      contains('for (final cookie in setCookieHeader)'),
    );
    expect(extractJSessionIdMethod, contains('cookie.startsWith(prefix)'));
    expect(
      extractJSessionIdMethod,
      contains("final endIndex = cookie.indexOf(';', prefix.length);"),
    );
    expect(extractJSessionIdMethod, contains('cookie.substring('));
    expect(extractJSessionIdMethod, isNot(contains('.split(')));
    expect(extractJSessionIdMethod, isNot(contains('replaceFirst(')));

    expect(extractOpenIdFromLocationMethod, isNotNull);
    expect(
      extractOpenIdFromLocationMethod,
      contains("Uri.tryParse(location)?.queryParameters['openid']"),
    );
    expect(
      extractOpenIdFromLocationMethod,
      contains("final startIndex = location.indexOf(parameter);"),
    );
    expect(
      extractOpenIdFromLocationMethod,
      contains('while (valueEnd < location.length)'),
    );
    expect(
      extractOpenIdFromLocationMethod,
      contains('location.codeUnitAt(valueEnd)'),
    );
    expect(
      extractOpenIdFromLocationMethod,
      contains('return location.substring(valueStart, valueEnd);'),
    );
    expect(extractOpenIdFromLocationMethod, isNot(contains('.split(')));

    expect(showWaterDeviceSelectionMethod, isNotNull);
    expect(
      showWaterDeviceSelectionMethod,
      contains('_isDeviceSelectionSheetOpen = true;'),
    );
    expect(
      showWaterDeviceSelectionMethod,
      contains('final devices = logic.state.deviceList;'),
      reason: '热水设备选择弹层应直接复用响应式设备列表，避免 Obx 重建时复制整表。',
    );
    expect(
      showWaterDeviceSelectionMethod,
      contains('final deviceCount = devices.length;'),
    );
    expect(
      showWaterDeviceSelectionMethod,
      contains('deviceCount: deviceCount,'),
    );
    expect(
      showWaterDeviceSelectionMethod,
      isNot(contains('List<dynamic>.from(logic.state.deviceList)')),
    );
    expect(
      showWaterDeviceSelectionMethod,
      contains('unawaited(_trackWaterDeviceSelectionSheet(sheet));'),
      reason: '热水设备选择弹层关闭后的打开标记清理应集中到 async helper。',
    );
    expect(
      showWaterDeviceSelectionMethod,
      isNot(contains('sheet.whenComplete')),
      reason: '热水设备选择弹层打开标记不应通过 whenComplete 回调链清理。',
    );
    expect(trackWaterDeviceSelectionMethod, isNotNull);
    expect(trackWaterDeviceSelectionMethod, contains('try {'));
    expect(trackWaterDeviceSelectionMethod, contains('await sheet;'));
    expect(trackWaterDeviceSelectionMethod, contains('} finally {'));
    expect(
      trackWaterDeviceSelectionMethod,
      contains('_isDeviceSelectionSheetOpen = false;'),
      reason: '热水设备选择弹层无论正常关闭还是异常完成，都必须释放打开标记。',
    );
    expect(trackWaterDeviceSelectionMethod, isNot(contains('.whenComplete(')));

    expect(showWaterDeviceManagementMethod, isNotNull);
    expect(
      showWaterDeviceManagementMethod,
      contains('_isDeviceManagementSheetOpen = true;'),
    );
    expect(
      showWaterDeviceManagementMethod,
      contains('final devices = logic.state.deviceList;'),
      reason: '热水设备管理弹层应直接复用响应式设备列表，避免 Obx 重建时复制整表。',
    );
    expect(
      showWaterDeviceManagementMethod,
      contains('final deviceCount = devices.length;'),
    );
    expect(
      showWaterDeviceManagementMethod,
      contains('deviceCount: deviceCount,'),
    );
    expect(showWaterDeviceManagementMethod, contains('index >= deviceCount'));
    expect(
      showWaterDeviceManagementMethod,
      contains('final device = devices[index] as Map;'),
    );
    expect(
      showWaterDeviceManagementMethod,
      isNot(contains('List<dynamic>.from(logic.state.deviceList)')),
    );
    expect(
      showWaterDeviceManagementMethod,
      isNot(contains('Map<String, dynamic>.from(')),
    );
    expect(
      showWaterDeviceManagementMethod,
      contains('unawaited(_trackWaterDeviceManagementSheet(sheet));'),
      reason: '热水设备管理弹层关闭后的打开标记清理应集中到 async helper。',
    );
    expect(
      showWaterDeviceManagementMethod,
      isNot(contains('sheet.whenComplete')),
      reason: '热水设备管理弹层打开标记不应通过 whenComplete 回调链清理。',
    );
    expect(trackWaterDeviceManagementMethod, isNotNull);
    expect(trackWaterDeviceManagementMethod, contains('try {'));
    expect(trackWaterDeviceManagementMethod, contains('await sheet;'));
    expect(trackWaterDeviceManagementMethod, contains('} finally {'));
    expect(
      trackWaterDeviceManagementMethod,
      contains('_isDeviceManagementSheetOpen = false;'),
      reason: '热水设备管理弹层无论正常关闭还是异常完成，都必须释放打开标记。',
    );
    expect(trackWaterDeviceManagementMethod, isNot(contains('.whenComplete(')));

    expect(waterDeviceSelectionSheetClass, isNotNull);
    expect(
      waterDeviceSelectionSheetClass,
      contains('required this.deviceCount'),
    );
    expect(waterDeviceSelectionSheetClass, contains('final int deviceCount;'));
    expect(
      waterDeviceSelectionSheetClass,
      contains('final listHeight = min(maxListHeight, deviceCount * 64.0);'),
    );
    expect(waterDeviceSelectionSheetClass, contains('if (deviceCount == 0)'));
    expect(waterDeviceSelectionSheetClass, contains('itemCount: deviceCount'));
    expect(
      waterDeviceSelectionSheetClass,
      contains('addRepaintBoundaries: false'),
      reason: '热水设备选择弹层是小型静态列表，不应为每个设备项自动创建 repaint 边界。',
    );
    expect(
      waterDeviceSelectionSheetClass,
      contains('final device = devices[index] as Map;'),
    );
    expect(
      waterDeviceSelectionSheetClass,
      isNot(contains('Map<String, dynamic>.from(')),
    );

    expect(waterDeviceManagementSheetClass, isNotNull);
    expect(
      waterDeviceManagementSheetClass,
      contains('required this.deviceCount'),
    );
    expect(waterDeviceManagementSheetClass, contains('final int deviceCount;'));
    expect(
      waterDeviceManagementSheetClass,
      contains('final listHeight = min(maxListHeight, deviceCount * 72.0);'),
    );
    expect(waterDeviceManagementSheetClass, contains('if (deviceCount == 0)'));
    expect(waterDeviceManagementSheetClass, contains('itemCount: deviceCount'));
    expect(
      waterDeviceManagementSheetClass,
      contains('addRepaintBoundaries: false'),
      reason: '热水设备管理弹层是小型静态列表，不应为每个设备项自动创建 repaint 边界。',
    );
    expect(
      waterDeviceManagementSheetClass,
      contains('final device = devices[index] as Map;'),
    );
    expect(
      waterDeviceManagementSheetClass,
      isNot(contains('Map<String, dynamic>.from(')),
    );

    expect(addWaterDeviceSheetClass, isNotNull);
    expect(
      addWaterDeviceSheetClass,
      contains('final Future<bool> Function(String deviceCode) onSubmit;'),
      reason: '热水添加设备提交结果应显式区分关闭弹层和留在弹层，避免成功关闭前多一次 loading 复位重建。',
    );
    expect(addWaterDeviceSheetState, isNotNull);
    expect(
      addWaterDeviceSheetState,
      contains('var shouldRestoreSubmitting = true;'),
    );
    expect(
      addWaterDeviceSheetState,
      contains(
        'final ValueNotifier<bool> _isSubmitting = ValueNotifier<bool>(false);',
      ),
      reason: '添加设备提交态只影响按钮区域，应使用局部监听而不是整张弹层 setState。',
    );
    expect(addWaterDeviceSheetState, contains('_isSubmitting.dispose();'));
    expect(addWaterDeviceSheetState, contains('if (_isSubmitting.value)'));
    expect(
      addWaterDeviceSheetState,
      contains('void _setSubmitting(bool isSubmitting)'),
    );
    expect(
      addWaterDeviceSheetState,
      contains('!mounted || _isSubmitting.value == isSubmitting'),
      reason: '提交态不变或弹层已卸载时不应通知按钮重建。',
    );
    expect(
      addWaterDeviceSheetState,
      contains('_isSubmitting.value = isSubmitting;'),
    );
    expect(
      addWaterDeviceSheetState,
      contains('final closesSheet = await widget.onSubmit'),
    );
    expect(
      addWaterDeviceSheetState,
      contains('shouldRestoreSubmitting = !closesSheet;'),
    );
    expect(addWaterDeviceSheetState, contains('_setSubmitting(true);'));
    expect(addWaterDeviceSheetState, contains('if (shouldRestoreSubmitting)'));
    expect(addWaterDeviceSheetState, contains('_setSubmitting(false);'));
    expect(
      addWaterDeviceSheetState,
      contains('ValueListenableBuilder<bool>'),
      reason: '提交 loading 切换应只重建按钮区域，输入框和提示说明不应跟着重建。',
    );
    expect(
      addWaterDeviceSheetState,
      contains('valueListenable: _isSubmitting'),
    );
    expect(
      addWaterDeviceSheetState,
      isNot(contains('setState(')),
      reason: '添加设备提交态不应通过整张弹层 setState 更新。',
    );
    expect(showAddDeviceMethod, isNotNull);
    expect(showAddDeviceMethod, contains('_isAddDeviceSheetOpen = true;'));
    expect(
      showAddDeviceMethod,
      contains('return false;'),
      reason: '输入为空、添加失败或页面已关闭时，添加设备 sheet 应恢复提交按钮。',
    );
    expect(
      showAddDeviceMethod,
      contains('return true;'),
      reason: '添加成功并关闭 sheet 时，不应再在关闭前复位 loading。',
    );
    expect(
      showAddDeviceMethod!.indexOf('Navigator.of(sheetContext).pop();'),
      lessThan(showAddDeviceMethod.indexOf('return true;')),
      reason: '成功路径应先关闭添加设备 sheet，再告诉子组件无需恢复 loading。',
    );
    expect(
      showAddDeviceMethod,
      contains('unawaited(_trackAddWaterDeviceSheet(sheet));'),
      reason: '热水添加设备弹层关闭后的打开标记清理应集中到 async helper。',
    );
    expect(
      showAddDeviceMethod,
      isNot(contains('sheet.whenComplete')),
      reason: '热水添加设备弹层打开标记不应通过 whenComplete 回调链清理。',
    );
    expect(trackAddWaterDeviceMethod, isNotNull);
    expect(trackAddWaterDeviceMethod, contains('try {'));
    expect(trackAddWaterDeviceMethod, contains('await sheet;'));
    expect(trackAddWaterDeviceMethod, contains('} finally {'));
    expect(
      trackAddWaterDeviceMethod,
      contains('_isAddDeviceSheetOpen = false;'),
      reason: '热水添加设备弹层无论正常关闭还是异常完成，都必须释放打开标记。',
    );
    expect(trackAddWaterDeviceMethod, isNot(contains('.whenComplete(')));
  });

  test('hot water operation failures use stable user messages', () {
    final logic = File('lib/pages/water/logic.dart').readAsStringSync();
    final startWaterMethod = RegExp(
      r'Future<void> startWater\(\) async \{[\s\S]*?\n  /// 结束洗澡',
    ).firstMatch(logic)?.group(0);
    final addDeviceMethod = RegExp(
      r'Future<bool> _addDevice\(String deviceCode\) async \{[\s\S]*?\n  /// 删除热水设备',
    ).firstMatch(logic)?.group(0);
    final deleteDeviceMethod = RegExp(
      r'Future<bool> _deleteDevice\(String deviceCode\) async \{[\s\S]*?\n  \}\n\}',
    ).firstMatch(logic)?.group(0);

    expect(
      logic,
      contains("const String hotWaterStartFailureMessage = '设备开启失败，请稍后重试';"),
    );
    expect(
      logic,
      contains(
        "const String hotWaterAddDeviceFailureMessage = '添加设备失败，请稍后重试';",
      ),
    );
    expect(
      logic,
      contains(
        "const String hotWaterDeleteDeviceFailureMessage = '删除设备失败，请稍后重试';",
      ),
    );

    expect(startWaterMethod, isNotNull);
    expect(startWaterMethod, contains('hotWaterStartFailureMessage'));
    expect(startWaterMethod, isNot(contains("value['message']")));

    expect(addDeviceMethod, isNotNull);
    expect(addDeviceMethod, contains('hotWaterAddDeviceFailureMessage'));
    expect(addDeviceMethod, isNot(contains("value['msg']")));

    expect(deleteDeviceMethod, isNotNull);
    expect(deleteDeviceMethod, contains('hotWaterDeleteDeviceFailureMessage'));
    expect(deleteDeviceMethod, isNot(contains("value['msg']")));
  });

  test('home electricity alert short-circuits before creating api', () {
    final homeView = File('lib/home/homeview/view.dart').readAsStringSync();
    final checkAlertMethod = RegExp(
      r'Future<void> checkAlert[\s\S]*?\n  void _showAlert',
    ).firstMatch(homeView)?.group(0);

    expect(checkAlertMethod, isNotNull);
    expect(
      checkAlertMethod,
      isNot(contains('ElectricityApi()')),
      reason: '首页启动预警应先读取本地开关，未启用时不创建电费 API 或走网络初始化。',
    );
    expect(
      homeView,
      contains('class HomeElectricityAlertChecker'),
      reason: '首页电费预警检查应拆出可测试的轻量检查器。',
    );
  });

  test('home update version read avoids shell rebuild', () {
    final homeView = File('lib/home/homeview/view.dart').readAsStringSync();
    final getCurrentVersionMethod = RegExp(
      r'Future<void> _getCurrentVersion\(\) async \{[\s\S]*?\n  Future<void> _runStartupDialogs',
    ).firstMatch(homeView)?.group(0);
    final checkVersionMethod = RegExp(
      r'Future<void> _checkVersion\(\) async \{[\s\S]*?\n  Future<void> _showUpdateDialog',
    ).firstMatch(homeView)?.group(0);

    expect(getCurrentVersionMethod, isNotNull);
    expect(
      getCurrentVersionMethod,
      contains('_currentVersion = packageInfo.version;'),
      reason: '当前版本号只用于后续更新检查参数，不参与渲染，不应触发首页 shell rebuild。',
    );
    expect(getCurrentVersionMethod, isNot(contains('setState(()')));

    expect(checkVersionMethod, isNotNull);
    expect(
      checkVersionMethod,
      contains('fetchUpdate(currentVersion: _currentVersion)'),
      reason: '更新检查仍应使用读取到的当前版本号。',
    );
  });

  test('course table primary action loading stays local to the button', () {
    final courseTable =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final handlePrimaryActionMethod = RegExp(
      r'Future<void> _handlePrimaryAction\(\) async \{[\s\S]*?\n  Future<void> _switchToSchedule',
    ).firstMatch(courseTable)?.group(0);
    final emptyStateMethod = RegExp(
      r'Widget _buildEmptyState\(BuildContext context\) \{[\s\S]*?\n  Widget _buildPreparingState',
    ).firstMatch(courseTable)?.group(0);

    expect(handlePrimaryActionMethod, isNotNull);
    expect(
      handlePrimaryActionMethod,
      contains('_isPrimaryActionLoadingNotifier.value'),
      reason: '课表页主操作 loading 应通过局部 notifier 防止重复点击。',
    );
    expect(
      handlePrimaryActionMethod,
      contains('_isPrimaryActionLoadingNotifier.value = true;'),
    );
    expect(
      handlePrimaryActionMethod,
      contains('_isPrimaryActionLoadingNotifier.value = false;'),
    );
    expect(
      handlePrimaryActionMethod,
      isNot(contains('setState(()')),
      reason: '课表页主操作 loading 不应触发整页重建。',
    );

    expect(emptyStateMethod, isNotNull);
    expect(
      emptyStateMethod,
      contains('ValueListenableBuilder<bool>'),
      reason: '课表页空状态主按钮应只监听局部 loading 状态。',
    );
    expect(
      emptyStateMethod,
      contains('valueListenable: _isPrimaryActionLoadingNotifier'),
    );
    expect(
      emptyStateMethod,
      matches(
        RegExp(
          r'isPrimaryActionLoading\s*\?\s*null\s*:\s*_handlePrimaryAction',
        ),
      ),
    );
  });

  test('about page skips unchanged version rebuild', () {
    final aboutView = File('lib/home/about/view.dart').readAsStringSync();
    final loadVersionMethod = RegExp(
      r'Future<void> _loadVersion\(\) async \{[\s\S]*?\n  void _applyVersionIfChanged',
    ).firstMatch(aboutView)?.group(0);
    final applyVersionMethod = RegExp(
      r'void _applyVersionIfChanged\(String version\) \{[\s\S]*?\n  Future<void> _openUrl',
    ).firstMatch(aboutView)?.group(0);
    final setCheckingUpdateMethod = RegExp(
      r'void _setCheckingUpdate\(bool isCheckingUpdate\) \{[\s\S]*?\n  void _showMessage',
    ).firstMatch(aboutView)?.group(0);
    final buildMethod = RegExp(
      r'Widget build\(BuildContext context\) \{[\s\S]*?\n  Widget _buildPageBackground',
    ).firstMatch(aboutView)?.group(0);

    expect(
      aboutView,
      contains('final ValueNotifier<_AboutHeroState> _heroState'),
      reason: '关于页版本和更新检查状态只影响 hero 卡，不应重建整页 ListView。',
    );
    expect(aboutView, contains('_heroState.dispose();'));
    expect(aboutView, contains('class _AboutHeroState'));
    expect(aboutView, contains("this.version = '--'"));
    expect(aboutView, contains('this.isCheckingUpdate = false'));
    expect(aboutView, contains('_AboutHeroState copyWith('));
    expect(loadVersionMethod, isNotNull);
    expect(
      loadVersionMethod,
      contains('_applyVersionIfChanged(version);'),
      reason: '关于页版本号参与渲染，应通过 helper 按需提交状态。',
    );
    expect(
      loadVersionMethod,
      contains('catch (error, stackTrace)'),
      reason: '关于页初始化版本读取失败不应冒泡成页面异常。',
    );
    expect(
      loadVersionMethod,
      isNot(contains('setState(()')),
      reason: '版本读取完成不应无条件重建关于页。',
    );

    expect(applyVersionMethod, isNotNull);
    expect(
      applyVersionMethod,
      contains('final currentState = _heroState.value;'),
      reason: '版本号更新应基于 hero 局部状态判断是否需要通知。',
    );
    expect(
      applyVersionMethod,
      contains('!mounted || currentState.version == version'),
      reason: '页面销毁后或版本号未变化时不应触发 hero 通知。',
    );
    expect(
      applyVersionMethod,
      contains('_heroState.value = currentState.copyWith(version: version);'),
    );
    expect(
      applyVersionMethod,
      isNot(contains('setState(')),
      reason: '版本号只影响 hero 卡，不应 setState 重建整页关于页。',
    );

    expect(setCheckingUpdateMethod, isNotNull);
    expect(
      setCheckingUpdateMethod,
      contains('final currentState = _heroState.value;'),
    );
    expect(
      setCheckingUpdateMethod,
      contains('currentState.isCheckingUpdate == isCheckingUpdate'),
      reason: '检查更新 loading 状态不变时不应通知 hero 按钮重建。',
    );
    expect(
      setCheckingUpdateMethod,
      contains('_heroState.value = currentState.copyWith('),
    );
    expect(
      setCheckingUpdateMethod,
      isNot(contains('setState(')),
      reason: '检查更新按钮 loading 只影响 hero 卡，不应重建整页。',
    );

    expect(buildMethod, isNotNull);
    expect(buildMethod, contains('ValueListenableBuilder<_AboutHeroState>'));
    expect(buildMethod, contains('valueListenable: _heroState'));
    expect(buildMethod, contains('version: heroState.version'));
    expect(
      buildMethod,
      contains('isCheckingUpdate: heroState.isCheckingUpdate'),
    );
    expect(
      buildMethod,
      isNot(contains('RepaintBoundary(')),
      reason: '关于页静态玻璃分段没有独立动画，不应为每个分段额外建 repaint 边界。',
    );
  });

  test('user page skips unchanged profile and score notifications', () {
    final userPage = File('lib/home/userpage/view.dart').readAsStringSync();
    final sameProfileMethod = RegExp(
      r'bool _hasSameProfileValues\([\s\S]*?\n  void _applyProfileIfChanged',
    ).firstMatch(userPage)?.group(0);
    final applyProfileMethod = RegExp(
      r'void _applyProfileIfChanged\(Map<String, String> nextProfile\) \{[\s\S]*?\n  void _applyAccountStateIfChanged',
    ).firstMatch(userPage)?.group(0);
    final applyAccountStateMethod = RegExp(
      r'void _applyAccountStateIfChanged\(bool hasLinkedCampusAccount\) \{[\s\S]*?\n  Future<void> _loadPageData',
    ).firstMatch(userPage)?.group(0);
    final loadPageDataMethod = RegExp(
      r'Future<void> _loadPageData\(\) async \{[\s\S]*?\n  @visibleForTesting',
    ).firstMatch(userPage)?.group(0);
    final reloadProfileMethod = RegExp(
      r'Future<void> _reloadProfileFromPrefs\(\) async \{[\s\S]*?\n  void _applyScoreSummaryIfChanged',
    ).firstMatch(userPage)?.group(0);
    final applyScoreSummaryMethod = RegExp(
      r'void _applyScoreSummaryIfChanged\(ScoreLoadResult scoreData\) \{[\s\S]*?\n  Future<void> _refreshScoreSummaryInBackground',
    ).firstMatch(userPage)?.group(0);
    final refreshScoreSummaryMethod = RegExp(
      r'Future<void> _refreshScoreSummaryInBackground\(\{int\? generation\}\) async \{[\s\S]*?\n  Future<void> _refreshBalance',
    ).firstMatch(userPage)?.group(0);
    final refreshBalanceMethod = RegExp(
      r'Future<void> _refreshBalance\(\{[\s\S]*?\n  Future<void> _launchUrl',
    ).firstMatch(userPage)?.group(0);
    final applyBalanceStateMethod = RegExp(
      r'void _applyBalanceStateIfChanged\(\{String\? value, bool\? isLoading\}\) \{[\s\S]*?\n  Future<void> _loadPageData',
    ).firstMatch(userPage)?.group(0);
    final buildMethod = RegExp(
      r'Widget build\(BuildContext context\) \{[\s\S]*?\n  Widget _buildLoadingShell',
    ).firstMatch(userPage)?.group(0);

    expect(sameProfileMethod, isNotNull);
    expect(
      sameProfileMethod,
      contains('currentProfile.length != nextProfile.length'),
      reason: '完整 profile 比较应先检查字段数量，避免字段缺失时误判相同。',
    );
    expect(
      sameProfileMethod,
      contains('for (final entry in nextProfile.entries)'),
    );
    expect(
      sameProfileMethod,
      contains('currentProfile[entry.key] != entry.value'),
    );

    expect(applyProfileMethod, isNotNull);
    expect(
      applyProfileMethod,
      contains('_hasSameProfileValues(currentProfile, nextProfile)'),
      reason: '我的页本地资料重复读取到相同值时，不应通知 profile 区域重建。',
    );
    expect(applyProfileMethod, contains('return;'));
    expect(
      applyProfileMethod,
      contains('_profileNotifier.value = nextProfile;'),
    );

    expect(applyAccountStateMethod, isNotNull);
    expect(
      applyAccountStateMethod,
      contains('final currentState = _accountStateNotifier.value;'),
      reason: '我的页账号状态应通过局部 notifier 管理，避免整页 setState。',
    );
    expect(applyAccountStateMethod, contains('currentState.isInitialized &&'));
    expect(applyAccountStateMethod, contains('return;'));
    expect(
      applyAccountStateMethod,
      contains('_accountStateNotifier.value = currentState.copyWith('),
    );
    expect(applyAccountStateMethod, contains('isInitialized: true,'));
    expect(
      applyAccountStateMethod,
      contains('hasLinkedCampusAccount: hasLinkedCampusAccount,'),
    );
    expect(
      applyAccountStateMethod,
      isNot(contains('setState(')),
      reason: '我的页账号状态切换不应触发整页重建。',
    );

    expect(
      userPage,
      contains('class _UserPageBalanceState'),
      reason: '我的页余额值和 loading 应合并为单一局部状态，避免嵌套监听重复 rebuild。',
    );
    expect(
      userPage,
      contains(
        'late final ValueNotifier<_UserPageBalanceState> _balanceStateNotifier',
      ),
    );
    expect(userPage, contains('_balanceStateNotifier.dispose();'));
    expect(userPage, isNot(contains('ValueNotifier<String> _balanceNotifier')));
    expect(
      userPage,
      isNot(contains('ValueNotifier<bool> _balanceLoadingNotifier')),
    );

    expect(applyBalanceStateMethod, isNotNull);
    expect(
      applyBalanceStateMethod,
      contains('final currentState = _balanceStateNotifier.value;'),
      reason: '余额卡片状态应集中通过 helper 读取当前值并做同值短路。',
    );
    expect(
      applyBalanceStateMethod,
      contains('final nextState = currentState.copyWith('),
    );
    expect(
      applyBalanceStateMethod,
      contains('currentState.value == nextState.value'),
    );
    expect(
      applyBalanceStateMethod,
      contains('currentState.isLoading == nextState.isLoading'),
    );
    expect(applyBalanceStateMethod, contains('return;'));
    expect(
      applyBalanceStateMethod,
      contains('_balanceStateNotifier.value = nextState;'),
    );
    expect(
      applyBalanceStateMethod,
      isNot(contains('setState(')),
      reason: '余额值/loading 切换只应刷新余额卡片局部区域。',
    );

    expect(loadPageDataMethod, isNotNull);
    expect(loadPageDataMethod, contains('_applyProfileIfChanged(profile);'));
    expect(
      loadPageDataMethod,
      contains('_applyAccountStateIfChanged(hasLinkedCampusAccount);'),
    );
    expect(
      loadPageDataMethod,
      isNot(contains('_profileNotifier.value = profile')),
    );
    expect(
      loadPageDataMethod,
      contains('_applyBalanceStateIfChanged('),
      reason: '首屏余额缓存落地应复用余额状态去重 helper。',
    );
    expect(
      loadPageDataMethod,
      isNot(contains('_balanceStateNotifier.value =')),
      reason: '_loadPageData 不应绕过余额状态 helper 直接通知余额卡片。',
    );
    expect(
      loadPageDataMethod,
      isNot(contains('setState(()')),
      reason: '_loadPageData 应通过账号状态 helper 按需重建，不应无条件 setState。',
    );

    expect(reloadProfileMethod, isNotNull);
    expect(
      reloadProfileMethod,
      contains('_applyProfileIfChanged(nextProfile);'),
      reason: '从成绩页返回后重读本地资料也应复用 profile 去重 helper。',
    );
    expect(
      reloadProfileMethod,
      isNot(contains('_profileNotifier.value = nextProfile')),
    );

    expect(applyScoreSummaryMethod, isNotNull);
    expect(
      applyScoreSummaryMethod,
      contains("currentProfile['yxzxf'] == scoreData.yxzxf"),
      reason: '我的页后台成绩摘要刷新如果数值未变化，不应通知统计卡片重建。',
    );
    expect(
      applyScoreSummaryMethod,
      contains("currentProfile['zxfjd'] == scoreData.zxfjd"),
    );
    expect(
      applyScoreSummaryMethod,
      contains("currentProfile['pjxfjd'] == scoreData.pjxfjd"),
    );
    expect(applyScoreSummaryMethod, contains('return;'));
    expect(applyScoreSummaryMethod, contains('_profileNotifier.value = {'));
    expect(applyScoreSummaryMethod, contains('...currentProfile,'));

    expect(refreshScoreSummaryMethod, isNotNull);
    expect(
      refreshScoreSummaryMethod,
      contains('_applyScoreSummaryIfChanged(scoreData);'),
      reason: '后台成绩摘要刷新应通过去重 helper 落状态。',
    );
    expect(
      refreshScoreSummaryMethod,
      isNot(contains('_profileNotifier.value = {')),
      reason: '异步刷新函数本身不应绕过去重检查直接通知统计卡片。',
    );

    expect(refreshBalanceMethod, isNotNull);
    final refreshBalanceText = refreshBalanceMethod!;
    final balanceValueIndex = refreshBalanceText.indexOf(
      'final value = await (widget.loadBalance ?? hutUserApi.getCardBalance)();',
    );
    final firstGenerationGuardIndex = refreshBalanceText.indexOf(
      'if (!mounted || refreshGeneration != _pageDataGeneration)',
      balanceValueIndex,
    );
    final prefsLoadIndex = refreshBalanceText.indexOf(
      'final prefs = await SharedPreferences.getInstance();',
    );
    final cacheWriteIndex = refreshBalanceText.indexOf(
      'await prefs.setString(_cachedBalanceKey, normalized);',
    );
    final notifierWriteIndex = refreshBalanceText.indexOf(
      '_applyBalanceStateIfChanged(value: normalized);',
    );
    final secondGenerationGuardIndex = refreshBalanceText.indexOf(
      'if (!mounted || refreshGeneration != _pageDataGeneration)',
      prefsLoadIndex,
    );
    final thirdGenerationGuardIndex = refreshBalanceText.indexOf(
      'if (!mounted || refreshGeneration != _pageDataGeneration)',
      cacheWriteIndex,
    );

    expect(balanceValueIndex, isNot(-1));
    expect(firstGenerationGuardIndex, isNot(-1));
    expect(prefsLoadIndex, isNot(-1));
    expect(cacheWriteIndex, isNot(-1));
    expect(notifierWriteIndex, isNot(-1));
    expect(secondGenerationGuardIndex, isNot(-1));
    expect(thirdGenerationGuardIndex, isNot(-1));
    expect(
      refreshBalanceText,
      contains('_applyBalanceStateIfChanged(isLoading: true);'),
      reason: '余额刷新 loading 应走同一个余额状态 notifier。',
    );
    expect(
      refreshBalanceText,
      contains('_applyBalanceStateIfChanged(isLoading: false);'),
      reason: '余额刷新结束也应走同一个余额状态 notifier。',
    );
    expect(
      refreshBalanceText,
      isNot(contains('_balanceStateNotifier.value =')),
      reason: '异步余额刷新函数不应绕过去重 helper 直接通知余额卡片。',
    );
    expect(
      firstGenerationGuardIndex,
      lessThan(prefsLoadIndex),
      reason: '我的页旧余额请求返回后应先丢弃，不能先打开缓存写入路径。',
    );
    expect(
      secondGenerationGuardIndex,
      lessThan(cacheWriteIndex),
      reason: '加载 SharedPreferences 后仍要确认余额刷新 generation 有效，避免旧结果写缓存。',
    );
    expect(
      thirdGenerationGuardIndex,
      lessThan(notifierWriteIndex),
      reason: '缓存写入后页面状态可能变化，通知余额 UI 前应再次确认 generation。',
    );

    expect(buildMethod, isNotNull);
    expect(
      buildMethod,
      contains('ValueListenableBuilder<_UserPageBalanceState>'),
      reason: '余额卡片应由一个局部 builder 同时接收余额值和 loading 状态。',
    );
    expect(buildMethod, contains('valueListenable: _balanceStateNotifier'));
    expect(buildMethod, contains('balanceState.value'));
    expect(buildMethod, contains('isLoading: balanceState.isLoading'));
    expect(
      buildMethod,
      isNot(contains('ValueListenableBuilder<String>')),
      reason: '余额值和 loading 不应拆成嵌套 builder。',
    );
    expect(buildMethod, isNot(contains('ValueListenableBuilder<bool>')));
  });

  test('home bottom nav reuses stable tab widgets', () {
    final homeView = File('lib/home/homeview/view.dart').readAsStringSync();
    final buildMethod = RegExp(
      r'Widget build\(BuildContext context\) \{[\s\S]*?\n  Widget _buildPageSlot',
    ).firstMatch(homeView)?.group(0);
    final tabChangeMethod = RegExp(
      r'void _onTabChange\(int index\) \{[\s\S]*?\n  \}',
    ).firstMatch(homeView)?.group(0);
    final animatedTabPageState = RegExp(
      r'class _AnimatedTabPageState extends State<_AnimatedTabPage>[\s\S]*?\nclass _ClassicTabBar',
    ).firstMatch(homeView)?.group(0);
    final didUpdateWidgetMethod = RegExp(
      r'void didUpdateWidget\(covariant _AnimatedTabPage oldWidget\) \{[\s\S]*?\n  @override\n  void dispose',
    ).firstMatch(homeView)?.group(0);
    final transitionSetterMethod = RegExp(
      r'void _setTransitioning\(bool value\) \{[\s\S]*?\n  void _startTransition',
    ).firstMatch(homeView)?.group(0);
    final classicTabBarClass = RegExp(
      r'class _ClassicTabBar extends StatelessWidget \{[\s\S]*?\n\}',
    ).firstMatch(homeView)?.group(0);

    expect(
      homeView,
      contains('static const List<GButton> _dockTabs = ['),
      reason: '首页底部导航的 GButton 列表应静态复用，避免每次切 tab 重新构造。',
    );
    expect(
      homeView,
      contains('tabs: _dockTabs,'),
      reason: '首页底部导航应把稳定 tabs 传给 _ClassicTabBar。',
    );
    expect(
      homeView,
      contains('class _HomeTabState'),
      reason: '首页 tab 切换状态应收敛为轻量值对象，避免散落字段导致整页 setState。',
    );
    expect(
      homeView,
      contains('late final ValueNotifier<_HomeTabState> _tabStateNotifier;'),
      reason: '首页 tab 切换应使用局部 notifier，避免点击底部导航时重建整个首页 shell。',
    );
    expect(homeView, contains('_tabStateNotifier.dispose();'));
    expect(
      homeView,
      isNot(contains('late int _selectedIndex')),
      reason: 'tab 选择态不应再由整页 State 字段配合 setState 管理。',
    );
    expect(
      homeView,
      isNot(contains('late final List<bool> _loadedPages')),
      reason: '已加载 tab 状态应封装到 _HomeTabState 中统一通知局部 builder。',
    );
    expect(classicTabBarClass, isNotNull);
    expect(
      classicTabBarClass,
      contains('final List<GButton> tabs;'),
      reason: '_ClassicTabBar 应接收稳定 tabs，而不是在 build 内从 items 生成。',
    );
    expect(
      classicTabBarClass,
      contains('tabs: tabs,'),
      reason: 'GNav 应直接使用外部传入的稳定 tabs。',
    );
    expect(animatedTabPageState, isNotNull);
    expect(
      animatedTabPageState,
      contains('with TickerProviderStateMixin'),
      reason:
          '首页 tab 转场会在动画完成后释放 controller，之后再次进入同一 tab 会重建 ticker，不能使用只允许创建一次 ticker 的 SingleTickerProviderStateMixin。',
    );
    expect(
      animatedTabPageState,
      isNot(contains('with SingleTickerProviderStateMixin')),
    );
    expect(
      animatedTabPageState,
      contains('final ValueNotifier<bool> _isTransitioningNotifier'),
      reason: '首页 tab 转场态应局部通知，避免动画完成时 setState 重建整个 tab slot。',
    );
    expect(
      animatedTabPageState,
      contains('_isTransitioningNotifier.dispose();'),
      reason: '局部过渡态 notifier 应随 tab state 释放。',
    );
    expect(
      animatedTabPageState,
      contains('ValueListenableBuilder<bool>'),
      reason: '真实过渡期间只应重建 SlideTransition 包裹层。',
    );
    expect(
      animatedTabPageState,
      contains(
        'if (!widget.isActive ||\n'
        '        _reduceMotion ||\n'
        '        !_isTransitioningNotifier.value ||\n'
        '        slide == null) {\n'
        '      return widget.child;\n'
        '    }',
      ),
      reason: '非活跃 tab、减弱动画和稳定态应直接返回 child，不应常驻过渡监听包装。',
    );
    expect(
      animatedTabPageState!.indexOf('return widget.child;'),
      lessThan(
        animatedTabPageState.indexOf('return ValueListenableBuilder<bool>('),
      ),
      reason: '稳定路径应先短路，只有真实过渡时才创建 ValueListenableBuilder。',
    );
    expect(
      animatedTabPageState,
      isNot(contains('setState(')),
      reason: '_AnimatedTabPageState 的过渡态不应通过 setState 重建页面内容。',
    );
    expect(transitionSetterMethod, isNotNull);
    expect(
      transitionSetterMethod,
      contains('!mounted || _isTransitioningNotifier.value == value'),
      reason: '过渡态写入应跳过卸载 state 和重复值。',
    );
    expect(
      transitionSetterMethod,
      contains('_isTransitioningNotifier.value = value;'),
      reason: '过渡态变化应只通知局部 ValueListenableBuilder。',
    );
    expect(didUpdateWidgetMethod, isNotNull);
    expect(
      didUpdateWidgetMethod,
      contains('if (!widget.isActive)'),
      reason: '首页 tab 退为非活动页时应先走释放分支。',
    );
    expect(didUpdateWidgetMethod, contains('_disposeTransitionController();'));
    expect(didUpdateWidgetMethod, contains('_setTransitioning(false);'));
    expect(didUpdateWidgetMethod, contains('return;'));
    expect(
      didUpdateWidgetMethod!.indexOf('if (!widget.isActive)'),
      lessThan(didUpdateWidgetMethod.indexOf('_configureAnimations();')),
      reason: '非活动 tab 不应先配置过渡动画再立即释放 controller。',
    );
    expect(buildMethod, isNotNull);
    expect(
      buildMethod,
      contains('ValueListenableBuilder<_HomeTabState>'),
      reason: '首页 tab 舞台和底部导航应分别局部监听 tab 状态。',
    );
    expect(
      buildMethod,
      contains('valueListenable: _tabStateNotifier'),
      reason: 'tab 切换不应依赖整页 build 传递选中态。',
    );
    expect(
      buildMethod,
      contains('for (var index = 0; index < _pages.length; index++)'),
      reason: '首页 shell 应直接循环构建页面槽位，避免每次 build 走 List.generate 闭包。',
    );
    expect(buildMethod, contains('_buildPageSlot(index, tabState)'));
    expect(
      buildMethod,
      isNot(contains('List.generate(_pages.length')),
      reason: '首页页面槽位处于常驻 shell build 路径，不应通过 List.generate 生成。',
    );
    expect(tabChangeMethod, isNotNull);
    expect(
      tabChangeMethod,
      contains('final tabState = _tabStateNotifier.value;'),
      reason: 'tab 点击应基于当前局部状态计算下一状态。',
    );
    expect(
      tabChangeMethod,
      contains('_tabStateNotifier.value = _HomeTabState('),
      reason: 'tab 点击应只通知 tab 舞台和底部导航局部重建。',
    );
    expect(
      tabChangeMethod,
      isNot(contains('setState(')),
      reason: '首页 tab 点击不应 setState 重建整个首页 shell。',
    );
    expect(
      classicTabBarClass,
      isNot(contains('.map(')),
      reason: '_ClassicTabBar build 不应通过 map/toList 重建 GButton 列表。',
    );
    expect(
      classicTabBarClass,
      isNot(contains('toList(growable: false)')),
      reason: '_ClassicTabBar build 不应物化新的 GButton 列表。',
    );
    expect(
      classicTabBarClass,
      contains('for (var index = 0; index < items.length; index++)'),
      reason: '首页底部导航透明点击热区应直接按下标构建，避免每次 build 走 List.generate 闭包。',
    );
    expect(classicTabBarClass, contains('_buildHitZone(index)'));
    expect(
      classicTabBarClass,
      isNot(contains('List.generate(items.length')),
      reason: '_ClassicTabBar build 不应通过 List.generate 重建透明点击热区。',
    );
  });

  test('function page reuses stable feature metadata', () {
    final functionPage =
        File('lib/home/Functionpage/view.dart').readAsStringSync();
    final stateClass = RegExp(
      r'class _FunctionPageState extends State<FunctionPage>[\s\S]*?\n  @override\n  void dispose',
    ).firstMatch(functionPage)?.group(0);
    final buildMethod = RegExp(
      r'Widget build\(BuildContext context\) \{[\s\S]*?\n  Widget _buildFeatureCard',
    ).firstMatch(functionPage)?.group(0);
    final buildFeatureCardMethod = RegExp(
      r'Widget _buildFeatureCard\(_FunctionFeature item\) \{[\s\S]*?\nclass _FunctionFeature',
    ).firstMatch(functionPage)?.group(0);
    final featureClass = RegExp(
      r'class _FunctionFeature \{[\s\S]*?\n\}',
    ).firstMatch(functionPage)?.group(0);

    expect(
      functionPage,
      contains('static final List<_FunctionFeature> _features ='),
      reason: '功能页入口元数据应静态复用，避免每次首页 rebuild 重建功能项。',
    );
    expect(
      functionPage,
      contains('List<_FunctionFeature>.unmodifiable(['),
      reason: '功能页入口列表应初始化为不可变元数据，避免运行期误改导致重复 rebuild 风险。',
    );
    expect(stateClass, isNotNull);
    expect(stateClass, contains('Future<void> _handleFeatureTap'));
    expect(
      stateClass,
      contains('item.requiresJwxtToken'),
      reason: '功能入口点击应由统一方法分发受保护和普通导航，避免每个入口持有闭包。',
    );

    expect(buildMethod, isNotNull);
    expect(buildMethod, contains('itemCount: _features.length'));
    expect(buildMethod, contains('_buildFeatureCard(_features[index])'));
    expect(
      buildMethod,
      contains('addRepaintBoundaries: false'),
      reason: '功能页入口网格是固定功能集合，不应为每个入口额外创建 repaint boundary。',
    );
    expect(
      buildMethod,
      isNot(contains('_FunctionFeature(')),
      reason: '功能页 build 不应重新创建功能项对象。',
    );
    expect(
      buildMethod,
      isNot(contains('final items = [')),
      reason: '功能页 build 不应重新创建入口列表。',
    );
    expect(buildFeatureCardMethod, isNotNull);
    expect(buildFeatureCardMethod, contains('item.lightAccent'));
    expect(buildFeatureCardMethod, contains('item.deepAccent'));
    expect(
      buildFeatureCardMethod,
      isNot(contains('HSLColor.fromColor')),
      reason: '功能卡片 build 热路径不应重复做 HSL 派生色计算。',
    );
    expect(
      buildFeatureCardMethod,
      isNot(contains('RepaintBoundary(')),
      reason: '功能入口卡片没有常驻独立动画，不应为每个卡片额外创建 repaint 边界。',
    );
    expect(
      buildFeatureCardMethod,
      contains('AppLoadingIndicator('),
      reason: '功能入口 loading 动画应由加载控件自身隔离，而不是整张卡片建层。',
    );

    expect(featureClass, isNotNull);
    expect(featureClass, contains('final Color lightAccent;'));
    expect(featureClass, contains('final Color deepAccent;'));
    expect(featureClass, contains('static Color _shiftAccent'));
    expect(featureClass, contains('final Widget page;'));
    expect(featureClass, contains('final bool requiresJwxtToken;'));
    expect(
      featureClass,
      isNot(contains('Future<void> Function() onTap')),
      reason: '功能入口元数据不应保存每次 build 创建的点击闭包。',
    );
  });

  test('support page network buttons avoid temporary mapped lists', () {
    final supportPage =
        File('lib/home/about/support_page.dart').readAsStringSync();
    final buildMethod = RegExp(
      r'Widget build\(BuildContext context\) \{[\s\S]*?\nclass _SupportSectionPanel',
    ).firstMatch(supportPage)?.group(0);

    expect(
      supportPage,
      contains(
        'late final ValueNotifier<_SupportNetwork> _selectedNetworkNotifier',
      ),
      reason: '支持页网络切换只应通知收款信息区域，不应 setState 重建整页背景。',
    );
    expect(
      supportPage,
      contains('late final ValueNotifier<bool> _isCopyingAddressNotifier'),
      reason: '复制地址的 pending 状态只应刷新复制按钮，不应重建二维码和整页内容。',
    );
    expect(supportPage, contains('_selectedNetworkNotifier.dispose();'));
    expect(supportPage, contains('_isCopyingAddressNotifier.dispose();'));
    expect(
      supportPage,
      contains('void _selectNetwork(_SupportNetwork network)'),
    );
    expect(
      supportPage,
      contains('if (_selectedNetworkNotifier.value == network)'),
      reason: '重复选择当前网络时不应触发 ValueNotifier 通知。',
    );
    expect(supportPage, contains('_selectedNetworkNotifier.value = network;'));
    expect(
      supportPage,
      contains('if (_isCopyingAddressNotifier.value)'),
      reason: '复制地址应在写剪贴板前防重复点击。',
    );
    expect(supportPage, contains('_setCopyingAddress(true);'));
    expect(supportPage, contains('_setCopyingAddress(false);'));
    expect(
      supportPage,
      contains('void _setCopyingAddress(bool isCopyingAddress)'),
    );
    expect(
      supportPage,
      contains(
        '!mounted || _isCopyingAddressNotifier.value == isCopyingAddress',
      ),
      reason: '复制 pending 状态不变或页面已卸载时不应通知按钮重建。',
    );
    expect(
      supportPage,
      contains('_isCopyingAddressNotifier.value = isCopyingAddress;'),
    );
    expect(
      supportPage,
      isNot(contains('setState(()')),
      reason: '支持页网络切换和复制按钮 pending 都应局部刷新，避免整个 ListView/背景重建。',
    );
    expect(
      supportPage,
      isNot(contains('AppAnimatedSwitcher(')),
      reason: '支持页二维码切换应直接替换，避免动画过渡期同时构建旧/新二维码。',
    );
    expect(
      supportPage,
      isNot(contains('AppAnimatedContainer(')),
      reason: '支持页网络按钮只需要直接切换最终选中样式，不应再引入隐式容器动画。',
    );

    expect(buildMethod, isNotNull);
    expect(buildMethod, contains('ValueListenableBuilder<_SupportNetwork>'));
    expect(buildMethod, contains('valueListenable: _selectedNetworkNotifier'));
    expect(
      buildMethod,
      contains('isCopyingListenable: _isCopyingAddressNotifier'),
    );
    expect(
      buildMethod,
      contains('for (final item in _networkSpecs.values)'),
      reason: '支持页网络按钮应直接用 collection-for 构建，避免每次 build 额外 map/toList。',
    );
    expect(buildMethod, contains('selected: item.network == selectedNetwork'));
    expect(buildMethod, contains('onTap: () => _selectNetwork(item.network)'));
    expect(buildMethod, isNot(contains('_networkSpecs.values.map')));
    expect(buildMethod, isNot(contains('toList(growable: false)')));
    expect(supportPage, contains('ValueListenableBuilder<bool>'));
    expect(supportPage, contains('valueListenable: isCopyingListenable'));
    expect(
      supportPage,
      contains('onPressed: isCopyingAddress ? null : onCopy'),
    );
    expect(supportPage, contains('AppLoadingIndicator('));
  });

  test('hut main caches service directory outside build filtering', () {
    final hutMain = File('lib/pages/hutpages/hutmain.dart').readAsStringSync();
    final buildContentMethod = RegExp(
      r'Widget _buildContent\(BuildContext context, List data\) \{[\s\S]*?\n  Widget _buildSearchResultList',
    ).firstMatch(hutMain)?.group(0);
    final directoryCacheMethod = RegExp(
      r'_ServiceDirectory _serviceDirectoryFor\(List data\) \{[\s\S]*?\n  _ServiceDirectory _buildServiceDirectory',
    ).firstMatch(hutMain)?.group(0);
    final buildDirectoryMethod = RegExp(
      r'_ServiceDirectory _buildServiceDirectory\(List data\) \{[\s\S]*?\n  List<_ServiceWithCategory> _filterSearchResults',
    ).firstMatch(hutMain)?.group(0);
    final filterSearchResultsMethod = RegExp(
      r'List<_ServiceWithCategory> _filterSearchResults\([\s\S]*?\n  List<_ServiceWithCategory> _searchResultsFor',
    ).firstMatch(hutMain)?.group(0);
    final searchResultCacheMethod = RegExp(
      r'List<_ServiceWithCategory> _searchResultsFor\([\s\S]*?\n  bool _isVisibleService',
    ).firstMatch(hutMain)?.group(0);
    final searchChangedMethod = RegExp(
      r'void _handleSearchTextChanged\(\) \{[\s\S]*?\n  void _unfocusSearchField',
    ).firstMatch(hutMain)?.group(0);
    final categoryPanelClass = RegExp(
      r'class _ServiceCategoryPanel extends StatelessWidget \{[\s\S]*?\nclass _ServiceTile',
    ).firstMatch(hutMain)?.group(0);
    final serviceTileClass = RegExp(
      r'class _ServiceTile extends StatelessWidget \{[\s\S]*?\nclass _CountPill',
    ).firstMatch(hutMain)?.group(0);

    expect(hutMain, contains('class _ServiceDirectory'));
    expect(hutMain, contains('_ServiceDirectory? _cachedServiceDirectory;'));
    expect(hutMain, contains('_ServiceDirectory? _searchResultsDirectory;'));
    expect(
      hutMain,
      contains('List<_ServiceWithCategory>? _cachedSearchResults;'),
    );
    expect(
      hutMain,
      contains(
        "final ValueNotifier<String> _searchTextNotifier = ValueNotifier<String>('');",
      ),
      reason: '智慧工大搜索词应使用局部 notifier，避免输入时 setState 重建整页。',
    );
    expect(
      hutMain,
      contains('_searchTextNotifier.dispose();'),
      reason: '搜索词 notifier 应随页面释放。',
    );
    expect(hutMain, contains('ValueListenableBuilder<String>'));
    expect(hutMain, contains('valueListenable: _searchTextNotifier'));

    expect(buildContentMethod, isNotNull);
    expect(
      buildContentMethod,
      contains('final directory = _serviceDirectoryFor(data);'),
    );
    expect(
      buildContentMethod,
      contains('SliverChildBuilderDelegate'),
      reason: '智慧工大服务分类应按可见项懒构建，不应一次性生成所有分类面板。',
    );
    expect(buildContentMethod, contains('final category = categories[index];'));
    expect(buildContentMethod, contains('childCount: categories.length'));
    expect(
      buildContentMethod,
      contains('_searchResultsFor(directory, searchText)'),
      reason: '智慧工大搜索结果应在局部监听内按目录和搜索词缓存，避免父级 rebuild 重复整表过滤。',
    );
    expect(
      buildContentMethod,
      isNot(contains('_normalizeCategories')),
      reason: '智慧工大完成态 build 不应重复归一化服务目录。',
    );
    expect(
      buildContentMethod,
      isNot(contains('_flattenServices')),
      reason: '智慧工大完成态 build 不应重复拉平服务目录。',
    );
    expect(
      buildContentMethod,
      isNot(contains('.where(')),
      reason: '智慧工大完成态 build 不应直接整表过滤服务。',
    );
    expect(
      buildContentMethod,
      isNot(contains('categories.map')),
      reason: '智慧工大完成态 build 不应通过 map 一次性物化全部分类面板。',
    );

    expect(directoryCacheMethod, isNotNull);
    expect(
      directoryCacheMethod,
      contains('identical(_serviceDirectorySource, data)'),
      reason: '同一服务数据源的目录归一化结果应复用。',
    );

    expect(buildDirectoryMethod, isNotNull);
    expect(
      buildDirectoryMethod,
      contains('for (final rawService in rawServices)'),
      reason: '服务目录构建应单次扫描服务并同时产出分类、全部服务、可搜索服务。',
    );
    expect(
      buildDirectoryMethod,
      contains('icon: _iconForService(rawService)'),
      reason: '服务图标应随目录缓存一次派生，避免 tile build 重复按名称推断。',
    );
    expect(
      buildDirectoryMethod,
      contains(
        'typeLabel: _serviceTypeLabel(rawService.serviceType, categoryLabel)',
      ),
      reason: '服务类型文案应随目录缓存一次派生，避免 tile build 重复拼接。',
    );
    expect(
      buildDirectoryMethod,
      contains('normalizedServiceName: rawService.serviceName.toLowerCase()'),
      reason: '服务搜索用的小写服务名应随目录缓存，避免每次搜索重复转换。',
    );
    expect(
      buildDirectoryMethod,
      contains('normalizedCategory: categoryLabel.toLowerCase()'),
      reason: '服务搜索用的小写分类名应随目录缓存，避免每次搜索重复转换。',
    );
    expect(buildDirectoryMethod, isNot(contains('whereType')));
    expect(buildDirectoryMethod, isNot(contains('.expand(')));

    expect(hutMain, contains('final IconData icon;'));
    expect(hutMain, contains('final String typeLabel;'));
    expect(hutMain, contains('final String normalizedServiceName;'));
    expect(hutMain, contains('final String normalizedCategory;'));

    expect(filterSearchResultsMethod, isNotNull);
    expect(
      filterSearchResultsMethod,
      contains('item.normalizedServiceName.contains(normalizedKeyword)'),
      reason: '搜索过滤应复用缓存的小写服务名。',
    );
    expect(
      filterSearchResultsMethod,
      contains('item.normalizedCategory.contains(normalizedKeyword)'),
      reason: '搜索过滤应复用缓存的小写分类名。',
    );
    expect(
      filterSearchResultsMethod,
      isNot(contains('item.service.serviceName.toLowerCase()')),
      reason: '搜索热路径不应对每个服务重复转换服务名大小写。',
    );
    expect(
      filterSearchResultsMethod,
      isNot(contains('item.category.toLowerCase()')),
      reason: '搜索热路径不应对每个服务重复转换分类名大小写。',
    );

    expect(searchResultCacheMethod, isNotNull);
    expect(
      searchResultCacheMethod,
      contains('identical(_searchResultsDirectory, directory)'),
      reason: '搜索缓存应绑定服务目录实例，避免数据源切换后复用旧结果。',
    );
    expect(
      searchResultCacheMethod,
      contains('_searchResultsKeyword == keyword'),
    );
    expect(searchResultCacheMethod, contains('return cachedSearchResults;'));
    expect(
      searchResultCacheMethod,
      contains(
        '_filterSearchResults(\n      directory.searchableServices,\n      keyword,',
      ),
      reason: '搜索缓存未命中时才扫描可搜索服务列表。',
    );

    expect(searchChangedMethod, isNotNull);
    expect(
      searchChangedMethod,
      contains('if (_searchTextNotifier.value == nextSearchText)'),
      reason: '搜索文本去空格后未变化时不应触发局部 rebuild。',
    );
    expect(
      searchChangedMethod,
      contains('_searchTextNotifier.value = nextSearchText;'),
      reason: '搜索输入变化只应通知搜索相关局部区域。',
    );
    expect(
      searchChangedMethod,
      isNot(contains('setState(')),
      reason: '搜索输入不应 setState 重建整页服务目录。',
    );

    expect(categoryPanelClass, isNotNull);
    expect(
      categoryPanelClass,
      contains('for (final item in category.services)'),
      reason: '分类面板内部服务项应直接 collection-for 构建，避免 map iterable 额外对象。',
    );
    expect(categoryPanelClass, contains('icon: item.icon'));
    expect(categoryPanelClass, contains('typeLabel: item.typeLabel'));
    expect(categoryPanelClass, isNot(contains('category.services.map')));

    expect(serviceTileClass, isNotNull);
    expect(serviceTileClass, contains('child: Icon(icon, color: accent'));
    expect(serviceTileClass, contains('Text(\n                  typeLabel,'));
    expect(
      serviceTileClass,
      isNot(contains('_iconForService(')),
      reason: '服务 tile build 不应重复按服务名称推断图标。',
    );
    expect(
      serviceTileClass,
      isNot(contains('_serviceTypeLabel(')),
      reason: '服务 tile build 不应重复拼接类型文案。',
    );
  });

  test('hut main drops late async results after close', () {
    final logic =
        File('lib/pages/hutpages/hutmain_logic.dart').readAsStringSync();
    final getFunListMethod = RegExp(
      r'Future<List> getFunList\(\) async \{[\s\S]*?\n  /// 判断是否需要跳转登录',
    ).firstMatch(logic)?.group(0);
    final checkLoginMethod = RegExp(
      r'Future<void> checkLogin\(\) async \{[\s\S]*?\n  void _queueLoginRedirect',
    ).firstMatch(logic)?.group(0);
    final queueLoginMethod = RegExp(
      r'void _queueLoginRedirect\(\) \{[\s\S]*?\n  @override',
    ).firstMatch(logic)?.group(0);

    expect(logic, contains('bool _isDisposed = false;'));
    expect(logic, contains('_isDisposed = true;'));
    expect(
      logic,
      isNot(contains('update();')),
      reason: '智慧工大目录页由 FutureBuilder 和 Rx 状态驱动，不应额外触发 GetxController.update。',
    );

    expect(getFunListMethod, isNotNull);
    expect(
      getFunListMethod,
      contains('if (_isDisposed)'),
      reason: '智慧工大目录页关闭后不应再创建新的服务目录请求。',
    );
    expect(
      getFunListMethod,
      contains('final loadedFunList = await load;'),
      reason: '服务目录请求返回后应先保存到局部变量，再判断页面是否已关闭。',
    );
    expect(
      getFunListMethod!.indexOf('if (_isDisposed)'),
      lessThan(getFunListMethod.indexOf('_loadFunctionList()')),
      reason: '发起服务目录请求前应先丢弃已关闭页面的入口。',
    );
    expect(
      getFunListMethod.indexOf(
        'if (_isDisposed)',
        getFunListMethod.indexOf('await load'),
      ),
      isNot(-1),
      reason: '服务目录请求返回后应丢弃关闭页面的旧结果。',
    );

    expect(checkLoginMethod, isNotNull);
    expect(
      checkLoginMethod,
      contains('if (_isDisposed)'),
      reason: '智慧工大登录检查在页面关闭后不应继续排跳转。',
    );
    expect(
      checkLoginMethod!.indexOf('if (_isDisposed)'),
      lessThan(checkLoginMethod.indexOf('_isHutLoggedIn()')),
      reason: '页面关闭后调用登录检查时不应再读取登录状态。',
    );
    expect(
      checkLoginMethod.indexOf(
        'if (_isDisposed)',
        checkLoginMethod.indexOf('_isHutLoggedIn()'),
      ),
      isNot(-1),
      reason: '登录状态读取返回后应再次丢弃关闭页面的旧结果。',
    );

    expect(queueLoginMethod, isNotNull);
    expect(
      queueLoginMethod,
      contains('if (_isDisposed)'),
      reason: '登录跳转 timer 入口也应防止关闭后重复排导航。',
    );
  });

  test('type2 webview caches token accept parsing and cookie keys', () {
    final type2Webview =
        File('lib/pages/hutpages/type2/type2webview.dart').readAsStringSync();
    final parseMethod = RegExp(
      r'List<Map<String, dynamic>> _parseTokenAccept[\s\S]*?\n  List<Map<String, dynamic>> _tokenAcceptList',
    ).firstMatch(type2Webview)?.group(0);
    final tokenAcceptMethod = RegExp(
      r'List<Map<String, dynamic>> _tokenAcceptList\(\) \{[\s\S]*?\n  String _applyTokenAccept',
    ).firstMatch(type2Webview)?.group(0);
    final applyMethod = RegExp(
      r'String _applyTokenAccept\(\{[\s\S]*?\n  List<String> _getCookieTokenKeys',
    ).firstMatch(type2Webview)?.group(0);
    final cookieKeysMethod = RegExp(
      r'List<String> _getCookieTokenKeys\(\) \{[\s\S]*?\n  String _buildCookieHeaderWithAttributes',
    ).firstMatch(type2Webview)?.group(0);
    final cookieHeaderMethod = RegExp(
      r'String _buildCookieHeaderWithAttributes\(String token\) \{[\s\S]*?\n  Future<void> _syncWebViewCookies',
    ).firstMatch(type2Webview)?.group(0);
    final injectCookiesMethod = RegExp(
      r'Future<void> _injectWebViewCookies\(\{[\s\S]*?\n  Future<bool> getDetail',
    ).firstMatch(type2Webview)?.group(0);

    expect(type2Webview, contains('String? _cachedTokenAcceptSource;'));
    expect(
      type2Webview,
      contains('List<Map<String, dynamic>>? _cachedTokenAcceptList;'),
    );
    expect(type2Webview, contains('List<String>? _cachedCookieTokenKeys;'));

    expect(parseMethod, isNotNull);
    expect(
      parseMethod,
      contains('for (final item in parsedList)'),
      reason: 'tokenAccept 解析应单次循环复制 Map，不应链式 where/map/toList。',
    );
    expect(parseMethod, isNot(contains('whereType')));
    expect(parseMethod, isNot(contains('.map(')));
    expect(parseMethod, isNot(contains('.toList()')));

    expect(tokenAcceptMethod, isNotNull);
    expect(tokenAcceptMethod, contains('_cachedTokenAcceptSource == source'));
    expect(tokenAcceptMethod, contains('return cachedList;'));
    expect(tokenAcceptMethod, contains('_cachedCookieTokenKeys = null;'));

    expect(applyMethod, isNotNull);
    expect(applyMethod, contains('required Map<String, String> headers'));
    expect(applyMethod, contains('required String resultUrl'));
    expect(applyMethod, contains('required String token'));
    expect(applyMethod, contains('var resolvedUrl = resultUrl;'));
    expect(applyMethod, contains('for (final item in _tokenAcceptList())'));
    expect(applyMethod, contains('headers[tokenKey] = token;'));
    expect(applyMethod, contains('return resolvedUrl;'));
    expect(
      applyMethod,
      isNot(contains('_parseTokenAccept(widget.tokenAccept)')),
      reason: 'header/url token 注入应复用缓存后的 tokenAccept 列表。',
    );

    expect(cookieKeysMethod, isNotNull);
    expect(
      cookieKeysMethod,
      contains('final cachedKeys = _cachedCookieTokenKeys;'),
    );
    expect(cookieKeysMethod, contains('return cachedKeys;'));
    expect(
      cookieKeysMethod,
      contains('for (final item in _tokenAcceptList())'),
    );
    expect(
      cookieKeysMethod,
      contains('_cachedCookieTokenKeys = resolvedKeys;'),
    );
    expect(cookieKeysMethod, isNot(contains('.where(')));
    expect(cookieKeysMethod, isNot(contains('.map(')));
    expect(cookieKeysMethod, isNot(contains('.toSet()')));
    expect(cookieKeysMethod, isNot(contains('.toList()')));

    expect(cookieHeaderMethod, isNotNull);
    expect(cookieHeaderMethod, contains('final buffer = StringBuffer();'));
    expect(cookieHeaderMethod, contains(r"'$key=$token;"));
    expect(
      cookieHeaderMethod,
      contains('for (final key in _getCookieTokenKeys())'),
    );
    expect(cookieHeaderMethod, isNot(contains('.map(')));
    expect(cookieHeaderMethod, isNot(contains(".join('; ')")));

    expect(injectCookiesMethod, isNotNull);
    expect(injectCookiesMethod, contains('required int generation'));
    expect(
      injectCookiesMethod,
      contains('if (!_isCurrentSetup(generation))'),
      reason: 'cookie 注入属于 setup 副作用，旧 setup 返回后不应继续写 cookie 或打日志。',
    );
    expect(
      injectCookiesMethod,
      contains('final cookieTokenKeys = _getCookieTokenKeys();'),
    );
    expect(
      injectCookiesMethod,
      contains('final cookieDebugInfo = StringBuffer();'),
    );
    expect(injectCookiesMethod, contains('for (final cookie in cookies)'));
    expect(
      injectCookiesMethod,
      isNot(contains('cookies\n          .where')),
      reason: 'cookie 注入日志不应链式过滤并重复读取 cookie key。',
    );
    expect(injectCookiesMethod, isNot(contains('.map(')));
  });

  test('hut webview setup drops stale async results', () {
    final hutServiceAuth =
        File('lib/pages/hutpages/hut_service_auth.dart').readAsStringSync();
    final webviewFiles = {
      'Type1Webview':
          File('lib/pages/hutpages/type1/type1webview.dart').readAsStringSync(),
      'Type2Webview':
          File('lib/pages/hutpages/type2/type2webview.dart').readAsStringSync(),
    };

    for (final entry in webviewFiles.entries) {
      final source = entry.value;
      final headerProfile =
          entry.key == 'Type1Webview'
              ? 'HutWebViewHeaderProfile.type1'
              : 'HutWebViewHeaderProfile.type2';
      final getDetailMethod = RegExp(
        r'Future<bool> getDetail\(\) \{[\s\S]*?\n  @visibleForTesting',
      ).firstMatch(source)?.group(0);
      final loadDetailMethod = RegExp(
        r'Future<bool> _loadDetail\(int generation\) async \{[\s\S]*?\n  @override',
      ).firstMatch(source)?.group(0);

      expect(source, contains('int _setupGeneration = 0;'));
      expect(
        source,
        contains('bool _isCurrentSetup(int generation)'),
        reason: '${entry.key} setup 需要集中判断当前 generation。',
      );
      expect(getDetailMethod, isNotNull);
      expect(
        getDetailMethod,
        contains('final generation = ++_setupGeneration;'),
        reason: '${entry.key} 每次 setup 应生成新的 generation。',
      );
      expect(getDetailMethod, contains('return _loadDetail(generation);'));

      expect(loadDetailMethod, isNotNull);
      final loadDetailText = loadDetailMethod!;
      final staleGuardIndex = loadDetailText.indexOf(
        'if (!_isCurrentSetup(generation))',
      );
      final tokenWriteIndex = loadDetailText.indexOf('token = nextToken;');
      final headerWriteIndex = loadDetailText.indexOf(
        'headerMap = nextHeaders;',
      );
      expect(staleGuardIndex, isNot(-1));
      expect(tokenWriteIndex, isNot(-1));
      expect(headerWriteIndex, isNot(-1));
      expect(
        staleGuardIndex,
        lessThan(tokenWriteIndex),
        reason: '${entry.key} 旧 setup 不应覆盖 token 或目标 URL。',
      );
      expect(
        staleGuardIndex,
        lessThan(headerWriteIndex),
        reason: '${entry.key} 旧 setup 不应覆盖 WebView 请求头。',
      );
      expect(
        loadDetailText,
        contains('final nextHeaders = buildHutWebViewHeaders('),
        reason: '${entry.key} WebView 请求头应通过共享 helper 在 setup 阶段构建并缓存。',
      );
      expect(loadDetailText, contains('token: nextToken,'));
      expect(loadDetailText, contains('profile: $headerProfile,'));
      expect(
        source,
        isNot(contains('Map<String, String> _baseHeaders')),
        reason: '${entry.key} 不应继续维护一份本地 WebView 请求头字面量。',
      );
      expect(
        loadDetailText,
        contains(
          'if (_isCurrentSetup(generation)) {\n        _setupErrorMessage = resolveHutServiceAuthErrorMessage(error);',
        ),
        reason: '${entry.key} 旧 setup 失败不应覆盖最新错误状态，且失败页不应展示底层异常。',
      );
      expect(
        loadDetailText,
        isNot(contains('error.toString()')),
        reason: '${entry.key} 初始化失败页不应直接展示底层异常字符串。',
      );
    }

    expect(hutServiceAuth, contains('enum HutWebViewHeaderProfile'));
    expect(
      hutServiceAuth,
      contains('String resolveHutServiceAuthErrorMessage(Object error)'),
      reason: 'HUT WebView 初始化失败文案应集中解析，避免 Type1/Type2 分叉并泄漏底层异常。',
    );
    expect(
      hutServiceAuth,
      contains('return hutServiceOpenFailureMessage;'),
      reason: '未知初始化错误应降级为稳定用户提示。',
    );
    expect(
      hutServiceAuth,
      contains('Map<String, String> buildHutWebViewHeaders'),
      reason: 'HUT WebView 请求头应集中在认证 helper 中维护，避免 Type1/Type2 分叉。',
    );
    expect(hutServiceAuth, contains('case HutWebViewHeaderProfile.type1:'));
    expect(hutServiceAuth, contains('case HutWebViewHeaderProfile.type2:'));
    expect(hutServiceAuth, contains(r'"Cookie": "userToken=$token"'));
    expect(hutServiceAuth, contains('"priority": "u=0, i"'));

    final type1Webview = webviewFiles['Type1Webview']!;
    final type1RewriteMethod = RegExp(
      r'Future<NavigationActionPolicy> _rewriteLegacyPortalNavigation\([\s\S]*?\n  Future<void> _openLoginAndRetry',
    ).firstMatch(type1Webview)?.group(0);
    final type1BuildMethod = RegExp(
      r'Widget build\(BuildContext context\) \{[\s\S]*?\n\}',
    ).firstMatch(type1Webview)?.group(0);

    expect(type1Webview, contains('Map<String, String> headerMap = {};'));
    expect(type1Webview, contains('Map<String, String> get debugHeaderMap'));
    expect(type1RewriteMethod, isNotNull);
    expect(
      type1RewriteMethod,
      contains('headers: headerMap'),
      reason: 'Type1 旧门户 URL 重写应复用 setup 缓存的请求头，避免每次重写重新组装 Map。',
    );
    expect(
      type1RewriteMethod,
      isNot(contains('_baseHeaders(')),
      reason: 'Type1 旧门户 URL 重写不应绕过缓存请求头。',
    );
    expect(type1BuildMethod, isNotNull);
    expect(
      type1BuildMethod,
      contains('headers: headerMap'),
      reason: 'Type1 初始 WebView 请求应复用 setup 缓存的请求头。',
    );
    expect(
      type1BuildMethod,
      isNot(contains('_baseHeaders(')),
      reason: 'Type1 build 不应重复构造 WebView 请求头。',
    );

    final type2Webview = webviewFiles['Type2Webview']!;
    final initialSetupMethod = RegExp(
      r'Future<bool> _performInitialSetup\(\) async \{[\s\S]*?\n  Future<void> _openLoginAndRetry',
    ).firstMatch(type2Webview)?.group(0);
    final syncCookiesMethod = RegExp(
      r'Future<void> _syncWebViewCookies\(\{[\s\S]*?\n  Future<void> _injectWebViewCookies',
    ).firstMatch(type2Webview)?.group(0);

    expect(initialSetupMethod, isNotNull);
    expect(
      initialSetupMethod,
      contains('final generation = ++_setupGeneration;'),
      reason: 'Type2 权限等待前应先标记 setup generation，避免旧初始化链路晚启动后反抢最新状态。',
    );
    expect(
      initialSetupMethod,
      contains('return await _loadDetail(generation);'),
    );
    expect(syncCookiesMethod, isNotNull);
    expect(syncCookiesMethod, contains('required int generation'));
    expect(syncCookiesMethod, contains('generation: generation'));
  });

  test('type2 webview keeps injected bridge handlers idempotent', () {
    final type2Webview =
        File('lib/pages/hutpages/type2/type2webview.dart').readAsStringSync();

    final registerMethod = RegExp(
      r'void _registerAlipayJavaScriptHandler[\s\S]*?\n  // 监听页面',
    ).firstMatch(type2Webview)?.group(0);
    final setupMethod = RegExp(
      r'void _setupAlipayLinkListener\(\) async[\s\S]*?\n  Future<void> _handleAlipayUrl',
    ).firstMatch(type2Webview)?.group(0);
    final alipayMethod = RegExp(
      r'Future<void> _handleAlipayUrl[\s\S]*?\n  @override',
    ).firstMatch(type2Webview)?.group(0);

    expect(registerMethod, isNotNull);
    expect(
      registerMethod,
      contains('identical(_alipayHandlerController, controller)'),
      reason: 'Flutter 侧 JS handler 应按 controller 幂等注册。',
    );
    expect(
      type2Webview,
      contains('_registerAlipayJavaScriptHandler(controller);'),
      reason: 'JS handler 应在 WebView 创建时注册，而不是每次 onLoadStop 重复注册。',
    );

    expect(setupMethod, isNotNull);
    expect(
      setupMethod,
      contains('window.__superhutAlipayBridgeInstalled'),
      reason: '网页侧支付宝桥接脚本应带全局标记，避免重复挂载事件监听器。',
    );
    expect(
      setupMethod,
      isNot(contains('addJavaScriptHandler')),
      reason: 'onLoadStop 触发的网页脚本注入不应重复注册 Flutter JS handler。',
    );
    expect(
      type2Webview,
      contains('window.__superhutHideNavObserver'),
      reason: '导航栏隐藏脚本应复用已有 observer，避免重复创建 MutationObserver。',
    );

    expect(alipayMethod, isNotNull);
    expect(
      alipayMethod,
      contains('if (_isLaunchingAlipay)'),
      reason: '支付宝外跳应防止同一链接被 JS 和导航回调重复触发。',
    );
    expect(
      alipayMethod,
      contains("message: '无法打开支付宝，请稍后重试'"),
      reason: '支付宝外跳失败不应把支付 URL 或底层异常直接显示给用户。',
    );
    expect(
      alipayMethod,
      isNot(contains("message: '无法打开支付宝:")),
      reason: '支付宝外跳失败提示不应包含完整支付 URL。',
    );
    expect(
      alipayMethod,
      isNot(contains("message: '打开链接失败：")),
      reason: '支付宝外跳失败提示不应包含底层异常字符串。',
    );
  });

  test('type2 webview back navigation is handled through one guarded entry', () {
    final type2Webview =
        File('lib/pages/hutpages/type2/type2webview.dart').readAsStringSync();

    final backMethod = RegExp(
      r'Future<void> _handleBackNavigationRequest\(\) async \{[\s\S]*?\n  // 更新是否可以回退的状态',
    ).firstMatch(type2Webview)?.group(0);
    final popScopeSection = RegExp(
      r'onPopInvokedWithResult: \(didPop, result\) async \{[\s\S]*?\n      \},',
    ).firstMatch(type2Webview)?.group(0);
    final floatingBackButtonSection = RegExp(
      r'child: IconButton\([\s\S]*?Ionicons\.arrow_back_circle_outline[\s\S]*?\n                  \),',
    ).firstMatch(type2Webview)?.group(0);

    expect(
      type2Webview,
      contains('bool _isHandlingBackNavigation = false;'),
      reason: 'WebView 返回路径应有页面级防重状态，避免快速返回触发重复 goBack/pop。',
    );
    expect(backMethod, isNotNull);
    expect(backMethod, contains('if (_isHandlingBackNavigation)'));
    expect(backMethod, contains('_isHandlingBackNavigation = true;'));
    expect(backMethod, contains('await _webViewController!.goBack();'));
    expect(backMethod, contains('Navigator.of(context).pop();'));
    expect(backMethod, contains('_isHandlingBackNavigation = false;'));
    expect(
      type2Webview,
      isNot(contains('Future<bool> _handleBackPressed')),
      reason: '返回逻辑不应保留未防重的旧入口。',
    );

    expect(popScopeSection, isNotNull);
    expect(popScopeSection, contains('await _handleBackNavigationRequest();'));

    expect(floatingBackButtonSection, isNotNull);
    expect(
      floatingBackButtonSection,
      contains('onPressed: _handleBackNavigationRequest'),
      reason: '悬浮返回按钮和系统返回应走同一个防重入口。',
    );
  });

  test('type2 webview back state drops stale async results', () {
    final type2Webview =
        File('lib/pages/hutpages/type2/type2webview.dart').readAsStringSync();

    final updateBackStateMethod = RegExp(
      r'void _updateCanGoBackState\(\) async \{[\s\S]*?\n  // 删除网页中的导航栏返回按钮',
    ).firstMatch(type2Webview)?.group(0);

    expect(
      type2Webview,
      contains('int _canGoBackGeneration = 0;'),
      reason: 'WebView history 回调可能连续触发，应给 canGoBack 查询加 generation。',
    );
    expect(
      type2Webview,
      contains('final ValueNotifier<bool> _canGoBackNotifier'),
      reason: 'Type2 WebView 返回状态应局部通知，避免 canGoBack 回调重建 InAppWebView。',
    );
    expect(type2Webview, contains('_canGoBackNotifier.dispose();'));
    expect(
      type2Webview,
      contains('valueListenable: _canGoBackNotifier'),
      reason: 'PopScope.canPop 应只监听返回状态 notifier。',
    );
    expect(updateBackStateMethod, isNotNull);
    expect(
      updateBackStateMethod,
      contains('final controller = _webViewController;'),
    );
    expect(
      updateBackStateMethod,
      contains('final generation = ++_canGoBackGeneration;'),
    );
    expect(updateBackStateMethod, contains('await controller.canGoBack();'));
    expect(
      updateBackStateMethod,
      contains('generation != _canGoBackGeneration'),
      reason: '旧 canGoBack 查询晚返回时不应覆盖最新返回状态。',
    );
    expect(
      updateBackStateMethod,
      contains('!identical(controller, _webViewController)'),
      reason: 'WebView controller 已替换时，旧 controller 的查询结果不能写入当前页面状态。',
    );
    expect(
      updateBackStateMethod,
      contains('canGoBack == _canGoBackNotifier.value'),
      reason: '返回状态未变化时不应触发局部通知。',
    );
    expect(
      updateBackStateMethod,
      contains('_canGoBackNotifier.value = canGoBack;'),
      reason: '返回状态变化应只通知 PopScope 局部 builder。',
    );
    expect(
      updateBackStateMethod,
      isNot(contains('setState(')),
      reason: '返回状态变化不应 setState 重建包含 InAppWebView 的页面。',
    );
  });

  test('hut webview loading callbacks avoid redundant rebuilds', () {
    final hutServiceAuth =
        File('lib/pages/hutpages/hut_service_auth.dart').readAsStringSync();
    final webviewFiles = {
      'Type1Webview':
          File('lib/pages/hutpages/type1/type1webview.dart').readAsStringSync(),
      'Type2Webview':
          File('lib/pages/hutpages/type2/type2webview.dart').readAsStringSync(),
    };

    for (final entry in webviewFiles.entries) {
      final source = entry.value;
      final loadingMethod = RegExp(
        r'void _setPageLoading\(bool isLoading\)[\s\S]*?\n  void _setRequestingPermission|void _setPageLoading\(bool isLoading\)[\s\S]*?\n  void _handlePossibleLoginRedirect',
      ).firstMatch(source)?.group(0);
      final callbackSection = RegExp(
        r'onLoadStart: \(controller, url\) \{[\s\S]*?shouldOverrideUrlLoading:',
      ).firstMatch(source)?.group(0);

      expect(
        source,
        contains(
          'final ValueNotifier<bool> _isPageLoadingNotifier = ValueNotifier<bool>(false);',
        ),
        reason: '${entry.key} WebView 页面加载遮罩应局部刷新，避免重建 InAppWebView。',
      );
      expect(
        source,
        contains('_isPageLoadingNotifier.dispose();'),
        reason: '${entry.key} 加载态 notifier 应随页面释放。',
      );
      expect(source, contains('ValueListenableBuilder<bool>'));
      expect(source, contains('valueListenable: _isPageLoadingNotifier'));
      expect(source, contains('HutWebViewLoadingOverlay('));
      expect(loadingMethod, isNotNull, reason: '${entry.key} 应集中管理加载态。');
      expect(
        loadingMethod,
        contains('if (!mounted || _isPageLoadingNotifier.value == isLoading)'),
        reason: '${entry.key} 页面销毁后或加载态不变时不应触发局部刷新。',
      );
      expect(
        loadingMethod,
        contains('_isPageLoadingNotifier.value == isLoading'),
        reason: '${entry.key} 加载态不变时不应触发局部刷新。',
      );
      expect(
        loadingMethod,
        contains('_isPageLoadingNotifier.value = isLoading;'),
        reason: '${entry.key} 应只在统一方法内更新加载态。',
      );
      expect(
        loadingMethod,
        isNot(contains('setState(')),
        reason: '${entry.key} 页面加载态不应 setState 重建 WebView。',
      );
      expect(callbackSection, isNotNull);
      expect(callbackSection, contains('_setPageLoading(true)'));
      expect(callbackSection, contains('_setPageLoading(false)'));
      expect(
        callbackSection,
        isNot(contains('_isPageLoading = true')),
        reason: '${entry.key} onLoadStart 不应无条件 setState。',
      );
      expect(
        callbackSection,
        isNot(contains('_isPageLoading = false')),
        reason: '${entry.key} onLoadStop 不应无条件 setState。',
      );
    }

    expect(hutServiceAuth, contains('class HutWebViewLoadingOverlay'));
    expect(
      'HutWebViewLoadingOverlay('.allMatches(hutServiceAuth).length,
      1,
      reason: 'HUT WebView 加载遮罩应集中维护，避免 Type1/Type2 重复 UI 结构。',
    );
  });

  test('type2 webview permission requests avoid redundant rebuilds', () {
    final type2Webview =
        File('lib/pages/hutpages/type2/type2webview.dart').readAsStringSync();
    final permissionLoadingMethod = RegExp(
      r'void _setRequestingPermission\(bool isRequestingPermission\)[\s\S]*?\n  void _handlePossibleLoginRedirect',
    ).firstMatch(type2Webview)?.group(0);
    final permissionMethod = RegExp(
      r'Future<void> _handleLocationPermission\(\) async \{[\s\S]*?\n  Future<void> _handleBackNavigationRequest',
    ).firstMatch(type2Webview)?.group(0);

    expect(type2Webview, contains('bool _permissionRequested = false;'));
    expect(
      type2Webview,
      contains('final ValueNotifier<bool> _isRequestingPermissionNotifier'),
      reason: 'Type2 权限遮罩应局部刷新，避免请求权限时重建 InAppWebView。',
    );
    expect(
      type2Webview,
      contains('_isRequestingPermissionNotifier.dispose();'),
      reason: '权限请求 notifier 应随页面释放。',
    );
    expect(
      type2Webview,
      contains('valueListenable: _isRequestingPermissionNotifier'),
      reason: '权限请求遮罩应通过局部监听刷新。',
    );
    expect(
      permissionLoadingMethod,
      isNotNull,
      reason: 'Type2 权限 loading 态应集中管理。',
    );
    expect(
      permissionLoadingMethod,
      contains(
        '_isRequestingPermissionNotifier.value == isRequestingPermission',
      ),
      reason: '页面销毁后或权限 loading 态不变时不应触发局部刷新。',
    );
    expect(
      permissionLoadingMethod,
      contains(
        '_isRequestingPermissionNotifier.value = isRequestingPermission;',
      ),
    );
    expect(
      permissionLoadingMethod,
      isNot(contains('setState(')),
      reason: '权限 loading 切换不应重建包含 InAppWebView 的整页。',
    );

    expect(permissionMethod, isNotNull);
    final permissionText = permissionMethod!;
    expect(permissionText, contains('if (_permissionRequested) return;'));
    expect(permissionText, contains('_permissionRequested = true;'));
    expect(
      permissionText,
      contains('if (!mounted || status == PermissionStatus.granted)'),
      reason: '已授权时不应先显示再隐藏权限 loading。',
    );
    expect(permissionText, contains('_setRequestingPermission(true);'));
    expect(permissionText, contains('_setRequestingPermission(false);'));
    expect(permissionText, isNot(contains('setState(')));
    expect(
      type2Webview,
      isNot(contains('bool _isRequestingPermission = false;')),
    );
    expect(permissionText, isNot(contains('_isRequestingPermission = true;')));
    expect(permissionText, isNot(contains('_isRequestingPermission = false;')));

    final grantedGuardIndex = permissionText.indexOf(
      'status == PermissionStatus.granted',
    );
    final loadingStartIndex = permissionText.indexOf(
      '_setRequestingPermission(true);',
    );
    expect(grantedGuardIndex, isNot(-1));
    expect(loadingStartIndex, isNot(-1));
    expect(
      grantedGuardIndex,
      lessThan(loadingStartIndex),
      reason: '应先确认确实需要系统权限请求，再显示权限 loading。',
    );
  });

  test('hut webview login redirect callbacks require mounted context', () {
    final webviewFiles = {
      'Type1Webview':
          File('lib/pages/hutpages/type1/type1webview.dart').readAsStringSync(),
      'Type2Webview':
          File('lib/pages/hutpages/type2/type2webview.dart').readAsStringSync(),
    };

    for (final entry in webviewFiles.entries) {
      final source = entry.value;
      final openLoginMethod = RegExp(
        r'Future<void> _openLoginAndRetry\(\) async \{[\s\S]*?\n  void _setPageLoading',
      ).firstMatch(source)?.group(0);
      final redirectMethod = RegExp(
        r'void _handlePossibleLoginRedirect\(WebUri\? url\) \{[\s\S]*?\n  @override',
      ).firstMatch(source)?.group(0);

      expect(openLoginMethod, isNotNull);
      expect(
        openLoginMethod,
        contains('if (!mounted || _isOpeningLogin)'),
        reason: '${entry.key} 登录重试入口在页面销毁或登录页打开中不应重复 push。',
      );
      expect(
        source,
        contains(
          'late final ValueNotifier<Future<bool>> _initialSetupFutureNotifier',
        ),
        reason: '${entry.key} 初始认证 Future 应由局部 notifier 持有，登录重试时只刷新认证承载区。',
      );
      expect(
        source,
        contains('_initialSetupFutureNotifier.dispose();'),
        reason: '${entry.key} 初始认证 Future notifier 应随页面释放。',
      );
      expect(
        source,
        contains('valueListenable: _initialSetupFutureNotifier'),
        reason: '${entry.key} 登录重试后应通过局部监听替换认证 Future。',
      );
      expect(
        source,
        contains('future: initialSetupFuture'),
        reason: '${entry.key} EnhancedFutureBuilder 应使用局部 builder 传入的 Future。',
      );
      expect(
        openLoginMethod,
        contains('_initialSetupFutureNotifier.value ='),
        reason: '${entry.key} 登录重试完成后只应替换 setup Future，不应重建整页。',
      );
      expect(
        openLoginMethod,
        isNot(contains('setState(')),
        reason: '${entry.key} 登录重试不应 setState 重建 WebView 页面。',
      );

      expect(redirectMethod, isNotNull);
      expect(
        redirectMethod,
        contains(
          'if (!mounted || _hasWarnedLoginRedirect || !isLikelyHutLoginUrl(url))',
        ),
        reason: '${entry.key} WebView 迟到回调不应在页面销毁后弹提示或安排登录。',
      );
      expect(redirectMethod, contains('showAppSnackBar('));
    }
  });

  test('hut login webview avoids redundant callback work', () {
    final loginSystem =
        File('lib/login/hut_login_system.dart').readAsStringSync();
    final checkUrlMethod = RegExp(
      r'Future<void> _checkUrlAndExtractTokenAndCookie[\s\S]*?\n  void _recordCurrentUrl',
    ).firstMatch(loginSystem)?.group(0);
    final extractTokenMethod = RegExp(
      r'String\? _extractTokenValue\(String source\) \{[\s\S]*?\nString\? _extractCasLoginTokenValue',
    ).firstMatch(loginSystem)?.group(0);
    final readTokenMethod = RegExp(
      r'String\? _readTokenValue\(String source, int start\) \{[\s\S]*?\nbool _isTokenTerminator',
    ).firstMatch(loginSystem)?.group(0);
    final casHtmlTokenMethod = RegExp(
      r'String\? extractJwxtTokenFromCasHtml\([\s\S]*?\nclass HutLoginSystem',
    ).firstMatch(loginSystem)?.group(0);
    final setLoadingMethod = RegExp(
      r'void _setLoading\(bool isLoading\)[\s\S]*?\n  void _updateNavigationState',
    ).firstMatch(loginSystem)?.group(0);
    final updateNavigationMethod = RegExp(
      r'void _updateNavigationState\(\{required String url, required bool isLoading\}\) \{[\s\S]*?\n  Future<void> _checkHtmlAndExtractTokenAndCookie',
    ).firstMatch(loginSystem)?.group(0);
    final htmlTokenMethod = RegExp(
      r'Future<void> _checkHtmlAndExtractTokenAndCookie\(\) async \{[\s\S]*?\n  // 获取指定名称的cookie',
    ).firstMatch(loginSystem)?.group(0);
    final deliverMethod = RegExp(
      r'Future<void> _deliverExtractedCredentials\(String token\) async \{[\s\S]*?\n  Future<void> _checkUrlAndExtractTokenAndCookie',
    ).firstMatch(loginSystem)?.group(0);
    final callbackSection = RegExp(
      r'onLoadStart: \(controller, url\) \{[\s\S]*?onReceivedError:',
    ).firstMatch(loginSystem)?.group(0);
    final errorCallbackSection = RegExp(
      r'onReceivedError: \(controller, request, error\) \{[\s\S]*?\n            \},',
    ).firstMatch(loginSystem)?.group(0);

    expect(checkUrlMethod, isNotNull);
    expect(
      checkUrlMethod,
      contains('if (!mounted)'),
      reason: 'WebView 迟到 URL 回调不应在页面销毁后继续记录状态或派发凭据。',
    );
    expect(
      checkUrlMethod,
      contains('_lastUrlWithoutJwxtToken == url'),
      reason:
          '同一无 token URL 可能被 shouldOverride/onLoadStart/onLoadStop 连续检查，应去重。',
    );
    expect(
      checkUrlMethod,
      contains('_lastUrlWithoutJwxtToken = url;'),
      reason: '无 token URL 应记录，避免重复解析同一跳转。',
    );
    expect(
      checkUrlMethod,
      contains('_lastUrlWithoutJwxtToken = null;'),
      reason: '发现可用 token 后应清理去重缓存，避免污染后续流程。',
    );

    expect(extractTokenMethod, isNotNull);
    expect(extractTokenMethod, contains('source.indexOf(_tokenQueryMarker)'));
    expect(extractTokenMethod, contains('_readTokenValue('));
    expect(
      extractTokenMethod,
      isNot(contains('RegExp')),
      reason: 'CAS URL token 提取会在 WebView 回调路径运行，不应重复创建正则。',
    );
    expect(readTokenMethod, isNotNull);
    expect(readTokenMethod, contains('source.codeUnitAt(index)'));
    expect(readTokenMethod, contains('_isTokenTerminator(codeUnit)'));
    expect(
      readTokenMethod,
      isNot(contains('RegExp')),
      reason: 'CAS token 值扫描应按终止字符读取，不应创建正则。',
    );
    expect(casHtmlTokenMethod, isNotNull);
    expect(
      casHtmlTokenMethod,
      contains('final token = _extractCasLoginTokenValue(html);'),
    );
    expect(
      casHtmlTokenMethod,
      isNot(contains('RegExp')),
      reason: 'CAS HTML token 提取应复用字符串扫描，避免登录完成回调额外正则分配。',
    );

    expect(setLoadingMethod, isNotNull);
    expect(
      setLoadingMethod,
      contains('if (!mounted || _isLoading == isLoading)'),
      reason: '登录 WebView 销毁后或加载态不变时不应通知加载遮罩重建。',
    );
    expect(
      setLoadingMethod,
      contains('_isLoadingNotifier.value = isLoading;'),
      reason: '登录 WebView 加载态应由统一方法通知加载遮罩。',
    );
    expect(
      setLoadingMethod,
      isNot(contains('setState(')),
      reason: '登录 WebView 加载态只影响遮罩层，不应 setState 重建 WebView。',
    );
    expect(
      loginSystem,
      contains(
        'final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(true);',
      ),
      reason: '登录 WebView 加载态应使用局部 notifier，避免重建底层 InAppWebView。',
    );
    expect(
      loginSystem,
      contains('bool get _isLoading => _isLoadingNotifier.value;'),
    );
    expect(loginSystem, contains('_isLoadingNotifier.dispose();'));
    expect(
      loginSystem,
      contains('valueListenable: _isLoadingNotifier'),
      reason: '登录 WebView 加载遮罩应通过 ValueListenableBuilder 局部刷新。',
    );

    expect(updateNavigationMethod, isNotNull);
    expect(
      updateNavigationMethod,
      contains('if (!mounted)'),
      reason: 'WebView 迟到导航状态回调不应在页面销毁后写入当前 URL。',
    );

    expect(htmlTokenMethod, isNotNull);
    expect(
      htmlTokenMethod,
      contains(
        'if (!mounted || controller == null || _hasDeliveredCredentials)',
      ),
      reason: 'HTML token 提取开始前应确认页面和 controller 仍有效。',
    );
    expect(
      htmlTokenMethod,
      contains('!identical(controller, _webViewController)'),
      reason: 'getHtml 晚返回时，旧 controller 的结果不应写入当前登录流程。',
    );
    expect(
      htmlTokenMethod,
      contains('if (mounted) {\n        AppLogger.debug'),
      reason: '页面销毁后的 HTML 读取异常不应继续写 UI 相关日志路径。',
    );

    expect(deliverMethod, isNotNull);
    expect(
      deliverMethod,
      contains(
        'if (!mounted || _hasDeliveredCredentials || _isDeliveringCredentials)',
      ),
      reason: '凭据派发入口应在页面销毁、已派发或正在派发时短路。',
    );
    expect(
      deliverMethod,
      contains('if (!mounted || _hasDeliveredCredentials)'),
      reason: '等待 cookie 后应再次确认页面仍存在，避免关闭页面后继续回调。',
    );
    expect(
      deliverMethod,
      contains('if (mounted && widget.onError != null)'),
      reason: '错误回调不应在页面销毁后继续触发。',
    );
    expect(
      deliverMethod,
      contains('hutLoginCredentialExtractionFailureMessage(error)'),
      reason: '凭据提取失败不应把底层异常字符串直接展示给用户。',
    );
    expect(
      deliverMethod,
      isNot(contains("'提取登录凭据失败：\$")),
      reason: '凭据提取失败提示不应拼接底层异常。',
    );

    expect(loginSystem, contains('void dispose()'));
    expect(
      loginSystem,
      contains('_webViewController = null;'),
      reason: '页面销毁时应清理 controller 引用，迟到异步结果可通过身份检查丢弃。',
    );

    expect(callbackSection, isNotNull);
    expect(callbackSection, contains('_updateNavigationState('));
    expect(
      callbackSection,
      isNot(contains('_isLoading = true')),
      reason: 'onLoadStart 不应无条件刷新加载层。',
    );
    expect(
      callbackSection,
      isNot(contains('_isLoading = false')),
      reason: 'onLoadStop/onReceivedError 不应无条件刷新加载层。',
    );
    expect(errorCallbackSection, isNotNull);
    expect(
      errorCallbackSection,
      contains('if (!mounted || !identical(controller, _webViewController))'),
      reason: 'WebView 错误回调迟到或来自旧 controller 时不应继续派发错误。',
    );
    expect(errorCallbackSection, contains('_setLoading(false);'));
    expect(
      errorCallbackSection,
      isNot(contains('_isLoading = false')),
      reason: 'onReceivedError 不应无条件刷新加载层。',
    );
    expect(
      errorCallbackSection,
      contains('hutLoginPageLoadFailureMessage(error)'),
      reason: '页面加载失败不应把 WebView 底层错误描述直接展示给用户。',
    );
    expect(
      errorCallbackSection,
      isNot(contains("'页面加载失败：\$")),
      reason: '页面加载失败提示不应拼接 WebView 错误描述。',
    );
  });

  test('unified login guards duplicate login and fallback work', () {
    final unifiedLogin =
        File('lib/login/unified_login_page.dart').readAsStringSync();
    final setLoadingMethod = RegExp(
      r'void _setLoading\(bool isLoading\)[\s\S]*?\n  void _finishLogin',
    ).firstMatch(unifiedLogin)?.group(0);
    final officialLoginMethod = RegExp(
      r'Future<bool> _tryOfficialJwxtLogin\(String reason\) async \{[\s\S]*?\n  Future<void> _loginWithCAS',
    ).firstMatch(unifiedLogin)?.group(0);
    final casLoginMethod = RegExp(
      r'Future<void> _loginWithCAS\(\) async \{[\s\S]*?\n  @override',
    ).firstMatch(unifiedLogin)?.group(0);

    expect(setLoadingMethod, isNotNull);
    expect(
      setLoadingMethod,
      contains('_isLoading == isLoading'),
      reason: '统一登录页加载态不变时不应通知按钮区域重建。',
    );
    expect(
      setLoadingMethod,
      contains('_isLoadingNotifier.value = isLoading;'),
      reason: '统一登录页加载态应由统一方法更新。',
    );
    expect(
      setLoadingMethod,
      isNot(contains('setState(')),
      reason: '统一登录页加载态只影响登录/游客按钮，不应整页 setState。',
    );
    expect(
      unifiedLogin,
      contains(
        'final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(false);',
      ),
      reason: '统一登录页加载态应使用局部 notifier，避免重建整个玻璃面板。',
    );
    expect(
      unifiedLogin,
      contains('bool get _isLoading => _isLoadingNotifier.value;'),
    );
    expect(unifiedLogin, contains('_isLoadingNotifier.dispose();'));
    expect(
      unifiedLogin,
      contains('valueListenable: _isLoadingNotifier'),
      reason: '统一登录页按钮区域应通过 ValueListenableBuilder 局部响应 loading。',
    );
    expect(
      unifiedLogin,
      isNot(contains('RepaintBoundary(')),
      reason: '统一登录页登录面板没有独立常驻动画，不应为整张玻璃面板额外建 repaint 边界。',
    );
    expect(
      unifiedLogin,
      isNot(contains('Opacity(')),
      reason: '统一登录页静态插图不应套整块 Opacity，避免登录页首屏多一层透明度合成。',
    );

    expect(officialLoginMethod, isNotNull);
    expect(
      unifiedLogin,
      contains('bool _isOpeningOfficialLogin = false;'),
      reason: '官方教务登录回退应有页面级 in-flight 标记。',
    );
    expect(
      officialLoginMethod,
      contains('if (_isOpeningOfficialLogin)'),
      reason: '官方教务登录页打开过程中不应重复 push。',
    );
    expect(officialLoginMethod, contains('_isOpeningOfficialLogin = true;'));
    expect(officialLoginMethod, contains('_isOpeningOfficialLogin = false;'));

    expect(casLoginMethod, isNotNull);
    expect(
      casLoginMethod,
      contains('if (_isLoading)'),
      reason: 'CAS 登录函数自身应防重复进入，不能只依赖按钮禁用。',
    );
    expect(casLoginMethod, contains('_setLoading(true);'));
    expect(casLoginMethod, contains('_setLoading(false);'));
    expect(
      casLoginMethod,
      isNot(contains('_isLoading = true')),
      reason: 'CAS 登录开始不应绕过统一加载态方法。',
    );
    expect(
      casLoginMethod,
      isNot(contains('_isLoading = false')),
      reason: 'CAS 登录结束不应绕过统一加载态方法。',
    );
  });

  test('legacy hut password encryption pads aes key without list slices', () {
    final pwdSource = File('lib/utils/pwd.dart').readAsStringSync();
    final formatObjectMethod = RegExp(
      r'String U\(dynamic data\) \{[\s\S]*?\n\}\n\n// 加密函数',
    ).firstMatch(pwdSource)?.group(0);
    final encryptPasswordMethod = RegExp(
      r'String encryptPassword\(String password, String key\) \{[\s\S]*?\n\}(?=\s*$)',
    ).firstMatch(pwdSource)?.group(0);

    expect(
      pwdSource,
      contains(r"final RegExp _unsafeObjectKeyPattern = RegExp(r'[^\w$]');"),
    );
    expect(formatObjectMethod, isNotNull);
    expect(
      formatObjectMethod,
      contains('for (final entry in data.entries)'),
      reason: '旧智慧工大密码格式化在同步路径执行，应直接遍历 entries，避免 forEach 闭包分配。',
    );
    expect(formatObjectMethod, contains('final key = entry.key;'));
    expect(formatObjectMethod, contains('final value = entry.value;'));
    expect(
      formatObjectMethod,
      contains('_unsafeObjectKeyPattern.hasMatch(key)'),
    );
    expect(formatObjectMethod, isNot(contains('.forEach(')));
    expect(formatObjectMethod, isNot(contains(r"RegExp(r'[^\w$]')")));

    expect(encryptPasswordMethod, isNotNull);
    expect(
      encryptPasswordMethod,
      contains('final sourceKeyBytes = utf8.encode(key);'),
    );
    expect(encryptPasswordMethod, contains('final keyBytes = Uint8List(16);'));
    expect(
      encryptPasswordMethod,
      contains('for (var index = 0; index < copyLength; index++)'),
      reason: '旧智慧工大登录加密在同步路径执行，应直接写入固定长度 key 缓冲，避免 take/toList 临时列表。',
    );
    expect(
      encryptPasswordMethod,
      contains('keyBytes[index] = sourceKeyBytes[index];'),
    );
    expect(
      encryptPasswordMethod,
      contains('final encryptKey = encrypt.Key(keyBytes);'),
    );
    expect(encryptPasswordMethod, isNot(contains('take(16)')));
    expect(encryptPasswordMethod, isNot(contains('.toList(')));
    expect(encryptPasswordMethod, isNot(contains('Uint8List.fromList')));
  });

  test('token display redirects only after save with mounted context', () {
    final tokenDisplay =
        File('lib/login/token_display_page.dart').readAsStringSync();
    final redirectMethod = RegExp(
      r'Future<void> _saveTokenAndMaybeRedirect\(\) async \{[\s\S]*?\n  @override',
    ).firstMatch(tokenDisplay)?.group(0);

    expect(tokenDisplay, contains('bool _hasScheduledHomeRedirect = false;'));
    expect(tokenDisplay, contains('unawaited(_saveTokenAndMaybeRedirect());'));
    expect(redirectMethod, isNotNull);
    expect(
      redirectMethod,
      contains('await (widget.saveTokenOverride ?? saveToken)(widget.token);'),
      reason: 'Token 展示页应先完成 token 保存，再安排首页重定向。',
    );
    expect(
      redirectMethod,
      contains('if (!mounted || _hasScheduledHomeRedirect)'),
      reason: '保存完成后页面已卸载或已安排跳转时，不应再次重定向。',
    );
    expect(redirectMethod, contains('_hasScheduledHomeRedirect = true;'));
    expect(
      redirectMethod,
      contains('WidgetsBinding.instance.addPostFrameCallback'),
      reason: '首页重定向仍应在首帧后执行，避免 initState 直接导航。',
    );
    expect(
      redirectMethod,
      contains('if (!mounted)'),
      reason: 'post-frame 回调执行时应再次检查页面是否仍挂载。',
    );
  });

  test('jwxt token renewal clears in-flight work through finally', () {
    final tokenSource = File('lib/utils/token.dart').readAsStringSync();
    final renewMethod = RegExp(
      r'Future<bool> renewToken\(BuildContext context\) \{[\s\S]*?\n\}',
    ).firstMatch(tokenSource)?.group(0);
    final loadRunnerMethod = RegExp(
      r'Future<bool> _runRenewTokenLoad\([\s\S]*?\nFuture<bool> _renewToken',
    ).firstMatch(tokenSource)?.group(0);

    expect(tokenSource, contains('Future<bool>? _renewTokenLoad;'));
    expect(renewMethod, isNotNull);
    expect(
      renewMethod,
      contains('final inFlight = _renewTokenLoad;'),
      reason: 'JWXT token 续期应复用正在进行的刷新，避免多个页面同时触发重复登录。',
    );
    expect(renewMethod, contains('return inFlight;'));
    expect(
      renewMethod,
      contains('load = _runRenewTokenLoad(context, () => load);'),
    );
    expect(renewMethod, contains('_renewTokenLoad = load;'));
    expect(
      renewMethod,
      isNot(contains('.whenComplete(')),
      reason: '共享刷新 Future 的清理应走统一 try/finally，不应挂在回调链上。',
    );

    expect(loadRunnerMethod, isNotNull);
    expect(loadRunnerMethod, contains('try {'));
    expect(loadRunnerMethod, contains('return await _renewToken(context);'));
    expect(loadRunnerMethod, contains('} finally {'));
    expect(
      loadRunnerMethod,
      contains('if (identical(_renewTokenLoad, currentLoad()))'),
      reason: '只有当前仍是同一批刷新 Future 时，才允许清空 in-flight 标记。',
    );
    expect(loadRunnerMethod, contains('_renewTokenLoad = null;'));
    expect(loadRunnerMethod, isNot(contains('.whenComplete(')));
  });

  test('hut cas login reuses id token loading work', () {
    final casLogin =
        File('lib/login/hut_cas_login_page.dart').readAsStringSync();
    final getTokenMethod = RegExp(
      r'Future<void> _getIdToken\(\) \{[\s\S]*?\n  Future<void> _loadIdToken',
    ).firstMatch(casLogin)?.group(0);
    final idTokenRunnerMethod = RegExp(
      r'Future<void> _runIdTokenLoad\([\s\S]*?\n  Future<void> _loadIdToken',
    ).firstMatch(casLogin)?.group(0);
    final loadTokenMethod = RegExp(
      r'Future<void> _loadIdToken\(\) async \{[\s\S]*?\n  void _retryGetIdToken',
    ).firstMatch(casLogin)?.group(0);
    final mountedTokenMethod = RegExp(
      r'Future<String\?> _loadMountedIdToken\(\) async \{[\s\S]*?\n  void _retryGetIdToken',
    ).firstMatch(casLogin)?.group(0);
    final tokenLoadStateMethod = RegExp(
      r'void _setTokenLoadState\(\{[\s\S]*?\n  // 保存获取到的新token和cookie',
    ).firstMatch(casLogin)?.group(0);
    final saveMethod = RegExp(
      r'Future<void> _saveTokenAndCookie\(Map<String, String> data\) async \{[\s\S]*?\n  @override',
    ).firstMatch(casLogin)?.group(0);
    final errorRetrySection = RegExp(
      r'final errorMessage = tokenLoadState.errorMessage;[\s\S]*?\n        return HutLoginSystem',
    ).firstMatch(casLogin)?.group(0);
    final tokenRetrieverClass = RegExp(
      r'class HutCasTokenRetriever \{[\s\S]*?\n\}',
    ).firstMatch(casLogin)?.group(0);
    final getJwxtTokenAndCookieMethod = RegExp(
      r'static Future<Map<String, String>\?> getJwxtTokenAndCookie\([\s\S]*?\n  static Future<Map<String, String>\?> _loadJwxtTokenAndCookie',
    ).firstMatch(casLogin)?.group(0);
    final jwxtTokenRunnerMethod = RegExp(
      r'static Future<Map<String, String>\?> _runJwxtTokenAndCookieLoad\([\s\S]*?\n  static Future<Map<String, String>\?> _loadJwxtTokenAndCookie',
    ).firstMatch(casLogin)?.group(0);
    final loadJwxtMethod = RegExp(
      r'static Future<Map<String, String>\?> _loadJwxtTokenAndCookie\([\s\S]*?\n  static Future<void> _completeJwxtTokenFromRoute',
    ).firstMatch(casLogin)?.group(0);
    final completeRouteMethod = RegExp(
      r'static Future<void> _completeJwxtTokenFromRoute\([\s\S]*?\n  static void setLoginPageBuilderForTest',
    ).firstMatch(casLogin)?.group(0);

    expect(getTokenMethod, isNotNull);
    expect(
      casLogin,
      contains('Future<void>? _idTokenLoad;'),
      reason: 'CAS 承载页应复用正在进行的 idToken 获取流程。',
    );
    expect(
      casLogin,
      contains('final ValueNotifier<_HutCasTokenLoadState> _tokenLoadState'),
      reason: 'CAS 承载页 token 加载态只影响加载/错误/WebView 入口，不应整页 setState。',
    );
    expect(casLogin, contains('ValueListenableBuilder<_HutCasTokenLoadState>'));
    expect(casLogin, contains('_tokenLoadState.dispose();'));
    expect(casLogin, contains('class _HutCasTokenLoadState'));
    expect(
      getTokenMethod,
      contains('final inFlight = _idTokenLoad;'),
      reason: '重复触发 idToken 获取时应先返回已有 Future。',
    );
    expect(getTokenMethod, contains('return inFlight;'));
    expect(getTokenMethod, contains('_idTokenLoad = load;'));
    expect(getTokenMethod, contains('load = _runIdTokenLoad(() => load);'));
    expect(
      getTokenMethod,
      isNot(contains('.whenComplete(')),
      reason: 'CAS 承载页 idToken in-flight 清理应走 try/finally，不应挂在回调链上。',
    );
    expect(idTokenRunnerMethod, isNotNull);
    expect(idTokenRunnerMethod, contains('try {'));
    expect(idTokenRunnerMethod, contains('await _loadIdToken();'));
    expect(idTokenRunnerMethod, contains('} finally {'));
    expect(
      idTokenRunnerMethod,
      contains('if (identical(_idTokenLoad, currentLoad()))'),
      reason: '只有当前仍是同一批 idToken Future 时，才允许清空加载标记。',
    );
    expect(idTokenRunnerMethod, contains('_idTokenLoad = null;'));
    expect(idTokenRunnerMethod, isNot(contains('.whenComplete(')));

    expect(loadTokenMethod, isNotNull);
    expect(
      loadTokenMethod,
      contains('await _loadMountedIdToken()'),
      reason: 'CAS 承载页 idToken 获取应集中到带 mounted 边界的 helper。',
    );
    expect(
      loadTokenMethod,
      contains('if (idToken == null)'),
      reason: '页面卸载后的 idToken 旧结果应直接丢弃。',
    );
    expect(
      loadTokenMethod,
      contains('if (!mounted)'),
      reason: 'idToken 获取失败后，若页面已卸载，不应再落错误态。',
    );
    expect(loadTokenMethod, contains('_setTokenLoadState(isLoading: false)'));
    expect(
      loadTokenMethod,
      contains('_setTokenLoadState('),
      reason: 'idToken 获取失败应通过统一状态方法落错误态。',
    );
    expect(
      loadTokenMethod,
      contains('errorMessage: _resolveIdTokenLoadErrorMessage(error),'),
      reason: 'idToken 获取失败不应把底层异常字符串直接展示给用户。',
    );
    expect(
      loadTokenMethod,
      isNot(contains("'获取统一认证令牌失败：\$")),
      reason: 'idToken 获取失败提示不应拼接底层异常。',
    );
    expect(
      loadTokenMethod,
      isNot(contains('_isLoading = false')),
      reason: 'idToken 获取流程不应绕过统一状态方法直接改加载态。',
    );

    expect(mountedTokenMethod, isNotNull);
    final mountedTokenText = mountedTokenMethod!;
    final validityIndex = mountedTokenText.indexOf(
      'final isValid = await _api.checkTokenValidity();',
    );
    final mountedAfterValidity = mountedTokenText.indexOf(
      'if (!mounted)',
      validityIndex,
    );
    final refreshIndex = mountedTokenText.indexOf(
      'final refreshed = await _api.refreshToken();',
    );
    final mountedAfterRefresh = mountedTokenText.indexOf(
      'if (!mounted)',
      refreshIndex,
    );
    final getTokenIndex = mountedTokenText.indexOf(
      'final idToken = await _api.getToken();',
    );
    final mountedAfterGetToken = mountedTokenText.indexOf(
      'if (!mounted)',
      getTokenIndex,
    );

    expect(validityIndex, isNot(-1));
    expect(mountedAfterValidity, greaterThan(validityIndex));
    expect(refreshIndex, isNot(-1));
    expect(mountedAfterRefresh, greaterThan(refreshIndex));
    expect(getTokenIndex, isNot(-1));
    expect(mountedAfterGetToken, greaterThan(getTokenIndex));

    expect(tokenLoadStateMethod, isNotNull);
    expect(
      tokenLoadStateMethod,
      contains('final currentState = _tokenLoadState.value;'),
    );
    expect(
      tokenLoadStateMethod,
      contains('currentState.isLoading == isLoading'),
      reason: 'CAS 承载页 token 加载态不变时不应触发局部通知。',
    );
    expect(
      tokenLoadStateMethod,
      contains('currentState.errorMessage == errorMessage'),
    );
    expect(
      tokenLoadStateMethod,
      contains('_tokenLoadState.value = _HutCasTokenLoadState('),
    );
    expect(tokenLoadStateMethod, contains('isLoading: isLoading,'));
    expect(tokenLoadStateMethod, contains('errorMessage: errorMessage,'));
    expect(tokenLoadStateMethod, isNot(contains('setState(')));

    expect(saveMethod, isNotNull);
    final saveMethodText = saveMethod!;
    final saveSessionIndex = saveMethodText.indexOf(
      'await prefs.saveJwxtSession(token: token, cookie: myClientTicket);',
    );
    final mountedBeforeCallback = saveMethodText.indexOf(
      'if (!mounted)',
      saveSessionIndex,
    );
    final callbackIndex = saveMethodText.indexOf(
      'widget.onLoginComplete!',
      mountedBeforeCallback,
    );
    final popIndex = saveMethodText.indexOf(
      'Navigator.of(',
      mountedBeforeCallback,
    );

    expect(saveSessionIndex, isNot(-1));
    expect(
      mountedBeforeCallback,
      greaterThan(saveSessionIndex),
      reason: 'CAS 会话保存完成后，继续回调或返回前应再次检查页面是否仍挂载。',
    );
    expect(callbackIndex, greaterThan(mountedBeforeCallback));
    expect(popIndex, greaterThan(mountedBeforeCallback));

    expect(errorRetrySection, isNotNull);
    expect(
      errorRetrySection,
      contains('onPressed: _retryGetIdToken'),
      reason: '错误页重试按钮应走带 in-flight 保护的统一入口。',
    );
    expect(
      errorRetrySection,
      isNot(contains('_getIdToken();')),
      reason: '错误页不应直接再次发起 idToken 获取。',
    );

    expect(tokenRetrieverClass, isNotNull);
    expect(
      tokenRetrieverClass,
      contains('Future<Map<String, String>?>? _jwxtTokenAndCookieLoad;'),
      reason: 'CAS token 检索应复用正在进行的登录页打开流程。',
    );
    expect(getJwxtTokenAndCookieMethod, isNotNull);
    expect(
      getJwxtTokenAndCookieMethod,
      contains('final inFlight = _jwxtTokenAndCookieLoad;'),
      reason: '重复触发 CAS token 检索时应先返回已有 Future。',
    );
    expect(getJwxtTokenAndCookieMethod, contains('return inFlight;'));
    expect(
      getJwxtTokenAndCookieMethod,
      contains('load = _runJwxtTokenAndCookieLoad(context, () => load);'),
    );
    expect(
      getJwxtTokenAndCookieMethod,
      contains('_jwxtTokenAndCookieLoad = load;'),
    );
    expect(
      getJwxtTokenAndCookieMethod,
      isNot(contains('.whenComplete(')),
      reason: 'CAS token 检索 in-flight 清理应走 try/finally，不应挂在回调链上。',
    );
    expect(jwxtTokenRunnerMethod, isNotNull);
    expect(jwxtTokenRunnerMethod, contains('try {'));
    expect(
      jwxtTokenRunnerMethod,
      contains('return await _loadJwxtTokenAndCookie(context);'),
    );
    expect(jwxtTokenRunnerMethod, contains('} finally {'));
    expect(
      jwxtTokenRunnerMethod,
      contains('if (identical(_jwxtTokenAndCookieLoad, currentLoad()))'),
      reason: '只有当前仍是同一批 JWXT token/cookie Future 时，才允许清空加载标记。',
    );
    expect(jwxtTokenRunnerMethod, contains('_jwxtTokenAndCookieLoad = null;'));
    expect(jwxtTokenRunnerMethod, isNot(contains('.whenComplete(')));
    expect(loadJwxtMethod, isNotNull);
    expect(
      loadJwxtMethod,
      contains('final routeResult = Navigator.of(context).push('),
      reason: 'CAS token 检索应先保存 route Future，再交给统一 helper 处理返回结果。',
    );
    expect(
      loadJwxtMethod,
      contains(
        'unawaited(_completeJwxtTokenFromRoute(routeResult, completeOnce));',
      ),
      reason: 'route 结果处理应集中到 helper，避免散落 then 回调。',
    );
    expect(
      loadJwxtMethod,
      isNot(contains('.then((value)')),
      reason: 'CAS token 检索不应在导航调用后串未审计的 then 回调。',
    );
    expect(completeRouteMethod, isNotNull);
    expect(
      completeRouteMethod,
      contains('final value = await routeResult;'),
      reason: 'route 返回结果应在 async helper 内等待并归一化。',
    );
    expect(completeRouteMethod, contains('Map<String, String>.from(value)'));
  });

  test('official webview login keeps auto login polling bounded', () {
    final webviewLogin =
        File('lib/login/webview_login_screen.dart').readAsStringSync();
    final tokenMessageMethod = RegExp(
      r'Future<void> _handleTokenMessage\(String token\) async \{[\s\S]*?\n  void _handleLoginError',
    ).firstMatch(webviewLogin)?.group(0);
    final loginErrorMethod = RegExp(
      r'void _handleLoginError\(String message\) \{[\s\S]*?\n  Future<void> _injectLoginHooks',
    ).firstMatch(webviewLogin)?.group(0);
    final timeoutSection = RegExp(
      r'void _startTimeoutTimer\(\) \{[\s\S]*?\n  Future<void> _handleTokenMessage',
    ).firstMatch(webviewLogin)?.group(0);
    final timeoutSetterMethod = RegExp(
      r'void _setAutoLoginTimedOut\(\) \{[\s\S]*?\n  Future<void> _handleTokenMessage',
    ).firstMatch(webviewLogin)?.group(0);
    final injectHooksMethod = RegExp(
      r'Future<void> _injectLoginHooks\(\) async \{[\s\S]*?\n  Future<void> _attemptAutoLogin',
    ).firstMatch(webviewLogin)?.group(0);
    final autoLoginMethod = RegExp(
      r'Future<void> _attemptAutoLogin\(\) async \{[\s\S]*?\n  Widget _buildStatusBanner',
    ).firstMatch(webviewLogin)?.group(0);
    final statusBannerMethod = RegExp(
      r'Widget _buildStatusBanner\(BuildContext context, bool autoLoginTimedOut\) \{[\s\S]*?\n  void _closePage',
    ).firstMatch(webviewLogin)?.group(0);
    final pageFinishedCallback = RegExp(
      r'onPageFinished: \(url\) async \{[\s\S]*?\n              \},',
    ).firstMatch(webviewLogin)?.group(0);

    expect(timeoutSection, isNotNull);
    expect(
      timeoutSection,
      contains('_timeoutTimer?.cancel();'),
      reason: '重新启动官方登录超时计时器前应取消旧 timer，避免重复超时提示。',
    );
    expect(
      timeoutSection,
      contains('_setAutoLoginTimedOut();'),
      reason: '官方登录自动登录超时应通过统一方法更新状态，避免重复刷新。',
    );
    expect(
      timeoutSection,
      contains('if (!mounted || _autoLoginTimedOut)'),
      reason: '自动登录超时状态不变时不应重复通知横幅重建。',
    );
    expect(timeoutSetterMethod, isNotNull);
    expect(
      timeoutSetterMethod,
      contains('_autoLoginTimedOutNotifier.value = true;'),
      reason: '官方登录自动登录超时只影响顶部提示横幅，不应重建底层 WebView。',
    );
    expect(
      timeoutSetterMethod,
      isNot(contains('setState(')),
      reason: '官方登录自动登录超时不应整页 setState。',
    );
    expect(
      webviewLogin,
      contains('_autoLoginTimedOutNotifier = ValueNotifier<bool>('),
      reason: '官方登录自动登录超时状态应由局部 notifier 持有。',
    );
    expect(
      webviewLogin,
      contains(
        'bool get _autoLoginTimedOut => _autoLoginTimedOutNotifier.value;',
      ),
    );
    expect(webviewLogin, contains('_autoLoginTimedOutNotifier.dispose();'));

    expect(tokenMessageMethod, isNotNull);
    expect(
      tokenMessageMethod,
      contains('!widget.navigateToCoursePageOnSuccess'),
      reason: '官方登录承载页显式关闭成功后跳首页时，应只 pop 结果给调用方。',
    );
    expect(
      tokenMessageMethod,
      contains('buildHomePageRoute(initialIndex: 0)'),
      reason: '默认成功登录仍应进入首页，保持现有入口行为。',
    );

    expect(
      webviewLogin,
      contains(
        "const String officialWebViewLoginFailureMessage = '登录失败，请稍后重试';",
      ),
    );
    expect(
      webviewLogin,
      contains('String resolveOfficialWebViewLoginErrorMessage(Object? _)'),
    );
    expect(loginErrorMethod, isNotNull);
    expect(
      loginErrorMethod,
      contains('resolveOfficialWebViewLoginErrorMessage(message)'),
      reason: '官方 WebView 登录失败提示不应透出页面脚本或接口原始 message。',
    );
    expect(loginErrorMethod, isNot(contains("'登录失败：\$message'")));

    expect(injectHooksMethod, isNotNull);
    expect(
      injectHooksMethod,
      contains('window.__superhutLoginHooksInstalled'),
      reason: '官方登录 XHR/fetch hook 应在页面内幂等安装。',
    );

    expect(autoLoginMethod, isNotNull);
    expect(
      autoLoginMethod,
      contains('if (!mounted || _hasHandledResult || _autoLoginTimedOut)'),
      reason: '页面卸载、结果已处理或自动登录超时后不应继续向 WebView 注入自动登录轮询。',
    );
    expect(
      autoLoginMethod,
      contains('window.__superhutAutoLoginAttempting'),
      reason: '页面内自动登录轮询应有进行中标记，避免多次 onPageFinished 叠加循环。',
    );
    expect(
      autoLoginMethod,
      contains('var attemptsLeft = 15;'),
      reason: '找不到登录表单时应限制轮询次数，避免后台长期空转。',
    );
    expect(autoLoginMethod, contains('attemptsLeft -= 1;'));
    expect(autoLoginMethod, contains('attemptsLeft <= 0'));
    expect(
      autoLoginMethod,
      contains('window.__superhutAutoLoginAttempting = false;'),
      reason: '轮询结束或失败后应清理进行中标记。',
    );
    expect(
      autoLoginMethod,
      contains("const eventTypes = ['input', 'change', 'blur'];"),
      reason: '自动填表仍需按 input/change/blur 顺序通知页面框架。',
    );
    expect(
      autoLoginMethod,
      contains('for (let index = 0; index < eventTypes.length; index += 1)'),
      reason: 'WebView 自动填表脚本应直接循环派发事件，避免数组 forEach 闭包。',
    );
    expect(autoLoginMethod, contains('const eventType = eventTypes[index];'));
    expect(autoLoginMethod, contains('element.dispatchEvent(event);'));
    expect(autoLoginMethod, isNot(contains('.forEach(')));

    expect(statusBannerMethod, isNotNull);
    expect(
      statusBannerMethod,
      contains('bool autoLoginTimedOut'),
      reason: '顶部状态横幅应从局部 builder 接收状态，避免直接依赖整页 setState。',
    );
    expect(statusBannerMethod, isNot(contains('_autoLoginTimedOut')));
    expect(
      webviewLogin,
      contains('valueListenable: _autoLoginTimedOutNotifier'),
      reason: '官方登录自动登录超时提示应通过 ValueListenableBuilder 局部刷新。',
    );
    expect(
      webviewLogin,
      contains('return _buildStatusBanner(context, autoLoginTimedOut);'),
    );

    expect(pageFinishedCallback, isNotNull);
    final pageFinishedCallbackText = pageFinishedCallback!;
    expect(
      pageFinishedCallbackText,
      contains('if (!mounted || _hasHandledResult || _autoLoginTimedOut)'),
      reason: '页面加载完成回调在页面卸载、结果已处理或超时后不应继续注入脚本。',
    );
    expect(pageFinishedCallbackText, contains('await _injectLoginHooks();'));
    expect(pageFinishedCallbackText, contains('await _attemptAutoLogin();'));
    expect(
      pageFinishedCallbackText.indexOf('if (!mounted || _hasHandledResult'),
      lessThan(pageFinishedCallbackText.indexOf('await _injectLoginHooks();')),
      reason: '注入登录 hook 前应先检查旧回调是否仍然有效。',
    );
    expect(
      pageFinishedCallbackText.lastIndexOf('if (!mounted || _hasHandledResult'),
      greaterThan(
        pageFinishedCallbackText.indexOf('await _injectLoginHooks();'),
      ),
      reason: 'hook 注入完成后、自动登录前应再次检查旧回调是否仍然有效。',
    );
  });

  test('widget action navigation is guarded against duplicate pushes', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final handleActionMethod = RegExp(
      r'void _handleWidgetAction\(String actionType\) \{[\s\S]*?\n  Widget\? _buildWidgetActionPage',
    ).firstMatch(mainSource)?.group(0);
    final trackActionRouteMethod = RegExp(
      r'Future<void> _trackWidgetActionRoute\([\s\S]*?\n  Widget\? _buildWidgetActionPage',
    ).firstMatch(mainSource)?.group(0);
    final buildActionPageMethod = RegExp(
      r'Widget\? _buildWidgetActionPage\(String actionType\) \{[\s\S]*?\n  Future<String\?> _consumeInitialWidgetAction',
    ).firstMatch(mainSource)?.group(0);

    expect(
      mainSource,
      contains('final Set<String> _pendingWidgetActions = <String>{};'),
      reason: '小组件系统回调可能在同一帧重复到达，应记录待执行 action。',
    );
    expect(
      mainSource,
      contains('final Set<String> _activeWidgetActionRoutes = <String>{};'),
      reason: '小组件打开的功能页未关闭前，不应再次打开同一功能页。',
    );

    expect(handleActionMethod, isNotNull);
    expect(
      handleActionMethod,
      contains('final normalizedAction = actionType.trim();'),
    );
    expect(handleActionMethod, contains('normalizedAction.isEmpty'));
    expect(
      handleActionMethod,
      contains('_pendingWidgetActions.contains(normalizedAction)'),
    );
    expect(
      handleActionMethod,
      contains('_activeWidgetActionRoutes.contains(normalizedAction)'),
    );
    expect(
      handleActionMethod,
      contains('_pendingWidgetActions.add(normalizedAction);'),
    );
    expect(
      handleActionMethod,
      contains('_pendingWidgetActions.remove(normalizedAction);'),
    );
    expect(
      handleActionMethod,
      contains('if (!mounted)'),
      reason: '延迟到下一帧执行系统回调时应先确认 app 仍挂载。',
    );
    expect(
      handleActionMethod,
      contains("normalizedAction == 'course'"),
      reason: '课程小组件入口应回到首页课表，不压入额外功能页。',
    );
    expect(handleActionMethod, contains('buildHomePageRoute(initialIndex: 0)'));
    expect(
      handleActionMethod,
      contains('_activeWidgetActionRoutes.add(normalizedAction);'),
    );
    expect(
      handleActionMethod,
      contains('unawaited(_trackWidgetActionRoute(normalizedAction, route));'),
      reason: '小组件功能页关闭后的 active 标记清理应集中到 async helper。',
    );
    expect(
      handleActionMethod,
      isNot(contains('.whenComplete(')),
      reason: '小组件功能页 active 标记不应通过 whenComplete 回调链清理。',
    );
    expect(
      handleActionMethod,
      contains('buildAppPageRoute<void>(builder: (_) => targetPage)'),
      reason: '小组件功能页跳转应走共享轻量路由。',
    );
    expect(trackActionRouteMethod, isNotNull);
    expect(trackActionRouteMethod, contains('try {'));
    expect(trackActionRouteMethod, contains('await route;'));
    expect(trackActionRouteMethod, contains('} finally {'));
    expect(
      trackActionRouteMethod,
      contains('_activeWidgetActionRoutes.remove(actionType);'),
      reason: '小组件功能页无论正常关闭还是异常完成，都必须释放 active 标记。',
    );
    expect(trackActionRouteMethod, isNot(contains('.whenComplete(')));

    expect(buildActionPageMethod, isNotNull);
    expect(buildActionPageMethod, contains("'drink' => FunctionDrinkPage()"));
    expect(buildActionPageMethod, contains("'bath' => FunctionHotWaterPage()"));
    expect(
      buildActionPageMethod,
      contains("'electricity' => ElectricityPage()"),
    );
    expect(buildActionPageMethod, contains("'score' => JumpToScorePage()"));
  });

  test('startup state resolution keeps local course cache check linear', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final localCourseCacheMethod = RegExp(
      r'Future<bool> _hasLocalCourseCacheOnStartup\(\) async \{[\s\S]*?\n  Future<void> _resolveStartupState',
    ).firstMatch(mainSource)?.group(0);
    final resolveStartupStateMethod = RegExp(
      r'Future<void> _resolveStartupState\(\) async \{[\s\S]*?\n  @override\n  Widget build',
    ).firstMatch(mainSource)?.group(0);

    expect(localCourseCacheMethod, isNotNull);
    expect(
      localCourseCacheMethod,
      contains('if (!widget.resolveCourseStateOnStartup)'),
      reason: '启动时禁用课表状态解析时不应读取本地课表缓存。',
    );
    expect(
      localCourseCacheMethod,
      contains('final courseData = await loadClassFromLocal();'),
      reason: '首屏启动链路应使用直线 async/await，避免在 Future.wait 中嵌入回调链。',
    );
    expect(localCourseCacheMethod, contains('return courseData.isNotEmpty;'));
    expect(
      localCourseCacheMethod,
      isNot(contains('.then(')),
      reason: '本地课表缓存启动判断不应重新引入 then 回调链。',
    );

    expect(resolveStartupStateMethod, isNotNull);
    expect(
      resolveStartupStateMethod,
      contains('_hasLocalCourseCacheOnStartup(),'),
    );
    expect(
      resolveStartupStateMethod,
      isNot(contains('loadClassFromLocal().then')),
      reason: '启动状态聚合只应组合明确 Future，不应内联课表缓存回调转换。',
    );
  });

  test('course local cache parsing avoids mapped course lists', () {
    final courseMain =
        File('lib/utils/course/coursemain.dart').readAsStringSync();
    final parseCourseListMethod = RegExp(
      r'List<Course> _parseCourseList\(List rawCourses\) \{[\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);
    final parseCourseDataMethod = RegExp(
      r'Map<String, List<Course>> _parseCourseDataMap\([\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);
    final parseSchedulesMethod = RegExp(
      r'List<SavedCourseSchedule> _parseSavedCourseSchedules\([\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);
    final parseWidgetEntriesMethod = RegExp(
      r'List<CourseWidgetCourseEntry> _parseWidgetCourseEntries\([\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);
    final sanitizeCoursesMethod = RegExp(
      r'List<Course> _sanitizeCoursesForShare\(List<Course> courses\) \{[\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);
    final encodeCoursesMethod = RegExp(
      r'List<Map<String, dynamic>> _encodeCourses\(List<Course> courses\) \{[\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);
    final encodeSavedSchedulesMethod = RegExp(
      r'List<Map<String, dynamic>> _encodeSavedCourseSchedules\([\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);
    final encodeWidgetEntriesMethod = RegExp(
      r'List<Map<String, dynamic>> _encodeWidgetCourseEntries\([\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);
    final savedScheduleFromJson = RegExp(
      r'factory SavedCourseSchedule.fromJson\([\s\S]*?\n  Map<String, dynamic> toJson',
    ).firstMatch(courseMain)?.group(0);
    final savedScheduleShareJson = RegExp(
      r'Map<String, dynamic> toShareJson\(\) \{[\s\S]*?\n  SavedCourseSchedule copyWith',
    ).firstMatch(courseMain)?.group(0);
    final archiveFromJson = RegExp(
      r'factory CourseScheduleArchive.fromJson\([\s\S]*?\n  Map<String, dynamic> toJson',
    ).firstMatch(courseMain)?.group(0);
    final archiveToJson = RegExp(
      r'class CourseScheduleArchive \{[\s\S]*?Map<String, dynamic> toJson\(\) \{[\s\S]*?\n  CourseScheduleArchive copyWith',
    ).firstMatch(courseMain)?.group(0);
    final widgetStoreToJson = RegExp(
      r'class CourseWidgetStore \{[\s\S]*?Map<String, dynamic> toJson\(\) \{[\s\S]*?\n  factory CourseWidgetStore.fromJson',
    ).firstMatch(courseMain)?.group(0);
    final widgetStoreFromJson = RegExp(
      r'factory CourseWidgetStore.fromJson\([\s\S]*?\nclass CourseWidgetPayload',
    ).firstMatch(courseMain)?.group(0);
    final widgetPayloadToJson = RegExp(
      r'class CourseWidgetPayload \{[\s\S]*?Map<String, dynamic> toJson\(\) \{[\s\S]*?\n  factory CourseWidgetPayload.fromJson',
    ).firstMatch(courseMain)?.group(0);
    final widgetPayloadFromJson = RegExp(
      r'factory CourseWidgetPayload.fromJson\([\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);
    final encodeCourseDataMethod = RegExp(
      r'Map<String, List<Map<String, dynamic>>> _encodeCourseDataMap\([\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);
    final readCourseDataMethod = RegExp(
      r'Future<Map<String, List<Course>>> readCourseDataFromJson\([\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);

    expect(parseCourseListMethod, isNotNull);
    expect(
      parseCourseListMethod,
      contains('final courses = <Course>[];'),
      reason: '本地课表课程列表解析应显式构建结果，避免 map/toList 临时链。',
    );
    expect(
      parseCourseListMethod,
      contains('for (final rawCourse in rawCourses)'),
    );
    expect(parseCourseListMethod, contains('courses.add('));
    expect(parseCourseListMethod, isNot(contains('.map(')));
    expect(parseCourseListMethod, isNot(contains('.toList(')));

    expect(parseCourseDataMethod, isNotNull);
    expect(
      parseCourseDataMethod,
      contains('for (final entry in rawCourseData.entries)'),
    );
    expect(
      parseCourseDataMethod,
      contains('_parseCourseListOrEmpty(entry.value)'),
    );
    expect(parseCourseDataMethod, isNot(contains('.map(')));
    expect(parseCourseDataMethod, isNot(contains('.toList(')));

    expect(parseSchedulesMethod, isNotNull);
    expect(
      parseSchedulesMethod,
      contains('final schedules = <SavedCourseSchedule>[];'),
    );
    expect(
      parseSchedulesMethod,
      contains('for (final rawSchedule in rawSchedules)'),
    );
    expect(parseSchedulesMethod, contains('schedules.add('));
    expect(parseSchedulesMethod, isNot(contains('.map(')));
    expect(parseSchedulesMethod, isNot(contains('.toList(')));

    expect(parseWidgetEntriesMethod, isNotNull);
    expect(
      parseWidgetEntriesMethod,
      contains('final courses = <CourseWidgetCourseEntry>[];'),
    );
    expect(
      parseWidgetEntriesMethod,
      contains('for (final rawCourse in rawCourses)'),
    );
    expect(parseWidgetEntriesMethod, contains('courses.add('));
    expect(parseWidgetEntriesMethod, isNot(contains('.map(')));
    expect(parseWidgetEntriesMethod, isNot(contains('.toList(')));

    expect(sanitizeCoursesMethod, isNotNull);
    expect(
      sanitizeCoursesMethod,
      contains('final sanitizedCourses = <Course>[];'),
    );
    expect(sanitizeCoursesMethod, contains('for (final course in courses)'));
    expect(
      sanitizeCoursesMethod,
      contains('sanitizedCourses.add(course.sanitizedForShare());'),
    );
    expect(sanitizeCoursesMethod, isNot(contains('.map(')));
    expect(sanitizeCoursesMethod, isNot(contains('.toList(')));

    expect(encodeCoursesMethod, isNotNull);
    expect(
      encodeCoursesMethod,
      contains('final encodedCourses = <Map<String, dynamic>>[];'),
    );
    expect(encodeCoursesMethod, contains('for (final course in courses)'));
    expect(
      encodeCoursesMethod,
      contains('encodedCourses.add(course.toJson());'),
    );
    expect(encodeCoursesMethod, isNot(contains('.map(')));
    expect(encodeCoursesMethod, isNot(contains('.toList(')));

    expect(encodeSavedSchedulesMethod, isNotNull);
    expect(
      encodeSavedSchedulesMethod,
      contains('final encodedSchedules = <Map<String, dynamic>>[];'),
    );
    expect(
      encodeSavedSchedulesMethod,
      contains('for (final schedule in schedules)'),
    );
    expect(
      encodeSavedSchedulesMethod,
      contains('encodedSchedules.add(schedule.toJson());'),
    );
    expect(encodeSavedSchedulesMethod, isNot(contains('.map(')));
    expect(encodeSavedSchedulesMethod, isNot(contains('.toList(')));

    expect(encodeWidgetEntriesMethod, isNotNull);
    expect(
      encodeWidgetEntriesMethod,
      contains('final encodedCourses = <Map<String, dynamic>>[];'),
    );
    expect(
      encodeWidgetEntriesMethod,
      contains('for (final course in courses)'),
    );
    expect(
      encodeWidgetEntriesMethod,
      contains('encodedCourses.add(course.toJson());'),
    );
    expect(encodeWidgetEntriesMethod, isNot(contains('.map(')));
    expect(encodeWidgetEntriesMethod, isNot(contains('.toList(')));

    expect(savedScheduleFromJson, isNotNull);
    expect(
      savedScheduleFromJson,
      contains("courseData: _parseCourseDataMap(json['courseData'])"),
    );
    expect(savedScheduleFromJson, isNot(contains('.map(')));
    expect(savedScheduleFromJson, isNot(contains('.toList(')));

    expect(savedScheduleShareJson, isNotNull);
    expect(
      savedScheduleShareJson,
      contains('for (final entry in courseData.entries)'),
      reason: '分享课表编码应直接遍历 entries，避免 forEach 闭包。',
    );
    expect(
      savedScheduleShareJson,
      contains('_sanitizeCoursesForShare(entry.value)'),
      reason: '分享课表编码应显式循环脱敏课程，避免 map/toList 临时链。',
    );
    expect(savedScheduleShareJson, contains('sharedCourseData[entry.key]'));
    expect(savedScheduleShareJson, isNot(contains('.forEach(')));
    expect(savedScheduleShareJson, isNot(contains('.map(')));
    expect(savedScheduleShareJson, isNot(contains('.toList(')));

    expect(archiveFromJson, isNotNull);
    expect(
      archiveFromJson,
      contains('schedules: _parseSavedCourseSchedules(rawSchedules)'),
    );
    expect(archiveFromJson, isNot(contains('.map(')));
    expect(archiveFromJson, isNot(contains('.toList(')));

    expect(archiveToJson, isNotNull);
    expect(
      archiveToJson,
      contains("'schedules': _encodeSavedCourseSchedules(schedules),"),
      reason: '课表归档编码应通过显式循环 helper 构建 schedules JSON。',
    );
    expect(archiveToJson, isNot(contains('schedules.map')));
    expect(archiveToJson, isNot(contains('.toList(')));

    expect(widgetStoreToJson, isNotNull);
    expect(
      widgetStoreToJson,
      contains('final encodedDays = <String, dynamic>{};'),
    );
    expect(widgetStoreToJson, contains('for (final entry in days.entries)'));
    expect(
      widgetStoreToJson,
      contains('final encodedDayCourses = <String, dynamic>{};'),
    );
    expect(
      widgetStoreToJson,
      contains('for (final entry in dayCourses.entries)'),
    );
    expect(
      widgetStoreToJson,
      contains('_encodeWidgetCourseEntries(entry.value)'),
      reason: '小组件 store 编码应显式循环构建每日课程 JSON。',
    );
    expect(widgetStoreToJson, isNot(contains('.map(')));
    expect(widgetStoreToJson, isNot(contains('.toList(')));

    expect(widgetStoreFromJson, isNotNull);
    expect(widgetStoreFromJson, contains('_parseWidgetCourseEntriesOrEmpty('));
    expect(
      widgetStoreFromJson,
      contains('courseData: _parseCourseDataMap(legacyCourseData)'),
    );
    expect(widgetStoreFromJson, isNot(contains('.map(')));
    expect(widgetStoreFromJson, isNot(contains('.toList(')));

    expect(widgetPayloadToJson, isNotNull);
    expect(
      widgetPayloadToJson,
      contains("'courses': _encodeWidgetCourseEntries(courses),"),
      reason: '小组件紧凑 payload 编码应通过显式循环 helper 构建课程 JSON。',
    );
    expect(widgetPayloadToJson, isNot(contains('.map(')));
    expect(widgetPayloadToJson, isNot(contains('.toList(')));

    expect(widgetPayloadFromJson, isNotNull);
    expect(
      widgetPayloadFromJson,
      contains('courses: _parseWidgetCourseEntries(rawCourses)'),
    );
    expect(widgetPayloadFromJson, isNot(contains('.map(')));
    expect(widgetPayloadFromJson, isNot(contains('.toList(')));

    expect(encodeCourseDataMethod, isNotNull);
    expect(
      encodeCourseDataMethod,
      contains('for (final entry in courseData.entries)'),
      reason: '课表数据编码应显式遍历日期和课程列表。',
    );
    expect(encodeCourseDataMethod, contains('_encodeCourses(entry.value)'));
    expect(encodeCourseDataMethod, isNot(contains('.map(')));
    expect(encodeCourseDataMethod, isNot(contains('.toList(')));

    expect(readCourseDataMethod, isNotNull);
    expect(
      readCourseDataMethod,
      contains('for (final entry in jsonData.entries)'),
    );
    expect(
      readCourseDataMethod,
      contains('_parseCourseList(entry.value as List)'),
    );
    expect(readCourseDataMethod, isNot(contains('.map(')));
    expect(readCourseDataMethod, isNot(contains('.toList(')));
  });

  test('course import parse errors use controlled messages', () {
    final courseMain =
        File('lib/utils/course/coursemain.dart').readAsStringSync();
    final courseTableView =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final parseShareCodeMethod = RegExp(
      r'SavedCourseSchedule parseCourseScheduleShareCode\(String rawCode\) \{[\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);
    final parseFileMethod = RegExp(
      r'SavedCourseSchedule parseCourseScheduleExportJsonString\(String rawJson\) \{[\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);
    String memberSlice(String source, String startMarker, String endMarker) {
      final startIndex = source.indexOf(startMarker);
      expect(startIndex, isNot(-1), reason: '找不到方法起点 $startMarker');
      final endIndex = source.indexOf(endMarker, startIndex);
      expect(endIndex, isNot(-1), reason: '找不到方法终点 $endMarker');
      return source.substring(startIndex, endIndex);
    }

    final importShareCodeMethod = memberSlice(
      courseTableView,
      'Future<void> _importScheduleFromShareCode(',
      'Future<void> _showManualImportDialog(',
    );
    final importFileMethod = memberSlice(
      courseTableView,
      'Future<void> _importScheduleFromFile()',
      'Future<String?> _pickImportFileContent()',
    );
    final normalizeShareCodeMethod = memberSlice(
      courseMain,
      'String _normalizeCourseShareCode(',
      'String _normalizeBase64Payload(',
    );

    expect(
      courseMain,
      contains(
        "const String courseScheduleShareCodeParseFailureMessage = '分享码解析失败，请检查分享码后重试';",
      ),
    );
    expect(
      courseMain,
      contains(
        "const String courseScheduleFileParseFailureMessage = '课表文件解析失败，请确认文件内容后重试';",
      ),
    );
    expect(
      courseMain,
      contains('class CourseScheduleImportException extends FormatException'),
    );
    expect(
      courseMain,
      contains("throw const CourseScheduleImportException('未识别到工大盒子课表分享码')"),
      reason: '导入分享码缺少前缀属于受控业务错误，可以继续给出明确提示。',
    );

    expect(parseShareCodeMethod, isNotNull);
    expect(parseShareCodeMethod, contains('on CourseScheduleImportException'));
    expect(
      parseShareCodeMethod,
      contains('courseScheduleShareCodeParseFailureMessage'),
    );
    expect(parseShareCodeMethod, isNot(contains("'分享码解析失败：\$error'")));
    expect(parseShareCodeMethod, isNot(contains('\$error')));

    expect(parseFileMethod, isNotNull);
    expect(parseFileMethod, contains('on CourseScheduleImportException'));
    expect(parseFileMethod, contains('courseScheduleFileParseFailureMessage'));
    expect(parseFileMethod, isNot(contains("'课表文件解析失败：\$error'")));
    expect(parseFileMethod, isNot(contains('\$error')));

    expect(
      importShareCodeMethod,
      contains('courseScheduleShareCodeParseFailureMessage'),
    );
    expect(importShareCodeMethod, isNot(contains('error.message')));

    expect(importFileMethod, contains('courseScheduleFileParseFailureMessage'));
    expect(importFileMethod, isNot(contains('error.message')));

    expect(normalizeShareCodeMethod, contains('StringBuffer()'));
    expect(normalizeShareCodeMethod, contains('rawCode.codeUnitAt(index)'));
    expect(
      normalizeShareCodeMethod,
      contains('_isCourseShareCodeWhitespace(codeUnit)'),
    );
    expect(normalizeShareCodeMethod, isNot(contains('RegExp')));
    expect(normalizeShareCodeMethod, isNot(contains('replaceAll')));
  });

  test('course widget payload builds compact course lists without mapped chains', () {
    final courseMain =
        File('lib/utils/course/coursemain.dart').readAsStringSync();
    final widgetDataHelper =
        File('lib/utils/widget_data_helper.dart').readAsStringSync();
    final saveCourseDataForWidgetMethod = RegExp(
      r'static Future<bool> saveCourseDataForWidget\([\s\S]*?\n  /// 示例方法',
    ).firstMatch(widgetDataHelper)?.group(0);
    final timeOnDateMethod = RegExp(
      r'DateTime\? _timeOnDate\(DateTime date, String timeLabel\) \{[\s\S]*?\nint\? _parseTimeLabelPart',
    ).firstMatch(courseMain)?.group(0);
    final parseTimeLabelPartMethod = RegExp(
      r'int\? _parseTimeLabelPart\(String timeLabel, int start, int end\) \{[\s\S]*?\nDateTime\? _courseEndsAt',
    ).firstMatch(courseMain)?.group(0);
    final remainingCoursesMethod = RegExp(
      r'List<CourseWidgetCourseEntry> _remainingCoursesForDate\([\s\S]*?\nList<CourseWidgetCourseEntry> _firstWidgetCourseEntries',
    ).firstMatch(courseMain)?.group(0);
    final firstWidgetEntriesMethod = RegExp(
      r'List<CourseWidgetCourseEntry> _firstWidgetCourseEntries\([\s\S]*?\nList<CourseWidgetCourseEntry> _resolveStoreDayCourses',
    ).firstMatch(courseMain)?.group(0);
    final findNextCourseDateAfterInStoreMethod = RegExp(
      r'DateTime\? _findNextCourseDateAfterInStore\([\s\S]*?\nCourseWidgetPayload _buildEmptyCourseWidgetPayload',
    ).firstMatch(courseMain)?.group(0);
    final displayEntriesMethod = RegExp(
      r'List<CourseWidgetCourseEntry> _displayEntriesForCourses\([\s\S]*?\nList<CourseWidgetCourseEntry> _firstDisplayEntries',
    ).firstMatch(courseMain)?.group(0);
    final firstDisplayEntriesMethod = RegExp(
      r'List<CourseWidgetCourseEntry> _firstDisplayEntries\([\s\S]*?\nDateTime\? _findNextCourseDateAfter',
    ).firstMatch(courseMain)?.group(0);
    final findNextCourseDateAfterMethod = RegExp(
      r'DateTime\? _findNextCourseDateAfter\([\s\S]*?\nCourseWidgetPayload _buildCourseWidgetPayloadForDate',
    ).firstMatch(courseMain)?.group(0);
    final storePayloadMethod = RegExp(
      r'CourseWidgetPayload _buildRelevantCourseWidgetPayloadFromStore\([\s\S]*?\nString _formatMonthDay',
    ).firstMatch(courseMain)?.group(0);
    final rawPayloadMethod = RegExp(
      r'CourseWidgetPayload _buildCourseWidgetPayloadForDate\([\s\S]*?\nCourseWidgetStore buildCourseWidgetStoreFromRawData',
    ).firstMatch(courseMain)?.group(0);
    final storeBuildMethod = RegExp(
      r'CourseWidgetStore buildCourseWidgetStoreFromRawData\([\s\S]*?\nCourseWidgetStore buildCourseWidgetStore',
    ).firstMatch(courseMain)?.group(0);
    final findFirstCourseDateMethod = RegExp(
      r'String _findFirstCourseDate\(Map<String, List<Course>> courseData\) \{[\s\S]*?\n\}',
    ).firstMatch(courseMain)?.group(0);

    expect(timeOnDateMethod, isNotNull);
    expect(timeOnDateMethod, contains("timeLabel == '--:--'"));
    expect(
      timeOnDateMethod,
      contains("final separatorIndex = timeLabel.indexOf(':');"),
    );
    expect(
      timeOnDateMethod,
      contains("timeLabel.indexOf(':', separatorIndex + 1) != -1"),
      reason: '小组件今日剩余课程会反复解析节次结束时间，应扫描冒号位置，避免 split 产生临时列表。',
    );
    expect(
      timeOnDateMethod,
      contains('_parseTimeLabelPart(timeLabel, 0, separatorIndex)'),
    );
    expect(timeOnDateMethod, isNot(contains(".split(':')")));
    expect(parseTimeLabelPartMethod, isNotNull);
    expect(parseTimeLabelPartMethod, contains('timeLabel.codeUnitAt(index)'));
    expect(parseTimeLabelPartMethod, contains('codeUnit < 0x30'));
    expect(parseTimeLabelPartMethod, contains('codeUnit > 0x39'));
    expect(
      parseTimeLabelPartMethod,
      contains('value = value * 10 + codeUnit - 0x30;'),
    );

    expect(remainingCoursesMethod, isNotNull);
    expect(
      remainingCoursesMethod,
      contains('final remaining = <CourseWidgetCourseEntry>[];'),
      reason: '小组件今日剩余课程过滤应显式循环，避免 where/toList 临时链。',
    );
    expect(remainingCoursesMethod, contains('for (final course in sorted)'));
    expect(remainingCoursesMethod, contains('remaining.add(course);'));
    expect(remainingCoursesMethod, isNot(contains('.where(')));
    expect(remainingCoursesMethod, isNot(contains('.toList()')));

    expect(firstWidgetEntriesMethod, isNotNull);
    expect(
      firstWidgetEntriesMethod,
      contains('final limit = courses.length < 2 ? courses.length : 2;'),
      reason: '从 store 读取小组件课程时应直接复制前两项，不应 take/toList。',
    );
    expect(
      firstWidgetEntriesMethod,
      contains('for (var index = 0; index < limit; index++)'),
    );
    expect(firstWidgetEntriesMethod, contains('entries.add(courses[index]);'));
    expect(firstWidgetEntriesMethod, isNot(contains('take(2)')));
    expect(firstWidgetEntriesMethod, isNot(contains('.toList()')));

    expect(findNextCourseDateAfterInStoreMethod, isNotNull);
    expect(
      findNextCourseDateAfterInStoreMethod,
      contains('DateTime? nextCourseDate;'),
    );
    expect(
      findNextCourseDateAfterInStoreMethod,
      contains('void considerDateKey(String dateKey)'),
    );
    expect(
      findNextCourseDateAfterInStoreMethod,
      contains('for (final dateKey in store.dayCourses.keys)'),
      reason: '小组件 store 查找下个课程日应扫描日期 key，避免为每次刷新排序整表日期。',
    );
    expect(
      findNextCourseDateAfterInStoreMethod,
      contains('for (final entry in store.days.entries)'),
      reason: '小组件 store fallback 查找同样应显式遍历 entries，避免 forEach 闭包。',
    );
    expect(
      findNextCourseDateAfterInStoreMethod,
      contains('final payload = entry.value;'),
    );
    expect(
      findNextCourseDateAfterInStoreMethod,
      contains('considerDateKey(entry.key);'),
    );
    expect(
      findNextCourseDateAfterInStoreMethod,
      contains('parsedDate.isBefore(currentNextCourseDate)'),
    );
    expect(findNextCourseDateAfterInStoreMethod, isNot(contains('.forEach(')));
    expect(findNextCourseDateAfterInStoreMethod, isNot(contains('.toList(')));
    expect(findNextCourseDateAfterInStoreMethod, isNot(contains('..sort()')));
    expect(
      findNextCourseDateAfterInStoreMethod,
      isNot(contains('actualDateKeys')),
    );

    expect(displayEntriesMethod, isNotNull);
    expect(displayEntriesMethod, contains('for (final course in courses)'));
    expect(displayEntriesMethod, contains('_buildDisplayEntry('));
    expect(displayEntriesMethod, isNot(contains('.map(')));
    expect(displayEntriesMethod, isNot(contains('.toList()')));

    expect(firstDisplayEntriesMethod, isNotNull);
    expect(
      firstDisplayEntriesMethod,
      contains('final limit = courses.length < 2 ? courses.length : 2;'),
      reason: '从原始课表构建紧凑 payload 时应直接构建前两项，不应 take/map/toList。',
    );
    expect(
      firstDisplayEntriesMethod,
      contains('for (var index = 0; index < limit; index++)'),
    );
    expect(firstDisplayEntriesMethod, contains('courses[index]'));
    expect(firstDisplayEntriesMethod, isNot(contains('take(2)')));
    expect(firstDisplayEntriesMethod, isNot(contains('.map(')));
    expect(firstDisplayEntriesMethod, isNot(contains('.toList()')));

    expect(findNextCourseDateAfterMethod, isNotNull);
    expect(
      findNextCourseDateAfterMethod,
      contains('DateTime? nextCourseDate;'),
    );
    expect(
      findNextCourseDateAfterMethod,
      contains('for (final entry in courseData.entries)'),
      reason: '原始课表查找下个课程日应单次扫描日期 entry，不应先复制并排序所有 key。',
    );
    expect(findNextCourseDateAfterMethod, contains('entry.value.isEmpty'));
    expect(
      findNextCourseDateAfterMethod,
      contains('parsedDate.isBefore(currentNextCourseDate)'),
    );
    expect(findNextCourseDateAfterMethod, isNot(contains('keys.toList')));
    expect(findNextCourseDateAfterMethod, isNot(contains('..sort()')));

    expect(storePayloadMethod, isNotNull);
    expect(
      storePayloadMethod,
      contains('courses: _firstWidgetCourseEntries(todayCourses),'),
    );
    expect(
      storePayloadMethod,
      contains('courses: _firstWidgetCourseEntries(tomorrowCourses),'),
    );
    expect(
      storePayloadMethod,
      contains('courses: _firstWidgetCourseEntries(nextCourses),'),
    );
    expect(storePayloadMethod, isNot(contains('take(2)')));

    expect(rawPayloadMethod, isNotNull);
    expect(
      rawPayloadMethod,
      contains(
        'courses: _firstDisplayEntries(todayCourses, includeDatePrefix: false),',
      ),
    );
    expect(
      rawPayloadMethod,
      contains(
        'courses: _firstDisplayEntries(tomorrowCourses, includeDatePrefix: false),',
      ),
    );
    expect(rawPayloadMethod, contains('courses: _firstDisplayEntries('));
    expect(rawPayloadMethod, contains('includeDatePrefix: true'));
    expect(rawPayloadMethod, isNot(contains('take(2)')));
    expect(rawPayloadMethod, isNot(contains('.map(')));

    expect(storeBuildMethod, isNotNull);
    expect(
      storeBuildMethod,
      contains('for (final entry in courseData.entries)'),
      reason:
          '小组件 store 构建应直接扫描课表日期 entry，避免为 dayCourses 或 fallback days 复制并排序整表 key。',
    );
    expect(storeBuildMethod, contains('final dateKey = entry.key;'));
    expect(
      storeBuildMethod,
      contains('dayCourses[dateKey] = _displayEntriesForCourses('),
      reason: '小组件 store 的整日课程展示项应走显式循环 helper。',
    );
    expect(storeBuildMethod, isNot(contains('sortedActualDateKeys')));
    expect(storeBuildMethod, isNot(contains('sortedDateKeys')));
    expect(storeBuildMethod, isNot(contains('keys.toList')));
    expect(storeBuildMethod, isNot(contains('..sort()')));

    expect(findFirstCourseDateMethod, isNotNull);
    expect(findFirstCourseDateMethod, contains("var firstDate = '';"));
    expect(
      findFirstCourseDateMethod,
      contains('for (final dateKey in courseData.keys)'),
    );
    expect(findFirstCourseDateMethod, contains('dateKey.compareTo(firstDate)'));
    expect(findFirstCourseDateMethod, isNot(contains('keys.toList')));
    expect(findFirstCourseDateMethod, isNot(contains('..sort()')));

    expect(saveCourseDataForWidgetMethod, isNotNull);
    expect(
      saveCourseDataForWidgetMethod,
      contains('final normalizedCourses = <Course>[];'),
      reason: '小组件保存入口应显式归一化课程列表，避免 map/toList 临时链。',
    );
    expect(
      saveCourseDataForWidgetMethod,
      contains('for (final entry in courseData.entries)'),
      reason: '小组件保存入口应直接遍历 entries，避免 forEach 闭包。',
    );
    expect(
      saveCourseDataForWidgetMethod,
      contains('final courses = entry.value;'),
    );
    expect(
      saveCourseDataForWidgetMethod,
      contains('for (final course in courses)'),
    );
    expect(saveCourseDataForWidgetMethod, contains('normalizedCourses.add('));
    expect(
      saveCourseDataForWidgetMethod,
      contains('Course('),
      reason: '小组件保存入口应直接构造 Course，避免每门课先复制 Map 再走 fromJson。',
    );
    expect(
      saveCourseDataForWidgetMethod,
      contains('normalizedCourseData[entry.key] = normalizedCourses;'),
    );
    expect(saveCourseDataForWidgetMethod, isNot(contains('.forEach(')));
    expect(
      saveCourseDataForWidgetMethod,
      isNot(contains('Map<String, dynamic>.from')),
    );
    expect(saveCourseDataForWidgetMethod, isNot(contains('Course.fromJson')));
    expect(saveCourseDataForWidgetMethod, isNot(contains('.map(')));
    expect(saveCourseDataForWidgetMethod, isNot(contains('.toList()')));
  });

  test('course week pager coalesces pending post-frame moves', () {
    final courseTable =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final moveWeekMethod = RegExp(
      r'void _moveWeekPagerTo\(int targetWeek, \{bool animated = false\}\) \{[\s\S]*?\n  void _syncWeekPageToCurrentWeek',
    ).firstMatch(courseTable)?.group(0);

    expect(
      courseTable,
      contains('class _PendingWeekPageMove'),
      reason: '周分页控制器未挂载时，应保存待执行移动目标而不是重复排多个闭包。',
    );
    expect(
      courseTable,
      contains('bool _weekPageMovePending = false;'),
      reason: '周分页 post-frame move 应有 pending 标记。',
    );
    expect(
      courseTable,
      contains('_PendingWeekPageMove? _pendingWeekPageMove;'),
      reason: '连续跳周请求应合并到最新目标。',
    );

    expect(moveWeekMethod, isNotNull);
    expect(moveWeekMethod, contains('if (_weekPageController.hasClients)'));
    expect(
      moveWeekMethod,
      contains('_pendingWeekPageMove = _PendingWeekPageMove('),
      reason: 'PageController 未挂载时应先记录最新目标页。',
    );
    expect(
      moveWeekMethod,
      contains('if (_weekPageMovePending)'),
      reason: '已有下一帧移动任务时不应继续追加 addPostFrameCallback。',
    );
    expect(moveWeekMethod, contains('_weekPageMovePending = true;'));
    expect(
      moveWeekMethod,
      contains('WidgetsBinding.instance.addPostFrameCallback'),
    );
    expect(moveWeekMethod, contains('_weekPageMovePending = false;'));
    expect(
      moveWeekMethod,
      contains('final pendingMove = _pendingWeekPageMove;'),
      reason: '下一帧执行时应读取最新合并后的移动目标。',
    );
    expect(moveWeekMethod, contains('_pendingWeekPageMove = null;'));
    expect(
      moveWeekMethod,
      contains(
        'move(pendingMove.targetPage, withAnimation: pendingMove.animated);',
      ),
      reason: '下一帧只应执行合并后的最新周分页移动。',
    );
  });

  test('course week warmup drops stale post-frame work', () {
    final courseTable =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final applyDisplayedWeekMethod = RegExp(
      r'void _applyDisplayedWeek\(int targetWeek\) \{[\s\S]*?\n  void _moveWeekPagerTo',
    ).firstMatch(courseTable)?.group(0);
    final clearCacheMethod = RegExp(
      r'void _clearWeekPlacementCache\(\) \{[\s\S]*?\n  String _buildWeekPlacementCacheKey',
    ).firstMatch(courseTable)?.group(0);
    final scheduleWarmupMethod = RegExp(
      r'void _scheduleWeekPlacementWarmup\([\s\S]*?\n  /\*',
    ).firstMatch(courseTable)?.group(0);

    expect(
      courseTable,
      contains('int _weekPlacementWarmupGeneration = 0;'),
      reason: '周布局预热应有 generation，避免状态变化后继续执行旧 post-frame 任务。',
    );
    expect(applyDisplayedWeekMethod, isNotNull);
    expect(
      applyDisplayedWeekMethod,
      contains('_invalidateWeekPlacementWarmup();'),
      reason: '切换显示周时旧的相邻周预热目标应失效。',
    );
    expect(clearCacheMethod, isNotNull);
    expect(
      clearCacheMethod,
      contains('_invalidateWeekPlacementWarmup();'),
      reason: '清理周缓存时应让已排队的预热回调失效。',
    );
    expect(scheduleWarmupMethod, isNotNull);
    expect(
      scheduleWarmupMethod,
      contains('final targetWeeks = <int>['),
      reason: '相邻周预热目标最多三项，应直接用顺序列表，避免 Set/List/sort 临时分配。',
    );
    expect(
      scheduleWarmupMethod,
      contains('var needsWarmup = false;'),
      reason: '预热必要性判断应显式短路扫描，避免 targetWeeks.any 闭包。',
    );
    expect(
      scheduleWarmupMethod,
      contains('for (final weekNumber in targetWeeks)'),
    );
    expect(scheduleWarmupMethod, contains('needsWarmup = true;'));
    expect(
      scheduleWarmupMethod,
      contains('break;'),
      reason: '发现任一缺失缓存后应立即停止扫描。',
    );
    expect(
      scheduleWarmupMethod,
      isNot(contains('targetWeeks.any')),
      reason: 'build 期间不应为预热判断创建 any 闭包。',
    );
    expect(
      scheduleWarmupMethod,
      isNot(contains('.toList()')),
      reason: '相邻周预热目标不应通过 toList 额外物化。',
    );
    expect(
      scheduleWarmupMethod,
      isNot(contains('..sort()')),
      reason: '相邻周预热目标顺序应在构造时确定，不应再排序。',
    );
    expect(
      scheduleWarmupMethod,
      contains('final warmupGeneration = _weekPlacementWarmupGeneration;'),
      reason: '排队预热时应捕获当前 generation。',
    );
    expect(
      scheduleWarmupMethod,
      contains('warmupGeneration != _weekPlacementWarmupGeneration'),
      reason: 'post-frame 预热执行前应丢弃旧 generation。',
    );
  });

  test('course qr scanner flash state follows camera status', () {
    final courseTable =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final scannerPageClass = RegExp(
      r'class _CourseShareQrScannerPage extends StatefulWidget \{[\s\S]*$',
    ).firstMatch(courseTable)?.group(0);

    expect(scannerPageClass, isNotNull);
    expect(
      scannerPageClass,
      contains('bool _isTogglingFlash = false;'),
      reason: '课表扫码页闪光灯切换应防重复，避免快速连点堆叠相机命令。',
    );
    expect(
      scannerPageClass,
      contains(
        'final ValueNotifier<bool> _isFlashOnNotifier = ValueNotifier<bool>(false);',
      ),
      reason: '课表扫码页闪光灯图标只应局部刷新，避免重建 QRView。',
    );
    expect(
      scannerPageClass,
      contains('_isFlashOnNotifier.dispose();'),
      reason: '课表扫码页闪光灯局部状态应随页面释放。',
    );
    expect(scannerPageClass, contains('ValueListenableBuilder<bool>'));
    expect(scannerPageClass, contains('valueListenable: _isFlashOnNotifier'));
    expect(scannerPageClass, contains('Future<void> _toggleFlash() async'));
    expect(scannerPageClass, contains('if (_isTogglingFlash)'));
    expect(scannerPageClass, contains('_isTogglingFlash = true;'));
    expect(scannerPageClass, contains('await controller.toggleFlash();'));
    expect(
      scannerPageClass,
      contains('final current = await controller.getFlashStatus() ?? false;'),
      reason: '闪光灯按钮状态应以相机返回的真实状态为准。',
    );
    expect(
      scannerPageClass,
      contains('if (!mounted || _isFlashOnNotifier.value == current)'),
      reason: '页面销毁或闪光灯状态未变化时不应触发局部 rebuild。',
    );
    expect(scannerPageClass, contains('_isFlashOnNotifier.value = current;'));
    expect(
      scannerPageClass,
      isNot(contains('setState(')),
      reason: '闪光灯图标变化不应 setState 重建课表扫码页相机视图。',
    );
    expect(scannerPageClass, contains('_isTogglingFlash = false;'));
    expect(scannerPageClass, contains('onPressed: _toggleFlash'));
    expect(scannerPageClass, contains('_isScanning = false;'));
    expect(
      scannerPageClass,
      contains('Navigator.of(context).pop(code);'),
      reason: '课表扫码成功后页面会立即返回分享码。',
    );
    final scannerPageText = scannerPageClass!;
    final scanSuccessIndex = scannerPageText.indexOf('_isScanning = false;');
    final scanPopIndex = scannerPageText.indexOf(
      'Navigator.of(context).pop(code);',
    );
    final scanSetStateIndex = scannerPageText.indexOf(
      'setState(()',
      scanSuccessIndex,
    );
    expect(scanSuccessIndex, isNot(-1));
    expect(scanPopIndex, greaterThan(scanSuccessIndex));
    expect(
      scanSetStateIndex == -1 || scanSetStateIndex > scanPopIndex,
      isTrue,
      reason: '课表扫码成功只需本地标志防重复处理，不应在即将 pop 的路径里重建扫码页。',
    );
    expect(
      scannerPageClass,
      isNot(contains('_isFlashOn = !_isFlashOn')),
      reason: '课表扫码页不应乐观翻转本地状态，避免与真实相机状态不一致。',
    );
  });

  test('course table hot paths avoid DateFormat allocation', () {
    final courseTable =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final dateKeyCheckMethod = RegExp(
      r'bool _isCourseDateKey\(String value\) \{[\s\S]*?\n\}',
    ).firstMatch(courseTable)?.group(0);
    final calculateSchoolWeekMethod = RegExp(
      r'int calculateSchoolWeek\(String\? firstDayString, \{DateTime\? now\}\) \{[\s\S]*?\n  int _resolveCurrentWeek',
    ).firstMatch(courseTable)?.group(0);
    final sanitizeFileNameMethod = RegExp(
      r'String _sanitizeFileNameSegment\(String value\) \{[\s\S]*?\n  String _buildExportFileName',
    ).firstMatch(courseTable)?.group(0);

    expect(
      courseTable,
      isNot(contains("package:intl/intl.dart")),
      reason: '课程表 build/cache 热路径不应依赖 DateFormat 创建格式化器。',
    );
    expect(
      courseTable,
      isNot(contains('DateFormat(')),
      reason: '课程表日期 key、周标题和表头日期应使用轻量格式化 helper。',
    );
    expect(courseTable, contains('String _formatCourseDateKey(DateTime date)'));
    expect(
      courseTable,
      contains('String _formatCourseMonthDay(DateTime date)'),
    );

    expect(dateKeyCheckMethod, isNotNull);
    expect(dateKeyCheckMethod, contains('_isCourseAsciiDigitAt(value, 0)'));
    expect(dateKeyCheckMethod, contains('value.codeUnitAt(4) == 0x2D'));
    expect(dateKeyCheckMethod, isNot(contains('RegExp')));

    expect(calculateSchoolWeekMethod, isNotNull);
    expect(
      calculateSchoolWeekMethod,
      contains('if (!_isCourseDateKey(firstDayString))'),
    );
    expect(
      calculateSchoolWeekMethod,
      isNot(contains('RegExp')),
      reason: '课表周数计算会在加载和重载路径调用，日期 key 校验不应重复创建正则。',
    );

    expect(sanitizeFileNameMethod, isNotNull);
    expect(sanitizeFileNameMethod, contains('final buffer = StringBuffer();'));
    expect(sanitizeFileNameMethod, contains('trimmed.codeUnitAt(index)'));
    expect(
      sanitizeFileNameMethod,
      contains('_isCourseFileNameWhitespace(codeUnit)'),
    );
    expect(
      sanitizeFileNameMethod,
      contains('_isUnsafeCourseFileNameCodeUnit(codeUnit)'),
    );
    expect(
      sanitizeFileNameMethod,
      isNot(contains('replaceAll')),
      reason: '课表导出文件名清洗应单次扫描，避免连续 replaceAll 产生临时字符串。',
    );
    expect(
      sanitizeFileNameMethod,
      isNot(contains('RegExp')),
      reason: '课表导出文件名清洗不应为每次导出创建正则。',
    );
  });

  test('course schedule reload reuses one current time value', () {
    final courseTable =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final reloadMethod = RegExp(
      r'Future<bool> _reloadScheduleState\(\) async \{[\s\S]*?\n  Future<void> _loadInitialData',
    ).firstMatch(courseTable)?.group(0);
    final currentTermMethod = RegExp(
      r'bool _isScheduleCurrentTerm\([\s\S]*?\n  int _resolveCurrentWeekForSchedule',
    ).firstMatch(courseTable)?.group(0);
    final currentWeekMethod = RegExp(
      r'int _resolveCurrentWeekForSchedule\([\s\S]*?\n  DateTime _buildInitialDateForSchedule',
    ).firstMatch(courseTable)?.group(0);
    final initialDateMethod = RegExp(
      r'DateTime _buildInitialDateForSchedule\([\s\S]*?\n  String _buildScheduleStatusLabel',
    ).firstMatch(courseTable)?.group(0);
    final hasSameReloadStateMethod = RegExp(
      r'bool _hasSameScheduleReloadState\([\s\S]*?\n  void _applyTodayDateIfChanged',
    ).firstMatch(courseTable)?.group(0);
    final applyTodayDateMethod = RegExp(
      r'void _applyTodayDateIfChanged\(DateTime todayDate\) \{[\s\S]*?\n  bool _hasSameScheduleList',
    ).firstMatch(courseTable)?.group(0);
    final hasSameScheduleListMethod = RegExp(
      r'bool _hasSameScheduleList\([\s\S]*?\n  bool _hasSameSavedSchedule',
    ).firstMatch(courseTable)?.group(0);
    final hasSameCourseDataMethod = RegExp(
      r'bool _hasSameCourseData\([\s\S]*?\n  bool _hasSameCourseList',
    ).firstMatch(courseTable)?.group(0);

    expect(reloadMethod, isNotNull);
    final reloadText = reloadMethod!;
    expect(
      'DateTime.now()'.allMatches(reloadText).length,
      1,
      reason: '同一轮课表重载应只读取一次当前时间，避免边界日/午夜时刻结果不一致。',
    );
    expect(reloadText, contains('final reloadNow = DateTime.now();'));
    expect(reloadText, contains('now: reloadNow'));
    expect(
      reloadText,
      contains('isCurrentTermSchedule: isCurrentTermSchedule'),
    );
    expect(reloadText, contains('reloadNow,'));
    expect(
      reloadText,
      contains('if (_hasSameScheduleReloadState('),
      reason: '同内容课表重载应在清缓存和 setState 前短路，避免重复刷新导致整页重建。',
    );
    expect(
      reloadText.indexOf('if (_hasSameScheduleReloadState('),
      lessThan(reloadText.indexOf('_clearWeekPlacementCache();')),
      reason: '课表重载同值短路必须早于布局缓存清理。',
    );
    expect(
      reloadText.indexOf('if (_hasSameScheduleReloadState('),
      lessThan(reloadText.indexOf('setState(() {')),
      reason: '课表重载同值短路必须早于整页 setState。',
    );
    expect(
      reloadText,
      contains('_applyTodayDateIfChanged(todayDate);'),
      reason: '同内容重载仍应刷新 today 状态，避免跨日后课程表高亮停留在旧日期。',
    );

    expect(currentTermMethod, isNotNull);
    expect(currentTermMethod, contains('required DateTime now'));
    expect(
      currentTermMethod,
      isNot(contains('DateTime.now()')),
      reason: '当前学期判断应复用课表重载传入的当前时间。',
    );

    expect(currentWeekMethod, isNotNull);
    expect(currentWeekMethod, contains('required DateTime now'));
    expect(currentWeekMethod, contains('required bool isCurrentTermSchedule'));
    expect(
      currentWeekMethod,
      contains('_resolveCurrentWeek(schedule.firstDay, now: now)'),
    );
    expect(
      currentWeekMethod,
      isNot(contains('DateTime.now()')),
      reason: '当前周计算应复用课表重载传入的当前时间。',
    );

    expect(initialDateMethod, isNotNull);
    expect(initialDateMethod, contains('DateTime now,'));
    expect(initialDateMethod, contains('return _startOfMonday(now);'));
    expect(
      initialDateMethod,
      isNot(contains('getMondayOfCurrentWeek(refreshWidget: false)')),
      reason: '缺失课表日期时也应复用本轮重载的当前时间，不应再次读取当前周。',
    );

    expect(hasSameReloadStateMethod, isNotNull);
    expect(hasSameReloadStateMethod, contains('_isInitialLoadComplete'));
    expect(
      hasSameReloadStateMethod,
      contains('_hasSameScheduleList(_savedSchedules, savedSchedules)'),
      reason: '课表归档即使重新解析成新对象，只要内容相同也应短路。',
    );
    expect(
      hasSameReloadStateMethod,
      contains('_activeSchedule?.id == activeSchedule?.id'),
    );
    expect(
      hasSameReloadStateMethod,
      contains('_currentRealWeek == currentRealWeek'),
    );
    expect(
      hasSameReloadStateMethod,
      isNot(contains('todayDate')),
      reason: '实际今天变化不应破坏同内容短路，否则后台刷新会把用户正在看的周拉回当前周。',
    );
    expect(
      hasSameReloadStateMethod,
      isNot(contains('_currentWeek ==')),
      reason: '后台重载同内容时不应把用户正在浏览的周强行拉回当前周。',
    );

    expect(applyTodayDateMethod, isNotNull);
    expect(
      applyTodayDateMethod,
      contains('if (!mounted || _isSameDay(_todayDate, todayDate))'),
      reason: 'today 状态同值时不应触发课程表重建。',
    );
    expect(
      courseTable,
      contains('late final ValueNotifier<DateTime> _todayDateNotifier'),
      reason: 'today 高亮状态应由局部 notifier 驱动，避免跨日刷新重建整页课表。',
    );
    expect(courseTable, contains('_todayDateNotifier.dispose();'));
    expect(applyTodayDateMethod, contains('_todayDate = todayDate;'));
    expect(
      applyTodayDateMethod,
      contains('_todayDateNotifier.value = todayDate;'),
    );
    expect(
      applyTodayDateMethod,
      isNot(contains('setState(')),
      reason: '跨日只需要刷新课程网格高亮，不应触发页面级 setState。',
    );
    expect(
      applyTodayDateMethod,
      isNot(contains('_currentWeek')),
      reason: '跨日只更新今天高亮状态，不应改变用户正在浏览的周。',
    );

    expect(hasSameScheduleListMethod, isNotNull);
    expect(
      hasSameScheduleListMethod,
      contains('for (var index = 0; index < left.length; index++)'),
      reason: '课表列表比较应显式按下标扫描，避免 map/toList 临时对象。',
    );
    expect(hasSameScheduleListMethod, isNot(contains('.map(')));
    expect(hasSameScheduleListMethod, isNot(contains('.toList()')));

    expect(hasSameCourseDataMethod, isNotNull);
    expect(
      hasSameCourseDataMethod,
      contains('for (final entry in left.entries)'),
    );
    expect(
      hasSameCourseDataMethod,
      contains('_hasSameCourseList(entry.value, rightCourses)'),
    );
    expect(hasSameCourseDataMethod, isNot(contains('.map(')));
    expect(hasSameCourseDataMethod, isNot(contains('.toList()')));
  });

  test('course experiment visibility skips unchanged rebuilds', () {
    final courseTable =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final setExperimentMethod = RegExp(
      r'Future<void> _setShowExperimentCourses\(bool value\) async \{[\s\S]*?\n  void _applyShowExperimentCoursesIfChanged',
    ).firstMatch(courseTable)?.group(0);
    final applyExperimentMethod = RegExp(
      r'void _applyShowExperimentCoursesIfChanged\(bool value\) \{[\s\S]*?\n  /\*',
    ).firstMatch(courseTable)?.group(0);
    final contentMethod = RegExp(
      r'Widget _buildCourseTableContent\(BuildContext context\) \{[\s\S]*?\n  static const List<_SectionTime>',
    ).firstMatch(courseTable)?.group(0);
    final placementCacheKeyMethod = RegExp(
      r'String _buildWeekPlacementCacheKey\([\s\S]*?\n  bool _hasWeekPlacementCache',
    ).firstMatch(courseTable)?.group(0);

    expect(
      courseTable,
      contains('late final ValueNotifier<bool> _showExperimentCoursesNotifier'),
      reason: '实验课显示开关应使用局部 notifier，避免点击工具栏时整页 setState。',
    );
    expect(courseTable, contains('_showExperimentCoursesNotifier.dispose();'));

    expect(setExperimentMethod, isNotNull);
    final setExperimentText = setExperimentMethod!;
    expect(
      setExperimentText.indexOf('if (_showExperimentCourses == value)'),
      lessThan(setExperimentText.indexOf('SharedPreferences.getInstance()')),
      reason: '实验课显示开关同值回调应先短路，避免重复写 prefs 和整页重建。',
    );
    expect(
      setExperimentText,
      contains('_applyShowExperimentCoursesIfChanged(value);'),
      reason: '异步写入返回后仍应通过 helper 复核状态再提交 UI 更新。',
    );
    expect(
      setExperimentText,
      isNot(contains('setState(()')),
      reason: '持久化入口不应直接重建课程表，应由状态 helper 按需处理。',
    );

    expect(applyExperimentMethod, isNotNull);
    expect(
      applyExperimentMethod,
      contains('_showExperimentCoursesNotifier.value == value'),
      reason: '页面销毁后或开关值未变化时不应触发课程表局部重建。',
    );
    expect(applyExperimentMethod, contains('_clearWeekPlacementCache();'));
    expect(applyExperimentMethod, contains('_showExperimentCourses = value;'));
    expect(
      applyExperimentMethod,
      contains('_showExperimentCoursesNotifier.value = value;'),
    );
    expect(
      applyExperimentMethod,
      isNot(contains('setState(()')),
      reason: '实验课显示开关只影响工具栏和课表内容，不应触发整页重建。',
    );

    expect(contentMethod, isNotNull);
    expect(
      contentMethod,
      contains('valueListenable: _showExperimentCoursesNotifier'),
      reason: '课表内容区域应局部监听实验课显示状态。',
    );
    expect(
      contentMethod,
      contains('showExperimentCourses: showExperimentCourses'),
    );

    expect(placementCacheKeyMethod, isNotNull);
    expect(
      placementCacheKeyMethod,
      contains('bool showExperimentCourses'),
      reason: '布局缓存键应显式包含实验课显示状态，避免局部监听后复用旧缓存。',
    );
    expect(
      placementCacheKeyMethod,
      contains('final experimentMode = showExperimentCourses ?'),
    );
  });

  test('course week page reuses one today value for highlights', () {
    final courseTable =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final contentMethod = RegExp(
      r'Widget _buildCourseTableContent\(BuildContext context\) \{[\s\S]*?\n  static const List<_SectionTime>',
    ).firstMatch(courseTable)?.group(0);
    final weekPageMethod = RegExp(
      r'Widget _buildWeekPage\(\{[\s\S]*?\n  void _appendDayCoursePlacements',
    ).firstMatch(courseTable)?.group(0);
    final showCourseDetailsMethod = RegExp(
      r'void _showCourseDetails\(_PlacedCourse placement\) \{[\s\S]*?\n  Future<void> _trackCourseDetailSheet',
    ).firstMatch(courseTable)?.group(0);
    final trackCourseDetailMethod = RegExp(
      r'Future<void> _trackCourseDetailSheet\(Future<void> sheet\) async \{[\s\S]*?\n  Future<void> _openCampusLogin',
    ).firstMatch(courseTable)?.group(0);
    final headerStripClass = RegExp(
      r'class _WeekHeaderStrip extends StatelessWidget \{[\s\S]*?\nclass _TimeAxisLabel',
    ).firstMatch(courseTable)?.group(0);

    expect(contentMethod, isNotNull);
    expect(contentMethod, contains('ValueListenableBuilder<DateTime>'));
    expect(contentMethod, contains('valueListenable: _todayDateNotifier'));
    expect(contentMethod, contains('today: today,'));
    expect(
      contentMethod,
      isNot(contains('DateTime.now()')),
      reason: '课表完成态布局重建应复用页面状态里的今天日期，不应反复读取当前时间。',
    );

    expect(weekPageMethod, isNotNull);
    expect(weekPageMethod, contains('required DateTime today,'));
    expect(weekPageMethod, contains('today: today,'));
    expect(
      weekPageMethod,
      contains('for (final section in _sectionTimes)'),
      reason: '周页节次标签处于高频 build 路径，应直接循环构建，避免 map 闭包和临时 iterable。',
    );
    expect(
      weekPageMethod,
      contains('for (final placement in placedCourses)'),
      reason: '周页课程点击热区应直接循环构建，避免 map 闭包和临时 iterable。',
    );
    expect(weekPageMethod, isNot(contains('_sectionTimes.map')));
    expect(weekPageMethod, isNot(contains('placedCourses.map')));
    expect(
      weekPageMethod,
      isNot(contains('DateTime.now()')),
      reason: '周页自身不应重复读取当前时间。',
    );

    expect(showCourseDetailsMethod, isNotNull);
    expect(
      showCourseDetailsMethod,
      contains('_isCourseDetailSheetOpen = true;'),
    );
    expect(
      showCourseDetailsMethod,
      contains('unawaited(_trackCourseDetailSheet(sheet));'),
      reason: '课表课程详情弹层关闭后的打开标记清理应集中到 async helper。',
    );
    expect(
      showCourseDetailsMethod,
      isNot(contains('sheet.whenComplete')),
      reason: '课表课程详情弹层打开标记不应通过 whenComplete 回调链清理。',
    );
    expect(trackCourseDetailMethod, isNotNull);
    expect(trackCourseDetailMethod, contains('try {'));
    expect(trackCourseDetailMethod, contains('await sheet;'));
    expect(trackCourseDetailMethod, contains('} finally {'));
    expect(
      trackCourseDetailMethod,
      contains('_isCourseDetailSheetOpen = false;'),
      reason: '课表课程详情弹层无论正常关闭还是异常完成，都必须释放打开标记。',
    );
    expect(trackCourseDetailMethod, isNot(contains('.whenComplete(')));

    expect(headerStripClass, isNotNull);
    expect(headerStripClass, contains('final DateTime today;'));
    expect(headerStripClass, contains('_isSameDay(day, today)'));
    expect(
      headerStripClass,
      contains('for (var index = 0; index < weekDays.length; index++)'),
      reason: '课表周页表头应直接按下标构建，避免 asMap/entries/map 临时对象。',
    );
    expect(headerStripClass, isNot(contains('weekDays.asMap()')));
    expect(headerStripClass, isNot(contains('.entries.map')));
    expect(
      headerStripClass,
      isNot(contains('DateTime.now()')),
      reason: '周表头应复用父级传入的 today。',
    );
  });

  test('course table widgets avoid temporary mapped child lists', () {
    final widgets =
        File(
          'lib/home/coursetable/widgets/course_table_widgets.dart',
        ).readAsStringSync();
    final weekdayHeaderClass = RegExp(
      r'class CourseWeekdayHeader extends StatelessWidget \{[\s\S]*?\nclass CourseSectionColumn',
    ).firstMatch(widgets)?.group(0);
    final sectionColumnClass = RegExp(
      r'class CourseSectionColumn extends StatelessWidget \{[\s\S]*?\nclass CourseSummary',
    ).firstMatch(widgets)?.group(0);
    final detailSheetClass = RegExp(
      r'class _CourseDetailSheetState extends State<CourseDetailSheet> \{[\s\S]*?\nclass ExperimentStudentsSheet',
    ).firstMatch(widgets)?.group(0);
    final detailGroupClass = RegExp(
      r'class _CourseDetailGroup extends StatelessWidget \{[\s\S]*?\nclass _CourseDetailRow',
    ).firstMatch(widgets)?.group(0);

    expect(weekdayHeaderClass, isNotNull);
    expect(
      weekdayHeaderClass,
      contains('for (var index = 0; index < dayLabels.length; index++)'),
      reason: '课表周表头处于高频 build 路径，应直接按下标构建，避免 asMap/entries/map 临时对象。',
    );
    expect(weekdayHeaderClass, isNot(contains('dayLabels.asMap()')));
    expect(weekdayHeaderClass, isNot(contains('.entries.map')));

    expect(sectionColumnClass, isNotNull);
    expect(
      sectionColumnClass,
      contains('for (var index = 0; index < sectionCount; index++)'),
      reason: '课表节次列应直接循环构建，避免 List.generate 闭包分配。',
    );
    expect(sectionColumnClass, isNot(contains('List.generate(sectionCount')));

    expect(detailSheetClass, isNotNull);
    expect(detailSheetClass, contains('for (final item in detailItems)'));
    expect(detailSheetClass, contains('for (final item in actionItems)'));
    expect(detailSheetClass, isNot(contains('detailItems.map')));
    expect(detailSheetClass, isNot(contains('actionItems.map')));
    expect(detailSheetClass, isNot(contains('.toList()')));

    expect(detailGroupClass, isNotNull);
    expect(
      detailGroupClass,
      contains('List<Widget> _buildSeparatedChildren()'),
    );
    expect(
      detailGroupClass,
      contains('for (var index = 0; index < children.length; index++)'),
      reason: '课程详情分组插入分隔线应直接循环，避免 List.generate 闭包分配。',
    );
    expect(
      detailGroupClass,
      isNot(contains('List.generate(children.length * 2 - 1')),
    );
  });

  test('course schedule manager avoids temporary mapped child lists', () {
    final courseTable =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final showScheduleManagerMethod = RegExp(
      r'Future<void> _showScheduleManager\(\) async \{[\s\S]*?\n  Widget _buildScheduleManagerBackground',
    ).firstMatch(courseTable)?.group(0);
    final scheduleManagerBuilder =
        showScheduleManagerMethod == null
            ? null
            : RegExp(
              r'builder: \(sheetContext\) \{[\s\S]*?\n          return Material',
            ).firstMatch(showScheduleManagerMethod)?.group(0);
    final savedSectionMethod = RegExp(
      r'Widget _buildScheduleManagerSavedSection\([\s\S]*?\n  Widget _buildSavedScheduleTile',
    ).firstMatch(courseTable)?.group(0);
    final savedTileMethod = RegExp(
      r'Widget _buildSavedScheduleTile\([\s\S]*?\n  Widget _buildScheduleManagerPlaceholder',
    ).firstMatch(courseTable)?.group(0);
    final scheduleManagerBodyMethod = RegExp(
      r'Widget _buildScheduleManagerBody\([\s\S]*?\n  Widget _buildScheduleManagerSections',
    ).firstMatch(courseTable)?.group(0);
    final placeholderCardMethod = RegExp(
      r'Widget _buildScheduleManagerPlaceholderCard\([\s\S]*?\n  Widget _buildScheduleManagerSection',
    ).firstMatch(courseTable)?.group(0);

    expect(showScheduleManagerMethod, isNotNull);
    expect(
      showScheduleManagerMethod,
      contains('Future<bool>? contentReadyFuture;'),
      reason:
          '课表管理弹层的内容准备 Future 应在弹层内容首次构建时懒创建，避免自定义 presenter 未构建内容时留下 pending timer。',
    );
    expect(
      showScheduleManagerMethod,
      contains('Future<bool> scheduleManagerContentReadyFuture()'),
      reason: '同一次弹层生命周期内应复用同一个内容准备 Future，避免 builder 重建时重复计时。',
    );
    expect(
      showScheduleManagerMethod,
      contains('return contentReadyFuture ??='),
    );
    expect(showScheduleManagerMethod, contains('Future<bool>.delayed('));
    expect(
      showScheduleManagerMethod,
      contains('SynchronousFuture<bool>(true)'),
    );
    expect(showScheduleManagerMethod, contains('contentReadyFuture:'));
    expect(
      showScheduleManagerMethod,
      contains('scheduleManagerContentReadyFuture(),'),
    );
    expect(scheduleManagerBuilder, isNotNull);
    expect(
      scheduleManagerBuilder,
      isNot(contains('Future<bool>.delayed')),
      reason: 'bottom sheet builder 不应直接创建 Future.delayed，否则重建会重新显示占位态。',
    );
    expect(scheduleManagerBodyMethod, isNotNull);
    expect(
      scheduleManagerBodyMethod,
      contains('return isReady'),
      reason: '轻量模式下课表管理弹层应直接切换占位和内容，不再追加透明度动画。',
    );
    expect(scheduleManagerBodyMethod, isNot(contains('AppAnimatedSwitcher(')));
    expect(scheduleManagerBodyMethod, isNot(contains('FadeTransition(')));

    expect(savedSectionMethod, isNotNull);
    expect(
      savedSectionMethod,
      contains('for (var index = 0; index < _savedSchedules.length; index++)'),
      reason: '课表管理弹层的已保存课表列表应直接按下标构建，避免 asMap/entries/map/toList 临时对象。',
    );
    expect(savedSectionMethod, contains('_buildSavedScheduleTile('));
    expect(savedSectionMethod, isNot(contains('_savedSchedules.asMap()')));
    expect(savedSectionMethod, isNot(contains('.entries.map')));
    expect(savedSectionMethod, isNot(contains('.toList()')));

    expect(savedTileMethod, isNotNull);
    expect(
      savedTileMethod,
      contains('for (final badge in badges) _ScheduleBadge(label: badge)'),
      reason: '课表管理弹层徽标应直接 collection-for 构建，避免 map/toList。',
    );
    expect(savedTileMethod, isNot(contains('badges.map')));
    expect(savedTileMethod, isNot(contains('.toList()')));

    expect(placeholderCardMethod, isNotNull);
    expect(
      placeholderCardMethod,
      contains('for (var index = 2; index < lineWidths.length; index++)'),
      reason: '课表管理占位行应直接循环构建，避免 skip/map 产生中间 iterable。',
    );
    expect(
      placeholderCardMethod,
      contains('for (var index = 0; index < trailingTiles; index++)'),
      reason: '课表管理占位尾部卡片应直接循环构建，避免 List.generate 闭包分配。',
    );
    expect(placeholderCardMethod, isNot(contains('.skip(2)')));
    expect(
      placeholderCardMethod,
      isNot(contains('List.generate(trailingTiles')),
    );
  });

  test('course schedule management filters without temporary list chains', () {
    final courseMain =
        File('lib/utils/course/coursemain.dart').readAsStringSync();
    final deleteScheduleMethod = RegExp(
      r'Future<bool> deleteCourseSchedule\(String scheduleId\) async \{[\s\S]*?\nFuture<void> clearCourseSchedules',
    ).firstMatch(courseMain)?.group(0);
    final clearSchedulesMethod = RegExp(
      r'Future<void> clearCourseSchedules\(\{[\s\S]*?\nMap<String, dynamic> _buildCourseScheduleTransferPayload',
    ).firstMatch(courseMain)?.group(0);
    final deleteCourseMethod = RegExp(
      r'Future<bool> deleteCourseFromActiveSchedule\(\{[\s\S]*?\n// 从 JSON 文件读取',
    ).firstMatch(courseMain)?.group(0);

    expect(deleteScheduleMethod, isNotNull);
    expect(
      deleteScheduleMethod,
      contains('final remainingSchedules = <SavedCourseSchedule>[];'),
      reason: '删除课表应单次循环保留剩余课表，避免 where/toList 临时链。',
    );
    expect(
      deleteScheduleMethod,
      contains('var activeScheduleStillPresent = false;'),
    );
    expect(
      deleteScheduleMethod,
      contains('for (final schedule in archive.schedules)'),
    );
    expect(deleteScheduleMethod, contains('remainingSchedules.add(schedule);'));
    expect(deleteScheduleMethod, isNot(contains('.where(')));
    expect(deleteScheduleMethod, isNot(contains('.toList()')));

    expect(clearSchedulesMethod, isNotNull);
    expect(
      clearSchedulesMethod,
      contains('final retainedSchedules = <SavedCourseSchedule>[];'),
      reason: '清理课表应单次循环保留指定来源之外的课表，避免 where/toList 临时链。',
    );
    expect(clearSchedulesMethod, contains('if (sourceTypes != null)'));
    expect(
      clearSchedulesMethod,
      contains('for (final schedule in archive.schedules)'),
    );
    expect(clearSchedulesMethod, contains('retainedSchedules.add(schedule);'));
    expect(clearSchedulesMethod, isNot(contains('.where(')));
    expect(clearSchedulesMethod, isNot(contains('.toList()')));

    expect(deleteCourseMethod, isNotNull);
    expect(
      deleteCourseMethod,
      contains('for (final entry in activeSchedule.courseData.entries)'),
      reason: '删除课程前复制课表数据应直接遍历 entries，避免 forEach 闭包。',
    );
    expect(
      deleteCourseMethod,
      contains(
        'updatedCourseData[entry.key] = List<Course>.from(entry.value);',
      ),
    );
    expect(
      deleteCourseMethod,
      isNot(contains('activeSchedule.courseData.forEach')),
    );
    expect(
      deleteCourseMethod,
      contains('var writeIndex = 0;'),
      reason: '整张课表删除同一课程应原地压缩已复制列表，避免为每天课程再创建过滤列表。',
    );
    expect(deleteCourseMethod, contains('sourceCourses[writeIndex] = course;'));
    expect(
      deleteCourseMethod,
      contains('sourceCourses.removeRange(writeIndex, sourceCourses.length);'),
    );
    expect(deleteCourseMethod, isNot(contains('final filteredCourses')));
    expect(deleteCourseMethod, isNot(contains('sourceCourses.where')));
  });

  test(
    'course sync snapshot merges experiment courses without closure loops',
    () {
      final courseMain =
          File('lib/utils/course/coursemain.dart').readAsStringSync();
      final loadSnapshotMethod = RegExp(
        r'Future<CourseSyncSnapshot> loadCourseSyncSnapshotFromUrl\([\s\S]*?\nFuture<Map<String, List<Course>>> loadClassFormUrl',
      ).firstMatch(courseMain)?.group(0);

      expect(loadSnapshotMethod, isNotNull);
      expect(
        loadSnapshotMethod,
        contains('for (final entry in expCourseData.entries)'),
        reason: '课表同步收尾会合并普通课和实验课，应直接遍历 entries，避免 forEach 闭包。',
      );
      expect(
        loadSnapshotMethod,
        contains('final existingCourses = courseData[entry.key];'),
      );
      expect(
        loadSnapshotMethod,
        contains('existingCourses.addAll(entry.value);'),
      );
      expect(
        loadSnapshotMethod,
        contains('courseData[entry.key] = entry.value;'),
      );
      expect(loadSnapshotMethod, isNot(contains('expCourseData.forEach')));
      expect(loadSnapshotMethod, isNot(contains('courseData.containsKey')));
      expect(loadSnapshotMethod, isNot(contains('courseData[date]!')));
    },
  );

  test('course sync builds weekly fetch batches without mapped chains', () {
    final getCourse =
        File('lib/utils/course/get_course.dart').readAsStringSync();
    final mergeCourseDataMethod = RegExp(
      r'void _mergeCourseData\(\{[\s\S]*?\n\}\n\nclass _WeekFetchResult',
    ).firstMatch(getCourse)?.group(0);
    final fetchWeeklyMethod = RegExp(
      r'Future<Map<int, Map<String, List<Course>>>> _fetchWeeklyCourseData\(\{[\s\S]*?\n  void _applyWeekResults',
    ).firstMatch(getCourse)?.group(0);
    final applyWeekResultsMethod = RegExp(
      r'void _applyWeekResults\(Map<int, Map<String, List<Course>>> weekResults\) \{[\s\S]*?\n  Future<Map<String, List<Course>>> getAllWeekClass',
    ).firstMatch(getCourse)?.group(0);
    final getAllWeekExpClassMethod = RegExp(
      r'Future<Map<String, List<Course>>> getAllWeekExpClass\([\s\S]*?\n  \}\n\}',
    ).firstMatch(getCourse)?.group(0);

    expect(mergeCourseDataMethod, isNotNull);
    expect(
      mergeCourseDataMethod,
      contains('for (final entry in source.entries)'),
      reason: '课程周数据合并会在普通课和实验课同步路径反复调用，应直接遍历 entries。',
    );
    expect(
      mergeCourseDataMethod,
      contains('final existingCourses = target[entry.key];'),
    );
    expect(
      mergeCourseDataMethod,
      contains('target[entry.key] = List<Course>.from(entry.value);'),
      reason: '首次写入某日期时应复制 source 列表，避免后续调用方改动 source 时影响 target。',
    );
    expect(
      mergeCourseDataMethod,
      contains('existingCourses.addAll(entry.value);'),
    );
    expect(mergeCourseDataMethod, isNot(contains('.forEach(')));
    expect(mergeCourseDataMethod, isNot(contains('putIfAbsent')));
    expect(mergeCourseDataMethod, isNot(contains('target[date]!')));

    expect(fetchWeeklyMethod, isNotNull);
    expect(
      fetchWeeklyMethod,
      contains('final batchFutures = <Future<_WeekFetchResult>>[];'),
      reason: '课表同步批量抓取应显式构建同批次 Future 列表，避免 sublist/map 临时链。',
    );
    expect(
      fetchWeeklyMethod,
      contains('for (var index = startIndex; index < endIndex; index++)'),
    );
    expect(
      fetchWeeklyMethod,
      contains('batchFutures.add(fetchWeekResult(weeks[index]));'),
    );
    expect(
      fetchWeeklyMethod,
      contains('final batchResults = await Future.wait(batchFutures);'),
    );
    expect(fetchWeeklyMethod, isNot(contains('weeks.sublist')));
    expect(fetchWeeklyMethod, isNot(contains('batchWeeks')));
    expect(fetchWeeklyMethod, isNot(contains('.map((week)')));

    expect(applyWeekResultsMethod, isNotNull);
    expect(
      applyWeekResultsMethod,
      contains('for (final entry in weekResults.entries)'),
      reason:
          '普通课表周结果由 _fetchWeeklyCourseData 按周次插入，应直接按 entries 合并，避免再次复制 key 并排序。',
    );
    expect(applyWeekResultsMethod, contains('final tempData = entry.value;'));
    expect(applyWeekResultsMethod, isNot(contains('sortedWeeks')));
    expect(applyWeekResultsMethod, isNot(contains('keys.toList')));
    expect(applyWeekResultsMethod, isNot(contains('..sort()')));

    expect(getAllWeekExpClassMethod, isNotNull);
    expect(
      getAllWeekExpClassMethod,
      contains('for (final entry in weekResults.entries)'),
      reason: '实验课表周结果同样应复用抓取顺序合并，不应为每次同步再构造排序 key 列表。',
    );
    expect(getAllWeekExpClassMethod, contains('final tempData = entry.value;'));
    expect(getAllWeekExpClassMethod, isNot(contains('sortedWeeks')));
    expect(getAllWeekExpClassMethod, isNot(contains('keys.toList')));
  });

  test('course visible-day filtering avoids extra list copies', () {
    final courseTable =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final showExpStudentsMethod = RegExp(
      r'Future<void> _showExpStudents\(String pcid\) async \{[\s\S]*?\nclass _CourseTablePagingPhysics',
    ).firstMatch(courseTable)?.group(0);
    final buildWeekDaysMethod = RegExp(
      r'List<DateTime> _buildWeekDays\(DateTime anchorDate\) \{[\s\S]*?\n  int _normalizeWeek',
    ).firstMatch(courseTable)?.group(0);
    final buildWeekDaysForWeekMethod = RegExp(
      r'List<DateTime> _buildWeekDaysForWeek\(int weekNumber\) \{[\s\S]*?\n  void _applyDisplayedWeek',
    ).firstMatch(courseTable)?.group(0);
    final coursesForDayMethod = RegExp(
      r'List<Course> _coursesForDay\(DateTime date\) \{[\s\S]*?\n  void _clearWeekPlacementCache',
    ).firstMatch(courseTable)?.group(0);
    final clearCacheMethod = RegExp(
      r'void _clearWeekPlacementCache\(\) \{[\s\S]*?\n  String _buildWeekPlacementCacheKey',
    ).firstMatch(courseTable)?.group(0);
    final buildPlacedCoursesMethod = RegExp(
      r'List<_PlacedCourse> _buildPlacedCourses\([\s\S]*?\n  String _buildWeekCourseCardPaintCacheKey',
    ).firstMatch(courseTable)?.group(0);
    final appendDayCoursePlacementsMethod = RegExp(
      r'void _appendDayCoursePlacements\(\{[\s\S]*?\n  @override',
    ).firstMatch(courseTable)?.group(0);

    expect(buildWeekDaysMethod, isNotNull);
    expect(
      buildWeekDaysMethod,
      contains('List<DateTime>.filled(7, weekStart, growable: false)'),
      reason: '课表周页固定 7 天列表应直接填充，避免 List.generate 闭包分配。',
    );
    expect(
      buildWeekDaysMethod,
      contains('for (var index = 0; index < weekDays.length; index++)'),
    );
    expect(buildWeekDaysMethod, isNot(contains('List.generate(7')));

    expect(
      courseTable,
      contains('final Map<int, List<DateTime>> _weekDaysCache'),
      reason: '周页、工具栏和预热会反复按周读取 7 天日期，应缓存固定周日期列表。',
    );
    expect(buildWeekDaysForWeekMethod, isNotNull);
    expect(buildWeekDaysForWeekMethod, contains('_normalizeWeek(weekNumber)'));
    expect(
      buildWeekDaysForWeekMethod,
      contains('final cachedWeekDays = _weekDaysCache[normalizedWeek];'),
    );
    expect(buildWeekDaysForWeekMethod, contains('return cachedWeekDays;'));
    expect(
      buildWeekDaysForWeekMethod,
      contains('_weekDaysCache[normalizedWeek] = weekDays;'),
    );

    expect(clearCacheMethod, isNotNull);
    expect(
      clearCacheMethod,
      contains('_weekDaysCache.clear();'),
      reason: '课表切换、重载或实验课显示变化后，按周日期缓存必须和布局缓存一起失效。',
    );

    expect(coursesForDayMethod, isNotNull);
    expect(
      coursesForDayMethod,
      contains("return _courseData[_dateKey(date)] ?? const <Course>[];"),
      reason: '当天课程热路径应只读取原始列表，实验课过滤并入布局收集循环。',
    );
    expect(
      coursesForDayMethod,
      isNot(contains('.where(')),
      reason: '当天课程热路径不应创建过滤 iterable。',
    );
    expect(
      coursesForDayMethod,
      isNot(contains('List<Course>.from')),
      reason: '当天课程热路径不应额外复制列表。',
    );
    expect(
      coursesForDayMethod,
      isNot(contains('.toList()')),
      reason: '当天课程过滤结果不应提前物化。',
    );

    expect(buildPlacedCoursesMethod, isNotNull);
    expect(
      buildPlacedCoursesMethod,
      contains('_appendDayCoursePlacements('),
      reason: '周布局应让每日布局直接写入同一个 placements 列表，避免每天返回临时列表再 addAll。',
    );
    expect(
      buildPlacedCoursesMethod,
      isNot(contains('placements.addAll(')),
      reason: '周布局热路径不应为每日课程布局额外创建列表后 addAll。',
    );

    expect(appendDayCoursePlacementsMethod, isNotNull);
    expect(
      appendDayCoursePlacementsMethod,
      contains('required List<_PlacedCourse> targetPlacements'),
      reason: '每日布局应直接写入周级 placements 列表。',
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('required List<Course> dayCourses'),
      reason: '布局函数直接消费当天课程列表，避免上游过滤 iterable。',
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('required bool showExperimentCourses'),
      reason: '实验课过滤应并入布局的单次收集循环。',
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('final sortedCourses = <_CourseSpan>[];'),
      reason: '排序列表应由单次循环收集有效课程段，避免 map/whereType/toList 链式临时对象。',
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('for (final course in dayCourses)'),
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('if (!showExperimentCourses && course.isExp)'),
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('var clusterStartIndex = 0;'),
      reason: '重叠课程簇应在 sortedCourses 上用索引范围处理，避免 clusters 嵌套列表。',
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('while (clusterStartIndex < sortedCourses.length)'),
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('var clusterEndIndex = clusterStartIndex + 1;'),
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('clusterStartIndex = clusterEndIndex;'),
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains(
        'for (var slotIndex = 0; slotIndex < active.length; slotIndex++)',
      ),
      reason: '重叠课程列分配应显式压缩 active 列表，避免 removeWhere 闭包。',
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('active.removeRange(activeWriteIndex, active.length)'),
      reason: 'active 列表清理应批量截断，而不是每次 removeWhere 闭包扫描。',
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('var columnInUse = false;'),
      reason: '列占用扫描应使用显式循环，避免 active.any 闭包。',
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('targetPlacements.add('),
      reason: '每日布局结果应直接追加到周级列表。',
    );
    expect(
      appendDayCoursePlacementsMethod,
      isNot(contains('return placements;')),
      reason: '每日布局不应返回短生命周期临时列表。',
    );
    expect(
      appendDayCoursePlacementsMethod,
      contains('sortedCourses.sort((a, b)'),
    );
    expect(appendDayCoursePlacementsMethod, isNot(contains('dayCourses.map')));
    expect(
      appendDayCoursePlacementsMethod,
      isNot(contains('whereType<_CourseSpan>')),
    );
    expect(
      appendDayCoursePlacementsMethod,
      isNot(contains('dayCourses.where')),
    );
    expect(appendDayCoursePlacementsMethod, isNot(contains('final clusters')));
    expect(appendDayCoursePlacementsMethod, isNot(contains('currentCluster')));
    expect(
      appendDayCoursePlacementsMethod,
      isNot(contains('for (final cluster in clusters)')),
    );
    expect(
      appendDayCoursePlacementsMethod,
      isNot(contains('active.removeWhere')),
    );
    expect(appendDayCoursePlacementsMethod, isNot(contains('active.any')));

    expect(showExpStudentsMethod, isNotNull);
    expect(
      showExpStudentsMethod,
      contains('final students = <Map<String, dynamic>>[];'),
      reason: '实验课学生名单解析应一次构造结果列表，避免 map/toList 链式临时对象。',
    );
    expect(
      showExpStudentsMethod,
      contains("final rawStudents = data['studentList'];"),
    );
    expect(showExpStudentsMethod, contains('if (rawStudents is List)'));
    expect(showExpStudentsMethod, contains('for (final item in rawStudents)'));
    expect(showExpStudentsMethod, contains('if (item is Map)'));
    expect(
      showExpStudentsMethod,
      contains('students.add(Map<String, dynamic>.from(item));'),
    );
    expect(showExpStudentsMethod, isNot(contains('.map(')));
    expect(showExpStudentsMethod, isNot(contains('.toList()')));
  });

  test('course experiment section parsers avoid mapped section lists', () {
    final getCourse =
        File('lib/utils/course/get_course.dart').readAsStringSync();
    final expParserClass = RegExp(
      r'class GetSingleWeekExpClass \{[\s\S]*?\nclass GetOrgDataWeb',
    ).firstMatch(getCourse)?.group(0);
    final initDataMethod = RegExp(
      r'void initData\(\) \{[\s\S]*?\n  void getWeekDate',
    ).firstMatch(expParserClass ?? '')?.group(0);
    final weekNoteSectionsMethod = RegExp(
      r'List<int> _parseWeekNoteSections\(String rawValue\) \{[\s\S]*?\n  List<int> _parseExplicitSections',
    ).firstMatch(getCourse)?.group(0);
    final explicitSectionsMethod = RegExp(
      r'List<int> _parseExplicitSections\(String rawValue\) \{[\s\S]*?\n  List<int> _resolveSectionsFromSectionLabel',
    ).firstMatch(getCourse)?.group(0);
    final resolveSectionLabelMethod = RegExp(
      r'List<int> _resolveSectionsFromSectionLabel\(Map<String, dynamic> tempClass\) \{[\s\S]*?\n  List<int> _resolveSectionsFromTimeRange',
    ).firstMatch(getCourse)?.group(0);

    expect(initDataMethod, isNotNull);
    expect(
      initDataMethod,
      contains(
        'for (var index = 0; index < sectionDefinitionList.length; index++)',
      ),
      reason: '实验课大节标签索引应直接下标扫描，避免 asMap/entries/map/where 链式临时对象。',
    );
    expect(
      initDataMethod,
      contains('_sectionDefinitionIndexByLabel[label] = index;'),
    );
    expect(initDataMethod, isNot(contains('.asMap()')));
    expect(initDataMethod, isNot(contains('.entries')));
    expect(initDataMethod, isNot(contains('.map(')));
    expect(initDataMethod, isNot(contains('.where(')));

    expect(weekNoteSectionsMethod, isNotNull);
    expect(
      weekNoteSectionsMethod,
      contains('final sections = <int>[];'),
      reason: '实验课 weekNoteDetail 节次解析应单次循环构造列表，避免 where/map/toList 链式临时对象。',
    );
    expect(
      weekNoteSectionsMethod,
      contains('for (var index = 0; index <= rawValue.length; index++)'),
    );
    expect(
      weekNoteSectionsMethod,
      contains('_isSectionTokenDelimiter(rawValue.codeUnitAt(index))'),
    );
    expect(
      weekNoteSectionsMethod,
      contains(
        '_addWeekNoteSectionToken(rawValue, tokenStart, index, sections);',
      ),
    );
    expect(weekNoteSectionsMethod, isNot(contains('RegExp')));
    expect(weekNoteSectionsMethod, isNot(contains('.split(')));
    expect(weekNoteSectionsMethod, isNot(contains('.where(')));
    expect(weekNoteSectionsMethod, isNot(contains('.map(')));
    expect(weekNoteSectionsMethod, isNot(contains('.toList()')));

    expect(explicitSectionsMethod, isNotNull);
    expect(
      explicitSectionsMethod,
      contains('final sections = <int>[];'),
      reason: '实验课大节定义解析应单次循环构造列表，避免 where/map/toList 链式临时对象。',
    );
    expect(
      explicitSectionsMethod,
      contains('for (var index = 0; index <= rawValue.length; index++)'),
    );
    expect(
      explicitSectionsMethod,
      contains('_isSectionTokenDelimiter(rawValue.codeUnitAt(index))'),
    );
    expect(
      explicitSectionsMethod,
      contains(
        '_addExplicitSectionToken(rawValue, tokenStart, index, sections);',
      ),
    );
    expect(explicitSectionsMethod, isNot(contains('RegExp')));
    expect(explicitSectionsMethod, isNot(contains('.split(')));
    expect(explicitSectionsMethod, isNot(contains('.where(')));
    expect(explicitSectionsMethod, isNot(contains('.map(')));
    expect(explicitSectionsMethod, isNot(contains('.toList()')));

    expect(resolveSectionLabelMethod, isNotNull);
    expect(
      resolveSectionLabelMethod,
      contains(
        'collected.removeRange(expectedSectionCount, collected.length);',
      ),
      reason: '实验课大节回退解析应原地截断已收集节次，避免 take/toList 临时列表。',
    );
    expect(resolveSectionLabelMethod, contains('collected.sort();'));
    expect(resolveSectionLabelMethod, contains('return collected;'));
    expect(resolveSectionLabelMethod, isNot(contains('.take(')));
    expect(resolveSectionLabelMethod, isNot(contains('.toList()')));
  });

  test('course experiment raw failure snapshot uses stable reason', () {
    final getCourse =
        File('lib/utils/course/get_course.dart').readAsStringSync();
    final jsonSafeValueMethod = RegExp(
      r'dynamic _jsonSafeValue\(dynamic value\) \{[\s\S]*?\n\}',
    ).firstMatch(getCourse)?.group(0);
    final getAllWeekExpClassMethod = RegExp(
      r'Future<Map<String, List<Course>>> getAllWeekExpClass\([\s\S]*?\n  \}\n\}',
    ).firstMatch(getCourse)?.group(0);

    expect(jsonSafeValueMethod, isNotNull);
    expect(
      jsonSafeValueMethod,
      contains('final safeMap = <String, dynamic>{};'),
    );
    expect(jsonSafeValueMethod, contains('for (final entry in value.entries)'));
    expect(
      jsonSafeValueMethod,
      contains('safeMap[entry.key.toString()] = _jsonSafeValue(entry.value);'),
    );
    expect(jsonSafeValueMethod, contains('final safeList = <dynamic>[];'));
    expect(jsonSafeValueMethod, contains('for (final item in value)'));
    expect(
      jsonSafeValueMethod,
      contains('safeList.add(_jsonSafeValue(item));'),
    );
    expect(jsonSafeValueMethod, isNot(contains('.map(')));
    expect(jsonSafeValueMethod, isNot(contains('.toList(')));

    expect(
      getCourse,
      contains(
        "const String courseExperimentWeekFetchFailureMessage = '实验课表抓取失败，请稍后重试';",
      ),
      reason: '实验课逐周失败原因会写入本地 raw snapshot，必须是稳定文案。',
    );
    expect(getAllWeekExpClassMethod, isNotNull);
    expect(
      getAllWeekExpClassMethod,
      contains("'error': courseExperimentWeekFetchFailureMessage,"),
      reason: '失败周记录不应把底层异常、URL 或 token 写入 experiment_course_raw.json。',
    );
    expect(
      getAllWeekExpClassMethod,
      isNot(contains("'error': error.toString()")),
    );
  });

  test('course paint cache builds immutable card list without double copy', () {
    final courseTable =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final paintDataMethod = RegExp(
      r'List<_CourseCardPaintData> _buildWeekCourseCardPaintDataForEnvironment\(\{[\s\S]*?\n  _CourseCardPaintData _buildCourseCardPaintData',
    ).firstMatch(courseTable)?.group(0);

    expect(paintDataMethod, isNotNull);
    expect(
      paintDataMethod,
      contains('final paintData = List<_CourseCardPaintData>.filled('),
      reason: '课程卡片绘制数据应按固定长度列表下标写入，避免 map/closure/iterable 临时对象。',
    );
    expect(
      paintDataMethod,
      contains('for (var index = 1; index < placedCourses.length; index++)'),
    );
    expect(
      paintDataMethod,
      contains('final placement = placedCourses[index];'),
    );
    expect(
      paintDataMethod,
      contains('List<_CourseCardPaintData>.unmodifiable(paintData)'),
      reason: '缓存结果仍应在写入缓存前冻结为不可变列表。',
    );
    expect(
      paintDataMethod,
      isNot(contains('placedCourses.map(')),
      reason: '绘制热路径不应通过 map 额外创建闭包和 iterable。',
    );
    expect(
      paintDataMethod,
      isNot(contains('toList(growable: false)')),
      reason: '缓存列表已经由 List.unmodifiable 物化，不应先构造中间列表。',
    );
  });

  test('course cache keys avoid temporary list join allocation', () {
    final courseTable =
        File('lib/home/coursetable/view.dart').readAsStringSync();
    final placementKeyMethod = RegExp(
      r'String _buildWeekPlacementCacheKey\([\s\S]*?\n  bool _hasWeekPlacementCache',
    ).firstMatch(courseTable)?.group(0);
    final paintKeyMethod = RegExp(
      r'String _buildWeekCourseCardPaintCacheKey\([\s\S]*?\n  List<_CourseCardPaintData> _buildWeekCourseCardPaintData',
    ).firstMatch(courseTable)?.group(0);
    final hitKeyMethod = RegExp(
      r'String _buildCourseCardHitKey\(_PlacedCourse placement\) \{[\s\S]*?\n  Widget _buildWeekPage',
    ).firstMatch(courseTable)?.group(0);

    expect(placementKeyMethod, isNotNull);
    expect(
      placementKeyMethod,
      contains(r"'$scheduleId|$experimentMode"),
      reason: '周布局缓存 key 应直接构造字符串，避免 List.join 临时列表。',
    );
    expect(
      placementKeyMethod,
      isNot(contains('.join(')),
      reason: '周布局缓存 key 处于 build/预热路径，不应通过 List.join 生成。',
    );

    expect(paintKeyMethod, isNotNull);
    expect(
      paintKeyMethod,
      contains(r"'$placementKey|${theme.brightness.name}|$bodyFontFamily|"),
      reason: '课程卡片绘制缓存 key 应直接构造字符串。',
    );
    expect(
      paintKeyMethod,
      isNot(contains('.join(')),
      reason: '课程卡片绘制缓存 key 不应通过 List.join 额外分配。',
    );

    expect(hitKeyMethod, isNotNull);
    expect(
      hitKeyMethod,
      contains(r"'${_dateKey(placement.day)}-${placement.startSection}-"),
      reason: '课程卡片命中 key 应直接构造字符串。',
    );
    expect(
      hitKeyMethod,
      isNot(contains('.join(')),
      reason: '课程卡片命中 key 生成不应构造临时列表。',
    );
  });
}
