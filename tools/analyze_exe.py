"""Disassemble FIFA96.EXE (LE / DOS4GW) and annotate it.

Usage: analyze_exe.py <FIFA96.EXE> <out_dir>

Writes:
  fifa96.asm        full annotated listing of the 32-bit code object
  functions.tsv     every call target with size, caller count and referenced strings
  strings.tsv       every string referenced from code, with referencing functions
"""
import bisect
import os
import re
import sys
from collections import defaultdict

from capstone import CS_ARCH_X86, CS_MODE_32, Cs

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from le import LEImage  # noqa: E402

PRINTABLE = re.compile(rb"^[\x09\x0a\x0d\x20-\x7e\x80-\xff]{3,}$")


def main(exe, out):
    os.makedirs(out, exist_ok=True)
    im = LEImage(open(exe, "rb").read())
    code = next(o for o in im.objects if o["flags"] & 0x4 and o["flags"] & 0x2000)
    cbase, cimg = code["base"], bytes(code["image"])
    entry = im.objects[im.eip_obj - 1]["base"] + im.eip

    md = Cs(CS_ARCH_X86, CS_MODE_32)
    md.skipdata = True
    insns = list(md.disasm(cimg, cbase))

    def in_code(a):
        return cbase <= a < cbase + len(cimg)

    def string_at(a):
        if in_code(a):
            return None
        s = im.cstring(a)
        if s and PRINTABLE.match(s):
            return s.decode("cp437")
        return None

    calls = defaultdict(set)
    for ins in insns:
        if ins.mnemonic == "call" and ins.op_str.startswith("0x"):
            t = int(ins.op_str, 16)
            if in_code(t):
                calls[t].add(ins.address)
    func_starts = sorted(set(calls) | {entry})
    names = {entry: "start"}

    def func_of(a):
        i = bisect.bisect_right(func_starts, a) - 1
        return func_starts[i] if i >= 0 else None

    fstrings = defaultdict(list)
    str_refs = defaultdict(set)
    imm = re.compile(r"0x[0-9a-f]+")
    comments = {}
    for ins in insns:
        notes = []
        for m in imm.findall(ins.op_str):
            v = int(m, 16)
            s = string_at(v)
            if s is not None:
                notes.append(repr(s[:70]))
                f = func_of(ins.address)
                if s not in fstrings[f]:
                    fstrings[f].append(s)
                str_refs[s].add(f)
        if notes:
            comments[ins.address] = "; " + " ".join(notes)

    def fname(a):
        return names.get(a, "sub_%06x" % a)

    with open(os.path.join(out, "fifa96.asm"), "w") as fh:
        fh.write("; FIFA 96 (FIFA96.EXE) - LE/DOS4GW, Watcom C/C++32\n")
        fh.write("; entry %s at 0x%x, %d fixups applied\n" % (fname(entry), entry, im.fixup_count))
        for o in im.objects:
            fh.write(";   object %d  base 0x%06x  size 0x%06x  %s\n" % (o["num"], o["base"], o["vsize"], im.obj_kind(o)))
        fs = set(func_starts)
        for ins in insns:
            if ins.address in fs:
                n = len(calls.get(ins.address, ()))
                fh.write("\n%s:%s\n" % (fname(ins.address), "  ; %d callers" % n if n else ""))
            ops = ins.op_str
            if ins.mnemonic in ("call", "jmp") and ops.startswith("0x"):
                t = int(ops, 16)
                if t in fs:
                    ops = fname(t)
            fh.write("  %06x  %-24s %-6s %s %s\n" % (ins.address, ins.bytes.hex(), ins.mnemonic, ops,
                                                   comments.get(ins.address, "")))

    ends = func_starts[1:] + [cbase + len(cimg)]
    with open(os.path.join(out, "functions.tsv"), "w") as fh:
        fh.write("address\tname\tsize\tcallers\tstrings\n")
        for a, e in zip(func_starts, ends):
            ss = " | ".join(s.replace("\n", "\\n").replace("\t", " ")[:60] for s in fstrings.get(a, [])[:8])
            fh.write("0x%06x\t%s\t%d\t%d\t%s\n" % (a, fname(a), e - a, len(calls.get(a, ())), ss))
    with open(os.path.join(out, "strings.tsv"), "w") as fh:
        fh.write("string\treferenced_by\n")
        for s, fs_ in sorted(str_refs.items()):
            fh.write("%s\t%s\n" % (s.replace("\n", "\\n").replace("\t", "\\t"), ",".join(fname(f) for f in sorted(x for x in fs_ if x))))
    print("instructions", len(insns), "functions", len(func_starts), "strings", len(str_refs))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
