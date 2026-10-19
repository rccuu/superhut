---
generated_from_state_version: 12
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 2
- 验证器尝试次数: 1
- 完成时间: 2026-10-19T00:58:33.142Z
- 摘要: 第二轮独立复核 9/9 通过。班级显示链路（Course.className 模型/解析/序列化、详情 sheet 换行条目、复制文本）与旧数据回退均有实现及通过中的测试支撑；应用内更新链路（Dio 流式下载+进度快照、顶部横幅、取消/失败/重试/发布页、同 tag 复用）状态机自洽，本轮修复点（HomeviewPage 向横幅注入 onOpenRelease 与横幅默认 launchUrl 兜底）已核实到位。flutter analyze 与 flutter test 均通过。A5/A6 真机行为仅代码审查通过，已列入 risks 待真机手工验收。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | Scenario: 打开带有班级数据的课程详情，详情信息列表出现「班级」条目，内容与教务返回一致，长文本自动换行完整显示，长按可复制。 | 代码审查+测试确认：course_table_widgets.dart 详情 sheet 在教师行后新增班级行（Ionicons.school_outline），wrapText: true 使 _CourseDetailRow 用 maxLines: null、overflow: visible、crossAxisAlignment.start 实现多行完整显示不截断；onLongPress 走既有 _copyValue 与其他信息行提示一致；课表格子卡片未加班级。新增 widget 测试（course_detail_sheet_test.dart 'shows class name row and fallback text'）验证班级内容展示，flutter test 整体通过。 |
| A2 | passed | brief.md | Scenario: 打开旧课表数据（无班级字段）的课程详情，班级条目显示回退文案（如「暂无班级信息」），其余信息行不受影响。 | coursemain.dart Course.fromJson 对 className 采用 json['className'] ?? '' 空串回退（默认构造参数同为 ''）；详情 sheet 空值显示「暂无班级信息」；其余信息行未改动。widget 测试断言 find.text('暂无班级信息') findsOneWidget，旧构造 Course（未传 className）渲染无异常。 |
| A3 | passed | brief.md | Scenario: 「复制课程信息为文本」的结果包含班级一行。 | lib/home/coursetable/view.dart _buildCourseCopyText 在「教师」之后插入 '班级：${course.className.isEmpty ? '暂无班级信息' : course.className}'，位于地点行之前，输出含班级行。 |
| A4 | passed | brief.md | Scenario: Android 上更新弹窗点击「下载安装包」后，页面顶部出现下载进度横幅，进度随下载推进；期间可正常切换标签页、使用各功能页面。 | HomeviewPage 在 Stack 顶层 Positioned(top: topInset+10) 挂载 AppUpdateDownloadBanner，位于 IndexedStack 之外、无全屏阻断层，仅横幅内按钮可点，不阻塞页面交互与切标签；下载由 AppUpdateDownloadService 单例执行，dio.downloadUri onReceiveProgress 实时更新 ValueNotifier 进度（百分比+进度条）。横幅测试与下载状态测试均通过。真机上进度推进与切标签流畅度未实测，见 risks。 |
| A5 | passed | brief.md | Scenario: Android 下载完成后自动唤起系统安装确认页，用户无需手动查找文件；若未授予「安装未知应用」权限，先引导到系统设置，返回后可继续。 | 代码审查通过（真机未实测，见 risks）：AndroidManifest 新增 REQUEST_INSTALL_PACKAGES 与 FileProvider（authority com.tune.superhut.updateprovider，@xml/file_paths 的 cache-path superhut_update/ 与 getTemporaryDirectory()/superhut_update 缓存路径一致）。MainActivity installApk：Android 8+ 先查 canRequestPackageInstalls，未授权则跳 ACTION_MANAGE_UNKNOWN_APP_SOURCES 并返回 missing-permission；授权路径经 FileProvider content URI 发 ACTION_VIEW(application/vnd.android.package-archive)+FLAG_GRANT_READ_URI_PERMISSION 唤起系统安装确认页，含 no-installer/failed 等异常分支；Dart 侧 _startPlatformInstall 失败时置 failed 状态可重试。 |
| A6 | passed | brief.md | Scenario: iOS 下载完成后弹出系统分享面板分享安装包文件，可交给 TrollStore 导入安装；取消分享不报错。 | 代码审查通过（真机未实测，见 risks）：_deliverCompletedFile 在 iOS 分支调用 Share.shareXFiles 分享本地安装包（mimeType application/octet-stream，文本注明 TrollStore 导入）；取消分享由 share_plus 正常返回不抛错；分享异常时捕获并置 failed 快照，横幅正常结束不崩溃。 |
| A7 | passed | brief.md | Scenario: 下载中点击横幅取消按钮，下载终止、横幅消失，不残留影响下一次下载的半截文件。 | cancelDownload 取消 CancelToken 并立即置 idle 快照（isVisible=false 横幅消失）；DioException 取消分支同样重置为 idle，不存在取消后横幅残留。半截文件在下一次 startDownload 时先 deleteSync 再下载（lib/core/services/app_update_download_service.dart 第 184-188 行），不会污染下一次下载；测试 'cancelDownload resets to idle and stops visible banner' 通过。注：取消瞬间半截文件仍留在临时目录、延迟到下次下载前清理，但满足验收语义（不影响下一次下载）。 |
| A8 | passed | brief.md | Scenario: 下载失败时横幅提示失败，可重试或改为打开发布页。 | 本轮修复重点已核实：HomeviewPage 第 589-596 行 Positioned 挂载 AppUpdateDownloadBanner(onOpenRelease: widget.openUpdateRelease ?? _launchUpdateRelease)，注入接线到位；banner 侧 _openUpdateRelease 有注入时优先调用注入器，无注入时默认 launchUrl(externalApplication) 兜底，两种路径失败均有错误 SnackBar。失败横幅展示「更新包下载失败」+ 重试（复用 update 重新 startDownload）+ 发布页两个操作。新增 banner 测试覆盖注入与非注入两条路径且通过。 |
| A9 | passed | brief.md | Scenario: 同一 tag 的安装包已下载成功后再次触发更新，直接复用本地文件，不重复下载。 | 下载成功后 _markDownloadedTag 在 SharedPreferences 记录 tag 与文件名；再次 startDownload 时 _resolveReusableFile 命中同 tag 且本地文件存在非空即返回 isReused=true 的 completed 快照并直接交付文件，跳过网络下载；tag 不匹配或文件缺失时正常重新下载。下载中取消不写 tag（_markDownloadedTag 仅在下载成功路径调用），不会误复用半截文件。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze | analyze --no-pub | . | passed | 0 | 2909 ms |
| flutter test | test | . | passed | 0 | 21392 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter analyze: passed — No issues found
- flutter test (full suite): passed — 693 tests passed
- banner wiring tests: passed — app_update_download_banner_test 2 项通过
- 已知限制: Android 真实设备安装确认页/未授权设置跳转需真机验收；编译已通过。
- 已知限制: iOS 分享面板交付需真机/模拟器验证 share_plus；下载链路逻辑已由单测覆盖。

## 阻塞项

_无。_

## 风险与跳过的工作

- A5/A6 及 A4 的真机表现未实测：Android 下载完成后自动唤起系统安装、未授权引导设置的全流程，以及 iOS 分享面板交付 TrollStore，需按 brief 验收期望做真机/实机手工验收
- Android 未授权「安装未知应用」时，跳转设置页后横幅约 4 秒自动消失且不会在返回后自动续装；用户需再次触发下载，走 A9 复用路径即时重试安装（体验上可接受但非自动续接）
- A1 班级超长文本的真实换行观感、A4 真机下载进度推进未在设备上人工核验，仅由代码审查与 widget 测试覆盖
- iOS sharePositionOrigin 使用 Rect.fromLTWH(0,0,1,1)，iPad 上分享popover定位为全屏左上角，功能可用但弹出位置不精致

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | 全部 9 项验收通过代码路径审查。班级链路：Course.className 贯穿模型全链路，普通课表解析 ktmc，详情 sheet 教师行后显示班级（自动换行、空值回退、长按复制），复制文本含班级行，均有测试覆盖。应用内更新：Dio 流式下载+顶部进度横幅（不拦截交互）+取消清理+失败重试+同 tag 复用已实现；Android FileProvider+REQUEST_INSTALL_PACKAGES 自动唤起安装、未授权跳系统设置（代码路径完整）；iOS 下载完分享面板交付 TrollStore。flutter analyze 与 flutter test（691 项）全部通过。真机安装、iOS 分享面板、失败横幅发布页按钮接线为主要遗留风险，需手工验收。 | 2026-10-19T00:38:56.470Z |
| 1 | 1 | 1 | recovery | — | 用户选择修复横幅「发布页」按钮接线：把首页 openUpdateRelease 注入横幅 onOpenRelease，未注入时横幅默认回退 launchUrl 打开 releaseUrl，修复 A8 的小半缺口 | 2026-10-19T00:46:29.683Z |
| 1 | 2 | 1 | pass | — | 第二轮独立复核 9/9 通过。班级显示链路（Course.className 模型/解析/序列化、详情 sheet 换行条目、复制文本）与旧数据回退均有实现及通过中的测试支撑；应用内更新链路（Dio 流式下载+进度快照、顶部横幅、取消/失败/重试/发布页、同 tag 复用）状态机自洽，本轮修复点（HomeviewPage 向横幅注入 onOpenRelease 与横幅默认 launchUrl 兜底）已核实到位。flutter analyze 与 flutter test 均通过。A5/A6 真机行为仅代码审查通过，已列入 risks 待真机手工验收。 | 2026-10-19T00:58:33.142Z |



## 结论

第二轮独立复核 9/9 通过。班级显示链路（Course.className 模型/解析/序列化、详情 sheet 换行条目、复制文本）与旧数据回退均有实现及通过中的测试支撑；应用内更新链路（Dio 流式下载+进度快照、顶部横幅、取消/失败/重试/发布页、同 tag 复用）状态机自洽，本轮修复点（HomeviewPage 向横幅注入 onOpenRelease 与横幅默认 launchUrl 兜底）已核实到位。flutter analyze 与 flutter test 均通过。A5/A6 真机行为仅代码审查通过，已列入 risks 待真机手工验收。
