import 'package:flutter/material.dart';
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

  testWidgets('drops backdrop blur in lite mode', (tester) async {
    await pumpPanel(tester, isLite: true);

    expect(find.byType(BackdropFilter), findsNothing);
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
