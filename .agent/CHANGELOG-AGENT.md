# Agent 变更日志

按时间倒序追加。每条写清：**日期、做了什么、为何、影响哪些文件、是否已提交**。

---

## 2026-07-17 — 修复通知权限状态一直显示「未设置」

- **问题**：系统设置里已允许通知，App 设置页仍显示「未设置」。  
- **原因**：权限状态放在 `SettingsView` 的 `@State` 默认值 `.notDetermined`；App/store 刷新重建视图时状态回落且刷新不可靠；async `notificationSettings` 在部分路径不稳。  
- **修复**：`NotificationPermissionModel` 挂到 `AppSession`；`getNotificationSettings` completion API；打开设置 / 回前台 / `.task` 刷新。  
- **文件**：`NotificationService.swift`, `SipApp.swift`, `SettingsView.swift`, `ContentView.swift`  
- **验证**：SipTests 32 passed  
- **提交**：本条一并 commit  

## 2026-07-17 — Release 1.1.4：修复设置页「允许通知」无响应

- **问题**：设置里点「允许通知…」无系统弹窗、状态也不变。  
- **原因**：菜单栏 accessory 模式下未先激活 App，`requestAuthorization` 可能静默失败；Form 内嵌套 `VStack+Button` 点击命中不稳；授权成功后未 force 重调度。  
- **修复**：请求权限前 `DockPolicy.showInDock` + `NSApp.activate`；扁平 Form 行；授权成功 `refreshRemindersAfterPermissionChange`；弹窗未出现时回退打开系统通知设置。  
- **版本**：1.1.3 → **1.1.4**，build 5 → **6**。  
- **文件**：`NotificationService.swift`, `SettingsView.swift`, `IntakeStore.swift`, `SipApp.swift`, `project.pbxproj`, README*  
- **验证**：build OK；SipTests 32 passed  
- **提交 / tag**：`v1.1.4`  

## 2026-07-17 — Release 1.1.3：P0/P1 提醒修复 + 中优先级 polish

### P0 / P1
- **间隔链**：`chainTimer`（fire+1.5s soft reschedule），菜单栏 accessory 不依赖 `willPresent`。  
- **调度结果**：`scheduleReminder` → `async Bool`；开日标记仅 `add` 成功后写入。  
- **点通知开窗**：`MainWindowPresenter` + `.sipOpenMainWindow`。  
- **时段分钟 + 结束含本分钟**：`activeStart/EndMinute`；旧 JSON 分钟缺省 0。  
- **通知权限 UI**：设置页状态 + 系统设置 / 再请求。  

### 中优先级
- **设置 debounce**：`ChangeKind.settings` → AppSession 0.35s 合并 force（滑块不 thrash）。  
- **删记录**：未跨达标线 → `soft` 保留下次提醒；跨达标线 → `force`。记水/撤销/日切仍 `force`。  
- **主窗识别**：`MainWindowIdentifierBinder` 打 `identifier = "main"`；`findMainWindow` 优先 id。  

### 版本 / 验证
- **版本**：1.1.2 → **1.1.3**，build 4 → **5**。  
- **SipTests**：32 passed。  
- **提交 / tag**：`v1.1.3`  

## 2026-07-17 — 修复打开主界面推迟下次提醒 → 1.1.2

- **问题**：关主窗口后未记水，再从菜单栏打开 Sip 时，下次提醒被重算为「打开时刻 + 间隔」，把原定时间往后推。  
- **原因**：`reschedule()` 一律 `cancel + now + interval`；`ContentView.onAppear` / `didBecomeActive` / `refreshDayAndReminders` 都会触发。  
- **修复**：  
  - `reschedule(force:)` — `force: true` 在记水 / 改设置 / 跨日 / 引导完成后从 now 重算；  
  - `force: false`（开窗、前台、生命周期 tick）保留已提交的未来 fire（`sip.nextScheduledFire` + 校验活跃时段/星期）。  
  - 通知真正到期后 soft 刷新会因 fire 已过期而排下一轮。  
- **版本**：1.1.1 → **1.1.2**，build 3 → **4**。  
- **文件**：`ReminderScheduler.swift`, `SipApp.swift`, `ContentView.swift`, `SipTests.swift`, `project.pbxproj`, README*  
- **验证**：SipTests 24 passed  
- **提交 / tag**：`v1.1.2`  

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
