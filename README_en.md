# Sip

[中文](README.md)

A lightweight macOS water drinking reminder.

## Features

- Set daily water intake goal (default 2000ml)
- Quick add buttons (+100 / +250 / custom)
- Progress ring + menu bar percentage display
- Local notification reminders with custom interval and active hours
- Enable reminders by weekday
- Auto-stop reminders when goal is reached
- First-launch onboarding
- Native SwiftUI with a clean cyan theme

## Installation

1. Download the latest `Sip.dmg` from [Releases](../../releases)
2. Double-click to open, drag Sip into your Applications folder
3. On first launch, **right-click → Open** (or run the following command in Terminal, then double-click to open):

```bash
xattr -cr /Applications/Sip.app
```

4. Allow notification permissions when prompted

## Requirements

- macOS 14.6 or later

## Build

```bash
git clone https://github.com/ArkURL/Sip.git
cd Sip
xcodebuild -scheme Sip -destination 'platform=macOS,arch=arm64' build
```

## Tech Stack

- SwiftUI
- UserNotifications
- UserDefaults persistence
- Zero third-party dependencies

## License

MIT
