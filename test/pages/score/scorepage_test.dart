import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/score/logic.dart';
import 'package:superhut/pages/score/scorepage.dart';

void main() {
  testWidgets('background semester probing does not persist score summaries', (
    tester,
  ) async {
    final scoreCalls = <_ScoreCall>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ScorePage(
          loadSemesters:
              () async => const SemesterListResult(
                idList: ['2024-2025-1', '2024-2025-2'],
                nowId: '2024-2025-2',
              ),
          loadScore: (semesterId, {bool persistSummary = true}) async {
            scoreCalls.add(
              _ScoreCall(
                semesterId: semesterId,
                persistSummary: persistSummary,
              ),
            );
            return ScoreLoadResult(
              achievement:
                  semesterId == '2024-2025-1'
                      ? const []
                      : [
                        Score(
                          curriculumAttributes: '',
                          state: '通过',
                          examName: '期末',
                          courseNature: '必修',
                          fraction: '90',
                          courseName: '高等数学',
                          examinationNature: '考试',
                          gradePoints: '4.0',
                          credit: '4',
                        ),
                      ],
              yxzxf: semesterId.isEmpty ? '40' : '10',
              zxfjd: semesterId.isEmpty ? '120' : '30',
              pjxfjd: semesterId.isEmpty ? '3.5' : '2.0',
            );
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => scoreCalls.length >= 3);

    expect(scoreCalls.first.semesterId, isEmpty);
    expect(scoreCalls.first.persistSummary, isTrue);
    expect(
      scoreCalls.skip(1).map((call) => call.persistSummary),
      everyElement(isFalse),
    );
    expect(
      scoreCalls.map((call) => call.semesterId),
      containsAll(['2024-2025-1', '2024-2025-2']),
    );
  });

  testWidgets('background semester probing stops after page unmounts', (
    tester,
  ) async {
    final firstProbeCompleter = Completer<ScoreLoadResult>();
    final scoreCalls = <_ScoreCall>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ScorePage(
          loadSemesters:
              () async => const SemesterListResult(
                idList: ['2024-2025-1', '2024-2025-2'],
                nowId: '2024-2025-2',
              ),
          loadScore: (semesterId, {bool persistSummary = true}) {
            scoreCalls.add(
              _ScoreCall(
                semesterId: semesterId,
                persistSummary: persistSummary,
              ),
            );
            if (semesterId == '2024-2025-1') {
              return firstProbeCompleter.future;
            }
            return Future.value(_scoreResult(courseName: '全部成绩'));
          },
        ),
      ),
    );

    await _pumpUntil(
      tester,
      () => scoreCalls.any((call) => call.semesterId == '2024-2025-1'),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('replacement'))),
    );
    firstProbeCompleter.complete(_scoreResult(courseName: '旧探测成绩'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('replacement'), findsOneWidget);
    expect(
      scoreCalls.map((call) => call.semesterId),
      isNot(contains('2024-2025-2')),
    );
  });

  testWidgets(
    'background semester probing errors keep current score and semester list',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final scoreCalls = <_ScoreCall>[];

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: ScorePage(
              loadSemesters:
                  () async => const SemesterListResult(
                    idList: ['2024-2025-1', '2024-2025-2'],
                    nowId: '2024-2025-2',
                  ),
              loadScore: (semesterId, {bool persistSummary = true}) {
                scoreCalls.add(
                  _ScoreCall(
                    semesterId: semesterId,
                    persistSummary: persistSummary,
                  ),
                );
                if (semesterId == '2024-2025-1') {
                  throw Exception('probe unavailable token=secret-token');
                }
                return Future.value(_scoreResult(courseName: '全部成绩'));
              },
            ),
          ),
        );

        await _pumpUntil(
          tester,
          () => scoreCalls.any((call) => call.semesterId == '2024-2025-1'),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('全部成绩'), findsOneWidget);
        expect(find.textContaining('secret-token'), findsNothing);

        final selector = find.text('全部学期').first;
        await tester.tap(selector);
        await tester.pumpAndSettle();

        expect(find.text('选择学期'), findsOneWidget);
        expect(find.text('2024-2025 · 上学期'), findsOneWidget);
        expect(find.text('2024-2025 · 下学期'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('semester probing reset reuses cached all score data', (
    tester,
  ) async {
    final probeCompleter = Completer<ScoreLoadResult>();
    final scoreCalls = <_ScoreCall>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ScorePage(
          loadSemesters:
              () async => const SemesterListResult(
                idList: ['2024-2025-1'],
                nowId: '2024-2025-1',
              ),
          loadScore: (semesterId, {bool persistSummary = true}) {
            scoreCalls.add(
              _ScoreCall(
                semesterId: semesterId,
                persistSummary: persistSummary,
              ),
            );
            if (semesterId == '2024-2025-1' && !persistSummary) {
              return probeCompleter.future;
            }
            if (semesterId == '2024-2025-1') {
              return Future.value(
                const ScoreLoadResult(
                  achievement: [],
                  yxzxf: '-',
                  zxfjd: '-',
                  pjxfjd: '-',
                ),
              );
            }
            return Future.value(_scoreResult(courseName: '全部成绩'));
          },
        ),
      ),
    );

    await _pumpUntil(
      tester,
      () => scoreCalls.any(
        (call) => call.semesterId == '2024-2025-1' && !call.persistSummary,
      ),
    );
    await _pumpUntil(tester, () => find.text('全部成绩').evaluate().isNotEmpty);

    final dynamic pageState = tester.state(find.byType(ScorePage));
    await (pageState.debugRefreshScoresForSelection('2024-2025-1')
        as Future<void>);
    await tester.pump();

    expect(find.text('这个学期目前没有可展示的成绩条目。'), findsOneWidget);

    probeCompleter.complete(
      const ScoreLoadResult(
        achievement: [],
        yxzxf: '-',
        zxfjd: '-',
        pjxfjd: '-',
      ),
    );
    await _pumpUntil(tester, () => find.text('全部成绩').evaluate().isNotEmpty);

    expect(find.text('全部成绩'), findsOneWidget);
    expect(find.text('全部学期'), findsOneWidget);
    expect(
      scoreCalls
          .where((call) => call.semesterId.isEmpty && call.persistSummary)
          .length,
      1,
      reason: '后台探测重置回全部学期时应复用首屏缓存，不应再次请求全部成绩。',
    );
  });

  testWidgets(
    'concurrent same semester score loads share one in-flight request',
    (tester) async {
      final targetCompleter = Completer<ScoreLoadResult>();
      var targetLoadCalls = 0;
      final targetResult = _scoreResult(courseName: '离散数学');

      await tester.pumpWidget(
        MaterialApp(
          home: ScorePage(
            loadSemesters:
                () async => const SemesterListResult(idList: [], nowId: ''),
            loadScore: (semesterId, {bool persistSummary = true}) async {
              if (semesterId == '2024-2025-1') {
                targetLoadCalls++;
                return targetCompleter.future;
              }
              return _scoreResult(courseName: '全部成绩');
            },
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('全部成绩').evaluate().isNotEmpty);

      final dynamic pageState = tester.state(find.byType(ScorePage));
      final firstLoad =
          pageState.debugLoadScoreForSemester(
                '2024-2025-1',
                persistSummary: false,
              )
              as Future<ScoreLoadResult>;
      final secondLoad =
          pageState.debugLoadScoreForSemester(
                '2024-2025-1',
                persistSummary: false,
              )
              as Future<ScoreLoadResult>;
      await tester.pump();

      expect(targetLoadCalls, 1);

      targetCompleter.complete(targetResult);

      expect(await firstLoad, same(targetResult));
      expect(await secondLoad, same(targetResult));

      final cachedLoad =
          pageState.debugLoadScoreForSemester(
                '2024-2025-1',
                persistSummary: false,
              )
              as Future<ScoreLoadResult>;

      expect(await cachedLoad, same(targetResult));
      expect(targetLoadCalls, 1);
    },
  );

  testWidgets('stale semester selection does not override latest score data', (
    tester,
  ) async {
    final staleCompleter = Completer<ScoreLoadResult>();
    final latestCompleter = Completer<ScoreLoadResult>();

    await tester.pumpWidget(
      MaterialApp(
        home: ScorePage(
          loadSemesters:
              () async => const SemesterListResult(idList: [], nowId: ''),
          loadScore: (semesterId, {bool persistSummary = true}) {
            return switch (semesterId) {
              '2024-2025-1' => staleCompleter.future,
              '2024-2025-2' => latestCompleter.future,
              _ => Future.value(_scoreResult(courseName: '全部成绩')),
            };
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('全部成绩').evaluate().isNotEmpty);

    final dynamic pageState = tester.state(find.byType(ScorePage));
    final staleRefresh =
        pageState.debugRefreshScoresForSelection('2024-2025-1') as Future<void>;
    await tester.pump();
    final latestRefresh =
        pageState.debugRefreshScoresForSelection('2024-2025-2') as Future<void>;
    await tester.pump();

    latestCompleter.complete(_scoreResult(courseName: '最新学期成绩'));
    await latestRefresh;
    await tester.pump();

    expect(find.text('最新学期成绩'), findsOneWidget);

    staleCompleter.complete(_scoreResult(courseName: '旧学期成绩'));
    await staleRefresh;
    await tester.pump();

    expect(find.text('最新学期成绩'), findsOneWidget);
    expect(find.text('旧学期成绩'), findsNothing);
  });

  testWidgets('semester selection recovers after score loader throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScorePage(
          loadSemesters:
              () async => const SemesterListResult(idList: [], nowId: ''),
          loadScore: (semesterId, {bool persistSummary = true}) {
            if (semesterId == '2024-2025-1') {
              throw Exception('score unavailable');
            }
            return Future.value(_scoreResult(courseName: '全部成绩'));
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('全部成绩').evaluate().isNotEmpty);

    final dynamic pageState = tester.state(find.byType(ScorePage));
    await (pageState.debugRefreshScoresForSelection('2024-2025-1')
        as Future<void>);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('成绩加载失败'), findsOneWidget);
    expect(find.text('成绩加载失败，请稍后重试'), findsWidgets);
    expect(find.text('2024-2025 上'), findsOneWidget);
  });

  testWidgets('ignores duplicate semester picker taps while sheet is open', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: ScorePage(
            loadSemesters:
                () async => const SemesterListResult(
                  idList: ['2024-2025-1'],
                  nowId: '2024-2025-1',
                ),
            loadScore: (semesterId, {bool persistSummary = true}) async {
              return ScoreLoadResult(
                achievement: [
                  Score(
                    curriculumAttributes: '',
                    state: '通过',
                    examName: '期末',
                    courseNature: '必修',
                    fraction: '90',
                    courseName: '高等数学',
                    examinationNature: '考试',
                    gradePoints: '4.0',
                    credit: '4',
                  ),
                ],
                yxzxf: semesterId.isEmpty ? '40' : '10',
                zxfjd: semesterId.isEmpty ? '120' : '30',
                pjxfjd: semesterId.isEmpty ? '3.5' : '2.0',
              );
            },
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('全部学期').evaluate().isNotEmpty);

      final selector = find.text('全部学期').first;
      final selectorCenter = tester.getCenter(selector);
      await tester.tapAt(selectorCenter);
      await tester.tapAt(selectorCenter);
      await tester.pumpAndSettle();

      expect(find.text('选择学期'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('score detail sheet ignores duplicate taps while open', (
    tester,
  ) async {
    final sheetCompleter = Completer<void>();
    var sheetCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ScorePage(
          loadSemesters:
              () async => const SemesterListResult(
                idList: ['2024-2025-1'],
                nowId: '2024-2025-1',
              ),
          loadScore: (semesterId, {bool persistSummary = true}) async {
            return ScoreLoadResult(
              achievement: [
                Score(
                  curriculumAttributes: '',
                  state: '通过',
                  examName: '期末',
                  courseNature: '必修',
                  fraction: '90',
                  courseName: '高等数学',
                  examinationNature: '考试',
                  gradePoints: '4.0',
                  credit: '4',
                ),
              ],
              yxzxf: semesterId.isEmpty ? '40' : '10',
              zxfjd: semesterId.isEmpty ? '120' : '30',
              pjxfjd: semesterId.isEmpty ? '3.5' : '2.0',
            );
          },
          showBottomSheet: <T>({
            required BuildContext context,
            required WidgetBuilder builder,
            bool expand = false,
            Color? backgroundColor,
            Color? barrierColor,
            Color? transitionBackgroundColor,
            Radius? topRadius,
            BoxShadow? shadow,
          }) {
            sheetCalls++;
            return sheetCompleter.future.then<T?>((_) => null);
          },
        ),
      ),
    );

    await _pumpUntil(tester, () => find.text('高等数学').evaluate().isNotEmpty);

    final course = find.text('高等数学').first;
    await tester.tap(course);
    await tester.pump();
    await tester.tap(course);
    await tester.pump();

    expect(sheetCalls, 1);

    sheetCompleter.complete();
    await tester.pump();

    await tester.tap(course);
    await tester.pump();

    expect(sheetCalls, 2);
  });
}

ScoreLoadResult _scoreResult({required String courseName}) {
  return ScoreLoadResult(
    achievement: [
      Score(
        curriculumAttributes: '',
        state: '通过',
        examName: '期末',
        courseNature: '必修',
        fraction: '90',
        courseName: courseName,
        examinationNature: '考试',
        gradePoints: '4.0',
        credit: '4',
      ),
    ],
    yxzxf: '40',
    zxfjd: '120',
    pjxfjd: '3.5',
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() predicate, {
  Duration timeout = const Duration(milliseconds: 200),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!predicate()) {
    if (stopwatch.elapsed >= timeout) {
      fail('Timed out while waiting for condition.');
    }
    await tester.pump(const Duration(milliseconds: 10));
  }
}

class _ScoreCall {
  const _ScoreCall({required this.semesterId, required this.persistSummary});

  final String semesterId;
  final bool persistSummary;
}
