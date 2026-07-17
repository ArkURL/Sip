# Sip

[中文](README.md)

A lightweight macOS water drinking reminder.

**Current version: 1.1.7**

## Features

- Set daily water intake goal (default 2000ml)
- Quick add buttons (+100 / +250 / custom)
- Progress ring + menu bar percentage display
- Next reminder time on the main window
- Local notification reminders with custom interval and active hours
- Enable reminders by weekday; day-start notification at the active window open
- Auto-stop reminders when the daily goal is reached
- Closing the main window keeps only the menu bar (no Dock tile); reopen anytime from the menu
- Auto day rollover and progress refresh after midnight / system wake
- English & Simplified Chinese UI (follows system language)
- First-launch onboarding
- Native SwiftUI with a clean cyan theme

## Installation

1. Download the latest `Sip.dmg` from [Releases](../../releases)
2. Double-click to open and **drag Sip into Applications** (arrow guide in the installer window)
3. On first launch, **right-click → Open** (or run the following command in Terminal, then double-click to open):

```bash
xattr -cr /Applications/Sip.app
```

4. Allow notification permissions when prompted

## Requirements

- macOS 14.6 or later

## Language

UI language follows the system:

- English
- Simplified Chinese

Change preferred languages under **System Settings → Language & Region**, then relaunch the app.

## Build

```bash
git clone https://github.com/ArkURL/Sip.git
cd Sip
xcodebuild -scheme Sip -destination 'platform=macOS,arch=arm64' build
```

Tag a release (triggers GitHub Actions DMG build):

```bash
git tag v1.1.7
git push origin v1.1.7
```

## Tech Stack

- SwiftUI + light AppKit
- UserNotifications
- UserDefaults persistence
- String Catalog localization (`en` / `zh-Hans`)
- Zero third-party dependencies

## License

MIT
