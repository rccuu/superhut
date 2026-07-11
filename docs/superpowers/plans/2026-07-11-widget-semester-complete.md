# Widget Semester Complete Empty State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the course widget has local schedule history but no remaining future courses, show a congratulatory semester-complete empty state instead of “当前暂无课表 / 同步或导入后显示课程”.

**Architecture:** Keep the existing relevant-course state machine (`today_courses` → `next_monday` / `tomorrow_courses` → `next_course` → terminal empty). Split only the terminal empty branch into `semester_complete` (store has historical courses) vs `empty` (no schedule). Implement the same branch in Flutter payload builders, iOS WidgetKit recompute, and Android App Widget recompute. No store schema change; UI already renders `isEmpty` via `headerTitle` / `headerSubtitle` / `emptyText`.

**Tech Stack:** Dart/Flutter (`coursemain.dart`), SwiftUI WidgetKit (`CourseWidget.swift`), Android Java App Widget (`CourseTableWidgetProvider.java`), Flutter unit tests.

**Spec:** `docs/superpowers/specs/2026-07-11-widget-semester-complete-design.md`

## Global Constraints

- Copy (exact strings, do not paraphrase):
  - `semester_complete.status` = `semester_complete`
  - `headerTitle` = `本学期课程已上完`
  - `headerSubtitle` = `辛苦啦，下学期见`
  - `emptyText` = `可同步新学期课表`
  - `empty` remains: `当前暂无课表` / `同步或导入后显示课程` / `同步或导入后显示课程`
- Historical courses = any non-empty `dayCourses[date]` OR any `days[date]` with `status == "today_courses"` and non-empty `courses`
- Do not expand store schema (`firstDay` / `maxWeek` stay out of store)
- Do not change visual layout, deep link, refresh policy, or priority of today/tomorrow/next
- iOS and Android must mirror Flutter terminal-branch semantics

## File map

| File | Responsibility |
|------|----------------|
| `lib/utils/course/coursemain.dart` | Historical-course check, semester-complete payload builder, terminal branches in relevant + per-date builders |
| `test/utils/course/coursemain_test.dart` | Unit coverage for semester_complete vs empty and non-regression |
| `ios/CourseWidget/CourseWidget.swift` | iOS local recompute terminal branch |
| `android/app/src/main/java/com/tune/superhut/CourseTableWidgetProvider.java` | Android local recompute terminal branch |

---

### Task 1: Flutter terminal branch + unit tests

**Files:**
- Modify: `lib/utils/course/coursemain.dart` (near `_buildEmptyCourseWidgetPayload` ~L954 and terminal returns ~L1088 / ~L1318)
- Test: `test/utils/course/coursemain_test.dart` (append after existing next-course tests ~L1047)

**Interfaces:**
- Consumes: `CourseWidgetStore`, existing `_resolveStoreDayCourses`, `_dateKey`, `_weekdayLabel`, `_weekIndexFromStore`, `_weekdayLabelFromStore`
- Produces:
  - `bool _hasHistoricalCourses(CourseWidgetStore store)`
  - `CourseWidgetPayload _buildSemesterCompleteCourseWidgetPayload({required DateTime date, required String updatedAt, int weekIndex = 0})`
  - Terminal branch returns `semester_complete` when historical courses exist and no future course day remains

- [ ] **Step 1: Write failing tests**

Append to `test/utils/course/coursemain_test.dart` after the unordered next-course test:

```dart
  test(
    'buildCompactCourseWidgetPayloadFromStore uses semester_complete when history exists and no future courses remain',
    () {
      final store = buildCourseWidgetStoreFromRawData(
        firstDay: '2026-03-16',
        maxWeek: 4,
        updatedAt: '2026-03-27T07:30:00.000',
        courseData: {
          '2026-03-20': [
            Course(
              name: '高数',
              teacherName: '张老师',
              weekDuration: '1-16',
              location: '公教101',
              startSection: 1,
              duration: 2,
            ),
          ],
        },
      );

      // After the only historical day, and with today's last course already over.
      final payload = buildCompactCourseWidgetPayloadFromStore(
        store,
        now: DateTime.parse('2026-03-27T12:00:00'),
      );

      expect(payload.status, 'semester_complete');
      expect(payload.isEmpty, isTrue);
      expect(payload.courses, isEmpty);
      expect(payload.headerTitle, '本学期课程已上完');
      expect(payload.headerSubtitle, '辛苦啦，下学期见');
      expect(payload.emptyText, '可同步新学期课表');
      expect(payload.date, '2026-03-27');
    },
  );

  test(
    'buildCompactCourseWidgetPayloadFromStore keeps empty when store has no historical courses',
    () {
      final emptyStore = CourseWidgetStore(
        schemaVersion: 2,
        updatedAt: '2026-03-27T07:30:00.000',
        days: const <String, CourseWidgetPayload>{},
        dayCourses: const <String, List<CourseWidgetCourseEntry>>{},
      );

      final payload = buildCompactCourseWidgetPayloadFromStore(
        emptyStore,
        now: DateTime.parse('2026-03-27T12:00:00'),
      );

      expect(payload.status, 'empty');
      expect(payload.headerTitle, '当前暂无课表');
      expect(payload.headerSubtitle, '同步或导入后显示课程');
      expect(payload.emptyText, '同步或导入后显示课程');
    },
  );

  test(
    'buildCompactCourseWidgetPayloadFromStore returns empty when store is null',
    () {
      final payload = buildCompactCourseWidgetPayloadFromStore(
        null,
        now: DateTime.parse('2026-03-27T12:00:00'),
      );

      expect(payload.status, 'empty');
      expect(payload.headerTitle, '当前暂无课表');
      expect(payload.emptyText, '同步或导入后显示课程');
    },
  );

  test(
    'buildCompactCourseWidgetPayloadFromStore uses semester_complete from legacy days without dayCourses',
    () {
      const pastCourse = CourseWidgetCourseEntry(
        name: '08:00 高数',
        meta: '公教101',
        location: '公教101',
        startSection: 1,
        endSection: 2,
        startTime: '08:00',
        sectionLabel: '1-2节',
      );
      final store = CourseWidgetStore(
        schemaVersion: 2,
        updatedAt: '2026-03-27T07:30:00.000',
        days: {
          '2026-03-20': CourseWidgetPayload(
            date: '2026-03-20',
            weekdayLabel: '周五',
            weekIndex: 1,
            status: 'today_courses',
            headerTitle: '今天课程',
            headerSubtitle: '周五 · 第1周',
            emptyText: '今日暂无课程',
            isEmpty: false,
            updatedAt: '2026-03-27T07:30:00.000',
            courses: const [pastCourse],
          ),
        },
        dayCourses: const <String, List<CourseWidgetCourseEntry>>{},
      );

      final payload = buildCompactCourseWidgetPayloadFromStore(
        store,
        now: DateTime.parse('2026-03-27T12:00:00'),
      );

      expect(payload.status, 'semester_complete');
      expect(payload.headerTitle, '本学期课程已上完');
      expect(payload.emptyText, '可同步新学期课表');
    },
  );

  test(
    'buildCompactCourseWidgetPayloadFromStore does not use semester_complete when tomorrow still has class',
    () {
      final store = buildCourseWidgetStoreFromRawData(
        firstDay: '2026-03-16',
        maxWeek: 4,
        updatedAt: '2026-03-27T07:30:00.000',
        courseData: {
          '2026-03-27': [
            Course(
              name: '高数',
              teacherName: '张老师',
              weekDuration: '1-16',
              location: '公教101',
              startSection: 1,
              duration: 2,
            ),
          ],
          '2026-03-28': [
            Course(
              name: '编译原理',
              teacherName: '周老师',
              weekDuration: '1-16',
              location: '信工楼201',
              startSection: 1,
              duration: 2,
            ),
          ],
        },
      );

      final payload = buildCompactCourseWidgetPayloadFromStore(
        store,
        now: DateTime.parse('2026-03-27T12:00:00'),
      );

      expect(payload.status, 'tomorrow_courses');
      expect(payload.headerTitle, '明天有课');
      expect(payload.status, isNot('semester_complete'));
    },
  );

  test(
    'buildCourseWidgetStore precomputes semester_complete for dates after last course day',
    () {
      final store = buildCourseWidgetStoreFromRawData(
        firstDay: '2026-03-16',
        maxWeek: 2,
        updatedAt: '2026-03-27T07:30:00.000',
        courseData: {
          '2026-03-16': [
            Course(
              name: '第一周周一课程',
              teacherName: '张老师',
              weekDuration: '1-16',
              location: '公共101',
              startSection: 1,
              duration: 2,
            ),
          ],
        },
      );

      // 2026-03-17 is after the only course day inside term range.
      final afterLast = store.days['2026-03-17'];
      expect(afterLast, isNotNull);
      expect(afterLast!.status, 'semester_complete');
      expect(afterLast.headerTitle, '本学期课程已上完');
      expect(afterLast.headerSubtitle, '辛苦啦，下学期见');
      expect(afterLast.emptyText, '可同步新学期课表');
      expect(afterLast.isEmpty, isTrue);
    },
  );
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
flutter test test/utils/course/coursemain_test.dart --name "semester_complete"
```

Expected: FAIL — actual status is `empty` / titles are still `当前暂无课表`, and the precompute test expects `semester_complete` but gets `empty` or `下次课程` depending on path. At least the first and last new tests should fail for wrong status/copy.

- [ ] **Step 3: Implement Flutter helpers and terminal branches**

In `lib/utils/course/coursemain.dart`, add constants near other top-level consts (after payload file name consts is fine):

```dart
const String _courseWidgetStatusEmpty = 'empty';
const String _courseWidgetStatusSemesterComplete = 'semester_complete';
const String _courseWidgetSemesterCompleteHeaderTitle = '本学期课程已上完';
const String _courseWidgetSemesterCompleteHeaderSubtitle = '辛苦啦，下学期见';
const String _courseWidgetSemesterCompleteEmptyText = '可同步新学期课表';
```

Add helpers immediately after `_buildEmptyCourseWidgetPayload`:

```dart
bool _hasHistoricalCourses(CourseWidgetStore store) {
  for (final courses in store.dayCourses.values) {
    if (courses.isNotEmpty) {
      return true;
    }
  }
  for (final payload in store.days.values) {
    if (payload.status == 'today_courses' && payload.courses.isNotEmpty) {
      return true;
    }
  }
  return false;
}

bool _hasHistoricalCoursesInCourseData(Map<String, List<Course>> courseData) {
  for (final courses in courseData.values) {
    if (courses.isNotEmpty) {
      return true;
    }
  }
  return false;
}

CourseWidgetPayload _buildSemesterCompleteCourseWidgetPayload({
  required DateTime date,
  required String updatedAt,
  int weekIndex = 0,
}) {
  final dateKey = _dateKey(date);
  return CourseWidgetPayload(
    date: dateKey,
    weekdayLabel: _weekdayLabel(date.weekday),
    weekIndex: weekIndex,
    status: _courseWidgetStatusSemesterComplete,
    headerTitle: _courseWidgetSemesterCompleteHeaderTitle,
    headerSubtitle: _courseWidgetSemesterCompleteHeaderSubtitle,
    emptyText: _courseWidgetSemesterCompleteEmptyText,
    isEmpty: true,
    updatedAt: updatedAt,
    courses: const [],
  );
}
```

Optionally align empty builder to use `_courseWidgetStatusEmpty` for consistency (not required).

Replace the terminal return of `_buildRelevantCourseWidgetPayloadFromStore` (currently `_buildEmptyCourseWidgetPayload(...)`) with:

```dart
  if (_hasHistoricalCourses(store)) {
    return _buildSemesterCompleteCourseWidgetPayload(
      date: today,
      updatedAt: updatedAt,
      weekIndex: todayWeekIndex,
    );
  }

  return _buildEmptyCourseWidgetPayload(date: today, updatedAt: updatedAt);
```

Replace the terminal return of `_buildCourseWidgetPayloadForDate` (the inline `status: 'empty'` payload) with:

```dart
  if (_hasHistoricalCoursesInCourseData(courseData)) {
    return _buildSemesterCompleteCourseWidgetPayload(
      date: date,
      updatedAt: updatedAt,
      weekIndex: weekIndex,
    );
  }

  return CourseWidgetPayload(
    date: dateKey,
    weekdayLabel: _weekdayLabel(date.weekday),
    weekIndex: weekIndex,
    status: _courseWidgetStatusEmpty,
    headerTitle: '当前暂无课表',
    headerSubtitle: '同步或导入后显示课程',
    emptyText: '同步或导入后显示课程',
    isEmpty: true,
    updatedAt: updatedAt,
    courses: const [],
  );
```

Notes for implementer:
- Prefer reusing `_buildEmptyCourseWidgetPayload` for the empty branch if you can pass `weekIndex`; if not, keep the inline empty payload with `weekIndex` from the date builder (existing behavior used `weekIndex` there).
- Do **not** change today/tomorrow/next branches.

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
flutter test test/utils/course/coursemain_test.dart --name "semester_complete|empty when|tomorrow still|precomputes semester"
flutter test test/utils/course/coursemain_test.dart --name "buildCompactCourseWidgetPayloadFromStore|buildCourseWidgetStore precomputes"
```

Also run the full course main suite:

```bash
flutter test test/utils/course/coursemain_test.dart
```

Expected: all PASS. Existing tomorrow/next-course tests must still pass.

If `buildCourseWidgetStore precomputes empty dates inside term range` fails because a date after last course now returns `semester_complete` instead of `下次课程`/`empty`, that is expected only for dates with **no** later courses — the existing test at L237 uses a later Thursday course so Tuesday should remain `下次课程`. Do not change that expectation.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/course/coursemain.dart test/utils/course/coursemain_test.dart
git commit -m "$(cat <<'EOF'
feat(widget): show semester-complete empty state when no future courses

Split terminal empty branch so stores with historical courses show
congratulatory copy instead of sync/import empty state.
EOF
)"
```

---

### Task 2: iOS WidgetKit terminal branch

**Files:**
- Modify: `ios/CourseWidget/CourseWidget.swift` (`relevantPayload` terminal return ~L318, helpers near `emptyPayload` / `actualCourseDateKeys`)

**Interfaces:**
- Consumes: existing `CourseWidgetStoreData`, `actualCourseDateKeys(from:)`, `emptyPayload(for:updatedAt:)`
- Produces: when no next course date and historical course keys exist → payload with `status: "semester_complete"` and fixed Chinese copy from Global Constraints

- [ ] **Step 1: Add semester-complete payload helper**

Near `emptyPayload(for:updatedAt:)` in `CourseWidgetRepository`, add:

```swift
  private static func semesterCompletePayload(
    for date: Date,
    updatedAt: String,
    weekIndex: Int
  ) -> CourseWidgetPayload {
    return CourseWidgetPayload(
      date: dateKey(from: date),
      weekdayLabel: weekdayLabel(from: date),
      weekIndex: weekIndex,
      status: "semester_complete",
      headerTitle: "本学期课程已上完",
      headerSubtitle: "辛苦啦，下学期见",
      emptyText: "可同步新学期课表",
      isEmpty: true,
      updatedAt: updatedAt,
      courses: []
    )
  }
```

- [ ] **Step 2: Branch terminal path in `relevantPayload`**

Replace:

```swift
    return emptyPayload(for: today, updatedAt: updatedAt)
```

at the end of `relevantPayload(from:now:)` with:

```swift
    if !actualCourseDateKeys(from: store).isEmpty {
      return semesterCompletePayload(
        for: today,
        updatedAt: updatedAt,
        weekIndex: todayWeekIndex
      )
    }

    return emptyPayload(for: today, updatedAt: updatedAt)
```

`actualCourseDateKeys` already matches historical-course semantics used by Flutter (`dayCourses` non-empty keys, else `days` with `today_courses`).

Do not change timeline refresh logic.

- [ ] **Step 3: Sanity-check compile (if Xcode tooling available)**

If on a Mac with the iOS project ready:

```bash
# Optional; skip if no simulator / signing setup
xcodebuild -workspace ios/Runner.xcworkspace -scheme CourseWidget -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

If this fails for unrelated signing/workspace reasons, do not block: review the Swift diff carefully instead.

- [ ] **Step 4: Commit**

```bash
git add ios/CourseWidget/CourseWidget.swift
git commit -m "$(cat <<'EOF'
feat(widget): mirror semester-complete empty state on iOS

When the course store has historical days but no future courses, show
congratulatory empty copy instead of sync/import empty state.
EOF
)"
```

---

### Task 3: Android App Widget terminal branch

**Files:**
- Modify: `android/app/src/main/java/com/tune/superhut/CourseTableWidgetProvider.java` (`buildRelevantPayloadFromStore` ~L524, helpers near `buildEmptyPayload` ~L552)

**Interfaces:**
- Consumes: existing `actualCourseDateKeys(daysObject, dayCoursesObject)`, `buildEmptyPayload`
- Produces: `buildSemesterCompletePayload(String dateKey, int weekIndex, String updatedAt)` returning `status = "semester_complete"` and Global Constraints copy

- [ ] **Step 1: Add semester-complete payload builder**

Immediately after `buildEmptyPayload`, add:

```java
    private static CompactPayload buildSemesterCompletePayload(
            String dateKey,
            int weekIndex,
            String updatedAt
    ) {
        CompactPayload payload = CompactPayload.empty();
        payload.date = dateKey;
        payload.weekdayLabel = weekdayLabelFromDateKey(dateKey);
        payload.weekIndex = weekIndex;
        payload.status = "semester_complete";
        payload.headerTitle = "本学期课程已上完";
        payload.headerSubtitle = "辛苦啦，下学期见";
        payload.emptyText = "可同步新学期课表";
        payload.updatedAt = updatedAt;
        payload.isEmpty = true;
        return payload;
    }
```

- [ ] **Step 2: Branch terminal path in `buildRelevantPayloadFromStore`**

Replace:

```java
        return buildEmptyPayload(todayKey, updatedAt);
```

with:

```java
        if (!actualCourseDateKeys(daysObject, dayCoursesObject).isEmpty()) {
            return buildSemesterCompletePayload(todayKey, todayWeekIndex, updatedAt);
        }

        return buildEmptyPayload(todayKey, updatedAt);
```

`actualCourseDateKeys` already mirrors Flutter historical-course detection.

No layout XML changes; empty UI already uses `headerTitle` / empty text.

- [ ] **Step 3: Optional compile check**

```bash
# Optional; skip if Android SDK not configured in this environment
./gradlew :app:compileReleaseJavaWithJavac 2>&1 | tail -40
```

If Gradle is unavailable, visual review of the Java branch is enough for this task.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/java/com/tune/superhut/CourseTableWidgetProvider.java
git commit -m "$(cat <<'EOF'
feat(widget): mirror semester-complete empty state on Android

Use the same historical-course terminal branch as Flutter/iOS so
end-of-term widgets show congratulatory empty copy.
EOF
)"
```

---

### Task 4: Regression + manual acceptance checklist

**Files:**
- No new code unless a bug is found

- [ ] **Step 1: Run Flutter widget/course tests**

```bash
flutter test test/utils/course/coursemain_test.dart
```

Expected: all PASS.

- [ ] **Step 2: Manual acceptance (device or simulator when available)**

Checklist from the design spec:

1. Local schedule exists, last course day is in the past → widget shows:
   - 标题：`本学期课程已上完`
   - 副标题：`辛苦啦，下学期见`
   - 正文：`可同步新学期课表`
2. Fresh install / no schedule → still `当前暂无课表` / `同步或导入后显示课程`
3. Today remaining courses / tomorrow / next course → unchanged
4. Clear schedules → back to `empty`
5. Sync new semester with future courses → leaves `semester_complete`

If devices are unavailable, mark manual steps as deferred in the PR/commit message and rely on unit tests + code review of the three mirrored branches.

- [ ] **Step 3: Final commit only if fixes were needed**

If Task 4 only verified, no commit. If fixes landed, commit with a focused message, e.g.:

```bash
git commit -m "$(cat <<'EOF'
fix(widget): correct semester-complete edge cases

EOF
)"
```

---

## Spec coverage self-check

| Spec requirement | Task |
|------------------|------|
| Distinguish semester end vs no schedule | Task 1 |
| Congratulatory copy exact strings | Tasks 1–3 Global Constraints |
| Flutter relevant + per-date builders | Task 1 |
| iOS mirror | Task 2 |
| Android mirror | Task 3 |
| Historical via dayCourses + legacy days | Tasks 1–3 (`_hasHistoricalCourses` / `actualCourseDateKeys`) |
| No schema expansion / no layout rewrite | All tasks |
| Today/tomorrow/next unchanged | Task 1 regression tests + Tasks 2–3 no branch edits |
| Unit tests for key branches | Task 1 |
| Manual acceptance | Task 4 |

## Placeholder scan

No TBD/TODO steps; each code-changing step includes concrete snippets and commands.

## Type / name consistency

- Status string: `semester_complete` everywhere
- Helpers: `_hasHistoricalCourses`, `_buildSemesterCompleteCourseWidgetPayload` (Dart); `semesterCompletePayload` (Swift); `buildSemesterCompletePayload` (Java)
- Copy fields: `headerTitle` / `headerSubtitle` / `emptyText` / `isEmpty=true` / `courses=[]`
