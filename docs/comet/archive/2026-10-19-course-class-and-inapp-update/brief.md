# Outcome

两项改进：

1. 课程详情弹层展示「班级」信息。数据来自教务系统课表接口返回的课堂/班级名称字段（暂按普通课表 item 的 `ktmc` 接入，待样本确认）。旧数据无该字段时显示回退文案，不影响其他信息行。
2. 应用内更新从「跳转外部浏览器下载」升级为「应用内下载 + 顶部进度横幅 + 下载完成后自动唤起安装」。下载期间用户可正常使用应用。Android 直接唤起系统安装流程；iOS 按确认结果处理（本应用 iOS 发行物为 TrollStore 包）。

# Scope

## 目录结构

### 新建

- Android FileProvider 路径配置 `android/app/src/main/res/xml/file_paths.xml`
- 更新下载服务（放 `lib/core/services/`，命名实现期定，如 `app_update_download_service.dart`）
- 顶部更新进度横幅组件（放 `lib/home/homeview/`，实现期定）

### 修改

- `lib/utils/course/coursemain.dart`：`Course` 模型新增班级字段，含 toJson/fromJson/分享兼容
- `lib/utils/course/get_course.dart`：解析课表接口的班级字段
- `lib/home/coursetable/widgets/course_table_widgets.dart`：详情 sheet 增加班级行
- `lib/home/coursetable/view.dart`：复制课程文本增加班级
- `lib/core/services/app_update_service.dart`：为下载提供更新信息（已有版本检测与安装包选择逻辑保持）
- `lib/home/homeview/view.dart`：更新弹窗动作改为应用内下载，顶部横幅展示进度，完成后唤起安装
- `lib/home/about/view.dart`：「检查更新」入口同样走应用内下载
- `android/app/src/main/AndroidManifest.xml`：新增 `REQUEST_INSTALL_PACKAGES` 权限与 FileProvider 声明
- `android/app/src/main/kotlin/com/tune/superhut/MainActivity.kt`：新增安装 APK 的 MethodChannel 方法（含未知来源权限引导）

### 删除

（无）

### 明确不建

- 不引入 flutter_downloader 等第三方下载库（复用现有 Dio）
- 不做断点续传、后台下载服务、通知栏进度
- 不做强制更新、灰度开关
- 课表格子（卡片）内不显示班级，仅详情弹层显示

## Source coverage

不适用：需求来自用户口头描述，尚无文件/链接类需求来源。待用户提供课表接口真实响应样本后，样本作为字段取值的事实证据（实现参考）核对 ktmc 假设，不触发需求来源覆盖模式。

# Non-goals

- iOS 官方商店分发或系统级应用内更新（iOS 无官方 sideload 途径，仅覆盖 TrollStore 渠道的可行做法）
- Windows/macOS/Web 平台的更新下载（现状已排除这些平台）
- 下载断点续传、Wi-Fi 强制校验、定时静默更新
- 教务系统登录、课表同步流程本身的行为变化

# Acceptance examples

- Scenario: 打开带有班级数据的课程详情，详情信息列表出现「班级」条目，内容与教务返回一致，长文本自动换行完整显示，长按可复制。
- Scenario: 打开旧课表数据（无班级字段）的课程详情，班级条目显示回退文案（如「暂无班级信息」），其余信息行不受影响。
- Scenario: 「复制课程信息为文本」的结果包含班级一行。
- Scenario: Android 上更新弹窗点击「下载安装包」后，页面顶部出现下载进度横幅，进度随下载推进；期间可正常切换标签页、使用各功能页面。
- Scenario: Android 下载完成后自动唤起系统安装确认页，用户无需手动查找文件；若未授予「安装未知应用」权限，先引导到系统设置，返回后可继续。
- Scenario: iOS 下载完成后弹出系统分享面板分享安装包文件，可交给 TrollStore 导入安装；取消分享不报错。
- Scenario: 下载中点击横幅取消按钮，下载终止、横幅消失，不残留影响下一次下载的半截文件。
- Scenario: 下载失败时横幅提示失败，可重试或改为打开发布页。
- Scenario: 同一 tag 的安装包已下载成功后再次触发更新，直接复用本地文件，不重复下载。

# Constraints and invariants

- 下载在前台进行但不阻塞 UI；复用现有 Dio，不新增重量级依赖（如需仅允许 FileProvider 相关原生配置，不引入新 Dart 插件时优先原生实现）。
- 分享码 / 导出文件向后兼容：新增字段按字段名序列化，老版本 `Course.fromJson` 读取已知字段自动忽略未知字段；`sanitizedForShare` 继续剥离 `pcid`。
- 版本比较逻辑（pub_semver）、忽略此版本、GitHub Releases 选择安装包的逻辑保持不变。
- Android 8+ 触发安装前检查 `canRequestPackageInstalls`，未授权时引导到系统设置页。
- 下载进度横幅不得遮挡关键操作，交互遵循现有 `_CourseSyncOverlay` 的层级习惯，置于安全区之下。

# Decisions

- D1 班级字段采用普通课表 item 的 `ktmc`（课堂名称，含班级串）；实验课无对应字段时显示回退文案。【用户已确认：采用 ktmc】
- D2 分享码、导出文件、复制文本均包含班级信息（班级串非隐私；新老版本按字段名兼容）。
- D3 首页启动更新弹窗与「我的-关于」检查更新入口统一改为应用内下载；不再先跳浏览器。
- D4 用户主动点击下载时直接开始，不强制 Wi-Fi 检查。
- D5 下载中用户可继续使用应用；切后台导致下载中断属预期，回前台可重试。
- D6 同一 tag 已下载成功的安装包直接复用本地文件。
- D7 Android 安装使用 FileProvider + ACTION_VIEW/ACTION_INSTALL_PACKAGE content URI 方式（开源惯例：flutter_downloader、install_plugin、apk_sideload 均如此），不引入第三方插件，在 MainActivity 原生实现。
- D8 班级过长时完整显示并自动换行（多行，不截断）。【用户已确认】
- D9 iOS 走「下载后分享安装包」：下载完成后弹系统分享面板把安装包交给 TrollStore 导入；不调用 apple-magnifier URL scheme。【用户已确认】

# Open questions

（无未决项；Q1–Q3 均已确认，结论见 Decisions D1/D8/D9。）

# Verification expectations

- `flutter analyze` 通过；`flutter test` 全量通过（含班级字段解析/序列化新测试）。
- 手工真机验收：Android 下载→自动唤起安装全流程；iOS 下载→分享面板交付 TrollStore 流程。
- 手工验收详情 sheet：新数据有班级、旧数据无班级两种表现，复制文本含班级。
