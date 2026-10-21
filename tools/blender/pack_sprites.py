"""Packs the renders of footballer_run.py into one animation for the game: a horizontal sheet
<out_dir>/<anim>.png (RGBA, own art) and <out_dir>/animations.json in the format of
assets/sprites/players/animations.json (per drawn direction, frames {x, y, w, h, ax, ay, t};
ax, ay is where the feet touch the ground).

    tools/.venv/bin/python -I tools/blender/pack_sprites.py <render_dir> <out_dir> <anim>

Each render is shrunk 4x (box filter, so the edges stay soft inside and the noise averages
out), alpha cut at half so the edge is hard like pixel art, outlined, then cropped to what's drawn.
"""
import json
import sys
from pathlib import Path

from PIL import Image

SCALE = 4
TICKS = 31  # one cycle in game ticks (30 a second), as FIFA 96's run


def frame(path):
    img = Image.open(path).convert("RGBA")
    img = img.resize((img.width // SCALE, img.height // SCALE), Image.BOX)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
            else:  # un-premultiply what the box filter blended with the transparent edge
                k = 255.0 / a
                px[x, y] = (min(255, round(r * k)), min(255, round(g * k)), min(255, round(b * k)), 255)
    return outline(img)


def outline(img):
    """A dark pixel round the figure, like the original sprites, so it reads on the grass."""
    out = img.copy()
    src, px = img.load(), out.load()
    for y in range(img.height):
        for x in range(img.width):
            if src[x, y][3] == 0 and any(0 <= x + dx < img.width and 0 <= y + dy < img.height
                                         and src[x + dx, y + dy][3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = (24, 28, 24, 255)
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
            l, t, r, b = img.getbbox()
            cells.append((img.crop((l, t, r, b)), x))
            meta[str(d)].append({"x": x, "y": 0, "w": r - l, "h": b - t, "ax": round(ox - l), "ay": round(oy - t),
                                 "t": 1 + round(i * TICKS / n)})
            x += r - l + 1
    height = max(c.height for c, _ in cells)
    sheet = Image.new("RGBA", (x, height), (0, 0, 0, 0))
    for c, cx in cells:
        sheet.paste(c, (cx, 0))
    out.mkdir(parents=True, exist_ok=True)
    sheet.save(out / (anim + ".png"))
    path = out / "animations.json"
    all_meta = json.loads(path.read_text()) if path.exists() else {}
    all_meta[anim] = meta
    path.write_text(json.dumps(all_meta))


main()
