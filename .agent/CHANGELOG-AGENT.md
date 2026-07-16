# Agent 变更日志

按时间倒序追加。每条写清：**日期、做了什么、为何、影响哪些文件、是否已提交**。

---

## 2026-07-16 — 窗口单例 + 设置关闭按钮（未提交时请核对 git status）

- **打开 Sip 重复弹窗**：`WindowGroup` → 单例 `Window("Sip", id: "main")`；菜单栏先 `findMainWindow` 再 `openWindow`。  
- **齿轮设置无关闭钮**：`SettingsView(showsDismissButton:)`，sheet 显示「完成」调用 `dismiss`。  
- **文件**：`Sip/SipApp.swift`, `Sip/ContentView.swift`, `Sip/Views/SettingsView.swift`  
- **提交**：请用 `git status` 确认（文档撰写时本地可能仍有未提交改动）。

## 2026-07-15 — 菜单栏打开窗口 / 设置无响应

- 抽出 `MenuBarMenuView`，使用 `openWindow` 与 `SettingsLink`。  
- **文件**：`Sip/SipApp.swift`

## 2026-07-15 — App Icon

- 水滴主题图标；圆角 alpha + 约 80% 光学边距，修复 Dock 方块/过大/脏边。  
- **文件**：`Sip/Assets.xcassets/AppIcon.appiconset/*`  
- **提交**：`5f4482e` Add Sip app icon with correct macOS Dock sizing  

## 2026-07-15 — 初始 MVP

- 喝水记录、进度环、设置、本地通知调度、菜单栏、引导、UserDefaults、SipTests。  
- **提交**：`07c31ca` Initial commit: Sip macOS water reminder MVP  
- **远程**：https://github.com/ArkURL/Sip  

## 2026-07-16 — 新增 / 迁移 Agent 文档

- 新增 Agent 接手文档；目录定为 **`.agent/`**（`README.md`, `PROJECT.md`, `CHANGELOG-AGENT.md`），根目录 `AGENTS.md` 作入口。
