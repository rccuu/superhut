# Task 1 Report: Extract Shared Auto-Selection Logic And Preserve Question-Page Behavior

## Status

DONE

## Scope

- 仅处理 Task 1 brief 要求的共享自动选项逻辑抽取。
- 未改 batch page、course list page 或其他任务内容。
- 仅修改以下文件：
  - `lib/pages/Commentary/commentary_auto_selection.dart`
  - `lib/pages/Commentary/commentary_question_page.dart`
  - `test/pages/commentary/commentary_auto_selection_test.dart`
  - `test/pages/commentary/commentary_question_page_test.dart`

## Implementation Summary

- 新增 `buildAutoCommentarySelections(List<CommentaryPayload> questions)`，把“一题选低分，其余题选高分”的自动选择规则抽到共享 helper。
- `CommentaryQuestionPage._buildAutoSelections()` 仅保留题目数一致性检查，再委托给共享 helper。
- 保持 `CommentaryQuestionPage._handleAutoSubmit()` 原有行为不变：当 helper 返回的答案数量少于题目数时，继续弹出“还有题目未匹配到可提交选项”告警，不直接提交。

## TDD Evidence

### RED

先写测试，再运行：

```bash
flutter test test/pages/commentary
```

实际失败证据：

- `Error when reading 'lib/pages/Commentary/commentary_auto_selection.dart': No such file or directory`
- `Method not found: 'buildAutoCommentarySelections'`

这说明新测试确实先于实现失败，符合 brief 要求的 RED 阶段。

### GREEN

完成最小实现后重新运行：

```bash
flutter test test/pages/commentary
```

结果：

- `All tests passed!`

额外按任务相关文件做 focused verification：

```bash
flutter test test/pages/commentary/commentary_auto_selection_test.dart test/pages/commentary/commentary_question_page_test.dart
```

结果：

- `All tests passed!`

## Verification Notes

- 目录级 `test/pages/commentary` 已通过，包含新增 helper 测试和题目页回归测试。
- 目录级运行中存在 course list / batch page 测试主动打印的异常日志（`navigator unavailable`），但最终 suite 通过，这些不是本任务新增问题。

## Commit

- 计划提交信息：`refactor(commentary): share auto selection rule`

## Risks / Remaining Concerns

- 当前共享规则仍依赖分数阈值 `4.75` 与“首题低分、后续高分”的既有业务约定；本任务只做抽取与回归保护，没有改变规则来源或配置方式。
