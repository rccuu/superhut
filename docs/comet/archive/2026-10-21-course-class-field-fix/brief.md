# 目标

让课程详情弹层的「班级」信息显示教务系统返回的真实班级串，并把同一批真实响应里已经拿到、但尚未展示的课程元信息补进详情。

上一轮 change（course-class-and-inapp-update）按假设把普通课表 item 的 `ktmc` 字段接入 `Course.className`，当时依据的样本是 `coursemain.dart` 内 `testc()` 保留的 2025 春季学期响应，用户反馈同步后每一门课都显示「暂无班级信息」。

本轮已用当前学期（2026-2027-1）真实响应完成取证，事实结论与原假设不同（详见「# 取证结论」）：普通课表的 `ktmc` 字段有效且解析链路正确，真正的缺陷在实验课解析器不读班级字段；实验课的 `ktmc` 还带课程号后缀需要剥离；同时真实响应里还有「上课人数 / 学时 / 考核方式」等可展示字段尚未接入。本轮据此修正实现并保证用户重新同步后能显示真实班级与课程元信息。

# 取证结论（本轮实测，2026-10-21）

抓取方式：Agent 在本机用用户提供的账号密码经 CAS 登录 `mycas.hut.edu.cn` → `jwxtsj.hut.edu.cn`，用浏览器会话的 JWT Token 直接请求教务接口。当前学期 `2026-2027-1`（`getXnxqList` 的 `isdqxq=1`），节次模式 `kbjcmsid=94D51EECEBF4F9B4E053474110AC8060`。抓取覆盖第 7–16 周（本周有课的全部周次）。

## 班级相关

1. **普通课表 `ktmc` 有效**。`POST /njwhd/student/curriculum?xnxq01id=2026-2027-1&kbjcmsid=...&week=7` 返回 6 条 item，`ktmc` 分别为「智能建造2304班」「智能建造[2303-2304]班」，非空。
2. **现有普通课解析器正确**。用项目真实的 `GetSingleWeekClass` 解析该真实样本，6 门课的 `className` 全部等于 `ktmc` 原值（`flutter test` 实跑通过）。
3. **持久化与展示链路完整**。`Course.toJson`/`fromJson` 均含 `className`，`CourseDetailSheet` 与复制文本均读取 `course.className`。
4. **实验课响应同样含 `ktmc`，但 App 不读**。`POST /njwhd/teacher/courseScheduleExp?xnxq01id=2026-2027-1&week=7` 返回的 course 项中 `ktmc` = 「智能建造[2303-2304]班」，而 `GetSingleWeekExpClass.getSingleClass`（`lib/utils/course/get_course.dart:569-580`）构造 `Course` 时未传 `className` → 实验课永远为空。上一轮 D1 决策中「实验课无对应字段」的前提被实测推翻。
5. **实验课的 `ktmc` 带课程号后缀**。23 条实验课样本中 16 条形如「智能建造2304班0315374031」= 班级串 + `kch`（课程号）+ 2 位组号；另 7 条为纯班级串「智能建造[2303-2304]班」。实验课名单接口 `getCuarStudentListExp` 的 `baseData.pcname` 与 `ktmc` 同构，旁证该结构。普通课表的 `ktmc` 始终是纯班级串。
6. **用户当前学期的课以实验/实践课为主**。`nkbList` 6 门（毕业实习、生产实习、智能建造综合实训、工程结构大数据及应用、工程造价与管理课程设计、结构试验与工程监测技术），普通课表每周仅 6 条。实验课占比高是「每一门课都显示暂无班级信息」的主要来源。
7. **另一独立因素：本地课表缓存可能是旧数据**。课表持久化在 `course_schedules.json`（`Course.fromJson` 对缺失 `className` 回退空串），升级到含班级功能的版本后，若未重新同步，本地数据仍无班级；静默刷新受 `staleAfter=6h` 与课表来源类型约束，未必立即补齐。

## 可新增展示的课程元信息

8. **普通课表**额外可用字段：`peopleNumber`（上课人数，int，样本值 30/64/92）、`zxs`（学时，int，16/12/6/4/2）、`khfs`（考核方式，「考试」/「考查」）、`kch`（课程号）、`xqName`（校区，样本恒为「河西校区」，本学期无区分度）。
9. **实验课表**额外可用字段：`peopleNumber`（分组人数，**字符串**类型，样本值 15/30/64）、`classroomName`（教室，样本值「实训中心110」等）、`kkzc`（开课周次）、`syxmName`（实验项目名，App 已用于拼接课程名「课程名 实验：项目名」）、`kch`（课程号）。
10. **`peopleNumber` 可信度已交叉验证**：用实验课名单接口 `getCuarStudentListExp` 拉取同一 `pcid` 的学生名单，名单 15 条、接口声明的 `peopleNumber` 也是 15，完全吻合。
11. **实测排除的字段**：`buildingName`（名为 building 实测恒等于当前登录学生本人姓名，属教务侧塞错字段，展示会误导）；`xqNumber`（恒为 "2"，无信息量）；`jx0408id`/`xmid`/`pcid`（内部 ID）；`weekNoteDetail`（节次编号，内部用）。

# 范围

## 目录结构

### 新建

- `docs/comet/changes/course-class-field-fix/sample/curriculum_week7.json`（普通课表真实响应样本，脱敏后留证）
- `docs/comet/changes/course-class-field-fix/sample/course_schedule_exp_week7.json`（实验课表真实响应样本，脱敏后留证）

### 修改

- `lib/utils/course/coursemain.dart`：`Course` 模型新增 `peopleCount`（上课人数）、`creditHours`（学时）、`assessmentType`（考核方式）三个字段，含 `toJson`/`fromJson`/`sanitizedForShare`/分享码序列化
- `lib/utils/course/get_course.dart`：`GetSingleWeekExpClass.getSingleClass` 接入实验课 item 的 `ktmc`（剥离课程号后缀）与 `peopleNumber` → `className`/`peopleCount`
- `lib/utils/course/get_course.dart`：`GetSingleWeekClass.getSingleClass` 接入 `peopleNumber`/`zxs`/`khfs` → `peopleCount`/`creditHours`/`assessmentType`；`ktmc` 取值收紧为 trim 后非空才写入
- `lib/home/coursetable/widgets/course_table_widgets.dart`：详情弹层新增「上课人数」「学时」「考核方式」三行，与既有行同风格（空值回退文案、长文本换行、长按复制）
- `lib/home/coursetable/view.dart`：复制课程信息文本新增对应三行
- `lib/utils/widget_data_helper.dart`：`saveCourseDataForWidget` 的字段归一化补上三个新字段（否则小组件链路会丢数据）
- `test/utils/course/coursemain_test.dart`：新增实验课解析班级（剥离后缀）与三项元信息用例；用真实样本补普通课表断言
- `test/utils/course/`：以真实样本为 fixture 驱动的解析回归用例（样本内联固化，不依赖外部路径）

### 删除

（无）

### 明确不建

- 不新增任何「手动抓取/调试导出」入口到 App 内（抓取仅为本轮开发期取证手段，一次性完成）
- 不改动课表同步整体流程、学期选择、进度 UI
- 不新增分享码字段名以外的破坏性改动（`className` 保持原名，新字段用新名，旧版本读新码时按未知字段忽略）
- 不做强制清空本地课表缓存的破坏性迁移（缓存问题通过重新同步解决，见 D7）
- 不展示实测已排除的字段（`buildingName`/`xqNumber`/内部 ID）

## Source coverage

不适用：需求来自用户口头描述。上一轮 change 的归档 brief/spec 是背景参考而非本轮需求来源；本轮的需求事实来源是本轮抓取的当前学期真实响应样本，样本落地后作为字段取值的事实证据核对解析实现，不触发源文档完整覆盖模式。

# 非目标

- 不重做上一轮 change 的 UI 框架（详情弹层的信息行组件、班级行位置、分享码兼容机制均已交付且保持不变，本轮只补数据来源与新增三行）
- 不改 `Course` 模型既有字段的序列化格式（`className` 字段名与向后兼容约定不变，新字段用新名追加）
- 不处理教务系统接口本身的数据缺失（若教务侧确实不再返回某个字段，App 只能如实回退显示）
- 不展示实测已排除的字段（`buildingName`、`xqNumber`、内部 ID）
- 不做实验课班级的猜测性接入（已由样本证实实验课响应含班级字段，本轮按实测结构接入）

# 验收示例

- Scenario: 用真实抓取的实验课样本驱动解析，含课程号后缀的 `ktmc`（如「智能建造2304班0315374031」）解析后 `Course.className` 为剥离后的「智能建造2304班」。
- Scenario: 用真实抓取的普通课表样本驱动解析，6 门课的 `className` 全部等于样本 `ktmc` 原值，无一条为空。
- Scenario: 实验课响应中 `ktmc` 为纯班级串（如「智能建造[2303-2304]班」）时解析结果原样保留，不误剥离。
- Scenario: 实验课响应中 `ktmc` 缺失或为空的课程条目解析后 `Course.className` 为空串，详情弹层显示「暂无班级信息」回退文案，其余信息行不受影响。
- Scenario: 同步后打开课程详情，详情信息列表出现「上课人数」「学时」「考核方式」三行，内容分别等于教务返回的 `peopleNumber`、`zxs`、`khfs`（普通课）；实验课的「上课人数」等于其分组人数。
- Scenario: 「上课人数」「学时」「考核方式」任一在响应中缺失或为空时，对应行显示回退文案，不显示空白，其余行不受影响。
- Scenario: 「复制课程信息为文本」的输出在既有行之后包含「上课人数」「学时」「考核方式」三行。
- Scenario: 含新字段的课表生成分享码，旧版本应用导入该分享码不报错（未知字段被忽略）；新版本导入后详情弹层显示三项信息。
- Scenario: 既有旧课表数据（本地缓存无这些字段）的详情弹层与复制文本行为保持上一轮交付的现状不变（回退文案、复制含班级行）；用户重新同步一次后，新字段显示真实值。
- Scenario: 单元测试用真实样本字段驱动：普通课表与实验课表各覆盖「有班级」「无班级」两分支，并覆盖三项元信息的解析与序列化，均有断言。

# 约束与不变量

- 解析修正只依据真实样本字段，不猜测字段名。
- `Course` 的 JSON 序列化/分享码兼容约定不变：`className` 字段名不变、`fromJson` 缺失回退空串、`sanitizedForShare` 保留班级；新增三字段同样「缺失回退空值」，旧数据与旧分享码导入时显示回退文案。
- 抓取凭证（账号密码、Token）只在本机临时使用，不写入任何仓库文件、日志或 brief；样本文件中的 `jx0408id`、`pcid` 等可关联个人的标识已脱敏。
- 不得为"造出班级/人数"而编造回退拼接逻辑；字段缺失时如实显示回退文案。
- 不引入新依赖；测试沿用现有 `coursemain_test.dart` 的构造方式。
- 班级串中的合班逗号串（如「土木工程2307班,智能建造[2303-2304]班」）保持原样，不做拆分或改写。
- 实验课班级串的课程号后缀剥离规则：仅当 `ktmc` 以 `kch`（课程号）开头时，截断到 `kch` 之前的部分作为班级串；否则原样保留（覆盖「智能建造[2303-2304]班」这类纯班级串）。
- 「上课人数」在普通课表示选课人数、在实验课表示分组人数，两者语义不同但都是教务侧该条记录的 `peopleNumber`，展示文案统一为「上课人数」，不做区分说明。
- 实验课 `peopleNumber` 是字符串、普通课是整数，解析时统一规范为字符串展示（去空白；非数字原样保留）。

# 决定

- D1 抓取方式：由 Agent 在本机用用户提供的账号密码经 CAS 登录，用浏览器会话 Token 直接请求教务接口；不通过 App 内加调试功能。【用户已确认，并由用户授权提供凭证】
- D2 抓取范围：当前学期 2026-2027-1，第 7–16 周（本周有课的全部周次），普通课表 + 实验课表两类响应。【用户已确认：Q1b 选 A；抓取过程中发现更多周次有课，顺带全量抓取】
- D3 实验课 `ktmc` 已实测存在 → 本轮把它接入 `Course.className`（修正上一轮 D1 中「实验课无对应字段」的失效前提）。
- D4 样本文件脱敏后留存到 change 产物目录作为事实证据；`testc()` 中 2025 春季的旧样本字符串保留不动（它仍是普通课表结构的历史事实，且无调用方）。
- D5 若实测发现教务系统当前响应确实不含任何班级字段，维持「暂无班级信息」回退文案为最终结果，如实告知用户教务侧数据情况，不编造数据、不探索其他数据来源。【用户已确认：Q2 选 A】——本轮实测不触发该分支。
- D6 班级串按教务原样展示（含合班逗号串），不解析、不拆分、不排序。
- D7 本地课表缓存的补齐方式：用户在新版 App 中重新执行一次课表同步即可刷新出班级与元信息；不写破坏性迁移清空用户本地课表。
- D8 详情新增三行：上课人数、学时、考核方式；课程号与校区不展示（用户已确认选 A+B+C）。【用户已确认】
- D9 实验课班级串剥离课程号后缀，展示为纯班级串，与普通课表观感一致。【用户已确认】
- D10 复制文本与分享码都带上三项新信息。【用户已确认】

# 未决问题

（无未决项；凭证已由用户授权提供，字段取舍与班级串格式已确认。取证结论已写入 brief，剩余为实现细节。）

# 验证预期

- `flutter analyze` 通过；`flutter test` 全量通过（含按真实样本驱动的普通课表 + 实验课解析用例、模型序列化用例、详情弹层与复制文本用例）。
- 手工验收：用户在真机重新同步当前学期课表后，普通课与实验课的详情弹层均显示真实班级、上课人数、学时、考核方式。
