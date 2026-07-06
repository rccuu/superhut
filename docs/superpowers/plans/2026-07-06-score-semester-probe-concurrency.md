# 成绩学期探测并发加速 + 学期类型过滤 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把成绩查询页的"自动隐藏空学期"探测从串行改为自适应并发，并在探测前过滤掉非"上/下学期"格式的学期；单学期探测失败时后台静默重试最多 2 次，仍失败则保留该学期（避免误隐藏）。

**Architecture:** 改造集中在 `lib/pages/score/scorepage.dart` 的 `_ScorePageState`：删除串行的 `_filterSemestersWithScores`，新增 `_isRegularTermSemester`（学期类型过滤）、`_probeSemesterKeep`（单学期探测+重试，返回是否保留）、`_probeRegularSemesters`（自适应并发调度）。复用现有 `_loadScoreForSemester` 去重缓存与 `mounted`/`_selectionRefreshGeneration` 生命周期保护。不改 `logic.dart` 数据层。Dart event loop 上的并发 Future 已是 I/O bound 任务的正确并发模型，不引入 isolate。

**Tech Stack:** Flutter / Dart，`Future.wait` 并发，`flutter_test` widget 测试，`@visibleForTesting` 测试入口（沿用 `debugRefreshScoresForSelection` 模式）。

## Global Constraints

- 文件命名 `snake_case.dart`，类 `PascalCase`，成员 `camelCase`（项目约定，CLAUDE.md）。
- Conventional Commits with scopes，本计划用 `feat(score):` / `test(score):` / `refactor(score):`。
- 改动前必须确认在 `main` 分支且工作区干净：`git status` 应为 clean。
- 验证命令：`flutter analyze`（必须无新增 error）、`flutter test test/pages/score/scorepage_test.dart`（本计划所有测试）、`flutter test`（全量回归）。
- 不改 `lib/pages/score/logic.dart`（数据层与 UI 过滤语义分离，spec 明确）。
- 不引入 isolate / `compute`（I/O 限流场景无收益，spec 明确）。
- 现有测试 `test/pages/score/scorepage_test.dart` 中"background semester probing errors keep current score and semester list"（约 119-171 行）断言的行为在新设计下仍成立（报错学期保留），必须保持绿色。

## File Structure

- **Modify**: `lib/pages/score/scorepage.dart`
  - 顶部新增 `import 'dart:math' show min;`
  - `_ScorePageState` 内新增方法：`_isRegularTermSemester`、`_probeSemesterKeep`、`_probeRegularSemesters`、`_probeKeepAll`
  - `_ScorePageState` 内删除方法：`_filterSemestersWithScores`
  - 改造 `_probeAvailableSemesters`：调用 `_probeRegularSemesters`，移除原整体回退语义
  - 新增 `@visibleForTesting` 方法 `debugProbeAvailableSemesters`
- **Modify**: `test/pages/score/scorepage_test.dart`
  - 新增测试：学期类型过滤、单学期重试保留、并发分批、报错学期保留
  - 调整既有"probing errors"测试以反映重试次数（如需）

每个任务的改动都自包含，可独立测试、独立提交。

---

### Task 1: 学期类型过滤方法 `_isRegularTermSemester` (TDD)

**Files:**
- Modify: `lib/pages/score/scorepage.dart`（新增私有方法 + `@visibleForTesting` 包装）
- Test: `test/pages/score/scorepage_test.dart`

**Interfaces:**
- Consumes: `_parseSemesterLabelParts`（scorepage.dart:400-427，已存在）
- Produces: `bool _isRegularTermSemester(String id)` 与 `@visibleForTesting bool debugIsRegularTermSemester(String id)` —— 后续任务（Task 4 整合）内部使用前者；测试使用后者。

- [ ] **Step 1: Write the failing test**

在 `test/pages/score/scorepage_test.dart` 的 `main()` 顶部（第一个 `testWidgets` 之前）新增：

```dart
  test('regular term semester filter keeps only upper/lower terms', () {
    final dynamic pageState = _ScorePageStateStub();
    expect(pageState.debugIsRegularTermSemester('2024-2025-1'), isTrue);
    expect(pageState.debugIsRegularTermSemester('2024-2025-2'), isTrue);
    expect(pageState.debugIsRegularTermSemester('2024-2025-3'), isFalse);
    expect(pageState.debugIsRegularTermSemester('2024-2025'), isFalse);
    expect(pageState.debugIsRegularTermSemester('abc'), isFalse);
    expect(pageState.debugIsRegularTermSemester(''), isFalse);
  });
```

由于 `_ScorePageState` 的实例化依赖 Widget 生命周期，且 `@visibleForTesting` 方法不应要求挂载，本任务的实现会把 `_isRegularTermSemester` 与其 `debug*` 包装写成**不依赖实例状态**的纯函数形式（`debugIsRegularTermSemester` 直接转调静态实现的 `_isRegularTermSemester`）。因此测试里用 `_ScorePageStateStub` 直接构造一个空实例不可行（State 的构造受保护），改为通过一个**只公开纯函数**的顶层测试入口。

修订测试（替换上面那段，使用顶层函数入口）：

```dart
  test('regular term semester filter keeps only upper/lower terms', () {
    expect(debugIsRegularTermSemester('2024-2025-1'), isTrue);
    expect(debugIsRegularTermSemester('2024-2025-2'), isTrue);
    expect(debugIsRegularTermSemester('2024-2025-3'), isFalse);
    expect(debugIsRegularTermSemester('2024-2025'), isFalse);
    expect(debugIsRegularTermSemester('abc'), isFalse);
    expect(debugIsRegularTermSemester(''), isFalse);
  });
```

对应实现为一个 `@visibleForTesting` 顶层函数（见 Step 3）。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pages/score/scorepage_test.dart --plain-name "regular term semester filter"`
Expected: FAIL with `debugIsRegularTermSemester` 未定义（Getter not found / method not declared）。

- [ ] **Step 3: Write minimal implementation**

在 `lib/pages/score/scorepage.dart`，于 `typedef ScoreBottomSheetPresenter = ...`（约 29 行）之后、`class ScorePage` 之前，新增：

```dart
@visibleForTesting
bool debugIsRegularTermSemester(String id) {
  final parts = _parseSemesterLabelPartsStatic(id);
  if (parts == null) return false;
  return parts.term == '1' || parts.term == '2';
}
```

由于现有 `_parseSemesterLabelParts` 是 `_ScorePageState` 的实例方法（scorepage.dart:400），纯函数入口需要无实例地解析。最小且不破坏现有调用的做法：把解析逻辑抽成顶层静态函数 `_parseSemesterLabelPartsStatic`，让 `_ScorePageState._parseSemesterLabelParts` 转调它（保持现有 UI 调用不变），新顶层函数也复用它。

具体改动：

(a) 在 `typedef ScoreBottomSheetPresenter` 之后新增静态解析函数（从原 scorepage.dart:400-427 的逻辑原样提取为顶层函数）：

```dart
({String startYear, String endYear, String term})?
_parseSemesterLabelPartsStatic(String value) {
  var firstDash = -1;
  var secondDash = -1;
  for (var index = 0; index < value.length; index++) {
    if (value.codeUnitAt(index) != 0x2D) {
      continue;
    }
    if (firstDash == -1) {
      firstDash = index;
    } else if (secondDash == -1) {
      secondDash = index;
    } else {
      return null;
    }
  }

  if (firstDash == -1 || secondDash == -1) {
    return null;
  }

  return (
    startYear: value.substring(0, firstDash),
    endYear: value.substring(firstDash + 1, secondDash),
    term: value.substring(secondDash + 1),
  );
}
```

(b) 把原 `_ScorePageState._parseSemesterLabelParts`（scorepage.dart:400-427）整个方法体替换为转调：

```dart
  ({String startYear, String endYear, String term})? _parseSemesterLabelParts(
    String value,
  ) => _parseSemesterLabelPartsStatic(value);
```

(c) 紧接 `_parseSemesterLabelPartsStatic` 之后加 Step 3 开头那个 `debugIsRegularTermSemester` 顶层函数。

确认 `package:flutter/foundation.dart` 已导入（`@visibleForTesting` 来源）——scorepage.dart:4 已有 `import 'package:flutter/foundation.dart';`，无需新增。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pages/score/scorepage_test.dart --plain-name "regular term semester filter"`
Expected: PASS。

- [ ] **Step 5: Run analyze + full score test file**

Run: `flutter analyze lib/pages/score/scorepage.dart test/pages/score/scorepage_test.dart`
Expected: 无新增 issue。

Run: `flutter test test/pages/score/scorepage_test.dart`
Expected: 全部既有 + 新增测试 PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/pages/score/scorepage.dart test/pages/score/scorepage_test.dart
git commit -m "feat(score): add regular-term semester filter helper"
```

---

### Task 2: 单学期探测 + 重试 `_probeSemesterKeep` (TDD)

**Files:**
- Modify: `lib/pages/score/scorepage.dart`（新增私有方法 + `@visibleForTesting` 包装）
- Test: `test/pages/score/scorepage_test.dart`

**Interfaces:**
- Consumes: `_loadScoreForSemester(String, {bool persistSummary})`（scorepage.dart:188，已存在，含去重缓存）；`AppLogger`（已导入）
- Produces: `Future<bool> _probeSemesterKeep(String id, {int maxRetries})` 与 `@visibleForTesting Future<bool> debugProbeSemesterKeep(String id, {int maxRetries = 2})`

返回契约：
- 成功且 `achievement` 非空 → `true`（保留）
- 成功但 `achievement` 为空 → `false`（剔除）
- 抛异常或 `errorMessage != null`，重试 `maxRetries` 次后仍失败 → `true`（保留，避免误隐藏）
- 探测期间页面 unmount → `true`（保留，外层会再判 mounted）

- [ ] **Step 1: Write the failing test**

在 `test/pages/score/scorepage_test.dart` 新增（紧跟 Task 1 的 test 之后）：

```dart
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
              return Future.value(_scoreResult(courseName: 'X'));
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
```

注：`'全部成绩'` 来自首屏 `loadScore('')` 返回的 `_scoreResult(courseName: '全部成绩')`（即上面 default 分支），与既有测试一致。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pages/score/scorepage_test.dart --plain-name "probe keeps semester"`
Expected: FAIL with `debugProbeSemesterKeep` 未定义。

- [ ] **Step 3: Write minimal implementation**

在 `lib/pages/score/scorepage.dart` 的 `_ScorePageState` 内，于 `_loadAndCacheScoreForSemester`（约 220 行）之后、`debugLoadScoreForSemester`（约 234 行）之前新增：

```dart
  Future<bool> _probeSemesterKeep(String id, {int maxRetries = 2}) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (!mounted) return true;
      ScoreLoadResult? result;
      try {
        result = await _loadScoreForSemester(id, persistSummary: false);
      } catch (error, stackTrace) {
        AppLogger.error(
          'Failed to probe score data for semester $id (attempt $attempt)',
          error: error,
          stackTrace: stackTrace,
        );
        if (attempt == maxRetries) return true; // 重试耗尽 → 保留
        continue; // 否则重试
      }
      if (!mounted) return true;
      if (result.errorMessage != null) return true; // 业务失败 → 保留
      return result.achievement.isNotEmpty; // 成功：非空保留，空剔除
    }
    // 不可达：循环必在任一分支返回
    return true;
  }
```

注意：上面循环体内 `try` 成功时走 `if (result.errorMessage...)` 早返回，与循环外 `for` 顶端 `attempt <= maxRetries` 配合 —— `continue` 仅在 catch 分支且 `attempt < maxRetries` 时触发，逻辑正确。但 `result` 在 catch 分支后为 `null`，需保证不越过 catch 后再访问。第 1 次迭代 catch 时 `continue` 跳回 for 顶端，下一次迭代重新进 try，`result` 重新赋值，无 null 访问问题。循环末尾 `return true` 兜底永不执行（编译器仍要求返回）。

在 `debugRefreshScoresForSelection`（约 243 行）附近新增 `@visibleForTesting` 包装：

```dart
  @visibleForTesting
  Future<bool> debugProbeSemesterKeep(String id, {int maxRetries = 2}) {
    return _probeSemesterKeep(id, maxRetries: maxRetries);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pages/score/scorepage_test.dart --plain-name "probe keeps semester"`
Expected: PASS。

- [ ] **Step 5: Run analyze + full score test file**

Run: `flutter analyze lib/pages/score/scorepage.dart`
Expected: 无新增 issue。

Run: `flutter test test/pages/score/scorepage_test.dart`
Expected: 全 PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/pages/score/scorepage.dart test/pages/score/scorepage_test.dart
git commit -m "feat(score): add retry-aware single-semester probe"
```

---

### Task 3: 自适应并发探测 `_probeRegularSemesters` (TDD)

**Files:**
- Modify: `lib/pages/score/scorepage.dart`（顶部新增 `dart:math` 导入；新增 `_probeRegularSemesters` + `_probeKeepAll` + `@visibleForTesting` 包装）
- Test: `test/pages/score/scorepage_test.dart`

**Interfaces:**
- Consumes: `debugIsRegularTermSemester`（Task 1）、`_probeSemesterKeep`（Task 2）、`mounted`
- Produces: `Future<List<String>> _probeRegularSemesters(List<String> ids)` —— 返回**应保留**的学期，按入参顺序；`@visibleForTesting Future<List<String>> debugProbeRegularSemesters(List<String> ids)`

并发策略：`ids.length <= 6` 时全量 `Future.wait`；超过 6 时分批，每批 `poolSize = 6` 个并发，批与批之间顺序 `await`（每批开始前判 mounted）。

- [ ] **Step 1: Write the failing test**

在测试文件新增（紧跟 Task 2 test 之后）：

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pages/score/scorepage_test.dart --plain-name "concurrent probe"`
Expected: FAIL with `debugProbeRegularSemesters` 未定义。

- [ ] **Step 3: Write minimal implementation**

(a) 在 `lib/pages/score/scorepage.dart` 顶部 import 区，于 `import 'dart:async';`（第 1 行）之后新增：

```dart
import 'dart:math' show min;
```

(b) 在 `_ScorePageState` 内，紧接 `_probeSemesterKeep`（Task 2 新增）之后新增：

```dart
  Future<List<String>> _probeRegularSemesters(List<String> ids) async {
    if (ids.isEmpty) return const <String>[];
    const int fullConcurrencyThreshold = 6;
    const int poolSize = 6;

    if (ids.length <= fullConcurrencyThreshold) {
      return _probeKeepAll(ids);
    }

    final kept = <String>[];
    for (var i = 0; i < ids.length; i += poolSize) {
      if (!mounted) return kept;
      final batch = ids.sublist(i, min(i + poolSize, ids.length));
      kept.addAll(await _probeKeepAll(batch));
    }
    return kept;
  }

  Future<List<String>> _probeKeepAll(List<String> ids) async {
    final results = await Future.wait(
      ids.map((id) => _probeSemesterKeep(id)),
    );
    return [
      for (var i = 0; i < ids.length; i++)
        if (results[i]) ids[i],
    ];
  }
```

(c) 紧接 `debugProbeSemesterKeep`（Task 2 新增）之后新增 `@visibleForTesting` 包装：

```dart
  @visibleForTesting
  Future<List<String>> debugProbeRegularSemesters(List<String> ids) {
    return _probeRegularSemesters(ids);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pages/score/scorepage_test.dart --plain-name "concurrent probe"`
Expected: 两个新测试均 PASS。

- [ ] **Step 5: Run analyze + full score test file**

Run: `flutter analyze lib/pages/score/scorepage.dart`
Expected: 无新增 issue。

Run: `flutter test test/pages/score/scorepage_test.dart`
Expected: 全 PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/pages/score/scorepage.dart test/pages/score/scorepage_test.dart
git commit -m "feat(score): add adaptive concurrent semester probe"
```

---

### Task 4: 整合到 `_probeAvailableSemesters` + 删除串行旧逻辑 (TDD + 改造)

**Files:**
- Modify: `lib/pages/score/scorepage.dart`
  - 删除 `_filterSemestersWithScores`（scorepage.dart:247-285）
  - 改造 `_probeAvailableSemesters`（scorepage.dart:287-331）
  - 新增 `@visibleForTesting debugProbeAvailableSemesters`
- Test: `test/pages/score/scorepage_test.dart`

**Interfaces:**
- Consumes: `_isRegularTermSemester`（通过 Task 1 的静态解析）、`_probeRegularSemesters`（Task 3）、`selectedId`、`semesterId`、`_scoreCache`、`_loadScoreForSemester`
- Produces: 改造后的 `_probeAvailableSemesters` 行为；`debugProbeAvailableSemesters` 供测试直接调用（绕过 `_isSemesterProbeStarted` 一次性锁，便于重复调用与竞态测试）

**关键行为变化**：
- 旧 `_filterSemestersWithScores` 中"任一失败即 `return semesterIds`（保留全部）"整体回退**删除**。
- 非标准格式学期一律从结果剔除（spec 第 4 节）。
- 报错学期由 `_probeSemesterKeep` 保留。
- 结果 `filteredSemesterIds = keptIds`（依赖 `.where` 保序 + `Future.wait` 保序）。

- [ ] **Step 1: Write the failing test**

在测试文件新增（紧跟 Task 3 test 之后）：

```dart
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
            loadSemesters: () async =>
                SemesterListResult(idList: semesterIds, nowId: '2024-2025-2'),
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/pages/score/scorepage_test.dart --plain-name "probe pipeline"`
Expected: FAIL with `debugProbeAvailableSemesters` 未定义（旧实现 `_probeAvailableSemesters` 是 private 且有 `_isSemesterProbeStarted` 一次性锁，无法直接测）。

- [ ] **Step 3: Write minimal implementation**

(a) **删除** 原 `_filterSemestersWithScores`（scorepage.dart:247-285 整段）。

(b) **替换** 原 `_probeAvailableSemesters`（scorepage.dart:287-331）为：

```dart
  Future<void> _probeAvailableSemesters(List<String> semesterIds) async {
    if (_isSemesterProbeStarted) {
      return;
    }
    _isSemesterProbeStarted = true;

    final regularIds =
        semesterIds.where(_isRegularTermSemesterStatic).toList();
    final keptIds = await _probeRegularSemesters(regularIds);
    if (!mounted) {
      return;
    }

    final filteredSemesterIds = keptIds;

    final shouldResetSelection =
        selectedId != 'all' && !filteredSemesterIds.contains(selectedId);
    if (!shouldResetSelection && listEquals(semesterId, filteredSemesterIds)) {
      return;
    }

    final cachedAllScoreData = shouldResetSelection ? _scoreCache['all'] : null;
    if (cachedAllScoreData != null) {
      semesterId = filteredSemesterIds;
      _assignScoreData(cachedAllScoreData, semesterId: 'all');
      _syncScoreContentState();
      _syncSelectionState();
      return;
    }

    semesterId = filteredSemesterIds;
    if (shouldResetSelection) {
      selectedId = 'all';
      _syncScoreContentState();
      _syncSelectionState();
    }

    if (!shouldResetSelection) {
      return;
    }

    final allScoreData = await _loadScoreForSemester('all');
    if (!mounted || selectedId != 'all') {
      return;
    }
    _setScoreData(allScoreData, semesterId: 'all');
  }
```

其中 `_isRegularTermSemesterStatic` 是 ServerState 内对 Task 1 顶层解析的薄封装。由于 Task 1 已经提供顶层 `debugIsRegularTermSemester` 与 `_parseSemesterLabelPartsStatic`，但 Server 内部不应用 `@visibleForTesting` 入口。补一个 internal 静态方法：

(c) 在 `_ScorePageState` 内新增（紧邻 `_probeSemesterKeep`）：

```dart
  bool _isRegularTermSemesterStatic(String id) {
    final parts = _parseSemesterLabelPartsStatic(id);
    if (parts == null) return false;
    return parts.term == '1' || parts.term == '2';
  }
```

注意：这与 Task 1 的顶层 `debugIsRegularTermSemester` 重复了判定逻辑，但二者用途不同（一个是纯测试入口、一个是实例内静态封装）。为 DRY，让顶层 `debugIsRegularTermSemester` 也调用 `_isRegularTermSemesterStatic` 不可行（后者在 State 内）。可接受方案：把判定逻辑只放顶层 `debugIsRegularTermSemester`，Server 内部 `_isRegularTermSemesterStatic` 转调顶层函数。调整 (c) 为：

```dart
  bool _isRegularTermSemesterStatic(String id) => debugIsRegularTermSemester(id);
```

这样判定逻辑唯一定义在顶层 `debugIsRegularTermSemester`。

(d) **新增** `@visibleForTesting` 包装（紧邻 `debugProbeRegularSemesters`）：

```dart
  @visibleForTesting
  Future<List<String>> debugProbeAvailableSemesters(List<String> ids) async {
    // 复用与 _probeAvailableSemesters 相同的纯过滤+探测管线，
    // 但不写回 semesterId / 不触发 UI 同步，不持有 _isSemesterProbeStarted 锁，
    // 便于测试直接断言探测结果。
    if (ids.isEmpty) return const <String>[];
    final regularIds = ids.where(_isRegularTermSemesterStatic).toList();
    return _probeRegularSemesters(regularIds);
  }
```

注：`debugProbeAvailableSemesters` 故意不触发 UI 写回，仅返回探测结果；写回 UI 的整段逻辑只由真实 `_probeAvailableSemesters`（生产路径，受 `_isSemesterProbeStarted` 锁保护）在 `getTimeList()` 中触发。测试用 `debug*` 入口断言纯探测结果，生产用 `_probeAvailableSemesters`。

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/pages/score/scorepage_test.dart --plain-name "probe pipeline"`
Expected: 两个新测试均 PASS。

- [ ] **Step 5: Run full score suite（含既有 probing errors 测试）**

Run: `flutter test test/pages/score/scorepage_test.dart`
Expected: 全 PASS。**特别确认** "background semester probing errors keep current score and semester list"（约 119-171 行）仍 PASS —— 该测试通过真实生产路径（`ScorePage` 挂载 → `getTimeList` → `_probeAvailableSemesters`），`2024-2025-1` 抛异常经重试后保留，`2024-2025-2` 返回有数据也保留，故学期选择器仍显示 `2024-2025 · 上学期` 与 `2024-2025 · 下学期`，断言成立。

- [ ] **Step 6: Run analyze**

Run: `flutter analyze lib/pages/score/scorepage.dart test/pages/score/scorepage_test.dart`
Expected: 无新增 issue。`_filterSemestersWithScores` 删除后应无 dangling 引用。

- [ ] **Step 7: Commit**

```bash
git add lib/pages/score/scorepage.dart test/pages/score/scorepage_test.dart
git commit -m "refactor(score): wire concurrent probe into semester pipeline"
```

---

### Task 5: 全量回归验证 + 收尾

**Files:**
- 无代码改动；仅验证。

- [ ] **Step 1: Run flutter analyze over whole project**

Run: `flutter analyze`
Expected: 与改动前基线一致，无新增 error/warning（已忽略的既有告警若存则在改动前即存在，不引入新的）。

- [ ] **Step 2: Run full test suite**

Run: `flutter test`
Expected: 全 PASS。重点关注：
- `test/pages/score/scorepage_test.dart` 所有测试（含本计划新增 4 组）
- `test/widget_test.dart`（首页 tab 导航、deep-link 不受影响）

- [ ] **Step 3: 验证 git 工作区状态**

Run: `git status`
Expected: clean。`git log --oneline -6` 应显示 4 个本计划的提交（Task 1-4 各一）。

- [ ] **Step 4: 记录交付**

向用户汇报：
- 改动文件清单、提交 hash
- 旧串行探测 → 新并发探测的预期效果（学期数 N 的串行总耗时 ≈ N × 单次往返，降为 ceil(N/6) × 单次往返；学期数 6-10 时基本一次 `Future.wait` 收敛）
- 学期类型过滤：非上/下学期不再进入探测，进一步减少请求
- 报错学期保留策略的实测验证点（对应测试名）

---

## Self-Review

**1. Spec coverage:**
- 探测前过滤（spec §1）→ Task 1 (`debugIsRegularTermSemester` / `_parseSemesterLabelPartsStatic`) + Task 4 整合调用。✓
- 单学期重试（spec §2）→ Task 2 (`_probeSemesterKeep`，maxRetries=2)。✓
- 自适应并发（spec §3）→ Task 3 (`_probeRegularSemesters` + `_probeKeepAll`，阈值 6 / 池 6)。✓
- 整合 `_probeAvailableSemesters` + 删除整体回退（spec §4）→ Task 4。✓
- 生命周期 mounted / 去重缓存复用（spec §5）→ 复用现有 `_loadScoreForSemester` 去重；`_probeSemesterKeep` 与 `_probeRegularSemesters` 各 await 点判 mounted。✓
- 测试（spec §6）→ 五个新增用例覆盖：全非空保留、混合保留、>6 分批、报错重试保留、空剔除、非标准剔除、heads：probe pipeline 两个、concurrent probe 两个、probe keeps 一个、regular filter 一个。✓

**2. Placeholder scan:** 无 TBD/TODO；每步代码完整；测试含具体 mock 与断言。✓

**3. Type consistency:**
- `_probeSemesterKeep(String, {int maxRetries = 2}) -> Future<bool>` 在 Task 2 定义、Task 3 `_probeKeepAll` 调用，签名一致。✓
- `_probeRegularSemesters(List<String>) -> Future<List<String>>` 在 Task 3 定义、Task 4 调用。✓
- `debugProbeSemesterKeep` / `debugProbeRegularSemesters` / `debugProbeAvailableSemesters` 三个 `@visibleForTesting` 命名一致、测试调用一致。✓
- `_isRegularTermSemesterStatic` 在 Task 4(c) 定义并被 Task 4(b) `_probeAvailableSemesters` 与 Task 4(d) `debugProbeAvailableSemesters` 调用。✓
- `_parseSemesterLabelPartsStatic` 在 Task 1 引入，`_parseSemesterLabelParts` 转调以保持现有 UI 调用（`_formatSemesterLabel` / `_compactSemesterLabel`）不变。✓

无悬挂引用。
