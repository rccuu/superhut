---
generated_from_state_version: 8
---

# 验证

## 当前结果

- 结果: **已归档**
- 验证情况: **已完成检查，验证结果已确认**
- 目标周期: 1
- 迭代: 1
- 验证器尝试次数: 1
- 完成时间: 2026-10-22T01:23:28.110Z
- 摘要: 独立核验 8 项验收全部通过。实现与 brief/spec 一致：8 个详情行统一为「图标 + 固定宽标签列 + 值列」；上课人数/学时在值为纯数字时追加「人」「学时」单位，非数字值原样显示；空值保留标签并以弱化色显示「暂无」；长按复制与 SnackBar 均为「字段名：值」形式；复制课程信息文本的数值行带单位且空值回退文案保持原样；实验课缺学时与考核方式时这两行显示「暂无」、其余行正常。行高由 66px 收到 48px、8 行合计 384px（实测详情组 391px 含 7 条 1px 分隔线），弹层可视高度内可完整显示的详情行由 5 行增至 7 行；实现者汇报的 358px 为标签文字间的跨度，属度量口径差异而非未达标。额外运行的检查：flutter test test/home/coursetable/course_detail_sheet_test.dart test/home/coursetable/course_copy_text_test.dart test/core/ui/performance_boundaries_test.dart 全部通过（108 个用例）；另在 /tmp 下运行 3 个临时 out-of-repo widget 测试独立测量行高/分组高度、可视行数、标签与单位渲染、空值回退、长按复制与提示文案。未重复执行 Runtime 已跑过的全量 flutter analyze 与全量 flutter test（两者 exit 0）。全程只读：未修改任何实现/测试/文档文件，git status 与核验前一致。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | Scenario: 打开课程详情弹层，8 个详情行各自显示字段名标签（周数、时间、教师、班级、上课人数、学时、考核方式、地点），不再只显示裸值。 | 实现：lib/home/coursetable/widgets/course_table_widgets.dart:449-493 构造 8 个 _CourseDetailItem，每个都带 label（周数/时间/教师/班级/上课人数/学时/考核方式/地点）；:591-599 渲染时传入 label: item.label；_CourseDetailRow 在 :1017-1033 渲染固定 64px 标签列（弱化色 onSurfaceVariant，w600），值另起一列右对齐，结构上不存在「只有图标+裸值」的行。独立复核：临时 out-of-repo widget 测试渲染同一张弹层，8 个标签各命中 1 次，值列文本（7-10,13-16 / 教师 / 班级等）独立存在。 |
| A2 | passed | brief.md | Scenario: 「上课人数」显示为「30 人」，「学时」显示为「16 学时」；非纯数字的值原样显示、不追加单位。 | 实现：formatCourseDetailValue（:18-27）仅在 trim 后为纯数字时拼接单位，_isNumericCourseValue（:29-37）逐码点判定 0-9；上课人数 unit='人'、学时 unit='学时'（:475/:481），其余字段 unit 为 null 直接原样返回。独立复核：渲染后 '30 人' 命中 1 次、'16 学时' 命中 1 次；peopleCount='三十'、creditHours='每周2' 时 '三十'、'每周2' 原样显示，而 '三十 人'、'每周2 学时' 命中 0 次。 |
| A3 | passed | brief.md | Scenario: 「班级」「考核方式」等文本型字段显示为「标签 + 原始值」，值不被改写。 | 实现：班级/考核方式/教师/地点/周数/时间 的 unit 均为 null，formatCourseDetailValue 直接返回原值，不做任何改写；班级 wrapText=true（:469）走 maxLines:null + overflow visible 的换行分支。独立复核：含合班逗号串的原始值 '土木工程2307班,智能建造[2303-2304]班' 完整命中 1 次，'考试' 命中 1 次，未出现任何被改写或带单位的变体；Course 模型字段（coursemain.dart:112-127）本身未改动，单位只存在于展示层。 |
| A4 | passed | brief.md | Scenario: 某字段没有值时，该行仍显示字段名标签，值位置显示弱化的「暂无」。 | 实现：_CourseDetailItem.isEmpty（:886）用 value.trim().isEmpty；displayValue（:889-890）空值返回 '暂无'；_CourseDetailRow 的 mutedText（:996-999/:1041-1046）把值色改为 onSurfaceVariant 且字重降到 w500（弱化），标签始终照常渲染。独立复核：把周数/教师/班级/上课人数/学时/考核方式/地点全部置空的课程，渲染出 7 个 '暂无'（时间是 scheduleText 恒非空），8 个标签各命中 1 次，无空行、无标签丢失。 |
| A5 | passed | brief.md | Scenario: 详情行比改动前明显更紧凑（行高由约 66px 降到约 48px，8 行总高由约 528px 降到约 384px），弹层内可容纳的行数增加。 | 实现：行内边距 vertical 14→8、图标容器 38→32、图标 19→17（diff 确认）。独立实测（临时 out-of-repo widget 测试，测量渲染后的真实几何）：8 个详情行内层 Row 高度均为 32，详情组 GlassPanel 高度 391 = 8×48 行 + 7×1px GlassHairlineDivider，即 8 行自身合计正好 384px，与 brief 目标值一致（改动前为 14×2+38=66px/行、8 行 528px）。可容纳行数：在 800×600 测试视口（弹层可视高度 504px）下，8 行中 7 行无需滚动即可完整可见（第 8 行底边 538 > 504），而按旧版 66px 行高推算仅第 1-5 行完整可见（第 6 行底边 548 > 504），可视行数由 5 增至 7。判定：实现达标。实现者汇报的 358px 是「第一行标签文字顶边到最后一行标签文字底边」的文本跨度（解析推导恰为 358.5px），因排除了首尾行的 8px 内边距与 32px 图标框高于 15px 标签文字的差值而偏小，属度量口径差异，不是实现未达验收。 |
| A6 | passed | brief.md | Scenario: 长按某个详情行复制，复制内容包含字段名与单位（如「上课人数：30 人」），提示文案与之一致。 | 实现：copyText getter（:893）为 '$label：$displayValue'；_CourseDetailSheetState 的 onLongPress（:598）传入 _copyValue(item.copyText, '已复制${item.copyText}')。独立复核：长按 '30 人' 行后剪贴板收到 '上课人数：30 人'，同时弹出的 SnackBar 文案为 '已复制上课人数：30 人'，提示与复制内容一致（含字段名与单位）。 |
| A7 | passed | brief.md | Scenario: 「复制课程信息为文本」的结果中「上课人数」「学时」两行带单位，空值回退文案保持原样。 | 实现：lib/home/coursetable/view.dart:1219-1220 对上课人数/学时改用 formatCourseDetailValue(..., '人') / formatCourseDetailValue(..., '学时')，空值分支仍是原来的 '暂无上课人数信息' / '暂无学时信息'（未改名为简写「暂无」），与 brief 约束一致；弹层 copyText 由 view.dart:1328 的 _buildCourseCopyText 提供。独立复核：仓库既有定向测试 test/home/coursetable/course_copy_text_test.dart 断言 contains('上课人数：30 人')、contains('学时：16 学时')、contains('上课人数：暂无上课人数信息')、contains('学时：暂无学时信息')，本次定向运行通过。 |
| A8 | passed | brief.md | Scenario: 实验课课程缺少学时与考核方式时，这两行显示「暂无」，其余行正常显示。 | 实现：detailItems 是与 isExp 无关的静态 8 项列表（:449-493），实验课不会少行；缺值行由通用的 displayValue='暂无' + mutedText 弱化处理。独立复核：构造 isExp=true、pcid='pcid-1'、className='智能建造2304班'、peopleCount='12'、creditHours/assessmentType 为空的课程，渲染结果恰为 2 个 '暂无'（学时、考核方式），8 个标签各命中 1 次，'12 人' 与 '智能建造2304班' 正常显示。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze | analyze | . | passed | 0 | 4032 ms |
| flutter test | test | . | passed | 0 | 21336 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter analyze: passed — 全量分析 No issues found。
- flutter test: passed — 全量 713 项通过。
- flutter test test/home/coursetable/: passed — 52 项通过，含新增 4 个用例。
- 已知限制: 行高与标签列宽为固定像素值（图标容器 32px、标签列 64px、行内边距 8px），未做文字缩放（textScaler）自适应；系统开启超大字号时标签列可能被截断。
- 已知限制: 「上课人数」在普通课表示选课人数、在实验课表示分组人数，本轮沿用 course-class-field-fix 已确认的统一文案，未做区分说明。

## 阻塞项

_无。_

## 风险与跳过的工作

- 展示层与复制层对「纯空白值」处理不一致：弹层用 value.trim().isEmpty 判空显示「暂无」，而复制文本用 isEmpty 且 formatCourseDetailValue 对空白返回原空白（view.dart:1219-1220）。解析层已保证字段 trim，实际不可达，仅为理论差异。
- 标签列固定 64px 加 8px 间距共占 72px，长地点等单行值的可用宽度相应变窄，会以省略号截断（仅班级行按规格允许换行）。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | 独立核验 8 项验收全部通过。实现与 brief/spec 一致：8 个详情行统一为「图标 + 固定宽标签列 + 值列」；上课人数/学时在值为纯数字时追加「人」「学时」单位，非数字值原样显示；空值保留标签并以弱化色显示「暂无」；长按复制与 SnackBar 均为「字段名：值」形式；复制课程信息文本的数值行带单位且空值回退文案保持原样；实验课缺学时与考核方式时这两行显示「暂无」、其余行正常。行高由 66px 收到 48px、8 行合计 384px（实测详情组 391px 含 7 条 1px 分隔线），弹层可视高度内可完整显示的详情行由 5 行增至 7 行；实现者汇报的 358px 为标签文字间的跨度，属度量口径差异而非未达标。额外运行的检查：flutter test test/home/coursetable/course_detail_sheet_test.dart test/home/coursetable/course_copy_text_test.dart test/core/ui/performance_boundaries_test.dart 全部通过（108 个用例）；另在 /tmp 下运行 3 个临时 out-of-repo widget 测试独立测量行高/分组高度、可视行数、标签与单位渲染、空值回退、长按复制与提示文案。未重复执行 Runtime 已跑过的全量 flutter analyze 与全量 flutter test（两者 exit 0）。全程只读：未修改任何实现/测试/文档文件，git status 与核验前一致。 | 2026-10-22T01:23:28.110Z |



## 结论

独立核验 8 项验收全部通过。实现与 brief/spec 一致：8 个详情行统一为「图标 + 固定宽标签列 + 值列」；上课人数/学时在值为纯数字时追加「人」「学时」单位，非数字值原样显示；空值保留标签并以弱化色显示「暂无」；长按复制与 SnackBar 均为「字段名：值」形式；复制课程信息文本的数值行带单位且空值回退文案保持原样；实验课缺学时与考核方式时这两行显示「暂无」、其余行正常。行高由 66px 收到 48px、8 行合计 384px（实测详情组 391px 含 7 条 1px 分隔线），弹层可视高度内可完整显示的详情行由 5 行增至 7 行；实现者汇报的 358px 为标签文字间的跨度，属度量口径差异而非未达标。额外运行的检查：flutter test test/home/coursetable/course_detail_sheet_test.dart test/home/coursetable/course_copy_text_test.dart test/core/ui/performance_boundaries_test.dart 全部通过（108 个用例）；另在 /tmp 下运行 3 个临时 out-of-repo widget 测试独立测量行高/分组高度、可视行数、标签与单位渲染、空值回退、长按复制与提示文案。未重复执行 Runtime 已跑过的全量 flutter analyze 与全量 flutter test（两者 exit 0）。全程只读：未修改任何实现/测试/文档文件，git status 与核验前一致。
