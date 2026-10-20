"""Readers for the Electronic Arts data formats found on the FIFA 96 PC CD-ROM."""
import struct


def refpack_decompress(data):
    """Decompress EA RefPack (magic 0x10FB / 0x11FB, big-endian sizes)."""
    flags, magic = data[0], data[1]
    if magic != 0xFB or (flags & 0x3E) != 0x10:
        raise ValueError("not RefPack")
    pos = 2
    size = int.from_bytes(data[pos:pos + 3], "big"); pos += 3
    if flags & 0x01:  # compressed size follows
        pos += 3
    out = bytearray()
    n = len(data)
    while pos < n and len(out) < size:
        b0 = data[pos]
        if b0 < 0x80:
            b1 = data[pos + 1]; pos += 2
            lit = b0 & 3
            cnt = ((b0 >> 2) & 7) + 3
            off = ((b0 & 0x60) << 3) + b1 + 1
        elif b0 < 0xC0:
            b1, b2 = data[pos + 1], data[pos + 2]; pos += 3
            lit = b1 >> 6
            cnt = (b0 & 0x3F) + 4
            off = ((b1 & 0x3F) << 8) + b2 + 1
        elif b0 < 0xE0:
            b1, b2, b3 = data[pos + 1], data[pos + 2], data[pos + 3]; pos += 4
            lit = b0 & 3
            cnt = ((b0 & 0x0C) << 6) + b3 + 5
            off = ((b0 & 0x10) << 12) + (b1 << 8) + b2 + 1
        elif b0 < 0xFC:
            pos += 1
            lit = ((b0 & 0x1F) << 2) + 4
            out += data[pos:pos + lit]; pos += lit
            continue
        else:  # end marker with 0-3 trailing literals
            pos += 1
            lit = b0 & 3
            out += data[pos:pos + lit]
            break
        out += data[pos:pos + lit]; pos += lit
        start = len(out) - off
        for i in range(cnt):  # byte-wise: overlapping copies are legal
            out.append(out[start + i])
    # Some 1995-era streams have no stop code; the last command may overrun by a few bytes.
    if len(out) < size:
        raise ValueError(f"RefPack truncated {len(out)} < {size}")
    return bytes(out[:size])


def is_refpack(data):
    return len(data) > 5 and data[1] == 0xFB and (data[0] & 0x3E) == 0x10


def maybe_decompress(data):
    return refpack_decompress(data) if is_refpack(data) else data


def read_bigf(data):
    """EA BIGF archive -> list of (name, bytes). Header and directory are big-endian."""
    if data[:4] != b"BIGF":
        raise ValueError("not BIGF")
    count, hdr_len = struct.unpack(">II", data[8:16])
    pos = 16
    entries = []
    for _ in range(count):
        off, size = struct.unpack(">II", data[pos:pos + 8]); pos += 8
        end = data.index(b"\0", pos)
        name = data[pos:end].decode("latin-1"); pos = end + 1
        entries.append((name, data[off:off + size]))
    return entries


# --- SHPI ("shape") image containers -------------------------------------
def _u24(b, o):
    return b[o] | (b[o + 1] << 8) | (b[o + 2] << 16)


def _parse_palette(block):
    kind = block[0] & 0x7F
    w = struct.unpack_from("<H", block, 4)[0]
    body = block[16:]
    pal = []
    if kind == 0x22:  # 24-bit, 6 bits per channel (VGA DAC)
        for i in range(w):
            r, g, b = body[i * 3:i * 3 + 3]
            pal.append(((r & 63) * 255 // 63, (g & 63) * 255 // 63, (b & 63) * 255 // 63, 255))
    elif kind == 0x24:
        for i in range(w):
            r, g, b = body[i * 3:i * 3 + 3]
            pal.append((r, g, b, 255))
    elif kind == 0x2A:
        for i in range(w):
            b, g, r, a = body[i * 4:i * 4 + 4]
            pal.append((r, g, b, a))
    elif kind == 0x2D:
        for i in range(w):
            v = struct.unpack_from("<H", body, i * 2)[0]
            pal.append((((v >> 10) & 31) * 255 // 31, ((v >> 5) & 31) * 255 // 31, (v & 31) * 255 // 31, 255))
    else:
        return None
    return pal


def read_shpi(data):
    """SHPI container -> (dir_id, [ {name, kind, width, height, x, y, pixels, palette} ])."""
    if data[:4] != b"SHPI":
        raise ValueError("not SHPI")
    count = struct.unpack_from("<I", data, 8)[0]
    dir_id = data[12:16].decode("latin-1")
    dirs = []
    for i in range(count):
        name = data[16 + i * 8:20 + i * 8].decode("latin-1", "replace")
        off = struct.unpack_from("<I", data, 20 + i * 8)[0]
        dirs.append((name, off))
    global_pal = None
    for name, off in dirs:
        if name == "!pal":
            global_pal = _parse_palette(data[off:])
    images = []
    for idx, (name, off) in enumerate(dirs):
        kind = data[off] & 0x7F
        w, h, cx, cy, x, y = struct.unpack_from("<6H", data, off + 4)
        img = dict(name=name, kind=kind, width=w, height=h, cx=cx, cy=cy, x=x, y=y, palette=None, pixels=None)
        if kind == 0x7B:
            img["pixels"] = data[off + 16:off + 16 + w * h]
            # attachments (local palette) chained by the 24-bit "next" field
            nxt = _u24(data, off + 1)
            a = off
            while nxt:
                a += nxt
                pal = _parse_palette(data[a:])
                if pal:
                    img["palette"] = pal
                nxt = _u24(data, a + 1)
            if img["palette"] is None:
                img["palette"] = global_pal
        elif kind in (0x7D, 0x7F, 0x78, 0x7E, 0x6D):
            bpp = {0x7D: 4, 0x7F: 3, 0x78: 2, 0x7E: 2, 0x6D: 2}[kind]
            img["pixels"] = data[off + 16:off + 16 + w * h * bpp]
        images.append(img)
    return dir_id, images


def shpi_image_to_pil(img):
    from PIL import Image
    w, h, k = img["width"], img["height"], img["kind"]
    if not w or not h or img["pixels"] is None:
        return None
    px = img["pixels"]
    if k == 0x7B:
        pal = img["palette"] or [(i, i, i, 255) for i in range(256)]
        im = Image.frombytes("P", (w, h), px.ljust(w * h, b"\0"))
        flat = []
        for c in pal[:256]:
            flat += c[:3]
        im.putpalette(flat)
        return im
    if k == 0x7D:
        return Image.frombytes("RGBA", (w, h), px, "raw", "BGRA")
    if k == 0x7F:
        return Image.frombytes("RGB", (w, h), px, "raw", "BGR")
    if k == 0x78:
        return Image.frombytes("RGB", (w, h), px, "raw", "BGR;16")
    if k == 0x7E:
        return Image.frombytes("RGB", (w, h), px, "raw", "BGR;15")
    return None


# --- EACS audio -------------------------------------------------------------
_IMA_STEP = [7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66,
             73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408,
             449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
             2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630,
             9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767]
_IMA_INDEX = [-1, -1, -1, -1, 2, 4, 6, 8]


def parse_eacs(data):
    """EACS header -> dict. Layout (little-endian): 'EACS', rate u32, bytes/sample u8,
    channels u8, compression u8 (0=PCM, 2=EA IMA ADPCM), type u8, samples u32,
    loop start u32, loop length u32, data offset u32."""
    if data[:4] != b"EACS":
        raise ValueError("not EACS")
    rate = struct.unpack_from("<I", data, 4)[0]
    width, chans, comp, typ = data[8], data[9], data[10], data[11]
    nsamp, loop_start, loop_len, data_off = struct.unpack_from("<4I", data, 12)
    return dict(rate=rate, width=width, channels=chans, compression=comp, type=typ,
                samples=nsamp, loop_start=loop_start, loop_len=loop_len, data_offset=data_off)


def ima_decode(payload, nsamples, channels=1):
    """EA 'EACS' IMA ADPCM: no per-block header, predictor/step start at 0,
    high nibble first; stereo interleaves L (high) / R (low) per byte."""
    pred = [0] * channels
    idx = [0] * channels
    out = []

    def nib(ch, n):
        step = _IMA_STEP[idx[ch]]
        diff = step >> 3
        if n & 4: diff += step
        if n & 2: diff += step >> 1
        if n & 1: diff += step >> 2
        p = pred[ch] - diff if n & 8 else pred[ch] + diff
        pred[ch] = max(-32768, min(32767, p))
        idx[ch] = max(0, min(88, idx[ch] + _IMA_INDEX[n & 7]))
        return pred[ch]

    total = nsamples * channels
    for b in payload:
        if channels == 1:
            out.append(nib(0, b >> 4)); out.append(nib(0, b & 15))
        else:
            out.append(nib(0, b >> 4)); out.append(nib(1, b & 15))
        if len(out) >= total:
            break
    return out[:total]


def eacs_to_wav(container, eacs_pos=0):
    """EACS sample -> WAV bytes. The header's data offset is relative to the start
    of the containing file (.spc entry or whole .BNK), so pass that container."""
    import io
    import wave
    h = parse_eacs(container[eacs_pos:])
    body = container[h["data_offset"]:]
    if h["compression"] == 2:
        pcm = struct.pack("<%dh" % (h["samples"] * h["channels"]), *ima_decode(body, h["samples"], h["channels"]))
        width = 2
    elif h["compression"] == 0:
        width = h["width"]
        pcm = body[:h["samples"] * h["channels"] * width]
        if width == 1:  # EA stores signed 8-bit; WAV wants unsigned
            pcm = bytes((b + 128) & 0xFF for b in pcm)
    else:
        raise ValueError("unknown EACS compression %d" % h["compression"])
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(h["channels"]); w.setsampwidth(width); w.setframerate(h["rate"])
        w.writeframes(pcm)
    return buf.getvalue()


def read_bnk(data):
    """SFX/chant bank: 128 u32 slots at offset 0 (0 = empty), each pointing to a
    72-byte patch record whose EACS header sits at +0x28. Returns [(slot, eacs_pos)]."""
    out = []
    for slot in range(128):
        off = struct.unpack_from("<I", data, slot * 4)[0]
        if off and data[off + 0x28:off + 0x2C] == b"EACS":
            out.append((slot, off + 0x28))
    return out
