# 目标

把独立项目 drink_798（HEAD `7380c52`，2026-10-18）吸收上游 `cc2562/superhut` 实测修复后的 798 增量同步到 superhut 内置的「慧生活798」模块，使两边的接口行为与支付路径保持一致：

1. 支付路径对齐：`dev/start` 的 `ptype` 从语义未确证的静态值 `0` 改为钱包支付 `91`，钱包被拒时在控制器回退支付宝免密 `21` 再试一次（登录过期不回退）。
2. 开始接水前置预检：先查设备状态，离线、禁用直接拦截并分别提示；设备被占用时同步为可结算态而不重发开始请求。
3. 扫码解析对齐官方入口：二维码末段先经 `qr/use` 换取真实设备 ID，失败回退二维码末段本身。
4. 其余线上形状对齐：`dev/end` 带 `rcp=false`；`dev/favo` 的 `remove` 以 `1/0` 上线；`dev/status` 请求改为 `did` + `more=false`（去 `promo`），响应按三态解析（`device.status` 0 离线、`device.gene.status` 99 空闲 / 98 禁用）。
5. 状态轮询加 30 分钟上限，防止异常情况下定时器长期驻留。

# 范围

## 目录结构

### 新建

- `lib/pages/drink/api/drink_device_status.dart`：设备状态三态模型（离线 / 禁用 / 空闲 / 运行中）与 `DeviceStatusResult`（携带服务端码与信息的查询结果）。
- 对应测试：`test/pages/drink/` 下的请求形状与逻辑分支断言。

### 修改

- `lib/pages/drink/api/drink_api.dart`：`_paymentType` 改为钱包 91 并公开常量；`startDrink` 增加可注入的 `ptype` 参数；`endDrink` 带 `rcp=false`；`favoDevice` 的 `remove` 上线 1/0；`isAvailableDevice` 改为 `did` + `more=false` 并去 `promo`；新增 `deviceStatus`（三态解析）与 `resolveQrDevice`（`qr/use`）。
- `lib/pages/drink/view/logic.dart`：`startDrink` 前置设备状态预检（离线、禁用拦截并分别提示，占用中同步为可结算态）；钱包被拒回退支付宝 21 一次且 `-99` 不回退；轮询加 30 分钟上限。
- `lib/pages/drink/view/view.dart`：扫码添加先调 `resolveQrDevice` 换真实设备 ID，失败回退二维码末段。
- `test/pages/drink/drink_api_request_test.dart`：更新 `dev/start`、`dev/end`、`dev/status` 的线上形状断言，新增 `qr/use` 与 `ptype` 传参断言。
- `test/pages/drink/function_drink_logic_test.dart`：新增预检三分支、支付回退、`-99` 不回退、轮询上限的测试；既有 fake 按新接口形状更新。
- `docs/comet/specs/drink-798/spec.md`（经 change specs 同步）：「开始接水请求」「状态轮询与自动结算」「设备管理」三节按新行为改写。

### 删除

- 无。

### 明确不建

- 不引入 drink_798 的 `Get.snackbar` 配色常量：提示继续走 superhut 的 `showAppSnackBar`。
- 不引入「使用已有 Token 登录」。
- 不移植drink_798 的 `DeviceStatus` 文件本体：superhut 按自身分层放在 `lib/pages/drink/api/` 下并遵循既有命名。
- 不改动 798 之外的页面、全局主题与依赖清单。

## 来源覆盖

覆盖边界：drink_798 提交 `7380c52` 中与「798 设备控制接口调用、接水流程控制、扫码添加设备」直接相关的增量，即 `lib/core/services/drink_api_service.dart`、`lib/core/models/device_status.dart`、`lib/features/home/home_controller.dart` 的 `startDrinking` / `_startStatusCheck` / `scanAndAddDevice` / `stopDrinking`，以及 `test/core/services/drink_api_service_request_test.dart`、`test/features/home/home_page_ui_test.dart` 中与上述行为对应的断言。边界外内容（drink_798 的 `.gitignore`、Comet 归档文档、UI 布局与配色）不纳入。

上游佐证：cc2562/superhut commit `61c5e076`（2026-10-18，"修复喝水功能无法使用的问题"），其取值为实测来源；本 change 同步的是 drink_798 消化后的版本（同一形状，但遵循 superhut 自身的分层与提示原语）。

| 来源条目与位置 | 读取状态 | 需要保留的内容 | Spec 位置 | 验收 ID | 覆盖状态 | 理由或替代关系 |
| --- | --- | --- | --- | --- | --- | --- |
| S1：drink_798 `drink_api_service.dart:379-417`（`startDrinking` ptype 参数） | complete | `ptype` 缺省钱包 91，可注入；常量公开 | specs/drink-798 的「开始接水请求」 | A1 | covered | 上游 61c5e076 实测取值 |
| S2：drink_798 `home_controller.dart:348-380`（支付回退） | complete | 钱包失败回退 21 一次；`-99` 不回退；回退成功进入接水态 | specs/drink-798 的「开始接水请求」 | A2 | covered | 同上 |
| S3：drink_798 `home_controller.dart`（预检）与 `device_status.dart` | complete | 预检失败不拦截；离线/禁用分别提示；占用中同步可结算态不重发 start | specs/drink-798 的「开始接水请求」与「状态轮询与自动结算」 | A3 | covered | 提示原语换 superhut 的 snackbar |
| S4：drink_798 `device_status.dart`（三态解析） | complete | `device.status` 0 离线；`gene.status` 99 空闲、98 禁用 | specs/drink-798 的「开始接水请求」 | A3 | covered | 文件落在 superhut 自己的 api 层 |
| S5：drink_798 `drink_api_service.dart:469-499`（dev/status 请求形状） | complete | `did` + `more=false`，无 `promo`、无 `sign` | specs/drink-798 的「开始接水请求」 | A4 | covered | 上游实测形状 |
| S6：drink_798 `drink_api_service.dart:419-438`（dev/end rcp） | complete | `dev/end` 查询参数 `did` + `rcp=false` | specs/drink-798 的「开始接水请求」 | A5 | covered | 上游实测形状 |
| S7：drink_798 `drink_api_service.dart:359-382`（favo remove 1/0） | complete | `remove` 以 `1`/`0` 上线 | specs/drink-798 的「开始接水请求」 | A5 | covered | 上游实测形状；drink_798 布尔形态未实测过 |
| S8：drink_798 `drink_api_service.dart:501-526`（qr/use） | complete | 二维码末段先经 `qr/use` 换设备 ID；空编号不发请求；失败回退末段 | specs/drink-798 的「设备管理」 | A6 | covered | 官方扫码入口同源 |
| S9：drink_798 `home_controller.dart`（轮询 30 分钟上限） | complete | 轮询开始时间 + 30 分钟上限 | specs/drink-798 的「状态轮询与自动结算」 | A7 | covered | superhut 已有代际计数，叠加时间上限 |
| S10：drink_798 请求头集合（不发 `ApplicationType` 等） | complete | 维持两个头 + 15s 超时，不随本次改动回退 | specs/drink-798 的既有要求 | — | background | 已由 sync-ilife798-updates 覆盖并有既有测试守护 |

# 非目标

- 不移植签名代码；任何 798 请求都不带 `sign`（drink_798 已实测服务端不校验签名）。
- 不改动 798 之外的页面（课表、查分、热水、评教等）与全局 `AppTheme`。
- 不改平台配置、构建脚本、依赖清单。
- 不引入「使用已有 Token 登录」。
- 不改动登录页、设备列表/网格布局、拖拽排序与设备备注（上一轮已同步的能力）。

# 验收示例

- A1：点击「开始接水」成功路径下，发往 `/api/v1/dev/start` 的查询参数中 `ptype` 为 `91`；其余参数仍为 `did`、`upgrade=true`、`args=`（空串）、`rcp=false`、`cnt=1`，无 `stype`、无 `sign`；有单元测试逐字断言。
- A2：钱包支付（`ptype=91`）返回失败且失败码非 `-99` 时，自动以 `ptype=21` 再发一次 `dev/start`；第二次成功则进入接水态并只重试一次（出现 `[91, 21]` 两次请求）；`code == -99` 时不重试（只有一次请求）；有按分支断言请求序列的测试。
- A3：点击开始时的设备状态预检按三态分支：`device.status == 0`（离线）不发开始请求并提示设备离线；`gene.status == 98`（禁用）不发开始请求并提示联系管理员；链路在线但 `gene.status` 既非 99 也非 98（占用中）不发开始请求、同步进入可结算态并开始状态轮询；状态查询本身失败（网络异常）时不拦截，仍发开始请求；有覆盖四条分支的测试。
- A4：`GET /ui/app/dev/status` 的查询参数恰为 `did` 与 `more=false`，不含 `promo`、不含 `sign`；响应按 `device.status` 与 `device.gene.status` 解析为离线 / 禁用 / 空闲 / 运行中四类判定；有单元测试断言参数集与三类响应解析。
- A5：`GET /dev/end` 的查询参数为 `did` 与 `rcp=false`；`GET /dev/favo` 的 `remove` 以 `1`（取消收藏）/`0`（收藏）上线；有单元测试断言两个请求的线上形状。
- A6：扫码添加设备时，二维码末段先经 `GET /qr/use?id=<末段>` 换取真实设备 ID：解析出设备 ID 时以该 ID 收藏；响应无设备或请求失败时回退二维码末段收藏；二维码末段为空时不发起任何请求；有覆盖三条路径的测试。
- A7：状态轮询自开始起 30 分钟后自动停止，不再发起状态查询；既有代际丢弃、连续空闲计数与结算即停轮询的行为不变；有单元测试断言轮询停止。
- A8：798 之外的页面与全局主题文件未被修改；`flutter analyze` 无告警，`flutter test` 全部通过（含按新接口形状更新的既有测试）。

# 约束与不变量

- superhut 现有的健壮性机制必须保留：控制器 `dispose` 后丢弃迟到结果、设备列表请求去重、`favoDevice` 按 key 去重、状态轮询的代际计数与 `requiredAvailablePolls`、单一登录跳转。这些是 `test/pages/drink/function_drink_logic_test.dart` 与 `function_drink_page_test.dart` 的既有断言对象。
- 新增的轮询上限只与代际计数叠加，不替换它；达到上限时静默停止，不弹提示。
- 798 提示沿用 superhut 的 `showAppSnackBar` 原语与 `AppSnackBarType`（离线/禁用/占用→info 或 error 语义、回退成功→success、登录过期→warning），不引入 drink_798 的 `Get.snackbar` 配色。
- 请求头集合、超时、Token 时序容错维持 sync-ilife798-updates 已交付的形态，本 change 不回退、不重复实现。
- 预检与回退都发生在控制器层；`DrinkApi` 接口层保持纯请求：新增 `deviceStatus` / `resolveQrDevice` 方法仍只做「请求 + 解析」，不持有业务策略。
- `_drinkOperationInFlight` 继续作为开始/结算的唯一并发闸门；预检与回退属于同一次开始操作，不引入新的并发状态。
- 存储键不变（`drink798UsrApiToken`、`hui798IsLogin`），不新增存储键。

# 决定

- [2026-10-18，用户确认] 设备被占用（非离线、非禁用、非空闲）时与 drink_798 完全一致：提示「设备正在使用中，可点击结算结束本次使用」，同步进入可结算态并开始状态轮询——用户可能之前开过水，点结算能结束那一单。
- [2026-10-18，来源事实] drink_798 已实测：`ptype=91`（钱包）与 `21`（支付宝免密）均为服务端接受的取值，`0` 为旧静态逆向值、支付语义未确证；`dev/end` 带 `rcp=false`、`dev/favo` 的 `remove` 上线 `1/0`、`dev/status` 请求 `did`+`more=false` 为上游 cc2562/superhut `61c5e076` 实测形状。
- [2026-10-18，agent 决定] 同步以 drink_798 `7380c52` 消化后的版本为准，而不是上游 superhut 原始 patch：两仓库 798 代码同源，drink_798 版本已按本仓库分层与提示原语适配， Superhut 侧改动更小。
- [2026-10-18，agent 决定] `DeviceStatus` 模型放 `lib/pages/drink/api/drink_device_status.dart`，跟随 superhut 既有 `drink_result.dart` 的分层方式，不复刻 drink_798 的目录。

# 未决问题

（无）

# 验证期望

- `flutter analyze` 与 `flutter test` 在本仓库全部通过，作为客观门槛（沿用系统 Flutter 3.41.9，本仓库未固定 fvm 版本）。
- 接口层用 `_RecordingAdapter` 式 HTTP 替身断言最终 URL、查询参数与请求序列，不依赖真实服务端。
- 控制器逻辑用 `_FakeDrinkApi` 式替身断言预检分支、支付回退序列、`-99` 不回退与轮询上限。
- 真机支付回退（钱包余额不足时转支付宝）无法在本环境复现，属于已知限制：以请求序列测试与 drink_798 上游实测作为依据，不声称已对真实服务端验证。
