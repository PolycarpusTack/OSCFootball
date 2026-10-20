"""Turn the EA SPORTS FC 27 download (tools/fetch_ea_ratings.py) into game data:

- game/data/squads.json: per club, the best 4-4-2 (formation order: GK, RB, CB, CB, LB,
  RM, CM, CM, LM, ST, ST) then the substitutes, each with all EA ratings
- game/assets/clubs/<SHORT>.png: club crest; <SHORT>_board.png: a pitch-side board
- game/assets/portraits/<id>.png: player photo pixelated to 40x40, 16 colours;
  unknown.png for players EA has no photo of
- per player with a photo: skin and hair colour sampled from it, for the sprites

    tools/.venv/bin/python -I tools/build_ea_assets.py downloads/ea_fc27 game
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
PORTRAIT = 40  # pixels square
PORTRAIT_COLOURS = 16
BOARD = (256, 32)  # two times the original 128x16 boards
# formation slot -> EA positions that fit it, best first
SLOTS = [
    ("GK", ["GK"]), ("RB", ["RB", "RWB"]), ("CB", ["CB"]), ("CB", ["CB"]), ("LB", ["LB", "LWB"]),
    ("RM", ["RM", "RW"]), ("CM", ["CM", "CDM", "CAM"]), ("CM", ["CM", "CDM", "CAM"]), ("LM", ["LM", "LW"]),
    ("ST", ["ST", "CF"]), ("ST", ["ST", "CF"]),
]
FILL_ORDER = [0, 9, 10, 2, 3, 6, 7, 1, 4, 5, 8]  # keeper and strikers first, wide players last


def positions(p: dict) -> tuple[str, list[str]]:
    alt = [a["shortLabel"] for a in (p.get("alternatePositions") or [])]
    return p["position"]["shortLabel"], alt


def best_xi(players: list[dict]) -> list[dict]:
    """Greedy: each slot takes the best unused player whose main position fits, else one
    whose alternative position fits, else the best unused outfield player."""
    pool = sorted(players, key=lambda p: -p["overallRating"])
    used: set[int] = set()
    xi: list[dict | None] = [None] * len(SLOTS)
    for slot in FILL_ORDER:
        fits = SLOTS[slot][1]
        tests = [lambda p: positions(p)[0] in fits, lambda p: any(a in fits for a in positions(p)[1])]
        if fits != ["GK"]:
            tests.append(lambda p: positions(p)[0] != "GK")
        for test in tests:
            pick = next((p for p in pool if p["id"] not in used and test(p)), None)
            if pick:
                xi[slot] = pick
                used.add(pick["id"])
                break
    subs = [p for p in pool if p["id"] not in used]
    return [p for p in xi if p] + subs


def entry(p: dict, number: int, photo: str | None) -> dict:
    e = {
        "id": p["id"],
        "name": p.get("commonName") or p["lastName"],
        "full_name": f'{p["firstName"]} {p["lastName"]}',
        "number": number,  # by formation slot: EA's pages don't list shirt numbers
        "position": p["position"]["shortLabel"],
        "overall": p["overallRating"],
        "preferred_foot": "right" if p.get("preferredFoot") == 1 else "left",
        "weak_foot": p.get("weakFootAbility"),
        "skill_moves": p.get("skillMoves"),
        "portrait": photo is not None,
        "stats": {k: v["value"] for k, v in p["stats"].items()},
    }
    if photo:
        e["skin"], e["hair"] = skin_and_hair(photo)
    return e


def pixelate(src: str, dst: str) -> None:
    im = Image.open(src).convert("RGBA")
    box = im.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox() or (0, 0, *im.size)
    im = im.crop(box)
    side = max(im.size)  # square, head and shoulders centred at the bottom
    sq = Image.new("RGBA", (side, side))
    sq.paste(im, ((side - im.width) // 2, side - im.height))
    small = sq.resize((PORTRAIT, PORTRAIT), Image.Resampling.BOX)
    alpha = small.getchannel("A").point(lambda a: 255 if a > 110 else 0)
    rgb = small.convert("RGB").quantize(PORTRAIT_COLOURS, method=Image.Quantize.MEDIANCUT).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    out.save(dst)


def _median(pixels: list[tuple]) -> tuple:
    return tuple(sorted(p[c] for p in pixels)[len(pixels) // 2] for c in range(3))


def skin_and_hair(src: str) -> tuple[str, str]:
    """Median colour of the cheeks and of the top of the head in the photo (head and
    shoulders on a transparent background). A bald head gives a skin-like hair colour."""
    im = Image.open(src).convert("RGBA")
    left, top, right, bottom = im.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox()
    w, h = right - left, bottom - top

    def sample(x0, x1, y0, y1):
        px = [im.getpixel((x, y)) for y in range(int(top + y0 * h), int(top + y1 * h))
              for x in range(int(left + x0 * w), int(left + x1 * w))]
        return _median([p for p in px if p[3] > 200] or [(128, 128, 128, 255)])

    skin = sample(0.38, 0.62, 0.30, 0.40)  # cheeks and nose, below the eyes
    hair = sample(0.40, 0.60, 0.00, 0.05)  # crown
    return "%02x%02x%02x" % skin, "%02x%02x%02x" % hair


def silhouette(dst: str) -> None:
    im = Image.new("RGBA", (PORTRAIT, PORTRAIT))
    d = ImageDraw.Draw(im)
    shade = (58, 62, 74, 255)
    d.ellipse((13, 6, 27, 22), fill=shade)                    # head
    d.rectangle((17, 20, 23, 26), fill=shade)                 # neck
    d.chord((4, 24, 36, 56), 180, 360, fill=shade)            # shoulders
    im.save(dst)


def board(crest: Image.Image | None, name: str, shirt: str, dst: str) -> None:
    bg = tuple(int(shirt[i:i + 2], 16) for i in (0, 2, 4))
    light = 0.299 * bg[0] + 0.587 * bg[1] + 0.114 * bg[2] > 150
    im = Image.new("RGB", BOARD, bg)
    d = ImageDraw.Draw(im)
    x = 4
    if crest:
        c = crest.copy()
        c.thumbnail((BOARD[1] - 4, BOARD[1] - 4), Image.Resampling.LANCZOS)
        im.paste(c, (x, (BOARD[1] - c.height) // 2), c)
        x += c.width + 6
    font = ImageFont.truetype(FONT, 18)
    text = name.upper()
    while d.textlength(text, font=font) > BOARD[0] - x - 4 and font.size > 9:
        font = ImageFont.truetype(FONT, font.size - 1)
    w = d.textlength(text, font=font)
    d.text((x + (BOARD[0] - x - w) / 2, BOARD[1] / 2), text, font=font, anchor="lm",
           fill=(20, 20, 24) if light else (245, 245, 245))
    im.save(dst)


def main(download: str, project: str) -> None:
    players = json.load(open(os.path.join(download, "players.json"), encoding="utf-8"))
    league = json.load(open(os.path.join(project, "data", "league.json"), encoding="utf-8"))
    clubs_dir = os.path.join(project, "assets", "clubs")
    portraits_dir = os.path.join(project, "assets", "portraits")
    os.makedirs(clubs_dir, exist_ok=True)
    os.makedirs(portraits_dir, exist_ok=True)
    silhouette(os.path.join(portraits_dir, "unknown.png"))

    squads = {}
    for club in league["teams"]:
        squad = [p for p in players if p["team"]["id"] == club["ea_id"]]
        ordered = best_xi(squad)
        rows = []
        for i, p in enumerate(ordered):
            photo = os.path.join(download, "portraits", f'{int(p["id"])}.png')
            has = os.path.exists(photo)
            if has:
                pixelate(photo, os.path.join(portraits_dir, f'{int(p["id"])}.png'))
            rows.append(entry(p, i + 1, photo if has else None))
        squads[club["name"]] = rows
        crest_path = os.path.join(download, "crests", f'{int(club["ea_id"])}.png')
        crest = Image.open(crest_path).convert("RGBA") if os.path.exists(crest_path) else None
        if crest:
            c = crest.copy()
            c.thumbnail((128, 128), Image.Resampling.LANCZOS)
            c.save(os.path.join(clubs_dir, f'{club["short"]}.png'))
        board(crest, club["name"], club["kit"]["shirt"], os.path.join(clubs_dir, f'{club["short"]}_board.png'))
        xi = ", ".join(f'{SLOTS[j][0]} {r["name"]} {r["overall"]}' for j, r in enumerate(rows[:11]))
        print(f'{club["short"]}: {len(rows)} players; XI: {xi}')
    with open(os.path.join(project, "data", "squads.json"), "w", encoding="utf-8") as f:
        json.dump(squads, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
