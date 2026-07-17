# Agent 变更日志

按时间倒序追加。每条写清：**日期、做了什么、为何、影响哪些文件、是否已提交**。

---

## 2026-07-17 — UI 轻 polish → 1.1.1

- 新增 `SipTheme`（accent / 渐变 / 圆角）。  
- 进度环：径向淡底 + angular 渐变描边 + 轻阴影；达标色统一为水感绿。  
- 快捷记水：更大 chip、统一软填充（无 250 高亮；Custom 同色）；按下微缩。  
- 列表：左侧 cyan 条、ml 强调色、空态改 `drop`、面板细描边。  
- 引导/设置 chip 同步 theme 色。  
- **版本**：1.1 → **1.1.1**，build 2 → **3**。  
- **文件**：`SipTheme.swift`（新）, Views, `project.pbxproj`, README*  
- **提交 / tag**：`v1.1.1`  

## 2026-07-17 — i18n + 版本 1.1 + README

- 新增 `Sip/Localizable.xcstrings`（源语言 en + zh-Hans）；`project.pbxproj` knownRegions 加入 zh-Hans。  
- UI / 通知 / 状态 / 菜单栏文案改为 `Text("…")` / `String(localized:)`；日期与星期随系统 locale。  
- **版本**：`MARKETING_VERSION` 1.0 → **1.1**，`CURRENT_PROJECT_VERSION` 1 → **2**；设置页从 Bundle 读版本。  
- README / README_en 同步 1.1 功能与语言说明。  
- **文件**：`Localizable.xcstrings`（新）, 各 View/Service, `AppSettings.swift`, `project.pbxproj`, README*, `.agent/*`, `SipTests`  
- **提交**：本条一并 commit  

## 2026-07-17 — 修复 DMG 背景与拖拽安装布局

- **问题**：`release.yml` 把背景指到卷内 `.github:dmg_background.png`，但未拷入卷，背景失效。  
- **修复**：挂载 RW 卷后写入 `.background/background.png`，AppleScript 用 `.background:background.png`；窗口 660×400 与背景图一致；图标位 (180,200)/(480,200) 对齐箭头。  
- **品牌背景**：嵌入 App Icon 水滴 + 中英文安装指引；脚本 `.github/scripts/generate_dmg_background.py` 可重生。  
- **本地冒烟**：BACKGROUND_OK + DS_STORE_OK。  
- **文件**：`.github/workflows/release.yml`, `.github/dmg_background.png`, `.github/scripts/generate_dmg_background.py`  
- **提交**：本条一并 commit  

## 2026-07-17 — 主界面显示下次提醒时间

- 进度环下方增加次要文案：`下次提醒 HH:mm` / `明天 HH:mm` / `提醒已关闭` / `今日已达标…` / `即将提醒`。  
- `ReminderScheduler` 变为 `ObservableObject`，`status` 在 `reschedule()` 时更新；`AppSession.scheduler` 启动即创建并注入 `ContentView`。  
- **文件**：`ReminderScheduler.swift`, `ProgressRingView.swift`, `ContentView.swift`, `SipApp.swift`, `SipTests.swift`  
- **提交**：未提交  

## 2026-07-17 — 跨日自动刷新进度 + 开日提醒通知

- **问题**：关窗后菜单栏保活时，睡眠跨日/次日唤醒不会走 `didBecomeActive`，进度仍显示昨天。  
- **日切监听**（`DayLifecycleMonitor`）：`NSCalendarDayChanged`、`NSWorkspace.didWakeNotification`、本地午夜 Timer；通知展示/点击也会触发刷新。  
- **开日通知**：到达活跃时段起点（或睡过起点后补发一次）推送「今日喝水提醒开始」；之后仍按间隔提醒。  
- **结构**：`AppSession` 持有 store/scheduler/monitor，转发 `objectWillChange` 保证菜单栏百分比更新。  
- **文件**：`DayLifecycleMonitor.swift`（新）, `ReminderScheduler.swift`, `NotificationService.swift`, `IntakeStore.swift`, `SipApp.swift`, `SipTests.swift`  
- **验证**：BUILD SUCCEEDED；SipTests 17 passed  
- **提交**：未提交  

## 2026-07-17 — 关闭窗口后隐藏 Dock 图标

- **行为**：关闭主窗口/设置窗后切换 `NSApp` 激活策略为 `.accessory`，Dock 不再占位；进程由 `MenuBarExtra` 保活。再打开窗口时切回 `.regular`。  
- **实现**：`DockPolicy` + `AppDelegate`（监听 `willClose` / `didBecomeKey`；`applicationShouldTerminateAfterLastWindowClosed` = false）。打开主窗口前先 `showInDock()`。  
- **文件**：`Sip/SipApp.swift`，`.agent/PROJECT.md`，本日志  
- **提交**：未提交  

## 2026-07-16 — 按星期提醒 + 主界面布局稳定 + 设置 UI 打磨

- **按周几提醒**：`AppSettings.reminderWeekdays`（Calendar weekday 1=日…7=六）；设置里七天切换（选中：青色实心底+白字）；调度跳过未选中日。旧设置 JSON 无该字段时默认可每天提醒。  
- **无快捷预设**：去掉「每天/工作日/周末」按钮，只保留单日按钮。  
- **设置滚动条**：`Form.scrollIndicators(.hidden)`。  
- **主界面布局**：固定内容尺寸 + 记录列表固定高度，避免首次记水后内容上顶裁切。  
- **标题去重**：去掉内容区「Sip」标题，设置进 toolbar。  
- **文件**：`AppSettings.swift`, `Date+Day.swift`, `ReminderScheduler.swift`, `SettingsView.swift`, `ContentView.swift`, `IntakeListView.swift`, `SipApp.swift`, `SipTests.swift`  
- **提交**：随本条一并 commit（见 git log）。

## 2026-07-16 — 窗口单例 + 设置关闭按钮 + Agent 文档

- **打开 Sip 重复弹窗**：`WindowGroup` → 单例 `Window("Sip", id: "main")`；菜单栏先 `findMainWindow` 再 `openWindow`。  
- **齿轮设置无关闭钮**：`SettingsView(showsDismissButton:)`，sheet 显示「完成」调用 `dismiss`。  
- **文件**：`Sip/SipApp.swift`, `Sip/ContentView.swift`, `Sip/Views/SettingsView.swift`, `.agent/*`, `AGENTS.md`  
- **提交**：`c0341e2`

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
