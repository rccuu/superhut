import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/ui/app_progress_indicator.dart';
import 'package:superhut/core/ui/apple_glass.dart';

void main() {
  Future<void> pumpProgress(
    WidgetTester tester, {
    required bool isLite,
    bool reduceMotion = false,
    bool tickerModeEnabled = true,
    double? value,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: TickerMode(
            enabled: tickerModeEnabled,
            child: AppGlassPerformanceScope(
              isLite: isLite,
              child: AppLinearProgressIndicator(value: value),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('keeps indeterminate progress in full effects mode', (
    tester,
  ) async {
    await pumpProgress(tester, isLite: false);

    expect(
      find.byKey(
        const ValueKey<String>('app-linear-progress-repaint-boundary'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppLinearProgressIndicator),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, isNull);
  });

  testWidgets('uses static progress in lite mode', (tester) async {
    await pumpProgress(tester, isLite: true);

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 0.42);
    expect(
      find.descendant(
        of: find.byType(AppLinearProgressIndicator),
        matching: find.byType(RepaintBoundary),
      ),
      findsNothing,
    );
  });

  testWidgets('uses static progress when animations are disabled', (
    tester,
  ) async {
    await pumpProgress(tester, isLite: false, reduceMotion: true);

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 0.42);
    expect(
      find.descendant(
        of: find.byType(AppLinearProgressIndicator),
        matching: find.byType(RepaintBoundary),
      ),
      findsNothing,
    );
  });

  testWidgets('uses static progress when ticker mode is disabled', (
    tester,
  ) async {
    await pumpProgress(tester, isLite: false, tickerModeEnabled: false);

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 0.42);
  });

  testWidgets('preserves determinate progress value', (tester) async {
    await pumpProgress(tester, isLite: true, value: 0.7);

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, 0.7);
    expect(
      find.descendant(
        of: find.byType(AppLinearProgressIndicator),
        matching: find.byType(RepaintBoundary),
      ),
      findsNothing,
    );
  });
}
