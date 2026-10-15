# 目标

把独立项目 drink_798（`/Users/tune/Develop/GitHub/drink_798`，HEAD `8e778ec`）已经验证可用的惠生活798能力同步到 superhut，使 superhut 内的 798 功能恢复可用并对齐新版界面：

1. 修好「启用不了设备」：`dev/start` 业务参数、请求头、Token 读取时序与服务端返回透出，全部对齐 drink_798 实测通过的形态。
2. 按 drink_798 新版重做 798 登录页与 798 饮水首页的界面与交互，包括首页的列表/网格双布局、长按拖拽排序与设备备注。

配色忠实照搬 drink_798 的页面私有 token，使已验证过的对比度数值直接沿用。

# 范围

## 目录结构

### 新建

- `lib/core/widgets/app_form_fields.dart`：`AppTextField` / `AppFieldLabel` / `AppPrimaryButton`，供 798 登录页使用。
- `lib/pages/drink/api/drink_result.dart`：798 接口返回类型（`success` / `code` / `message` / `isSessionExpired`）。
- `lib/pages/drink/core/drink_device.dart`：设备行 id/名称存取与 `applyDrinkDeviceOrder` 纯函数。
- `lib/pages/drink/core/drink_failure_prompt.dart`：把 `DrinkResult` 映射为提示标题、正文与语义类型。
- `lib/pages/drink/core/drink_home_tokens.dart`：首页页面私有 token 与命名渐变表。
- 对应测试：`test/pages/drink/**`（接口请求、Token 时序、失败提示、顺序、首页与登录页 widget 测试）。

### 修改

- `lib/pages/drink/api/drink_api.dart`：请求头、超时、`dev/start` 参数集、登录参数集、`_authOptions` 等待 Token 初始化、损坏 Token 容错、返回类型改为 `DrinkResult`、设备列表解析与备注字段。
- `lib/pages/drink/view/logic.dart`、`state.dart`、`view.dart`：首页新版分层表面与配色、双布局、拖拽排序、备注、失败提示映射；正文由 `RefreshIndicator` 直接承载带 `Expanded` 内联列表的 Column；保留既有 dispose 守卫、并发去重与状态轮询代际机制。
- `lib/pages/drink/login/command.dart`、`view.dart`：登录页改为单页内联面板，套用新版视觉与共享输入组件，透出服务端真实失败原因。
- `lib/pages/drink/view/widgets/drink_page_widgets.dart`：首页新版分层表面与配色、双布局、拖拽排序、备注编辑器对话框；保留既有扫码页与设备管理抽屉。
- `test/core/ui/performance_boundaries_test.dart`：更新与 798 首页/登录页结构相关的源码断言，性能约束本身保持不变（隐式过渡继续必须走 `AppAnimatedContainer`）。

### 删除

- `lib/pages/drink/login/loginpart2.dart`：短信验证码面板并入登录页，不再作为独立路由。
- `lib/pages/drink/login/widgets/login_widgets.dart`：卡片式登录壳层与页面私有输入框被 `lib/core/widgets/app_form_fields.dart` 取代。

### 明确不建

- 不引入 drink_798 的签名实现（`drink_api_signer.dart`）与任何 `sign` 查询参数。
- 不引入「使用已有 Token 登录」入口与 `loginWithToken` 能力。
- 不新增 `lib/core/theme` 下的独立主题文件，不修改 superhut 全局 `AppTheme`。
- 不引入 `ionicons`、`modal_bottom_sheet`、`google_fonts`、`crypto` 等新依赖（superhut 已有 `ionicons`；其余按需使用现有能力）。

## 来源覆盖

覆盖边界：drink_798 HEAD `8e778ec` 中直接与「798 设备控制接口调用、798 登录页、798 饮水首页」相关的实现文件，即 `lib/core/services/drink_api_service.dart`、`lib/core/models/device_model.dart`、`lib/core/utils/device_order.dart`、`lib/core/widgets/app_form_fields.dart`、`lib/core/theme/app_theme.dart`、`lib/features/login/login_page.dart`、`lib/features/home/home_page.dart`、`lib/features/home/home_controller.dart`、`lib/features/home/home_prompt_colors.dart`，以及它们对应的 `test/` 断言。边界外内容（drink_798 的 App 外壳 `lib/main.dart`、`lib/features/scanner/**`、平台配置、发布脚本、changelog）不纳入。superhut 与 drink_798 的 798 代码同源，其接口层基线对应 drink_798 提交 `6c18269` 之前、首页布局对应 `e9c494d`（顺序工具）之前的状态。

| 来源条目与位置 | 读取状态 | 需要保留的内容 | Spec 位置 | 验收 ID | 覆盖状态 | 理由或替代关系 |
| --- | --- | --- | --- | --- | --- | --- |
| S1：`drink_api_service.dart:356-382`（提交 `85d73de`，由 `09a1c08` 保留） | complete | `dev/start` 发送 `did/upgrade/ptype/args/rcp/cnt`，去掉不存在的 `stype` | specs/drink-798/spec.md「开始接水请求」 | A1 | covered | 实测接水真正需要的改动 |
| S2：`drink_api_service.dart:55-69`（提交 `6c18269`→`85d73de`→`48db1df`） | complete | 只发 `VersionCode: 3.1.8` 与 `User-Agent: Android_ilife798_3.1.8`，移除 `ApplicationType` 等历史头；15 秒超时 | specs/drink-798/spec.md「请求头与超时」 | A2 | covered | 官方客户端请求画像 |
| S3：`drink_api_service.dart:37-116`、`277-287`（提交 `6c18269`、`48db1df`） | complete | 认证请求先 `await` Token 初始化；损坏 Token 按未登录并清理；保存新 Token 前等待旧读取 | specs/drink-798/spec.md「凭据加载时序」 | A3 | covered | 启动竞态会导致空 Authorization |
| S4：`drink_api_service.dart:12-30`、`403-417`（提交 `85d73de`） | complete | `DrinkResult` 透出 `code`/`msg`，`-99` 视为登录态过期 | specs/drink-798/spec.md「服务端返回透出」 | A4 | covered | 不再一律提示设备无响应 |
| S5：`home_controller.dart:34-51`、`294-370`（提交 `85d73de`、`09a1c08`） | complete | 按返回码呈现失败提示：`-99` 引导重新登录，其他透出 `msg`，缺失时退回固定文案 | specs/drink-798/spec.md「服务端返回透出」 | A4 | covered | 与 S4 同一条行为链的界面侧 |
| S6：`drink_api_service.dart:188-250`（提交 `8658ca1`、`d9048ee`） | complete | `acc/login` 参数为 `openCode/authCode/un`，删除 `cid`；登录与短信接口不发送 `sign` | specs/drink-798/spec.md「登录请求」 | A5 | covered | 官方不发送 `cid` |
| S7：`drink_api_service.dart:142-179`、`login_controller.dart:154-162`（提交 `004ed98`、`d0a222e`） | complete | 登录与短信区分服务端拒绝、响应形状异常、网络/解析异常；`code` 为 null 时标题「登录异常」，提示展示 8 秒 | specs/drink-798/spec.md「登录请求」 | A5 | covered | 误导性的「验证码错误」掩盖真实故障 |
| S8：`login_page.dart:25-55`、`195-289`（提交 `19f225b`） | complete | 去掉卡片层，单一浅色表面 + 168 高品牌带；验证码 104×52 与输入框同排居中、点击刷新；数字键盘与仅数字过滤、`maxLength` 6 | specs/drink-798/spec.md「798 登录页」 | A6 | covered | 登录页视觉重做主体 |
| S9：`app_form_fields.dart`、`login_page.dart:112-170`（提交 `19f225b`） | complete | 抽取共享输入组件；同一页面内在手机号/短信码面板间切换并提供返回 | specs/drink-798/spec.md「798 登录页」 | A7 | covered | 用户确认单页内联面板 |
| S10：`home_page.dart:48-234`（提交 `9d3edf7`、`978537f`） | complete | 页面私有 token 分层（≥1.15:1 且两个通道）、idle/active/accentFill 命名渐变、深浅两套取值 | specs/drink-798/spec.md「798 首页表面与配色」 | A8 | covered | 首页视觉重做主体 |
| S11：`home_page.dart:904-993`（提交 `9d3edf7`） | complete | 主操作按钮：外层渐变 + 透明 `FilledButton` + 固定禁用底色，保留禁用语义与涟漪 | specs/drink-798/spec.md「798 首页表面与配色」 | A8 | covered | — |
| S12：`home_page.dart:587-879`（提交 `9d3edf7`、`350ea7b`） | complete | 选中态语言：1.6px 品牌描边 + 勾选标记 + 抬升阴影，灰度下仍可辨 | specs/drink-798/spec.md「设备选择与选中态」 | A9 | covered | — |
| S13：`home_controller.dart:68-103`、`224-232`，`home_page.dart` 列表/网格（提交 `448aacc`、`aa431dd`） | complete | 列表/网格双布局并持久化 `device_list_layout` | specs/drink-798/spec.md「设备布局与排序」 | A10 | covered | 用户确认移植 |
| S14：`home_controller.dart:196-267`、`device_order.dart`（提交 `e9c494d`） | complete | 拖拽排序、`applyDeviceOrder` 规则、顺序持久化 `device_order`、重排后保持选中 | specs/drink-798/spec.md「设备布局与排序」 | A10 | covered | 用户确认移植 |
| S15：`home_controller.dart:235-291` | complete | 接水中切换设备或进入排序被拒绝并提示「正在接水中，请先结算」 | specs/drink-798/spec.md「接水中守卫」 | A11 | covered | — |
| S16：`home_controller.dart:166-194`、`home_page.dart` 编辑芯片 | complete | 设备备注本地持久化 `device_note_<id>`，列表与当前设备卡片显示 | specs/drink-798/spec.md「设备备注」 | A12 | covered | 用户确认一并移植 |
| S17：`home_controller.dart:80-84`、`112-164`、`215-232` | complete | 刷新去重：在途时不并发发请求，结束后补跑一次 | specs/drink-798/spec.md「设备列表刷新」 | A13 | covered | superhut `logic.dart:96-112` 以复用同一 Future 去重，需确认扫码新增后仍能刷新 |
| S18：`login_page.dart` Token 表单、`drink_api_service.dart:252-275`（提交 `9dbd60f`） | complete | 使用已有 Token 登录 | — | — | non-goal | 用户在 Q2/Q3 明确不引入该入口 |
| S19：`drink_api_signer.dart` 及其测试（提交 `85d73de`，被 `09a1c08` 停用） | complete | 逆向得到的 MD5 签名算法 | — | — | superseded | drink_798 实测服务端不校验签名，带签名反而「验签失败」，代码已成死路 |
| S20：`app_theme.dart:52`、`129`（提交 `19f225b`） | complete | 显式设置 `onSurfaceVariant`，避免退化为 `onSurface` | — | — | covered | 已由事实调查解决：superhut `main.dart:26-60` 用 `ColorScheme.fromSeed`，`onSurfaceVariant` 与 `onSurface` 本就不同，无需改全局主题 |
| S21：`home_page.dart` 页面私有气泡层 | complete | 首页背景气泡动画 | — | — | superseded | 保留 superhut 共享的 `AmbientBubbleField`（受 `AppGlassPerformanceScope` 门控），避免重复动画层与性能回退 |
| S22：`test/features/home/home_page_ui_test.dart`、`test/features/login/login_page_ui_test.dart` | complete | WCAG 采样工具与逐条设计断言 | — | — | background | 作为实现参考；移植其中可验证的规则子集，不整份复制其私有 harness |

# 非目标

- 不移植签名代码，任何 798 请求都不带 `sign` 参数。
- 不新增「使用已有 Token 登录」能力，`DrinkApi` 不新增 `loginWithToken`。
- 不改动 798 之外的功能页面（课表、查分、热水、评教、统一登录等）与全局 `AppTheme`。
- 不改平台配置、构建脚本、依赖清单（除非移植确实缺少某个已被 superhut 使用的包）。
- 不引入 drink_798 的 App 外壳能力：独立启动页、关于对话框、`url_launcher` 跳转、其自有扫码页。
- 不合并或搬运 drink_798 的 Git 历史、changelog 与 `pubspec.yaml` 版本号。

# 验收示例

- A1：点击「开始接水」时，superhut 发往 `https://i.ilife798.com/api/v1/dev/start` 的查询参数恰为 `did`、`upgrade=true`、`ptype=0`、`args=`（空串）、`rcp=false`、`cnt=1`，且不含 `stype`；有单元测试逐字断言该参数集。
- A2：798 的每个请求都携带 `VersionCode: 3.1.8` 与 `User-Agent: Android_ilife798_3.1.8`，不携带 `ApplicationType`、`Accept`、`Accept-Encoding`、`Connection`；连接与接收超时均为 15 秒；有单元测试断言头集合与超时值。
- A3：本地已存有有效 Token 时，冷启动后第一次 798 认证请求（设备列表、`dev/start`）的 `Authorization` 即为该 Token，不会出现空值；本地 Token 内容不是 JSON 对象时按未登录处理并清掉坏数据，且不使任何请求抛异常；刚登录保存的新 Token 不会被启动时迟到的旧 Token 读取覆盖。有覆盖这三种情形的测试。
- A4：开始接水或结算失败时，提示正文使用服务端 `msg`；服务端返回 `code == -99` 时提示为「登录已过期 / 请重新登录后再试」并使用 warning 语义配色，其他失败使用 error 语义配色；服务端未给出 `msg` 时分别退回「设备无响应，请检查设备状态」与「结算可能未成功，请检查」。有按返回码分支的测试。
- A5：`acc/login` 请求体恰为 `openCode`（空串）、`authCode`、`un`，不含 `cid`；`acc/login/code` 与登录请求都不含 `sign`。登录与发送短信返回区分三种失败并在界面如实呈现：服务端拒绝（显示服务端 `msg`）、响应缺少账号信息（提示「登录已被接受，但响应缺少账号信息」，不得显示验证码错误）、网络或解析异常（标题为「登录异常」，展示 8 秒）。有覆盖三类路径的测试。
- A6：798 登录页只有一个渐变：高度 168 的顶部品牌带，起始色为品牌蓝不透明、终止色 alpha 为 0 且其纯色等于主题 `scaffoldBackgroundColor`；页面不再绘制卡片层，深浅两种模式下都不存在 `#0099CC` 的实色或渐变终止色，`Scaffold.backgroundColor` 保持为 null。图形验证码图片显示为 104×52、与验证码输入框在同一 `Row` 内且两者垂直中心相差小于 4 像素，点击图片即重新拉取（刷新次数 1→2），页面上不存在「看不清？点击刷新」按钮。验证码输入框使用数字键盘、仅数字过滤器、`maxLength` 为 6，输入 `a1b2c` 后得到 `12`。
- A7：手机号+图形验证码面板与短信验证码面板位于同一路由页面内：提交手机号后面板就地切换为短信码并保留已输入手机号，面板内提供返回上一步的入口且返回时重新拉取图形验证码；`loginpart2.dart` 不再存在。798 登录页的输入框与主按钮使用 `lib/core/widgets/app_form_fields.dart` 的共享组件，其中主按钮在加载态禁用并显示进度指示，输入框圆角在正常/启用/聚焦三态一致且不显示计数器文字。
- A8：798 首页使用页面私有 token，浅色模式取值与 drink_798 一致（页面底 `#E4EEF8`、卡片 `#FFFFFF`、选中 `#FFFFFF`、tint `#DCEBF9`、顶部带 `#C5E0F7`、发丝线 `0x4D7E96AE`、强调渐变 `#0277BD`→`#00619E`）。页面背景是三个终止点不全等的命名渐变，空闲态终止色 `t = 1.0` 与 `Scaffold.backgroundColor` 相同；卡片填充相对其真实背景至少 1.15:1 亮度分离且至少两个通道（亮度差 + 描边或阴影）可辨；深浅两种模式下正文对比度 ≥ 4.5:1、两个标题 ≥ 3.0:1，且浅色的 `#00D4FF` 不出现在任何渐变终止色中。主操作按钮外层绘制渐变、内层 `FilledButton` 背景透明并显式设置禁用底色与 `overlayColor`，禁用时不响应点击且不调用接口。
- A9：设备行在选中时具有品牌色 1.6px 描边、勾选标记与抬升阴影，未选中时三者皆无；把饱和度归零后选中态仍可通过至少两个通道区分。
- A10：首页可在列表与网格（两列）两种布局间切换，选择持久化到 `device_list_layout` 并在下次进入时恢复；进入排序模式后使用拖拽手柄重排，重排结果写入 `device_order`，下次进入时按 `applyDeviceOrder` 规则恢复（已知名按保存顺序在前，未知名保持原有相对顺序，保存中已不存在的 id 忽略），且重排与恢复后选中设备仍是同一台设备。
- A11：正在接水时切换设备或进入/退出排序模式都不改变状态，并提示「正在接水中，请先结算」；此时点击主按钮执行结算而非开始。
- A12：每台设备可通过编辑入口写入备注并持久化到 `device_note_<id>`，写入后列表项与当前设备卡片立即显示该备注，重新进入页面后仍存在。
- A13：连续触发刷新时只有一次在途请求，且刷新期间新增设备所需的后续重载不会被丢弃；设备列表接口失败时给出可重试提示而不清空已有列表。
- A14：798 之外的页面与全局主题文件未被修改；`flutter analyze` 无告警，`flutter test` 全部通过（含因首页与登录页重构而更新的既有测试）。

# 约束与不变量

- superhut 现有的健壮性机制必须保留：控制器 `dispose` 后丢弃迟到结果、设备列表请求去重、`favoDevice` 按 key 去重、状态轮询的代际计数与 `requiredAvailablePolls`、单一登录跳转。这些是既有测试 `test/pages/drink/function_drink_logic_test.dart` 与 `test/pages/drink/function_drink_page_test.dart` 的既有断言对象。
- 798 提示沿用 superhut 的 `showAppSnackBar` 原语与其 `AppSnackBarType`（notice→info、成功→success、登录过期→warning、其他失败→error），不引入 drink_798 页面私有的 `Get.snackbar` 配色常量。
- 两页的强调色与表面色使用页面私有常量（沿用 drink_798 取值），不读取宿主 `colorScheme.primary`；中性文字色与 `scaffoldBackgroundColor` 仍从 superhut 主题读取。
- 不新增第三方依赖。首页所需的图标与弹层沿用 superhut 现有实现。
- 保留 superhut 共享的 `AmbientBubbleField` 气泡层与 `AppGlassPerformanceScope` lite 门控，不移植 drink_798 的页面私有气泡。
- 存储键沿用 superhut 现有的 `drink798UsrApiToken` 与 `hui798IsLogin`，不得改名为 drink_798 的键，以免覆盖既有登录态。新增键仅为 `device_order`、`device_list_layout`、`device_note_<id>`。
- 本地化文案与 superhut 现有中文文案风格保持一致；`设备可切换，开始用水后会自动检测状态。` 一类既有提示若因新版布局需要调整，须在测试中同步更新。
- 扫码添加、删除设备、下拉刷新、透明 AppBar 与 `extendBodyBehindAppBar` 的既有入口行为保持可用。

# 决定

- [2026-10-15，用户确认] 接口层全量同步 drink_798 实测形态：参数集、请求头、Token 时序容错、`DrinkResult` 透出、登录去掉 `cid`；不移植签名代码（drink_798 已实测服务端不校验签名，`drink_api_signer.dart` 现为死代码）。
- [2026-10-15，用户确认] UI 完整移植：饮水首页与登录页两页重做，含列表/网格双布局、长按拖拽排序与顺序持久化。
- [2026-10-15，用户确认] 配色忠实照搬 drink_798 的页面私有 token 与强调渐变，不改用 superhut 品牌蓝。
- [2026-10-15，用户确认] 设备备注一并移植。
- [2026-10-15，用户确认] 登录页改为单页内联面板，删除 `loginpart2.dart` 独立路由。
- [2026-10-15，事实调查] superhut 的 798 接口层对应 drink_798 提交 `6c18269` 之前的状态，首页布局不含 `e9c494d` 之后的顺序/布局能力，据此确定同步边界。
- [2026-10-15，事实调查] superhut 全局主题使用 `ColorScheme.fromSeed`，`onSurfaceVariant` 已不同于 `onSurface`，因此不需要移植 drink_798 的主题补丁。
- [2026-10-15，Agent 决定] 单个 Native change 承载，不拆 Supervisor：三块改动都落在 `lib/pages/drink/**` 同一核心区域，接口层是两页的共同前置，且 `test/core/ui/performance_boundaries_test.dart` 对该模块有整片源码断言，并行改写只会产生冲突。

# 未决问题

（无）

# 验证期望

- `flutter analyze` 与 `flutter test` 在当前工作区全部通过，作为客观门槛。
- 接口层用可注入的 HTTP 替身断言最终 URL、查询参数、请求体、请求头与超时，不依赖真实服务端。
- 登录页与首页用 widget 测试断言可见结果：验证码尺寸与同行居中的像素差、数字过滤后的输入值、面板就地切换、渐变终止点与 `Scaffold.backgroundColor` 的关系、卡片与页面底的相对亮度分离、正文与标题对比度阈值、布局切换与顺序持久化往返、备注写入与显示。
- 真机登录与真实接水无法在本环境复现，属于已知限制：以参数集、头集合与返回码分支的测试，以及 drink_798 已实测通过同一形态作为依据，不声称已对真实服务端验证。
- 798 之外页面无回归，以既有测试全套通过为证据。
