# 成绩学期筛选缓存设计

## 概述

成绩查询页面每次打开都需要从服务端拉取学期列表并逐个探测是否有成绩数据，导致首屏加载慢。本设计引入本地缓存层：打开时先用上次的过滤结果立即渲染，后台静默重新探测，有变化再更新 UI。

## 目标

- 打开成绩页面时瞬间恢复上次浏览状态（学期列表 + 选中学期 + 摘要指标）
- 后台静默刷新，无感知更新
- 用户身份隔离，登出时清除

## 数据模型

```dart
class ScoreSemesterCacheData {
  final List<String> semesterIds;   // 探测后的有效学期列表
  final String selectedId;          // 上次选中的学期 ('all' 或具体 id)
  final String nowSemesterId;       // 当前学期标记
  final String zxf;                 // 已修总学分
  final String zxfjd;               // 总学分绩点
  final String pjjd;                // 平均绩点
  final int courseCount;            // 课程数量
}
```

## 存储结构

使用 SharedPreferences，key 以用户标识为前缀：

| Key | 类型 | 说明 |
|-----|------|------|
| `score_cache_{userId}_semesters` | StringList | 过滤后的学期 ID 列表 |
| `score_cache_{userId}_selectedId` | String | 上次选中学期 |
| `score_cache_{userId}_nowId` | String | 当前学期标识 |
| `score_cache_{userId}_zxf` | String | 已修总学分 |
| `score_cache_{userId}_zxfjd` | String | 总学分绩点 |
| `score_cache_{userId}_pjjd` | String | 平均绩点 |
| `score_cache_{userId}_courseCount` | int | 课程数 |

不缓存成绩条目列表本身，只缓存摘要指标和学期选择状态。

## 服务类设计

文件：`lib/core/services/score_semester_cache.dart`

```dart
class ScoreSemesterCache {
  ScoreSemesterCache._();
  static final ScoreSemesterCache instance = ScoreSemesterCache._();

  /// 读取缓存，userId 为空或无缓存时返回 null
  Future<ScoreSemesterCacheData?> read(String userId);

  /// 写入/更新缓存
  Future<void> write(String userId, ScoreSemesterCacheData data);

  /// 清除指定用户的缓存
  Future<void> clear(String userId);

  /// 清除所有用户的缓存（登出时调用）
  Future<void> clearAll();
}
```

设计决策：

- 单例模式，和 `AppAuthStorage` 保持一致
- `read()` 返回 nullable，调用方通过 null 判断是否有缓存可用
- `clearAll()` 遍历 SharedPreferences 所有 keys，匹配 `score_cache_` 前缀逐个删除
- `userId` 参数由调用方传入，不在 cache 类内部耦合认证逻辑

## 集成流程

### 打开成绩页面的新流程

```
打开成绩页面
    │
    ▼
读取缓存 (ScoreSemesterCache.read)
    │
    ├─ 有缓存 → 立即用缓存数据渲染 UI（学期列表、选中状态、摘要指标）
    │            first = false，页面可交互
    │            unawaited 启动后台刷新
    │
    └─ 无缓存 → 走原有流程（显示 loading → 请求 → 渲染）
                 完成后写入缓存

后台刷新流程：
  1. semesterIdfc() 拉取学期列表
  2. getScore('all') 拿全量成绩
  3. _probeAvailableSemesters() 探测过滤
  4. 比较探测结果与当前缓存
     ├─ 无变化 → 不动 UI，覆盖写入缓存
     └─ 有变化 → 静默更新 semesterId 列表 + 摘要
                  selectedId 被移除时 reset 到 'all'
  5. 写入新缓存 (ScoreSemesterCache.write)
```

### ScorePage 改动点

1. `getTimeList()` 开头新增缓存读取分支：有缓存时用缓存数据设置状态，标记 `first = false`，`unawaited()` 启动 `_backgroundRefresh()`
2. 新增 `_backgroundRefresh()` 方法，封装原有的"拉学期 → 加载成绩 → 探测过滤"逻辑
3. `_probeAvailableSemesters()` 完成后调用 `ScoreSemesterCache.write()` 持久化
4. `_refreshScoresForSelection()` 成功后更新缓存的 `selectedId` 和摘要指标

### 对 `_initialScoreFuture` 的影响

- 有缓存时 `getTimeList()` 在缓存读取后立即 complete，`EnhancedFutureBuilder` 瞬间切到主界面
- 无缓存时行为和原来一样，等全部加载完再 complete

### 联动清除

在 `AppAuthStorage.clearAllAuthData()` 末尾追加：

```dart
await ScoreSemesterCache.instance.clearAll();
```

## 边界情况与错误处理

1. **缓存读取失败**：静默捕获，日志记录，返回 null，退化到无缓存流程
2. **后台刷新网络失败**：不弹错误提示，保持缓存数据不变，下次打开再尝试，日志记录
3. **缓存数据部分损坏**：`read()` 内校验 `semesterIds` 为空则视为无效缓存返回 null
4. **用户切换学期后 crash/退出**：切换成功后立即写缓存，最坏情况用上一次成功写入的缓存
5. **userId 获取不到（未登录）**：跳过缓存读写，走原有流程
6. **clearAll 实现**：遍历所有 keys，匹配 `score_cache_` 前缀逐个删除

## userId 来源

使用 `AppAuthStorage.instance` 读取当前 JWXT 用户名（`readJwxtUsername()` 返回的学号字符串）作为 userId。该值在成绩页面可到达时必然已存在。

## 缓存失效策略

- 按用户身份隔离（key 含 userId）
- 不设时间过期（每次打开都后台刷新）
- 登出时随 `clearAllAuthData()` 一起清除

## 文件清单

| 操作 | 文件 |
|------|------|
| 新增 | `lib/core/services/score_semester_cache.dart` |
| 修改 | `lib/pages/score/scorepage.dart`（`_ScorePageState`） |
| 修改 | `lib/core/services/app_auth_storage.dart`（联动清除） |
| 新增 | `test/score_semester_cache_test.dart`（单元测试） |
