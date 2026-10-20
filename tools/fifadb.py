"""FIFA 96 player/team database (FEDATA/PCCD.POG after RefPack, magic 'PCDB').

Layout (little-endian), offsets verified against the CD's data:
  0x0000  'PCDB', u32 header fields
  0x0884  team array, 137-byte records, up to 0x8A06
  0x8A06  u32 player record size (36), u32 player count (3615)
  0x8A0E  player array, 36-byte records
  0x2866A string pool (NUL-terminated, code page 437)

Team record (137 bytes):
  +0  u32 team id
  +4  u32 name, +8 u32 short name, +12 u32 display name   (string pool offsets)
  +16 53 bytes, not yet decoded (ratings, kit colours, formation ...)
  +69 u32 roster size, +73 u32[16] player indexes (into the player array)

Player record (36 bytes):
  +0  u32 player id          +4  first-name initial (ASCII)
  +5  u24 surname offset     +8  u8 (unknown, usually 0)
  +9  position letter G/D/M/F
  +10 u8 shirt number
  +11 16 x u8 ratings (0-15); names below are ASSUMED, taken in order
      from the game's own attribute labels in LANG000
  +27 u8 overall rating
  +28 2 ASCII digits (appearance codes, ASSUMED: skin / hair)
  +30 6 bytes, not yet decoded
"""
import struct

TEAM_START, TEAM_END, TEAM_SIZE = 0x884, 0x8A06, 137
PLAYER_HDR, STRINGS = 0x8A06, 0x2866A
RATINGS = ["skill", "speed", "aggression", "ball_control", "shot_power", "shot_accuracy", "agility",
           "reaction", "headers", "slides", "stamina", "passing", "acceleration", "fitness",
           "awareness", "first_touch"]


def _str(d, off):
    end = d.index(b"\0", STRINGS + off)
    return d[STRINGS + off:end].decode("cp437")


def read_players(d):
    size, count = struct.unpack_from("<II", d, PLAYER_HDR)
    out = []
    for i in range(count):
        r = d[PLAYER_HDR + 8 + i * size:PLAYER_HDR + 8 + (i + 1) * size]
        p = dict(index=i, id=struct.unpack_from("<I", r)[0], initial=chr(r[4]),
                 surname=_str(d, r[5] | r[6] << 8 | r[7] << 16), position=chr(r[9]), number=r[10],
                 overall=r[27], appearance=r[28:30].decode("latin-1"), unknown=r[30:].hex())
        p.update(zip(RATINGS, r[11:27]))
        out.append(p)
    return out


def read_teams(d):
    out = []
    for a in range(TEAM_START, TEAM_END - TEAM_SIZE + 1, TEAM_SIZE):
        tid, n1, n2, n3 = struct.unpack_from("<4I", d, a)
        n = struct.unpack_from("<I", d, a + 69)[0]
        out.append(dict(id=tid, name=_str(d, n1), short=_str(d, n2), display=_str(d, n3),
                        unknown=d[a + 16:a + 69].hex(), roster=list(struct.unpack_from("<%dI" % n, d, a + 73))))
    return out
