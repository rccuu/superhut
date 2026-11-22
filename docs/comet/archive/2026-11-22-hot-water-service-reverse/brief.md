# 目标

逆向分析智慧工大官方 App（`com.supwisdom.hut` 1.1.8）用水服务中的**热水（洗澡）功能**，弄清楚：

1. 开关热水的完整链路：登录鉴权 → 用水会话（openid / JSESSIONID）→ 设备列表 → 开阀 / 关阀 API 的每个请求与响应。
2. 为什么会出现「开水开不了、关水关不了」：服务端返回哪些错误码 / 消息、客户端在什么条件下失败、官方 App 是如何处理（重试、轮询、提示）的。
3. 评估 superhut 现有实现（`lib/utils/hut_user_api/hut_user_api_water.dart`、`lib/pages/water/logic.dart`）与官方行为的差异，回答「有没有可能做得更稳定」，并给出可落地的改进方案。

# 调查结论（已核实事实）

- 官方 IPA（49 MB）为 uni-app/Weex 容器：主包 `__UNI__AA068AD.wgt` 与原生二进制 `SWSuperApp` 中**均无任何用水业务字符串**（`zdRedirect`/`toSingleMenu`/`openWater`/`boiling`/`bathroom`/`waterpage`/`poscode` 命中 0，仅 `X-Id-Token` 命中 1 处于鉴权层）。
- 结论：热水功能与校园卡充值同模式 —— 全部业务逻辑在服务端 H5 `https://v8mobile.hut.edu.cn/waterpage/waterHomePage`，App 只负责鉴权并打开 WebView。因此：
  - 静态分析重心 = 带真实会话抓取该 H5 页面与其 JS，逆向开关阀的前端逻辑（调哪些接口、如何处理失败、是否轮询）；
  - REA 对原生二进制的分析仅用于确认鉴权链（mycas → idToken → zdRedirect 会话）；
  - 开关阀的真实请求-响应需真机动态抓取。
- superhut 已实现该链路（登录 → `zdRedirect/toSingleMenu?code=openWater` 换 openid+JSESSIONID → `/bathroom/*`、`/boiling/*`），现有已知薄弱点（待逆向证据确认）：
  - `startHotWater`/`stopHotWater` 失败时**丢弃服务端 message**，用户只看到通用「设备开启失败」；
  - 无重试；v8mobile Dio `receiveTimeout` 仅 3 秒，校园网慢时直接异常；
  - 开关后不回查设备状态，状态可能与服务端漂移。
- 动态分析环境已核对：设备 UDID `00008020-000168582290003A` 在线，frida 17.26.2 可用，iOS MCP 助手 `/tmp/phfwork/mc.py` 在位，逆向方法按 `JB-IOS-RE-PLAYBOOK.md`。

# 范围

## Source coverage

需求来源 = 用户原始请求文本（本文件「目标」一节为其完整保留）。无外部需求文档。
`/Users/tune/Documents/MDo/JB-IOS-RE-PLAYBOOK.md` 为方法参考（取证/实现参考材料，非需求来源），其中与本任务直接相关的约束：真机操作注意 SpringBoard 重启与 App 异常检测冷却、抓包走 App 进程内观测（H5 网络在 `com.apple.WebKit.Networking` XPC，frida 注不进去）、证据入 git。

| 来源条目 | 读取状态 | 需要保留的内容 | 对应产物 | 覆盖状态 |
| --- | --- | --- | --- | --- |
| 用户请求：逆向热水开关 API 与逻辑 | complete | 链路每步 API/请求/响应/错误处理 | 分析报告 | covered |
| 用户请求：解释开不了水/关不了水 | complete | 根因清单（带证据与置信度） | 分析报告 | covered |
| 用户请求：登录账号鉴权如何实现 | complete | 鉴权链还原（mycas → token → openid 会话） | 分析报告 | covered |
| 用户请求：能否更稳定 | complete | 差异清单 + 改进方案（视 Q1 决定是否实现） | 分析报告（+代码） | covered |
| 用户请求：只查用水服务里的热水 | complete | 范围边界：不做饮水机之外的服务 | 非目标 | covered |

## 目录结构

### 新建
- `docs/water_hot_reverse_findings.md`：完整逆向分析报告（链路、证据、根因、改进方案），证据文件（抓包记录、H5 JS 快照）随报告入 git。
- `test/` 下水务改动对应的单元测试文件（镜像 `lib/` 路径）。

### 修改
- `lib/utils/hut_user_api/hut_user_api_water.dart`：按分析结论实现稳定性改进（超时、重试、错误透传）。
- `lib/pages/water/logic.dart`：开/关阀失败时向用户透传服务端具体原因。

# Decisions

- Q1（2026-11-22 用户确认）：交付范围 = 逆向分析 + 在 superhut 实现稳定性改进。
- Q2（2026-11-22 用户确认）：授权真机实际开阀/关阀抓取真实请求-响应；开阀后立即关闭，控制计费在几分钱内。

# 非目标

- 不分析热水以外的校园服务（校园卡充值、电费、饮水机以外的任何功能）。
- 不逆向学校服务端代码；仅观察客户端可见行为与公开 HTTP 接口。
- 不做高频/批量开阀等可能影响水控系统或其他用户的操作。
- 不重构 water 页面 UI 视觉。

# 验收示例

- A1：分析报告完整记录开关热水链路每一步（鉴权换会话、设备列表、开阀、关阀、状态查询）的 URL、方法、关键请求头、请求体、响应结构与错误码，每步至少一处真实证据（抓包记录或 H5 JS 快照）支撑。
- A2：分析报告给出「开不了水 / 关不了水」的根因清单，每条标注证据来源（抓包 / H5 JS / 官方行为实测）与置信度（实锤 / 高度可能 / 存疑）。
- A3：分析报告给出 superhut 现有实现与官方行为的差异清单，以及每项差异对应的稳定性改进方案（含优先级）。
- A4：报告与证据文件提交入 git（docs/ 下），路径在报告开头列明。
- A5：`startHotWater`/`stopHotWater` 失败时，用户提示包含服务端返回的具体 `message`（不再只有固定通用文案）；服务端未返回 message 时回退通用文案。
- A6：开阀/关阀对瞬时网络错误（超时、连接类异常）自动重试，重试次数与判定条件在报告中明确，并有单元测试覆盖（成功不重试、可重试错误重试、不可重试错误不重试）。
- A7：水务接口的超时时间依据实测响应时间调整，具体数值写入报告，不再沿用 3 秒默认值。
- A8：`flutter analyze`（改动文件范围）与 `flutter test` 通过。
