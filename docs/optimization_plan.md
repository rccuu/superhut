# SuperHUT Optimization Plan

Last updated: 2026-03-19 (Ticket 14 HutUserApi split complete)

## Current status

This document is the handoff plan for the ongoing cleanup and optimization work.

What has already been completed in this round:

- Added a shared auth/storage layer in `lib/core/services/`.
- Moved stored passwords out of `SharedPreferences` and into `flutter_secure_storage`.
- Added migration logic so existing users can transparently move old saved passwords.
- Unified JWXT token/cookie reads through the new storage layer.
- Refactored the main JWXT login flow, CAS token flow, and logout flow to use the shared storage layer.
- Reduced duplicated direct credential access in:
  - `lib/utils/token.dart`
  - `lib/login/loginwithpost.dart`
  - `lib/login/webview_login_screen.dart`
  - `lib/login/unified_login_page.dart`
  - `lib/login/hut_cas_login_page.dart`
  - `lib/utils/hut_user_api.dart`
  - `lib/pages/water/logic.dart`
  - `lib/home/userpage/view.dart`
- Fixed the app locale from `zh_CH` to `zh_CN`.
- Replaced the default counter test with a real onboarding smoke test.
- Moved dev-only packages out of runtime dependencies:
  - `flutter_launcher_icons`
  - `change_app_package_name`
- Applied `dart fix --apply` once across the project.
- Cleaned `lib/utils/course/get_course.dart`:
  - replaced debug prints with `AppLogger`
  - added typed helpers for parsing
  - added safer course-data merging
  - added mounted guards for course-loading snackbars
  - removed loose inference in key utility entry points
- Cleaned nearby utility files:
  - `lib/utils/widget_data_helper.dart`
  - `lib/utils/course/coursemain.dart`
  - `lib/utils/hut_user_api.dart`
- Refactored `lib/pages/Electricitybill/electricity_page.dart`:
  - extracted recharge validation and snackbar helpers
  - fixed async `BuildContext` usage in recharge, room picker, and alert bottom sheet flows
  - removed duplicate `setState` and page-local debug `print`
  - tightened room info refresh and warning-setting persistence logic
- Cleaned the active recharge API path in `lib/pages/Electricitybill/electricity_api.dart`:
  - renamed `JSESSIONID` to `jsessionId`
- Refactored `lib/home/coursetable/view.dart`:
  - replaced the one-time `firstload` guard with a dedicated initial-load future
  - extracted toolbar, weekday header, section column, and bottom-sheet UI into `widgets/course_table_widgets.dart`
  - removed duplicated course-detail sheet markup
  - fixed async `BuildContext` usage in the experiment-student flow
  - removed dead null-aware code and nearby dead controller code
- Refactored `lib/pages/water/view.dart`:
  - extracted presentation widgets and bottom-sheet UI into `widgets/water_page_widgets.dart`
  - removed local pseudo-localization and responsive helper debt from the main page
  - replaced deprecated `withOpacity` usage in this flow
  - fixed the bubble animation immutability warning by moving completion state out of the widget fields
  - kept page-level device / action flow in `view.dart` while shrinking the file substantially
- Refactored `lib/pages/drink/view/view.dart`:
  - extracted presentation widgets, bottom sheets, and QR-scan flow into `widgets/drink_page_widgets.dart`
  - kept page-level device selection and drink action flow in `view.dart` while shrinking the file substantially
- Cleaned the drink flow support files:
  - tightened async init / cleanup and device-state handling in `lib/pages/drink/view/logic.dart`
  - removed debug `print` calls from `lib/pages/drink/api/drink_api.dart`
  - refactored `lib/pages/drink/login/command.dart` to use typed async flows with mounted guards
  - fixed public `createState()` signatures in the drink login pages
- Renamed and cleaned the commentary flow:
  - replaced `Commentary*.dart` files with snake_case file names under `lib/pages/Commentary/`
  - renamed the page widgets to `CommentaryBatchPage`, `CommentaryCourseListPage`, and `CommentaryQuestionPage`
  - updated the function-entry import and route usage to the new page names
  - removed debug `print` calls, tightened payload typing, and fixed async submission handling in the question flow
- Cleaned the low-risk UI warning batch:
  - removed dead easter-egg text state from `lib/home/about/view.dart` and wired the opacity animation to the live text opacity value
  - replaced deprecated `withOpacity` usage in `lib/home/userpage/view.dart`
  - fixed public `createState()` signatures in the main login pages
- Cleaned the HUT webview batch:
  - replaced debug `print` calls with `AppLogger` in the type1/type2 webview flows
  - replaced deprecated `withOpacity` usage in both webview overlays
  - updated the type2 back-navigation flow to `onPopInvokedWithResult`
  - fixed async permission / Alipay handling so `BuildContext` is used safely after awaits
- Cleaned the score batch:
  - renamed `jumpToScorePage.dart` to `jump_to_score_page.dart`
  - fixed async navigation and loading-dialog handling in the score flow
  - removed the leftover score-page debug `print`
  - renamed score-page local helpers to lowerCamelCase
- Completed the residual naming-cleanup batch:
  - renamed remaining analyzer-visible legacy files to snake_case across bridge, electricity, free-room, hut main, and course utility flows
  - renamed `GetBuilding`, `JSESSIONID`, and `Sw` local identifiers to follow lowerCamelCase conventions
  - updated all imports and call sites to the new file paths
- Completed the final HUT auth/session storage audit:
  - extended `lib/core/services/app_auth_storage.dart` with HUT session helpers for token, refresh token, device id, and login status
  - removed remaining feature-level raw HUT session reads and writes from:
    - `lib/utils/hut_user_api.dart`
    - `lib/pages/water/logic.dart`
    - `lib/pages/hutpages/hutmain_logic.dart`
    - `lib/pages/Electricitybill/electricity_api.dart`
  - kept the custom key fallback in `lib/login/hut_cas_login_page.dart` unchanged because it intentionally supports non-default token/cookie keys
- Added focused auth/session regression coverage:
  - password migration tests for JWXT and HUT secure storage reads
  - HUT session helper persistence tests
  - logout/auth-clear regression coverage around `clearAllAuthData()`
  - cached token happy-path coverage for JWXT and HUT token reads
- Added utility regression coverage for stable local helpers:
  - course cache write/read coverage for app and widget consumers
  - widget refresh service success/failure wrapper coverage
  - hardened `loadClassFromLocal()` so first load without a cache file returns empty data without logging a file-read error
- Split the HUT API facade into smaller helper parts without changing callers:
  - kept `lib/utils/hut_user_api.dart` as the stable public entry point
  - moved auth, session, water, portal, and shared support logic into `lib/utils/hut_user_api/`
  - reduced the maintenance risk of future HUT feature work by removing the old 700+ line single-file hotspot

## Verification snapshot

Commands run in this round:

- `flutter pub get`
- `dart fix --apply`
- `flutter analyze`
- `flutter test test/widget_test.dart`

Results after the latest cleanup batch:

- `flutter test test/widget_test.dart`: passing
- `flutter analyze`: passing, no issues found
- `flutter analyze lib/home/coursetable/view.dart lib/home/coursetable/widgets/course_table_widgets.dart`: no issues found
- `flutter analyze lib/pages/water/view.dart lib/pages/water/widgets/water_page_widgets.dart`: no issues found
- `flutter analyze lib/pages/drink/view/view.dart lib/pages/drink/view/logic.dart lib/pages/drink/view/widgets/drink_page_widgets.dart lib/pages/drink/api/drink_api.dart lib/pages/drink/login/command.dart lib/pages/drink/login/view.dart lib/pages/drink/login/loginpart2.dart`: no issues found
- `flutter analyze lib/home/Functionpage/view.dart lib/pages/Commentary/commentary_api.dart lib/pages/Commentary/commentary_batch_page.dart lib/pages/Commentary/commentary_course_list_page.dart lib/pages/Commentary/commentary_question_page.dart`: no issues found
- `flutter analyze lib/home/about/view.dart lib/home/userpage/view.dart lib/login/hut/view.dart lib/login/login_page.dart`: no issues found
- `flutter analyze lib/pages/hutpages/type1/type1webview.dart lib/pages/hutpages/type2/type2webview.dart`: no issues found
- `flutter analyze lib/pages/score/jump_to_score_page.dart lib/pages/score/scorepage.dart lib/main.dart`: no issues found
- `flutter analyze`: passing again after Ticket 11
- `flutter test test/widget_test.dart`: passing after Ticket 11
- `flutter test test/core/services/app_auth_storage_test.dart test/utils/auth_token_helpers_test.dart`: passing
- `flutter analyze`: passing again after Ticket 12
- `flutter test`: passing after Ticket 12
- `flutter test test/utils/course/coursemain_test.dart test/widget_refresh_service_test.dart`: passing
- `flutter analyze`: passing again after Ticket 13
- `flutter test`: passing after Ticket 13
- `flutter analyze lib/utils/hut_user_api.dart lib/utils/hut_user_api lib/pages/hutpages/hutmain.dart lib/pages/water/logic.dart lib/login/hut/view.dart lib/login/hut_cas_login_page.dart lib/pages/Electricitybill/electricity_api.dart`: passing after Ticket 14
- `flutter analyze`: passing again after Ticket 14
- `flutter test`: passing after Ticket 14

Important note:

- The analyzer backlog has been cleared to zero.
- The highest-risk auth/storage work has already been addressed first.
- The current stabilization baseline is now strong enough to stop scheduled cleanup tickets and return to feature work.
- The optional HutUserApi structural split has also been completed, so there is no scheduled optimization ticket left in this plan.
- The remaining optimization items below are optional maintenance backlog, not blockers for the next feature batch.

## New files added

- `lib/core/services/app_auth_storage.dart`
- `lib/core/services/app_logger.dart`
- `lib/home/coursetable/widgets/course_table_widgets.dart`
- `lib/pages/water/widgets/water_page_widgets.dart`
- `lib/pages/drink/view/widgets/drink_page_widgets.dart`
- `lib/pages/Commentary/commentary_api.dart`
- `lib/pages/Commentary/commentary_batch_page.dart`
- `lib/pages/Commentary/commentary_course_list_page.dart`
- `lib/pages/Commentary/commentary_question_page.dart`
- `lib/pages/score/jump_to_score_page.dart`
- `lib/bridge/get_course_page.dart`
- `lib/pages/Electricitybill/electricity_api.dart`
- `lib/pages/Electricitybill/electricity_page.dart`
- `lib/pages/freeroom/building_bridge.dart`
- `lib/pages/hutpages/hutmain_logic.dart`
- `lib/pages/hutpages/hutmain_state.dart`
- `lib/utils/course/get_course.dart`
- `test/support/secure_storage_mock.dart`
- `test/support/path_provider_mock.dart`
- `test/core/services/app_auth_storage_test.dart`
- `test/utils/auth_token_helpers_test.dart`
- `test/utils/course/coursemain_test.dart`
- `test/widget_refresh_service_test.dart`
- `lib/utils/hut_user_api/hut_user_api_support.dart`
- `lib/utils/hut_user_api/hut_user_api_auth.dart`
- `lib/utils/hut_user_api/hut_user_api_session.dart`
- `lib/utils/hut_user_api/hut_user_api_water.dart`
- `lib/utils/hut_user_api/hut_user_api_portal.dart`

## Main goals for the next rounds

1. Keep auth/session storage centralized and avoid reintroducing feature-level raw key access.
2. Only schedule structural refactors when they clearly help the next feature batch move faster.
3. Keep the test baseline healthy while prioritizing product and feature work first.
4. Keep auth/token refresh behavior documented and stable.
5. Avoid reintroducing analyzer debt as features continue to evolve.

## Remaining work by priority

### P0: keep auth and storage consistent

- Treat `lib/core/services/app_auth_storage.dart` as the single entry point for persisted auth/session state.
- During future feature work, audit any newly introduced direct reads/writes of:
  - `user`
  - `password`
  - `hutUsername`
  - `hutPassword`
  - `token`
  - `my_client_ticket`
  - `hutToken`
  - `hutRefreshToken`
  - `deviceId`
  - `hutIsLogin`
- Leave the custom `tokenKey` / `cookieKey` fallback in `lib/login/hut_cas_login_page.dart` as an explicit escape hatch unless a real product need justifies abstracting it further.

Recommended files to inspect next:

- `lib/login/hut_cas_login_page.dart`
- `lib/login/hut_login_system.dart`
- `lib/utils/token.dart`
- `lib/widget_refresh_service.dart`

### P1: clean the biggest high-churn pages

These are the biggest remaining files worth splitting next only if feature work touches them heavily:

- `lib/pages/hutpages/hutmain.dart`
- `lib/bridge/get_course_page.dart`
- `lib/pages/freeroom/building_bridge.dart`

Suggested split pattern:

- `view.dart`
- `widgets/*.dart`
- `logic.dart`
- `models.dart` or `state.dart`
- `services/*.dart`

### P1: harden frequently touched utilities and bridge files

Good next cleanup targets:

- Audit remaining raw auth/token reads.
- Reduce shared mutable state where simple wrappers are enough.
- Add clearer helper boundaries where flows are still hard to trace.
- Add a couple of focused tests around the riskiest utilities.

Best next files for low-risk wins:

- `lib/utils/pwd.dart`
- `lib/pages/freeroom/building_bridge.dart`
- `lib/bridge/get_course_page.dart`
- `lib/pages/hutpages/hutmain_logic.dart`
- `lib/widget_refresh_service.dart`

### P2: naming cleanup

Analyzer-visible naming cleanup is complete as of 2026-03-19.

Future renames should be opportunistic only when a touched area benefits from clearer semantics.

### P2: tests

Current test coverage is minimal.

Add next:

- a narrower token-renewal decision test only after the network/UI boundary is extracted

## Recommended execution order from here

1. Switch back to product and feature work.
2. Only schedule another cleanup pass when feature work touches a risky area.
3. Revisit remaining large pages only if they start slowing delivery again.
4. Only add webview/login refresh tests after extracting a mockable boundary.

## Resume commands

Use these commands when continuing later:

```bash
flutter pub get
flutter analyze
flutter test test/widget_test.dart
rg -n "print\\(" lib
rg -n "getString\\('password'|setString\\('password'|getString\\('hutPassword'|setString\\('hutPassword'" lib
rg -n "withOpacity\\(" lib
```

## Suggested next ticket breakdown

Ticket 1:

- Finish cleanup of `lib/utils/course/get_course.dart`
- Replace debug prints
- Add missing types
- Reduce analyzer warnings in that file

Status:

- Completed on 2026-03-19
- Follow-up is optional only if future product work warrants a deeper split

Recommended next ticket now:

- No blocking optimization ticket remains in the current baseline
- No scheduled Ticket 15 is needed before returning to feature work

Ticket 2:

- Refactor `lib/pages/Electricitybill/electricity_page.dart`
- Fix async context issues
- Extract request and state handling from UI

Status:

- Completed on 2026-03-19
- Naming cleanup for the electricity files was completed later in Ticket 10

Ticket 3:

- Split `lib/home/coursetable/view.dart` into smaller widgets
- Remove dead code
- Fix null-aware and async warnings

Status:

- Completed on 2026-03-19
- Added `lib/home/coursetable/widgets/course_table_widgets.dart`
- Removed unused `lib/home/coursetable/logic.dart`
- `flutter analyze lib/home/coursetable/view.dart lib/home/coursetable/widgets/course_table_widgets.dart`: clean

Ticket 4:

- Split `lib/pages/water/view.dart`
- Reduce `withOpacity` and naming debt in the same pass where safe
- Keep widget behavior unchanged while shrinking the main file

Status:

- Completed on 2026-03-19
- Added `lib/pages/water/widgets/water_page_widgets.dart`
- `flutter analyze lib/pages/water/view.dart lib/pages/water/widgets/water_page_widgets.dart`: clean

Ticket 5:

- Split `lib/pages/drink/view/view.dart`
- Reduce async-context and typing debt in the same pass where safe
- Preserve existing drink flow behavior while shrinking the main page

Status:

- Completed on 2026-03-19
- Added `lib/pages/drink/view/widgets/drink_page_widgets.dart`
- Cleaned `lib/pages/drink/view/logic.dart`, `lib/pages/drink/api/drink_api.dart`, and `lib/pages/drink/login/command.dart`
- Fixed public widget API typing in:
  - `lib/pages/drink/login/view.dart`
  - `lib/pages/drink/login/loginpart2.dart`
- `flutter analyze lib/pages/drink/view/view.dart lib/pages/drink/view/logic.dart lib/pages/drink/view/widgets/drink_page_widgets.dart lib/pages/drink/api/drink_api.dart lib/pages/drink/login/command.dart lib/pages/drink/login/view.dart lib/pages/drink/login/loginpart2.dart`: clean

Ticket 6:

- Rename `Commentary*` files and types
- Update imports
- Re-run analyze

Status:

- Completed on 2026-03-19
- Replaced legacy files with:
  - `lib/pages/Commentary/commentary_api.dart`
  - `lib/pages/Commentary/commentary_batch_page.dart`
  - `lib/pages/Commentary/commentary_course_list_page.dart`
  - `lib/pages/Commentary/commentary_question_page.dart`
- Renamed the page widgets to:
  - `CommentaryBatchPage`
  - `CommentaryCourseListPage`
  - `CommentaryQuestionPage`
- Cleaned the remaining commentary-file `print` calls, naming issues, and async submit flow
- `flutter analyze lib/home/Functionpage/view.dart lib/pages/Commentary/commentary_api.dart lib/pages/Commentary/commentary_batch_page.dart lib/pages/Commentary/commentary_course_list_page.dart lib/pages/Commentary/commentary_question_page.dart`: clean

Ticket 7:

- Remove unused fields and dead helpers in `lib/home/about/view.dart`
- Replace deprecated `withOpacity` calls in `lib/home/userpage/view.dart`
- Fix public `createState()` signatures in:
  - `lib/login/hut/view.dart`
  - `lib/login/login_page.dart`
- Re-run analyze

Status:

- Completed on 2026-03-19
- `flutter analyze lib/home/about/view.dart lib/home/userpage/view.dart lib/login/hut/view.dart lib/login/login_page.dart`: clean
- `flutter test test/widget_test.dart`: passing after this batch

Ticket 8:

- Remove remaining debug `print` calls in:
  - `lib/pages/hutpages/type1/type1webview.dart`
  - `lib/pages/hutpages/type2/type2webview.dart`
- Replace deprecated `withOpacity` calls in the same batch
- Fix `BuildContext` across async gaps in `lib/pages/hutpages/type2/type2webview.dart`
- Re-run analyze

Status:

- Completed on 2026-03-19
- `flutter analyze lib/pages/hutpages/type1/type1webview.dart lib/pages/hutpages/type2/type2webview.dart`: clean
- `flutter test test/widget_test.dart`: passing after this batch

Ticket 9:

- Fix async `BuildContext` usage in:
  - `lib/pages/score/jump_to_score_page.dart`
  - `lib/pages/score/scorepage.dart`
- Remove the remaining score-page `print` call
- Rename local identifiers such as `ShowLoadingDialog` and `BigTopCard` to lowerCamelCase where safe
- Re-run analyze

Status:

- Completed on 2026-03-19
- Renamed `lib/pages/score/jumpToScorePage.dart` to `lib/pages/score/jump_to_score_page.dart`
- `flutter analyze lib/pages/score/jump_to_score_page.dart lib/pages/score/scorepage.dart lib/main.dart`: clean
- `flutter test test/widget_test.dart`: passing after this batch

Ticket 10:

- Rename legacy files to snake_case in small batches:
  - `lib/bridge/get_course_page.dart`
  - `lib/pages/Electricitybill/electricity_api.dart`
  - `lib/pages/Electricitybill/electricity_page.dart`
  - `lib/pages/freeroom/building_bridge.dart`
  - `lib/pages/hutpages/hutmain_logic.dart`
  - `lib/pages/hutpages/hutmain_state.dart`
  - `lib/utils/course/get_course.dart`
- Rename remaining legacy local identifiers where safe:
  - `GetBuilding` in `lib/pages/freeroom/building_bridge.dart`
  - `JSESSIONID` locals in `lib/utils/hut_user_api.dart`
  - `Sw` in `lib/utils/pwd.dart`
- Re-run analyze after each rename batch

Status:

- Completed on 2026-03-19
- `flutter analyze`: clean project-wide
- `flutter test test/widget_test.dart`: passing after this batch

Ticket 11:

- Audit all remaining auth/token storage reads and writes in:
  - `lib/utils/hut_user_api.dart`
  - `lib/login/hut_login_system.dart`
  - `lib/login/hut/view.dart`
  - `lib/login/login_page.dart`
- Move any leftover raw password/token access behind `AppAuthStorage`
- Re-run analyze and smoke tests

Status:

- Completed on 2026-03-19
- Added HUT session helpers to `lib/core/services/app_auth_storage.dart`
- Replaced the remaining raw HUT session storage access in:
  - `lib/utils/hut_user_api.dart`
  - `lib/pages/water/logic.dart`
  - `lib/pages/hutpages/hutmain_logic.dart`
  - `lib/pages/Electricitybill/electricity_api.dart`
- Left `lib/login/hut_cas_login_page.dart` custom key fallback unchanged by design
- `flutter analyze`: clean
- `flutter test test/widget_test.dart`: passing

Ticket 12:

- Add focused regression coverage for auth/session behavior:
  - `AppAuthStorage` migration and HUT session helpers
  - logout clearing auth data
  - token refresh / cached token happy path where feasible
- Prefer small tests over broad widget rewrites
- Keep the ticket scoped to stable paths that do not depend on fragile webview flows

Status:

- Completed on 2026-03-19
- Added:
  - `test/support/secure_storage_mock.dart`
  - `test/core/services/app_auth_storage_test.dart`
  - `test/utils/auth_token_helpers_test.dart`
- Covered:
  - legacy password migration into secure storage
  - HUT session helper persistence
  - auth clearing via `clearAllAuthData()`
  - JWXT and HUT cached token reads
- `flutter analyze`: clean
- `flutter test`: passing

Ticket 13:

- Add focused tests for:
  - course cache read/write helpers
  - `lib/widget_refresh_service.dart` wrapper behavior with mocked channel
- Keep the scope on stable utility code, not webviews
- Re-run full `flutter test` and `flutter analyze`

Status:

- Completed on 2026-03-19
- Added:
  - `test/support/path_provider_mock.dart`
  - `test/utils/course/coursemain_test.dart`
  - `test/widget_refresh_service_test.dart`
- Covered:
  - course cache write/read behavior for both app and widget file paths
  - widget refresh service success and failure return paths
- Hardened:
  - `lib/utils/course/coursemain.dart` now returns `{}` on first load when `course_data.json` is absent, without treating that normal cold-start case as an error
- `flutter analyze`: clean
- `flutter test`: passing

Ticket 14:

- Split `lib/utils/hut_user_api.dart` into smaller auth/session/service helpers while keeping the public API stable
- Keep existing callers unchanged
- Re-run analyze and tests

Status:

- Completed on 2026-03-19
- Kept `lib/utils/hut_user_api.dart` as the facade and moved implementation into:
  - `lib/utils/hut_user_api/hut_user_api_support.dart`
  - `lib/utils/hut_user_api/hut_user_api_auth.dart`
  - `lib/utils/hut_user_api/hut_user_api_session.dart`
  - `lib/utils/hut_user_api/hut_user_api_water.dart`
  - `lib/utils/hut_user_api/hut_user_api_portal.dart`
- Preserved existing callers in login, water, hut main, and electricity flows
- `flutter analyze`: clean
- `flutter test`: passing

## Risks to remember

- Git has now been initialized locally on branch `main`, but there is still no first baseline commit yet.
- Some features still depend on fragile third-party web flows and unofficial endpoints.
- Large file renames should be done in small groups to avoid breaking imports silently.

## Definition of done for the optimization effort

- `flutter analyze` has no warnings or infos that matter operationally.
- auth and token logic no longer depends on scattered raw storage access
- all major pages under reasonable size
- at least a small smoke/integration test baseline exists
- logout/login/refresh/course-cache flows are documented and stable
