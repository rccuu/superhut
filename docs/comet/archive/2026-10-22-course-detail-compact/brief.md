# 目标

优化课程详情弹层（`CourseDetailSheet`）的信息呈现：

1. **补上文字描述** — 现有信息行只有「图标 + 裸值」，用户看到 `45`、`16` 这类数字无法判断含义。改为「字段名标签 + 带单位的值」，8 行统一。
2. **收紧行间距** — 现有行高约 66px（内边距 14 + 图标容器 38），8 个详情行合计约 528px，弹层可视高度不足，空间利用率低、可读性差。收紧到约 48px。

本轮修改已有 capability `course-class-display` 的完整目标规格（`docs/comet/specs/course-class-display/spec.md`），只改详情弹层的展示形态与复制文本的取值形态，不改课程数据模型与解析链路。

# 范围

## 目录结构

### 新建

- `docs/comet/changes/course-detail-compact/specs/course-class-display/spec.md` — `course-class-display` capability 修改后的完整目标规格

### 修改

- `lib/home/coursetable/widgets/course_table_widgets.dart`：
  - `_CourseDetailItem` 增加 `label` 字段（字段名标签）
  - `_CourseDetailRow` 改为「图标 + 标签列 + 值」两段式布局；行内边距与图标容器尺寸收紧
  - `CourseDetailSheet` 的 8 个详情行补齐标签；数值型字段追加单位后缀；长按复制内容改为带标签的形式
- `lib/home/coursetable/view.dart`：`_buildCourseCopyText` 的「上课人数」「学时」两行追加单位后缀
- `test/home/coursetable/course_detail_sheet_test.dart`：更新受影响的断言（标签、单位、空值回退、长按复制内容）
- `test/home/coursetable/course_copy_text_test.dart`：更新复制文本的单位断言

### 删除

（无）

### 明确不建

- 不改动 `Course` 数据模型与 `get_course.dart` 的解析链路（字段值本身不变）
- 不改动课表表格单元格的显示（课表格子卡片仍不显示这些信息）
- 不改动弹层最大高度系数（`maxHeightFactor: 0.84`）与整体结构（顶部课程名卡片、两组分组、分隔线）
- 不做标签的国际化 / 多语言
- 不引入新依赖

## Source coverage

不适用：需求来自用户口头描述（本轮消息），无文件 / 链接 / 附件类需求来源，不触发源文档完整覆盖模式。字段语义依据已归档 change `course-class-field-fix` 的实测取证结论（见 Decisions D2）。

# 非目标

- 不改变「上课人数」在普通课（选课人数）与实验课（分组人数）下的统一文案——沿用上一轮已确认决定
- 不改动课程分享码、课表同步、本地缓存的任何逻辑
- 不给「周数」「时间」「教师」「班级」「考核方式」「地点」追加单位（它们本身已是带语义的文本或复合值）
- 不调整详情弹层与操作区的分组顺序、图标选择与配色

# 验收示例

- Scenario: 打开课程详情弹层，8 个详情行各自显示字段名标签（周数、时间、教师、班级、上课人数、学时、考核方式、地点），不再只显示裸值。
- Scenario: 「上课人数」显示为「30 人」，「学时」显示为「16 学时」；非纯数字的值原样显示、不追加单位。
- Scenario: 「班级」「考核方式」等文本型字段显示为「标签 + 原始值」，值不被改写。
- Scenario: 某字段没有值时，该行仍显示字段名标签，值位置显示弱化的「暂无」。
- Scenario: 详情行比改动前明显更紧凑（行高由约 66px 降到约 48px，8 行总高由约 528px 降到约 384px），弹层内可容纳的行数增加。
- Scenario: 长按某个详情行复制，复制内容包含字段名与单位（如「上课人数：30 人」），提示文案与之一致。
- Scenario: 「复制课程信息为文本」的结果中「上课人数」「学时」两行带单位，空值回退文案保持原样。
- Scenario: 实验课课程缺少学时与考核方式时，这两行显示「暂无」，其余行正常显示。

# Constraints and invariants

- 不得破坏 `test/core/ui/performance_boundaries_test.dart` 对 `lib/home/coursetable/widgets/course_table_widgets.dart` 的既有断言：`_CourseDetailSheetState` 内 `for (final item in detailItems)` / `for (final item in actionItems)` 的直接循环（不得改为 `.map` / `.toList()`）、`_CourseDetailGroup` 的 `_buildSeparatedChildren()` 直接循环结构不得变。
- `_CourseDetailGroup` 的分隔线插入逻辑与 `GlassHairlineDivider` 用法保持不变。
- 课程字段的原始值不被改写：单位后缀只在展示层拼接，`Course` 模型与持久化数据仍存原始值。
- 复制文本中已有的字段名与「暂无…」回退文案不改名，只在数值行追加单位。
- 详情行与操作行共用同一 `_CourseDetailRow`，收紧行高对两者一致生效。
- 浅色 / 深色模式均可正常显示；标签使用弱化色，值使用主色，保证对比度。

# Decisions

- D1 展示形态为「字段名标签 + 带单位的值」，8 行统一加标签。理由：同一张卡片内标签有无混排会割裂，统一后扫读最快、误读最少。【用户明确选择】
- D2 只给数值型字段追加单位：「上课人数」→「人」，「学时」→「学时」；其余字段不加单位。理由：周数是周次区间、时间已含「第…节」、班级/考核方式/教师/地点是纯文本，追加单位会产出怪异文案。
- D3 单位后缀只在值为纯数字时追加；非数字值原样显示。理由：解析层已用 `_readDisplayValue` 规范为字符串，异常值不应被拼成「abc 人」。
- D4 行高收紧到约 48px（内边距 14→8、图标容器 38→32、图标 19→17），对应用户选定的「中度收紧」档位。理由：8 详情行从约 528px 降到约 384px，弹层可视高度内的信息量明显提升，且保留图标辨识度与点按舒适度。
- D5 标签使用固定宽度列，值左对齐成一列。理由：不同字段名长度不一（「学时」2 字 vs「上课人数」4 字），不定宽会让值列参差。
- D6 字段值为空时值位置显示弱化的「暂无」。理由：标签已在左侧，重复「暂无上课人数信息」冗余；复制文本没有相邻标签，仍保留完整回退文案。
- D7 长按复制的文本改为「字段名：值」形式，与「复制课程信息为文本」的格式一致。理由：复制裸值「30」在脱离界面后同样无法判断含义，与本轮目标一致。
- D8 「上课人数」在普通课与实验课下文案统一，不因实验课表示分组人数而改标签。理由：沿用 `course-class-field-fix` 已确认的决定（统一为「上课人数」），本轮不修订该决定。
- D9 弹层最大高度系数（0.84）与整体结构不动。理由：用户诉求集中在行内间距，弹层高度属另一维度，改动会引入遮挡风险且收益不确定。
- D10 工作区使用独立 worktree（`.worktrees/course-detail-compact`），目标分支 `main`。【用户明确选择】

# Open questions

（无未决项。展示形态、标签覆盖范围、行距收紧档位、工作区隔离四项决定已由用户在需求澄清中确认；其余为实现选择，无 `[blocking]`。）

# Verification expectations

- `flutter analyze` 无新增 warning / error。
- `flutter test` 全量通过，重点为 `test/home/coursetable/` 与 `test/core/ui/performance_boundaries_test.dart`。
- 新增 / 更新 widget 用例覆盖：8 行标签齐全、数值行带单位、文本行不加单位、空值显示「暂无」、长按复制内容带标签与单位、复制文本带单位。
