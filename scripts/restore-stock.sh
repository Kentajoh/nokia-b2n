#!/bin/bash
# Flash a dump created by backup/tools/dump-stock.sh back to the matching
# partition names. Refuses to run unless the first argument is --confirm.
# Does not touch userdata, and does not erase any partition before writing.
set -euo pipefail

if [[ "${1:-}" != "--confirm" ]]; then
  echo "This writes the stock dump back to the phone." >&2
  echo "Usage: $0 --confirm [dump-directory]" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DUMP="${2:-$ROOT/backup/stock-00WW_4_15N}"
FASTBOOT="$HOME/Library/Android/sdk/platform-tools/fastboot"
ADB="$HOME/Library/Android/sdk/platform-tools/adb"

if [[ ! -d "$DUMP" ]]; then
  echo "Dump directory not found: $DUMP" >&2
  exit 1
fi

cd "$DUMP"
if [[ -f SHA256SUMS ]]; then
  shasum -a 256 -c SHA256SUMS
fi

"$ADB" reboot bootloader
echo "waiting for fastboot"
for _ in $(seq 1 30); do
  if "$FASTBOOT" devices | grep -q fastboot; then
    break
  fi
  sleep 1
done

for image in *.img; do
  partition="${image%.img}"
  if [[ "$partition" == "userdata" ]]; then
    echo "SKIP userdata"
    continue
  fi
  echo "FLASH $partition"
  "$FASTBOOT" flash "$partition" "$image"
done

"$FASTBOOT" reboot
echo "RESTORE_DONE"
