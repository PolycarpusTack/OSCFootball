# FIFA 96 (PC CD-ROM, EA Sports 1995): deconstruction notes

Source: `FIFA96.ISO` (ISO 9660, volume `FIFAPCCD`, 807 files, 454 MB, Oct 1995 build).
Everything below was checked against the actual files unless it is marked **ASSUMED**.

## Layout

```
extracted/   raw ISO contents (7z x FIFA96.ISO -oextracted)
decoded/     everything converted to PNG / WAV / MP4 / CSV / TSV
  images/    4,216 PNGs (menus, stadiums, pitch, player animations, fonts are not rendered)
  audio/     18,492 WAVs (Motson/Hill commentary, crowd chants, SFX, 15 music cues)
  video/     73 MP4s (FMV clips, upscaled 4x from 160x120)
  text/      LANG000-005.tsv: the 591 UI strings for each of the 6 languages
  data/      players.csv (3,615), teams.csv (242)
  raw/       undecoded game data from the PVI archives (formations, animation tables)
  exe/       fifa96.asm (full annotated disassembly), functions.tsv, strings.tsv
tools/       Python decoders (run with tools/.venv/bin/python -I)
```

To regenerate: `tools/.venv/bin/python -I tools/extract_all.py extracted decoded` (about 10 minutes).

## File formats

| Ext | What it is | Decoder |
|---|---|---|
| `.VIV` `.PAR` | **BIGF** archive (EA's "big file"): big-endian header, `u32 offset, u32 size, cstring name` per entry | `eaformats.read_bigf` |
| `.POG` `.QFS` `.PVI` | Compressed containers. `.POG` = renamed `.FSH`/`.DAT` (the EXE string `.fsh.vsh.qfs.qvs` maps the extensions); `.PVI` = compressed BIGF | `EADecoders.unpack` |
| `.FSH` | **SHPI** shape container: `SHPI, u32 size, u32 count, dir id (GIMX/SPIT)`, then `name[4], u32 offset` per image. Image header: `u8 type, u24 next, u16 w, h, cx, cy, x, y`. Type `0x7B` = 8-bit indexed. A `0x22` palette (6-bit VGA) is chained or held in a `!pal` entry | `read_shpi` |
| `.FFN` / `FNTI` | Bitmap fonts. Identified only, not decoded | – |
| `.spc` (inside VIV/PAR) | **EACS** sample: `EACS, u32 rate, u8 width, u8 channels, u8 codec, u8 type, u32 samples, loop start, loop length, data offset`. Every speech file is 16 kHz mono with codec 2 = EA IMA ADPCM (no block header, predictor starts at 0, high nibble first) | `eacs_to_wav` |
| `.BNK` | Sound bank: 128 × u32 slot table, each slot → 72-byte patch record with EACS at +0x28 (data offset is file-absolute). Chants carry loop points | `read_bnk` |
| `.ASF` | Music: `1SNh/1SNd/1SNe` EA stream, 22 kHz stereo PCM | ffmpeg |
| `.TGV` | FMV: EA `kVGT` video, 160×120 pal8 @15 fps, 16 kHz 8-bit audio | ffmpeg |
| `.CRD` `CRDF`, `.ARA`, `PHR_*/ZZZZZZZZ.DAT` | Credits data, the autorun archive, phrase-assembly tables. Identified only | – |

### Compression (byte 0-1 = `xx FB`)
The game has one decompression dispatcher (EXE ~`0x9e74c`) that branches on the first byte:

- `0x10/0x11` **RefPack** (LZ77, the same as later EA titles). Some 1995 streams have no stop code, so output is truncated to the header size. Implemented natively.
- `0x30–0x35` **EA Huffman** → `sub_09c7e0(eax=src, edx=dst, ebx=1)`
- `0x46/0x47` **BTree** → `sub_09da14(eax=src, edx=dst)`

The player animation sprites in `PLAYART.PVI` are layered **Huffman → RefPack → BTree**. I could find no public spec for the Huffman and BTree codecs. Instead of reimplementing them, `tools/eahuff.py` runs the game's own x86 routines in the Unicorn CPU emulator.

### In-game palette
In-game art (sprites, pitch, stadium) has no palette of its own. It is drawn with `PALsys.fsh` from `GAMEART0.PVI`, where index 255 is transparent. Team kits are recoloured at runtime through `PALteam.fsh`, so the exported sprites all show the default kit (red/yellow shirt, blue shorts).

### Stadium textures (`GAMESTDn.PVI`, `GAMEART0.PVI`)
The stadium is real 3D geometry with mipmapped textures. Each texture comes in sizes ×1, ×2
and ×4, stored consecutively. The four `GAMESTDn.PVI` files are stadium variants. In
`GAMESTD1.PVI`:
- `STACcovr`: crowd terraces, 128×128 (largest), two tiers per tile, in three variants:
  plain, with a tunnel, with stairs.
- `STABcovr`: advertising boards, 128×16. There are 10 boards: TADAL, FIFA, SOCCER, TL73,
  FIFA '96, I.L.L., EA SPORTS, Virtual Stadium, DEMO, and one blank.
- `STARcovr`: a 64×128 roof/structure panel.
- `STAScovr`: a 194×87 stand-end piece with an EA SPORTS sign.

In `GAMEART0.PVI`:
- `STAFront`: the stand front wall, as a straight piece and a corner piece.
- `Net` and `Npost`: the goal net and posts.

How these pieces are laid out in FIFA 96 itself (presumably `3dwpts.dat`) is not decoded.
The Godot stadium arranges them by eye.

### Sound effect slots (`SFX_GAME.BNK`), ASSUMED
These are identified from spectra and envelopes, not by listening. The game code that
plays them hasn't been traced.

| Slots | Likely sound | Why |
|---|---|---|
| 029 (1.0 s), 030 (0.17 s) | referee's whistle, long and short | near-pure tones at 3.8–4 kHz |
| 001–003, 009, 011, 012, 019 | ball contacts | low thuds of 30–50 ms |
| 005 | crowd "ooh" | broadband noise that swells and fades over 2 s |
| 021 | crowd roar | holds for 5 s, then fades |
| 015 | crowd chant or reaction | broadband, 6.8 s |

## Database (`FEDATA/PCCD.POG` → `PCDB`)
See `tools/fifadb.py` for byte offsets. In short:
- **242 teams**, 137 bytes each: id, three name strings, 53 undecoded bytes (probably kit colours and team ratings), and a 16-entry roster of player indexes. Includes EA's hidden dev team **"As Designed"**.
- **3,615 players**, 36 bytes each: id, initial, surname, position G/D/M/F, shirt number, 16 ratings (0–15), overall (e.g. Klinsmann 98, Shearer 91), and two appearance digits.
- **ASSUMED:** the names of the 16 rating columns. They follow the order of the game's own attribute labels in `LANG000` (Skill, Speed, Aggress., Ball Cntrl, Power, Accuracy, Agility, Reaction, Headers, Slides, Stamina, Passing, Accel., Fitness, Aware., A. Touch). The values look plausible (goalkeepers score low on headers and slides) but the order is not confirmed from code.

## Executable
- `FIFA96.EXE`: DOS/4GW-bound Watcom C/C++32 program (internal name `FIFAPCCD`), in **LE** format. Gotcha: in the bound file the LE data-pages offset is relative to an *inner* MZ header at `0x26654`, not to the start of the file.
- 4 objects: code32 @`0x10000` (0xC1EA0 bytes), a small code16 stub, data32 @`0x100000`. 32,461 internal fixups are applied before disassembly.
- 2,674 functions (call targets) and 691 strings referenced from code. `functions.tsv` lists each function with the strings it uses, which is the fastest way to find a subsystem, e.g.:
  - `sub_04a6bc` / `sub_04a830` / `sub_04aae0`: load in-game art (`art/gameart0.pvi`, `gamefld%d`, `gamestd%d`, `playart.pvi`)
  - `sub_065ea0` / `sub_065e70`: speech banks (`PLR_0000.VIV`, `TEM_0000.VIV`)
  - `sub_01b1c8`: front-end menu screens (`mod*.fsh`)
  - `sub_063734`: FMV playback (`VIDEO/VID_%s.tgv`)
- Other executables: `INSTALL.EXE`/`INST.EXE` (installer, Watcom), `UNIVBE.EXE` and `CHKVESA.EXE` (SciTech VESA driver and VESA check, Borland C++), `AUTORUN.EXE` (Win32 PE).
- No debug symbols, so every function name beyond `sub_xxxxxx` has to be derived by hand.

## Not done yet
- FNTI font rendering, the 53 undecoded team bytes, the `.fmt` formation files, `3dwpts.dat` (pitch geometry), `Nanim*.dat` / `freekick.fmt`, the speech phrase tables, and gameplay logic (physics, AI, input) in the EXE.
