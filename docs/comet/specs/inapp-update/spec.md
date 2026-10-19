# 应用内更新下载与安装

## Outcome

检测到新版本后，用户可在应用内直接下载安装包：页面顶部出现下载进度横幅，下载期间可正常使用应用；Android 下载完成后自动唤起系统安装；iOS 下载完成后弹系统分享面板把安装包交给 TrollStore 导入。

## Requirements

### R1 下载通道

- 从 GitHub Release 选中的安装包直链（现有 `AppUpdateInfo.downloadUrl`）用现有 Dio 流式下载到应用临时目录，文件名沿用 Release 资产名。
- 下载过程回报进度（已下载字节 / 总字节），不阻塞 UI 主线程交互。
- 下载中可取消；取消后终止请求并清理半截文件。
- 下载失败时给出失败状态，可重试；重试前清理半截文件。
- 同一 tag 的安装包已在本地完整存在时直接复用，不重复下载。

### R2 顶部进度横幅

- 下载开始后页面顶部（安全区下方）出现横幅，显示进度（百分比或进度条）。
- 横幅不阻塞页面交互；用户可继续使用全部功能。
- 横幅带取消操作；下载完成或取消后横幅消失；失败时横幅提示失败并可重试或打开发布页。
- 层级与现有 `_CourseSyncOverlay` 习惯一致，不遮挡关键操作。

### R3 Android 安装

- `AndroidManifest.xml` 新增 `REQUEST_INSTALL_PACKAGES` 权限与 `FileProvider` 声明（含 `file_paths.xml`）。
- 下载完成后通过 MethodChannel 调用原生代码，用 FileProvider content URI 发起 ACTION_VIEW/ACTION_INSTALL_PACKAGE 安装意图，自动唤起系统安装确认页。
- Android 8+ 发起安装前检查 `canRequestPackageInstalls`；未授权时先引导用户到「安装未知应用」系统设置页，返回后可继续安装。

### R4 iOS 交付

- 下载完成后用系统分享面板分享本地安装包文件，由用户交给 TrollStore 导入安装；取消分享不报错、横幅正常结束。

### R5 入口统一

- 首页启动检测的更新弹窗与「我的-关于」页的检查更新入口，主操作统一改为应用内下载；两条入口共用同一下载状态（避免重复下载、重复横幅）。
- Android 无 `downloadUrl` 或非 Android/iOS 平台时回退现有「打开发布页」行为。

## Scenario

- Scenario: Android 上在更新弹窗点击「下载安装包」，页面顶部出现下载进度横幅，进度随下载推进；期间切换标签页、使用各功能页面不受影响。
- Scenario: Android 下载完成后自动唤起系统安装确认页；未授予「安装未知应用」权限时先跳系统设置引导，返回后可继续安装。
- Scenario: iOS 下载完成后弹出系统分享面板分享安装包文件，可交给 TrollStore 导入；取消分享不报错。
- Scenario: 下载中点击横幅取消按钮，下载终止、横幅消失，再次触发下载可正常重新开始。
- Scenario: 下载失败时横幅提示失败，可重试，也可改为打开发布页。
- Scenario: 同一 tag 的安装包已下载成功后再次触发更新，直接复用本地文件，不重复下载。
- Scenario: Release 没有可用安装包资产时，更新弹窗回退为「打开发布页」。
