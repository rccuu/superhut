import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/ui/app_animated_container.dart';
import 'package:superhut/core/ui/apple_glass.dart';

void main() {
  Future<void> pumpContainer(
    WidgetTester tester, {
    required bool isLite,
    bool reduceMotion = false,
    bool tickerModeEnabled = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: TickerMode(
            enabled: tickerModeEnabled,
            child: AppGlassPerformanceScope(
              isLite: isLite,
              child: const AppAnimatedContainer(
                duration: Duration(milliseconds: 180),
                width: 48,
                height: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('keeps configured duration in full effects mode', (tester) async {
    await pumpContainer(tester, isLite: false);

    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(container.duration, const Duration(milliseconds: 180));
  });

  testWidgets('uses a static container in lite mode', (tester) async {
    await pumpContainer(tester, isLite: true);

    expect(find.byType(AppAnimatedContainer), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('uses a static container when animations are disabled', (
    tester,
  ) async {
    await pumpContainer(tester, isLite: false, reduceMotion: true);

    expect(find.byType(AppAnimatedContainer), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('uses a static container when ticker mode is disabled', (
    tester,
  ) async {
    await pumpContainer(tester, isLite: false, tickerModeEnabled: false);

    expect(find.byType(AppAnimatedContainer), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.byType(Container), findsWidgets);
  });
}
