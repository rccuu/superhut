import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/ui/apple_glass.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPanel(WidgetTester tester, {required bool isLite}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppGlassPerformanceScope(
              isLite: isLite,
              child: const GlassPanel(
                style: GlassPanelStyle.card,
                blur: 18,
                child: SizedBox(width: 120, height: 80),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('respects disable animations as lite mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              return Text('${AppGlassPerformanceScope.isLiteOf(context)}');
            },
          ),
        ),
      ),
    );

    expect(find.text('true'), findsOneWidget);
  });

  testWidgets('uses lite scope as reduced motion signal', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppGlassPerformanceScope(
          isLite: true,
          child: Builder(
            builder: (context) {
              return Text(
                '${AppGlassPerformanceScope.shouldReduceMotionOf(context)}',
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('true'), findsOneWidget);
  });

  testWidgets('keeps motion when full effects are explicit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppGlassPerformanceScope(
          isLite: false,
          child: Builder(
            builder: (context) {
              return Text(
                '${AppGlassPerformanceScope.shouldReduceMotionOf(context)}',
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('false'), findsOneWidget);
  });

  testWidgets('uses disabled ticker mode as reduced motion signal', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TickerMode(
          enabled: false,
          child: AppGlassPerformanceScope(
            isLite: false,
            child: Builder(
              builder: (context) {
                return Text(
                  '${AppGlassPerformanceScope.shouldReduceMotionOf(context)}',
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('true'), findsOneWidget);
  });

  testWidgets('uses lite layout on Android by default', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Text(
                '${AppGlassPerformanceScope.shouldUseLiteLayoutOf(context)}',
              );
            },
          ),
        ),
      );

      expect(find.text('true'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('keeps full layout on non-Android by default', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Text(
                '${AppGlassPerformanceScope.shouldUseLiteLayoutOf(context)}',
              );
            },
          ),
        ),
      );

      expect(find.text('false'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('uses lite layout when full effects are not explicit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppGlassPerformanceScope(
          isLite: true,
          child: Builder(
            builder: (context) {
              return Text(
                '${AppGlassPerformanceScope.shouldUseLiteLayoutOf(context)}',
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('true'), findsOneWidget);
  });

  testWidgets('keeps full layout when full effects are explicit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppGlassPerformanceScope(
          isLite: false,
          child: Builder(
            builder: (context) {
              return Text(
                '${AppGlassPerformanceScope.shouldUseLiteLayoutOf(context)}',
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('false'), findsOneWidget);
  });

  testWidgets('drops backdrop blur in lite mode', (tester) async {
    await pumpPanel(tester, isLite: true);

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('scales custom box shadows in lite mode', (tester) async {
    const sourceShadow = BoxShadow(
      color: Color(0x80223344),
      offset: Offset(10, 20),
      blurRadius: 30,
      spreadRadius: -12,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: AppGlassPerformanceScope(
          isLite: true,
          child: GlassPanel(
            style: GlassPanelStyle.floating,
            boxShadow: [sourceShadow],
            child: SizedBox(width: 120, height: 80),
          ),
        ),
      ),
    );

    final decoration = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((decoration) => decoration.boxShadow?.isNotEmpty == true);
    final shadow = decoration.boxShadow!.single;

    expect(
      shadow.color,
      sourceShadow.color.withValues(alpha: sourceShadow.color.a * 0.62),
    );
    expect(shadow.offset.dx, closeTo(7.2, 0.0001));
    expect(shadow.offset.dy, closeTo(12.4, 0.0001));
    expect(shadow.blurRadius, 10);
    expect(shadow.spreadRadius, -6);
    expect(shadow.blurStyle, sourceShadow.blurStyle);
  });

  testWidgets('drops ambient orb image filters in lite background mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppGlassPerformanceScope(
          isLite: true,
          child: AppGlassBackground(
            style: AppGlassBackgroundStyle.rich,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets('keeps ambient orb image filters in full background mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppGlassPerformanceScope(
          isLite: false,
          child: AppGlassBackground(
            style: AppGlassBackgroundStyle.rich,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );

    expect(find.byType(ImageFiltered), findsWidgets);
  });
}
