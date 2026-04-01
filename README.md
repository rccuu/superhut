# 工大盒子

**为湖南工业大学学生打造的第三方一站式服务应用**

## 📱 项目简介

为提供更便捷的第三方校园工具体验，我们在原项目基础上进行 fork 与二次开发，持续维护这个更易用、界面更统一的校园工具版本。

## 🍴 Fork 说明

- 当前维护仓库：`rccuu/superhut`
- 仓库地址：https://github.com/rccuu/superhut
- 原作仓库：`cc2562/superhut`
- 原作地址：https://github.com/cc2562/superhut

当前项目基于原作仓库 fork 后继续维护与调整，包含界面、文案、图标与部分功能体验上的二次开发。

仓库名与 Dart/包名目前仍沿用 `superhut`，应用对外显示名称为 `工大盒子`。

## ✨ 主要功能

### 🎓 学习服务
- **📅 课表查询** - 查看个人课程安排
- **📊 成绩查询** - 实时查询各学期成绩和学分
- **📝 考试安排** - 查看考试时间表和考场信息
- **🏫 空教室查询** - 快速查找可用教室，支持按教学楼筛选

### 🏠 生活服务
- **💧 宿舍喝水** - 一键购买宿舍饮用水
- **🚿 洗澡服务** - 便捷的洗澡卡充值和管理
- **⚡ 电费充值** - 宿舍电费查询和在线充值
- **💧 水费管理** - 宿舍水费查询和充值服务

### 📋 其他功能
- **📝 学生评教** - 参与课程评价和教学质量反馈
- **🔐 统一登录** - 支持HUT统一身份认证系统
- **🌙 深色模式** - 支持明暗主题切换
- **📱 Android 桌面小组件** - 课表与快捷功能快速查看
- **🔔 智能提醒** - 电费预警、课程提醒等功能

## 🛠️ 技术栈

- **框架**: Flutter 3.7.0+
- **状态管理**: GetX
- **网络请求**: Dio
- **本地存储**: SharedPreferences + flutter_secure_storage
- **WebView**: flutter_inappwebview
- **UI组件**: Material Design 3
- **主题**: FlexColorScheme
- **图标**: Ionicons
- **二维码**: qr_code_scanner

## 📦 安装说明

### 环境要求
- Flutter SDK 3.7.0 或更高版本
- Dart SDK 3.7.0 或更高版本
- Android Studio / VS Code
- Android SDK (Android 5.0+)
- iOS SDK (iOS 11.0+) - 仅iOS开发需要

### 安装步骤

1. **克隆项目**
```bash
git clone https://github.com/rccuu/superhut.git
cd superhut
```

2. **安装依赖**
```bash
flutter pub get
```

3. **运行项目**
```bash
# 调试模式
flutter run

# 发布模式
flutter run --release
```

### 构建发布版本

```bash
# Android 分架构 APK，并移动到 releases/
bash scripts/build_android_release.sh

# Android App Bundle
flutter build appbundle --release

# iOS 未签名 IPA
bash scripts/build_ios_quick.sh

```

## 🚀 开发指南

### 添加新功能
1. 在 `lib/pages/` 下创建新的功能模块
2. 在 `lib/home/Functionpage/view.dart` 中添加功能入口
3. 更新路由配置和状态管理

### 代码规范
- 使用 GetX 进行状态管理
- 遵循 Flutter 官方代码规范
- 使用有意义的方法和变量命名
- 添加适当的注释和文档

## 🔒 为什么可以相对放心使用

如果你不熟悉 GitHub，也不想先读源码，可以先看这几条：

- 当前仓库、上游仓库和版本发布页都是公开的
- 应用内更新检查直接读取 GitHub Releases
- 当前公开代码中可见的业务域名主要是学校系统、校园生活服务提供方和 GitHub
- 密码优先保存在系统安全存储中，登录态和缓存默认保存在本机

更完整的说明见：

- [工大盒子的信任与隐私说明](docs/trust-and-privacy.md)

## ❤️ 支持项目

想支持的话，可以在 App 内查看方式。

- App 内入口：`我的 -> 关于工大盒子 -> 支持项目`
- 页面内支持查看二维码大图和一键复制当前网络地址
- 转账前请务必确认网络一致，转错链无法找回

当前支持的网络与地址：

- `TRC20`：`TNvVV3XgpDbnfT8kAVB5Pwe7UYVCfqekDT`
- `BSC (BEP-20)`：`0xca48641aad9c37f74d2999686799deaee95b6105`

## 🤝 贡献指南

我们欢迎所有形式的贡献！

1. Fork 本项目
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 开启 Pull Request

## 📄 许可证

本项目采用 GPL-3.0 license - 查看 [LICENSE](LICENSE) 文件了解详情

## 📦 版本发布

- Releases: https://github.com/rccuu/superhut/releases
- 应用内更新检查当前也基于 GitHub Releases

## 🙏 致谢

- 感谢所有为项目做出贡献的开发者
- 感谢Flutter团队提供的优秀框架
