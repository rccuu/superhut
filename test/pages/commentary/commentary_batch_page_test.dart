import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/Commentary/commentary_batch_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('duplicate batch taps open a single course list route', (
    tester,
  ) async {
    var buildCoursePageCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryBatchPage(
          loadBatches:
              () async => [
                {
                  'BATCHID': 'batch-1',
                  'PJ01ID': 'pj01-1',
                  'PJ05ID': 'pj05-1',
                  'EVALUATIONBATCH': '2026 春季评教',
                  'KCLBMC': '理论课',
                  'XQMC': '2025-2026-2',
                },
              ],
          buildCoursePage: (batch) {
            buildCoursePageCalls++;
            return Scaffold(
              appBar: AppBar(title: const Text('课程列表')),
              body: Text('batch ${batch['BATCHID']}'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final batchTile = find.text('2026 春季评教');
    final batchTileCenter = tester.getCenter(batchTile);
    await tester.tapAt(batchTileCenter);
    await tester.tapAt(batchTileCenter);
    await tester.pumpAndSettle();

    expect(buildCoursePageCalls, 1);
    expect(find.text('课程列表'), findsOneWidget);
    expect(find.text('batch batch-1'), findsOneWidget);

    Navigator.of(tester.element(find.text('课程列表'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(batchTile);
    await tester.pumpAndSettle();

    expect(buildCoursePageCalls, 2);
  });

  testWidgets('batch tap recovers after route push throws', (tester) async {
    var pushCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CommentaryBatchPage(
          loadBatches:
              () async => [
                {
                  'BATCHID': 'batch-1',
                  'PJ01ID': 'pj01-1',
                  'PJ05ID': 'pj05-1',
                  'EVALUATIONBATCH': '2026 春季评教',
                  'KCLBMC': '理论课',
                  'XQMC': '2025-2026-2',
                },
              ],
          buildCoursePage: (_) => const Scaffold(body: Text('课程列表')),
          pushRoute: <T>(context, route) async {
            pushCalls++;
            throw Exception('navigator unavailable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final batchTile = find.text('2026 春季评教');
    await tester.tapAt(tester.getCenter(batchTile));
    await tester.pump();
    await tester.pump();

    expect(pushCalls, 1);
    expect(tester.takeException(), isNull);
    expect(find.text('无法打开评教课程列表，请稍后重试'), findsOneWidget);

    await tester.tapAt(tester.getCenter(batchTile));
    await tester.pump();
    await tester.pump();

    expect(pushCalls, 2);
  });
}
