import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/home_route.dart';
import 'package:superhut/home/homeview/view.dart';

void main() {
  testWidgets('builds the home page route with the requested tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(onGenerateRoute: (_) => buildHomePageRoute(initialIndex: 1)),
    );

    final page = tester.widget<HomeviewPage>(find.byType(HomeviewPage));
    expect(page.initialIndex, 1);
  });
}
