# Sip

[English](README_en.md)

一款轻量 macOS 喝水提醒工具。

**当前版本：1.1.4**

## 功能

- 设定每日饮水目标（默认 2000ml）
- 快捷记录饮水量（+100 / +250 / 自定义）
- 进度圆环 + 菜单栏百分比显示
- 主界面显示下次提醒时间
- 本地通知提醒，支持自定义间隔与活跃时段
- 按星期几启用提醒；时段起点会发「开日」通知
- 达标后当天停止提醒
- 关主窗口后仅保留菜单栏（不占 Dock）；菜单栏可随时再打开窗口
- 跨日 / 唤醒后自动清零并刷新进度
- 中英文界面（跟随系统语言）
- 首次引导设置
- 原生 SwiftUI，清爽青色主题

## 安装

1. 前往 [Releases](../../releases) 下载最新版 `Sip.dmg`
2. 双击打开，**将 Sip 拖入 Applications**（安装窗口内有箭头指引）
3. 首次打开时，**右键 → 打开**（或在终端运行以下命令后双击打开）：

```bash
xattr -cr /Applications/Sip.app
```

4. 如果提示通知权限，点击「允许」

## 系统要求

- macOS 14.6 或更高版本

## 语言

界面语言跟随系统：

- 简体中文
- English

可在 **系统设置 → 语言与地区** 中调整首选语言后重启应用。

## 构建

```bash
git clone https://github.com/ArkURL/Sip.git
cd Sip
xcodebuild -scheme Sip -destination 'platform=macOS,arch=arm64' build
```

打 tag 发布（触发 GitHub Actions 打包 DMG）：

```bash
git tag v1.1.4
git push origin v1.1.4
```

## 技术栈

- SwiftUI + 少量 AppKit
- UserNotifications
- UserDefaults 持久化
- String Catalog 本地化（`en` / `zh-Hans`）
- 无第三方依赖

## License

MIT
