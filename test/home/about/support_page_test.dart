import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:superhut/core/ui/app_loading_indicator.dart';
import 'package:superhut/home/about/support_page.dart';

void main() {
  Widget buildPage({SupportClipboardWriter? writeClipboard}) {
    return MaterialApp(home: SupportPage(writeClipboard: writeClipboard));
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
    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('network switch replaces the qr without animation overlap', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support-qr-trc20')), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('support-network-bsc')));
    await tester.pump();

    expect(find.byKey(const ValueKey('support-qr-bsc')), findsOneWidget);
    expect(find.byKey(const ValueKey('support-qr-trc20')), findsNothing);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('copy button ignores duplicate taps while clipboard is writing', (
    tester,
  ) async {
    final writeCompleter = Completer<void>();
    final copiedTexts = <String>[];

    await tester.pumpWidget(
      buildPage(
        writeClipboard: (text) {
          copiedTexts.add(text);
          return writeCompleter.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    final copyButton = find.byKey(const ValueKey('support-copy-button'));
    final onPressed = tester.widget<FilledButton>(copyButton).onPressed;
    onPressed?.call();
    onPressed?.call();
    await tester.pump();

    expect(copiedTexts, ['TNvVV3XgpDbnfT8kAVB5Pwe7UYVCfqekDT']);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(copyButton).onPressed, isNull);

    writeCompleter.complete();
    await tester.pump();

    expect(find.byType(AppLoadingIndicator), findsNothing);
    expect(find.text('复制地址'), findsOneWidget);
  });

  testWidgets('copy button recovers after clipboard write fails', (
    tester,
  ) async {
    var copyCalls = 0;

    await tester.pumpWidget(
      buildPage(
        writeClipboard: (_) async {
          copyCalls++;
          throw Exception('clipboard unavailable');
        },
      ),
    );
    await tester.pumpAndSettle();

    final copyButton = find.byKey(const ValueKey('support-copy-button'));
    final onPressed = tester.widget<FilledButton>(copyButton).onPressed;
    onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(copyCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('复制地址失败，请稍后重试'), findsOneWidget);
    expect(find.byType(AppLoadingIndicator), findsNothing);
    expect(find.text('复制地址'), findsOneWidget);

    onPressed?.call();
    await tester.pump();
    await tester.pump();

    expect(copyCalls, 2);
  });
}
