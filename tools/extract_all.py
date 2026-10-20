"""Decode every asset on the FIFA 96 CD into standard formats.

Usage: extract_all.py <extracted_iso_dir> <out_dir>

  images/  PNG for every SHPI shape (.POG .QFS .FSH, and shapes inside .PVI archives)
  audio/   WAV for speech (.VIV/.PAR), banks (.BNK) and music (.ASF, via ffmpeg)
  video/   MP4 for every .TGV movie (via ffmpeg)
  text/    language string tables as TSV, install readmes
  data/    players.csv, teams.csv
"""
import csv
import os
import subprocess
import sys
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fifadb  # noqa: E402
from eaformats import (eacs_to_wav, read_bigf, read_bnk, read_shpi,  # noqa: E402
                       shpi_image_to_pil)
from eahuff import EADecoders  # noqa: E402

errors = []


def log_error(what):
    errors.append(what + "\n" + traceback.format_exc())


def inside(dest, name):
    """dest/name, refusing archive entry names that would land outside dest."""
    path = os.path.normpath(os.path.join(dest, name))
    if os.path.isabs(name) or os.path.commonpath([os.path.normpath(dest), path]) != os.path.normpath(dest):
        raise ValueError("archive entry outside the output folder: %r" % name)
    return path


def save_shapes(data, dest, palette=None):
    """Write each image of an SHPI container. In-game art carries no palette of its
    own; it is drawn with the shared PALsys palette, index 255 transparent."""
    _, images = read_shpi(data)
    os.makedirs(dest, exist_ok=True)
    seen = {}
    for i, img in enumerate(images):
        borrowed = img["kind"] == 0x7B and not img["palette"]
        if borrowed:
            img["palette"] = palette
        pil = shpi_image_to_pil(img)
        if pil is None:
            continue
        if borrowed:
            pil.info["transparency"] = 255
        name = img["name"].strip().replace("/", "_").replace("\0", "") or "img"
        seen[name] = seen.get(name, -1) + 1
        pil.save(os.path.join(dest, "%03d_%s%s.png" % (i, name, "_%d" % seen[name] if seen[name] else "")))


def images(src, out, dec):
    game_art = dict(read_bigf(dec.unpack(open(os.path.join(src, "ART/GAMEART0.PVI"), "rb").read())))
    palette = read_shpi(dec.unpack(game_art["PALsys.fsh"]))[1][0]["palette"]
    for root, _, files in os.walk(src):
        for f in sorted(files):
            ext = f.rsplit(".", 1)[-1].upper()
            if ext not in ("POG", "QFS", "FSH", "PVI"):
                continue
            path = os.path.join(root, f)
            rel = os.path.relpath(path, src)
            try:
                data = dec.unpack(open(path, "rb").read())
                if data[:4] == b"SHPI":
                    save_shapes(data, os.path.join(out, "images", rel), palette)
                elif data[:4] == b"BIGF":
                    for name, blob in read_bigf(data):
                        inner = dec.unpack(blob)
                        if inner[:4] == b"SHPI":
                            save_shapes(inner, inside(os.path.join(out, "images", rel), name), palette)
                        else:
                            raw = os.path.join(out, "raw", rel)
                            os.makedirs(raw, exist_ok=True)
                            open(inside(raw, name), "wb").write(inner)
            except Exception:
                log_error(rel)


def audio(src, out):
    snd = os.path.join(src, "SOUND")
    for f in sorted(os.listdir(snd)):
        path = os.path.join(snd, f)
        ext = f.rsplit(".", 1)[-1].upper()
        try:
            if ext in ("VIV", "PAR"):
                dest = os.path.join(out, "audio", f)
                os.makedirs(dest, exist_ok=True)
                for name, blob in read_bigf(open(path, "rb").read()):
                    if blob[:4] == b"EACS":
                        open(inside(dest, name.rsplit(".", 1)[0] + ".wav"), "wb").write(eacs_to_wav(blob))
                    else:
                        open(inside(dest, name), "wb").write(blob)
            elif ext == "BNK":
                dest = os.path.join(out, "audio", f)
                os.makedirs(dest, exist_ok=True)
                data = open(path, "rb").read()
                for slot, pos in read_bnk(data):
                    open(os.path.join(dest, "slot%03d.wav" % slot), "wb").write(eacs_to_wav(data, pos))
            elif ext == "ASF":
                dest = os.path.join(out, "audio", "music")
                os.makedirs(dest, exist_ok=True)
                ffmpeg(path, os.path.join(dest, f[:-4] + ".wav"))
        except Exception:
            log_error(f)


def video(src, out):
    vid = os.path.join(src, "VIDEO")
    dest = os.path.join(out, "video")
    os.makedirs(dest, exist_ok=True)
    for f in sorted(os.listdir(vid)):
        try:
            ffmpeg(os.path.join(vid, f), os.path.join(dest, f[:-4] + ".mp4"),
                   ["-vf", "scale=iw*4:ih*4:flags=neighbor", "-pix_fmt", "yuv420p"])
        except Exception:
            log_error(f)


def ffmpeg(src, dst, args=()):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src, *args, dst], check=True)


def text(src, out, dec):
    import struct
    dest = os.path.join(out, "text")
    os.makedirs(dest, exist_ok=True)
    for n in range(6):
        d = dec.unpack(open(os.path.join(src, "FEDATA/LANG%03d.POG" % n), "rb").read())
        count, pool = struct.unpack_from("<II", d, 4)
        offs = struct.unpack_from("<%dI" % count, d, 16)
        with open(os.path.join(dest, "LANG%03d.tsv" % n), "w", encoding="utf-8") as fh:
            for i, o in enumerate(offs):
                e = d.index(b"\0", pool + o)
                fh.write("%d\t%s\n" % (i, d[pool + o:e].decode("cp437").replace("\n", "\\n")))


def database(src, out, dec):
    d = dec.unpack(open(os.path.join(src, "FEDATA/PCCD.POG"), "rb").read())
    dest = os.path.join(out, "data")
    os.makedirs(dest, exist_ok=True)
    players = fifadb.read_players(d)
    teams = fifadb.read_teams(d)
    team_of = {}
    for t in teams:
        for p in t["roster"]:
            team_of.setdefault(p, t["name"])
    with open(os.path.join(dest, "players.csv"), "w", newline="", encoding="utf-8") as fh:
        cols = ["index", "id", "team", "initial", "surname", "position", "number", "overall"] + fifadb.RATINGS + ["appearance", "unknown"]
        w = csv.DictWriter(fh, cols)
        w.writeheader()
        for p in players:
            w.writerow(dict(p, team=team_of.get(p["index"], "")))
    with open(os.path.join(dest, "teams.csv"), "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["id", "name", "short", "display", "roster", "unknown"])
        for t in teams:
            w.writerow([t["id"], t["name"], t["short"], t["display"],
                        "; ".join("%s %s" % (players[i]["initial"], players[i]["surname"]) for i in t["roster"]), t["unknown"]])


def main(src, out):
    dec = EADecoders(os.path.join(src, "FIFA96.EXE"))
    for step in (lambda: database(src, out, dec), lambda: text(src, out, dec), lambda: images(src, out, dec),
                 lambda: audio(src, out), lambda: video(src, out)):
        step()
    report = os.path.join(out, "errors.txt")
    if errors:
        with open(report, "w") as fh:
            fh.write("\n".join(errors))
    elif os.path.exists(report):
        os.remove(report)  # left over from an earlier run
    print("done, %d errors" % len(errors))
    if errors:
        sys.exit("see " + report)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
