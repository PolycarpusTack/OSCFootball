"""Minimal loader for DOS/4GW Linear Executable (LE) binaries built with Watcom C.

Loads every object at its preferred base address, applies internal fixups and
returns a flat memory image that a disassembler can work on.
"""
import struct


class LEImage:
    def __init__(self, data):
        self.data = data
        self.le = data.find(b"LE\x00\x00")
        if self.le < 0:
            raise ValueError("no LE header")
        # In a bound DOS/4GW executable the extender stub comes first; the
        # application's own MZ header sits in front of the LE header and the
        # data-pages offset is relative to that inner MZ.
        self.mz = 0
        i = data.find(b"MZ", 1)
        while 0 <= i < self.le:
            if i + struct.unpack_from("<I", data, i + 0x3C)[0] == self.le:
                self.mz = i
                break
            i = data.find(b"MZ", i + 1)
        h = self.le
        u32 = lambda o: struct.unpack_from("<I", data, h + o)[0]
        self.num_pages = u32(0x14)
        self.eip_obj, self.eip = u32(0x18), u32(0x1C)
        self.esp_obj, self.esp = u32(0x20), u32(0x24)
        self.page_size = u32(0x28)
        self.last_page = u32(0x2C)
        obj_tab, n_obj = u32(0x40), u32(0x44)
        self.page_map_off = h + u32(0x48)
        self.fixup_page_off = h + u32(0x68)
        self.fixup_rec_off = h + u32(0x6C)
        self.data_pages = self.mz + u32(0x80)
        self.objects = []
        for i in range(n_obj):
            vsize, base, flags, pidx, npages, _ = struct.unpack_from("<6I", data, h + obj_tab + i * 24)
            self.objects.append(dict(num=i + 1, vsize=vsize, base=base, flags=flags, page_index=pidx, npages=npages))
        self.mem = {}
        self._load()

    def obj_kind(self, o):
        f = o["flags"]
        return ("code" if f & 0x4 else "data") + ("32" if f & 0x2000 else "16")

    def _page_file_offset(self, logical_page):
        # LE page map entry: 3-byte big-endian physical page number + flags byte
        e = self.data[self.page_map_off + (logical_page - 1) * 4:self.page_map_off + logical_page * 4]
        phys = (e[0] << 16) | (e[1] << 8) | e[2]
        if phys == 0:
            phys = logical_page
        return self.data_pages + (phys - 1) * self.page_size, phys

    def _load(self):
        d = self.data
        for o in self.objects:
            buf = bytearray(o["vsize"])
            for k in range(o["npages"]):
                lp = o["page_index"] + k
                off, phys = self._page_file_offset(lp)
                size = self.last_page if phys == self.num_pages else self.page_size
                chunk = d[off:off + size]
                buf[k * self.page_size:k * self.page_size + len(chunk)] = chunk[:max(0, len(buf) - k * self.page_size)]
            o["image"] = buf
        self.fixup_count = 0
        for o in self.objects:
            for k in range(o["npages"]):
                self._apply_fixups(o, o["page_index"] + k, k * self.page_size)

    def _apply_fixups(self, obj, lp, page_base):
        d = self.data
        start = struct.unpack_from("<I", d, self.fixup_page_off + (lp - 1) * 4)[0]
        end = struct.unpack_from("<I", d, self.fixup_page_off + lp * 4)[0]
        p = self.fixup_rec_off + start
        stop = self.fixup_rec_off + end
        buf = obj["image"]
        while p < stop:
            src, flg = d[p], d[p + 1]; p += 2
            if src & 0x20:
                cnt = d[p]; p += 1
                srcoffs = None
            else:
                srcoffs = [struct.unpack_from("<h", d, p)[0]]; p += 2
            if flg & 3 != 0:
                raise NotImplementedError("imported fixups not expected in a DOS/4GW image")
            if flg & 0x40:
                tobj = struct.unpack_from("<H", d, p)[0]; p += 2
            else:
                tobj = d[p]; p += 1
            stype = src & 0x0F
            if stype == 0x02:
                toff = 0
            elif flg & 0x10:
                toff = struct.unpack_from("<I", d, p)[0]; p += 4
            else:
                toff = struct.unpack_from("<H", d, p)[0]; p += 2
            if srcoffs is None:
                srcoffs = list(struct.unpack_from("<%dh" % cnt, d, p)); p += 2 * cnt
            target = self.objects[tobj - 1]["base"] + toff
            for so in srcoffs:
                at = page_base + so
                if at < 0 or at + 4 > len(buf):
                    continue
                if stype == 0x07:  # 32-bit offset
                    struct.pack_into("<I", buf, at, target & 0xFFFFFFFF)
                elif stype == 0x08:  # 32-bit self-relative
                    struct.pack_into("<i", buf, at, target - (obj["base"] + at + 4))
                elif stype == 0x05:
                    struct.pack_into("<H", buf, at, target & 0xFFFF)
                elif stype == 0x06:  # 16:32 pointer
                    struct.pack_into("<I", buf, at, target & 0xFFFFFFFF)
                self.fixup_count += 1

    def object_at(self, addr):
        for o in self.objects:
            if o["base"] <= addr < o["base"] + o["vsize"]:
                return o
        return None

    def read(self, addr, n):
        o = self.object_at(addr)
        if not o:
            return None
        a = addr - o["base"]
        return bytes(o["image"][a:a + n])

    def cstring(self, addr, maxlen=200):
        o = self.object_at(addr)
        if not o:
            return None
        a = addr - o["base"]
        img = o["image"]
        e = img.find(b"\0", a, a + maxlen)
        if e < 0:
            return None
        return bytes(img[a:e])
