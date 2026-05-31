import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/ui/app_loading_indicator.dart';
import 'package:superhut/core/ui/apple_glass.dart';

void main() {
  Future<void> pumpIndicator(
    WidgetTester tester, {
    required bool isLite,
    bool reduceMotion = false,
    bool tickerModeEnabled = true,
    bool animating = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: TickerMode(
            enabled: tickerModeEnabled,
            child: AppGlassPerformanceScope(
              isLite: isLite,
              child: AppLoadingIndicator(animating: animating),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('animates in full effects mode by default', (tester) async {
    await pumpIndicator(tester, isLite: false);

    final indicator = tester.widget<CupertinoActivityIndicator>(
      find.byType(CupertinoActivityIndicator),
    );
    expect(indicator.animating, isTrue);
    expect(
      find.descendant(
        of: find.byType(AppLoadingIndicator),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
  });

  testWidgets('stops animation in lite mode', (tester) async {
    await pumpIndicator(tester, isLite: true);

    final indicator = tester.widget<CupertinoActivityIndicator>(
      find.byType(CupertinoActivityIndicator),
    );
    expect(indicator.animating, isFalse);
    expect(
      find.descendant(
        of: find.byType(AppLoadingIndicator),
        matching: find.byType(RepaintBoundary),
      ),
      findsNothing,
    );
  });

  testWidgets('stops animation when animations are disabled', (tester) async {
    await pumpIndicator(tester, isLite: false, reduceMotion: true);

    final indicator = tester.widget<CupertinoActivityIndicator>(
      find.byType(CupertinoActivityIndicator),
    );
    expect(indicator.animating, isFalse);
  });

  testWidgets('stops animation when ticker mode is disabled', (tester) async {
    await pumpIndicator(tester, isLite: false, tickerModeEnabled: false);

    final indicator = tester.widget<CupertinoActivityIndicator>(
      find.byType(CupertinoActivityIndicator),
    );
    expect(indicator.animating, isFalse);
  });

  testWidgets('respects explicit animating false', (tester) async {
    await pumpIndicator(tester, isLite: false, animating: false);

    final indicator = tester.widget<CupertinoActivityIndicator>(
      find.byType(CupertinoActivityIndicator),
    );
    expect(indicator.animating, isFalse);
    expect(
      find.descendant(
        of: find.byType(AppLoadingIndicator),
        matching: find.byType(RepaintBoundary),
      ),
      findsNothing,
    );
  });
}
