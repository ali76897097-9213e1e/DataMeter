# DataMeter

A macOS app for tracking how much network data each app/process uses on your Mac.

DataMeter is designed for everyday network data-usage awareness: keep it running, let it launch at login, and use the dashboard to see which apps are consuming data today, this week, this month, or during the current session.

## Features

- Per-app/process network usage tracking using macOS `nettop`.
- Session, Today, This Week, This Month, and All Time filters.
- Network filter, useful for isolating usage on specific Wi-Fi or network connections.
- Searchable, sortable app usage table.
- Download/upload/total summaries.
- App icons and nicer app names when macOS can resolve the process to an app bundle.
- Local SQLite history at `~/Library/Application Support/DataMeter/usage.sqlite`.
- Launch at Login enabled automatically so totals keep accumulating.
- Menu bar companion view.

## Project structure

This is an XcodeGen-managed macOS app project:

```text
DataMeterApp/          SwiftUI app, dashboard, settings, menu bar UI, app icon/display resolution
DataMeterCore/         nettop sampler, parser, accumulator, SQLite storage, network identity/session history
DataMeterCoreTests/    unit tests for core behavior
scripts/               local install and smoke-test scripts
project.yml            source of truth for DataMeter.xcodeproj
Package.swift          SwiftPM entry point for core/test iteration
```

Generated artifacts are ignored by git:

```text
DerivedData/
.build/
artifacts/
```

## Install locally

```bash
scripts/install-local.sh
```

This builds Release, installs `DataMeter.app` into `/Applications`, launches it, and lets the app register itself for Launch at Login.

## Develop

Generate/open the Xcode project:

```bash
xcodegen generate
open DataMeter.xcodeproj
```

Run tests:

```bash
swift test
xcodebuild -project DataMeter.xcodeproj -scheme DataMeter -configuration Debug -derivedDataPath DerivedData test
```

Run a debug build:

```bash
xcodebuild -project DataMeter.xcodeproj -scheme DataMeter -configuration Debug -derivedDataPath DerivedData build
open DerivedData/Build/Products/Debug/DataMeter.app
```

## Smoke check

```bash
scripts/smoke-macos.sh
```

This builds the app, opens it, verifies the accessibility snapshot, captures a screenshot, and writes ignored artifacts to `artifacts/smoke/`.

## Limitations

- DataMeter tracks; it does not block or limit apps.
- Per-app totals are not retroactive. DataMeter has to be running to collect usage.
- Very short-lived commands can be missed between samples.
- Browser tabs are not separated.
