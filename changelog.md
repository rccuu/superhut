# Changelog

维护约定
- 每次代码提交后，都要同步补充本文件。
- 每条记录至少包含：日期、提交哈希、提交标题、详细修改说明、关键文件、变更统计。
- 记录口径以主线提交为准；如果一次提交覆盖多个模块，要按用户可感知的变化拆开写清楚，不只写一句标题。
- 如果某条记录是在正式 `git commit` 之前先写入仓库，允许先把提交哈希记成 `待提交`；下一次维护本文件时，必须回填成真实哈希。

统计范围
- 起点提交（含）：`a123ed99fda436af7eef7f1ce7ca8f55750b60c5`
- 终点提交（首次整理基线）：`01cb342d499b61c45498159fe9d3143b4e94b584`
- 整理口径：按 `git log --first-parent --reverse a123ed99fda436af7eef7f1ce7ca8f55750b60c5^..01cb342d499b61c45498159fe9d3143b4e94b584` 的主线历史整理，共 14 次主线提交。
- 说明：`a123ed9` 是合并提交，本文记录这次合并落到主线后的结果，不把它带入的更早分支提交 `4bd0ca9` / `54bab78` / `03ba842` 再重复展开；后续新提交按追加记录维护。

## 2026-03-25 · `待提交` · chore(release): prepare v1.4.8
- 作者：rccuu
- 这次发版不再继续沿着上一轮那种更激进的课表自定义吸附方案往前推，而是收口回“更接近系统原生分页，但把真正影响手感的触发条件继续打磨顺手”的方向。目标很明确：优先把课表左右切周做得自然、稳、可预期，而不是为了更早翻页引入新的顿挫和反向抽动。
- `lib/home/coursetable/view.dart` 里，顶部周标题和日期范围的刷新从整页 `setState` 拆成 `ValueNotifier<int> + ValueListenableBuilder<int>`，切周时只更新周信息本身，不再把整页课表内容一起重建。这样做主要是为了减少翻页落点附近那一下不必要的整页刷新，把“快到下一页时那一下明显顿一下”的感觉继续往下压。
- 课表分页容器本身继续保留 `PageView.builder` 的连续周序列实现，但这次更明确地把交互细节收成更顺手的一组组合：`dragStartBehavior: DragStartBehavior.down` 让手指一落下就尽快接管横向拖动，`allowImplicitScrolling: true` 让相邻周更早参与布局预热，而 `_CourseTablePagingPhysics` 则只保留轻量调参，不再强行接管整套吸附行为。
- 这组物理参数当前的收口结果是：`minFlingDistance = 8.0`、`minFlingVelocity = 20.0`、`dragStartDistanceMotionThreshold = 1.5`。也就是说，保留系统原生分页吸附的同时，把短距离快速甩动的识别门槛继续下调，让用户在真正完成横向手势接管之后，不必再靠特别大的位移才能翻到下一周。
- 为了防止后续继续在“感觉更丝滑”和“实际更稳”之间来回摆动，`test/home/coursetable/course_table_swipe_test.dart` 这次补齐了几类关键回归：立即起拖与相邻周预构建、短距离高速甩动翻页，以及在越过 touch slop 后较低速度 fling 仍能被识别。这样至少能把这次明确确认保留的手感参数固定下来，避免后续再悄悄退回更钝的状态。
- 本次提交同时把版本号提升到 `1.4.8+1`，用于对应这一轮课表横滑手感打磨后的正式发版整理。
- 关键文件：`pubspec.yaml`、`changelog.md`、`lib/home/coursetable/view.dart`、`test/home/coursetable/course_table_swipe_test.dart`
- 代码统计：4 files changed, 150 insertions(+), 25 deletions(-)

## 2026-03-24 · `17c95a7` · chore(release): prepare v1.4.7
- 作者：rccuu
- 这次发版是在 `v1.4.5` 这个最后一个可验证正式 tag 之后，继续把已经进入主线但尚未对外打 tag 的 `v1.4.6` 收口，以及刚完成的课表连续分页优化，一起整理成新的 `1.4.7` 发布包。也就是说，这次对外公告的口径不是只看当前工作区，而是明确覆盖 `v1.4.5..当前版本` 这一段真实进入版本的变化。
- 延续 `831bd0a` 那轮 UI 减重与玻璃层级收口，本次版本继续保留更轻的全局视觉基底：课表、空教室、成绩页、首页、功能页、我的页和统一登录页都已经收敛到更克制的 `soft` 背景和更明确的面板层级，这部分虽然已经在主线里，但直到这次才和新的交互优化一起进入新的正式版本口径。
- 本轮真正新增、也是用户直接推动的改动，集中在 `lib/home/coursetable/view.dart` 的课表切周体验。原先实现是“三页循环 + 中页重置”，用户慢慢拖动跨过半页时会被程序直接 `jumpToPage(1)` 抢走控制权，看起来像页面突然脱手。现在改成按周连续分页：`PageView.builder` 直接渲染完整周序列，慢拖时相邻周内容会像纸张一样持续随手势进入视口，快速甩动时则保留系统原生分页物理，自然落到上一周或下一周。
- 课表页这次不只是把分页容器换掉，还顺手统一了周状态同步模型。初始化、切换课表、回到本周和手势切周现在都共用同一套目标周同步逻辑，避免页码、周标题和顶部日期范围出现不同步。对应地，`test/home/coursetable/course_table_swipe_test.dart` 也补了新的慢拖回归测试，专门验证“手指还按着时 pager 仍停留在分数页位置，不会被程序强行吸回整页”。
- 工程维护侧补了一个很小但实际有用的收尾：`.gitignore` 新增 `.serena`，避免本地语义分析缓存继续污染工作区。这个改动不会影响用户功能，但能减少后续发版和 review 时的噪音。
- 本次提交同时把版本号提升到 `1.4.7+1`，并重新生成 iOS unsigned IPA，方便直接进入后续签名或分发流程。
- 关键文件：`pubspec.yaml`、`changelog.md`、`lib/home/coursetable/view.dart`、`test/home/coursetable/course_table_swipe_test.dart`、`.gitignore`
- 代码统计（待提交时回填）：5 files changed, version bump + release notes update + smoother course table paging + regression test + local ignore cleanup

## 2026-03-24 · `831bd0a` · chore(release): prepare v1.4.6
- 作者：rccuu
- 这次发版整理不是继续扩需求，而是把当前工作区里已经确认保留的一轮 UI 减重与交互收口正式整理成 `1.4.6`。总体方向很明确：尽量保留现有玻璃主题的质感，但降低 blur、阴影和过度透明带来的性能与廉价感问题，重点覆盖空教室、课表、成绩页和几个高频入口页。
- `lib/core/ui/apple_glass.dart` 新增 `AppGlassBackgroundStyle` / `GlassPanelStyle` 两套分层枚举，把背景拆成 `rich / soft / flat`，把面板拆成 `hero / floating / card / list / solid`。这样一来，不同页面和不同密度的组件都可以按场景选更轻的材质，而不是继续让整页所有卡片都走同一种重玻璃参数。
- 课表和空教室是这轮最核心的用户路径。`lib/home/coursetable/view.dart`、`lib/home/coursetable/widgets/course_table_widgets.dart` 统一了底部弹层的 route background / barrier 策略，课程详情与实验名单弹层改成更稳定的分段式卡片结构，顺手修掉点击课程后详情层后方背景缺失的问题；`lib/pages/freeroom/room.dart` 则保留性能向优化，用 `SliverChildBuilderDelegate` 和预计算 `_RoomGridItem` 降低网格滚动开销，同时把具体教室空闲状态弹层改成更实的双卡片结构，提升可读性但不再让外层托举区域变成生硬的纯白块。
- 其余页面这次主要做统一收口而不是再发散新样式。`lib/pages/freeroom/building.dart`、`lib/pages/score/scorepage.dart`、`lib/pages/score/jump_to_score_page.dart`，以及首页 / 功能页 / 关于页 / 个人页 / 统一登录页，都切到更轻的 `soft` 背景和明确的卡片层级，顺手削弱了一批过重阴影，让整体主题仍保持同一套玻璃语言，但滚动和阅读都更干净。
- 这次提交同时把版本号提升到 `1.4.6+1`，并把这一轮确认保留的 UI 减重与交互收口整理成可发布的正式变更说明。
- 关键文件：`lib/core/ui/apple_glass.dart`、`lib/home/coursetable/view.dart`、`lib/home/coursetable/widgets/course_table_widgets.dart`、`lib/pages/freeroom/room.dart`、`lib/pages/score/scorepage.dart`、`pubspec.yaml`、`changelog.md`
- 代码统计：14 files changed, 809 insertions(+), 422 deletions(-)

## 2026-03-23 · `38bf9ef` · chore(release): prepare v1.4.5
- 作者：rccuu
- 这次发版准备把应用版本从 `1.4.2+1` 提升到 `1.4.5+1`，并把 `v1.4.2` 之后已经进入主线的 UI 与 Android 高刷改动整理成一份可直接用于发布说明的摘要。
- 需要特别说明的是：仓库里当前没有可验证的 `v1.4.3` Git tag，本次发布摘要因此按最后一个可验证正式基线 `v1.4.2` 到当前主线 `b6c9f2b` 的实际提交来整理，不把不存在的 tag 当作差异基线。
- 从代码层面看，`357f96d` 先补了一轮全局深色模式细节修正，覆盖登录、评教、考试安排、慧生活 798、宿舍热水和 HUT WebView 等页面；`b7dd274` 继续重做成绩查询、空教室查询和宿舍热水三条高频路径，重点是压缩留白、提高信息密度、统一玻璃材质与深浅色表现；`b6c9f2b` 则把 Android 高刷新率适配落到了原生入口，策略是优先 120Hz，没有 120Hz 就回退到设备支持的最高高刷档。
- 这次提交本身只负责发版元数据和说明整理，不引入新的功能逻辑；真正进入安装包的功能改动以上述三次主线提交为准。
- 关键文件：`pubspec.yaml`、`changelog.md`
- 代码统计：2 files changed, version bump + release notes update

## 2026-03-23 · `b6c9f2b` · feat(android): prefer high refresh rate on supported devices
- 作者：rccuu
- 这次提交只做一件事：把 Android 端的高刷新率请求补到原生入口里，目标不是激进追 144/165Hz，而是按照前面确认的策略，优先请求 120Hz；如果设备没有 120Hz，再回退到设备支持的最高高刷档。这样既贴近用户实际感知，也避免为了少数面板规格把逻辑写得过于激进。
- `android/app/src/main/kotlin/com/tune/superhut/MainActivity.kt` 不再是空的 `FlutterActivity()` 壳，而是开始在 `onCreate` 和 `onResume` 两个时机都执行高刷偏好设置。这样做的原因是 Android 上窗口属性在前后台切换、系统回收恢复、厂商 ROM 介入时都有可能被重置，只在创建时设一次不够稳。
- 这轮实现不只是简单写一个 `preferredRefreshRate = 120f`。Android 23+ 设备上，代码会先读取当前显示模式和 `supportedModes`，优先从“和当前分辨率一致”的模式里挑选最合适的高刷档，再把 `preferredDisplayModeId` 和 `preferredRefreshRate` 一起写回窗口属性。这样可以减少系统为了追高刷顺手切分辨率的概率，也更接近社区里 `flutter_displaymode` 这类成熟方案的实现思路。
- 具体策略上，代码会先找 `>60Hz 且 <=120Hz` 的最高刷新率；如果设备没有这一档，比如只给 90Hz，那就落 90Hz；如果设备是更少见的 144Hz/165Hz 且没有 120Hz，同分辨率模式选择会回退到设备可用的最高高刷档。对不支持高刷的设备，逻辑会直接 no-op，不会影响现有行为。
- 兼容性方面也做了分层处理。Android 30+ 直接用 `display`，老版本则回退到 `windowManager.defaultDisplay`；Android 23 以下没有 `supportedModes`，只保留对 `display.refreshRate` 的安全判断。也就是说，这次改动不会强行把旧版本设备拖进一套它根本不支持的 API。
- 需要明确的是，这次实现的是“向系统表达高刷偏好”，不是“强制锁定 120Hz”。最终实际刷新率仍然可能被系统的省电策略、发热控制、厂商游戏模式/省电模式、用户手动的刷新率设置覆盖。这一点符合 Android 官方文档对 `preferredRefreshRate` / 显示模式偏好的定义。
- 这次提交前还专门做了构建级验证：`flutter analyze lib` 已通过，`flutter build apk --debug --target-platform android-arm64` 也成功出包，说明 Kotlin 改动至少在当前 Flutter/Gradle 构建链路下是成立的。
- 关键文件：`android/app/src/main/kotlin/com/tune/superhut/MainActivity.kt`
- 代码统计（不含 `changelog.md`）：1 file changed, 108 insertions(+), 1 deletion(-)

## 2026-03-22 · `b7dd274` · feat(ui): refine score, free room and hot water experience
- 作者：rccuu
- 这次提交是一轮覆盖“空教室查询”“成绩查询”“宿舍热水”三条高频路径的集中 UI 收口，不是简单换色，而是把前面多轮反复确认过的布局压缩、深浅色修正、交互取舍和视觉统一一次性落进仓库。整体方向很明确：减少无效留白、提高信息获取效率、让新旧页面的主题语言真正统一。
- 空教室部分重点改的是“空间浪费”和“列表节奏”。`lib/pages/freeroom/building.dart` 重新整理了校区与教学楼之间的距离、顶部标题区与分组区的关系、教学楼名和状态胶囊的字号与对齐标准，最终收成“最长教学楼名称也能稳定一行”的统一字号，并把 `xx间`、`空闲xx间` 做成更圆润的小胶囊，避免信息既散又丑。`lib/pages/freeroom/room.dart` 则继续压缩楼内页顶部和列表空白，把卡片收得更紧，尽量在一屏展示更多教室，同时顺手修掉多处 `BOTTOM OVERFLOWED BY 6.0 PIXELS`。
- 这次空教室还一起重做了时间筛选表达。原来按小节显示的信息被改成更符合校内使用习惯的“大节”表达，一天只保留 5 大节，并尽量按当前日期和当前上课时段帮助用户默认落到更实用的查询结果；顶部筛选区里一些本来用户自己已经明确选过的信息也被移除，避免再重复占空间。
- 成绩查询部分核心是把“花里胡哨”收回到“快速看清楚”。`lib/pages/score/scorepage.dart` 和 `lib/pages/score/jump_to_score_page.dart` 把成绩卡片默认展示的信息压到最关键的三项：课程类型、绩点、学分；详细内容改成点开后再看，默认态不再塞过多说明。顶部摘要区也删掉了“已汇总全部历史成绩”“展示的学期”“已修总学分”“总学分绩点”等会分散视线的内容，只保留更有判断价值的平均绩点。
- 成绩页这轮还继续处理了信息密度和主题一致性。课程卡片的高度被进一步压缩，课程名称字号放大，让用户扫一眼就能快速定位课程；右上角学期选择入口保留原有交互位置，但外观被收成和主界面一致的主题样式，不再像独立拼进去的旧控件。
- 宿舍热水部分是一次比较完整的视觉重做。`lib/pages/water/view.dart` 与 `lib/pages/water/widgets/water_page_widgets.dart` 基于“Golden Powder Family”那套偏金粉、暖粉、少女粉的色相，把页面背景、顶部状态卡、当前设备卡、开始按钮、返回按钮、底部弹层统一进同一套粉色玻璃语言。重点不是堆更重的装饰，而是让每一块都更暖、更软、更精致，同时不牺牲可读性。
- 开始按钮这次被收成单层外圆的“果冻感”主按钮，去掉了多余的播放图标和内部多层圆环，文案也回到更兼容多设备的系统字体系，并把颜色收成更稳的深玫瑰棕，避免白字在粉底上发灰、发飘。准备态/进行态顶部卡片与“当前设备”卡片则补了更明确的边框、高光和轻阴影，让它们从背景里浮出来，但又不会厚重得像另一套风格。
- 热水页这轮还修了几个明显穿帮点。`当前设备` 卡片去掉了偏黑的底色，改成更纯的粉白到浅粉渐变；设备选择、设备管理和新增设备三个底部弹层统一成 28 圆角，并把 `modal_bottom_sheet` 默认黑色阴影替换成粉调阴影，解决了“选择设备”边缘露黑的问题。这样热水页里从主界面到弹层，终于不再有那种半旧半新的割裂感。
- 关键文件：`lib/pages/freeroom/building.dart`、`lib/pages/freeroom/room.dart`、`lib/pages/score/scorepage.dart`、`lib/pages/score/jump_to_score_page.dart`、`lib/pages/water/view.dart`、`lib/pages/water/widgets/water_page_widgets.dart`
- 代码统计（不含 `changelog.md`）：6 files changed, 4938 insertions(+), 1127 deletions(-)

## 2026-03-22 · `919f042` · chore(release): prepare v1.4.2
- 作者：rccuu
- 这是 `v1.4.2` 的发布准备提交，内容不是再去扩首页主结构，而是把这两天一直在反复打磨的底栏体验真正收口：一方面把版本号从 `1.4.0+1` 提升到 `1.4.2+1`，另一方面把底栏的点击热区、外圈阴影和视觉层次按最终确认的方向稳定下来。
- 这次收尾的核心不是“再加一层更重的卡片效果”，而是明确把阴影限制在底栏边框外面。普通 `boxShadow` 对半透明玻璃胶囊会把中间也一起压暗，看起来像阴影跑进了选项框内部；为了解决这个问题，`lib/home/homeview/view.dart` 新增了 `_OuterOnlyShadowPainter` 和 `_OuterShadowLayer`，改成先画黑色模糊阴影，再把胶囊本体区域挖空，最后只留下外圈那一层更像真实投影的 halo。
- 为了让这种“只保留外圈阴影”的做法能精确落到底栏，而不影响其他玻璃卡片，`lib/core/ui/apple_glass.dart` 里的 `GlassPanel` 新增了可选 `boxShadow` 参数。首页底栏实例显式传入 `boxShadow: const []`，关闭组件默认阴影，让真正的阴影只来自外面那层自定义 painter；其他继续复用 `GlassPanel` 的页面则保持原先默认行为，不会被这次一起改坏。
- 底栏交互本身这次也一起定稿。`lib/home/homeview/view.dart` 保留 `GNav/GButton` 的视觉内容，但在其上覆盖三等分的透明点击层，每一段都能直接切到对应 tab，不再要求用户必须精确点中图标或文字。与此同时，热区相关的 widget 测试也同步更新成点击 `home-hit-zone-*`，并额外验证“点左侧热区能切回课表页”，保证后续不会回退成只能点中图标的小热区。
- 这轮阴影参数最后又收了两次，目标是让底部投影更像正前方打光下沿着胶囊边缘落下的一圈黑色阴影，而不是在底部散成一大片脏灰。最终保留的是更贴边、扩散更小、下沉更浅的双层外圈阴影。
- 关键文件：`pubspec.yaml`、`lib/core/ui/apple_glass.dart`、`lib/home/homeview/view.dart`、`test/widget_test.dart`
- 代码统计（当前工作区，含版本与测试更新，不含本次提交哈希回填）：5 files changed, 235 insertions(+), 50 deletions(-)

## 2026-03-22 · `a82bed5` · refactor(ui): polish floating tab bar and transparent bottom safe area
- 作者：rccuu
- 这次提交继续收尾首页底栏体验，重点不是再加一层“尾巴”，而是把底栏下方的安全区透明区真正打通，同时把底栏样式换成更简洁、更稳的胶囊导航实现。
- `lib/home/homeview/view.dart` 里原先自绘的 `Ionicons` 底栏被替换成 `_ClassicTabBar + GNav/GButton`。底栏仍然保留悬浮胶囊形态，但交互改成更窄、更扁的主题色图标和文字切换；同时 `Scaffold.bottomNavigationBar` 改成 `Stack + Positioned(bottom: dockBottom)` 精确贴底布局，修正之前容易漂到中间、点按区域异常的布局问题。
- 这次真正处理的是“底栏下方的安全区透明区”。首页 `Scaffold` 保持 `extendBody: true` 且背景透明，功能页、课表页、我的页统一 `SafeArea(bottom: false)`，不再额外补一层独立的底部背景层；这样滚动内容可以自然延伸到底栏下面，而不是在胶囊下方再出现一段割裂的白底或尾巴。
- `lib/core/ui/apple_glass.dart` 的 `AppGlassBackground` 新增 `bottomHighlightOpacity`、`lightBottomColor`、`darkBottomColor`，让页面可以单独压掉底部提亮并微调底色。功能页、课表页、我的页都把底部高亮关闭，功能页和我的页还把底部滚动 padding 从 `120` 收到 `88`，避免透明安全区打通后仍然空出一大截。
- 这轮改动还顺手把首页底栏测试补齐。`test/widget_test.dart` 不再依赖旧 `Ionicons` 查找，而是新增对新底栏 key、手机尺寸下的底栏实际位置，以及从“功能”切到“我的”页的行为验证，避免后续再回归到底栏跑偏或点了不切页的问题。
- 关键文件：`lib/home/homeview/view.dart`、`lib/core/ui/apple_glass.dart`、`lib/home/Functionpage/view.dart`、`lib/home/userpage/view.dart`、`lib/home/coursetable/view.dart`
- 代码统计（不含 `changelog.md`）：6 files changed, 187 insertions(+), 157 deletions(-)

## 2026-03-19 · `0f4e776` · 初次
- 作者：Tune
- 这是一次大体量基础重构，覆盖登录、课表、喝水/洗澡、评教、电费、空教室、成绩、网络层和测试体系，基本相当于做了一轮全仓整理。
- 新增 `lib/core/services/app_auth_storage.dart` 和 `lib/core/services/app_logger.dart`，把 JWXT/HUT 的会话、账号和密码读写集中管理，并把密码迁移到 `flutter_secure_storage`，保留 SharedPreferences 回退逻辑。
- 把多个历史 CamelCase 文件迁移到 snake_case 命名，旧文件被删除或重命名，例如 `getCoursePage.dart` → `get_course_page.dart`、`getCourse.dart` → `get_course.dart`，评教、电费、空教室、HUT 页面、成绩跳转等模块也一起规范命名。
- 课表、喝水、洗澡页面被大幅拆分组件：新增 `course_table_widgets.dart`、`drink_page_widgets.dart`、`water_page_widgets.dart`，原先塞在单文件里的 UI 和交互逻辑被抽离出来。
- `lib/utils/hut_user_api.dart` 被拆成 `hut_user_api_auth.dart`、`hut_user_api_portal.dart`、`hut_user_api_session.dart`、`hut_user_api_support.dart`、`hut_user_api_water.dart` 多个 mixin 文件，HUT 相关接口不再集中堆在单文件里。
- 登录链路整体重做：`hut_login_system.dart`、CAS 登录页、统一登录页、网页登录页、`main.dart` 启动流程、token 处理页都同步改造。
- 课程同步和本地课表缓存逻辑迁到新的 `get_course.dart` / `coursemain.dart`，同时把桌面小组件刷新也纳入统一处理。
- 依赖层面引入 `flutter_secure_storage`，并把 `flutter_launcher_icons`、`change_app_package_name` 调整到开发依赖侧。
- 补了大批测试和 mock：认证存储测试、登录系统测试、课表同步测试、`WidgetRefreshService` 测试、`path_provider`/secure storage mock 支撑文件。
- 还新增了 `docs/optimization_plan.md`、`docs/optimization_summary.md` 两份调优记录文档。
- 关键文件：`lib/core/services/app_auth_storage.dart`、`lib/home/coursetable/view.dart`、`lib/utils/hut_user_api.dart`、`lib/utils/course/get_course.dart`、`test/core/services/app_auth_storage_test.dart`
- 统计：88 files changed, 7841 insertions(+), 5731 deletions(-)

## 2026-03-19 · `68c9f89` · 修复一些问题
- 作者：Tune
- 这次提交集中做稳定性修复，重点是教务自动登录、空教室/成绩/考试安排的数据容错和 HTTP 错误处理。
- `webview_login_screen.dart` 改成只处理一次登录结果，新增自动登录超时后的手动登录兜底文案，同时把原来只拦截 XHR 的逻辑扩展到 `fetch`，避免教务前端换实现后拿不到 token。
- 统一登录 WebView 增加顶部状态卡片和关闭按钮，自动登录超时后不再直接失败退出，而是提示用户在页面上手动完成登录。
- 电费页开始捕获校园卡余额和寝室信息加载异常，并把错误消息显式渲染到页面上，而不是直接崩掉或静默失败。
- 考试安排页改用更明确的数据结构和错误消息展示，既能显示“当前学期没有考试安排”，也能显示真正的接口异常。
- 空教室查询相关的 `roomapi.dart` 开始校验教务接口返回码、确保先取到当前学期、对教学楼/教室数据做 map 级容错解析，避免响应结构变化时出现空指针。
- `hut_user_api_session.dart` 里对 `openid` 和 `JSESSIONID` 的提取逻辑重写，拿不到关键字段时直接抛出可读错误，而不是返回空数组让上层继续误跑。
- `withhttp.dart` 增加 `mapFromResponseData`、`responseMessageOf`、`buildJwxtStateError` 等工具，并改成按请求构造独立 Dio，减少全局 header/timeout 被串改的风险。
- 成绩页与成绩逻辑层一起改造，统一错误状态、空状态和渲染入口，减少学期切换时的状态错乱。
- 关键文件：`lib/login/webview_login_screen.dart`、`lib/pages/Electricitybill/electricity_page.dart`、`lib/pages/ExamSchedule/exam_schedule_page.dart`、`lib/utils/roomapi.dart`、`lib/utils/withhttp.dart`
- 统计：18 files changed, 1531 insertions(+), 828 deletions(-)

## 2026-03-20 · `c18951c` · refactor: 精简首页/功能页/个人页，重做课表页并调整启动流程
- 作者：Tune
- 这次提交把首页主流程从“首次打开走欢迎页”改成“有会话直接进首页，无会话进统一登录页”，应用真正进入基于登录态判断的启动方式。
- `main.dart` 放弃 `FlexColorScheme`，改成手写的 Material 3 主题：品牌色、卡片、输入框、按钮、对话框、BottomSheet、文本层级全部重新定义，后续 UI 重构都建立在这套主题上。
- 功能页从一长串卡片改成双列功能网格，功能项被抽象成 `_FunctionFeature`，加载中的交互也统一成卡片内部的状态切换。
- 个人页重做成统计卡片 + 动作面板 + 危险操作区的结构，退出登录入口、刷新课表入口和个人信息展示逻辑都被收拢。
- 课表页开始支持“显示/隐藏实验课”开关，并把星期头、当前周状态、今日高亮等展示逻辑统一整理了一遍。
- `coursemain.dart` 新增实验课原始快照落盘能力，把实验课接口原始响应保存成 JSON，方便后续排查课表异常。
- `roomapi.dart` 给教学楼列表加了优先级排序，河西/公共教学楼会优先出现，减少空教室查询时的选择成本。
- 测试同步调整：启动测试不再检查 onboarding，而是检查无会话时直接落到登录页；同时新增实验课原始快照测试。
- 关键文件：`lib/main.dart`、`lib/home/Functionpage/view.dart`、`lib/home/userpage/view.dart`、`lib/home/coursetable/view.dart`、`lib/utils/course/coursemain.dart`
- 统计：11 files changed, 1364 insertions(+), 955 deletions(-)

## 2026-03-20 · `6302b14` · refactor(app): 重做课表页并统一 Glass UI，切换包名为 com.tune.superhut
- 作者：Tune
- 这次提交一边做包名切换，一边正式引入整套 Glass UI 视觉层，属于品牌和界面体系双重重构。
- Android `namespace` / `applicationId` 以及 iOS `PRODUCT_BUNDLE_IDENTIFIER` 全部改成 `com.tune.superhut`，Java/Kotlin 的桌面小组件 Provider/Service 类也一起迁移到新包路径。
- 新增 `lib/core/ui/apple_glass.dart`，提供 `AppGlassBackground`、`GlassPanel`、`GlassIconBadge`、`GlassHairlineDivider` 等基础组件，后续多个页面都开始复用它们。
- 课表页被重写成自定义 7 天 × 10 节的网格布局：有时间轴、日期头、重叠课程布局算法、课程块颜色调色板、详情弹窗复制文本等一整套新的实现。
- `main.dart` 再次细化主题色和表面层级，打开 `ThemeMode.system`，并把 Android/iOS/macOS 页面切换统一成更接近 Cupertino 的转场。
- 功能页、首页、个人页和统一登录页同时往 Glass 风格靠拢，形成统一的毛玻璃卡片与渐变背景语言。
- 关键文件：`android/app/build.gradle.kts`、`android/app/src/main/AndroidManifest.xml`、`ios/Runner.xcodeproj/project.pbxproj`、`lib/core/ui/apple_glass.dart`、`lib/home/coursetable/view.dart`
- 统计：15 files changed, 2382 insertions(+), 987 deletions(-)

## 2026-03-20 · `df2ef44` · feat: rebrand app to 工大盒子
- 作者：Tune
- 这是一次正式的品牌切换提交，把应用对外名称从旧品牌统一切到“工大盒子”。
- Android `app_name`、iOS `CFBundleDisplayName`、Web `manifest.json`、README、应用图标、启动图标、资源图全部换成“工大盒子”品牌内容。
- 新增 `lib/core/services/app_update_service.dart`，通过 GitHub Releases Atom feed 拉取版本信息，并用 `pub_semver` 解析版本号，给应用内检查更新打基础。
- `lib/home/about/view.dart` 被完全重写，去掉之前的彩蛋/传感器交互，改成版本信息、更新检查、fork 仓库 / 上游仓库入口和开发者说明。
- 旧的 `lib/login/login_page.dart` 和 `lib/welcomepage/view.dart` 被彻底删除，说明统一登录页已经成为唯一的主登录入口。
- 版本号提升到 `1.3.0+1`；依赖上移除了 `introduction_screen`，新增 `pub_semver`。
- 同时更新了桌面/Web/macOS/Windows 的图标与窗口标题，让各个平台的外观都跟新品牌保持一致。
- 关键文件：`lib/core/services/app_update_service.dart`、`lib/home/about/view.dart`、`android/app/src/main/res/values/strings.xml`、`ios/Runner/Info.plist`、`web/manifest.json`
- 统计：130 files changed, 811 insertions(+), 1317 deletions(-)

## 2026-03-20 · `a21e025` · feat: improve score and free room browsing
- 作者：Tune
- 这次提交主要优化“成绩查询”和“空教室查询”两条用户路径，同时顺手精简了 README。
- README 里补充说明：仓库名和 Dart 包名仍然保留 `superhut`，但对外显示名称已经是“工大盒子”；同时新增 GitHub Releases 相关说明。
- 教学楼页按 `河西校区`、`河东校区`、`其他` 分组展示，并对建筑名称做压缩处理，避免重复出现“河西校区公共教学楼”这类过长前缀。
- 空教室页从长列表改成三列卡片网格，教室名会去掉“多媒体教室”“教室”等冗余字样，点进后用底部弹层展示座位数和各节次占用情况。
- 成绩页开始缓存各学期请求结果，并过滤掉没有成绩的学期；学期为空时也会给出更明确的空状态文案。
- 关键文件：`lib/pages/freeroom/building.dart`、`lib/pages/freeroom/room.dart`、`lib/pages/score/scorepage.dart`、`README.md`
- 统计：4 files changed, 381 insertions(+), 333 deletions(-)

## 2026-03-20 · `76fb510` · fix: improve dark mode and restore iOS course sync
- 作者：rccuu
- 这次提交同时修两类问题：一类是深色模式下的硬编码颜色，另一类是 iOS/macOS 课表本地持久化导致的同步失效。
- `pubspec.yaml` 增加 `dependency_overrides`，把 `path_provider_foundation` 固定到 `2.5.1`，注释里明确说明是为了绕过新版直接 FFI native assets 在当前模拟器工具链上造成的课表持久化异常；对应 lockfile 和插件注册文件也一起更新。
- 成绩页改成先拉“全部成绩”，再后台异步探测哪些学期真的有数据，配合本地 cache 避免每次切学期都重复请求。
- 电费页、喝水页部件、成绩页摘要卡片统一移除硬编码的黑/灰/蓝色，改成使用 `colorScheme`，让深色模式下的文本和按钮颜色正确跟主题同步。
- 功能页里“宿舍喝水”的入口名称被改成“慧生活798”。
- README 删除内嵌的法律文档区块，仓库内的 `assets/PrivacyAgreement.md`、`assets/UserAgreement.md` 也随之删掉。
- 关键文件：`pubspec.yaml`、`lib/pages/score/scorepage.dart`、`lib/pages/Electricitybill/electricity_page.dart`、`lib/pages/drink/view/widgets/drink_page_widgets.dart`
- 统计：12 files changed, 152 insertions(+), 242 deletions(-)

## 2026-03-21 · `8c83a1c` · feat: refine hui798 drink experience
- 作者：rccuu
- 这次提交集中重做“慧生活798”体验，重点是扫码能力、登录流程和喝水设备页状态管理。
- iOS 侧显式把最低系统版本设到 13.0，在 Podfile 的 `post_install` 里打开 `PERMISSION_CAMERA=1`，并在 `Info.plist` 增加 `NSCameraUsageDescription`，为扫码绑定饮水设备做权限准备。
- `lib/pages/drink/login/view.dart` 和 `loginpart2.dart` 被整体重写，引入新的 `lib/pages/drink/login/widgets/login_widgets.dart`，把手机号输入、图形验证码、短信验证码、发送按钮、加载状态、验证码刷新等交互全部做成一致的登录壳层。
- 登录流程开始支持“发送验证码中”“提交中”状态，短信验证码页也补了“重新获取验证码”“未收到短信可返回上一页”等提示。
- `lib/pages/drink/view/state.dart` 新增 `isLoading` / `isRefreshing`，`logic.dart` 则把设备列表刷新改成带 loading/error 处理，并在刷新后尽量保留用户原先选中的设备。
- 当设备列表接口返回账户失效时，逻辑层会主动清空状态并跳回登录页；网络失败时会弹出底部错误提示而不是静默不更新。
- 关键文件：`ios/Podfile`、`ios/Runner/Info.plist`、`lib/pages/drink/login/view.dart`、`lib/pages/drink/login/loginpart2.dart`、`lib/pages/drink/view/logic.dart`
- 统计：13 files changed, 1780 insertions(+), 855 deletions(-)

## 2026-03-21 · `a6d1157` · chore: ignore local editor settings
- 作者：rccuu
- 这是一次仓库清洁提交，把用户本地 IDE 配置从版本控制中移走。
- `.gitignore` 调整为忽略本地编辑器配置，同时删除已被跟踪的 `.vscode/settings.json`，避免每个人的本地设置继续污染提交记录。
- 影响文件：`.gitignore`、`.vscode/settings.json`
- 统计：2 files changed, 1 insertion(+), 4 deletions(-)

## 2026-03-21 · `6b9975f` · feat: add guest mode and manual course sync
- 作者：rccuu
- 这次提交引入了“游客模式”，把应用从“强制先登录才能进”改成“可以先逛、需要校园能力时再登录”。
- `AppAuthStorage` 新增 `hasAnyCampusSession()` 和 `hasLinkedCampusAccount()`，把“有 token 会话”和“账号是否已经绑定过”区分开，供启动页、个人页、课表页分别判断。
- 统一登录页增加 `暂不登录` / `先逛功能` 按钮；登录成功后也不再强制跳课表同步页，而是回到首页。
- `main.dart` 的启动逻辑调整为：如果有校园会话，或者本地已有课表缓存，就直接进入首页；否则默认进首页的功能页 tab，而不是把用户挡在登录页外。
- 个人页增加“游客模式”卡片和受限操作面板，明确告诉用户无需登录可直接用慧生活798，退出登录后也还能继续使用不依赖校园账号的功能。
- 课表页空状态被拆成两种：未登录时显示“登录校园账号”，已登录但还没课表时显示“刷新课表”；手动刷新会先续 token，再跳 `Getcoursepage(renew: true)` 执行同步。
- 对应的 widget 测试也更新为覆盖新的游客路径和启动判断。
- 关键文件：`lib/core/services/app_auth_storage.dart`、`lib/login/unified_login_page.dart`、`lib/home/userpage/view.dart`、`lib/home/coursetable/view.dart`、`lib/main.dart`
- 统计：14 files changed, 539 insertions(+), 153 deletions(-)

## 2026-03-21 · `22519c4` · feat: add timetable sharing and library flow
- 作者：rccuu
- 这次提交新增的是“课表库”流程，不是普通单份课表缓存；用户可以开始管理自己的历史课表和别人分享过来的课表。
- `lib/utils/course/coursemain.dart` 引入课表归档模型：支持多份 `SavedCourseSchedule`、当前激活课表、重命名、删除、切换、来源标记、只读快照，以及从旧版 `course_data.json` 自动迁移到新档案结构。
- 新增课表分享协议：分享码使用 `SUPERHUT1:` 前缀 + gzip/base64 编码；同时支持导出 JSON 文件、从文件导入、从剪贴板导入、扫码导入、系统分享。
- 课表页新增“课表库”管理底部面板，把“从教务抓取”“扫码导入”“剪贴板导入”“文件导入”“手动粘贴”“复制分享码”“分享文件”等动作全部收口到一个入口里。
- 课表数据开始记录来源类型，如 `selfSync`、`shareImport`、`migratedLegacy`、`manual`，并在 UI 中给当前课表、归档课表、只读分享快照打上不同状态标签。
- 新增依赖 `qr_flutter`、`file_picker`、`share_plus`；对应 iOS/macOS/Windows 的插件注册文件和 lockfile 也一起变化。
- `About` 页再次升级为 Glass 风格：加入 hero 卡片、仓库卡片、开发者卡片和更完整的版本展示。
- 测试侧扩展了课表分享码、导入/导出、归档持久化等能力的覆盖。
- 关键文件：`lib/utils/course/coursemain.dart`、`lib/home/coursetable/view.dart`、`lib/home/about/view.dart`、`pubspec.yaml`
- 统计：12 files changed, 3750 insertions(+), 404 deletions(-)

## 2026-03-21 · `f719a4e` · chore: prepare v1.4.0 release
- 作者：rccuu
- 这是 `v1.4.0` 的发布准备提交，既做版本号提升，也把前一版课表库/扫码导入所需的最后一批收尾补齐。
- `pubspec.yaml` 版本号从 `1.3.0+1` 提升到 `1.4.0+1`。
- Android Manifest 新增 `android.permission.CAMERA`，为课表二维码导入提供系统权限声明。
- 课表页继续打磨“课表库”底部面板：文案更清晰，入口分成“从教务系统抓取课表”“扫码导入”“从剪贴板导入”“导入文件”“手动粘贴”“复制分享码/分享文件”等一组更完整的动作。
- 课表详情页修正实验课“查看实验人员名单”入口的显示条件，只有 `isExp == true` 且 `pcid` 非空时才展示，避免出现点进去必失败的死按钮。
- 新增两个测试：一个校验 Android Manifest 里确实声明了相机权限，一个校验实验课详情页在 `pcid` 为空时不会出现人员名单入口。
- README 也顺手精简了一遍，更偏向发布态说明而不是开发说明。
- 关键文件：`android/app/src/main/AndroidManifest.xml`、`lib/home/coursetable/view.dart`、`test/android_manifest_test.dart`、`test/home/coursetable/course_detail_sheet_test.dart`
- 统计：8 files changed, 583 insertions(+), 551 deletions(-)

## 2026-03-21 · `01cb342` · perf: smooth android flows and polish sharing ui
- 作者：rccuu
- 这次提交是一轮针对 Android 真机体验的集中调优，核心目标不是“去掉动画”，而是把掉帧最明显的页面切换、弹层打开和深色模式可读性问题拆开处理，尽量做到既流畅又保留一点灵动感。
- 首页主切换链路被重做：`lib/home/homeview/view.dart` 不再用 `PageView.animateToPage` 驱动三大主 tab，而是改成 `IndexedStack + lazy load + RepaintBoundary`，首次只构建当前页，其他页按需挂载；同时给当前激活页保留一个很轻的淡入/微位移动画，底部导航项也补了更轻的缩放和文字切换动画。
- Android 全局转场被降级成更轻的系统风格：`lib/main.dart` 把 Android 的页面过渡从 `CupertinoPageTransitionsBuilder` 调整为 `FadeUpwardsPageTransitionsBuilder`，`GetMaterialApp` 默认转场也改成短时长 `fadeIn`，减少多页面跳转时整屏滑动造成的卡顿感。
- `lib/core/ui/apple_glass.dart` 新增 Android 轻量 Glass 策略：环境光球背景模糊半径降低，`GlassPanel` 支持 `useBackdropFilter` 开关，并在 Android 上自动压低 blur 和 shadow。后续多个重区域都开始直接关闭背板模糊，只保留渐变、描边和轻阴影。
- 功能页和课表详情相关弹层同步减负：`lib/home/Functionpage/view.dart` 的功能卡片在 Android 上包进 `RepaintBoundary` 并关闭背板模糊；`lib/home/coursetable/widgets/course_table_widgets.dart` 里的实验人员弹层、课程详情分组卡片也走轻面板，避免滚动或打开详情时 GPU 压力过大。
- 课表库是这次调优的重点之一。`lib/home/coursetable/view.dart` 里把多个 `showCupertinoModalBottomSheet` 改成 Android 自适应底部弹层；课表库管理弹层改成“先出壳，再挂重内容”的结构，顶部标题和主按钮先显示，导入/导出/已保存列表在短暂延迟后再挂载，并带一个很轻的淡入切换；Android 上这层背景也不再用整块 Glass 背景，而改成更轻的纯渐变底。原先用于显示的“本地只读快照”和“只读”标签也一并移除，因为底层并没有真正做权限限制，只是占 UI 空间。
- 课表分享二维码弹层被连续重做两轮：先取消固定 `320/240` 小尺寸限制，改成按屏幕宽高自适应放大；随后又从系统 `AlertDialog` 换成自定义 `Dialog`，收回默认左右留白和动作区占用，让二维码本体尽量吃满屏幕宽度。深色模式下也重新做了层次，外层弹窗、二维码承托面和白色二维码卡片都有各自的渐变、描边和阴影，避免暗底上直接贴一块白板的突兀感。
- 登录页面和“关于工大盒子”页面的打开卡顿也被单独处理。`lib/login/unified_login_page.dart` 新增 `UnifiedLoginPage.route()`，Android 上使用更轻的 fade/slide 路由，并把保存账号信息的读取延后到首帧之后；登录页在 Android 上去掉重 SVG + 玻璃组合，换成更轻的图标徽章与简化卡片。`lib/home/about/view.dart` 也新增 `AboutPage.route()`，Android 上使用轻量路由、首帧后再读版本号、页面背景换成更轻的渐变底，页内 hero 卡片、仓库卡片、返回按钮等都关闭背板模糊并包上 `RepaintBoundary`，专门针对“从我的页进入关于页很卡”的问题减负。
- `lib/home/userpage/view.dart` 修了“已修学分 / 平均绩点要点进去再切回来才显示”的时机问题。用户页现在仍然优先展示 SharedPreferences 里的本地缓存，但在页面初始化完成后会后台静默刷新成绩汇总，不阻塞前台，也不额外弹登录流程；从成绩页返回后，还会立即重新读取缓存并再触发一次后台刷新，保证统计卡片能自动更新。
- 电费页的深色模式可读性也一起重做。`lib/pages/Electricitybill/electricity_page.dart` 不再直接把信息和输入框堆在深色 `primaryContainer / secondaryContainer` 上，而是拆成更清楚的表面层、信息徽标、输入面板、余额面板和统一动作卡片；房间选择弹层、电费预警弹层也去掉了 `Colors.white.withAlpha(...)` 这类固定半透明白层和 `Colors.grey[300]` 这类浅色硬编码，改为跟随 `colorScheme` 的深色表面层与描边。
- 构建流程侧新增 `scripts/build_android_release.sh`，统一执行 `flutter build apk --release --split-per-abi` 并自动把 3 个 APK 移到 `releases/`；`README.md` 也改成直接说明 Android 分架构包和 iOS 未签名 IPA 的构建脚本用法。
- 顺手清了一些导航实现细节：`drink` / `water` / `hutpages` 里几处 `Get.off` / `Get.to` 改成闭包形式，避免目标页面在导航前被提前构建，和这次整体的“减少不必要首帧构建”方向一致。`test/widget_test.dart` 也同步改成检查 `IndexedStack` 和新的游客页展示路径。
- 关键文件：`lib/home/homeview/view.dart`、`lib/home/coursetable/view.dart`、`lib/home/about/view.dart`、`lib/home/userpage/view.dart`、`lib/pages/Electricitybill/electricity_page.dart`
- 统计：17 files changed, 2086 insertions(+), 1219 deletions(-)
