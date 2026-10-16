# Outcome

The change records a read-only comparison between this repository and upstream `cc2562/superhut` `master` after fork point `b05265c` (2025-05-25). It identifies which upstream platform changes are already present on current `main`, and which upstream logic is worth learning. No application behavior changes.

# Scope

- Compare `b05265c` with `upstream/master` at `7b37379` (2026-08-18).
- Exclude SMS-login history authored in this repository and later merged upstream.
- Cover dependency and Android build tooling, academic-system authentication, course sync, WebView cookies, hot water, and upstream-only features.

## Directory structure

### Created

- Nothing. The investigation record already lives in this change's target spec, which Archive promotes to `docs/comet/specs/upstream-delta-review/spec.md`; no new project file is added.

### Modified

- `docs/comet/changes/review-upstream-delta/specs/upstream-delta-review/spec.md` — the record itself. It carries no application change; this round only corrects and sharpens facts against read-only evidence: main's own commit count since the fork (151 → 156), the source of the Gradle `9.2.1` pin (the wrapper is `android/gradle/wrapper/gradle-wrapper.properties`, not a repository-root wrapper), the measured size of the upstream day-view widget (1,038 lines against 135 lines of `logic.dart`), the full paths of the three upstream Android notification classes, the commit that actually adds `test/course_table_logic_test.dart` (`a05f833`, not `9fd9fd5`), the fact that `9fd9fd5` grows the 9-line `logic.dart` stub created at project init (`b83f4ba`) to its final 135 lines instead of introducing the file, the complete set of seven day-view helpers with their source-order line numbers (16/29/33/58/62/93/104), the attribution of the archive/silent-refresh/widget-payload logic to `lib/utils/course/coursemain.dart` rather than `course_sync_service.dart`, the correction that the network-versus-expired-session classification belongs to the course-sync path (`coursemain.dart:519-532`) and not to `lib/utils/token.dart`, whose `checkTokenValid` collapses every error and every non-`1` code into a single `false`, and the note that the 96 upstream-only commits are a commit count rather than a count of missing capabilities (8 of them authored here for SMS login, and `git cherry` marks 33 of 76 patch-carrying commits as already equivalent on `main`).

### Deleted

- Nothing.

### Not created

- No application source file is created or edited: `lib/**`, `android/**`, `test/**` and `pubspec.yaml` stay identical to current `main`.
- No upstream file is copied in: neither the day-view `logic.dart` helpers, nor `lib/theme/theme_controller.dart`, nor the `com/zhiquxy/rice/*.kt` notification chain.
- No implementation plan, task list, or generated report file; the target spec is the only deliverable.

# Non-goals

- Do not merge upstream code or port the day view, dynamic color theme, or class live notification.
- Do not modify `pubspec.yaml`, Gradle, login, course, or WebView implementation.
- Do not reconcile branding, package name, icons, legal documents, or README differences.

# Acceptance examples

- A1：梳理 `b05265c..upstream/master` 中本仓库缺失的提交，把已被当前 `main` 覆盖的平台改动与三个上游独有逻辑区分开，并给出各自依据。
- A2：核对 Android 构建工具链、教务系统 cookie、Type2 WebView cookie、实验课解析、热水开启结果，确认每项能力在当前 `main` 上已存在并引用对应文件。
- A3：阅读上游日视图辅助函数、主题偏好控制器与 Android 上课通知实现，说明可复用逻辑、边界行为，以及不应照搬的部分。
- A4：产出仅为调研文档，`pubspec.yaml`、Gradle、登录、课表、WebView 等应用代码保持不变，不合并、不移植上游代码。

# Constraints and invariants

- The investigation is read-only apart from `git fetch upstream`, which only updates the local remote-tracking branch.
- Every conclusion must trace to a commit or a file on current `main`. Branding changes and duplicate commits are not new capabilities.
- Features where current `main` is ahead of upstream `master` are not treated as missing.

# Decisions

- This change delivers the investigation only and does not enter implementation.
- Android Gradle Plugin `8.12.3`, Kotlin `2.2.21`, Gradle `9.2.1`, and `compileSdk 36` on current `main` already match or exceed upstream, so the build-toolchain delta is not a follow-up.
- The logic worth learning is limited to the course day-view pure functions and tests, the theme preference controller, and the Android class-notification scheduling state machine.
- No product behavior change: documentation-only wording.

# Open questions

- [confirmed 2026-10-09] Deliver only the upstream-delta investigation, without merging or porting code; the outcome, scope, the three learning areas, and the non-goal of leaving application code unchanged are all confirmed by the user.

# Verification expectations

- Verify the conclusions with read-only Git history, `git diff`, and the current source files.
- Do not run the application test suite because no implementation changes.
