import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/ui/app_page_route.dart';

void main() {
  testWidgets('uses the lightweight page route on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    try {
      final route = buildAppPageRoute<void>(builder: (_) => const SizedBox());

      expect(route, isA<PageRouteBuilder<void>>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('keeps the platform Material route off Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      final route = buildAppPageRoute<void>(builder: (_) => const SizedBox());

      expect(route, isA<MaterialPageRoute<void>>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('skips transition widgets when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppLightRouteTransition(
            animation: kAlwaysCompleteAnimation,
            child: const Text('route child'),
          ),
        ),
      ),
    );

    expect(find.text('route child'), findsOneWidget);
    expect(find.byType(SlideTransition), findsNothing);
  });

  testWidgets('skips transition widgets when ticker mode is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      TickerMode(
        enabled: false,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppLightRouteTransition(
            animation: kAlwaysCompleteAnimation,
            child: const Text('route child'),
          ),
        ),
      ),
    );

    expect(find.text('route child'), findsOneWidget);
    expect(find.byType(FadeTransition), findsNothing);
    expect(find.byType(SlideTransition), findsNothing);
  });
}
