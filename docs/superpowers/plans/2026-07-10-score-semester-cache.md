# Score Semester Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cache the score page's filtered semester list and summary metrics so subsequent opens render instantly from local state, with a silent background refresh.

**Architecture:** A new `ScoreSemesterCache` singleton manages read/write/clear against SharedPreferences with per-user key isolation. `ScorePage._ScorePageState.getTimeList()` is split into a cache-first fast path + a background refresh path. `AppAuthStorage.clearAllAuthData()` is extended to clear the cache on logout.

**Tech Stack:** Dart/Flutter, SharedPreferences, existing `AppLogger`

## Global Constraints

- SharedPreferences keys prefixed `score_cache_` — never collide with existing keys
- userId source: `AppAuthStorage.instance.readJwxtUsername()`
- No time-based expiration — background refresh handles staleness
- Cache cleared on logout via `AppAuthStorage.clearAllAuthData()`

---

### Task 1: ScoreSemesterCache service

**Files:**
- Create: `lib/core/services/score_semester_cache.dart`
- Test: `test/core/services/score_semester_cache_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences`, `AppLogger`
- Produces:
  - `ScoreSemesterCacheData` — data class with fields: `List<String> semesterIds`, `String selectedId`, `String nowSemesterId`, `String zxf`, `String zxfjd`, `String pjjd`, `int courseCount`
  - `ScoreSemesterCache.instance` — singleton with methods: `Future<ScoreSemesterCacheData?> read(String userId)`, `Future<void> write(String userId, ScoreSemesterCacheData data)`, `Future<void> clear(String userId)`, `Future<void> clearAll()`

- [ ] **Step 1: Write failing tests for `ScoreSemesterCache`**

Create `test/core/services/score_semester_cache_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/core/services/score_semester_cache.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('read returns null when no cache exists', () async {
    final result = await ScoreSemesterCache.instance.read('2021001');
    expect(result, isNull);
  });

  test('read returns null when userId is empty', () async {
    final result = await ScoreSemesterCache.instance.read('');
    expect(result, isNull);
  });

  test('write then read returns same data', () async {
    const data = ScoreSemesterCacheData(
      semesterIds: ['2024-2025-1', '2024-2025-2'],
      selectedId: '2024-2025-1',
      nowSemesterId: '2024-2025-2',
      zxf: '40',
      zxfjd: '120',
      pjjd: '3.5',
      courseCount: 12,
    );

    await ScoreSemesterCache.instance.write('2021001', data);
    final result = await ScoreSemesterCache.instance.read('2021001');

    expect(result, isNotNull);
    expect(result!.semesterIds, ['2024-2025-1', '2024-2025-2']);
    expect(result.selectedId, '2024-2025-1');
    expect(result.nowSemesterId, '2024-2025-2');
    expect(result.zxf, '40');
    expect(result.zxfjd, '120');
    expect(result.pjjd, '3.5');
    expect(result.courseCount, 12);
  });

  test('different userId isolation', () async {
    const data = ScoreSemesterCacheData(
      semesterIds: ['2024-2025-1'],
      selectedId: 'all',
      nowSemesterId: '2024-2025-1',
      zxf: '10',
      zxfjd: '30',
      pjjd: '3.0',
      courseCount: 3,
    );

    await ScoreSemesterCache.instance.write('2021001', data);
    final other = await ScoreSemesterCache.instance.read('2021002');
    expect(other, isNull);
  });

  test('clear removes specific user cache', () async {
    const data = ScoreSemesterCacheData(
      semesterIds: ['2024-2025-1'],
      selectedId: 'all',
      nowSemesterId: '2024-2025-1',
      zxf: '10',
      zxfjd: '30',
      pjjd: '3.0',
      courseCount: 3,
    );

    await ScoreSemesterCache.instance.write('2021001', data);
    await ScoreSemesterCache.instance.write('2021002', data);
    await ScoreSemesterCache.instance.clear('2021001');

    expect(await ScoreSemesterCache.instance.read('2021001'), isNull);
    expect(await ScoreSemesterCache.instance.read('2021002'), isNotNull);
  });

  test('clearAll removes all user caches', () async {
    const data = ScoreSemesterCacheData(
      semesterIds: ['2024-2025-1'],
      selectedId: 'all',
      nowSemesterId: '2024-2025-1',
      zxf: '10',
      zxfjd: '30',
      pjjd: '3.0',
      courseCount: 3,
    );

    await ScoreSemesterCache.instance.write('2021001', data);
    await ScoreSemesterCache.instance.write('2021002', data);
    await ScoreSemesterCache.instance.clearAll();

    expect(await ScoreSemesterCache.instance.read('2021001'), isNull);
    expect(await ScoreSemesterCache.instance.read('2021002'), isNull);
  });

  test('read returns null when semesterIds is empty (corrupted)', () async {
    SharedPreferences.setMockInitialValues({
      'score_cache_2021001_semesters': <String>[],
      'score_cache_2021001_selectedId': 'all',
      'score_cache_2021001_nowId': '',
      'score_cache_2021001_zxf': '10',
      'score_cache_2021001_zxfjd': '30',
      'score_cache_2021001_pjjd': '3.0',
      'score_cache_2021001_courseCount': 0,
    });

    final result = await ScoreSemesterCache.instance.read('2021001');
    expect(result, isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/score_semester_cache_test.dart`
Expected: Compilation error — `score_semester_cache.dart` does not exist.

- [ ] **Step 3: Implement `ScoreSemesterCache`**

Create `lib/core/services/score_semester_cache.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

class ScoreSemesterCacheData {
  const ScoreSemesterCacheData({
    required this.semesterIds,
    required this.selectedId,
    required this.nowSemesterId,
    required this.zxf,
    required this.zxfjd,
    required this.pjjd,
    required this.courseCount,
  });

  final List<String> semesterIds;
  final String selectedId;
  final String nowSemesterId;
  final String zxf;
  final String zxfjd;
  final String pjjd;
  final int courseCount;
}

class ScoreSemesterCache {
  ScoreSemesterCache._();

  static final ScoreSemesterCache instance = ScoreSemesterCache._();

  static const _prefix = 'score_cache_';

  String _key(String userId, String field) => '$_prefix${userId}_$field';

  Future<ScoreSemesterCacheData?> read(String userId) async {
    if (userId.isEmpty) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final semesterIds = prefs.getStringList(_key(userId, 'semesters'));
      if (semesterIds == null || semesterIds.isEmpty) return null;

      return ScoreSemesterCacheData(
        semesterIds: semesterIds,
        selectedId: prefs.getString(_key(userId, 'selectedId')) ?? 'all',
        nowSemesterId: prefs.getString(_key(userId, 'nowId')) ?? '',
        zxf: prefs.getString(_key(userId, 'zxf')) ?? '-',
        zxfjd: prefs.getString(_key(userId, 'zxfjd')) ?? '-',
        pjjd: prefs.getString(_key(userId, 'pjjd')) ?? '-',
        courseCount: prefs.getInt(_key(userId, 'courseCount')) ?? 0,
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to read score semester cache',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> write(String userId, ScoreSemesterCacheData data) async {
    if (userId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key(userId, 'semesters'), data.semesterIds);
      await prefs.setString(_key(userId, 'selectedId'), data.selectedId);
      await prefs.setString(_key(userId, 'nowId'), data.nowSemesterId);
      await prefs.setString(_key(userId, 'zxf'), data.zxf);
      await prefs.setString(_key(userId, 'zxfjd'), data.zxfjd);
      await prefs.setString(_key(userId, 'pjjd'), data.pjjd);
      await prefs.setInt(_key(userId, 'courseCount'), data.courseCount);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to write score semester cache',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> clear(String userId) async {
    if (userId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final fields = [
      'semesters', 'selectedId', 'nowId', 'zxf', 'zxfjd', 'pjjd', 'courseCount',
    ];
    for (final field in fields) {
      await prefs.remove(_key(userId, field));
    }
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
    for (final key in keys.toList()) {
      await prefs.remove(key);
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/score_semester_cache_test.dart`
Expected: All 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/score_semester_cache.dart test/core/services/score_semester_cache_test.dart
git commit -m "feat(score): add ScoreSemesterCache service with unit tests"
```

---

### Task 2: Integrate cache into ScorePage

**Files:**
- Modify: `lib/pages/score/scorepage.dart` (`_ScorePageState`)
- Test: existing `test/pages/score/scorepage_test.dart` (add new test cases)

**Interfaces:**
- Consumes: `ScoreSemesterCache.instance.read(userId)`, `ScoreSemesterCache.instance.write(userId, data)`, `AppAuthStorage.instance.readJwxtUsername()`
- Produces: Modified `getTimeList()` that restores from cache; new `_backgroundRefresh()` method; cache write on probe completion and selection change

- [ ] **Step 1: Add import and userId helper to `_ScorePageState`**

Add to the imports section of `lib/pages/score/scorepage.dart`:

```dart
import '../../core/services/app_auth_storage.dart';
import '../../core/services/score_semester_cache.dart';
```

Add a helper method inside `_ScorePageState`:

```dart
  Future<String> _resolveUserId() async {
    return AppAuthStorage.instance.readJwxtUsername();
  }
```

- [ ] **Step 2: Modify `getTimeList()` for cache-first path**

Replace the current `getTimeList()` method body with:

```dart
  Future<void> getTimeList() async {
    if (!first) {
      return;
    }

    final userId = await _resolveUserId();
    final cached = userId.isNotEmpty
        ? await ScoreSemesterCache.instance.read(userId)
        : null;

    if (cached != null) {
      semesterId = cached.semesterIds;
      nowSemesterId = cached.nowSemesterId.isEmpty ? 'all' : cached.nowSemesterId;
      selectedId = cached.selectedId;
      zxf = cached.zxf;
      zxfjd = cached.zxfjd;
      pjjd = cached.pjjd;
      first = false;
      _syncScoreContentState();
      _syncSelectionState();
      unawaited(_backgroundRefresh(userId));
      return;
    }

    final timeData = await (widget.loadSemesters ?? semesterIdfc)();
    if (!mounted) {
      return;
    }
    if (timeData.errorMessage != null) {
      semesterId = timeData.idList;
      nowSemesterId = timeData.nowId.isEmpty ? 'all' : timeData.nowId;
      _errorMessage = timeData.errorMessage;
      selectedId = 'all';
      first = false;
      _syncScoreContentState();
      _syncSelectionState();
      return;
    }

    final scoreData = await _loadScoreForSemester('all');
    if (!mounted) {
      return;
    }

    semesterId = timeData.idList;
    nowSemesterId = timeData.nowId.isEmpty ? 'all' : timeData.nowId;
    selectedId = 'all';
    _assignScoreData(scoreData, semesterId: 'all');
    first = false;
    _syncScoreContentState();
    _syncSelectionState();
    unawaited(_probeAvailableSemesters(timeData.idList));
  }
```

- [ ] **Step 3: Add `_backgroundRefresh()` method**

Add after `getTimeList()`:

```dart
  Future<void> _backgroundRefresh(String userId) async {
    try {
      final timeData = await (widget.loadSemesters ?? semesterIdfc)();
      if (!mounted) return;
      if (timeData.errorMessage != null) return;

      await _loadScoreForSemester('all');
      if (!mounted) return;

      // 启动探测，完成后写缓存
      await _probeAvailableSemesters(timeData.idList);
      if (!mounted) return;

      await _writeCacheSnapshot(userId);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Background score refresh failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
```

- [ ] **Step 4: Add `_writeCacheSnapshot()` helper**

Add after `_backgroundRefresh()`:

```dart
  Future<void> _writeCacheSnapshot(String userId) async {
    if (userId.isEmpty) return;

    await ScoreSemesterCache.instance.write(
      userId,
      ScoreSemesterCacheData(
        semesterIds: semesterId,
        selectedId: selectedId,
        nowSemesterId: nowSemesterId,
        zxf: zxf,
        zxfjd: zxfjd,
        pjjd: pjjd,
        courseCount: scoreList.length,
      ),
    );
  }
```

- [ ] **Step 5: Write cache after `_probeAvailableSemesters` completes in the non-cached path**

In the existing `getTimeList()` non-cached branch, the call to `_probeAvailableSemesters` is already `unawaited`. Modify `_probeAvailableSemesters` to write cache at the end. Add at the very end of the `_probeAvailableSemesters` method (before the final closing brace):

```dart
    // 探测完毕，持久化结果
    final cacheUserId = await _resolveUserId();
    await _writeCacheSnapshot(cacheUserId);
```

- [ ] **Step 6: Write cache on semester selection change**

At the end of `_refreshScoresForSelection`, after the final `_syncSelectionState()` call (the successful path, line ~220), add:

```dart
    unawaited(_resolveUserId().then(_writeCacheSnapshot));
```

- [ ] **Step 7: Run existing tests to verify no regressions**

Run: `flutter test test/pages/score/scorepage_test.dart`
Expected: All existing tests PASS. The tests mock `SharedPreferences.setMockInitialValues({})` implicitly via the test framework, so the cache `read()` returns null and existing behavior is unchanged.

- [ ] **Step 8: Add test for cache-first restore**

Add to `test/pages/score/scorepage_test.dart`:

```dart
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
```

- [ ] **Step 9: Run all score tests**

Run: `flutter test test/pages/score/scorepage_test.dart`
Expected: All tests PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/pages/score/scorepage.dart test/pages/score/scorepage_test.dart
git commit -m "feat(score): integrate semester cache into ScorePage for instant restore"
```

---

### Task 3: Logout cache clearance

**Files:**
- Modify: `lib/core/services/app_auth_storage.dart`
- Test: `test/core/services/score_semester_cache_test.dart` (extend existing)

**Interfaces:**
- Consumes: `ScoreSemesterCache.instance.clearAll()`
- Produces: `clearAllAuthData()` now also clears score cache

- [ ] **Step 1: Add import to `app_auth_storage.dart`**

Add at the top of `lib/core/services/app_auth_storage.dart`:

```dart
import 'score_semester_cache.dart';
```

- [ ] **Step 2: Add cache clear call at end of `clearAllAuthData()`**

In `clearAllAuthData()`, after `await _deleteSecurePassword(_hutPasswordKey, label: 'HUT');` (line 247), add:

```dart
    await ScoreSemesterCache.instance.clearAll();
```

- [ ] **Step 3: Write integration test**

Add a new test to `test/core/services/score_semester_cache_test.dart`:

```dart
  test('clearAll is callable without error on empty prefs', () async {
    // 验证空状态下 clearAll 不会抛异常
    await ScoreSemesterCache.instance.clearAll();
    // 无异常即通过
  });
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/services/score_semester_cache_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/services/app_auth_storage.dart test/core/services/score_semester_cache_test.dart
git commit -m "feat(score): clear semester cache on logout"
```

---

### Task 4: Static analysis and final verification

**Files:**
- All modified files

- [ ] **Step 1: Run static analysis**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 2: Run full test suite**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 3: Format code**

Run: `dart format lib/core/services/score_semester_cache.dart lib/pages/score/scorepage.dart lib/core/services/app_auth_storage.dart test/core/services/score_semester_cache_test.dart test/pages/score/scorepage_test.dart`
Expected: No formatting changes (or changes applied).

- [ ] **Step 4: Final commit (if formatting changed)**

```bash
git add -u
git commit -m "style(score): format semester cache files"
```
