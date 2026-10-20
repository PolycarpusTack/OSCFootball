"""Download the 1A Pro League squads, ratings, club crests and player portraits from
EA SPORTS FC 27's public ratings site, politely (one page every 2 s), into
downloads/ea_fc27/. EA's data: personal use only, kept out of git.

    tools/.venv/bin/python -I tools/fetch_ea_ratings.py downloads/ea_fc27

Re-running skips what is already there. Everything downloaded is treated as data:
images only from EA's two image hosts, files named by numeric id only.
"""
import json
import math
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

LEAGUE_URL = "https://www.ea.com/games/ea-sports-fc/ratings/leagues-ratings/1a-pro-league/4"
LEAGUE_GROUP_ID = 4  # "1A Pro League" in the site's team filter
IMAGE_HOSTS = {"drop-assets.ea.com", "ratings-images-prod.pulse.ea.com"}
PAGE_DELAY = 2.0
IMAGE_DELAY = 0.25
MAX_IMAGE = 2 * 1024 * 1024
UA = "Mozilla/5.0 (personal FIFA 96 remake; one-off download)"


def get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def next_data(html: str) -> dict:
    m = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', html, re.S)
    if not m:
        raise ValueError("no __NEXT_DATA__ in page")
    return json.loads(m.group(1))["props"]["pageProps"]


def fetch_image(url: str, path: str) -> bool:
    if os.path.exists(path):
        return False
    host = urllib.parse.urlparse(url).hostname
    if host not in IMAGE_HOSTS:
        print("  skipped (unexpected host):", host)
        return False
    try:
        data = get(url)
    except urllib.error.HTTPError as e:  # some players have no portrait
        print(f"  skipped (HTTP {e.code}):", path)
        return False
    if not data.startswith(b"\x89PNG\r\n\x1a\n") or len(data) > MAX_IMAGE:
        print("  skipped (not a PNG or too big):", path)
        return False
    with open(path, "wb") as f:
        f.write(data)
    time.sleep(IMAGE_DELAY)
    return True


def main(out: str) -> None:
    os.makedirs(os.path.join(out, "pages"), exist_ok=True)
    os.makedirs(os.path.join(out, "crests"), exist_ok=True)
    os.makedirs(os.path.join(out, "portraits"), exist_ok=True)

    players: dict[int, dict] = {}
    crests: dict[int, str] = {}
    page, pages = 1, 1
    while page <= pages:
        path = os.path.join(out, "pages", f"league_p{page}.html")
        if not os.path.exists(path):
            html = get(f"{LEAGUE_URL}?page={page}").decode("utf-8")
            with open(path, "w", encoding="utf-8") as f:
                f.write(html)
            time.sleep(PAGE_DELAY)
        pp = next_data(open(path, encoding="utf-8").read())
        entries = pp["ratingsEntries"]
        pages = math.ceil(entries["totalItems"] / max(1, len(entries["items"]))) if page == 1 else pages
        for p in entries["items"]:
            players[int(p["id"])] = p
        for g in pp["ratingsFilters"]["teamGroups"]:
            if str(g["id"]) == str(LEAGUE_GROUP_ID):
                crests = {int(t["id"]): t["imageUrl"] for t in g["teams"]}
        print(f"page {page}/{pages}: {len(players)} players so far")
        page += 1
    total = entries["totalItems"]
    if len(players) != total:
        print(f"warning: {len(players)} players collected, site says {total}")

    with open(os.path.join(out, "players.json"), "w", encoding="utf-8") as f:
        json.dump(sorted(players.values(), key=lambda p: (p["team"]["id"], -p["overallRating"])), f, ensure_ascii=False)

    new = sum(fetch_image(url, os.path.join(out, "crests", f"{tid}.png")) for tid, url in crests.items())
    print(f"crests: {len(crests)} ({new} new)")
    new = 0
    for i, (pid, p) in enumerate(players.items()):
        if p.get("avatarUrl"):
            new += fetch_image(p["avatarUrl"], os.path.join(out, "portraits", f"{pid}.png"))
        if i % 50 == 0:
            print(f"portraits: {i}/{len(players)}")
    print(f"portraits: {len(players)} players ({new} new)")


if __name__ == "__main__":
    main(sys.argv[1])
