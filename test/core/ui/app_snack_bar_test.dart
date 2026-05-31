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

  testWidgets('coalesces duplicate snackbars within the duplicate window', (
    tester,
  ) async {
    late BuildContext capturedContext;

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

    final first = showAppSnackBar(
      capturedContext,
      message: '设备状态提醒：检测到有设备尚未关闭',
      type: AppSnackBarType.warning,
    );
    final second = showAppSnackBar(
      capturedContext,
      message: '设备状态提醒：检测到有设备尚未关闭',
      type: AppSnackBarType.warning,
    );
    await tester.pump();

    expect(first, isNotNull);
    expect(second, same(first));
    expect(find.byType(AppSnackBarContent), findsOneWidget);
    expect(find.text('设备状态提醒：检测到有设备尚未关闭'), findsOneWidget);
  });

  testWidgets('shows a new snackbar when duplicate window is disabled', (
    tester,
  ) async {
    late BuildContext capturedContext;

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

    final first = showAppSnackBar(
      capturedContext,
      message: '请输入有效的数字格式',
      type: AppSnackBarType.warning,
      duplicateWindow: Duration.zero,
    );
    final second = showAppSnackBar(
      capturedContext,
      message: '请输入有效的数字格式',
      type: AppSnackBarType.warning,
      duplicateWindow: Duration.zero,
    );
    await tester.pump();

    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(second, isNot(same(first)));
    expect(find.byType(AppSnackBarContent), findsOneWidget);
    expect(find.text('请输入有效的数字格式'), findsOneWidget);
  });

  testWidgets('clears duplicate record after snackbar closes', (tester) async {
    late BuildContext capturedContext;

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

    final first = showAppSnackBar(
      capturedContext,
      message: '设备已关闭',
      type: AppSnackBarType.success,
    );
    await tester.pump();

    expect(first, isNotNull);

    first!.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await first.closed;
    await tester.pump();

    final second = showAppSnackBar(
      capturedContext,
      message: '设备已关闭',
      type: AppSnackBarType.success,
    );
    await tester.pump();

    expect(second, isNotNull);
    expect(second, isNot(same(first)));
    expect(find.text('设备已关闭'), findsOneWidget);
  });
}
