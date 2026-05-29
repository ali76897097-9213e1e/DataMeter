# Privacy

DataMeter is local-first.

## What DataMeter stores

DataMeter stores local network usage history so it can show per-app/process totals over time. The local database may include:

- app or process names,
- network names or interface names,
- timestamps,
- downloaded and uploaded byte counts.

The database is stored at:

```text
~/Library/Application Support/DataMeter/usage.sqlite
```

## What DataMeter does not do

DataMeter does not include analytics, telemetry, ads, cloud sync, or crash-report uploading. It does not send your usage history to the developer or to a third-party service.

## Launch at Login

Launch at Login is optional. Enable or disable it in DataMeter Settings. It is useful if you want daily/monthly totals to keep accumulating after you restart or log in.

## Deleting local data

Quit DataMeter, then remove the local database directory:

```bash
rm -rf "$HOME/Library/Application Support/DataMeter"
```

## Limitations

DataMeter uses macOS `nettop` output to estimate per-process usage. Very short-lived processes can be missed, browser tabs are not separated, and helper processes may be grouped under a parent app name.
