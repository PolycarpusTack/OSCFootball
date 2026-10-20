"""EA Huffman (0x30FB-0x35FB) and BTree (0x46FB) decompression, done by emulating
the game's own decoders from FIFA96.EXE. Both are called from the game's
decompression dispatcher (around 0x9e74c) with Watcom register arguments:

  sub_09c7e0  Huffman  eax=src, edx=dst, ebx=1   -> eax = decoded length
  sub_09da14  BTree    eax=src, edx=dst          -> eax = decoded length

A stage's output may itself be compressed (e.g. Huffman -> RefPack -> BTree);
`unpack` peels layers until none is left.
"""
import os
import sys

from unicorn import UC_ARCH_X86, UC_MODE_32, Uc
from unicorn.x86_const import UC_X86_REG_EAX, UC_X86_REG_EBX, UC_X86_REG_EDX, UC_X86_REG_ESP

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eaformats import is_refpack, refpack_decompress  # noqa: E402
from le import LEImage  # noqa: E402

HUFFMAN, BTREE = 0x09C7E0, 0x09DA14
STACK, SRC, DST, RET = 0x0800000, 0x1000000, 0x2000000, 0x0700000


def _align(n):
    return (n + 0xFFFF) & ~0xFFFF


def is_huffman(d):
    return len(d) > 5 and d[1] == 0xFB and d[0] & 0xFE in (0x30, 0x32, 0x34)


def is_btree(d):
    return len(d) > 5 and d[1] == 0xFB and d[0] & 0xFE == 0x46


class EADecoders:
    def __init__(self, exe_path):
        im = LEImage(open(exe_path, "rb").read())
        self.objects = [(o["base"], bytes(o["image"])) for o in im.objects]

    def _run(self, func, data, ebx=None):
        # flag bit 0 set: a 3-byte size precedes this stage's own output size
        hdr = 5 if data[0] & 1 else 2
        out_len = int.from_bytes(data[hdr:hdr + 3], "big")
        uc = Uc(UC_ARCH_X86, UC_MODE_32)
        for base, img in self.objects:
            uc.mem_map(base & ~0xFFFF, _align((base & 0xFFFF) + len(img)))
            uc.mem_write(base, img)
        uc.mem_map(RET, 0x1000)
        uc.mem_write(RET, b"\xf4")  # hlt
        uc.mem_map(STACK, 0x100000)
        uc.mem_map(SRC, _align(len(data) + 0x1000))
        uc.mem_write(SRC, bytes(data))
        uc.mem_map(DST, _align(out_len + 0x10000))
        esp = STACK + 0xFFF00
        uc.mem_write(esp, RET.to_bytes(4, "little"))
        uc.reg_write(UC_X86_REG_ESP, esp)
        uc.reg_write(UC_X86_REG_EAX, SRC)
        uc.reg_write(UC_X86_REG_EDX, DST)
        if ebx is not None:
            uc.reg_write(UC_X86_REG_EBX, ebx)
        uc.emu_start(func, RET)
        n = uc.reg_read(UC_X86_REG_EAX)
        if n != out_len:
            raise ValueError("decoder 0x%x produced %d bytes, header says %d" % (func, n, out_len))
        return bytes(uc.mem_read(DST, n))

    def unpack(self, data):
        while True:
            if is_huffman(data):
                data = self._run(HUFFMAN, data, ebx=1)
            elif is_btree(data):
                data = self._run(BTREE, data)
            elif is_refpack(data):
                data = refpack_decompress(data)
            else:
                return data
