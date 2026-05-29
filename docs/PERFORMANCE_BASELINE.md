# DataMeter Performance Baseline

Date: 2026-05-29
Build: Release
Machine: macOS desktop

## Method

- Built Release app with Xcode.
- Launched DataMeter from `DerivedData/Build/Products/Release/DataMeter.app`.
- Captured short visible and background samples with `ps`.
- Also attempted Instruments Power Profiler, but that template is not supported for macOS targets in the installed Xcode. Time Profiler traces were captured briefly to validate attachability, then removed because `.trace` exports include environment metadata and should not be kept in the repo.

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

## Follow-up triggers

Re-profile if any of these change:

- sampling interval decreases,
- long-lived `nettop` process is introduced,
- raw retention period changes,
- table/UI updates become more frequent,
- background CPU rises above ~0.5% sustained.
