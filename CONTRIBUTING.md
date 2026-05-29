# Contributing

Thanks for considering a contribution to DataMeter.

## Development setup

Install Xcode and XcodeGen, then generate the project:

```bash
xcodegen generate
open DataMeter.xcodeproj
```

## Checks

Run these before opening a PR:

```bash
swift test
xcodebuild -project DataMeter.xcodeproj -scheme DataMeter -configuration Debug -derivedDataPath DerivedData test
scripts/smoke-macos.sh
```

## Architecture direction

Keep the app split into:

- `DataMeterApp`: SwiftUI/AppKit presentation and platform integration.
- `DataMeterCore`: sampling, parsing, accumulation, storage, and tracking logic.
- `DataMeterCoreTests`: deterministic tests for core behavior.

Prefer moving runtime behavior into testable core types instead of adding orchestration to SwiftUI views.

## Privacy and trust

DataMeter handles local per-app network usage history. Avoid adding analytics, telemetry, or network calls unless they are discussed clearly first and documented in `PRIVACY.md`.
