# Sip — Agent 项目手册

> 最后更新：2026-07-17（i18n en / zh-Hans）  
> 仓库：https://github.com/ArkURL/Sip  
> Bundle ID：`com.liao.Sip`  
> 平台：macOS 14.6+ · SwiftUI · Xcode（PBXFileSystemSynchronizedRootGroup，Sip/ 下文件自动入工程）

---

## 1. 产品是什么

**Sip** 是一款轻量 macOS 喝水提醒工具。

核心闭环：

1. 设定每日目标（默认 2000 ml）
2. 快捷记录当日摄入并累计
3. 进度可视化（圆环 + 菜单栏百分比）
4. 未达标时，在**选中的星期几**与活跃时段内按间隔本地通知；达标后当天停提醒

设计风格：清爽、原生 SwiftUI 组件、青色（cyan）水感主色、SF Symbols（`drop.fill` 等）。

### 1.1 MVP 范围内

- 每日目标、快捷加水量、自定义水量、撤销最近 / 删除记录
- 今日列表、进度环、达标态
- 本地通知 + 间隔 + 活跃时段 + **按周几启用** + 总开关
- 设置（主窗口齿轮在 toolbar / sheet；系统 Settings 场景）
- 菜单栏：进度、快捷 +100/+250、打开主窗口、设置、退出
- 首次引导（目标 + 通知权限）
- UserDefaults 持久化、自然日切换清零
- 主界面固定尺寸，避免记水后布局跳动
- App Icon（圆角 + 透明边距，Dock 光学尺寸约 80% 画布）

### 1.2 明确不做（勿擅自扩大范围）

- 多日历史 / 图表 / 周报
- iCloud / 账号 / 多设备同步
- Apple Health
- Widget / Siri / 复杂音效
- 饮品类型（茶/咖啡等）
- 应用内语言切换（跟随系统语言：`en` / `zh-Hans`）

---

## 2. 技术栈与工程

| 项 | 值 |
|----|-----|
| UI | SwiftUI + 少量 AppKit（窗口前置、菜单栏） |
| 通知 | `UserNotifications` |
| 存储 | `UserDefaults` + `Codable` JSON（无 Core Data / SwiftData） |
| 本地化 | `Localizable.xcstrings`（源语言 **en**，另有 **zh-Hans**）；跟随系统语言 |
| 测试 | `SipTests`（IntakeStore / 调度 / 持久化） |
| 签名 | Automatic Signing；打包需在 Xcode 选 Team |
| 部署 | `MACOSX_DEPLOYMENT_TARGET = 14.6` |

工程使用 **文件系统同步**（Xcode 新工程默认）：在 `Sip/`、`SipTests/` 下增删 `.swift` **无需** 手改 `project.pbxproj`。

---

## 3. 目录结构

```
Sip/
├── AGENTS.md                  ← 根入口，指向 .agent/
├── .agent/                    ← 本目录：Agent 接手文档
├── Sip/                       ← 主 target 源码
│   ├── SipApp.swift           ← App 入口：Window + MenuBarExtra + Settings
│   ├── ContentView.swift      ← 主界面
│   ├── Models/
│   │   ├── IntakeEntry.swift
│   │   └── AppSettings.swift
│   ├── Services/
│   │   ├── IntakeStore.swift       ← 状态中心 + 持久化 + 日切
│   │   ├── NotificationService.swift
│   │   └── ReminderScheduler.swift
│   ├── Views/
│   │   ├── ProgressRingView.swift
│   │   ├── QuickAddBar.swift
│   │   ├── IntakeListView.swift
│   │   ├── SettingsView.swift
│   │   └── OnboardingView.swift
│   ├── Utilities/
│   │   └── Date+Day.swift
│   ├── Localizable.xcstrings     ← en（源）+ zh-Hans
│   ├── Assets.xcassets/
│   │   └── AppIcon.appiconset/   ← mac_*_1x/2x.png
│   └── Sip.entitlements          ← App Sandbox 开启
├── SipTests/SipTests.swift
├── SipUITests/                   ← 模板 UI 测试（易卡住，优先跑 SipTests）
├── Sip.xcodeproj/
└── .gitignore
```

本地可能存在 `.venv-icon/`（生成图标用，已 gitignore），**不要提交**。

### 3.1 本地化约定

- **String Catalog**：`Sip/Localizable.xcstrings`；`developmentRegion = en`；`knownRegions` 含 `zh-Hans`。  
- UI 用 `Text("English key")`；代码用 `String(localized: "English key")` / 插值 `String(localized: "Still \(n) ml to go")`。  
- 日期：`DateFormatter` + `setLocalizedDateFormatFromTemplate` + `.autoupdatingCurrent`。  
- 星期短标签：`AppSettings.weekdayShortLabel(for:)` ← `Calendar.veryShortStandaloneWeekdaySymbols`。  
- **不**做应用内语言切换；跟随系统（系统偏好设置 → 语言与地区）。  
- 新增文案：先写英文 key，再在 catalog 补 `zh-Hans`。

---

## 4. 架构与数据流

```
┌─────────────────────────────────────────────────────────┐
│  SipApp                                                  │
│  · @StateObject IntakeStore                              │
│  · ReminderScheduler（onStateChanged → reschedule force） │
│  · Window("Sip", id: "main")  ← 单例主窗口               │
│  · MenuBarExtra → MenuBarMenuView                        │
│  · Settings { SettingsView }                             │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐     persist      ┌──────────────────┐
│  IntakeStore    │◄───────────────►│  UserDefaults    │
│  entries        │                  │  sip.todayEntries│
│  settings       │                  │  sip.settings    │
│  total/progress │                  │  sip.lastActiveDay│
└────────┬────────┘                  └──────────────────┘
         │ onStateChanged
         ▼
┌─────────────────┐     schedule     ┌──────────────────┐
│ReminderScheduler│────────────────►│ UNUserNotification│
│ nextFireDate()  │     cancel      │ center           │
└─────────────────┘                  └──────────────────┘
```

### 4.1 关键类型

**IntakeEntry**

- `id: UUID`, `amountML: Int`, `timestamp: Date`

**AppSettings**

- `dailyGoalML` 默认 2000，范围 500…5000  
- `reminderEnabled` 默认 true  
- `reminderIntervalMinutes` 默认 60，可选 30/45/60/90/120  
- `activeStartHour` / `activeStartMinute` / `activeEndHour` / `activeEndMinute` 默认 9:00–21:00  
- 活跃判定：**结束时刻含该分钟**（21:00 仍可提醒，21:01 不可）  
- `reminderWeekdays`：`[Int]`，Calendar weekday **1=周日 … 7=周六**；默认全部；`clamp` 时空数组回退为全周  
- `hasCompletedOnboarding`  
- `quickAmounts`：`[100, 150, 250, 350, 500]`  
- Codable 兼容：旧 JSON 缺 `reminderWeekdays` / 分钟字段时 decode 为全周、分钟 0

**IntakeStore**（`@MainActor` + `ObservableObject`）

- `addIntake` / `undoLast` / `removeEntry`  
- `ensureCurrentDay()`：跨自然日清空 entries  
- 计算属性：`totalML`、`remainingML`、`progress`、`isGoalReached`、`statusText`  
- `settings` 的 `didSet` 会 clamp + 持久化 + `onStateChanged`

**ReminderScheduler**

- 达标或关闭提醒 → 取消待发通知  
- 否则安排 **下一次** 本地通知（非排全天）  
- 活跃时段外 / 非选中星期 → `nextReminderOpportunity` 跳到下一允许日的时段起点  
- `nextFireDate(..., allowedWeekdays:)` 对单测开放  
- **`reschedule(force:)`**（易错）：  
  - `force: true` — 记水 / 撤销最近 / 跨日 / 引导完成 / 设置（debounce 后）→ 从 `now` 重算  
  - `force: false` — 开主窗 / becomeActive / 生命周期 tick / **删中间记录（未跨达标）** → 保留未来 fire  
  - `IntakeStore.ChangeKind`：`.force` / `.soft` / `.settings`（0.35s debounce）  
  - **`chainTimer`**：display fire +1.5s soft reschedule（菜单栏链不断）  
  - 系统 `add` 成功后才 `markDayStartNotified`  
  - 主窗：`identifier = "main"`（`MainWindowIdentifierBinder`），勿只靠高度找窗

### 4.2 日切策略

- `ensureCurrentDay()`：对比 `sip.lastActiveDay` 与今日 `dayKey`，跨日清空 entries。  
- 触发点：启动 / `didBecomeActive` / 写操作前 / **`DayLifecycleMonitor`**（日历日变、系统唤醒、午夜 Timer）/ 本地通知 willPresent·点击。  
- 关主窗口后菜单栏模式往往不会 `didBecomeActive`，因此 **不能只依赖 active**。  
- 开日通知：`sip.water.dayStart`（活跃时段起点，或睡过起点后补一次）；间隔通知：`sip.water.reminder`。  
- 去重键：`sip.lastDayStartNotifiedDay`。 

### 4.3 双入口设置

| 入口 | 方式 | 关闭 |
|------|------|------|
| 主窗口齿轮 | `.sheet` → `SettingsView(showsDismissButton: true)` | 顶部「完成」 |
| 菜单栏「设置…」 | `SettingsLink` → `Settings` scene | 系统窗口关闭钮 |

修改设置 UI 时两边共用 `SettingsView`，注意 `showsDismissButton` 默认 `false`。  
设置 `Form` 使用 `.scrollIndicators(.hidden)`。星期按钮选中态：青色实心底 + 白字（勿再加「每天/工作日/周末」预设条）。

---

## 5. 窗口与菜单栏（易错区）

### 5.1 主窗口必须是单例

- 使用 **`Window("Sip", id: "main")`**，**不要** 改回 `WindowGroup`（会重复开窗）。  
- `SipApp.mainWindowID == "main"`。  
- 菜单「打开 Sip」逻辑（`MenuBarMenuView.openMainWindow`）：  
  1. 若已有主窗口 → `makeKeyAndOrderFront` / `deminiaturize`  
  2. 否则 → `openWindow(id:)`  
- 识别主窗口：可成为 key、非 status/menu、高度 ≥ 480（与设置窗约 420 区分）。

### 5.2 菜单栏

- 记录 +100 / +250、撤销、打开 Sip、`SettingsLink`、退出。  
- 打开窗口相关逻辑放在 **独立 View**（`MenuBarMenuView`），才能用 `@Environment(\.openWindow)`。  
- 勿再依赖 fragile 的 `showSettingsWindow:` 作为主路径。

### 5.3 应用生命周期与 Dock

- 关主窗口后 App 仍可因 **MenuBarExtra** 存活（`applicationShouldTerminateAfterLastWindowClosed` → `false`）。  
- **Dock 策略**（`DockPolicy` + `AppDelegate`）：  
  - 有用户窗口（主窗口 / 设置窗，含最小化）→ `setActivationPolicy(.regular)`，Dock 有图标。  
  - 关闭最后一个用户窗口 → `.accessory`，**从 Dock 消失**，仅保留菜单栏。  
  - 菜单「打开 Sip」会先 `showInDock()` 再 `activate` / `openWindow`（accessory → regular 顺序重要）。  
- 退出：菜单「退出 Sip」→ `NSApp.terminate`。

---

## 6. App Icon 约定

路径：`Sip/Assets.xcassets/AppIcon.appiconset/`

| 要求 | 说明 |
|------|------|
| 文件名 | `mac_{size}_{1x\|2x}.png`（避免文件名含 `@`，部分工具链会异常） |
| 形状 | 圆角在 **PNG alpha** 内；圆角外 **alpha=0** |
| 光学尺寸 | 不透明主体约占画布 **~80%**（与 Dock 系统图标对齐） |
| 错误做法 | 全出血无圆角 → Dock 显方块；铺满圆角无边距 → 显过大；半透明四角 → 圆角外一圈填充 |

改图标后：Clean + Run；必要时 `killall Dock`。

---

## 7. 构建、测试、运行

```bash
# 编译
xcodebuild -scheme Sip -destination 'platform=macOS,arch=arm64' build

# 仅单元测试（推荐；完整 test 可能被 UITests 拖住）
xcodebuild -scheme Sip -destination 'platform=macOS,arch=arm64' \
  -only-testing:SipTests test
```

Xcode：Scheme **Sip** → My Mac → Run。

### 打包（给用户本机 / 分发）

1. Signing & Capabilities 选 **Team**  
2. Product → Archive → Distribute → 导出 `Sip.app`  
3. 对外分发需 Developer ID + 公证（付费账号）

Debug 下 Memory 基线 **~40–80MB** 对 SwiftUI macOS 小应用常见，优先看是否持续上涨，勿误判为泄漏。

---

## 8. 代码风格与约定

- UI 文案：**中文**  
- 单位：仅 **ml**  
- 新功能优先接 `IntakeStore`，避免平行状态源  
- 设置变更必须触发提醒重调度（现有 `onStateChanged` 路径）  
- 持久化 key 已占用：`sip.todayEntries` / `sip.settings` / `sip.lastActiveDay` — 迁移时兼容旧 key  
- 少加依赖；无 SPM 第三方包  
- 不提交：`.venv-icon/`、`xcuserdata`、DerivedData、密钥  

---

## 9. 测试要点（SipTests）

现有覆盖：

- 累计 / 达标 / 撤销 / 非法水量  
- settings clamp  
- 活跃时段判断  
- `nextFireDate` 时段内 / 时段外  
- UserDefaults suite 隔离的持久化 round-trip  

新增逻辑时：优先给 Store / Scheduler 补单测，少依赖 UI 测试。

---

## 10. 已知问题与历史坑

| 问题 | 处理 / 状态 |
|------|-------------|
| 菜单「打开 Sip」无响应 | 用 `openWindow` + 独立 MenuBar View |
| 重复开主窗口 | `Window` 单例 + 先 find 再 open |
| 齿轮设置无关闭按钮 | sheet 使用 `showsDismissButton: true` +「完成」 |
| 记水后界面上顶裁切 | 主界面固定 frame；列表区固定高度 |
| 内容区与标题栏双 Sip | 仅窗口标题保留品牌；设置用 toolbar |
| Dock 图标方块 / 过大 / 圆角脏边 | 见 §6；勿随意改成全出血无透明 |
| UITests / 管道缓冲拖死终端 | 用 `-only-testing:SipTests`；少用 `\| tail` 包住长时间 xcodebuild |
| 图标缓存 | Clean Build Folder；`killall Dock` |

---

## 11. 建议的后续迭代方向（未做）

按产品需要挑选，**不要** 一轮全做：

1. 通知 Action：`+250ml` / 稍后  
2. 多日历史 + 简单图表（再考虑 SwiftData）  
3. 菜单栏 Popover 代替纯 Menu（一眼看进度）  
4. 开机启动 / 登录项  
5. 更细的安静时段（午休等）  
6. 单元测试：日切边界、onboarding 标志  

---

## 12. Agent 工作清单模板

接到任务时建议：

- [ ] 读本文件相关章节 + `CHANGELOG-AGENT.md`  
- [ ] `git status` / 确认未提交改动是否与任务相关  
- [ ] 最小改动实现；不扩 scope  
- [ ] `xcodebuild … build` 与相关 `SipTests`  
- [ ] 手动点一遍：主窗口、菜单栏打开/设置、加水量、设置完成关闭  
- [ ] 更新 `CHANGELOG-AGENT.md`；架构变化则改 `PROJECT.md`  

---

## 13. 关键文件速查

| 任务 | 先看 |
|------|------|
| 改主界面布局 | `ContentView.swift`, `Views/*` |
| 改目标/提醒规则 | `AppSettings.swift`, `IntakeStore.swift`, `ReminderScheduler.swift` |
| 改通知文案/权限 | `NotificationService.swift`, `OnboardingView.swift` |
| 改菜单栏 | `SipApp.swift` → `MenuBarMenuView` |
| 改窗口行为 | `SipApp.swift`（保持 `Window` 单例） |
| 改设置页 | `SettingsView.swift` + ContentView sheet 参数 |
| 改图标 | `AppIcon.appiconset` + §6 |
| 加测试 | `SipTests/SipTests.swift` |
