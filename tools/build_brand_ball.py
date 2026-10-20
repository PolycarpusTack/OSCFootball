"""The ball sprite from our own ball render (a ball on a flat background): cut out, then
8 frames of 16x16 turned in 45-degree steps, like the original ball's 8 roll frames.

    tools/.venv/bin/python -I tools/build_brand_ball.py game/ball_1.png game/brand/ball
"""
import os
import sys

import numpy as np
from PIL import Image

FRAMES = 8
SIZE = 16  # as the original frames


def cutout(src: str) -> Image.Image:
    """The ball as a square RGBA image: the background is the median colour of the top and
    bottom rows; the ball is the circle around everything that differs from it."""
    rgb = np.asarray(Image.open(src).convert("RGB")).astype(int)
    bg = np.median(np.concatenate([rgb[:20].reshape(-1, 3), rgb[-20:].reshape(-1, 3)]), 0)
    ys, xs = np.where(np.abs(rgb - bg).sum(2) > 40)
    cy, cx = (ys.min() + ys.max()) / 2, (xs.min() + xs.max()) / 2
    r = max(ys.max() - ys.min(), xs.max() - xs.min()) / 2
    im = Image.open(src).convert("RGBA").crop((int(cx - r), int(cy - r), int(cx + r), int(cy + r)))
    yy, xx = np.mgrid[0:im.height, 0:im.width]
    inside = (yy - im.height / 2 + 0.5) ** 2 + (xx - im.width / 2 + 0.5) ** 2 <= (r - 2) ** 2
    arr = np.asarray(im).copy()
    arr[..., 3] = inside * 255
    return Image.fromarray(arr)


def main(src: str, out: str) -> None:
    os.makedirs(out, exist_ok=True)
    ball = cutout(src)
    for i in range(FRAMES):
        frame = ball.rotate(-i * 360 / FRAMES, resample=Image.Resampling.BICUBIC).resize((SIZE, SIZE), Image.Resampling.LANCZOS)
        arr = np.asarray(frame).copy()
        arr[..., 3] = np.where(arr[..., 3] > 110, 255, 0)  # hard pixel edge
        Image.fromarray(arr).save(os.path.join(out, "ball_%d.png" % i))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
