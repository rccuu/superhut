import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/core/ui/app_snack_bar.dart';
import 'package:superhut/main.dart';

void main() {
  testWidgets('builds themed floating snackbar with icon and action', (
    tester,
  ) async {
    late BuildContext capturedContext;
    var actionPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    showAppSnackBar(
      capturedContext,
      message: '智慧工大登录状态可能已失效，请重新登录后再试',
      type: AppSnackBarType.warning,
      icon: CupertinoIcons.lock_rotation,
      actionLabel: '重新登录',
      onAction: () {
        actionPressed = true;
      },
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppSnackBarContent), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.lock_rotation), findsOneWidget);
    expect(find.text('智慧工大登录状态可能已失效，请重新登录后再试'), findsOneWidget);
    expect(find.text('重新登录'), findsOneWidget);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.elevation, 0);
    expect(snackBar.margin, const EdgeInsets.fromLTRB(16, 0, 16, 72));

    await tester.tap(find.text('重新登录'));
    expect(actionPressed, isTrue);
  });
}
