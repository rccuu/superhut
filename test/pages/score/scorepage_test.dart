import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/score/logic.dart';
import 'package:superhut/pages/score/scorepage.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('regular term semester filter keeps only upper/lower terms', () {
    expect(debugIsRegularTermSemester('2024-2025-1'), isTrue);
    expect(debugIsRegularTermSemester('2024-2025-2'), isTrue);
    expect(debugIsRegularTermSemester('2024-2025-3'), isFalse);
    expect(debugIsRegularTermSemester('2024-2025'), isFalse);
    expect(debugIsRegularTermSemester('abc'), isFalse);
    expect(debugIsRegularTermSemester(''), isFalse);
  });

  testWidgets(
    'probe keeps semester with data, drops empty, retains on retry-exhausted error',
    (tester) async {
      var failCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ScorePage(
            loadSemesters: () async =>
                const SemesterListResult(idList: [], nowId: ''),
            loadScore: (semesterId, {bool persistSummary = true}) {
              if (semesterId == '2024-2025-1') {
                // 始终抛异常：重试 2 次后仍失败 → 应保留
                failCount++;
                throw Exception('always fails');
              }
              if (semesterId == '2024-2025-2') {
                // 业务失败 (errorMessage)：应保留
                return Future.value(const ScoreLoadResult(
                  achievement: [],
                  yxzxf: '-',
                  zxfjd: '-',
                  pjxfjd: '-',
                  errorMessage: 'business error',
                ));
              }
              if (semesterId == '2024-2025-3') {
                // 成功但空：应剔除
                return Future.value(const ScoreLoadResult(
                  achievement: [],
                  yxzxf: '-',
                  zxfjd: '-',
                  pjxfjd: '-',
                ));
              }
              return Future.value(_scoreResult(courseName: '全部成绩'));
            },
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('全部成绩').evaluate().isNotEmpty);

      final dynamic pageState = tester.state(find.byType(ScorePage));
      // 2024-2025-1 抛异常，maxRetries=2 → 总共调用 3 次（1 初试 + 2 重试），最终保留
      final keepThrower =
          await (pageState.debugProbeSemesterKeep('2024-2025-1', maxRetries: 2)
              as Future<bool>);
      expect(keepThrower, isTrue);
      expect(failCount, 3);

      // 2024-2025-2 业务 errorMessage → 保留
      final keepBizError =
          await (pageState.debugProbeSemesterKeep('2024-2025-2', maxRetries: 0)
              as Future<bool>);
      expect(keepBizError, isTrue);

      // 2024-2025-3 成功但空 → 剔除
      final keepEmpty =
          await (pageState.debugProbeSemesterKeep('2024-2025-3', maxRetries: 0)
              as Future<bool>);
      expect(keepEmpty, isFalse);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'concurrent probe batches exceed 6 with pool size 6',
    (tester) async {
      // 8 个学期：全部成功且非空 → 全部保留；验证批次调度不重复、顺序保持
      final semesterIds = [
        '2024-2025-1', '2024-2025-2', '2025-2026-1', '2025-2026-2',
        '2026-2027-1', '2026-2027-2', '2023-2024-1', '2023-2024-2',
      ];
      final probed = <String>{};

      await tester.pumpWidget(
        MaterialApp(
          home: ScorePage(
            loadSemesters: () async =>
                SemesterListResult(idList: semesterIds, nowId: '2024-2025-2'),
            loadScore: (semesterId, {bool persistSummary = true}) {
              if (semesterId.isEmpty) {
                return Future.value(_scoreResult(courseName: '全部成绩'));
              }
              probed.add(semesterId);
              return Future.value(_scoreResult(courseName: semesterId));
            },
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('全部成绩').evaluate().isNotEmpty);

      final dynamic pageState = tester.state(find.byType(ScorePage));
      final kept = await (pageState.debugProbeRegularSemesters(semesterIds)
          as Future<List<String>>);

      // 全部非空 → 全部保留
      expect(kept, equals(semesterIds));
      // 每个学期恰好被探测一次（去重缓存保证不重复）
      expect(probed.length, semesterIds.length);
    },
  );

  testWidgets(
    'concurrent probe filters empty semesters while keeping order',
    (tester) async {
      final semesterIds = ['2024-2025-1', '2024-2025-2', '2025-2026-1'];

      await tester.pumpWidget(
        MaterialApp(
          home: ScorePage(
            loadSemesters: () async =>
                const SemesterListResult(idList: [], nowId: ''),
            loadScore: (semesterId, {bool persistSummary = true}) {
              if (semesterId.isEmpty) {
                return Future.value(_scoreResult(courseName: '全部成绩'));
              }
              // 中间那个返回空
              if (semesterId == '2024-2025-2') {
                return Future.value(const ScoreLoadResult(
                  achievement: [],
                  yxzxf: '-',
                  zxfjd: '-',
                  pjxfjd: '-',
                ));
              }
              return Future.value(_scoreResult(courseName: semesterId));
            },
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('全部成绩').evaluate().isNotEmpty);

      final dynamic pageState = tester.state(find.byType(ScorePage));
      final kept = await (pageState.debugProbeRegularSemesters(semesterIds)
          as Future<List<String>>);

      expect(kept, equals(['2024-2025-1', '2025-2026-1']));
    },
  );

  testWidgets(
    'probe pipeline filters non-regular terms and empty semesters',
    (tester) async {
      // 含 1 个非标准学期 (暑期 term=3) + 1 个空学期 + 2 个有数据
      final semesterIds = [
        '2024-2025-3', // 非标准 → 探测前剔除
        '2024-2025-1', // 有数据 → 保留
        '2024-2025-2', // 空 → 剔除
        '2025-2026-1', // 有数据 → 保留
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ScorePage(
            loadSemesters: () async =>
                SemesterListResult(idList: semesterIds, nowId: '2024-2025-1'),
            loadScore: (semesterId, {bool persistSummary = true}) {
              if (semesterId.isEmpty) {
                return Future.value(_scoreResult(courseName: '全部成绩'));
              }
              if (semesterId == '2024-2025-2') {
                return Future.value(const ScoreLoadResult(
                  achievement: [],
                  yxzxf: '-',
                  zxfjd: '-',
                  pjxfjd: '-',
                ));
              }
              return Future.value(_scoreResult(courseName: semesterId));
            },
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('全部成绩').evaluate().isNotEmpty);

      final dynamic pageState = tester.state(find.byType(ScorePage));
      final kept = await (pageState.debugProbeAvailableSemesters(semesterIds)
          as Future<List<String>>);

      // 非标准剔除、空剔除，仅保留有数据的两个
      expect(kept, equals(['2024-2025-1', '2025-2026-1']));
    },
  );

  testWidgets(
    'probe pipeline retains semester whose probe throws after retries',
    (tester) async {
      final semesterIds = ['2024-2025-1', '2024-2025-2'];
      var throwCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ScorePage(
            // 生产路径仅装载空学期列表，避免后台探测重复计入 throwCount；
            // debug 入口独立验证重试+保留语义。
            loadSemesters: () async =>
                const SemesterListResult(idList: [], nowId: ''),
            loadScore: (semesterId, {bool persistSummary = true}) {
              if (semesterId.isEmpty) {
                return Future.value(_scoreResult(courseName: '全部成绩'));
              }
              if (semesterId == '2024-2025-1') {
                throwCount++;
                throw Exception('always throws');
              }
              return Future.value(_scoreResult(courseName: semesterId));
            },
          ),
        ),
      );

      await _pumpUntil(tester, () => find.text('全部成绩').evaluate().isNotEmpty);

      final dynamic pageState = tester.state(find.byType(ScorePage));
      final kept = await (pageState.debugProbeAvailableSemesters(semesterIds)
          as Future<List<String>>);

      // 报错学期保留 + 重试累计 3 次
      expect(kept, equals(semesterIds));
      expect(throwCount, 3);
      expect(tester.takeException(), isNull);
    },
  );

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

    // 并发管线会在挂载期间同时派发两个学期的探测；记录卸载前已派发的次数。
    final secondProbedBeforeUnmount = scoreCalls
        .where((call) => call.semesterId == '2024-2025-2')
        .length;

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('replacement'))),
    );
    firstProbeCompleter.complete(_scoreResult(courseName: '旧探测成绩'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('replacement'), findsOneWidget);
    // 卸载后不应再额外派发 2024-2025-2 的探测；UI 也不会写回。
    expect(
      scoreCalls.where((call) => call.semesterId == '2024-2025-2').length,
      secondProbedBeforeUnmount,
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

  testWidgets('restores from cache and shows cached summary immediately', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'user': '2021001',
      'score_cache_2021001_semesters': ['2024-2025-1', '2024-2025-2'],
      'score_cache_2021001_selectedId': '2024-2025-1',
      'score_cache_2021001_nowId': '2024-2025-2',
      'score_cache_2021001_zxf': '40',
      'score_cache_2021001_zxfjd': '120',
      'score_cache_2021001_pjjd': '3.5',
      'score_cache_2021001_courseCount': 12,
    });

    var semesterLoadCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ScorePage(
          loadSemesters: () async {
            semesterLoadCalled = true;
            return const SemesterListResult(
              idList: ['2024-2025-1', '2024-2025-2'],
              nowId: '2024-2025-2',
            );
          },
          loadScore: (semesterId, {bool persistSummary = true}) async {
            return _scoreResult(courseName: '网络成绩');
          },
        ),
      ),
    );

    // 缓存恢复后应立即显示摘要，无需等待网络
    await tester.pump();
    expect(find.text('40'), findsOneWidget); // zxf
    expect(find.text('3.5'), findsOneWidget); // pjjd
    expect(find.text('2024-2025 上'), findsOneWidget); // selectedId label

    // 后台刷新应被触发
    await _pumpUntil(tester, () => semesterLoadCalled);
    expect(semesterLoadCalled, isTrue);
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
