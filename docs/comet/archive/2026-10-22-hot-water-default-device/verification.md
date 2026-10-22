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
- 完成时间: 2026-10-22T01:51:40.957Z
- 摘要: 逐条核验 hot-water-default-device 的 7 项验收，全部通过。实现与需求一致：默认设备以 poscode 存储在 SharedPreferences（独立键 hot_water_default_device，与饮水页 device_order/device_note_* 不冲突），逻辑层只依赖可注入的 HotWaterDevicePreferenceStore 抽象；_applyDeviceList 先按默认设备号解析选中（缺失/解绑回退第一台），随后未关闭设备检查仍可覆盖并给出既有提示，符合 R2/R4 的顺序约束；星标入口只改默认不改本次选择、不关列表，删除默认设备会真实删键并回退第一台。核验方式：只读阅读 brief/spec 与实现 + 在仓库副本（/tmp/hwd-verify-67129，未改动被验工作树，git status 与开始时一致）中新增 13 个针对真实 SharedPreferences 存储与真实页面渲染的独立用例，全部通过：(1) `flutter test test/pages/water/zz_verifier_persistence_test.dart` → 6/6 通过（A1/A2 选型、A3 落盘与新 controller 读回、A4 取消默认删键、A5 未关闭设备优先、A6 删除清理、A7 解绑回退）；(2) `flutter test test/pages/water/zz_verifier_widget_test.dart` → 7/7 通过（含 '默认' 标记渲染、星标交互真实落盘、'检测到有设备尚未关闭' 提示可见、页面内删除默认设备后的清理与回退、解绑回退）。额外运行的检查仅为上述两个定向测试，未重跑 Runtime 已通过的 flutter analyze / flutter test 全量。

## 验收

| 编号 | 结果 | 来源 | 验收项 | 原因 |
| --- | --- | --- | --- | --- |
| A1 | passed | brief.md | Scenario: 设备列表加载后，本机保存的默认设备号在返回列表中时，页面自动选中该设备，且当前设备卡片标注「默认」。 | 实现：logic.dart:331-360 `_applyDefaultDeviceSelection` 按 poscode 在 deviceList 中匹配 savedCode 并 `_assignChoiceDevice(index)`，命中时同时置 `state.defaultDeviceCode = savedCode`；view.dart:421-435 由「当前选中设备号 == defaultDeviceCode」算出 `isDefaultDevice` 传给 HotWaterCurrentDeviceCard；water_page_widgets.dart:331-341 在 isDefaultDevice 时渲染 _WaterCapsule(label: '默认', icon: star_rounded)。独立验证（在 /tmp 的仓库副本中新增只读核验用例，走真实 SharedPreferencesHotWaterDevicePreferenceStore 与默认注入的 FunctionHotWaterLogic，未改动被验仓库）：`flutter test test/pages/water/zz_verifier_widget_test.dart` 的 A1 用例通过——预置 SharedPreferences 键 hot_water_default_device='200002'，getDeviceList() 后 choiceDevice==1（选中二栋热水），渲染页面后 find.text('二栋热水') 与 find.text('默认') 均 findsOneWidget，HotWaterCurrentDeviceCard.isDefaultDevice==true。存储键与饮水页 'device_order'/'device_note_*' 无冲突（grep 确认）。 |
| A2 | passed | brief.md | Scenario: 本机没有保存过默认设备时，保持现状选中列表第一台设备。 | 实现：logic.dart:343-347，savedCode 为空时 `state.defaultDeviceCode=''` 且 `_assignChoiceDevice(0)`，与改造前 `_assignChoiceDevice(state.deviceList.isNotEmpty ? 0 : -1)`（git diff 可见）对非空列表完全等价，空列表仍为 -1。独立验证：zz_verifier_widget_test.dart 的 A2 用例通过——无预置默认时 choiceDevice==0，页面渲染 find.text('一栋热水') 命中且 find.text('默认') findsNothing（不误标）。 |
| A3 | passed | brief.md | Scenario: 在选择设备列表中点击某台设备的「设为默认」后，该选择被持久保存，退出并重新进入宿舍热水页面仍自动选中它。 | 持久化路径核对：view.dart:177-180 把星标点击接到 `logic.toggleDefaultDevice(index)`；logic.dart:538-571 `toggleDefaultDevice` 调 `_devicePreferenceStore.writeDefaultDeviceCode(deviceCode)`（写入失败弹 '操作失败：默认设备设置失败，请稍后重试'，不静默丢弃）；默认注入为 `SharedPreferencesHotWaterDevicePreferenceStore`（logic.dart:145-147），其实现 default_device_store.dart:41-49 用 `prefs.setString('hot_water_default_device', code)` 落盘、读用 `prefs.getString`（读取失败按无默认处理）。独立验证（真实存储 + 新 controller 实例读回）：zz_verifier_persistence_test.dart 的 A3 用例通过——toggleDefaultDevice(1) 后 SharedPreferences.getInstance().getString('hot_water_default_device')=='200002'，随后新建的第二个 FunctionHotWaterLogic（未注入假存储，走默认真实存储）getDeviceList() 后 choiceDevice==1、defaultDeviceCode=='200002'；zz_verifier_widget_test.dart 的 A3 用例通过——页面内点列表星标后 prefs 真实键值为 '200002'、state.defaultDeviceCode 立即更新、choiceDevice 仍为 0（不改本次选择）、WaterDeviceSelectionSheet 未关闭、列表出现 '默认设备' 标注。 |
| A4 | passed | brief.md | Scenario: 在选择设备列表中再次点击已设为默认的设备可取消默认；取消后重新进入页面回到选中列表第一台。 | 实现：logic.dart:548-551 当 state.defaultDeviceCode 与目标设备号相同即转 `clearDefaultDevice()`，后者在 logic.dart:574-593 写空串；default_device_store.dart:44-46 空串走 `prefs.remove(hotWaterDefaultDeviceKey)`（真正删键，不是写空值）。独立验证：zz_verifier_persistence_test.dart 的 A4 用例通过——预置默认 '200002' 后 toggleDefaultDevice(1) 使 prefs.containsKey('hot_water_default_device')==false，新建 controller 实例 getDeviceList() 后 choiceDevice==0、defaultDeviceCode==''；zz_verifier_widget_test.dart 的 A4 用例通过——点实心星标后键被删除、state.defaultDeviceCode 清空、列表中 '默认设备' 标注消失。 |
| A5 | passed | brief.md | Scenario: 检测到有设备未关闭时，仍优先选中该未关闭设备并给出提示，不被默认设备覆盖。 | 时序核对：logic.dart:308-325 `_applyDeviceList` 先 `await _applyDefaultDeviceSelection()`（默认选中），再 `await Future.wait([_refreshOpenDeviceState(), _refreshBalanceValue()])`；`_refreshOpenDeviceState`→`_applyOpenDeviceState`（logic.dart:510-527）在检测到未关闭设备时重新 `_assignChoiceDevice(deviceIndex)` 并弹既有提示 '设备状态提醒：检测到有设备尚未关闭'（isWarning），顺序上默认设备无法覆盖未关闭设备；逻辑层默认存储读取与设备状态检查、余额刷新仍并发（Future.wait 保持原样）。独立验证：zz_verifier_persistence_test.dart 的 A5 用例通过（默认 '200002' + 未关闭 '100001' → choiceDevice==0、waterStatus==true、defaultDeviceCode 仍为 '200002'）；zz_verifier_widget_test.dart 的 A5 用例通过——GetMaterialApp 下确实渲染出 '检测到有设备尚未关闭' 提示，当前卡片显示一栋热水且 find.text('默认') findsNothing（按 R4 以实际选中设备判断标记）。 |
| A6 | passed | brief.md | Scenario: 删除已设为默认的设备后，本机默认偏好被清理，重新进入页面选中列表第一台，且不报错、不残留旧运行态。 | 实现：logic.dart:777-809 `_deleteDevice` 在 result==true 后先 `await _clearDefaultDeviceIfMatches(deviceCode)`（logic.dart:770-775，仅当被删设备号等于当前默认设备号才清），再 `await getDeviceList()` 重新加载；清理走 clearDefaultDevice→prefs.remove，删除失败分支不触碰默认偏好（logic.dart:790-797）。清空后 `_applyDefaultDeviceSelection` 读到空 savedCode → 选 index 0。独立验证：zz_verifier_persistence_test.dart 的 A6 用例通过——删除默认设备 '200002' 后 prefs.containsKey('hot_water_default_device')==false、state.defaultDeviceCode==''、choiceDevice==0，且新建 controller 实例 getDeviceList() 后仍选中第一台；zz_verifier_widget_test.dart 的 A6 用例通过——走真实页面路径（选择列表→管理设备→删除默认设备→确认删除）后 prefs 键被清理、deviceList 只剩 1 台、choiceDevice==0，页面既无 '默认' 也无 '默认设备' 残留（无报错）。 |
| A7 | passed | brief.md | Scenario: 默认设备已被学校侧解绑（不在返回列表中）时，回退选中列表第一台，不崩溃、不残留旧运行态。 | 实现：logic.dart:349-356，当 savedCode 非空但在返回列表中找不到（index==-1，即已被学校侧解绑）时 `state.defaultDeviceCode=''` 并 `_assignChoiceDevice(0)`，不抛异常、不访问越界下标；_deviceIndexForCode（logic.dart:362-370）对不完整设备数据做了 is Map 保护。独立验证：zz_verifier_persistence_test.dart 的 A7 用例通过——预置默认 '999999'（不在列表）后 getDeviceList() 正常完成，choiceDevice==0、defaultDeviceCode==''、waterStatus==false、deviceCheckComplete==true；zz_verifier_widget_test.dart 的 A7 用例通过——页面渲染无异常，当前卡片显示 '一栋热水'（第一台）且无 '默认' 标记，无旧运行态残留。 |

## 检查

| 检查 | 命令 | 工作目录 | 状态 | 退出码 | 耗时 |
| --- | --- | --- | --- | ---: | ---: |
| flutter analyze | analyze | . | passed | 0 | 3450 ms |
| flutter test | test | . | passed | 0 | 21137 ms |

### Builder 报告的证据

以下为 Builder 报告，不等同于 Runtime 检查凭据或独立验收结果。

- flutter analyze: passed — 全量分析 No issues found。
- flutter test: passed — 全量 718 项通过。
- flutter test test/pages/water/: passed — 33 项通过，含新增 9 个用例。
- flutter test test/core/ui/performance_boundaries_test.dart: passed — 94 项通过，热水页结构断言未受影响。
- 已知限制: 默认设备按设备号全局存储，不按 HUT 账号分桶：不同账号共用同一台设备时偏好会互相影响。已按 D5 决策实现，跨账号时该设备号不在对方列表中会自然回退到第一台。
- 已知限制: 默认设备被学校侧解绑（不在设备列表中）时只回退选中第一台，本机偏好仍保留，设备重新绑定后会自动重新选中。
- 已知限制: 真机手工验收未执行：需用户在 App 内登录 HUT 账号、绑定多台设备后验证「选择设备」列表的星标入口与跨次进入页面的默认选中效果。

## 阻塞项

_无。_

## 风险与跳过的工作

- 持久化证据来自 shared_preferences 的测试平台 mock（SharedPreferences.setMockInitialValues）下的真实 SharedPreferencesHotWaterDevicePreferenceStore 实现，验证了键级读写/删键与跨 controller 实例读回；未做真机平台通道的磁盘往返（无设备环境），但实现使用插件标准的 setString/getString/remove 路径。
- A7 场景下持久化偏好本身被有意保留（仅运行时状态清空），设备重新绑定后会再次自动选中——这与 spec R2（解绑只要求回退第一台）、R5（仅删除时清理）及 brief D5 一致，非实现偏差，但若产品期望解绑即清盘需另行确认。
- logic.dart 仍直接 import shared_preferences 用于既有 hutUserInfo 持久化（与本 change 无关的旧代码）；默认设备路径本身已完全走可注入的 HotWaterDevicePreferenceStore 抽象。

## 之前的迭代

| 目标周期 | 迭代 | 尝试 | 结果 | 未解决项 | 摘要 | 完成时间 |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 1 | 1 | pass | — | 逐条核验 hot-water-default-device 的 7 项验收，全部通过。实现与需求一致：默认设备以 poscode 存储在 SharedPreferences（独立键 hot_water_default_device，与饮水页 device_order/device_note_* 不冲突），逻辑层只依赖可注入的 HotWaterDevicePreferenceStore 抽象；_applyDeviceList 先按默认设备号解析选中（缺失/解绑回退第一台），随后未关闭设备检查仍可覆盖并给出既有提示，符合 R2/R4 的顺序约束；星标入口只改默认不改本次选择、不关列表，删除默认设备会真实删键并回退第一台。核验方式：只读阅读 brief/spec 与实现 + 在仓库副本（/tmp/hwd-verify-67129，未改动被验工作树，git status 与开始时一致）中新增 13 个针对真实 SharedPreferences 存储与真实页面渲染的独立用例，全部通过：(1) `flutter test test/pages/water/zz_verifier_persistence_test.dart` → 6/6 通过（A1/A2 选型、A3 落盘与新 controller 读回、A4 取消默认删键、A5 未关闭设备优先、A6 删除清理、A7 解绑回退）；(2) `flutter test test/pages/water/zz_verifier_widget_test.dart` → 7/7 通过（含 '默认' 标记渲染、星标交互真实落盘、'检测到有设备尚未关闭' 提示可见、页面内删除默认设备后的清理与回退、解绑回退）。额外运行的检查仅为上述两个定向测试，未重跑 Runtime 已通过的 flutter analyze / flutter test 全量。 | 2026-10-22T01:51:40.957Z |



## 结论

逐条核验 hot-water-default-device 的 7 项验收，全部通过。实现与需求一致：默认设备以 poscode 存储在 SharedPreferences（独立键 hot_water_default_device，与饮水页 device_order/device_note_* 不冲突），逻辑层只依赖可注入的 HotWaterDevicePreferenceStore 抽象；_applyDeviceList 先按默认设备号解析选中（缺失/解绑回退第一台），随后未关闭设备检查仍可覆盖并给出既有提示，符合 R2/R4 的顺序约束；星标入口只改默认不改本次选择、不关列表，删除默认设备会真实删键并回退第一台。核验方式：只读阅读 brief/spec 与实现 + 在仓库副本（/tmp/hwd-verify-67129，未改动被验工作树，git status 与开始时一致）中新增 13 个针对真实 SharedPreferences 存储与真实页面渲染的独立用例，全部通过：(1) `flutter test test/pages/water/zz_verifier_persistence_test.dart` → 6/6 通过（A1/A2 选型、A3 落盘与新 controller 读回、A4 取消默认删键、A5 未关闭设备优先、A6 删除清理、A7 解绑回退）；(2) `flutter test test/pages/water/zz_verifier_widget_test.dart` → 7/7 通过（含 '默认' 标记渲染、星标交互真实落盘、'检测到有设备尚未关闭' 提示可见、页面内删除默认设备后的清理与回退、解绑回退）。额外运行的检查仅为上述两个定向测试，未重跑 Runtime 已通过的 flutter analyze / flutter test 全量。
