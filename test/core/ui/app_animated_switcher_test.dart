import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/ui/app_animated_switcher.dart';
import 'package:superhut/core/ui/apple_glass.dart';

void main() {
  Future<void> pumpSwitcher(
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
              child: const AppAnimatedSwitcher(
                duration: Duration(milliseconds: 180),
                child: Text('ready', key: ValueKey('ready')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('keeps configured duration in full effects mode', (tester) async {
    await pumpSwitcher(tester, isLite: false);

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.duration, const Duration(milliseconds: 180));
  });

  testWidgets('uses a static child in lite mode', (tester) async {
    await pumpSwitcher(tester, isLite: true);

    expect(find.byType(AppAnimatedSwitcher), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('uses a static child when animations are disabled', (
    tester,
  ) async {
    await pumpSwitcher(tester, isLite: false, reduceMotion: true);

    expect(find.byType(AppAnimatedSwitcher), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('uses a static child when ticker mode is disabled', (
    tester,
  ) async {
    await pumpSwitcher(tester, isLite: false, tickerModeEnabled: false);

    expect(find.byType(AppAnimatedSwitcher), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(find.text('ready'), findsOneWidget);
  });
}
