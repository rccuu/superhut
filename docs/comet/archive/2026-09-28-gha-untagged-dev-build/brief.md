# 目标

维护者可以在不打 Git tag 的情况下，从 GitHub Actions 页面手动触发一次构建，直接拿到工大盒子的 Android APK 与 iOS IPA / TrollStore TIPA 安装包。

# 范围

- 新增 `.github/workflows/dev-build.yml`，只由 `workflow_dispatch` 手动触发。
- 输入项只有 `platform`：`both`（默认）/ `android` / `ios`，用于选择构建哪一类安装包。
- `android` job：`actions/checkout@v4` → `actions/setup-java@v4`（temurin 17）→ `subosito/flutter-action@v2`（3.41.9 / stable）→ `bash scripts/build_android_release.sh` → 上传 artifact。
- `ios` job：`actions/checkout@v4` → `subosito/flutter-action@v2`（3.41.9 / stable）→ `bash scripts/build_ios_quick.sh` → 安装 ldid → `bash scripts/build_ios_trollstore.sh` → 上传 artifact。
- 两个 job 之间没有依赖关系，同时跑；按 `platform` 取值跳过不需要的那一个。
- 产物以 Actions artifact 形式上传，保留 30 天。
- 本次只新增这一个文件。

# 非目标

- 不为无 tag 构建创建、编辑或上传 GitHub Release。
- 不为无 tag 构建生成 Release Notes（`scripts/generate_release_notes.py` 仍强制要求 `--current-tag`，本次不改造它）。
- 不引入 push / pull_request / schedule 等任何自动构建触发器。
- 不引入签名密钥或 keystore：继续沿用 `android/app/build.gradle` 中「没有 release keystore 时回退 debug 签名」的现有行为。
- 不把 Android job 从 macOS runner 迁到 Linux runner（本仓库 Android 尚未在 Linux 上构建过）。
- 不改动应用内更新链路（`lib/core/services/app_update_service.dart` 保持原样）。
- 不改动 `scripts/`、`pubspec.yaml` 与任何 Dart 代码。

# 验收示例

- A1：`.github/workflows/dev-build.yml` 存在，且能被 YAML 解析器正常解析。
- A2：解析出的触发方式只有 `workflow_dispatch`，其输入项只有 `platform`，取值为 `both` / `android` / `ios` 且默认 `both`；不存在任何必填的 tag 输入项。
- A3：`android` job 的 `if` 条件让它在 `platform` 为 `android` 或 `both` 时执行、为 `ios` 时不执行；其步骤包含 `bash scripts/build_android_release.sh` 和产物上传，上传 path 能覆盖 `releases/superhut-*-arm64-v8a-*.apk`。
- A4：`ios` job 的 `if` 条件让它在 `platform` 为 `ios` 或 `both` 时执行、为 `android` 时不执行；其步骤包含 `bash scripts/build_ios_quick.sh`、ldid 安装、`bash scripts/build_ios_trollstore.sh` 和产物上传，上传 path 同时覆盖未签名 `*.ipa` 与 `*.tipa`。
- A5：两个上传步骤的 artifact 名称互不相同，且都设置了保留期。
- A6：workflow 内不存在依赖「当前引用是 tag」的内容：没有比对 tag 与 `pubspec.yaml` 版本的校验步骤，没有以 `github.ref` 是否为 tag 为条件的分支。
- A7：workflow 内没有 `gh release create` / `gh release edit` / `gh release upload` 或任何创建、修改 GitHub Release 的调用；`permissions` 只声明 `contents: read`。
- A8：`concurrency.group` 与 `.github/workflows/release.yml` 的组名前缀不同，两者不会互相取消。
- A9：安装包文件名不依赖 tag：`scripts/build_android_release.sh` 与 `scripts/build_ios_quick.sh` 的产物名只由 `pubspec.yaml` 的 `version:` 推导。
- A10：本次改动后，`git status` / `git diff` 只显示新增 `.github/workflows/dev-build.yml`，`release.yml`、`scripts/`、`pubspec.yaml`、`lib/` 均无改动。

# 约束与不变量

- 工具链必须复用 `release.yml` 中已经验证过的版本：`macos-latest`、`actions/checkout@v4`、`actions/setup-java@v4`（temurin 17）、`subosito/flutter-action@v2`（`flutter-version: "3.41.9"`、`channel: stable`）、`actions/upload-artifact@v4`。
- APK / IPA / TIPA 的生成逻辑和文件命名完全复用现有 `scripts/`，不在 workflow 里重新实现打包。
- 不引入新的密钥、Secret 或凭据读取。
- workflow 不自己产生版本号；版本号唯一来源仍是 `pubspec.yaml`。

# 决策

- D1：触发方式只保留 `workflow_dispatch` 手动，不加 push / PR / 定时。理由：用户明确选择；避免每次提交都消耗 CI 分钟。影响：没有自动 nightly，每次出包需要在 Actions 页面手动点一次。
- D2：产物放 Actions artifact 而不是 GitHub Release，保留 30 天。理由：用户明确选择；不产生公开 Release、到期自动清理。影响：安装包只能从对应 run 的页面下载，链接会随保留期过期失效。
- D3：本次改动在独立 worktree 上进行（分支 `comet/gha-untagged-dev-build`）。理由：项目已有另一个进行中的 Native change（`review-upstream-delta`），worktree 让写入归属明确。影响：完成后需要合并或推送才能到 main。
- D4：`android` job 也用 `macos-latest`，本次不迁 `ubuntu-latest`。理由：iOS job 本来就要 macOS；本仓库 Android 尚未在 Linux 上验证过（Android license 接受、NDK 28.2.13676358 下载），混在一次改动里风险不划算。影响：Android job 比 Linux runner 慢且更贵；后续可单独验证后再迁移。
- D5：`cancel-in-progress: true`。理由：手动 dev 构建被更新的手动构建取代更符合直觉。影响：并发发起第二次运行会取消第一次还没跑完的运行，其产物不会保留。
- D6：`platform` 默认 `both`。理由：最常需要的是一次拿全；选 `android` / `ios` 用来跳过另一半、省时间。影响：只想要 Android 时不能在默认值上直接点，需要手动改选项。

# 待解决问题

（无）

2026-09-28 用户确认：目标、范围、非目标、决策 D1-D6、验收示例 A1-A10 与验证预期作为最终共享理解。

# 验证预期

可本地静态验证的部分：

- 用 YAML 解析器解析 `.github/workflows/dev-build.yml`，核对 A1-A5、A8、A10。
- 用 `grep` 核对 A6、A7 中「不存在」类条件。
- 用 `git status --porcelain` / `git diff --stat` 核对 A10。
- A9 需读 `scripts/build_android_release.sh`、`scripts/build_ios_quick.sh`，确认产物命名只依赖 `pubspec.yaml`。

必须在 GitHub 上由维护者实际运行才能验收的部分（本地与 Verifier 都无法执行 GitHub Actions）：

- 在 Actions 页面手动运行 Dev Build，`platform` 分别取 `android`、`ios`、`both`，确认 run 成功结束，页面出现 `superhut-android-apk` 与 `superhut-ios-packages` 两个 artifact，且下载后是能装的 APK、可重签的 IPA 和可装进 TrollStore 的 TIPA。
- 确认当前 HEAD 没有打 tag 的前提下上述运行不失败。

已知限制：本次改动没有自动化测试可写（workflow 属于 CI 配置，仓库现有的 `flutter test` 体系不覆盖它），因此「真实构建成功」只能靠上面这次手动运行确认。
