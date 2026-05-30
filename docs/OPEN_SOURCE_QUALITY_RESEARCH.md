# DataMeter Quality Research Status

Date: 2026-05-29

## Current conclusion

DataMeter has moved from a useful first build to a much stronger pre-release architecture. The original high-risk findings around overlapping samples, main-actor backend work, shell hangs, network-switch misattribution, display-name-only identity, and unbounded raw storage have been addressed with hard cutovers.

Because this app has not shipped publicly, we intentionally prefer clean hard cuts over compatibility migrations.

## Completed hardening

### Correctness

- Tracking orchestration moved into `UsageTrackingEngine` actor.
- Repeating `Timer` removed; sampling is serialized by a single task loop and actor isolation.
- Network changes close the old session and reset/prime sampling baseline so cross-network deltas are not attributed to the wrong network.
- Local potentially polluted tracking data was reset during development.
- Stable app identity is separate from display name:
  - bundle identifier when available,
  - bundle path fallback,
  - grouped fallback such as `group:Safari`,
  - process fallback such as `process:curl`.
- Parser is now header-based and quote-aware instead of fixed-column/simple comma splitting.
- SQLite schema is hard-cut into a single current schema, not a compatibility chain.

### Reliability

- Shell execution has timeout support.
- Shell stdout/stderr are drained concurrently to avoid pipe deadlocks.
- Shell failures/timeouts produce clear errors.
- Storage startup is recoverable; the app shows a storage error instead of crashing.
- Pause/sleep/quit close sessions through the engine.
- Tests cover network switch attribution, pause session closure, no-delta cache reuse, parser edge cases, shell timeout/large output, SQLite queries, and rollups.

### Performance and energy

- Sampling interval is visibility-based:
  - faster while dashboard/menu is visible,
  - slower while background-only.
- App identity resolution is cached.
- UI publishing avoids setting unchanged values.
- Network list queries are cached and invalidated only when needed.
- Record queries are cached for no-delta samples.
- SQLite uses WAL and `synchronous=NORMAL`.
- Composite indexes match common time/network/app query shapes.
- Raw deltas older than 30 days roll into daily summaries.

### Privacy / local trust

- Launch at Login is explicit through Settings; the app no longer silently registers itself.
- `PRIVACY.md` states what is stored locally and how to delete it.
- No analytics, telemetry, cloud sync, ads, or crash uploading are present.

## Verification status

Current checks pass:

```bash
swift test
xcodebuild -project DataMeter.xcodeproj -scheme DataMeter -configuration Debug -derivedDataPath DerivedData test
scripts/smoke-macos.sh
```

Current test count: 16 XCTest tests plus Swift Testing runner sanity.

## Performance baseline

See `docs/PERFORMANCE_BASELINE.md`.

Short Release-build sample:

```text
Visible UI:       avg_cpu=0.567%, avg_rss_mb=103.8
Background/hidden avg_cpu=0.017%, avg_rss_mb=98.8
```

Apple's Power Profiler template is not available for macOS targets in the installed Xcode. Time Profiler can attach to the app, but trace exports include environment metadata and should not be committed.

## Remaining focused work

These are the remaining meaningful items before a first public release. They are not open-source ceremony; they directly affect product quality.

### 1. Optional UI polish from real use

Only after the architecture is stable:

- clearer first-run empty state,
- visible storage error state,
- optional manual “Delete local history” control,
- maybe show last sample time/failure only if something is wrong.

## Not recommended right now

- Network Extension/System Extension rewrite: high entitlement/distribution complexity, not justified for v1.
- Backwards-compatible DB migration chain: unnecessary before first release.
- Complex release/notarization automation before the app behavior settles.
- Localization scaffolding before the UI text stabilizes.

## Release-readiness gate

Before first public release, require:

- all current checks passing,
- accessibility pass complete,
- battery/low-power-aware sampling complete,
- no known correctness issue that can pollute usage totals,
- local data reset once more after final schema decision,
- README/PRIVACY accurately matching behavior,
- clean commit history for the pre-release hardening work.
