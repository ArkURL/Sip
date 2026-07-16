# Sip

[English](README_en.md)

一款轻量 macOS 喝水提醒工具。

## 功能

- 设定每日饮水目标（默认 2000ml）
- 快捷记录饮水量（+100 / +250 / 自定义）
- 进度圆环 + 菜单栏百分比显示
- 本地通知提醒，支持自定义间隔与活跃时段
- 按星期几启用提醒
- 达标后当天停止提醒
- 首次引导设置
- 原生 SwiftUI，清爽青色主题

## 安装

1. 前往 [Releases](../../releases) 下载最新版 `Sip.dmg`
2. 双击打开，将 Sip 拖入 Applications 文件夹
3. 首次打开时，**右键 → 打开**（或在终端运行以下命令后双击打开）：

```bash
xattr -cr /Applications/Sip.app
```

4. 如果提示通知权限，点击「允许」

## 系统要求

- macOS 14.6 或更高版本

## 构建

```bash
git clone https://github.com/ArkURL/Sip.git
cd Sip
xcodebuild -scheme Sip -destination 'platform=macOS,arch=arm64' build
```

## 技术栈

- SwiftUI
- UserNotifications
- UserDefaults 持久化
- 无第三方依赖

## License

MIT
