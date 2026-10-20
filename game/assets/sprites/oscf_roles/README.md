# OSCF referee and effects — brief items 9–16

Original artwork generated with the built-in image-generation tool, using the
OSCF starter footballer as the referee's face/proportion reference. The referee
wears black with a white collar. Sources have real RGBA transparency, no ball,
background or baked ground shadow. Public prompts use body descriptions only.

## Ready-to-pack sheets

| File | Layout | Contents | Size |
| --- | --- | --- | --- |
| [effects.png](effects.png) | 4 columns × 5 rows | Impact burst, dust, yellow-card spin, red-card spin, whistle ring; 4 frames each | 1536×1280 |
| [referee_idle.png](referee_idle.png) | 5 columns × 2 rows | Idle/breathing, 2 frames per direction | 1536×512 |
| [referee_run.png](referee_run.png) | 5 columns × 5 rows | Run, 5 frames per direction | 1536×1280 |
| [referee_whistle.png](referee_whistle.png) | 3 columns × 4 rows | Raise whistle, blow and signal stop | 1536×1024 |
| [referee_card.png](referee_card.png) | 3 columns × 4 rows | Reach pocket, draw, raise, show card | 1536×1024 |
| [referee_point.png](referee_point.png) | 3 columns × 3 rows | Prepare, extend arm, point | 1536×768 |

**88 poses total: 68 referee poses and 20 effects frames.**

For referee sheets, columns are directions and rows are successive frames:

- Idle/run: **N, NE, E, SE, S**, matching the starter pack.
- Whistle/card/point: **NE, E, SE**. Mirror horizontally for opposite directions;
  pure north/south use the nearest view if needed.

For `effects.png`, rows from top to bottom are **impact burst, dust puff,
yellow card spin, red card spin, whistle ring**. Columns are animation frames 1–4.
The ring centres are transparent. The last burst, dust and ring frames break apart.

## Packing and event markers

All final rows are exactly 256 pixels high. Referee feet use an anchor at row-local
**y=240**, with roughly 180-pixel bodies and extra room for raised hands. Each
column anchor is its centre. Five columns across 1536 pixels are not an integer
cell width: **use the exact cell rectangles in `source_regions.json`** rather than
repeatedly truncating 1536/5. Three-column cells are 512 pixels wide; effects cells
are 384 pixels wide.

Suggested event frames (human numbering / zero-based JSON index):

| Animation | Frame | JSON index | Event |
| --- | ---: | ---: | --- |
| Whistle | 3 | 2 | Blow whistle / emit shockwave |
| Show card | 4 | 3 | Fully raised card |
| Point | 3 | 2 | Direction signal fully extended |

The visible green face of the held card is normalized to **#00FF00** for colour
replacement; preserve alpha when replacing it with yellow or red. Thin outline
and antialiased boundary pixels remain. Only the held-card sheet uses this marker.
The separate spinning-card effects are already yellow/red.

Suggested preview rates: idle 2 fps, run 10 fps, other referee actions 10 fps,
impact/dust 12 fps and other effects 10 fps. Only idle and run should loop. These
are art timings, not a live referee rules implementation.

The previous player moves remain in `brand/sprites/line_actions/`. Their contact
markers are in `CONTACT_FRAMES.md` and `manifest.json` there. Their accepted
side-view limitation has not changed.

## Sources and reproduction

- `*_prompt.txt`: generation recipes, including the separate fifth run phase and
  the card-layout correction. No external character or move names.
- `raw/`: original generated images used for preparation. **Do not pack the raw
  run sheet directly**: its clipped fifth row is unused. The complete fifth phase
  comes from `raw/referee_run_phase5.png` and is already included in the final sheet.
- `preparation.json`: measured raw crops, scales and row/column assignment.
- `source_regions.json`: final crops, cells, anchors, directions and event markers.

The layout preparation preserves the artwork, places frames on the requested grid,
normalizes size and makes the card's key green exact. Rebuild from the game folder:

```sh
godot --headless --path . -s res://tools/prepare_oscf_referee_sources.gd
```

These are ready-to-pack sources; they do not replace the live match referee or
implement new referee behaviour. Run continuity and hand/foot alignment still
benefit from review at the eventual in-game size.
