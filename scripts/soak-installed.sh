#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="$ROOT_DIR/artifacts/soak"
APP_PATH="/Applications/DataMeter.app"
APP_EXEC="$APP_PATH/Contents/MacOS/DataMeter"
DB_PATH="$HOME/Library/Application Support/DataMeter/usage.sqlite"
DURATION_SECONDS="${1:-1800}"
INTERVAL_SECONDS="${SOAK_INTERVAL_SECONDS:-10}"

mkdir -p "$ARTIFACT_DIR"
cd "$ROOT_DIR"

if [ ! -x "$APP_EXEC" ]; then
  echo "Missing installed app: $APP_PATH" >&2
  echo "Run scripts/install-local.sh first." >&2
  exit 1
fi

pkill -x DataMeter 2>/dev/null || true
sleep 1
open -n "$APP_PATH"
sleep 5

PID="$(pgrep -nx DataMeter || true)"
if [ -z "$PID" ]; then
  echo "DataMeter did not launch" >&2
  exit 1
fi

COMMAND_PATH="$(ps -p "$PID" -o comm= | tr -d '\n')"
if [ "$COMMAND_PATH" != "$APP_EXEC" ]; then
  echo "Unexpected DataMeter executable: $COMMAND_PATH" >&2
  echo "Expected: $APP_EXEC" >&2
  exit 1
fi

osascript -e 'tell application "System Events" to set visible of process "DataMeter" to false' >/dev/null 2>&1 || true

SAMPLES="$ARTIFACT_DIR/samples.tsv"
SUMMARY="$ARTIFACT_DIR/summary.txt"
: > "$SAMPLES"

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
END_AT=$(( $(date +%s) + DURATION_SECONDS ))

while [ "$(date +%s)" -lt "$END_AT" ]; do
  if ! ps -p "$PID" >/dev/null; then
    echo "DataMeter exited during soak" >&2
    exit 1
  fi
  printf "%s\t" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$SAMPLES"
  ps -p "$PID" -o %cpu= -o rss= | awk '{print $1 "\t" $2}' >> "$SAMPLES"
  sleep "$INTERVAL_SECONDS"
done

{
  echo "started_at=$STARTED_AT"
  echo "ended_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "duration_seconds=$DURATION_SECONDS"
  echo "interval_seconds=$INTERVAL_SECONDS"
  echo "pid=$PID"
  echo "app_path=$APP_PATH"
  awk -F '\t' 'NF>=3 {cpu+=$2; rss+=$3; n++; if (minrss==0 || $3<minrss) minrss=$3; if ($3>maxrss) maxrss=$3; if ($2>maxcpu) maxcpu=$2} END {printf "samples=%d\navg_cpu=%.3f\nmax_cpu=%.3f\navg_rss_mb=%.1f\nmin_rss_mb=%.1f\nmax_rss_mb=%.1f\n", n, cpu/n, maxcpu, rss/n/1024, minrss/1024, maxrss/1024}' "$SAMPLES"
  if [ -f "$DB_PATH" ]; then
    echo "db_bytes=$(stat -f%z "$DB_PATH")"
    sqlite3 "$DB_PATH" 'select "usage_deltas=" || count(*) from usage_deltas; select "usage_daily_rollups=" || count(*) from usage_daily_rollups; select "network_sessions=" || count(*) from network_sessions;'
  else
    echo "db_missing=true"
  fi
} > "$SUMMARY"

cat "$SUMMARY"
