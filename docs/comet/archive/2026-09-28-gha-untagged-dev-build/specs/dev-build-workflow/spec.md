# Capability: dev-build-workflow

## 概述

`dev-build-workflow` 让维护者在不打 Git tag 的前提下，通过 GitHub Actions 手动构建并下载工大盒子的 Android / iOS 安装包。它与 `release.yml` 的 tag 发布链路完全独立，两者互不影响。

## 入口

- 唯一入口：GitHub Actions 页面上的 `Dev Build` workflow，通过 `workflow_dispatch` 手动触发。
- 输入项 `platform`（`choice`，必填，默认 `both`）：
  - `both`：同时构建 Android 与 iOS。
  - `android`：只构建 Android。
  - `ios`：只构建 iOS。
- 没有其他触发器：不打 tag、不推分支、不开 PR 都不会自动运行。

## 运行名

运行名格式为 `Dev Build · <platform> · <ref_name>`。

## 权限

- `permissions.contents: read`。
- 不申请 `contents: write`，因此无法创建或修改 Release。
- 不读取任何 Secret。

## 并发

- `concurrency.group` 为 `dev-build-<github.ref>`。
- `cancel-in-progress: true`：同一 ref 上新的手动运行会取消上一次尚未结束的运行。
- 与 `release.yml` 的 `release-*` 组不同名，两者互不取消。

## Android job（`android`）

执行条件：`platform` 为 `both` 或 `android`。

runner：`macos-latest`。

步骤：

1. `actions/checkout@v4` 检出触发时的 ref。
2. `actions/setup-java@v4`，`distribution: temurin`，`java-version: "17"`。
3. `subosito/flutter-action@v2`，`flutter-version: "3.41.9"`，`channel: stable`。
4. `bash scripts/build_android_release.sh`：构建 arm64-v8a release APK，产出 `releases/superhut-v<pubspec version>-arm64-v8a-release-<时间戳>.apk`。
5. `actions/upload-artifact@v4`：artifact 名 `superhut-android-apk`，path `releases/superhut-*-arm64-v8a-*.apk`，`if-no-files-found: error`，保留 30 天。

## iOS job（`ios`）

执行条件：`platform` 为 `both` 或 `ios`。

runner：`macos-latest`。

步骤：

1. `actions/checkout@v4` 检出触发时的 ref。
2. `subosito/flutter-action@v2`，`flutter-version: "3.41.9"`，`channel: stable`。
3. `bash scripts/build_ios_quick.sh`：`flutter clean` → `flutter pub get` → `flutter precache --ios` → `pod install` → `flutter build ios --no-coresign --release`，剥离签名后打包为 `releases/superhut-v<pubspec version>-unsigned-<时间戳>.ipa`。
4. 安装 `ldid`（不存在时执行 `brew install ldid`）。
5. `bash scripts/build_ios_trollstore.sh <第 3 步产出的未签名 IPA>`：用 `scripts/trollstore/*.entitlements.plist` 对主 app 与 `CourseWidget.appex` 做 ldid fakesign，产出 `releases/superhut-v<pubspec version>-trollstore-<时间戳>.tipa`，并自动执行 `scripts/verify_ios_widget_signing.sh --mode trollstore` 校验。
6. `actions/upload-artifact@v4`：artifact 名 `superhut-ios-packages`，path 同时覆盖 `releases/superhut-*-unsigned-*.ipa` 与 `releases/superhut-*-trollstore-*.tipa`，`if-no-files-found: error`，保留 30 天。

## 版本与产物命名

- 版本号唯一来源是 `pubspec.yaml` 的 `version:`（当前为 `1.6.6+19`）。
- workflow 不推导、不传递、也不校验版本号，更不要求当前 ref 是 tag。
- 因此同一份代码重复构建会因时间戳不同而得到不同文件名，可以区分每次运行。

## 与 tag 发布链路的关系

- `release.yml` 只由 `push.tags: ["v*"]` 或带必填 `tag` 输入项的 `workflow_dispatch` 触发，并且会强校验 tag 与 pubspec 版本一致；该链路本次不改动。
- 两个 workflow 的并发组不同，互不取消。
- 应用内更新检查只认非 draft、非 prerelease 的正式 Release，因此本 capability 不产生任何 Release，也就不会进入用户的更新提示。

## 文件边界

本次只新增 `.github/workflows/dev-build.yml`。不改 `release.yml`、`scripts/`、`pubspec.yaml`、`lib/`。
