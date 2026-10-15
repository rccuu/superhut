---
generated_from_state_version: 11
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 2
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-10-15T07:49:16.383Z
- 摘要: 独立只读验收：flutter analyze 无告警、flutter test 663 例全绿且无 skip；A1-A14 全部以自身读取到的源码位置与真实测试断言取证通过，接口层与 drink_798 HEAD 8e778ec 实测形态逐字对齐，改动严格限于 798 范围，既有健壮性机制与共享性能入口均未回退。两处 brief 措辞（A6 起始色不透明、A9 未选中三者皆无）与 drink_798 源码不符，实现按「配色忠实照搬」的决定取源码值，已记入 risks 供用户裁定。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | A1：点击「开始接水」时，superhut 发往 `https://i.ilife798.com/api/v1/dev/start` 的查询参数恰为 `did`、`upgrade=true`、`ptype=0`、`args=`（空串）、`rcp=false`、`cnt=1`，且不含 `stype`；有单元测试逐字断言该参数集。 | drink_api.dart:317-324 参数集恰为 did/upgrade=true/ptype=0/args 空串/rcp=false/cnt=1 且无 stype；drink_api_request_test.dart:20-65 逐字断言键集合与完整 URL「…?did=dev-9&upgrade=true&ptype=0&args=&rcp=false&cnt=1」，该用例单独运行通过。 |
| A2 | passed | brief.md | A2：798 的每个请求都携带 `VersionCode: 3.1.8` 与 `User-Agent: Android_ilife798_3.1.8`，不携带 `ApplicationType`、`Accept`、`Accept-Encoding`、`Connection`；连接与接收超时均为 15 秒；有单元测试断言头集合与超时值。 | drink_api.dart:77-87 仅 VersionCode: 3.1.8 与 User-Agent: Android_ilife798_3.1.8 加 15s 连接/接收超时，Authorization 由 _authOptions 按请求注入；drink_api_request_test.dart:141-201 对 5 类请求逐一断言头值、超时，并断言 applicationtype/accept/accept-encoding/connection 均不存在。 |
| A3 | passed | brief.md | A3：本地已存有有效 Token 时，冷启动后第一次 798 认证请求（设备列表、`dev/start`）的 `Authorization` 即为该 Token，不会出现空值；本地 Token 内容不是 JSON 对象时按未登录处理并清掉坏数据，且不使任何请求抛异常；刚登录保存的新 Token 不会被启动时迟到的旧 Token 读取覆盖。有覆盖这三种情形的测试。 | drink_api.dart:100-107 鉴权前 await _tokenInitialized，:113-135 非 Map Token 记录后 prefs.remove 且 catch 不外抛，:253-263 与 :379-384 保存新 Token 前等待旧读取；drink_api_token_init_test.dart:23-140 覆盖冷启动首个请求即带旧 Token、坏 Token 按未登录清理、:113 证明新 Token 不被迟到旧读覆盖。 |
| A4 | passed | brief.md | A4：开始接水或结算失败时，提示正文使用服务端 `msg`；服务端返回 `code == -99` 时提示为「登录已过期 / 请重新登录后再试」并使用 warning 语义配色，其他失败使用 error 语义配色；服务端未给出 `msg` 时分别退回「设备无响应，请检查设备状态」与「结算可能未成功，请检查」。有按返回码分支的测试。 | drink_result.dart:18 isSessionExpired => code==-99；drink_failure_prompt.dart:24-38 将 -99 映射为「登录已过期：请重新登录后再试」warning、其他失败 error 并透出服务端 msg、缺失时退回各自固定文案；function_drink_logic_test.dart:1141-1200 三分支均有断言。 |
| A5 | passed | brief.md | A5：`acc/login` 请求体恰为 `openCode`（空串）、`authCode`、`un`，不含 `cid`；`acc/login/code` 与登录请求都不含 `sign`。登录与发送短信返回区分三种失败并在界面如实呈现：服务端拒绝（显示服务端 `msg`）、响应缺少账号信息（提示「登录已被接受，但响应缺少账号信息」，不得显示验证码错误）、网络或解析异常（标题为「登录异常」，展示 8 秒）。有覆盖三类路径的测试。 | drink_api.dart:206-210 请求体恰为 openCode 空串/authCode/un（无 cid、无 sign），:234-237 缺账号信息给出「登录已被接受，但响应缺少账号信息，请反馈此问题」；command.dart:229-233 code 为 null 时展示 8 秒并标题「登录异常」；drink_api_request_test.dart:81-111/:362-431 与 drink_login_command_test.dart:147-241 覆盖服务端拒绝、形状异常、网络异常三路径，且断言文案不含「验证码错误」。 |
| A6 | passed | brief.md | A6：798 登录页只有一个渐变：高度 168 的顶部品牌带，起始色为品牌蓝不透明、终止色 alpha 为 0 且其纯色等于主题 `scaffoldBackgroundColor`；页面不再绘制卡片层，深浅两种模式下都不存在 `#0099CC` 的实色或渐变终止色，`Scaffold.backgroundColor` 保持为 null。图形验证码图片显示为 104×52、与验证码输入框在同一 `Row` 内且两者垂直中心相差小于 4 像素，点击图片即重新拉取（刷新次数 1→2），页面上不存在「看不清？点击刷新」按钮。验证码输入框使用数字键盘、仅数字过滤器、`maxLength` 为 6，输入 `a1b2c` 后得到 `12`。 | login/view.dart:154-167 页面唯一渐变，bandHeight=168、尾色 scaffoldColor alpha 0；drink_login_page_test.dart:282-319 断言渐变恰 1 个、尾色纯色等于 scaffoldBackgroundColor、高度 168，:321-342 验证码 104×52 与输入框垂直中心差 <4px，:185-199 点击刷新 1→2，:29 无「刷新」文案按钮，:344-384 无 #0099CC 且 Scaffold.backgroundColor 为 null，:261-280 数字键盘+仅数字+maxLength 6（输入 a1b2c 得 12）。起始色为品牌蓝 alpha 0.16 与 drink_798 login_page.dart:36 一致，brief 该句「不透明」用词不准，见 risks。 |
| A7 | passed | brief.md | A7：手机号+图形验证码面板与短信验证码面板位于同一路由页面内：提交手机号后面板就地切换为短信码并保留已输入手机号，面板内提供返回上一步的入口且返回时重新拉取图形验证码；`loginpart2.dart` 不再存在。798 登录页的输入框与主按钮使用 `lib/core/widgets/app_form_fields.dart` 的共享组件，其中主按钮在加载态禁用并显示进度指示，输入框圆角在正常/启用/聚焦三态一致且不显示计数器文字。 | command.dart:12,29-34,97-100 以 ValueNotifier<DrinkLoginStep> 在同一页切换面板，view.dart:176-197 就地渲染；drink_login_page_test.dart:202-233 断言不压新路由并保留手机号，:236-259 返回时重拉验证码（1→2）；loginpart2.dart 与 login/widgets/login_widgets.dart 已删除且全仓无引用；app_form_fields.dart:83,95-106 counterText 置空且三态圆角 16 一致，:160-186 主按钮加载态 onPressed=null 并显示进度指示，drink_login_page_test.dart:386-423 断言共享指标。 |
| A8 | passed | brief.md | A8：798 首页使用页面私有 token，浅色模式取值与 drink_798 一致（页面底 `#E4EEF8`、卡片 `#FFFFFF`、选中 `#FFFFFF`、tint `#DCEBF9`、顶部带 `#C5E0F7`、发丝线 `0x4D7E96AE`、强调渐变 `#0277BD`→`#00619E`）。页面背景是三个终止点不全等的命名渐变，空闲态终止色 `t = 1.0` 与 `Scaffold.backgroundColor` 相同；卡片填充相对其真实背景至少 1.15:1 亮度分离且至少两个通道（亮度差 + 描边或阴影）可辨；深浅两种模式下正文对比度 ≥ 4.5:1、两个标题 ≥ 3.0:1，且浅色的 `#00D4FF` 不出现在任何渐变终止色中。主操作按钮外层绘制渐变、内层 `FilledButton` 背景透明并显式设置禁用底色与 `overlayColor`，禁用时不响应点击且不调用接口。 | drink_home_tokens.dart:28-73,146-168 与 drink_798 home_page.dart:50-101,104-200 逐项比对一致（#E4EEF8/#FFFFFF/#DCEBF9/#C5E0F7/0x4D7E96AE/#0277BD→#00619E 及深色六项与命名渐变公式）；drink_home_ui_test.dart:51-105 三终止点互不相等且 t=1.0 等于 Scaffold.backgroundColor，:107-161 表面分离 ≥1.15:1 且两通道，:163-217 正文 ≥4.5:1、两标题 ≥3.0:1，:316-338 #00D4FF 永不出现在任何已绘制渐变，:340-378 外层渐变 + 内层透明 FilledButton（widgets.dart:873-887 显式 disabledBackgroundColor/overlayColor），:381-419 禁用态点击不产生 startDrink 请求。 |
| A9 | passed | brief.md | A9：设备行在选中时具有品牌色 1.6px 描边、勾选标记与抬升阴影，未选中时三者皆无；把饱和度归零后选中态仍可通过至少两个通道区分。 | drink_page_widgets.dart:609-630 选中为 brandInk 1.6px 描边 + :587-591 勾选标记 + alpha 0.22/blur 14 抬升阴影；drink_home_ui_test.dart:243-280 断言宽度 1.6、描边对比 ≥3.0、标记存在，未选中为 1.0px hairline、marker findsNothing。未选中仍保留 1px 发丝边框与静止阴影，与 drink_798 home_page.dart:634-641 相同，brief「三者皆无」按选中专属表达成立，见 risks。 |
| A10 | passed | brief.md | A10：首页可在列表与网格（两列）两种布局间切换，选择持久化到 `device_list_layout` 并在下次进入时恢复；进入排序模式后使用拖拽手柄重排，重排结果写入 `device_order`，下次进入时按 `applyDeviceOrder` 规则恢复（已知名按保存顺序在前，未知名保持原有相对顺序，保存中已不存在的 id 忽略），且重排与恢复后选中设备仍是同一台设备。 | logic.dart:355-366 与 :88-91 持久化/恢复 device_list_layout，:382-419 reorderDevices 写入 device_order 并按 id 重定位选中，:241-245 经 drink_device.dart:25-51 的 applyDrinkDeviceOrder（已知名在前、未知名保序、失效 id 忽略）；function_drink_logic_test.dart:723-802/:866/:936/:988 与 drink_home_ui_test.dart:469-541（grid crossAxisCount==2、ReorderableListView + 2 个拖拽手柄 + 提示条）覆盖，抽样用例单独运行通过。 |
| A11 | passed | brief.md | A11：正在接水时切换设备或进入/退出排序模式都不改变状态，并提示「正在接水中，请先结算」；此时点击主按钮执行结算而非开始。 | logic.dart:337-343 与 :369-379 在 drinkStatus 为真时不改状态并回 _refuseWhileDrinking(:436-442「提示：正在接水中，请先结算」)；function_drink_logic_test.dart:1095/1115/1252 覆盖切换设备、进出排序与文案，drink_home_ui_test.dart:421-467 断言接水态主按钮变结算且 endDrinkRequests==['tap-1']。 |
| A12 | passed | brief.md | A12：每台设备可通过编辑入口写入备注并持久化到 `device_note_<id>`，写入后列表项与当前设备卡片立即显示该备注，重新进入页面后仍存在。 | logic.dart:264-282 saveDeviceNote 写入/清除 device_note_<id> 后刷新 deviceList，:247-261 重载读回，:285-292 deviceTitle 拼接备注，view.dart:428/:463 当前设备卡片与列表项同源显示；function_drink_page_test.dart:613「note dialog writes and clears device_note_<id」与 :663 长按同入口、function_drink_logic_test.dart:1069 重载恢复并忽略空备注，抽样单独运行通过。 |
| A13 | passed | brief.md | A13：连续触发刷新时只有一次在途请求，且刷新期间新增设备所需的后续重载不会被丢弃；设备列表接口失败时给出可重试提示而不清空已有列表。 | logic.dart:135-160 在途复用同一 Future 并置 _reloadQueued 完成后补跑一次，:198 登录过期分支显式不补跑，:228-237 失败只提示不清空列表；function_drink_logic_test.dart:27/:69/:108/:1299 与 function_drink_page_test.dart:95 覆盖单在途、补跑不丢新设备、失败保留设备，抽样单独运行通过。 |
| A14 | passed | brief.md | A14：798 之外的页面与全局主题文件未被修改；`flutter analyze` 无告警，`flutter test` 全部通过（含因首页与登录页重构而更新的既有测试）。 | git status --porcelain 与 git diff HEAD --stat 全量核对：仅 lib/pages/drink/**、新增 lib/core/widgets/app_form_fields.dart 与 test/pages/drink/**、test/core/ui/performance_boundaries_test.dart；pubspec.yaml、lib/core/theme/**、lib/main.dart 与 798 之外页面零命中；798 代码内无 sign/crypto/drink_api_signer/loginWithToken/stype，无 loginpart2/login_widgets 残留；grep -rn "skip:" test/ 无输出；flutter analyze → No issues found!，flutter test → 00:16 +663: All tests passed!。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze | analyze | . | passed | 0 | 6209 ms |
| flutter test | test | . | passed | 0 | 25179 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter analyze: passed — No issues found! (ran in 2.6s)，无告警、无 error。
- flutter test: passed — All tests passed! 663 例全部实际执行（drink 相关 125 例 + performance_boundaries 93 例），test/ 下无 skip:true 残留。
- 范围自查: passed — git status 仅 lib/pages/drink/**、lib/core/widgets/、test/pages/drink/**、test/core/ui/performance_boundaries_test.dart 与 docs/comet 产物；lib/core/theme、AppTheme、pubspec.yaml 与 798 之外页面零修改。
- 已知限制: 真机登录与真实接水无法在本环境复现：接口层证据为可注入 HTTP 替身断言的 URL、查询参数、请求体、头与超时，加上 drink_798 已用同一形态实测通过；未声称已对真实服务端验证，需用户在设备上完成最终确认。
- 已知限制: 首页与登录页视觉结论以 widget 测试的像素/对比度断言为证据（品牌带唯一渐变、验证码 104×52 与中心差 <4px、命名渐变终止点、≥1.15:1 表面分离、≥4.5:1 正文与 ≥3.0:1 标题），未经真机截图人工确认。
- 已知限制: 接水中「自动结算依赖状态轮询」沿用既有实现与既有代际测试，本环境无法用真实设备验证轮询与自动结算的实际时序。
- 已知限制: 签名能力按用户决定与 drink_798 实测结论（服务端不校验 sign，带 sign 反而验签失败）刻意不移植，因此若服务端策略日后变化需要单独 change 处理。
- 已知限制: 本次不改动 Git 历史：worktree 分支 comet/sync-ilife798-updates 上尚无提交，提交、合并、推送或 PR 均需用户单独授权。

## 阻塞项

_无。_

## 风险与跳过的工作

- brief A6 原文「起始色为品牌蓝不透明」与 drink_798 login_page.dart:36 的 colorScheme.primary.withValues(alpha: 0.16) 不符；实现与测试忠于参考源码（用户决定为配色忠实照搬），因此按源码取值判定通过，brief 该句措辞需在归档说明中记录为文字偏差。
- brief A9 原文「未选中时三者皆无」：未选中行仍保留 1px hairline 边框与 ink@0.06/blur 8 的静止阴影，与 drink_798 home_page.dart:634-641 完全一致；按「1.6px 品牌描边、勾选标记、抬升阴影」三项选中专属表达判定成立。
- A9 的「去饱和后仍至少两通道可辨」没有专门测试（drink_798 亦无）：现有证据为结构性通道（描边 1.6 vs 1.0、勾选标记有/无、阴影 0.22/blur14 vs 0.06/blur8）加实测亮度对比 ≥3.0，未做去饱和演算。
- A4 的 warning/error 语义配色只由 drink_failure_prompt.dart:29/:36 源码取证，测试仅断言文案文本；若语义类型被误改不会被现有测试发现。
- 真机登录与真实接水在本环境无法复现（brief 已知限制）：A1/A2/A5 以可注入 HTTP 替身断言的参数集、头集合、超时与返回码分支，加上 drink_798 已用同一形态实测通过为依据；需用户在设备上完成最终确认。
- 页面底色来源在两页不同：首页 idleBackground 尾点取 drink_home_tokens.dart:146-151 的私有 token，登录页尾点取主题 scaffoldBackgroundColor（login/view.dart:162）；若日后 superhut 调整主题底色，登录页自动跟随而首页不会，需同步维护。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 0 | recovery | — | Native Shape artifacts changed | 2026-10-15T05:14:54.665Z |
| 2 | 1 | 1 | pass | — | 独立只读验收：flutter analyze 无告警、flutter test 663 例全绿且无 skip；A1-A14 全部以自身读取到的源码位置与真实测试断言取证通过，接口层与 drink_798 HEAD 8e778ec 实测形态逐字对齐，改动严格限于 798 范围，既有健壮性机制与共享性能入口均未回退。两处 brief 措辞（A6 起始色不透明、A9 未选中三者皆无）与 drink_798 源码不符，实现按「配色忠实照搬」的决定取源码值，已记入 risks 供用户裁定。 | 2026-10-15T07:49:16.383Z |



## 结论

独立只读验收：flutter analyze 无告警、flutter test 663 例全绿且无 skip；A1-A14 全部以自身读取到的源码位置与真实测试断言取证通过，接口层与 drink_798 HEAD 8e778ec 实测形态逐字对齐，改动严格限于 798 范围，既有健壮性机制与共享性能入口均未回退。两处 brief 措辞（A6 起始色不透明、A9 未选中三者皆无）与 drink_798 源码不符，实现按「配色忠实照搬」的决定取源码值，已记入 risks 供用户裁定。
