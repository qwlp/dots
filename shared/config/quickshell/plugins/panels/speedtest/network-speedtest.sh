#!/bin/sh
set -eu

phase=${1:-}
case "$phase" in down|up) ;; *) echo "Usage: $0 down|up" >&2; exit 2 ;; esac
command -v curl >/dev/null 2>&1 || { echo "curl is required for the speed test" >&2; exit 1; }

# Emit a fresh sample after every transfer. The panel intentionally stops this
# worker after five seconds, so it needs streaming samples rather than a value
# printed only when a long transfer completes.
while :; do
  if [ "$phase" = down ]; then
    bytes_per_second=$(curl -LfsS --connect-timeout 4 --max-time 8 -o /dev/null \
      -w '%{speed_download}' 'https://speed.cloudflare.com/__down?bytes=2000000') || exit 1
  else
    bytes_per_second=$(dd if=/dev/zero bs=100000 count=10 2>/dev/null | \
      curl -LfsS --connect-timeout 4 --max-time 8 -o /dev/null \
        -w '%{speed_upload}' -H 'Content-Type: application/octet-stream' \
        --data-binary @- 'https://speed.cloudflare.com/__up') || exit 1
  fi
  awk -v rate="$bytes_per_second" 'BEGIN { printf "%.2f\n", rate * 8 / 1000000; fflush() }'
done
