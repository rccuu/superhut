import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/ui/apple_glass.dart';
import 'package:superhut/core/ui/scanner_line.dart';

void main() {
  Future<void> pumpScannerLine(
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
              child: const SizedBox(
                width: 160,
                height: 160,
                child: AppScannerLine(color: Colors.blue),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('animates scanner line through painter repaint in full mode', (
    tester,
  ) async {
    await pumpScannerLine(tester, isLite: false);

    dynamic state = tester.state(find.byType(AppScannerLine));
    expect(state.debugHasController, isTrue);
    expect(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('isolates scanner repaint work', (tester) async {
    await pumpScannerLine(tester, isLite: false);

    expect(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
  });

  testWidgets('marks animated paint as changing work', (tester) async {
    await pumpScannerLine(tester, isLite: false);

    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(paint.isComplex, isTrue);
    expect(paint.willChange, isTrue);
  });

  testWidgets('uses static scanner line in lite mode', (tester) async {
    await pumpScannerLine(tester, isLite: true);

    expect(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );

    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(paint.willChange, isFalse);
  });

  testWidgets('releases controller when switching to lite mode', (
    tester,
  ) async {
    await pumpScannerLine(tester, isLite: false);

    dynamic state = tester.state(find.byType(AppScannerLine));
    expect(state.debugHasController, isTrue);

    await pumpScannerLine(tester, isLite: true);

    state = tester.state(find.byType(AppScannerLine));
    expect(state.debugHasController, isFalse);
    expect(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );

    await pumpScannerLine(tester, isLite: false);

    state = tester.state(find.byType(AppScannerLine));
    expect(state.debugHasController, isTrue);
    expect(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
  });

  testWidgets('uses static scanner line when animations are disabled', (
    tester,
  ) async {
    await pumpScannerLine(tester, isLite: false, reduceMotion: true);

    expect(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses static scanner line when ticker mode is disabled', (
    tester,
  ) async {
    await pumpScannerLine(tester, isLite: false, tickerModeEnabled: false);

    expect(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AppScannerLine),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });
}
