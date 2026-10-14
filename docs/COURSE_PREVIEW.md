# 安卓课堂网页兼容版（实验性，尚未实机验证）

基于上游 master 的 83a9d70ad1bbb7c4c07a7292baca3439ecde7be3。

## 已实现

- 识别官方 `/cheese/play/ss数字` 和 `/cheese/play/ep数字` 链接。
- 搜索框粘贴链接/分享文字、系统分享、剪贴板确认和短链接展开后的课程入口。
- 使用 Android WebView 打开官方桌面课堂页面，复用 Android CookieManager 登录态。
- 阻止跳到普通首页及唤起外部 App；保留官方网页的购买权限判定。
- 加载错误提示、刷新、切到后台时尝试暂停网页媒体。

## 明确限制

这是官方网页兼容入口，不是原生付费课程播放器。尚未用已购账号验证该课程，不保证官方网页允许在 Android WebView 播放。官方若要求 App、DRM、额外验证或改变网页路由，需要继续适配，不能通过绕过权限来解决。
不提供自动已购列表、原生笔记、缓存、原生全屏和播放进度集成。网页自身可能仍显示课程推荐；顶层导航限制并不等同于删除全部网页推荐。登录跳转被阻止时先返回“我的”完成登录，再重开课程。
当前执行环境没有 Flutter/Dart/Android SDK：未执行 flutter analyze/test 或 APK 编译。新增测试与工作流待运行，不能视为已通过。

## 获得 APK

1. 在自己的 GitHub 账号 Fork 原项目，将此修改上传到 Fork 的分支。不要直接覆盖其他版本的同名源文件。
2. 补丁仅适用于上述基线：`git apply --check focubili-course-preview.patch` 成功后执行 `git apply focubili-course-preview.patch`，提交并推送。完整源码包则可直接作为分支内容使用。
3. GitHub 仓库 Actions → Android course preview → Run workflow，选择含修改的分支。
4. 全部检查与编译成功后，在该次运行的 Artifacts 下载 `FocuBili-course-preview-debug`，解压得到 APK。
5. 上游 Debug 已配置独立包名 `com.focubili.app.preview`，可与正式版共存，无需卸载正式版。测试版数据和登录态独立，需要在测试版重新登录；本实现会复用测试版内部的登录态。
6. 安装后在“我的”登录购买课程的账号，搜索框粘贴：
   `https://www.bilibili.com/cheese/play/ss968174948`

若不熟悉 Git，可将源码包交给开发者编译；压缩包不是 APK。

## 验收清单（需要真实安卓平板）

- 已购账号：目录、第一节/后续章节、倍速、拖动、画面声音均正常。
- 未购和退出账号：仍由官方显示登录/购买/试看要求。
- 断网刷新有错误提示，网络恢复后可以重试。
- 分享/搜索/剪贴板三种入口都能打开相同课程。
- 普通 BV 视频和原生播放器没有回归。
- 原生视频播放期间打开课程不会双重出声；返回、锁屏与后台无持续声音。
- 横屏平板布局、页面内播放和触控正常。

如页面打不开或提示只能使用官方 App，请记录平板型号、Android/WebView版本、登录方式、错误原文或不含账号隐私的截图。不要分享 Cookie、SESSDATA、密码或短信验证码。
