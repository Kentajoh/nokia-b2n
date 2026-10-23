#!/bin/bash
# Read-only dump of the installed stock firmware. Does not flash the bootloader
# image: TWRP is booted into RAM and the phone is rebooted to Android afterwards.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOOLS="$ROOT/backup/tools"
OUT="$ROOT/backup/stock-00WW_4_15N"
TWRP="$TOOLS/twrp-3.7.0_9-0-B2N_sprout.img"
SDK="$HOME/Library/Android/sdk/platform-tools"
ADB="$SDK/adb"
FASTBOOT="$SDK/fastboot"
SERIAL="$("$ADB" devices | awk 'NR>1 && ($2=="device" || $2=="recovery") {print $1; exit}')"
if [[ -z "${SERIAL}" ]]; then
  echo "No adb device in device or recovery state" >&2
  exit 1
fi

mkdir -p "$OUT"
exec > >(tee -a "$OUT/dump.log") 2>&1

reboot_android() {
  if "$ADB" devices | awk -v s="$SERIAL" '$1 == s { found = 1 } END { exit !found }'; then
    "$ADB" -s "$SERIAL" reboot || true
  fi
}
trap 'status=$?; if [[ "$status" -ne 0 ]]; then echo "returning to Android after failure"; reboot_android; fi' EXIT

echo "DUMP_START $(date -u +%Y-%m-%dT%H:%M:%SZ)"

if "$ADB" -s "$SERIAL" shell id 2>/dev/null | tr -d '\r' | grep -q 'uid=0'; then
  echo "TWRP already running as root; continuing the read"
else
  "$ADB" -s "$SERIAL" reboot bootloader || true
  echo "waiting for fastboot"
  for _ in $(seq 1 30); do
    if "$FASTBOOT" -s "$SERIAL" devices | awk -v s="$SERIAL" '$1 == s { found = 1 } END { exit !found }'; then
      break
    fi
    sleep 1
  done
  "$FASTBOOT" -s "$SERIAL" devices
  echo "booting TWRP into RAM (boot partition is not written)"
  if ! "$FASTBOOT" -s "$SERIAL" boot "$TWRP"; then
    echo "DUMP_FAILED fastboot boot"
    "$FASTBOOT" -s "$SERIAL" reboot || true
    exit 1
  fi

  echo "waiting for TWRP adb as root"
  ready=0
  for _ in $(seq 1 45); do
    if "$ADB" -s "$SERIAL" shell id 2>/dev/null | tr -d '\r' | grep -q 'uid=0'; then
      ready=1
      break
    fi
    sleep 2
  done
  if [[ "$ready" -ne 1 ]]; then
    echo "DUMP_FAILED twrp adb did not become root"
    "$FASTBOOT" -s "$SERIAL" reboot || "$ADB" -s "$SERIAL" reboot || true
    exit 1
  fi
fi

"$ADB" -s "$SERIAL" shell 'ls /dev/block/by-name >/dev/null && echo by-name-ok'

# Partition names and byte sizes, excluding userdata.
"$ADB" -s "$SERIAL" shell 'for p in /dev/block/by-name/*; do n=$(basename "$p"); s=$(blockdev --getsize64 "$p"); printf "%s %s\n" "$n" "$s"; done' \
  | tr -d '\r' | awk '$1 != "userdata" && $2 + 0 > 0' | sort > "$OUT/partitions.txt"

echo "partitions:"
cat "$OUT/partitions.txt"

while read -r name size; do
  dest="$OUT/${name}.img"
  if [[ -f "$dest" ]] && [[ "$(wc -c < "$dest" | tr -d ' ')" == "$size" ]]; then
    echo "SKIP $name already complete"
    continue
  fi
  # Logical block size is 512. Large reads are split so a USB drop can resume.
  if (( size % 512 != 0 )); then
    echo "DUMP_FAILED $name size $size is not a multiple of 512"
    exit 1
  fi
  echo "DUMP $name $size"
  have=0
  if [[ -f "$dest" ]]; then
    have="$(wc -c < "$dest" | tr -d ' ')"
    have=$((have - have % 512))
    if (( have > size )); then
      have=0
    fi
    if (( have > 0 )); then
      truncate -s "$have" "$dest"
      echo "RESUME $name at $have"
    fi
  fi
  chunk=$((128 * 1024 * 1024))
  while (( have < size )); do
    remain=$((size - have))
    this=$chunk
    if (( this > remain )); then
      this=$remain
    fi
    count=$((this / 512))
    skip=$((have / 512))
    tmp="$dest.part"
    ok=0
    for _try in 1 2 3; do
      if "$ADB" -s "$SERIAL" exec-out "dd if=/dev/block/by-name/${name} bs=512 skip=${skip} count=${count} 2>/dev/null" > "$tmp" \
        && [[ "$(wc -c < "$tmp" | tr -d ' ')" == "$this" ]]; then
        ok=1
        break
      fi
      echo "RETRY $name at $have"
      sleep 2
    done
    if (( ok != 1 )); then
      echo "DUMP_FAILED $name at offset $have"
      exit 1
    fi
    cat "$tmp" >> "$dest"
    rm -f "$tmp"
    have=$((have + this))
    echo "PROGRESS $name $have/$size"
  done
done < "$OUT/partitions.txt"

(
  cd "$OUT"
  shasum -a 256 *.img partitions.txt > SHA256SUMS
)

echo "rebooting to Android"
"$ADB" -s "$SERIAL" reboot || true
echo "DUMP_DONE $(date -u +%Y-%m-%dT%H:%M:%SZ)"
