"""Packs the coded renders of footballer_run.py into one animation for the game, in FIFA 96's
format (see tools/build_godot_assets.py): an 8-bit grayscale sheet <out_dir>/<anim>.png whose
pixels are palette indices (255 transparent), <out_dir>/palette.png (256 x 2: row 0 the
colours, row 1 R = kit slot, G = shade) and <out_dir>/animations.json (per drawn direction,
frames {x, y, w, h, ax, ay, t}; ax, ay is where the feet touch the ground).

    tools/.venv/bin/python -I tools/blender/pack_sprites.py <render_dir> <out_dir> <anim>

Each 4 x 4 block of a render becomes one pixel: drawn if half of it is, in the slot most of
it shows, at the shade band of that slot's average light. A dark outline goes round the
figure, like the original sprites, so it reads on the grass.
"""
import json
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

SCALE = 4
TICKS = 31  # one cycle in game ticks (30 a second), as FIFA 96's run
SLOT_STEP = 32  # footballer_run.py's red byte per kit slot
TRANSPARENT = 255
OUTLINE = 0  # palette index, slot 0: drawn as is
OUTLINE_COLOUR = (24, 28, 24)
BANDS = [-0.1, 0.3, 0.65]  # light . normal where the next shade band starts
# per slot: the colour row 0 shows when the shader doesn't recolour it (the OSCF kit: white
# shirt and socks, blue shorts; skin and hair for a player without a photo), and the shade of
# each band (row 1). Skin and hair are centred lower: the shader's photo ramp is 0.35 + 1.3 g.
KIT_SHADES = [0.55, 0.7, 0.85, 1.0]
BODY_SHADES = [0.3, 0.4, 0.5, 0.62]
SLOTS = {
    1: ((242, 242, 242), KIT_SHADES), 2: ((242, 242, 242), KIT_SHADES), 3: ((26, 56, 204), KIT_SHADES),
    4: ((242, 242, 242), KIT_SHADES), 5: ((26, 26, 26), KIT_SHADES),
    6: ((235, 173, 128), BODY_SHADES), 7: ((77, 51, 26), BODY_SHADES),
}


def index(slot, band):
    return slot * 16 + band


def palette():
    img = Image.new("RGB", (256, 2))
    img.putpixel((OUTLINE, 0), OUTLINE_COLOUR)
    for slot, (colour, shades) in SLOTS.items():
        for band, g in enumerate(shades):
            lit = (0.55 + 0.45 * band / (len(shades) - 1))
            img.putpixel((index(slot, band), 0), tuple(round(c * lit) for c in colour))
            img.putpixel((index(slot, band), 1), (slot, round(255 * g), 0))
    return img


def linear(byte):
    v = byte / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def frame(path):
    src = Image.open(path).convert("RGBA")
    px = src.load()
    w, h = src.width // SCALE, src.height // SCALE
    out = Image.new("L", (w, h), TRANSPARENT)
    dst = out.load()
    for y in range(h):
        for x in range(w):
            block = [px[x * SCALE + i, y * SCALE + j] for i in range(SCALE) for j in range(SCALE)]
            drawn = [p for p in block if p[3] > 127]
            if len(drawn) * 2 < len(block):
                continue
            slot = Counter(round(p[0] / SLOT_STEP) for p in drawn).most_common(1)[0][0]
            if slot not in SLOTS:
                continue
            light = [2.0 * linear(p[1]) - 1.0 for p in drawn if round(p[0] / SLOT_STEP) == slot]
            dot = sum(light) / len(light)
            dst[x, y] = index(slot, sum(dot >= b for b in BANDS))
    return outline(out)


def outline(img):
    out = img.copy()
    src, px = img.load(), out.load()
    for y in range(img.height):
        for x in range(img.width):
            if src[x, y] == TRANSPARENT and any(0 <= x + dx < img.width and 0 <= y + dy < img.height
                                                and src[x + dx, y + dy] != TRANSPARENT
                                                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = OUTLINE
    return out


def main():
    src, out, anim = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
    origin = json.loads((src / "origin.json").read_text())
    ox, oy = origin["x"] / SCALE, origin["y"] / SCALE
    n = origin["frames"]
    cells, meta = [], {}
    x = 0
    for d in (0, 2, 4, 6, 8):
        meta[str(d)] = []
        for i in range(n):
            img = frame(src / ("%d_%02d.png" % (d, i)))
            l, t, r, b = img.point(lambda v: 0 if v == TRANSPARENT else 255).getbbox()
            cells.append((img.crop((l, t, r, b)), x))
            meta[str(d)].append({"x": x, "y": 0, "w": r - l, "h": b - t, "ax": round(ox - l), "ay": round(oy - t),
                                 "t": 1 + round(i * TICKS / n)})
            x += r - l + 1
    height = max(c.height for c, _ in cells)
    sheet = Image.new("L", (x, height), TRANSPARENT)
    for c, cx in cells:
        sheet.paste(c, (cx, 0))
    out.mkdir(parents=True, exist_ok=True)
    sheet.save(out / (anim + ".png"))
    palette().save(out / "palette.png")
    path = out / "animations.json"
    all_meta = json.loads(path.read_text()) if path.exists() else {}
    all_meta[anim] = meta
    path.write_text(json.dumps(all_meta))


main()
