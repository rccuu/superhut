# 成绩学期探测：并发加速 + 学期类型过滤

## 背景

成绩查询页 (`lib/pages/score/scorepage.dart`) 的"自动隐藏不含数据的学期"功能当前实现为串行探测：`_filterSemestersWithScores` 用 `for` 循环依次 `await` 每个学期的成绩请求，N 个学期就是 N 次串行网络往返，用户感知明显变慢。

本设计在两个维度优化：
1. **学期类型过滤**：只保留"年份-年份-上/下学期"格式的学期（`term` 为 `1` 或 `2`），其他（如暑期学期 `term=3`、解析失败的异常 ID）在探测前剔除，减少探测请求数。
2. **并发加速**：把串行探测改为自适应并发，并对单学期失败做后台静默重试。

## 现状关键事实

- 学期 ID 格式：`{起始年}-{结束年}-{学期号}`，如 `2024-2025-1`（上学期）、`2024-2025-2`（下学期）。
- `_parseSemesterLabelParts`（scorepage.dart:400-427）已能解析该三段格式，返回 `({startYear, endYear, term})` 或 `null`。
- `_loadScoreForSemester`（scorepage.dart:188-218）已内置去重：通过 `_ScoreLoadKey(semesterId, persistSummary)` 合并并发同一学期的加载，并缓存到 `_scoreCache`。
- `getScore`（logic.dart:119）在 `semesterId == ''` 时请求全部学期成绩，单学期请求返回 `errorMessage`（接口/网络异常）或 `achievement` 为空（该学期无数据）。
- 现有生命周期保护：探测期间多处 `if (!mounted) return`；`_selectionRefreshGeneration` 用于让过期的选择刷新失效。

## 现有回退逻辑（将被替换）

`_filterSemestersWithScores`（scorepage.dart:247-285）当前行为：任何一次单个学期探测抛异常或返回 `errorMessage != null`，立即 `return semesterIds`（保留全部学期）。这是"整体回退"语义，粒度粗、易因一次抖动放弃过滤。

## 设计

### 1. 学期类型过滤（探测前，新增）

新增私有方法：

```dart
bool _isRegularTermSemester(String id) {
  final parts = _parseSemesterLabelParts(id);
  if (parts == null) return false;
  return parts.term == '1' || parts.term == '2';
}
```

在 `_probeAvailableSemesters` 入口，先把入参 `semesterIds` 过滤为 `regularSemesterIds = semesterIds.where(_isRegularTermSemester).toList()`。仅 `regularSemesterIds` 进入并发探测。

**不在 `logic.dart` 层做此过滤**：保持数据层纯净，避免影响未来可能复用完整学期列表的页面。

### 2. 单学期探测 + 重试（新增）

新增私有方法，封装"探测一个学期是否有数据"的语义，含后台静默重试：

```dart
// 返回：keep=true 表示该学期应保留在可选列表中
//   - 成功且 achievement 非空 → keep=true
//   - 成功但 achievement 为空  → keep=false（明确无数据，剔除）
//   - 报错（重试 maxRetries 次仍失败）→ keep=true（保留，避免误隐藏）
Future<bool> _probeSemesterKeep(String id, {int maxRetries = 2}) async {
  ScoreLoadResult? result;
  for (var attempt = 0; attempt <= maxRetries; attempt++) {
    if (!mounted) return true;
    try {
      result = await _loadScoreForSemester(id, persistSummary: false);
      break; // 成功拿到结果（含 errorMessage 的"业务失败"也算拿到，见下）
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to probe score data for semester $id (attempt $attempt)',
        error: error, stackTrace: stackTrace,
      );
      if (attempt == maxRetries) return true; // 重试耗尽 → 保留
      // 否则继续下一次重试
    }
  }
  if (!mounted) return true;
  // errorMessage != null 视为业务失败，等同"拿不到数据"→ 按报错语义保留
  if (result == null || result.errorMessage != null) return true;
  return result.achievement.isNotEmpty;
}
```

说明：
- 重试无 delay（避免拖慢；网络抖动在下次请求时自然恢复）。
- `errorMessage != null` 也走"保留"分支，与原"整体回退"的安全取向一致，但粒度收敛到单学期。
- 复用 `_loadScoreForSemester` 的去重缓存：同 semesterId 的并发 in-flight 请求自动合并。

### 3. 自适应并发探测（新增）

新增私有方法，按学期数选择并发度：

```dart
Future<List<String>> _probeRegularSemesters(List<String> ids) async {
  if (ids.isEmpty) return const [];
  const int fullConcurrencyLimit = 6;
  const int poolSize = 6;

  if (ids.length <= fullConcurrencyLimit) {
    // 全量并发，逐个判定
    return _probeKeepAll(ids);
  }
  // 分批，每批 poolSize 个并发
  final kept = <String>[];
  for (var i = 0; i < ids.length; i += poolSize) {
    if (!mounted) return kept; // 中途离开：返回已判定部分（外层会再判 mounted）
    final batch = ids.sublist(i, min(i + poolSize, ids.length));
    kept.addAll(await _probeKeepAll(batch));
  }
  return kept;
}

Future<List<String>> _probeKeepAll(List<String> ids) async {
  final results = await Future.wait(ids.map((id) => _probeSemesterKeep(id)));
  return [for (var i = 0; i < ids.length; i++) if (results[i]) ids[i]];
}
```

- 并发池上限固定 6，全量并发阈值 6。学期数通常 6–10，多数情况一次 `Future.wait` 即收束。
- 不使用 isolate / `compute`：探测瓶颈是网络 I/O，event loop 上的并发 Future 已是正确模型，isolate 会引入序列化开销，无收益。
- 使用 `dart:math` 的 `min`（文件顶部已 `import 'dart:async'`，需补 `import 'dart:math' show min;`）。

### 4. 整合到 `_probeAvailableSemesters`（改造）

原 `_filterSemestersWithScores` 方法整体删除，由下列流程承担：

```dart
Future<void> _probeAvailableSemesters(List<String> semesterIds) async {
  if (_isSemesterProbeStarted) return;
  _isSemesterProbeStarted = true;

  // 1. 探测前过滤：只保留标准上/下学期格式，其余一律剔除（不再保留）。
  final regularIds = semesterIds.where(_isRegularTermSemester).toList();

  // 2. 并发探测；keptIds 已按 regularIds 顺序排列（.where 保序、Future.wait 保序）。
  final keptIds = await _probeRegularSemesters(regularIds);
  if (!mounted) return;

  final filteredSemesterIds = keptIds; // 直接使用，无需重排

  // 3. 与当前列表比较，决定是否刷新 UI（以下与原实现一致）。
  final shouldResetSelection =
      selectedId != 'all' && !filteredSemesterIds.contains(selectedId);
  if (!shouldResetSelection && listEquals(semesterId, filteredSemesterIds)) {
    return;
  }

  final cachedAllScoreData = shouldResetSelection ? _scoreCache['all'] : null;
  if (cachedAllScoreData != null) {
    semesterId = filteredSemesterIds;
    _assignScoreData(cachedAllScoreData, semesterId: 'all');
    _syncScoreContentState();
    _syncSelectionState();
    return;
  }

  semesterId = filteredSemesterIds;
  if (shouldResetSelection) {
    selectedId = 'all';
    _syncScoreContentState();
    _syncSelectionState();
  }

  if (!shouldResetSelection) return;

  final allScoreData = await _loadScoreForSemester('all');
  if (!mounted || selectedId != 'all') return;
  _setScoreData(allScoreData, semesterId: 'all');
}
```

关键判定语义：
- `filteredSemesterIds` 直接等于 `keptIds`。`List.where` 保序、`Future.wait` 按 map 输入顺序回填，故 `keptIds` 保持 `regularIds`（即原始 `semesterIds` 中标准学期的）相对顺序，UI 列表顺序稳定，无需额外 `_mergeKeptOrder`。
- 非标准格式学期一律从可选列表剔除（符合需求："其他的不显示"）。
- 报错学期由 `_probeSemesterKeep` 保留在 `keptIds` 中。


**移除的旧逻辑**：原 `_filterSemestersWithScores` 中"一次失败即 `return semesterIds`（保留全部）"的整体回退被取消，改为单学期粒度的"报错保留"。`_filterSemestersWithScores` 方法整体删除，由上述新方法承担。

### 5. 生命周期与取消

- 现有 `_loadScoreForSemester` 的去重保证：探测期间的 Future 与 UI 切换触发的加载共享 in-flight 句柄，不会重复请求。
- `_probeSemesterKeep` 与 `_probeRegularSemesters` 在每个 await 点后检查 `mounted`；页面销毁后未完成的 Future 在 `_syncSelectionState`/`_syncScoreContentState` 已有的 `mounted` 检测处短路，不会更新已销毁的 widget。
- 不引入结构化取消（无 `CancelableOperation`）：当前 `mounted` + generation 机制已足够，引入会更复杂且收益有限。

### 6. 测试

新增 `@visibleForTesting` 入口（沿用 `debugRefreshScoresForSelection` 模式）：

```dart
@visibleForTesting
Future<List<String>> debugProbeAvailableSemesters(List<String> semesterIds) async {
  // 不依赖 widget._isSemesterProbeStarted 状态，便于重复调用
}
```

测试用例（通过 `loadScore` 注入 mock `ScoreResultLoader`）：
1. 全部学期非空 → 保留全部。
2. 混合（部分空、部分报错）→ 空的被剔除，报错的保留。
3. 含非上/下学期 → 探测前已过滤，不调用 mock for those。
4. 学期数 > 6 → 分批并验证批次调度（通过 mock 计数并发峰值）。
5. 解析失败的 semesterId → 当非标准学期处理（从可选列表剔除，不调用 mock）。
6. 重试生效：mock 前两次抛异常、第三次成功 → 最终判定按成功结果。

## 不做的事（YAGNI）

- 不改 `logic.dart`：数据层与 UI 过滤语义分离。
- 不引入 isolate / `compute`：I/O 限流场景下无收益。
- 不加重试 delay：网络抖动恢复交给下次请求自然处理。
- 不动 `_parseSemesterLabelParts`：现解析逻辑正确复用。
