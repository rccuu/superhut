---
generated_from_state_version: 10
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 2
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-10-21T06:36:03.528Z
- 摘要: A1-A10 全部通过。实现侧：Course 模型新增 peopleCount/creditHours/assessmentType 三字段并贯通 toJson/fromJson/sanitizedForShare（lib/utils/course/coursemain.dart:112-181）；普通课解析接入 ktmc/peopleNumber/zxs/khfs（lib/utils/course/get_course.dart:339-342），实验课接入 ktmc（经 _readExperimentClassName 剥离课程号后缀）与 peopleNumber（get_course.dart:625-629）；详情弹层新增三行回退文案（lib/home/coursetable/widgets/course_table_widgets.dart:440-451）；复制文本新增三行（lib/home/coursetable/view.dart:1219-1221）；小组件归一化补三字段（lib/utils/widget_data_helper.dart:32-34）。测试侧：真实样本内联于 test/utils/course/course_class_display_test.dart（普通课表样本与 docs/comet/changes/course-class-field-fix/sample/curriculum_week7.json 逐字节一致；实验课样本比留证文件多一条带课程号后缀的条目，字段结构一致），覆盖有/无班级两分支与三项元信息解析；coursemain_test.dart:1422/1449/1465 覆盖序列化、旧数据回退与分享码；course_detail_sheet_test.dart:177/200 与 course_copy_text_test.dart:102/151 覆盖详情弹层与复制文本的有值/回退。Runtime 两条检查（flutter analyze、flutter test）均为 passed/exit 0，测试日志确认新测试文件已执行、全量 709 项通过；我另跑 4 个定向测试文件全绿。唯一遗留：真机手工验收未执行、旧版本 App 导入新分享码未做跨版本实测（已由 Builder 在 known_limits 中声明）。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | Scenario: 用真实抓取的实验课样本驱动解析，含课程号后缀的 `ktmc`（如「智能建造2304班0315374031」）解析后 `Course.className` 为剥离后的「智能建造2304班」。 | 实现：lib/utils/course/get_course.dart:38-57 新增 _readExperimentClassName，实验课 getSingleClass 在 :625-628 传入 rawClassName=_readDisplayValue(ktmc)。剥离规则：以 kch 为锚点（:42 取 tempClass['kch']），取 indexOf(courseCode)（:45），要求锚点前非空（:46 courseCodeIndex <= 0 时原样返回），且其后缀为空或 ≤3 位纯数字（:50-53 _isAllDigits），否则原样保留；命中则截取前缀并 trim（:55-56）。测试：test/utils/course/course_class_display_test.dart:64-87 真实实验课样本用例，ktmc='智能建造2304班0315374031'（kch='03153740'）解析结果断言为 '智能建造2304班'（:78）；同文件 :121-133 另有独立构造用例覆盖同一形态。定向运行该文件全部通过（Runtime 全量 flutter test 日志亦含该文件，:2632-2635 行）。 |
| A2 | passed | brief.md | Scenario: 用真实抓取的普通课表样本驱动解析，6 门课的 `className` 全部等于样本 `ktmc` 原值，无一条为空。 | 实现：lib/utils/course/get_course.dart:339 className: _readDisplayValue(tempClass['ktmc'])，trim 后非空才写入（:28-34 null/空白统一返回空串）。样本一致性核对（我自己做的字节级比对）：测试内联的 _realCurriculumWeek7Json 与留证文件 docs/comet/changes/course-class-field-fix/sample/curriculum_week7.json 逐字节相同（Python 比对结果 True，JSON 解析后也相等），样本第 7 周 6 条 item 的 ktmc 为「智能建造2304班」「智能建造[2303-2304]班」，与 brief 取证结论一致。测试：test/utils/course/course_class_display_test.dart:27-40 断言课程数 6、每条 className 非空、取值集合等于 {智能建造2304班, 智能建造[2303-2304]班]}。定向与全量测试均通过。 |
| A3 | passed | brief.md | Scenario: 实验课响应中 `ktmc` 为纯班级串（如「智能建造[2303-2304]班」）时解析结果原样保留，不误剥离。 | 实现：get_course.dart:45-53 只有在 ktmc 中确实包含该条目 kch 且其后缀是 ≤3 位纯数字时才剥离；纯班级串「智能建造[2303-2304]班」不含 kch（:46 indexOf 返回 -1 → courseCodeIndex <= 0 → 原样返回），且该串本身含非数字字符，即使误命中后缀检查也会被 _isAllDigits 拦下。测试：test/utils/course/course_class_display_test.dart:82-86 真实样本中 ktmc='智能建造[2303-2304]班'、kch='03153761' 断言原样保留；:135-147 独立构造用例同样断言原样保留。定向测试通过。 |
| A4 | passed | brief.md | Scenario: 实验课响应中 `ktmc` 缺失或为空的课程条目解析后 `Course.className` 为空串，详情弹层显示「暂无班级信息」回退文案，其余信息行不受影响。 | 实现：get_course.dart:28-34 _readDisplayValue 对 null/''/纯空白统一返回空串；实验课 className 经 :625-628 传入空串时 _readExperimentClassName（:42 kch 非空但 :45 indexOf('')= -1 → courseCodeIndex<=0 → 返回 rawClassName 即空串）。测试：test/utils/course/course_class_display_test.dart:149-163 循环覆盖 null/''/' ' 三态，断言 parsed?.className isEmpty。展示回退：lib/home/coursetable/widgets/course_table_widgets.dart:437 班级行 text: course.className.isEmpty ? '暂无班级信息' : ...；其余信息行（周数/时间/教师/地点）各自独立渲染（:425-452），不受班级空值影响。回退文案用例见 course_detail_sheet_test.dart:200-215（断言 暂无上课人数信息/暂无学时信息/暂无考核方式信息）与 course_copy_text_test.dart:151-191（断言 班级：暂无班级信息 等四条）。 |
| A5 | passed | brief.md | Scenario: 同步后打开课程详情，详情信息列表出现「上课人数」「学时」「考核方式」三行，内容分别等于教务返回的 `peopleNumber`、`zxs`、`khfs`（普通课）；实验课的「上课人数」等于其分组人数。 | 实现：普通课 lib/utils/course/get_course.dart:340-342 peopleCount=peopleNumber、creditHours=zxs、assessmentType=khfs，均经 _readDisplayValue 规范为字符串（普通课接口为 int，toString 后一致）；实验课 :629 peopleCount=peopleNumber（实验课为字符串类型，同样规范）。展示：course_table_widgets.dart:440-451 新增三行。测试：course_class_display_test.dart:42-62 用真实普通课样本断言 '30'/'16'/'考试' 与 '64'/'12'/'考查'；:79/:86 断言实验课分组人数 '15' 与 '64'（即其分组人数）。详情弹层渲染用例见 course_detail_sheet_test.dart:177-198（断言 30/16/考试 均存在）。定向与全量测试通过。 |
| A6 | passed | brief.md | Scenario: 「上课人数」「学时」「考核方式」任一在响应中缺失或为空时，对应行显示回退文案，不显示空白，其余行不受影响。 | 实现：缺失/空值在解析层统一为 ''（get_course.dart:28-34），展示层三行各带独立回退文案：course_table_widgets.dart:442 暂无上课人数信息、:446 暂无学时信息、:450 暂无考核方式信息；复制文本 view.dart:1219-1221 同样各自回退。三行互不影响（每行独立 _CourseDetailItem）。测试：course_detail_sheet_test.dart:200-215 断言三条回退文案均出现且不显示空白（find.text 精确匹配回退串，若行内仍显示空白则断言不成立）；course_copy_text_test.dart:151-191 断言复制文本含「上课人数：暂无上课人数信息」等。逐项「仅缺失其一」的组合未单独建用例，但因三行取值与文案互相独立、且解析层统一走同一 _readDisplayValue，缺失组合与全缺失路径同构。 |
| A7 | passed | brief.md | Scenario: 「复制课程信息为文本」的输出在既有行之后包含「上课人数」「学时」「考核方式」三行。 | 实现：lib/home/coursetable/view.dart:1211-1222 _buildCourseCopyText 在既有行（课程名称/周数/时间/教师/班级/地点）之间新增「上课人数：」「学时：」「考核方式：」三行（:1219-1221），位置在既有行之后、仍在既有行序列内。测试：test/home/coursetable/course_copy_text_test.dart:102-149 通过 mock Clipboard.setData 捕获真实剪贴板写入，断言含 '班级：智能建造2304班'、'上课人数：30'、'学时：16'、'考核方式：考试'。定向测试通过。 |
| A8 | passed | brief.md | Scenario: 含新字段的课表生成分享码，旧版本应用导入该分享码不报错（未知字段被忽略）；新版本导入后详情弹层显示三项信息。 | 实现：lib/utils/course/coursemain.dart:143-146 toJson 含 className/peopleCount/creditHours/assessmentType；:161-164 fromJson 逐字段读取；:178-181 sanitizedForShare 保留四字段且仍剥离 pcid（:177 pcid: ''）。分享码链路：SavedCourseSchedule.toShareJson（coursemain.dart:377-392）经 _sanitizeCoursesForShare（:241-247）+ _encodeCourses→course.toJson（:249-255）落盘，buildCourseScheduleShareCode（:2161-2169）gzip+base64 打包；parseCourseScheduleShareCode（:2196-2215）反解后走 SavedCourseSchedule.fromJson → _parseCourseDataMap → Course.fromJson。测试：coursemain_test.dart:1465-1504 走完整 buildCourseScheduleShareCode → parseCourseScheduleShareCode 往返，断言四项全部保留。旧版本兼容：仓库内无旧版本二进制可实测；但「按字段名序列化 + fromJson 只读已知键、忽略未知键」在当前与 HEAD 版本的 fromJson 实现一致（HEAD 版本 coursemain.dart:142-154 同样逐字段读取），旧版本遇到新增键不会报错，该结论属代码事实推导而非实测。 |
| A9 | passed | brief.md | Scenario: 既有旧课表数据（本地缓存无这些字段）的详情弹层与复制文本行为保持上一轮交付的现状不变（回退文案、复制含班级行）；用户重新同步一次后，新字段显示真实值。 | 旧数据兼容：coursemain.dart:161-164 fromJson 对缺失 peopleCount/creditHours/assessmentType 回退空串（className 同），不触发任何清理/迁移；归档读写仅做 toJson/fromJson 往返（coursemain.dart:457-463 archive toJson → CourseScheduleArchive.fromJson → _parseSavedCourseSchedules → Course.fromJson），无破坏性改写。测试：coursemain_test.dart:1449-1463 断言缺字段时四项均为空串；course_copy_text_test.dart:151-191 断言旧数据下复制文本为「班级：暂无班级信息」「上课人数：暂无上课人数信息」等回退文案（上一轮交付的班级行仍在）；course_detail_sheet_test.dart:200-215 断言详情弹层回退。重新同步后新字段为真实值：coursemain.dart:2480-2578 saveClassToLocal 用快照 courseData 整体覆盖写入（:2543-2558 copyWith(courseData: snapshot.courseData)），新解析的数据带新字段；解析侧由真实样本测试（course_class_display_test.dart:42-62）保证值来自接口字段。 |
| A10 | passed | brief.md | Scenario: 单元测试用真实样本字段驱动：普通课表与实验课表各覆盖「有班级」「无班级」两分支，并覆盖三项元信息的解析与序列化，均有断言。 | 测试以真实样本字段驱动：test/utils/course/course_class_display_test.dart 内联固化真实样本（:9-11 普通课表，与留证 sample/curriculum_week7.json 逐字节一致；:17-19 实验课，结构同源），覆盖普通课表有班级（:27-40，6 门课 className 全非空且等于样本 ktmc 原值）与实验课有班级（:64-87，含剥离与原样两分支）、无班级分支（:149-163，ktmc 缺失/空串/空白三态）；三项元信息解析断言见 :52-61 与 :79/:86；序列化断言见 coursemain_test.dart:1422-1447（toJson/fromJson/sanitizedForShare 四字段）、:1449-1463（旧数据回退）、:1465-1504（分享码往返）；详情弹层与复制文本断言见 course_detail_sheet_test.dart:177-215、course_copy_text_test.dart:102-191。Runtime 全量 flutter test 日志确认 course_class_display_test.dart 与 course_copy_text_test.dart 均已执行并计入 709 项全通过；我另跑 4 个相关测试文件（71 项）亦全通过。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze | analyze | . | passed | 0 | 3505 ms |
| flutter test | test | . | passed | 0 | 20362 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter analyze: passed — No issues found! (ran in 2.7s)
- flutter test（全量）: passed — 709 项全部通过
- flutter test test/utils/course/course_class_display_test.dart: passed — 6 项通过
- flutter test test/utils/course/coursemain_test.dart: passed — 54 项通过
- flutter test test/home/coursetable/course_detail_sheet_test.dart: passed — 9 项通过
- flutter test test/home/coursetable/course_copy_text_test.dart: passed — 2 项通过
- 已知限制: 真机手工验收未执行：需用户在 App 内重新同步当前学期课表，确认普通课与实验课详情弹层显示真实班级、上课人数、学时、考核方式。
- 已知限制: 旧版本 App 导入含新字段的分享码不报错这一点未做跨版本实测，只依据「按字段名序列化 + fromJson 忽略未知字段」的既有约定推导。
- 已知限制: 实验课班级串剥离规则以真实样本中出现的「班级+课程号+≤3位数字组号」形态为准；若教务侧出现其它后缀形态，会走原样保留分支。

## 阻塞项

_无。_

## 风险与跳过的工作

- 留证样本文件 docs/comet/changes/course-class-field-fix/sample/course_schedule_exp_week7.json 只含 1 条实验课 course，而测试内联的实验课样本含 2 条（多出带课程号后缀的「智能建造2304班0315374034031」形态那条）。该条只存在于测试内联样本中，仓库内无其它留证可交叉核对该具体取值，属未独立留证的样本条目。
- A8 的「旧版本应用导入含新字段的分享码不报错」未做跨版本实测：仓库内只有当前版本（fromJson 忽略未知字段），旧版本二进制不在本工作区，无法直接观测；结论基于「按字段名序列化 + fromJson 逐字段读取、忽略未知键」的代码事实推导。
- A9 的「用户重新同步一次后新字段显示真实值」依赖真实教务响应，本次仅以真实样本驱动的解析测试覆盖，未在真机执行同步。
- 实验课班级串剥离规则只覆盖「班级 + kch + ≤3 位纯数字组号」形态；若教务侧出现其他后缀形态（如组号超过 3 位或含非数字），会走原样保留分支。
- 本次改动的新增代码未通过 dart format（dart format --output=none --set-exit-if-changed 报告 lib/utils/course/get_course.dart、lib/home/coursetable/widgets/course_table_widgets.dart 及 3 个测试文件需要重排）。该现象在 HEAD 版本同样存在（同一命令对 HEAD 抽取的 4 个文件同样报 changed），属仓库既有风格状态而非本次回归；CI 未配置格式检查。
- Brief 提到的「本轮抓取 23 条实验课样本、16 条带课程号后缀、7 条纯班级串」只有第 7 周的 2 条进了留证文件，其余周次样本未留证，无法独立复核该统计口径。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 0 | 0 | recovery | — | Native confirmed acceptance criteria changed | 2026-10-21T05:14:44.399Z |
| 2 | 1 | 1 | pass | — | A1-A10 全部通过。实现侧：Course 模型新增 peopleCount/creditHours/assessmentType 三字段并贯通 toJson/fromJson/sanitizedForShare（lib/utils/course/coursemain.dart:112-181）；普通课解析接入 ktmc/peopleNumber/zxs/khfs（lib/utils/course/get_course.dart:339-342），实验课接入 ktmc（经 _readExperimentClassName 剥离课程号后缀）与 peopleNumber（get_course.dart:625-629）；详情弹层新增三行回退文案（lib/home/coursetable/widgets/course_table_widgets.dart:440-451）；复制文本新增三行（lib/home/coursetable/view.dart:1219-1221）；小组件归一化补三字段（lib/utils/widget_data_helper.dart:32-34）。测试侧：真实样本内联于 test/utils/course/course_class_display_test.dart（普通课表样本与 docs/comet/changes/course-class-field-fix/sample/curriculum_week7.json 逐字节一致；实验课样本比留证文件多一条带课程号后缀的条目，字段结构一致），覆盖有/无班级两分支与三项元信息解析；coursemain_test.dart:1422/1449/1465 覆盖序列化、旧数据回退与分享码；course_detail_sheet_test.dart:177/200 与 course_copy_text_test.dart:102/151 覆盖详情弹层与复制文本的有值/回退。Runtime 两条检查（flutter analyze、flutter test）均为 passed/exit 0，测试日志确认新测试文件已执行、全量 709 项通过；我另跑 4 个定向测试文件全绿。唯一遗留：真机手工验收未执行、旧版本 App 导入新分享码未做跨版本实测（已由 Builder 在 known_limits 中声明）。 | 2026-10-21T06:36:03.528Z |



## 结论

A1-A10 全部通过。实现侧：Course 模型新增 peopleCount/creditHours/assessmentType 三字段并贯通 toJson/fromJson/sanitizedForShare（lib/utils/course/coursemain.dart:112-181）；普通课解析接入 ktmc/peopleNumber/zxs/khfs（lib/utils/course/get_course.dart:339-342），实验课接入 ktmc（经 _readExperimentClassName 剥离课程号后缀）与 peopleNumber（get_course.dart:625-629）；详情弹层新增三行回退文案（lib/home/coursetable/widgets/course_table_widgets.dart:440-451）；复制文本新增三行（lib/home/coursetable/view.dart:1219-1221）；小组件归一化补三字段（lib/utils/widget_data_helper.dart:32-34）。测试侧：真实样本内联于 test/utils/course/course_class_display_test.dart（普通课表样本与 docs/comet/changes/course-class-field-fix/sample/curriculum_week7.json 逐字节一致；实验课样本比留证文件多一条带课程号后缀的条目，字段结构一致），覆盖有/无班级两分支与三项元信息解析；coursemain_test.dart:1422/1449/1465 覆盖序列化、旧数据回退与分享码；course_detail_sheet_test.dart:177/200 与 course_copy_text_test.dart:102/151 覆盖详情弹层与复制文本的有值/回退。Runtime 两条检查（flutter analyze、flutter test）均为 passed/exit 0，测试日志确认新测试文件已执行、全量 709 项通过；我另跑 4 个定向测试文件全绿。唯一遗留：真机手工验收未执行、旧版本 App 导入新分享码未做跨版本实测（已由 Builder 在 known_limits 中声明）。
