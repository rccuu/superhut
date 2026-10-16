# Upstream delta review

## Purpose

This capability is a maintained record of what `cc2562/superhut` `master` added after this repository forked at `b05265c` on 2025-05-25, and which of that logic is worth learning. Reading it does not change application behavior.

## Comparison baseline

- Upstream remote: `https://github.com/cc2562/superhut.git`, branch `master`.
- Fork point: `b05265c` (`feat(electricity)`, 2025-05-25). It is an ancestor of current `main`.
- Upstream tip inspected: `7b37379` (2026-08-18).
- `b05265c..upstream/master` contains 96 commits that are not in current `main`. Current `main` has 156 commits of its own since the fork, so the histories diverged rather than one being behind.
- That 96 is a commit count, not a count of missing capabilities. Eight of them were authored in this repository and merged upstream afterwards (`git log b05265c..upstream/master --author=rccuu` returns the SMS-login chain from `1ea9814` to `a30f71e`), and `git cherry main upstream/master b05265c` reports 76 patch-carrying commits of which 33 are already patch-equivalent to something on `main` and 43 are not.

## Already covered on current main

- Android build stack: `android/settings.gradle.kts` uses Android Gradle Plugin `8.12.3` and Kotlin `2.2.21`; `android/app/build.gradle.kts` uses `compileSdk 36`, NDK `28.2.13676358`, release signing, shrinking, and ProGuard; `android/gradle/wrapper/gradle-wrapper.properties` pins Gradle `9.2.1`.
- Academic-system session: `lib/utils/withhttp.dart` sends `my_client_ticket` as a cookie and configures Dio from storage.
- Type2 WebView: `lib/pages/hutpages/type2/type2webview.dart` injects service cookies through `CookieManager` for `xzhngydx.hut.edu.cn`.
- Experiment courses: `lib/utils/course/get_course.dart` parses `weekNoteDetail` and `syxmName` into courses with `isExp: true`.
- Hot water: `lib/utils/hut_user_api/hut_user_api_water.dart` returns `result`, `message`, and `success`, and `lib/pages/water/logic.dart` treats a start as successful only when `success` is true and `result` is `000000`.
- Token renewal: `lib/utils/token.dart` returns a boolean, deduplicates concurrent renewals (the in-flight slot at :16, reused at :49-52), and prompts to log in again (`_showReauthPrompt` at :133-157). It deliberately does not separate a network outage from an expired session: `checkTokenValid` (:31-47) collapses any thrown error and any non-`1` code into a single `false`, and the login-rejected and login-threw branches (:92-110) both raise that same prompt. That classification lives on the course-sync side instead — `lib/utils/course/coursemain.dart:519-532` maps `DioExceptionType.connectionTimeout/sendTimeout/receiveTimeout/connectionError` to `网络连接失败，请检查网络后重试` and HTTP 401/403 to `教务系统登录状态已失效，请重新登录后再试`.
- Course refresh is stronger than upstream: the archive model, the silent-refresh plan, and the widget payloads all live in `lib/utils/course/coursemain.dart` (`CourseScheduleArchive` at :407, `CourseSilentRefreshReason` at :485 with its attempt keys at :28-30, widget store and payload file names at :23-24, `_parseWidgetCourseEntries` at :202), while `lib/core/services/course_sync_service.dart` only orchestrates `startManualSync` (:91).
- Commentary already exists under `lib/pages/Commentary/` with batch execution and tests.

## Worth learning

### Course day view

Upstream commit `9fd9fd5` turns `lib/home/coursetable/logic.dart` from the 9-line stub created at project init (`b83f4ba`) into its final 135 lines — 126 insertions, and no later commit on `upstream/master` touches the file again. Its day-view helpers, in source order:

- `courseTableViewModeFromPreference` (:16) defaults to week unless the stored value is exactly `day`.
- `normalizeCourseDate` (:29) drops the time part, keeping only year, month and day.
- `calculateSchoolWeekFromFirstDay` (:33) returns null for a missing, malformed, or impossible semester date instead of throwing.
- `isSameCourseDate` (:58) compares two dates through `normalizeCourseDate`.
- `moveCourseTableDay` (:62) changes the week only when crossing Monday or Sunday, and does not move past week 1 or the last week.
- `sortCoursesForDay` (:93) sorts a copy by section, then name.
- `findNextCoursesForDay` (:104) returns every course sharing the earliest start time still in the future, skips a course at or after its start, and returns nothing for another date.

The coverage came separately: `test/course_table_logic_test.dart` does not exist at `9fd9fd5` and was added by `a05f833`.

The day-view widget in upstream `lib/home/coursetable/view.dart` runs to 1,038 lines, against 135 lines for the `logic.dart` helpers above, and is not the part to copy. Current `main` already has its own week grid.

### Theme preference controller

Upstream commit `a05f833` adds `lib/theme/theme_controller.dart`. It persists theme mode, dynamic-color opt-in, and a preset, and resolves the scheme in this order: dynamic scheme when enabled and available, otherwise the selected preset. Selecting a preset turns dynamic color off. Current `main` builds fixed light and dark schemes in `lib/main.dart` and has no equivalent preference state.

### Android class progress notification

Upstream commit `8d49645` adds `android/app/src/main/kotlin/com/zhiquxy/rice/ClassScheduleManager.kt`, `ClassAlarmReceiver.kt`, and `NotificationHelper.kt`:

- The schedule is stored as JSON with class name, location, and absolute start and end timestamps.
- `scheduleNextAlarm` picks the earliest future boundary among ten minutes before start, start, and end, then schedules it with `AlarmManager.setAlarmClock`.
- The receiver matches the current time to the preparation or in-class window, shows a finished state for up to 60 seconds after the end, cancels the notification otherwise, and always schedules the next alarm.
- Boot and package replacement reschedule the chain. A 10-second partial wake lock covers the work.
- The notification uses `NotificationCompat.ProgressStyle`: the first 20 points cover preparation and the remaining 80 cover class time.

Do not copy the upstream package name `com.zhiquxy.rice`, and do not copy `USE_EXACT_ALARM` without a product decision. Current `main` has desktop widgets but no class-time notification chain.

## Not worth porting

- Brand rename to `超级包菜`, package `com.zhiquxy.rice`, icons, privacy text, and README updates.
- Replacing `google_nav_bar` with `flutter_floating_bottom_bar`. Current `main` already has a custom bottom dock in `lib/home/homeview/view.dart`.
- Upstream login and hot-water code. Current `main` has a stricter SMS session check and a split `HutUserApi`.
- `ionicons` to `ionicons_plus`, `introduction_screen` 4, and `sensors_plus` 7. Current `main` does not depend on the latter two, and the icon package is an unmaintained-package swap rather than new behavior.
