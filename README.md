# 工大盒子

**为湖南工业大学学生打造的第三方一站式服务应用**

基于 [cc2562/superhut](https://github.com/cc2562/superhut) fork 并持续维护，在原作功能基础上进行了架构重建、UI 全面翻新、性能深度优化和大量功能增强。

## 与上游的主要区别

### 架构重建

- **认证系统全面重写**：HUT 智慧工大门户认证从单步 CAS 改为完整闭环（CAS 重定向 → 门户票据 → 设备绑定 → Token 刷新），修复了"功能页点了没反应""切后台回来要重新登录"等长期问题
- **API 层模块化拆分**：`HutUserApi` 从单一文件拆为 auth / portal / session / support / water 五个 mixin 模块，边界清晰
- **凭据存储升级**：新增 `AppAuthStorage` 统一管理 JWXT + HUT 双登录系统的所有凭据，密码迁移至 `FlutterSecureStorage` 并保留自动回退机制
- **服务层新增**：`CourseSyncService`（非阻塞课表同步）、`AppUpdateService`（基于 GitHub Releases 的版本检查）、`AppLogger`（统一日志）
- **代码规范统一**：全仓 CamelCase 文件重命名为 `snake_case`，消除历史遗留的命名混乱

### UI 全面翻新

- **自研 Glass UI 系统**：`lib/core/ui/apple_glass.dart` 提供分层玻璃材质组件（`AppGlassBackground` / `GlassPanel`），支持 rich / soft / flat 三档性能策略；视觉效果默认轻量，布局级降级由 Android、系统减少动态或显式性能作用域控制
- **手写 Material 3 主题**：放弃 FlexColorScheme，自建完整的 light/dark `ColorScheme`，统一品牌蓝 #3B6EEA
- **课表页重做**：自定义 7 天 × 10 节网格布局、重叠课程布局算法、21 色调色板、课程详情弹层
- **底栏重做**：悬浮玻璃胶囊 + 外圈阴影绘制器（`_OuterOnlyShadowPainter`），三等分大热区点击
- **深色模式全面修正**：逐个页面消除硬编码颜色，统一使用 `colorScheme`
- **高刷新率适配**：Android 端自动请求 120Hz，优先匹配当前分辨率模式

### 新功能

- **课表库**：多份课表归档管理，支持 QR 码分享/导入、文件导入导出、剪贴板导入、重命名和删除
- **游客模式**：无需登录即可浏览功能页和使用慧生活 798，需要校园账号时再登录
- **非阻塞课表同步**：带进度报告的异步同步，不再卡住 UI
- **首次信任说明**：首次打开展示透明度和隐私说明，让用户清楚 App 连接哪些服务
- **项目支持页**：App 内查看支持方式和加密地址
- **课程删除**：支持手动删除不需要的课程条目

### 性能优化

- **GPU 过绘削减**：玻璃背景和重组件统一收敛到轻量策略，降低大面积 blur、阴影和重复 raster 成本
- **页面转场降级**：Android 使用 `AppLightPageTransitionsBuilder` 和 `buildAppPageRoute` 的轻量 fade + 微位移转场，避免默认重转场叠加
- **轻量玻璃策略**：视觉效果默认轻量，Android 及系统减少动态场景自动采用更保守的布局与动效
- **共享动效组件**：`AppAnimatedContainer`、`AppAnimatedSwitcher`、`AppLinearProgressIndicator`、`AppLoadingIndicator` 统一响应轻量/减少动态策略
- **弹层适配收敛**：页面层通过 `showAppAdaptiveBottomSheet` 打开弹层；Android 使用原生 Material bottom sheet，其他平台保留 Cupertino sheet
- **懒加载 + RepaintBoundary**：首页三大 tab 按需构建，功能卡片、路线转场和重组件隔离重绘层
- **弹层先出壳再挂内容**：课表库管理等重弹层先显示骨架，延迟挂载重内容
- **课表连续分页**：`PageView.builder` 渲染完整周序列，慢拖时相邻周内容持续进入视口

### 品牌变更

- 应用名称：超级包菜 → **工大盒子**
- 包名：`com.superhut.rice.superhut` → `com.tune.superhut`
- 全平台图标与窗口标题统一更新

## 主要功能

| 类别 | 功能 | 说明 |
|---|---|---|
| 学习 | 课表查询 | 自定义网格视图，支持周切换、实验课筛选、课表库管理 |
| 学习 | 成绩查询 | 按学期查询，缓存结果，深色模式可用 |
| 学习 | 考试安排 | 考试时间与考场信息，倒计时显示 |
| 学习 | 空教室查询 | 按校区/教学楼筛选，三列卡片网格，大节时间表达 |
| 学习 | 学生评教 | 批次获取、课程列表、选项选择与提交 |
| 生活 | 慧生活 798 | 扫码绑定饮水设备，手机号验证码登录 |
| 生活 | 宿舍热水 | 设备管理与洗澡卡充值，金粉暖色调 UI |
| 生活 | 电费充值 | 房间选择、余额查询、在线充值 |
| 系统 | 统一登录 | JWXT 教务系统 + HUT 智慧工大双登录，游客模式 |
| 系统 | 深色模式 | 全页面跟随系统明暗主题 |
| 系统 | 桌面小组件 | Android/iOS 课表桌面小组件 |
| 系统 | 课表分享 | QR 码、文件、剪贴板多种分享与导入方式 |

## 技术栈

- **框架**: Flutter 3.7+ / Dart 3.7+
- **状态管理**: GetX
- **网络**: Dio + dio_cache_interceptor
- **存储**: SharedPreferences + FlutterSecureStorage（密码安全存储）
- **WebView**: flutter_inappwebview
- **主题**: 手写 Material 3 ColorScheme（非 FlexColorScheme）
- **响应式**: responsive_framework
- **其他**: qr_flutter, share_plus, file_picker, encrypt, pub_semver

## 快速开始

```bash
git clone https://github.com/rccuu/superhut.git
cd superhut
flutter pub get
flutter run
```

构建发布包：

```bash
# Android 分架构 APK → releases/
bash scripts/build_android_release.sh

# iOS 未签名 IPA
bash scripts/build_ios_quick.sh
```

## 信任与隐私

- 源码、版本发布和更新入口均公开在 GitHub
- 业务域名均为学校系统和校园生活服务提供方
- 密码存储在系统安全存储中
- 完整说明见 [工大盒子的信任与隐私说明](docs/trust-and-privacy.md)

## 版本历史

从上游 v1.2.0 fork 后，已迭代至 v1.6.0。详细变更见 [changelog.md](changelog.md)。

## 许可证

GPL-3.0 — 查看 [LICENSE](LICENSE)

## 致谢

- 原作 [cc2562/superhut](https://github.com/cc2562/superhut) 及其贡献者
- 湖南工业大学各系统的维护团队
- Flutter 团队
