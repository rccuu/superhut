import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/ui/ambient_bubble_field.dart';
import 'package:superhut/core/ui/apple_glass.dart';

void main() {
  const bubbles = [
    AmbientBubbleSpec(
      xFactor: 0.5,
      size: 20,
      speed: 0.5,
      drift: 10,
      phase: 0.1,
    ),
  ];

  Future<void> pumpField(
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
                child: AmbientBubbleField(
                  isActive: true,
                  color: Colors.blue,
                  bubbles: bubbles,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('animates bubble field through painter repaint in full mode', (
    tester,
  ) async {
    await pumpField(tester, isLite: false);

    dynamic state = tester.state(find.byType(AmbientBubbleField));
    expect(state.debugHasController, isTrue);
    expect(
      find.descendant(
        of: find.byType(AmbientBubbleField),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AmbientBubbleField),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses static bubble field in lite mode', (tester) async {
    await pumpField(tester, isLite: true);

    expect(
      find.descendant(
        of: find.byType(AmbientBubbleField),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AmbientBubbleField),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('releases controller when switching to lite mode', (
    tester,
  ) async {
    await pumpField(tester, isLite: false);

    dynamic state = tester.state(find.byType(AmbientBubbleField));
    expect(state.debugHasController, isTrue);

    await pumpField(tester, isLite: true);

    state = tester.state(find.byType(AmbientBubbleField));
    expect(state.debugHasController, isFalse);
    expect(
      find.descendant(
        of: find.byType(AmbientBubbleField),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );

    await pumpField(tester, isLite: false);

    state = tester.state(find.byType(AmbientBubbleField));
    expect(state.debugHasController, isTrue);
    expect(
      find.descendant(
        of: find.byType(AmbientBubbleField),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AmbientBubbleField),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses static bubble field when animations are disabled', (
    tester,
  ) async {
    await pumpField(tester, isLite: false, reduceMotion: true);

    expect(
      find.descendant(
        of: find.byType(AmbientBubbleField),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AmbientBubbleField),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses static bubble field when ticker mode is disabled', (
    tester,
  ) async {
    await pumpField(tester, isLite: false, tickerModeEnabled: false);

    expect(
      find.descendant(
        of: find.byType(AmbientBubbleField),
        matching: find.byType(AnimatedBuilder),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AmbientBubbleField),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });
}
