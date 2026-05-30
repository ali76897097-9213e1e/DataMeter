# DataMeter Performance Baseline

Date: 2026-05-29
Build: Release
Machine: macOS desktop

## Method

- Built Release app with Xcode.
- Launched DataMeter from `DerivedData/Build/Products/Release/DataMeter.app`.
- Captured short visible and background samples with `ps`.
- Also attempted Instruments Power Profiler, but that template is not supported for macOS targets in the installed Xcode. Time Profiler traces were captured briefly to validate attachability, then removed because `.trace` exports include environment metadata and should not be kept in the repo.

## Sampling policy

- Visible UI: 2 seconds.
- Background/hidden: 8 seconds.
- Low Power Mode or battery power while visible: 5 seconds.
- Low Power Mode or battery power while background/hidden: 15 seconds.

## Results

Visible UI sample, approximately 30 seconds:

```text
avg_cpu=0.567%
avg_rss_mb=103.8
samples=6
```

Background/hidden sample, approximately 30 seconds:

```text
avg_cpu=0.017%
avg_rss_mb=98.8
samples=6
```

## Interpretation

- Background CPU is very low, which validates the visibility-based adaptive sampling path.
- Visible CPU is acceptable for a live network dashboard and substantially below the earlier concern that `nettop` could dominate CPU when sampled aggressively.
- Memory is around 100 MB in Release during this short run. This is acceptable for a SwiftUI menu/dashboard utility, but worth watching after long-running use.

## Installed app background soak

Release build installed at `/Applications/DataMeter.app`, app hidden/background, approximately 1 hour:

```text
started_at=2026-05-30T00:19:31Z
ended_at=2026-05-30T01:20:46Z
duration_seconds=3600
interval_seconds=10
samples=173
avg_cpu=1.427
max_cpu=15.300
avg_rss_mb=115.3
min_rss_mb=78.9
max_rss_mb=123.0
db_bytes=835584
usage_deltas=2935
usage_daily_rollups=0
network_sessions=25
```

The installed app stayed stable over the hour: no crash, no obvious memory runaway, and database growth remained modest. CPU averaged higher than the short idle sample because this run captured real traffic and `nettop` sampling work. The 15.3% max spike appears transient; sustained average is the number to watch in future profiles.

## Follow-up triggers

Re-profile if any of these change:

- sampling interval decreases,
- long-lived `nettop` process is introduced,
- raw retention period changes,
- table/UI updates become more frequent,
- background CPU rises above ~0.5% sustained.
