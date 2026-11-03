#!/usr/bin/env python3
"""Link a freestanding aarch64 object into a bionic-loadable ET_DYN .so."""
import struct
import sys

obj_path, soname, out_path = sys.argv[1:4]
obj = open(obj_path, "rb").read()
e_shoff = struct.unpack_from("<Q", obj, 40)[0]
e_shnum = struct.unpack_from("<H", obj, 60)[0]
e_shstrndx = struct.unpack_from("<H", obj, 62)[0]


def shdr(i):
    return struct.unpack_from("<IIQQQQIIQQ", obj, e_shoff + i * 64)


names = {}
shstr = shdr(e_shstrndx)
blob = obj[shstr[4] : shstr[4] + shstr[5]]
for i in range(e_shnum):
    s = shdr(i)
    names[blob[s[0] : blob.find(b"\0", s[0])].decode()] = i

if ".text" not in names:
    raise SystemExit("no .text")

text = obj[shdr(names[".text"])[4] : shdr(names[".text"])[4] + shdr(names[".text"])[5]]
ro_name = next((n for n in (".rodata.str1.1", ".rodata") if n in names), None)
ro = b""
if ro_name:
    ro = obj[shdr(names[ro_name])[4] : shdr(names[ro_name])[4] + shdr(names[ro_name])[5]]
bss_size = shdr(names[".bss"])[5] if ".bss" in names else 0
rela = b""
if ".rela.text" in names:
    rela = obj[shdr(names[".rela.text"])[4] : shdr(names[".rela.text"])[4] + shdr(names[".rela.text"])[5]]
symraw = obj[shdr(names[".symtab"])[4] : shdr(names[".symtab"])[4] + shdr(names[".symtab"])[5]]
strraw = obj[shdr(names[".strtab"])[4] : shdr(names[".strtab"])[4] + shdr(names[".strtab"])[5]]
first_global = shdr(names[".symtab"])[7]

exports = []
for i in range(first_global, len(symraw) // 24):
    name, info, other, shndx, val, sz = struct.unpack_from("<IBBHQQ", symraw, i * 24)
    if shndx == names[".text"] and (info & 0xF) == 2 and (info >> 4) == 1:
        exports.append((strraw[name : strraw.find(b"\0", name)].decode(), val, sz))
if not exports:
    raise SystemExit("no exported functions")

phdr_off = 64
phdr_count = 4
rx = bytearray(0x10000)
text_off = (phdr_off + phdr_count * 56 + 15) & ~15
rx[text_off : text_off + len(text)] = text
ro_off = text_off + len(text)
rx[ro_off : ro_off + len(ro)] = ro
rx_size = (ro_off + len(ro) + 15) & ~15
rw_vaddr = (rx_size + 0xFFF) & ~0xFFF


def align(n, a):
    return (n + a - 1) & ~(a - 1)


dynstr = bytearray(b"\0")
soname_off = len(dynstr)
dynstr += soname.encode() + b"\0"
str_off = {}
for name, val, sz in exports:
    str_off[name] = len(dynstr)
    dynstr += name.encode() + b"\0"
while len(dynstr) % 8:
    dynstr.append(0)

nsyms = 1 + len(exports)
dynsym = bytearray(nsyms * 24)
for i, (name, val, sz) in enumerate(exports, start=1):
    info = (1 << 4) | 2
    struct.pack_into("<IBBHQQ", dynsym, i * 24, str_off[name], info, 0, 1, text_off + val, sz)


def sysv_hash(name):
    h = 0
    for c in name.encode():
        h = (h << 4) + c
        g = h & 0xF0000000
        if g:
            h ^= g >> 24
        h &= ~g
    return h & 0xFFFFFFFF


nbucket = nsyms
nchain = nsyms
buckets = [0] * nbucket
chain = [0] * nchain
for i, (name, val, sz) in enumerate(exports, start=1):
    h = sysv_hash(name) % nbucket
    chain[i] = buckets[h]
    buckets[h] = i
hash_bytes = struct.pack("<II", nbucket, nchain)
hash_bytes += struct.pack("<" + "I" * nbucket, *buckets)
hash_bytes += struct.pack("<" + "I" * nchain, *chain)

meta = dynsym + dynstr + hash_bytes
dyn_off = align(len(meta), 8)
rw = bytearray(dyn_off + 16 * 12)
rw[0 : len(dynsym)] = dynsym
str_at = len(dynsym)
rw[str_at : str_at + len(dynstr)] = dynstr
hash_at = str_at + len(dynstr)
rw[hash_at : hash_at + len(hash_bytes)] = hash_bytes

dyn_vaddr = rw_vaddr + dyn_off
entries = [
    (4, rw_vaddr + hash_at),
    (5, rw_vaddr + str_at),
    (6, rw_vaddr),
    (10, len(dynstr)),
    (11, 24),
    (14, soname_off),
    (0, 0),
]
for i, (tag, val) in enumerate(entries):
    struct.pack_into("<QQ", rw, dyn_off + i * 16, tag, val)

bss_off = align(len(rw), 16)
bss_vaddr = rw_vaddr + bss_off
rw_memsz = bss_off + bss_size
section_base = {names[".text"]: text_off}
if ro_name:
    section_base[names[ro_name]] = ro_off
if ".bss" in names:
    section_base[names[".bss"]] = bss_vaddr

R_ADR, R_ADD, R_LD8, R_LD32, R_LD64 = 275, 277, 278, 285, 286
for i in range(0, len(rela), 24):
    r_offset, r_info, r_addend = struct.unpack_from("<QQq", rela, i)
    sym = r_info >> 32
    kind = r_info & 0xFFFFFFFF
    name, info, other, shndx, val, sz = struct.unpack_from("<IBBHQQ", symraw, sym * 24)
    if shndx not in section_base:
        raise SystemExit(f"reloc to section {shndx}")
    target = section_base[shndx] + val + r_addend
    place = text_off + r_offset
    insn = struct.unpack_from("<I", rx, place)[0]
    if kind == R_ADR:
        imm = ((target & ~0xFFF) - (place & ~0xFFF)) >> 12
        if imm < -(1 << 20) or imm >= (1 << 20):
            raise SystemExit(f"adrp out of range at {place:#x}")
        imm &= 0x1FFFFF
        insn &= ~((3 << 29) | (0x7FFFF << 5))
        insn |= ((imm & 3) << 29) | ((imm >> 2) << 5)
    elif kind == R_ADD:
        insn &= ~(0xFFF << 10)
        insn |= (target & 0xFFF) << 10
    elif kind in (R_LD8, R_LD32, R_LD64):
        shift = {R_LD8: 0, R_LD32: 2, R_LD64: 3}[kind]
        if target & ((1 << shift) - 1):
            raise SystemExit(f"unaligned load at {place:#x}")
        insn &= ~(0xFFF << 10)
        insn |= ((target & 0xFFF) >> shift) << 10
    else:
        raise SystemExit(f"unknown reloc {kind}")
    struct.pack_into("<I", rx, place, insn)

rx = rx[:rx_size]
file_rw_off = rw_vaddr
out = bytearray(file_rw_off + len(rw))
out[: len(rx)] = rx
out[file_rw_off : file_rw_off + len(rw)] = rw

shnames = [b"", b".dynsym", b".dynstr", b".hash", b".dynamic", b".shstrtab"]
shstr = bytearray()
name_off = []
for name in shnames:
    name_off.append(len(shstr))
    shstr += name + b"\0"
while len(out) % 8:
    out.append(0)
shstr_off = len(out)
out += shstr
while len(out) % 8:
    out.append(0)
shoff = len(out)


def mkshdr(name, kind, flags, addr, offset, size, link, info, align, entsize):
    return struct.pack("<IIQQQQIIQQ", name, kind, flags, addr, offset, size, link, info, align, entsize)


SHF_WRITE, SHF_ALLOC = 1, 2
sections = [
    mkshdr(0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    mkshdr(name_off[1], 11, SHF_ALLOC, rw_vaddr, file_rw_off, len(dynsym), 2, 1, 8, 24),
    mkshdr(name_off[2], 3, SHF_ALLOC, rw_vaddr + str_at, file_rw_off + str_at, len(dynstr), 0, 0, 1, 0),
    mkshdr(name_off[3], 5, SHF_ALLOC, rw_vaddr + hash_at, file_rw_off + hash_at, len(hash_bytes), 1, 0, 4, 4),
    mkshdr(name_off[4], 6, SHF_ALLOC | SHF_WRITE, dyn_vaddr, file_rw_off + dyn_off, 16 * len(entries), 2, 0, 8, 16),
    mkshdr(name_off[5], 3, 0, 0, shstr_off, len(shstr), 0, 0, 1, 0),
]
out += b"".join(sections)

ehdr = struct.pack(
    "<16sHHIQQQIHHHHHH",
    b"\x7fELF" + bytes([2, 1, 1, 0]) + b"\0" * 8,
    3,
    183,
    1,
    0,
    phdr_off,
    shoff,
    0,
    64,
    56,
    phdr_count,
    64,
    len(sections),
    len(sections) - 1,
)
out[:64] = ehdr


def phdr(kind, flags, off, vaddr, filesz, memsz, align):
    return struct.pack("<IIQQQQQQ", kind, flags, off, vaddr, vaddr, filesz, memsz, align)


phdrs = [
    phdr(6, 4, phdr_off, phdr_off, phdr_count * 56, phdr_count * 56, 8),
    phdr(1, 5, 0, 0, len(rx), len(rx), 0x1000),
    phdr(1, 6, file_rw_off, rw_vaddr, len(rw), rw_memsz, 0x1000),
    phdr(2, 6, file_rw_off + dyn_off, dyn_vaddr, 16 * len(entries), 16 * len(entries), 8),
]
for i, p in enumerate(phdrs):
    out[phdr_off + i * 56 : phdr_off + (i + 1) * 56] = p

open(out_path, "wb").write(out)
print(f"wrote {out_path} {len(out)} bytes exports {len(exports)}")
