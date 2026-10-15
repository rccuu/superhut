import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/ui/app_animated_container.dart';
import 'package:superhut/pages/drink/api/drink_api.dart';
import 'package:superhut/pages/drink/api/drink_result.dart';
import 'package:superhut/pages/drink/core/drink_home_tokens.dart';
import 'package:superhut/pages/drink/view/logic.dart';
import 'package:superhut/pages/drink/view/view.dart';
import 'package:superhut/pages/drink/view/widgets/drink_page_widgets.dart';

/// 首页设计规则的实测版。
///
/// 每条对比度都从「这个 widget 在它自己那个位置上真正画出来的那一层」取样计算：
/// `_faceOf` 取目标自身着色的面，`_backdropOf` 沿元素树按真实绘制顺序合成目标
/// 脚下的所有色层。两者都不写死猜测值，所以换色、挪动渐变停靠点、把卡片挪到
/// 页面更高的带子上，都会立刻被测出来。
const Color _legacyCyan = Color(0xFF00D4FF);

const List<Map> _twoDevices = <Map>[
  {'id': 'tap-1', 'name': '一栋饮水机'},
  {'id': 'tap-2', 'name': '二栋饮水机'},
];

const String _hintLine = '设备可切换，开始用水后会自动检测状态。';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'hui798IsLogin': true,
    });
  });

  tearDown(() {
    Get.reset();
  });

  for (final bool dark in <bool>[false, true]) {
    final String mode = dark ? 'dark' : 'light';
    final DrinkHomePalette palette =
        dark ? const DrinkHomePalette.dark() : const DrinkHomePalette.light();

    testWidgets(
      'page background is a named gradient ending exactly on the body colour ($mode)',
      (tester) async {
        await _pumpHome(tester, dark: dark, devices: _twoDevices);

        final background = tester.widget<AppAnimatedContainer>(
          find.byKey(drinkBackgroundKey),
        );
        final box = background.decoration! as BoxDecoration;
        // 背景不能塌成一块死色：本体色必须由渐变的最后一个停靠点交出。
        expect(box.color, isNull);
        expect(box.gradient, isA<LinearGradient>());

        final gradient = box.gradient! as LinearGradient;
        expect(gradient.begin, Alignment.topCenter);
        expect(gradient.end, Alignment.bottomCenter);
        expect(gradient.stops, hasLength(gradient.colors.length));
        expect(gradient.stops!.first, 0.0);
        expect(gradient.stops!.last, 1.0);
        expect(
          gradient.colors.toSet().length,
          gradient.colors.length,
          reason: '渐变停靠点不能全是同一块色',
        );

        final scaffoldColor =
            tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor;
        expect(
          scaffoldColor,
          dark ? DrinkHomeT.pageDark : DrinkHomeT.pageLight,
        );

        final rect = tester.getRect(find.byKey(drinkBackgroundKey));
        expect(
          _sampleGradient(gradient, rect, Offset(rect.center.dx, rect.bottom)),
          scaffoldColor,
          reason: 't = 1.0 的取样必须正好接住页面本体色',
        );
        expect(gradient.colors.last, scaffoldColor);
        expect(
          _sampleGradient(gradient, rect, Offset(rect.center.dx, rect.top)),
          dark ? DrinkHomeT.bandTopDark : DrinkHomeT.bandTopLight,
        );

        // 状态卡脚下那一层要真的取自渐变带，而不是页面本体色：
        // 实测底色必须等于同一点的渐变取样值。
        final cardFinder = find.byKey(drinkStatusCardKey);
        final measured = _backdropOf(tester, cardFinder);
        expect(
          measured,
          _sampleGradient(gradient, rect, tester.getCenter(cardFinder)),
          reason: '卡片脚下就是这条带子，取样要能对上',
        );
        expect(measured, isNot(scaffoldColor));
      },
    );

    testWidgets(
      'status card and device tiles separate from the surface under them ($mode)',
      (tester) async {
        await _pumpHome(tester, dark: dark, devices: _twoDevices);

        final finders = <Finder>[
          find.byKey(drinkStatusCardKey),
          find.byKey(drinkDeviceTileKey('tap-1')),
          find.byKey(drinkDeviceTileKey('tap-2')),
        ];
        for (final finder in finders) {
          final face = _faceOf(tester, finder);
          final backdrop = _backdropOf(tester, finder);
          final separation = _contrast(face.color, backdrop);
          expect(
            separation,
            greaterThanOrEqualTo(1.15),
            reason:
                '$finder 只靠亮度分层就要有 1.15:1，'
                '实测 $separation（面 ${face.color} / 底 $backdrop）',
          );

          // 第二条通道：描边或投影必须真的看得见，不能只是「画了」。
          final border = face.decoration.border;
          final shadows = face.decoration.boxShadow;
          expect(
            border != null || (shadows != null && shadows.isNotEmpty),
            isTrue,
            reason: '除了亮度差，还必须要有描边或投影这条通道',
          );
          if (border != null) {
            final side = (border as Border).top;
            expect(side.width, greaterThan(0.0));
            expect(side.color.a, greaterThan(0.0));
            expect(
              _contrast(side.color, face.color),
              greaterThan(1.0),
              reason: '描边压在自家面上要看得出来',
            );
          }
          if (shadows != null && shadows.isNotEmpty) {
            final shadow = shadows.first;
            expect(shadow.color.a, greaterThan(0.0));
            expect(
              _contrast(shadow.color, backdrop),
              greaterThanOrEqualTo(1.02),
              reason: '投影落在底色上必须留下可见的一档差',
            );
          }
        }

        // 浅色下选中的条目不换填充，靠描边 + 勾选 + 抬升说话。
        expect(palette.selectionTintsFill, dark);
      },
    );

    testWidgets('body text and headings keep their contrast floors ($mode)', (
      tester,
    ) async {
      await _pumpHome(tester, dark: dark, devices: _twoDevices);

      // 正文级：条目名、状态卡副标题、页面提示行都要 4.5:1。
      final bodyTexts = <String, Finder>{
        '选中的条目名': find.descendant(
          of: find.byKey(drinkStatusCardKey),
          matching: find.text('一-饮水机'),
        ),
        '静止条目名': find.descendant(
          of: find.byKey(drinkDeviceTileKey('tap-2')),
          matching: find.text('二-饮水机'),
        ),
        '状态卡副标题': find.text('选择设备开始接水'),
        '页面提示行': find.text(_hintLine),
      };
      for (final entry in bodyTexts.entries) {
        final color = _textColor(tester, entry.value);
        final backdrop = _backdropOf(tester, entry.value);
        expect(
          _contrast(color, backdrop),
          greaterThanOrEqualTo(4.5),
          reason:
              '${entry.key} 是正文，实测 ${_contrast(color, backdrop)}，'
              '字色 $color 压在底 $backdrop 上',
        );
      }

      // 两级标题靠字号与字重走大尺度，底线 3.0。
      final headings = <String, Finder>{
        '状态标题': find.text('准备就绪'),
        '设备区标题': find.text('我的设备'),
      };
      for (final entry in headings.entries) {
        final color = _textColor(tester, entry.value);
        final backdrop = _backdropOf(tester, entry.value);
        expect(
          _contrast(color, backdrop),
          greaterThanOrEqualTo(3.0),
          reason: '${entry.key} 是大尺度标题，实测 ${_contrast(color, backdrop)}',
        );
      }

      // 非文字元素（图标）底线同样是 3.0。
      final chipFinder = find.byKey(drinkStatusIconChipKey);
      final icon = tester.widget<Icon>(
        find.descendant(of: chipFinder, matching: find.byType(Icon)),
      );
      expect(
        _contrast(icon.color!, _faceOf(tester, chipFinder).color),
        greaterThanOrEqualTo(3.0),
      );
    });

    testWidgets(
      'labels stay readable against what is really painted under them ($mode)',
      (tester) async {
        await _pumpHome(tester, dark: dark, devices: _twoDevices);

        // 白色标签压在强调渐变上：按标签真实所在的取样点算，不看两端猜测值。
        final label = find.descendant(
          of: find.byKey(drinkPrimaryActionKey),
          matching: find.text('开始用水'),
        );
        expect(
          _contrast(_textColor(tester, label), _backdropOf(tester, label)),
          greaterThanOrEqualTo(4.5),
        );

        // 设备数量徽标：品牌墨压在图标底上。
        final badge = find.text('2 台设备');
        expect(
          _contrast(_textColor(tester, badge), _backdropOf(tester, badge)),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    testWidgets(
      'selected tile carries the 1.6px brand border and the check marker ($mode)',
      (tester) async {
        await _pumpHome(tester, dark: dark, devices: _twoDevices);

        final selectedFinder = find.byKey(drinkDeviceTileKey('tap-1'));
        final selected = _faceOf(tester, selectedFinder);
        final border = selected.decoration.border! as Border;
        expect(border.top.width, 1.6);
        expect(border.top.color, palette.brandInk);
        expect(
          _contrast(border.top.color, selected.color),
          greaterThanOrEqualTo(3.0),
          reason: '选中描边是非文字指示元素，底线 3.0',
        );
        expect(find.byKey(drinkDeviceCheckMarkerKey('tap-1')), findsOneWidget);
        expect(find.byKey(drinkDeviceEditKey('tap-1')), findsNothing);

        final markerFinder = find.byKey(drinkDeviceCheckMarkerKey('tap-1'));
        expect(_faceOf(tester, markerFinder).color, palette.markerFill);
        final markerInk = tester.widget<Icon>(
          find.descendant(of: markerFinder, matching: find.byType(Icon)),
        );
        expect(markerInk.color, palette.markerInk);
        expect(
          _contrast(markerInk.color!, _faceOf(tester, markerFinder).color),
          greaterThanOrEqualTo(3.0),
        );

        // 静止条目不换填充，第二条通道只有描边 + 编辑芯片。
        final idle = _faceOf(tester, find.byKey(drinkDeviceTileKey('tap-2')));
        final idleBorder = idle.decoration.border! as Border;
        expect(idleBorder.top.width, 1.0);
        expect(idleBorder.top.color, palette.hairline);
        expect(find.byKey(drinkDeviceEditKey('tap-2')), findsOneWidget);
        expect(find.byKey(drinkDeviceCheckMarkerKey('tap-2')), findsNothing);
      },
    );
  }

  testWidgets('settle fill and accent stops clear 4.5:1 with white', (
    tester,
  ) async {
    for (final bool dark in <bool>[false, true]) {
      final logic = await _pumpHome(tester, dark: dark, devices: _twoDevices);

      final idle = _faceOf(tester, find.byKey(drinkPrimaryActionKey));
      final gradient = idle.decoration.gradient! as LinearGradient;
      for (final Color stop in gradient.colors) {
        expect(
          _contrast(Colors.white, stop),
          greaterThanOrEqualTo(4.5),
          reason: '强调渐变的每个停靠点都要撑住白色标签',
        );
      }

      logic.state.drinkStatus.value = true;
      await tester.pump();
      await tester.pump();

      final settling = _faceOf(tester, find.byKey(drinkPrimaryActionKey));
      expect(settling.color, DrinkHomeT.settle);
      expect(settling.decoration.gradient, isNull);
      expect(settling.color, isNot(DrinkHomeT.accentStart));

      final settleLabel = find.text('结算');
      expect(
        _contrast(Colors.white, _backdropOf(tester, settleLabel)),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets('no painted gradient on the page ever stops at the old cyan', (
    tester,
  ) async {
    for (final bool dark in <bool>[false, true]) {
      final logic = await _pumpHome(tester, dark: dark, devices: _twoDevices);

      // 先确认扫描确实取到了页面上的渐变，否则下面的断言是空的。
      expect(_gradientColorsInTree(tester), contains(DrinkHomeT.accentStart));
      expect(_gradientColorsInTree(tester), isNot(contains(_legacyCyan)));

      // 排序提示条与接水态背景都带渐变，换到这两个状态再各扫一遍。
      logic.state.isReordering.value = true;
      await tester.pump();
      expect(find.byKey(drinkReorderHintKey), findsOneWidget);
      expect(_gradientColorsInTree(tester), isNot(contains(_legacyCyan)));

      logic.state.isReordering.value = false;
      logic.state.drinkStatus.value = true;
      await tester.pump();
      await tester.pump();
      expect(_gradientColorsInTree(tester), isNot(contains(_legacyCyan)));
    }
  });

  testWidgets(
    'primary action paints its gradient outside a transparent button',
    (tester) async {
      await _pumpHome(tester, dark: false, devices: _twoDevices);

      final face = _faceOf(tester, find.byKey(drinkPrimaryActionKey));
      final outer = face.decoration;
      expect(outer.gradient, isA<LinearGradient>());
      expect((outer.gradient! as LinearGradient).colors, const <Color>[
        DrinkHomeT.accentStart,
        DrinkHomeT.accentEnd,
      ]);
      expect(outer.color, isNull);

      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(drinkPrimaryActionKey),
          matching: find.byType(FilledButton),
        ),
      );
      // 底交给外层画：按钮自己必须是全透明、零 elevation，
      // 否则禁用态会盖掉外层的中性底与标签配色。
      expect(
        button.style!.backgroundColor!.resolve(const <WidgetState>{}),
        Colors.transparent,
      );
      expect(
        button.style!.backgroundColor!.resolve(<WidgetState>{
          WidgetState.disabled,
        }),
        Colors.transparent,
      );
      expect(
        button.style!.shadowColor!.resolve(const <WidgetState>{}),
        Colors.transparent,
      );
      expect(button.style!.elevation!.resolve(const <WidgetState>{}), 0.0);
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'primary action is dead without a device and never starts a drink',
    (tester) async {
      final api = _FakeDrinkApi();
      final logic = await _pumpHome(
        tester,
        dark: false,
        devices: const <Map>[],
        api: api,
      );

      final face = _faceOf(tester, find.byKey(drinkPrimaryActionKey));
      // 没有设备时不能还穿着强调色：那看着像可以点。
      expect(face.color, DrinkHomeT.disabledLight);
      expect(face.color, isNot(DrinkHomeT.accentStart));
      expect(face.decoration.gradient, isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(drinkPrimaryActionKey),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        _textColor(tester, find.text('开始用水')),
        DrinkHomeT.disabledInkLight,
      );

      await tester.tap(find.byKey(drinkPrimaryActionKey));
      await tester.pump();

      expect(api.startDrinkRequests, isEmpty);
      expect(logic.state.drinkStatus.value, isFalse);
    },
  );

  testWidgets('drinking turns the primary action into the settle button', (
    tester,
  ) async {
    final api = _FakeDrinkApi(devices: _twoDevices);
    final logic = await _pumpHome(
      tester,
      dark: false,
      devices: _twoDevices,
      api: api,
    );

    await tester.tap(find.byKey(drinkPrimaryActionKey));
    await tester.pump();
    await tester.pump();

    expect(api.startDrinkRequests, ['tap-1']);
    expect(logic.state.drinkStatus.value, isTrue);

    final face = _faceOf(tester, find.byKey(drinkPrimaryActionKey));
    expect(face.color, DrinkHomeT.settle);
    expect(face.decoration.gradient, isNull);

    final actionIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(drinkPrimaryActionKey),
        matching: find.byType(Icon),
      ),
    );
    expect(actionIcon.icon, Ionicons.stop_circle);
    expect(actionIcon.color, Colors.white);

    // 结算：状态轮询定时器会一直挂着，只有真正结算才会取消，
    // 收尾不把它留成 pending timer。「开始接水」提示条是 floating 的，压在
    // 主按钮上；它自己消失之前不能点第二下，否则指针事件打在条子上。
    // 提示条的三秒计时是在入场动画跑完之后才起的，所以要先 settle 一次。
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.byKey(drinkPrimaryActionKey));
    await tester.pumpAndSettle();

    expect(api.endDrinkRequests, ['tap-1']);
    expect(logic.state.drinkStatus.value, isFalse);
    expect(logic.state.deviceStatusTimer, isNull);
  });

  testWidgets(
    'layout toggle swaps grid for list, persists and reordering takes over',
    (tester) async {
      final logic = await _pumpHome(tester, dark: false, devices: _twoDevices);
      final prefs = await SharedPreferences.getInstance();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      expect(find.byKey(drinkReorderHintKey), findsNothing);

      await tester.tap(find.byKey(drinkLayoutToggleKey));
      await tester.pumpAndSettle();

      expect(logic.state.layoutMode.value, 'grid');
      expect(prefs.getString('device_list_layout'), 'grid');
      expect(find.byType(ListView), findsNothing);
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2,
      );
      expect(find.byKey(drinkDeviceTileKey('tap-2')), findsOneWidget);

      await tester.tap(find.byKey(drinkLayoutToggleKey));
      await tester.pumpAndSettle();

      expect(logic.state.layoutMode.value, 'list');
      expect(prefs.getString('device_list_layout'), 'list');
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(ListView), findsOneWidget);

      await tester.tap(find.byKey(drinkReorderToggleKey));
      await tester.pumpAndSettle();

      expect(logic.state.isReordering.value, isTrue);
      expect(find.byKey(drinkReorderHintKey), findsOneWidget);
      expect(find.text('拖动调整顺序'), findsOneWidget);
      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
      // 排序模式下列表交给拖拽，布局切换入口必须禁用。
      expect(
        tester.widget<IconButton>(find.byKey(drinkLayoutToggleKey)).onPressed,
        isNull,
      );

      // 提示条要落在和静止浏览明显不同的面上，并且白色正文读得清。
      final hint = _faceOf(tester, find.byKey(drinkReorderHintKey));
      expect(hint.decoration.gradient, isA<LinearGradient>());
      final hintLabel = find.text('拖动调整顺序');
      expect(
        _contrast(
          _textColor(tester, hintLabel),
          _backdropOf(tester, hintLabel),
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(
          hint.color,
          _backdropOf(tester, find.byKey(drinkReorderHintKey)),
        ),
        greaterThanOrEqualTo(1.15),
      );

      await tester.tap(find.byKey(drinkReorderToggleKey));
      await tester.pumpAndSettle();

      expect(logic.state.isReordering.value, isFalse);
      expect(find.byKey(drinkReorderHintKey), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
    },
  );
}

/// ---------------------------------------------------------------------------
/// 取样与对比度工具（WCAG 相对亮度，前景按 alpha 合成到真实底色上）
/// ---------------------------------------------------------------------------

/// WCAG 相对亮度：sRGB 分量先线性化，再按 0.2126 / 0.7152 / 0.0722 加权。
double _relativeLuminance(Color color) {
  double linearize(double channel) =>
      channel <= 0.03928
          ? channel / 12.92
          : pow((channel + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * linearize(color.r) +
      0.7152 * linearize(color.g) +
      0.0722 * linearize(color.b);
}

/// [foreground] 按自身 alpha 合成到 [backdrop] 之后，两色的对比度。
double _contrast(Color foreground, Color backdrop) {
  final Color blended = Color.alphaBlend(foreground, backdrop);
  final double a = _relativeLuminance(blended);
  final double b = _relativeLuminance(backdrop);
  final double lighter = a > b ? a : b;
  final double darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

/// 线性渐变在 [point] 处的实际着色：把点投影到 begin → end 轴上取 t，
/// 再在相邻停靠点之间插值；没有 stops 时按等距铺开。
Color _sampleGradient(Gradient gradient, Rect box, Offset point) {
  if (gradient is! LinearGradient) {
    throw StateError('首页只使用线性渐变，收到 ${gradient.runtimeType}');
  }
  if (gradient.begin is! Alignment || gradient.end is! Alignment) {
    throw StateError('方向性渐变需要 textDirection，取样暂不支持');
  }

  final List<Color> colors = gradient.colors;
  final List<double> stops =
      gradient.stops ??
      <double>[
        for (var index = 0; index < colors.length; index++)
          colors.length == 1 ? 0.0 : index / (colors.length - 1),
      ];

  Offset resolve(Alignment alignment) => Offset(
    box.center.dx + alignment.x * box.width / 2.0,
    box.center.dy + alignment.y * box.height / 2.0,
  );
  final Offset start = resolve(gradient.begin as Alignment);
  final Offset end = resolve(gradient.end as Alignment);
  final double axisX = end.dx - start.dx;
  final double axisY = end.dy - start.dy;
  final double length = axisX * axisX + axisY * axisY;
  final double raw =
      length == 0.0
          ? 0.0
          : ((point.dx - start.dx) * axisX + (point.dy - start.dy) * axisY) /
              length;
  final double position = raw.clamp(0.0, 1.0);

  if (position <= stops.first) return colors.first;
  if (position >= stops.last) return colors.last;
  for (var index = 1; index < stops.length; index++) {
    if (position > stops[index]) continue;
    final double span = stops[index] - stops[index - 1];
    final double local =
        span == 0.0 ? 0.0 : (position - stops[index - 1]) / span;
    return Color.lerp(colors[index - 1], colors[index], local)!;
  }
  return colors.last;
}

/// 目标自身画出来的那一层面（颜色 + 完整 BoxDecoration + 绘制矩形）。
_Face _faceOf(WidgetTester tester, Finder finder) {
  final Offset point = tester.getCenter(finder);
  _Face? found;

  void walk(Element element) {
    if (found != null) return;
    final Rect? rect = _rectOf(element);
    if (rect != null && rect.contains(point)) {
      final BoxDecoration? decoration = _backgroundDecorationOf(element);
      if (decoration != null) {
        final Color? color = _decorationColor(decoration, rect, point);
        if (color != null) {
          found = _Face(color: color, decoration: decoration, rect: rect);
          return;
        }
      }
    }
    element.visitChildElements(walk);
  }

  walk(tester.element(finder));
  if (found == null) {
    throw StateError('$finder 自己没有画出任何面，取不到实测色');
  }
  return found!;
}

/// 目标脚下真正叠着的那一层：按真实绘制顺序合成——祖先自身的底色，
/// 以及每一级祖先里排在目标分支之前的兄弟子树（Stack 的下层就走这条路）。
Color _backdropOf(WidgetTester tester, Finder finder) {
  final Element target = tester.element(finder);
  final Offset point = tester.getCenter(finder);
  final List<Element> path = _pathFromRoot(target);
  Color result = _bodyColor(tester);

  for (var index = 0; index < path.length - 1; index++) {
    final Element element = path[index];
    final Element branch = path[index + 1];
    final Rect? rect = _rectOf(element);
    if (rect != null && rect.contains(point)) {
      final Color? own = _paintOf(element, point, foreground: false);
      if (own != null) result = Color.alphaBlend(own, result);
    }

    final List<Element> children = <Element>[];
    element.visitChildElements(children.add);
    final int branchIndex = children.indexOf(branch);
    if (branchIndex == -1) {
      throw StateError('元素树里找不到目标所属分支，取样无法还原绘制顺序');
    }
    for (final Element sibling in children.take(branchIndex)) {
      result = _compositeSubtree(result, sibling, point);
    }
  }
  return result;
}

Color _compositeSubtree(Color base, Element element, Offset point) {
  final Color? below = _paintOf(element, point, foreground: false);
  if (below != null) base = Color.alphaBlend(below, base);
  final List<Element> children = <Element>[];
  element.visitChildElements(children.add);
  for (final Element child in children) {
    base = _compositeSubtree(base, child, point);
  }
  // foregroundDecoration 画在子树之后，所以要在回溯时合成。
  final Color? above = _paintOf(element, point, foreground: true);
  if (above != null) base = Color.alphaBlend(above, base);
  return base;
}

List<Element> _pathFromRoot(Element target) {
  final List<Element> upward = <Element>[];
  target.visitAncestorElements((Element element) {
    upward.add(element);
    return true;
  });
  return <Element>[...upward.reversed, target];
}

Rect? _rectOf(Element element) {
  final Object? renderObject = element.renderObject;
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

BoxDecoration? _backgroundDecorationOf(Element element) {
  final Widget widget = element.widget;
  if (widget is DecoratedBox &&
      widget.position == DecorationPosition.background) {
    final Decoration decoration = widget.decoration;
    return decoration is BoxDecoration ? decoration : null;
  }
  return null;
}

/// 不经过 BoxDecoration 的实底：Scaffold 的 Material 与 ColoredBox。
Color? _flatPaintOf(Element element) {
  final Widget widget = element.widget;
  if (widget is ColoredBox && widget.color.a > 0.0) {
    return widget.color;
  }
  if (widget is Material &&
      widget.type != MaterialType.transparency &&
      widget.color != null &&
      widget.color!.a > 0.0) {
    return widget.color;
  }
  return null;
}

Color? _paintOf(Element element, Offset point, {required bool foreground}) {
  // 任何一层都要先落在取样点上：按钮内部的 Material 是实底，
  // 少这一步就会把不相干条目的颜色混进目标脚下，取样结果全盘失真。
  final Rect? rect = _rectOf(element);
  if (rect == null || !rect.contains(point)) return null;
  final Widget widget = element.widget;
  if (widget is! DecoratedBox) {
    return foreground ? null : _flatPaintOf(element);
  }
  final bool isForeground = widget.position == DecorationPosition.foreground;
  if (isForeground != foreground) return null;
  return _decorationColor(widget.decoration, rect, point);
}

Color? _decorationColor(Decoration decoration, Rect rect, Offset point) {
  Color? base;
  Gradient? gradient;
  if (decoration is BoxDecoration) {
    base = decoration.color;
    gradient = decoration.gradient;
  } else if (decoration is ShapeDecoration) {
    base = decoration.color;
    gradient = decoration.gradient;
  }
  Color? result;
  if (base != null && base.a > 0.0) result = base;
  if (gradient != null) {
    final Color sampled = _sampleGradient(gradient, rect, point);
    result = result == null ? sampled : Color.alphaBlend(sampled, result);
  }
  return result;
}

Color _textColor(WidgetTester tester, Finder finder) {
  final Color? color = tester.widget<Text>(finder).style?.color;
  if (color == null) {
    throw StateError('$finder 的文字没有自带颜色，取样无法确定实际墨色');
  }
  return color;
}

Color _bodyColor(WidgetTester tester) {
  final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
  return scaffold.backgroundColor ??
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor;
}

/// 页面上此刻所有真正带渐变的色层（含按钮 styleFrom 指定的实底）。
Set<Color> _gradientColorsInTree(WidgetTester tester) {
  final Set<Color> colors = <Color>{};

  void addGradient(Gradient? gradient) {
    if (gradient is LinearGradient) colors.addAll(gradient.colors);
  }

  void addDecoration(Decoration? decoration) {
    if (decoration is BoxDecoration) {
      addGradient(decoration.gradient);
    } else if (decoration is ShapeDecoration) {
      addGradient(decoration.gradient);
    }
  }

  for (final Element element in tester.allElements) {
    final Widget widget = element.widget;
    if (widget is DecoratedBox) {
      addDecoration(widget.decoration);
    } else if (widget is Container) {
      addDecoration(widget.decoration);
      addDecoration(widget.foregroundDecoration);
    } else if (widget is AppAnimatedContainer) {
      addDecoration(widget.decoration);
      addDecoration(widget.foregroundDecoration);
    } else if (widget is FilledButton) {
      final Color? background = widget.style?.backgroundColor?.resolve(
        const <WidgetState>{},
      );
      if (background != null) colors.add(background);
    }
  }
  return colors;
}

/// ---------------------------------------------------------------------------
/// 宿主与假接口
/// ---------------------------------------------------------------------------

class _Face {
  const _Face({
    required this.color,
    required this.decoration,
    required this.rect,
  });

  final Color color;
  final BoxDecoration decoration;
  final Rect rect;
}

Future<FunctionDrinkLogic> _pumpHome(
  WidgetTester tester, {
  required bool dark,
  required List<Map> devices,
  _FakeDrinkApi? api,
}) async {
  // 同一个 test 里第二次 pumpWidget 会复用 _FunctionDrinkPageState：
  // initState 不再执行，页面还绑着上一个 logic 的状态（接水态、备注都会串味）。
  // 先清空一次树，保证每次拿到的都是新 State。
  await tester.pumpWidget(const SizedBox());

  final logic = FunctionDrinkLogic(
    drinkApi: api ?? _FakeDrinkApi(devices: devices),
    redirectToLogin: () {},
  );
  addTearDown(logic.onClose);
  logic.state.isLoading.value = false;
  logic.state.deviceList.value = List<Map>.of(devices);
  logic.state.choiceDevice.value = devices.isEmpty ? -1 : 0;

  await tester.pumpWidget(
    GetMaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      home: FunctionDrinkPage(logic: logic),
    ),
  );
  await _pumpUntil(tester, () => find.text('开始用水').evaluate().isNotEmpty);
  return logic;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(milliseconds: 500),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!predicate()) {
    if (stopwatch.elapsed >= timeout) {
      fail('Timed out while waiting for condition.');
    }
    await tester.pump(const Duration(milliseconds: 10));
  }
}

class _FakeDrinkApi implements DrinkApiClient {
  _FakeDrinkApi({List<Map>? devices})
    : _devices = devices ?? const <Map>[],
      _ok = const DrinkResult(success: true, code: 0);

  final List<Map> _devices;
  final DrinkResult _ok;
  final List<String> startDrinkRequests = <String>[];
  final List<String> endDrinkRequests = <String>[];

  @override
  Future<List<Map>> deviceList() async => List<Map>.of(_devices);

  @override
  Future<bool> favoDevice({required String id, required bool isUnFavo}) async =>
      true;

  @override
  Future<DrinkResult> startDrink({required String id}) async {
    startDrinkRequests.add(id);
    return _ok;
  }

  @override
  Future<DrinkResult> endDrink({required String id}) async {
    endDrinkRequests.add(id);
    return _ok;
  }

  @override
  Future<bool> isAvailableDevice({required String id}) async => false;

  @override
  Future<String> getToken() async => 'token';

  @override
  Future<void> setToken({required String token}) async {}
}
