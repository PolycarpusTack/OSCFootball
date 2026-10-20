"""Build the Godot project's asset folder from the FIFA 96 CD contents.

Usage: build_godot_assets.py <extracted_iso_dir> <decoded_dir> <godot_project_dir>

Player animations (ART/PLAYART.PVI) become one sprite sheet + JSON per animation.
Frame names are <letter><direction><time>: direction 0/2/4/6/8 = away, up-right,
right, down-right, toward camera (the three left-facing directions are drawn
mirrored); <time> is the frame's start tick within the animation. Each frame
keeps its foot anchor (cx, cy) from the SHPI header.

Sheets are stored as 8-bit grayscale where each pixel is the original palette
index (255 = transparent), so the game can recolour kits in a shader.
palette.png (256x2) holds the colours (row 0) and, per index, the kit slot and
shade (row 1: R = slot, G = shade 0-255). Kit slots were found by where each
index appears on the body across the stand/walk/jog/run frames:
  1 shirt, 2 shirt second colour (stripes, sleeves, trim), 3 shorts, 4 socks, 5 boots.
"""
import glob
import json
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eaformats import read_bigf, read_shpi  # noqa: E402
from eahuff import EADecoders  # noqa: E402

FRAME_NAME = re.compile(r"^[a-z](\d)(\d\d)$")
TRANSPARENT = 255
KIT_SLOTS = [(204, 214, 1), (78, 101, 2), (113, 129, 2), (137, 154, 2), (197, 203, 3),
             (130, 136, 3), (102, 112, 4), (155, 168, 4), (228, 229, 5)]


def build_palette(palette):
    from PIL import Image
    slot = {}
    for a, b, s in KIT_SLOTS:
        for i in range(a, b + 1):
            slot[i] = s

    def lum(c):
        return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]

    brightest = {s: max(lum(palette[i]) for i in slot if slot[i] == s) for s in set(slot.values())}
    img = Image.new("RGB", (256, 2))
    for i in range(256):
        img.putpixel((i, 0), tuple(palette[i][:3]))
        s = slot.get(i, 0)
        shade = int(255 * lum(palette[i]) / brightest[s]) if s else 0
        img.putpixel((i, 1), (s, shade, 0))
    return img


def build_sheet(images):
    from PIL import Image
    frames = []
    for img in images:
        m = FRAME_NAME.match(img["name"])
        if not m or not img["width"]:
            continue
        pil = Image.frombytes("L", (img["width"], img["height"]), img["pixels"])
        frames.append((int(m.group(1)), int(m.group(2)), img, pil))
    if not frames:
        return None, None
    pad = 1
    width = sum(f[3].width + pad for f in frames)
    height = max(f[3].height for f in frames)
    sheet = Image.new("L", (width, height), TRANSPARENT)
    meta = {}
    x = 0
    for direction, t, img, pil in frames:
        sheet.paste(pil, (x, 0))
        meta.setdefault(str(direction), []).append(
            dict(x=x, y=0, w=pil.width, h=pil.height, ax=img["cx"], ay=img["cy"], t=t))
        x += pil.width + pad
    for lst in meta.values():
        lst.sort(key=lambda f: f["t"])
    return sheet, meta


def main(src, decoded, project):
    dec = EADecoders(os.path.join(src, "FIFA96.EXE"))
    art = dict(read_bigf(dec.unpack(open(os.path.join(src, "ART/GAMEART0.PVI"), "rb").read())))
    palette = read_shpi(dec.unpack(art["PALsys.fsh"]))[1][0]["palette"]

    sprites = os.path.join(project, "assets/sprites/players")
    os.makedirs(sprites, exist_ok=True)
    shapes = {}
    for name, blob in read_bigf(dec.unpack(open(os.path.join(src, "ART/PLAYART.PVI"), "rb").read())):
        shapes[name.rsplit(".", 1)[0].lower()] = read_shpi(dec.unpack(blob))[1]
    # Large animations were split over "<name>a" / "<name>b" files, each holding
    # different directions. Rejoin pairs whose directions do not overlap.
    for a in [n for n in shapes if n.endswith("a") and n[:-1] + "b" in shapes]:
        base, b = a[:-1], a[:-1] + "b"
        dirs = [{FRAME_NAME.match(i["name"]).group(1) for i in shapes[n] if FRAME_NAME.match(i["name"])} for n in (a, b)]
        if base not in shapes and not dirs[0] & dirs[1]:
            shapes[base] = shapes.pop(a) + shapes.pop(b)
    index = {}
    for anim, images in sorted(shapes.items()):
        sheet, meta = build_sheet(images)
        if sheet is None:
            continue
        sheet.save(os.path.join(sprites, anim + ".png"))
        index[anim] = meta
    build_palette(palette).save(os.path.join(sprites, "palette.png"))
    with open(os.path.join(sprites, "animations.json"), "w") as fh:
        json.dump(index, fh, separators=(",", ":"))

    copies = {
        "ART/GAMEFLD1.PVI/FplainH.fsh/000_Fpl6.png": "assets/pitch/grass.png",
        "ART/GAMEART0.PVI/ball.fsh": "assets/ball",
        "ART/GAMEART0.PVI/Net.fsh": "assets/goal/net",
        "FEGFX/TITLE.POG": "assets/ui/title",
        # 3D stadium textures (largest mip of each): crowd, advertising boards, stand front, roof
        "ART/GAMESTD1.PVI/STACcovr.fsh/002_c003.png": "assets/stadium/crowd.png",
        "ART/GAMESTD1.PVI/STACcovr.fsh/005_c006.png": "assets/stadium/crowd_tunnel.png",
        "ART/GAMESTD1.PVI/STACcovr.fsh/008_c009.png": "assets/stadium/crowd_stairs.png",
        "ART/GAMEART0.PVI/STAFront.fsh/002_fr03.png": "assets/stadium/front.png",
        "ART/GAMEART0.PVI/STAFront.fsh/005_fc03.png": "assets/stadium/front_corner.png",
        "ART/GAMESTD1.PVI/STARcovr.fsh/000_r001.png": "assets/stadium/roof.png",
        "ART/GAMESTD1.PVI/STAScovr.fsh/000_s001.png": "assets/stadium/stand_end.png",
    }
    from PIL import Image
    boards = sorted(glob.glob(os.path.join(decoded, "images/ART/GAMESTD1.PVI/STABcovr.fsh/*.png")))
    for i, src in enumerate(b for b in boards if Image.open(b).width == 128):
        os.makedirs(os.path.join(project, "assets/stadium"), exist_ok=True)
        shutil.copy(src, os.path.join(project, "assets/stadium/board%d.png" % i))
    img_root = os.path.join(decoded, "images")
    for rel, dst in copies.items():
        s, d = os.path.join(img_root, rel), os.path.join(project, dst)
        if os.path.isdir(s):
            shutil.copytree(s, d, dirs_exist_ok=True)
        elif os.path.exists(s):
            os.makedirs(os.path.dirname(d), exist_ok=True)
            shutil.copy(s, d)
        else:
            print("missing", rel)

    audio = os.path.join(decoded, "audio")
    for sub, dst in (("music", "assets/audio/music"), ("SFX_GAME.BNK", "assets/audio/sfx"),
                     ("CHN_GEN1.BNK", "assets/audio/crowd")):
        shutil.copytree(os.path.join(audio, sub), os.path.join(project, dst), dirs_exist_ok=True)
    shutil.copytree(os.path.join(decoded, "data"), os.path.join(project, "data"), dirs_exist_ok=True)
    # intro FMV for the boot sequence; Godot plays Ogg Theora
    intro = os.path.join(project, "assets/video/intro.ogv")
    if not os.path.exists(intro):
        os.makedirs(os.path.dirname(intro), exist_ok=True)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", os.path.join(decoded, "video/VID_INTR.mp4"),
                        "-vf", "scale=640:480", "-c:v", "libtheora", "-q:v", "8", "-c:a", "libvorbis", "-q:a", "5",
                        intro], check=True)
    print("animations", len(index))


if __name__ == "__main__":
    main(*sys.argv[1:4])
