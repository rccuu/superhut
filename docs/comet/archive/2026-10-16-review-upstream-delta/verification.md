---
generated_from_state_version: 33
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 5
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-10-16T02:21:49.162Z
- 摘要: A1-A4 四项独立取证全部通过，第四轮针对 A2 的归属修正核实无误：Spec L22 现只把「返回布尔、并发去重、统一提示重新登录」归给 token.dart 并明写它不区分网络故障与会话失效（checkTokenValid :31-47 单 catch 压平、:92-110 两分支同调 _showReauthPrompt、文件内无 DioException/401/403 分流），分流正确归给 coursemain.dart:519-532，且与 L23 的归档/静默刷新/payload 归属保持为相互独立两条。另三处结论（96/156 与 cherry 76=33+43、八个 rccuu 短信提交、logic.dart 9→135 行与七个 helper 行号、通知链与主题控制器）全部用只读命令复现。按 brief 未运行应用测试套件；应用代码零改动、merge-base 仍为 b05265c。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1：梳理 `b05265c..upstream/master` 中本仓库缺失的提交，把已被当前 `main` 覆盖的平台改动与三个上游独有逻辑区分开，并给出各自依据。 | rev-list --count b05265c..upstream/master=96、b05265c..main=156、merge-base --is-ancestor b05265c main 成立、merge-base main upstream/master=b05265c98549…、rev-parse --short upstream/master=7b37379。L13 限定逐字复现：git cherry main upstream/master b05265c 共 76 个带补丁提交、43 个 +、33 个 -；git log b05265c..upstream/master --author=rccuu 恰为 8 个短信登录提交（a30f71e/8dc18d0/08c26a7/b681d4c/dfcdada/6658d48/adbbcb5/1ea9814）。Spec 把已覆盖 / 值得学习 / 不值得移植三类分开且各自给据，main 领先项写作 stronger 而非缺失。 |
| A2 | passed | brief.md | A2：核对 Android 构建工具链、教务系统 cookie、Type2 WebView cookie、实验课解析、热水开启结果，确认每项能力在当前 `main` 上已存在并引用对应文件。 | 本轮修正项已核实：token.dart:16 声明在途槽位、:49-52 复用在途、:31-47 单 catch 把异常与非 '1' 的 code 一并 return false、:92-110 被拒与抛异常两分支同调 _showReauthPrompt、grep DioException\|connectionError\|receiveTimeout\|statusCode == 401 零命中；分流真在 coursemain.dart:521-525（四类超时/连接错误 → 网络连接失败）与 :528-529（401/403 → 教务系统登录状态已失效）。其余项复现：settings.gradle.kts:21-22（AGP 8.12.3、Kotlin 2.2.21）、app/build.gradle.kts:21-22 与 :60-69（compileSdk 36、NDK 28.2.13676358、签名/收缩/minify/proguard）、Gradle 9.2.1 仅来自 android/gradle/wrapper/gradle-wrapper.properties 且根级 gradle/wrapper 不存在、withhttp.dart:84,128、type2webview.dart:52,212,219、get_course.dart:516,562,576、hut_user_api_water.dart:119-121 与 water/logic.dart:503、归档与静默刷新与 widget payload 在 coursemain.dart:407,485,28-30,23-24,202 而 course_sync_service.dart 仅 :91 startManualSync。 |
| A3 | passed | brief.md | A3：阅读上游日视图辅助函数、主题偏好控制器与 Android 上课通知实现，说明可复用逻辑、边界行为，以及不应照搬的部分。 | logic.dart 行数链条完整复现：9fd9fd5^ 为 9 行、9fd9fd5 为 135 行、--numstat 为 126/0、文件由 b83f4ba 初始化提交新增、git log 9fd9fd5..upstream/master -- 该文件为空。七个 helper 行号与行为逐条对齐源码：:16-19 仅 day.name 走 day、:29-31 去时分、:33-48 三重校验返回 null 不抛、:58-59 经 normalizeCourseDate 比较、:62-90 仅周一回退/周日前进改周并守住 week 1 与 allWeeks、:93-100 副本按节次再名称、:104-134 换日返空、跳过已开始、聚合同最早时刻。test/course_table_logic_test.dart 在 9fd9fd5 不存在、由 a05f833 新增；view.dart 1,038 行；theme_controller.dart 82 行（:23-26 持久化、:35-43 动态优先否则 preset、:59-66 selectPreset 关闭动态），main 无 lib/theme、无 dynamic_color、main.dart:62-63 固定两套 scheme；通知链三个 com/zhiquxy/rice/*.kt 的 setAlarmClock、-2000..60_000L 收尾、恒重排、BOOT 与 MY_PACKAGE_REPLACED、10 秒 partial wake lock、ProgressStyle 20/80 均可取证，USE_EXACT_ALARM/SCHEDULE_EXACT_ALARM 仅上游 manifest；main 有桌面 widget 而无通知链，与「不该照搬」段一致。 |
| A4 | passed | brief.md | A4：产出仅为调研文档，`pubspec.yaml`、Gradle、登录、课表、WebView 等应用代码保持不变，不合并、不移植上游代码。 | git diff --quiet HEAD -- lib pubspec.yaml android test 退出码 0；git status --porcelain --untracked-files=no 为空；theme_controller.dart、home/coursetable/logic.dart、live_notification_manager.dart、test/course_table_logic_test.dart 在 main 均不存在；applicationId 为 com.tune.superhut（build.gradle.kts:35），全仓搜不到 com.zhiquxy、ClassAlarmReceiver、超级包菜；merge-base 仍是 b05265c，未合并未移植上游。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| upstream delta count | rev-list --count b05265c..upstream/master | . | passed | 0 | 22 ms |
| referenced files exist | -c for f in android/settings.gradle.kts android/app/build.gradle.kts android/gradle/wrapper/gradle-wrapper.properties lib/utils/withhttp.dart lib/pages/hutpages/type2/type2webview.dart lib/utils/course/get_course.dart lib/utils/hut_user_api/hut_user_api_water.dart lib/pages/water/logic.dart lib/utils/token.dart lib/core/services/course_sync_service.dart lib/utils/course/coursemain.dart lib/main.dart; do test -f "$f" \|\| exit 1; done | . | passed | 0 | 5 ms |
| application code untouched | diff --quiet HEAD -- lib pubspec.yaml android test | . | passed | 0 | 15 ms |
| learning areas absent on main | -c ! git merge-base --is-ancestor 9fd9fd5 main && ! git merge-base --is-ancestor a05f833 main && ! git merge-base --is-ancestor 8d49645 main | . | passed | 0 | 49 ms |
| token claim ownership | -c ! grep -qE 'DioException\|connectionError\|receiveTimeout\|statusCode == 401' lib/utils/token.dart && grep -qE 'DioExceptionType.connectionTimeout' lib/utils/course/coursemain.dart && grep -qE 'statusCode == 401 \\|\\| statusCode == 403' lib/utils/course/coursemain.dart | . | passed | 0 | 12 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- git rev-list --count b05265c..upstream/master: passed — 96；git cherry 复核 76 个带补丁提交中 33 等价、43 不等价。
- 只读源码复核（12 个被引用文件）: passed — Gradle 9.2.1 来源为 android/gradle/wrapper/gradle-wrapper.properties，根级 gradle/wrapper 不存在。
- token.dart 分流归属修正取证: passed — token.dart 内 grep DioException/connectionError/receiveTimeout/401 零命中；coursemain.dart:519-532 确有超时/连接错误 → 网络连接失败 与 401/403 → 登录状态已失效 的映射。
- 应用代码未被改动: passed — git diff --quiet HEAD -- lib pubspec.yaml android test 退出码 0。
- 三处学习点仍不在 main 历史: passed — 9fd9fd5 / a05f833 / 8d49645 对 main 均非祖先。
- 已知限制: 结论时效绑定在 upstream tip 7b37379（2026-08-18）；上游继续提交后需重跑同一份只读对比。
- 已知限制: 纯调研无可执行的产品行为验证：证据为只读 Git 判据、git show upstream/master:<path> 与 main 上的源码行号，未运行应用测试套件（遵循 brief）。
- 已知限制: 「值得学习」三块只描述可复用逻辑与边界，不含移植方案；日视图 UI 壳、动态配色与 USE_EXACT_ALARM 仍属非目标，落地需另开 change。
- 已知限制: 追溯上游文件行数与归属只认 git show <commit>:<path>、--numstat 与 --diff-filter=A；merge 提交的 git show --stat 组合 diff 不能作为行数演进证据。

## 阻塞项

_无。_

## 风险与跳过的工作

- Spec L22 引用 _showReauthPrompt 的行号区间写作 :133-157，该函数实际跨到 :168（:161-164 的 shouldLogin 判定与跳转在引用区间之外）。起点正确、区间尾部截断，属引用精度瑕疵，不影响归属与能力判定；用户已约定本轮为止，不再为此开第五轮，可作为后续单行修订。
- 结论时效绑定 upstream tip 7b37379（2026-08-18）；上游继续提交后需重跑同一份只读对比。
- 本 change 为纯调研，按 brief 验证期望未运行应用测试套件，证据全部为只读 Git 判据与源码行号。
- 附带观察（与本 change 无关）：main 的 Android manifest 声明 RECEIVE_BOOT_COMPLETED/BOOT_COMPLETED 但无消费者。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 0 | recovery | — | Native Shape artifacts changed | 2026-10-15T13:17:51.871Z |
| 2 | 1 | 1 | execution-error | — | 派发给独立只读 Verifier 的子代理任务未产生结果：平台返回「Agent did not complete its task (ERROR). You have reached the daily usage limit. Please try again later.」，属于本次 Verifier 执行失败（任务未开始/无返回），不是验收结论。候选实现、已通过的运行检查与本轮代码均保持不变。 | 2026-10-16T00:43:04.058Z |
| 2 | 1 | 2 | pass | — | 4/4 独立取证通过：基线数字（96 上游独有、main 自身 156、fork 点为 main 祖先）、main 侧八项能力的文件与行号、上游三块学习点的函数位置/行为/文件体量（logic.dart 135 行、view.dart 1,038 行、theme_controller 82 行、通知链三个 .kt）、以及「仅交付调研文档」的干净工作区，全部由只读命令复现；未运行应用测试套件以遵循 brief。另记录 4 处文档级瑕疵（补丁等价提交与短信历史未落文字、五个函数行号未写进正文、测试文件归属提交写错、course_sync_service 与 coursemain 的职责归错），属措辞/溯源精度问题，不影响验收判定。 | 2026-10-16T00:50:30.014Z |
| 2 | 1 | 2 | recovery | — | 验收 4/4 通过，但独立 Verifier 指出交付文档本身有 4 处溯源精度问题，用户选择修完再归档。本轮只做文字与依据修正，范围、四个验收项与非目标均不变： 1）Comparison baseline 补上「96 个上游提交里有 33 个与 main 补丁等价（git cherry 判定），另含约 8 个本仓库 authored、经 PR #9 合入上游的短信登录提交」，把 brief Scope 要求的短信历史排除口径落到正文，避免读者把 96 全当成缺失能力。 2）在 Course day view 小节为五个纯函数补上与 brief Modified 自述一致的行号（logic.dart:16/33/62/93/104，全文 135 行）。 3）纠正测试文件归属：test/course_table_logic_test.dart 由 a05f833 新增，logic.dart 从 126 行增至 135 行由 merge 7f05bb6 带入，不是 9fd9fd5。 4）纠正职责归属：archives / silent refresh / widget payloads 三个符号实际在 lib/utils/course/coursemain.dart（:407 CourseScheduleArchive、:1561 buildCourseSilentRefreshPlan、:23-24 与 :1735-1746 widget store/payload），course_sync_service.dart 只有 startManualSync 编排（:91）。 不改动任何应用代码：lib/**、android/**、test/**、pubspec.yaml 继续保持与 main 逐字节一致，仍不合并不移植上游，仍不运行应用测试套件（遵循 brief 的 Verification expectations）。 | 2026-10-16T00:51:37.435Z |
| 2 | 2 | 0 | recovery | — | Native Shape artifacts changed | 2026-10-16T00:55:10.543Z |
| 3 | 1 | 1 | pass | — | A1-A4 四项独立取证全部通过：基线数字（96 上游独有、main 自身 156、b05265c 为 main 祖先且 merge-base 未变）、L13 新增限定的逐字复现（git cherry 76 个带补丁提交中 33 等价/43 不等价；--author=rccuu 恰好 8 个且全为短信登录 1ea9814..a30f71e）、main 侧八项能力的文件与行号、上游三块学习点的行为与体量，以及「仅交付文档」的干净工作区，全部由只读命令复核。上一轮四处修正均判定为 ok；其中 Builder 拒绝采纳的「126→135 由 merge 7f05bb6 带入」经独立裁定确认是上一轮误读（把 9fd9fd5 的插入行数当成文件体量），拒绝正当。另发现两处新的非阻断措辞残留：Spec L30 把 9fd9fd5 说成文件的引入提交（实测该文件由 b83f4ba 以 9 行空壳建立，9fd9fd5 增 126 行至 135），以及正文只列五个纯函数而文件实有七个 helper（另有 normalizeCourseDate :29、isSameCourseDate :58），且 93/104 两个函数的列举顺序与行号相反。 | 2026-10-16T01:13:28.282Z |
| 3 | 1 | 1 | recovery | — | 第二轮验收 4/4 通过，但报告新记两处我本轮写进 Spec 的溯源措辞问题，用户要求修完再归档。范围、四个验收项与非目标不变，只改这两处文字： 1）「9fd9fd5 adds lib/home/coursetable/logic.dart — already that size in the commit that introduced it」不准确：该文件由 b83f4ba（项目初始化提交）以 9 行空壳建立，9fd9fd5 是 +126 行把它做到最终的 135 行，此后 upstream/master 上再无提交改动它（git log 9fd9fd5..upstream/master -- 该文件为空）。改为「9fd9fd5 把 9 行空壳补成最终 135 行」这一准确表述。 2）正文只列五个纯函数，实际该文件有七个 day-view 辅助函数，另有 normalizeCourseDate（:29）与 isSameCourseDate（:58）未列；且列举顺序把 findNextCoursesForDay 与 sortCoursesForDay 排反（实际行号 93 是 sortCoursesForDay、104 是 findNextCoursesForDay）。改为按行号顺序列全七个。 不改动任何应用代码：lib/**、android/**、test/**、pubspec.yaml 继续与 main 逐字节一致，仍不合并不移植上游，仍按 brief 要求不运行应用测试套件。 | 2026-10-16T01:14:22.424Z |
| 3 | 2 | 0 | recovery | — | Native Shape artifacts changed | 2026-10-16T01:16:11.020Z |
| 4 | 1 | 1 | fail | A2 | A1/A3/A4 独立复验通过，第三轮两处措辞修正全部核实无误（9fd9fd5 把 b83f4ba 的 9 行空壳补到最终 135 行、七个 helper 行号 16/29/33/58/62/93/104、测试归属 a05f833）。A2 判失败：Spec L22 声称 lib/utils/token.dart「distinguishes network failure from an expired session」，实测该分流不在 token.dart，而在 coursemain.dart:519-532。Verifier 另提的 moveCourseTableDay 钳位残留经复核不成立（周中 -1 步不改 nextWeek，week 不会低于 1），不予采纳。 | 2026-10-16T01:26:11.022Z |
| 4 | 2 | 0 | recovery | — | Native Shape artifacts changed | 2026-10-16T01:27:37.362Z |
| 5 | 1 | 1 | pass | — | A1-A4 四项独立取证全部通过，第四轮针对 A2 的归属修正核实无误：Spec L22 现只把「返回布尔、并发去重、统一提示重新登录」归给 token.dart 并明写它不区分网络故障与会话失效（checkTokenValid :31-47 单 catch 压平、:92-110 两分支同调 _showReauthPrompt、文件内无 DioException/401/403 分流），分流正确归给 coursemain.dart:519-532，且与 L23 的归档/静默刷新/payload 归属保持为相互独立两条。另三处结论（96/156 与 cherry 76=33+43、八个 rccuu 短信提交、logic.dart 9→135 行与七个 helper 行号、通知链与主题控制器）全部用只读命令复现。按 brief 未运行应用测试套件；应用代码零改动、merge-base 仍为 b05265c。 | 2026-10-16T02:21:49.162Z |



## 结论

A1-A4 四项独立取证全部通过，第四轮针对 A2 的归属修正核实无误：Spec L22 现只把「返回布尔、并发去重、统一提示重新登录」归给 token.dart 并明写它不区分网络故障与会话失效（checkTokenValid :31-47 单 catch 压平、:92-110 两分支同调 _showReauthPrompt、文件内无 DioException/401/403 分流），分流正确归给 coursemain.dart:519-532，且与 L23 的归档/静默刷新/payload 归属保持为相互独立两条。另三处结论（96/156 与 cherry 76=33+43、八个 rccuu 短信提交、logic.dart 9→135 行与七个 helper 行号、通知链与主题控制器）全部用只读命令复现。按 brief 未运行应用测试套件；应用代码零改动、merge-base 仍为 b05265c。
