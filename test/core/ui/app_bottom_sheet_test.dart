import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/ui/app_bottom_sheet.dart';

void main() {
  Widget buildSheetRouteDurationProbe({bool tickerModeEnabled = true}) {
    return MaterialApp(
      home: TickerMode(
        enabled: tickerModeEnabled,
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showAppAdaptiveBottomSheet<void>(
                  context: context,
                  builder: (sheetContext) {
                    final route = ModalRoute.of(sheetContext);
                    return SizedBox(
                      height: 120,
                      child: Text(
                        'duration ${route?.transitionDuration.inMilliseconds}',
                      ),
                    );
                  },
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
  }

  testWidgets('uses the native Material bottom sheet on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  showAppAdaptiveBottomSheet<void>(
                    context: context,
                    builder:
                        (_) => const SizedBox(
                          height: 120,
                          child: Text('Android sheet'),
                        ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Android sheet'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('uses a short Material sheet transition on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    try {
      await tester.pumpWidget(buildSheetRouteDurationProbe());

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('duration 140'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'disables Android sheet transition when ticker mode is disabled',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      try {
        await tester.pumpWidget(
          buildSheetRouteDurationProbe(tickerModeEnabled: false),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('duration 0'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
