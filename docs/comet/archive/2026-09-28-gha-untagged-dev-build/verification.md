---
generated_from_state_version: 11
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-09-28T01:05:02.644Z
- 摘要: All ten acceptance items pass on independent static verification. I parsed the workflow with Ruby Psych (the `on:` key parses as boolean `true`), enumerated the trigger/input structure, evaluated both job-level `if:` expressions for platform = both/android/ios by literal substitution (android = true/true/false, ios = true/false/true), and read every step's uses/run/with block. The android and ios upload steps have distinct artifact names and `retention-days: 30`; the iOS upload `path` is a block scalar that parses to exactly the two required globs. Negative conditions hold: no `gh release` calls, no GH_TOKEN/token/secrets reference, `permissions` is exactly `{contents: read}`, the only `github.ref` uses are the concurrency group and the display-only run-name, and neither of the two `if:` lines references a tag. Concurrency prefixes `dev-build-` vs `release-` differ, and the three build scripts derive filenames solely from `grep "version:" pubspec.yaml` plus a `date` timestamp, with no GITHUB_REF, git describe/tag, or positional version argument. Change scope is confirmed by `git status --porcelain=v1 -uall` (only `?? .github/workflows/dev-build.yml` outside `.comet/`), empty `git diff HEAD --stat`, and empty `main...HEAD` diff. I additionally reproduced the Builder's shell check by extracting all four `run:` blocks and running `bash -n` on each (0 failures). The one thing neither I nor the Builder could verify is actual GitHub Actions execution, which is expected for a CI-config change and is already stated as the brief's known limitation.

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1：`.github/workflows/dev-build.yml` 存在，且能被 YAML 解析器正常解析。 | `.github/workflows/dev-build.yml` exists (2243 bytes, mtime 2026-09-28 08:54) and parses cleanly with Ruby Psych YAML.safe_load, yielding top-level keys [name, true(=on:), permissions, concurrency, run-name, jobs]. |
| A2 | passed | brief.md | A2：解析出的触发方式只有 `workflow_dispatch`，其输入项只有 `platform`，取值为 `both` / `android` / `ios` 且默认 `both`；不存在任何必填的 tag 输入项。 | Parsed trigger map has exactly one key `workflow_dispatch`; its `inputs` has exactly one key `platform` with type=choice, options=[both, android, ios], default=both, required=true; no input name contains 'tag' and the only required input is platform. |
| A3 | passed | brief.md | A3：`android` job 的 `if` 条件让它在 `platform` 为 `android` 或 `both` 时执行、为 `ios` 时不执行；其步骤包含 `bash scripts/build_android_release.sh` 和产物上传，上传 path 能覆盖 `releases/superhut-*-arm64-v8a-*.apk`。 | android job `if: "inputs.platform == 'both' \|\| inputs.platform == 'android'"` evaluates true for both/android and false for ios; steps include `bash scripts/build_android_release.sh` (L44) and upload-artifact@v4 whose path is exactly `releases/superhut-*-arm64-v8a-*.apk` (L50), which matches a real script output name `superhut-v1.6.6+19-arm64-v8a-release-<ts>.apk`. |
| A4 | passed | brief.md | A4：`ios` job 的 `if` 条件让它在 `platform` 为 `ios` 或 `both` 时执行、为 `android` 时不执行；其步骤包含 `bash scripts/build_ios_quick.sh`、ldid 安装、`bash scripts/build_ios_trollstore.sh` 和产物上传，上传 path 同时覆盖未签名 `*.ipa` 与 `*.tipa`。 | ios job `if: "inputs.platform == 'both' \|\| inputs.platform == 'ios'"` evaluates true for both/ios and false for android; steps include `bash scripts/build_ios_quick.sh` (L67), ldid install via `command -v ldid` + `brew install ldid` (L70-73), `bash scripts/build_ios_trollstore.sh "$UNSIGNED_IPA"` (L78), and the upload path block scalar parses to the two lines `releases/superhut-*-unsigned-*.ipa` and `releases/superhut-*-trollstore-*.tipa`. |
| A5 | passed | brief.md | A5：两个上传步骤的 artifact 名称互不相同，且都设置了保留期。 | The two upload-artifact@v4 steps use distinct names `superhut-android-apk` and `superhut-ios-packages`, and both set `retention-days: 30` (parsed as integer 30, not nil). |
| A6 | passed | brief.md | A6：workflow 内不存在依赖「当前引用是 tag」的内容：没有比对 tag 与 `pubspec.yaml` 版本的校验步骤，没有以 `github.ref` 是否为 tag 为条件的分支。 | The only `github.ref`/`ref_name` uses are L20 `concurrency.group: dev-build-${{ github.ref }}` and L23 `run-name: ... ${{ github.ref_name }}`; the only two `if:` keys in the file (L28, L56) compare `inputs.platform` alone; raw text has no `pubspec`, `refs/tags`, `startsWith(`, `contains(`, or `version:` grep. |
| A7 | passed | brief.md | A7：workflow 内没有 `gh release create` / `gh release edit` / `gh release upload` 或任何创建、修改 GitHub Release 的调用；`permissions` 只声明 `contents: read`。 | Raw text has no `gh release` substring and no `gh release create\|edit\|upload\|delete\|view` match, no `GH_TOKEN`, no `github.token`, no `secrets.*`; parsed `permissions` equals exactly `{"contents" => "read"}`. |
| A8 | passed | brief.md | A8：`concurrency.group` 与 `.github/workflows/release.yml` 的组名前缀不同，两者不会互相取消。 | dev-build.yml `concurrency.group` = `dev-build-${{ github.ref }}` vs release.yml's `release-${{ github.event.inputs.tag \|\| github.ref_name }}`; literal prefixes `dev-build-` and `release-` differ, so the two group strings can never collide. |
| A9 | passed | brief.md | A9：安装包文件名不依赖 tag：`scripts/build_android_release.sh` 与 `scripts/build_ios_quick.sh` 的产物名只由 `pubspec.yaml` 的 `version:` 推导。 | build_android_release.sh L10 `VERSION=$(grep "version:" pubspec.yaml \| awk '{print $2}' \| tr -d '\r')` -> L23 `superhut-v${VERSION}-arm64-v8a-release-${TIMESTAMP}.apk`; build_ios_quick.sh L18 uses the identical VERSION source -> L68 `superhut-v${VERSION}-unsigned-${TIMESTAMP}.ipa`; no GITHUB_REF, `git describe/tag/rev-parse`, or positional version arg in any of the three scripts, so only `date` timestamps vary. pubspec.yaml L19 version: 1.6.6+19. |
| A10 | passed | brief.md | A10：本次改动后，`git status` / `git diff` 只显示新增 `.github/workflows/dev-build.yml`，`release.yml`、`scripts/`、`pubspec.yaml`、`lib/` 均无改动。 | `git status --porcelain=v1 -uall` excluding `.comet/` yields exactly one line `?? .github/workflows/dev-build.yml`; `git diff HEAD --stat` and `git diff --name-status main...HEAD` are both empty, so release.yml, scripts/, pubspec.yaml and lib/ are unmodified. |

## 检查

_没有记录 Runtime 检查。_

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- yaml-parse-and-structure: passed — ruby YAML.unsafe_load 解析 dev-build.yml 成功；触发键只有 workflow_dispatch，输入项只有 platform（options both/android/ios，default both，无必填 tag 输入项）；两个 job 的 if 条件按 both/android/ios 逐一求值，android=[true,true,false]、ios=[true,false,true]；两个 artifact 名互异且 retention-days 均为 30。
- inline-shell-syntax: passed — 提取 workflow 内全部 4 个 run 块，逐个 bash -n 通过，0 语法错误。
- negative-greps: passed — workflow 内无 refs/tags、github.ref_type、startsWith(github.ref)、以 tag 为条件的 if 分支；未出现 pubspec.yaml；无 gh release create/edit/upload/delete/view。github.ref_name 仅出现在 run-name（L23，纯展示）。
- release-workflow-untouched: passed — dev-build.yml 的 concurrency.group 为 dev-build-${{ github.ref }}，release.yml 为 release-${{ github.event.inputs.tag || github.ref_name }}，前缀 dev/release 不同，互不取消。
- artifact-naming-independent-of-tag: passed — 脚本侧核对：build_android_release.sh 输出 superhut-v${VERSION}-arm64-v8a-release-${TIMESTAMP}.apk，build_ios_quick.sh 输出 superhut-v${VERSION}-unsigned-${TIMESTAMP}.ipa，VERSION 均只来自 pubspec.yaml 的 version:，且两个脚本都不引用 GITHUB_REF。
- git-status-scope: passed — git status --porcelain=v1 忽略 .comet/ 后仅一条：?? .github/workflows/dev-build.yml。
- 已知限制: 未运行 GitHub Actions：本地无法执行 workflow，A1-A10 全部是静态验收。真实出包需维护者在 Actions 页面手动触发一次（platform 分别取 android/ios/both），确认 run 成功并下载到可安装的 APK / 可重签 IPA / 可装进 TrollStore 的 TIPA。
- 已知限制: 无自动化测试可写：本次改动是 CI 配置，仓库现有 flutter test 体系不覆盖它。
- 已知限制: Android job 复用 macOS runner，未在 Linux 上验证过（brief D4 已记录原因与后续迁移建议）。

## 阻塞项

_无。_

## 风险与跳过的工作

- The iOS upload step's `path` is a multi-line YAML block scalar (two glob patterns). actions/upload-artifact@v4 supports newline-separated patterns, but no prior workflow in this repo used multi-line path (da107dc and 507f15d both used a single-line glob), so there is no in-repo precedent and this cannot be exercised locally.
- `.github/workflows/dev-build.yml` is untracked in the worktree (git status shows `??`), so the workflow takes no effect until the change is committed or merged into main (brief D3).
- The iOS job selects the IPA with `UNSIGNED_IPA="$(ls -t releases/superhut-*-unsigned-*.ipa | head -n 1)"`, which assumes a fresh `releases/` on the runner; that holds because `/releases/` is gitignored and never committed, and the same pattern is used in release.yml.
- `retention-days: 30` is valid for public repos (allowed range 1-90) but would need to drop to 1-30 if the repository ever becomes private.
- `.gitignore` L55 `docs/*` ignores the whole docs tree, so brief.md and spec.md for this change are untracked and exist only inside this worktree.
- A8 only proves the concurrency groups cannot collide; it cannot prove they never interact, because `cancel-in-progress: true` on the dev-build group (brief D5) means a second manual run cancels the first and discards its still-uploading artifacts.
- No local test suite covers this file (it is CI configuration); real build success requires the maintainer to dispatch the workflow from the Actions page with platform = android / ios / both, as the brief's 验证预期 already states.

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | All ten acceptance items pass on independent static verification. I parsed the workflow with Ruby Psych (the `on:` key parses as boolean `true`), enumerated the trigger/input structure, evaluated both job-level `if:` expressions for platform = both/android/ios by literal substitution (android = true/true/false, ios = true/false/true), and read every step's uses/run/with block. The android and ios upload steps have distinct artifact names and `retention-days: 30`; the iOS upload `path` is a block scalar that parses to exactly the two required globs. Negative conditions hold: no `gh release` calls, no GH_TOKEN/token/secrets reference, `permissions` is exactly `{contents: read}`, the only `github.ref` uses are the concurrency group and the display-only run-name, and neither of the two `if:` lines references a tag. Concurrency prefixes `dev-build-` vs `release-` differ, and the three build scripts derive filenames solely from `grep "version:" pubspec.yaml` plus a `date` timestamp, with no GITHUB_REF, git describe/tag, or positional version argument. Change scope is confirmed by `git status --porcelain=v1 -uall` (only `?? .github/workflows/dev-build.yml` outside `.comet/`), empty `git diff HEAD --stat`, and empty `main...HEAD` diff. I additionally reproduced the Builder's shell check by extracting all four `run:` blocks and running `bash -n` on each (0 failures). The one thing neither I nor the Builder could verify is actual GitHub Actions execution, which is expected for a CI-config change and is already stated as the brief's known limitation. | 2026-09-28T01:05:02.644Z |



## 结论

All ten acceptance items pass on independent static verification. I parsed the workflow with Ruby Psych (the `on:` key parses as boolean `true`), enumerated the trigger/input structure, evaluated both job-level `if:` expressions for platform = both/android/ios by literal substitution (android = true/true/false, ios = true/false/true), and read every step's uses/run/with block. The android and ios upload steps have distinct artifact names and `retention-days: 30`; the iOS upload `path` is a block scalar that parses to exactly the two required globs. Negative conditions hold: no `gh release` calls, no GH_TOKEN/token/secrets reference, `permissions` is exactly `{contents: read}`, the only `github.ref` uses are the concurrency group and the display-only run-name, and neither of the two `if:` lines references a tag. Concurrency prefixes `dev-build-` vs `release-` differ, and the three build scripts derive filenames solely from `grep "version:" pubspec.yaml` plus a `date` timestamp, with no GITHUB_REF, git describe/tag, or positional version argument. Change scope is confirmed by `git status --porcelain=v1 -uall` (only `?? .github/workflows/dev-build.yml` outside `.comet/`), empty `git diff HEAD --stat`, and empty `main...HEAD` diff. I additionally reproduced the Builder's shell check by extracting all four `run:` blocks and running `bash -n` on each (0 failures). The one thing neither I nor the Builder could verify is actual GitHub Actions execution, which is expected for a CI-config change and is already stated as the brief's known limitation.
