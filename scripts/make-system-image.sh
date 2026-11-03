#!/bin/bash
# Build a 3000 MiB ext4 system image for slot system_b.
# The image contains the Ubuntu Touch 24.04-2.x Halium rootfs plus the
# ofono, device-info, and kernel-module overlay from device_B2N.tar.xz.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out"
MKE2FS="${MKE2FS:-$HOME/Library/Android/sdk/platform-tools/mke2fs}"
ROOTFS_TAR="$OUT/ubuntu-touch-android9plus-rootfs-arm64.tar.gz"
DEVICE_TAR="$OUT/device_B2N.tar.xz"
TREE="$OUT/system-root"
IMAGE="$OUT/system.img"
BYTES=$((3000 * 1024 * 1024))
BLOCK=4096
BLOCKS=$((BYTES / BLOCK))

if [[ ! -x "$MKE2FS" ]]; then
  echo "mke2fs not found: $MKE2FS" >&2
  exit 1
fi
if [[ ! -f "$ROOTFS_TAR" || ! -f "$DEVICE_TAR" ]]; then
  echo "Need $ROOTFS_TAR and $DEVICE_TAR" >&2
  exit 1
fi

if [[ -d "$TREE" ]]; then
  chmod u+rwx "$TREE/var/lib/snapd/void" 2>/dev/null || true
  chmod -R u+rwx "$TREE" 2>/dev/null || true
  rm -rf "$TREE"
fi
mkdir -p "$TREE"
tar -xzf "$ROOTFS_TAR" -C "$TREE"
# Some rootfs archives wrap the filesystem in one top-level directory.
entries=("$TREE"/*)
if [[ ${#entries[@]} -eq 1 && -d "${entries[0]}" && ! -d "$TREE/etc" ]]; then
  shopt -s dotglob
  mv "${entries[0]}"/* "$TREE"/
  rmdir "${entries[0]}"
  shopt -u dotglob
fi
if [[ ! -d "$TREE/etc" || ! -d "$TREE/usr" ]]; then
  echo "Rootfs did not unpack to a filesystem root" >&2
  exit 1
fi

# device_B2N.tar.xz stores the overlay under system/, which is the root
# of the flashed system image.
tar -xJf "$DEVICE_TAR" -C "$TREE" --strip-components=1 system
if [[ ! -f "$TREE/opt/halium-overlay/etc/ofono/binder.d/qti.conf" ]]; then
  echo "Ofono overlay missing from the system tree" >&2
  exit 1
fi
if [[ ! -f "$TREE/opt/halium-overlay/etc/deviceinfo/devices/halium.yaml" ]]; then
  echo "Device info overlay missing from the system tree" >&2
  exit 1
fi

# Record original modes, then grant the owner read access so mke2fs can
# copy execute-only directories such as var/lib/snapd/void. The image
# walk below writes the recorded modes back. Host tar extracts as the
# Mac user, so uid/gid come from the rootfs tarball, not the tree.
python3 - "$ROOTFS_TAR" "$OUT/system-owners.txt" <<'PY'
import tarfile, sys
tar_path, dest = sys.argv[1:]
count = 0
with tarfile.open(tar_path, "r:*") as archive, open(dest, "w", encoding="utf-8") as out:
    for member in archive.getmembers():
        rel = member.name.lstrip("./")
        if rel in ("", "."):
            continue
        out.write(f"{member.uid}\t{member.gid}\t{rel}\n")
        count += 1
print(f"recorded owners for {count} rootfs members")
PY
python3 - "$TREE" "$OUT/system-modes.txt" <<'PY'
import os, stat, sys
tree, manifest = sys.argv[1:]
opened = 0
with open(manifest, "w", encoding="utf-8") as out:
    def walk(rel):
        global opened
        path = tree if rel == "" else os.path.join(tree, rel)
        mode = os.lstat(path).st_mode
        out.write(f"{mode}\t{rel}\n")
        if stat.S_ISLNK(mode):
            return
        if not mode & stat.S_IRUSR:
            os.chmod(path, mode | stat.S_IRUSR)
            opened += 1
        if stat.S_ISDIR(mode):
            for name in os.listdir(path):
                walk(name if rel == "" else rel + "/" + name)
    walk("")
print(f"recorded modes, temporarily opened {opened} unreadable nodes")
PY

rm -f "$IMAGE"
# One inode per 8 KiB leaves room for the rootfs in the 3000 MiB image.
# metadata_csum and orphan_file are not safe on this 4.4 kernel.
# dir_index is left off so directory blocks stay linear and modes can be
# restored after packing.
"$MKE2FS" -q -t ext4 -b "$BLOCK" -m 0 -i 8192 -L ubuntu -o Linux \
  -O ^metadata_csum,^orphan_file,^dir_index \
  -d "$TREE" "$IMAGE" "$BLOCKS"

python3 - "$IMAGE" "$OUT/system-modes.txt" "$OUT/system-owners.txt" <<'PY'
import mmap, struct, sys
image_path, manifest_path, owners_path = sys.argv[1:]
modes = {}
with open(manifest_path, encoding="utf-8") as handle:
    for line in handle:
        text, rel = line.rstrip("\n").split("\t", 1)
        modes[rel] = int(text)
owners = {}
with open(owners_path, encoding="utf-8") as handle:
    for line in handle:
        uid_text, gid_text, rel = line.rstrip("\n").split("\t", 2)
        owners[rel] = (int(uid_text), int(gid_text))

def extent_blocks(data, header, header_len):
    magic, entries, _max, depth = struct.unpack_from("<HHHI", data, header)[:4] if False else struct.unpack_from("<HHHH", data, header)
    if magic != 0xF30A:
        raise SystemExit("inode does not use extents")
    blocks = []
    if depth == 0:
        for index in range(entries):
            off = header + 12 + index * 12
            logical, length, start_hi, start_lo = struct.unpack_from("<IHHI", data, off)
            if length > 32768:
                length -= 32768
            start = start_lo | (start_hi << 32)
            for block in range(length):
                blocks.append((logical + block, start + block))
        return blocks
    for index in range(entries):
        off = header + 12 + index * 12
        _logical, leaf_lo, leaf_hi, _unused = struct.unpack_from("<IIHH", data, off)
        leaf = leaf_lo | (leaf_hi << 32)
        blocks.extend(extent_blocks(data, leaf * block_size, block_size))
    return blocks

with open(image_path, "r+b") as handle:
    data = mmap.mmap(handle.fileno(), 0)
    sb = 1024
    magic = struct.unpack_from("<H", data, sb + 0x38)[0]
    if magic != 0xEF53:
        raise SystemExit("system.img is not ext4")
    block_size = 1024 << struct.unpack_from("<I", data, sb + 0x18)[0]
    inodes_per_group = struct.unpack_from("<I", data, sb + 0x28)[0]
    blocks_count = struct.unpack_from("<I", data, sb + 0x04)[0]
    blocks_per_group = struct.unpack_from("<I", data, sb + 0x20)[0]
    inode_size = struct.unpack_from("<H", data, sb + 0x58)[0]
    incompat = struct.unpack_from("<I", data, sb + 0x60)[0]
    desc_size = struct.unpack_from("<H", data, sb + 0xFE)[0] if incompat & 0x80 else 32
    if data.size() > 3221225472:
        raise SystemExit(f"system.img is {data.size()} bytes")

    def inode_offset(ino):
        group = (ino - 1) // inodes_per_group
        index = (ino - 1) % inodes_per_group
        desc = block_size + group * desc_size
        table = struct.unpack_from("<I", data, desc + 8)[0]
        if desc_size >= 0x2C:
            table |= struct.unpack_from("<I", data, desc + 0x28)[0] << 32
        return table * block_size + index * inode_size

    def set_owner_and_mode(ino, mode, uid=0, gid=0):
        off = inode_offset(ino)
        struct.pack_into("<H", data, off, mode & 0xFFFF)
        struct.pack_into("<H", data, off + 2, uid & 0xFFFF)
        struct.pack_into("<H", data, off + 24, gid & 0xFFFF)
        if inode_size >= 128:
            struct.pack_into("<H", data, off + 120, (uid >> 16) & 0xFFFF)
            struct.pack_into("<H", data, off + 122, (gid >> 16) & 0xFFFF)

    def directory_entries(ino):
        off = inode_offset(ino)
        blocks = extent_blocks(data, off + 40, 60)
        blob = bytearray()
        for _logical, physical in sorted(blocks):
            start = physical * block_size
            blob += data[start:start + block_size]
        entries = []
        cursor = 0
        while cursor + 8 <= len(blob):
            child, rec_len, name_len, _file_type = struct.unpack_from("<IHBB", blob, cursor)
            if rec_len < 8 or cursor + rec_len > len(blob):
                break
            name = blob[cursor + 8:cursor + 8 + name_len].decode("utf-8", "surrogateescape")
            if child and name not in (".", ".."):
                entries.append((name, child))
            cursor += rec_len
            if rec_len == 0:
                break
        return entries

    seen = {"qti": False, "yaml": False, "void": None}
    def walk(ino, rel):
        uid, gid = owners.get(rel, (0, 0))
        if rel in modes:
            set_owner_and_mode(ino, modes[rel], uid, gid)
        else:
            current = struct.unpack_from("<H", data, inode_offset(ino))[0]
            set_owner_and_mode(ino, current, uid, gid)
        off = inode_offset(ino)
        mode = struct.unpack_from("<H", data, off)[0]
        if rel == "var/lib/snapd/void":
            seen["void"] = mode
        if rel == "opt/halium-overlay/etc/ofono/binder.d/qti.conf":
            seen["qti"] = True
        if rel == "opt/halium-overlay/etc/deviceinfo/devices/halium.yaml":
            seen["yaml"] = True
        if not mode & 0x4000:
            return
        for name, child in directory_entries(ino):
            child_rel = name if rel == "" else rel + "/" + name
            walk(child, child_rel)

    set_owner_and_mode(2, modes[""])
    for name, child in directory_entries(2):
        walk(child, name)
    data.flush()
    print(f"image {data.size()} bytes, blocks {blocks_count}")
    if seen["void"] is None or (seen["void"] & 0o777) != 0o111:
        raise SystemExit(f"void directory mode was not restored: {seen['void']}")
    if not seen["qti"] or not seen["yaml"]:
        raise SystemExit("overlay files are missing from system.img")
    print(f"void mode {seen['void']:#o}, overlays present")
PY

echo "wrote $IMAGE"
