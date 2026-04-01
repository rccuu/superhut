import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:superhut/home/about/support_page.dart';

void main() {
  Widget buildPage() {
    return const MaterialApp(home: SupportPage());
  }

  testWidgets('defaults to trc20 and can switch to bsc', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('TNvVV3XgpDbnfT8kAVB5Pwe7UYVCfqekDT'), findsOneWidget);
    expect(
      find.text('0xca48641aad9c37f74d2999686799deaee95b6105'),
      findsNothing,
    );
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('support-network-bsc')));
    await tester.pumpAndSettle();

    expect(
      find.text('0xca48641aad9c37f74d2999686799deaee95b6105'),
      findsOneWidget,
    );
    expect(find.text('TNvVV3XgpDbnfT8kAVB5Pwe7UYVCfqekDT'), findsNothing);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}
