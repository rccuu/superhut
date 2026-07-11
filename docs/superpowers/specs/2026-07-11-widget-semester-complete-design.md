# 课表小组件学期结束空态设计

## 概述

课表小组件在「今天起已无任何后续课程」时，会落到与「从未同步课表」相同的空态文案（`当前暂无课表` / `同步或导入后显示课程`）。学期末用户明明本地已有完整课表，却被提示去同步/导入，体验错误。

本设计在现有「相关课程」状态机最后一跳拆出学期结束态 `semester_complete`，与真正的无课表空态 `empty` 区分，并在 Flutter / iOS / Android 三端保持一致。

## 背景与根因

当前相关课程优先级（三端镜像实现）：

1. 今天仍有未结束课程 → `today_courses`
2. 周日且周一有课 → `next_monday`
3. 明天有课 → `tomorrow_courses`
4. 未来某天有课 → `next_course`
5. 否则 → 统一 `empty`（`当前暂无课表`）

学期结束后第 1–4 步全部不命中，第 5 步无法区分：

- 本地有历史课表、只是课程已全部上完
- 从未同步/导入，或用户清空了课表

相关实现位置：

- Flutter：`lib/utils/course/coursemain.dart`（`_buildRelevantCourseWidgetPayloadFromStore`、`_buildEmptyCourseWidgetPayload`、`_buildCourseWidgetPayloadForDate`）
- iOS：`ios/CourseWidget/CourseWidget.swift`（`relevantPayload` → `emptyPayload`）
- Android：`android/.../CourseTableWidgetProvider.java`（`buildRelevantPayloadFromStore` → `buildEmptyPayload`）

原生侧会按 `course_widget_store` 本地重算展示内容，因此不能只改 Flutter 写出的单日 payload 文案。

## 目标

- 有本地课表且今天起无后续课程时，显示祝贺型「本学期课程已上完」
- 真正无课表时，继续显示「当前暂无课表 / 同步或导入后显示课程」
- iOS 与 Android 文案、`status` 一致
- 不改变「今天剩余 → 明天/周一 → 下次课程」的优先顺序

## 非目标

- 不改 widget 视觉皮肤、尺寸、配色、布局结构
- 不扩展 `CourseWidgetStore` schema（不把 `firstDay` / `maxWeek` 写入 store）
- 不新增设置项
- 不改登录、课表同步链路、静默刷新策略
- 不引入「学期日历边界」判定（见方案取舍）

## 方案取舍

| 方案 | 做法 | 结论 |
|------|------|------|
| A. 运行时空态分支 | 无下次课程时，按「是否有历史课」拆 `semester_complete` / `empty` | **采用** |
| B. 学期日历边界 | 用 `firstDay + maxWeek` 判断是否过学期末日 | 需扩 schema；手动导入课表边界不准；本次不做 |
| C. 只改 Flutter payload 文案 | 同步时写死祝贺文案 | 原生本地重算会覆盖，不可行 |

## 状态机

判定顺序（仅拆最后一跳）：

```
今天剩余课?
  ├─ 是 → today_courses
  └─ 否 → 周日且周一有课?
            ├─ 是 → next_monday
            └─ 否 → 明天有课?
                      ├─ 是 → tomorrow_courses
                      └─ 否 → 未来有课日?
                                ├─ 是 → next_course
                                └─ 否 → 有历史课?
                                          ├─ 是 → semester_complete  ← 新增
                                          └─ 否 → empty
```

### 历史课判定

满足任一即视为「有历史课」：

1. `store.dayCourses` 中存在任一日期，其课程列表非空
2. （兼容旧 store）`store.days` 中存在 `status == "today_courses"` 且 `courses` 非空

无 store、store 为空、或用户清空课后 `dayCourses`/`days` 均无有效课程 → 视为无历史课。

说明：判定用「是否存在过课程数据」，不要求该历史课日期必须早于今天；只要未来已无课且 store 里有课，即进入学期结束态（覆盖「最后一节课刚上完」的当天场景）。

### 新增状态字段

| 字段 | `semester_complete` | `empty`（保持现有） |
|------|---------------------|---------------------|
| `status` | `semester_complete` | `empty` |
| `headerTitle` | `本学期课程已上完` | `当前暂无课表` |
| `headerSubtitle` | `辛苦啦，下学期见` | `同步或导入后显示课程` |
| `emptyText` | `可同步新学期课表` | `同步或导入后显示课程` |
| `isEmpty` | `true` | `true` |
| `courses` | `[]` | `[]` |
| `weekIndex` | 尽量沿用今日在 store 中的 weekIndex；不可得则为 `0` | `0` |
| `date` / `weekdayLabel` | 今日 | 今日 |
| `updatedAt` | store.updatedAt 或当前时间 | 同左 |

UI 无需新布局：三端已有 `isEmpty` 分支，继续渲染标题 + 副标题 + `emptyText`。

## 边界行为

| 场景 | 期望 |
|------|------|
| 今天最后一节刚结束，明天仍有课 | `tomorrow_courses`，不进学期结束 |
| 本周无课但下周有课 | `next_course` |
| 本地有课表，最后一天课程全部结束 | `semester_complete` |
| 从未同步 / 无 store | `empty` |
| 用户清空全部课表 | `empty` |
| 同步/导入新学期后出现未来课 | 自动回到有课态 |
| 仅有旧版 `days`、无 `dayCourses` | 仍能按历史课判定进入 `semester_complete` |

## 实现落点

### 1. Flutter — `lib/utils/course/coursemain.dart`

- 新增 `_hasHistoricalCourses(CourseWidgetStore store)`（或等价私有函数）
- 新增 `_buildSemesterCompleteCourseWidgetPayload(...)`，与 `_buildEmptyCourseWidgetPayload` 并列
- 在 `_buildRelevantCourseWidgetPayloadFromStore` 末尾：无下次课程时按历史课分支
- 在 `_buildCourseWidgetPayloadForDate` 末尾：同样分支，保证按日预计算的 `days[date]` 在学期末写入 `semester_complete` 而非 `empty`（便于调试与旧路径一致）
- 文案集中为常量或单一构造函数，避免三处硬编码漂移

### 2. iOS — `ios/CourseWidget/CourseWidget.swift`

- 在 `relevantPayload` 中，`nextCourseDate` 为 nil 时：
  - 若 `actualCourseDateKeys` 非空 → 返回 semester complete payload
  - 否则 → 现有 `emptyPayload`
- 不改 Timeline 刷新策略：现有按课程结束 / 跨天刷新仍足够；学期结束态跨天保持不变

### 3. Android — `CourseTableWidgetProvider.java`

- 在 `buildRelevantPayloadFromStore` 末尾做与 iOS 相同分支
- 新增 `buildSemesterCompletePayload`（或参数化 empty builder）
- 布局与刷新逻辑不变

### 4. 测试 — `test/utils/course/coursemain_test.dart`

至少覆盖：

1. 有 `dayCourses` 历史课 + 今天及之后无课 → `status == semester_complete` 且文案正确
2. store 为 null / 空 dayCourses → `empty`
3. 今天有剩余课 / 明天有课 / 下次有课 → 不进入 `semester_complete`
4. 仅旧 `days`（`today_courses`）无 `dayCourses` 时，未来无课仍可 `semester_complete`

原生侧以手工验收为主；若后续有原生单测基建再补。

## 数据流（无 schema 变更）

```
SavedCourseSchedule
    → buildCourseWidgetStore / dayCourses
    → 三端 relevant 重算
         → semester_complete | empty | 有课态
    → Widget UI（isEmpty 分支读 headerTitle / headerSubtitle / emptyText）
```

`WidgetRefreshService.syncCourseTableWidget` 路径不变；用户打开 App、同步课表、跨天/课程结束刷新后即可看到新状态。

## 验收标准

- [ ] 本地有本学期课表、今天起无后续课：小组件标题为「本学期课程已上完」，副标题「辛苦啦，下学期见」，空态正文「可同步新学期课表」
- [ ] 从未同步课表：仍为「当前暂无课表」/「同步或导入后显示课程」
- [ ] 今天、明天、下次课程场景行为与现网一致，无回归
- [ ] 清空课表后回到 `empty`；同步新学期后恢复课程显示
- [ ] iOS 与 Android 在同一 store 下 `status` 与三条文案一致
- [ ] Flutter 单测覆盖上述关键分支并通过

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| 三端文案不一致 | 文案在本 spec 定稿；实现时对照表抄写；测试断言完整字符串 |
| 旧 store 无 `dayCourses` | 兼容 `days` 中 `today_courses` 判定 |
| 误把「长期无课但中间学期」当学期结束 | 本方案有意采用「无未来课即祝贺」；若未来要区分假期间，再引入方案 B |
| 用户期望点击后进同步页 | 现有 `superhut://widget/course` 深链保持不变，不在本次改交互 |

## 实现顺序建议

1. Flutter 判定 + payload + 单测（可测真源）
2. iOS 镜像分支
3. Android 镜像分支
4. 真机/模拟器手工抽查学期末与无课表两种空态
