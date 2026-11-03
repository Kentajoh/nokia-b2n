#!/bin/bash
# Flash Ubuntu Touch to slot B only. Slot A stays the stock 00WW_4_15N
# install. Does not write vendor, userdata, persist, modem, or fsg.
set -euo pipefail

if [[ "${1:-}" != "--confirm" ]]; then
  echo "This flashes boot_b and system_b, then makes slot b active." >&2
  echo "Usage: $0 --confirm" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOT="$ROOT/out/boot.img"
SYSTEM="$ROOT/out/system.img"
FASTBOOT="${FASTBOOT:-$HOME/Library/Android/sdk/platform-tools/fastboot}"
SYSTEM_PARTITION_BYTES=3221225472

if [[ ! -x "$FASTBOOT" ]]; then
  echo "fastboot not found: $FASTBOOT" >&2
  exit 1
fi
if [[ ! -f "$BOOT" || ! -f "$SYSTEM" ]]; then
  echo "Need $BOOT and $SYSTEM" >&2
  exit 1
fi

SPARSE="$ROOT/out/system.sparse.img"
python3 - "$BOOT" "$SYSTEM" "$SPARSE" "$SYSTEM_PARTITION_BYTES" <<'PY'
import pathlib, struct, sys
boot_path, system_path, sparse_path, limit_text = sys.argv[1:]
boot = pathlib.Path(boot_path).read_bytes()
system = pathlib.Path(system_path)
limit = int(limit_text)
if boot[:8] != b"ANDROID!":
    raise SystemExit("boot.img is not an Android boot image")
page = struct.unpack_from("<I", boot, 36)[0]
version = struct.unpack_from("<I", boot, 40)[0]
if page != 4096 or version != 0:
    raise SystemExit(f"unexpected boot header page={page} version={version}")
system_bytes = system.stat().st_size
if system_bytes > limit:
    raise SystemExit(f"system.img is {system_bytes} bytes, partition is {limit}")
print(f"boot header version {version}, system.img {system_bytes} bytes")

# A raw image smaller than the partition makes current platform-tools try to
# read the whole file into memory while copying an AVB footer. A sparse image
# skips that path. Zero blocks are marked don't-care.
block = 4096
raw_type = 0xCAC1
dont_type = 0xCAC3
max_raw_blocks = 8192
zero = b"\x00" * block
sparse = pathlib.Path(sparse_path)
raw_newer = sparse.exists() and sparse.stat().st_mtime >= system.stat().st_mtime
if raw_newer and sparse.stat().st_size > 28:
    print(f"using existing {sparse}")
    sys.exit(0)

total_blocks = 0
total_chunks = 0
pending_raw = bytearray()
pending_dont = 0

def chunk_header(kind, blocks, payload):
    total = 12 + len(payload)
    return struct.pack("<HHII", kind, 0, blocks, total) + payload

with system.open("rb") as source, sparse.open("wb") as output:
    output.write(b"\x00" * 28)

    def flush_raw():
        global pending_raw, total_chunks
        if not pending_raw:
            return
        blocks = len(pending_raw) // block
        output.write(chunk_header(raw_type, blocks, pending_raw))
        pending_raw = bytearray()
        total_chunks += 1

    def flush_dont():
        global pending_dont, total_chunks
        if not pending_dont:
            return
        output.write(chunk_header(dont_type, pending_dont, b""))
        pending_dont = 0
        total_chunks += 1

    while True:
        data = source.read(block)
        if not data:
            break
        if len(data) < block:
            data = data.ljust(block, b"\x00")
        total_blocks += 1
        if data == zero:
            flush_raw()
            pending_dont += 1
        else:
            flush_dont()
            pending_raw += data
            if len(pending_raw) // block >= max_raw_blocks:
                flush_raw()
    flush_raw()
    flush_dont()
    output.seek(0)
    output.write(struct.pack("<IHHHHIIII", 0xED26FF3A, 1, 0, 28, 12,
                             block, total_blocks, total_chunks, 0))

expanded = total_blocks * block
if expanded != system_bytes and expanded != ((system_bytes + block - 1) // block) * block:
    raise SystemExit(f"sparse image expands to {expanded}, raw image is {system_bytes}")
print(f"sparse image {sparse.stat().st_size} bytes, {total_chunks} chunks, expands to {expanded}")
PY
SYSTEM="$SPARSE"

echo "waiting for fastboot"
if ! "$FASTBOOT" devices | awk 'NR==1 {found=1} END {exit !found}'; then
  echo "No fastboot device. Boot the phone to the bootloader and run this again." >&2
  exit 1
fi

"$FASTBOOT" flash boot_b "$BOOT"
# Chunks near the 384 MiB download limit stall this bootloader's USB.
"$FASTBOOT" -S 64M flash system_b "$SYSTEM"
"$FASTBOOT" set_active b
"$FASTBOOT" reboot
echo "Slot b is now active. If it does not boot, run: fastboot set_active a"
