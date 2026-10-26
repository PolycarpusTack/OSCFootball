# Polish slices (after EPIC G), 2026-10-26

Feature work is paused (the user's decision, 2026-10-26). Two slices of polish follow, each
planned before it's built. Slice 2 gets its own plan when slice 1 is done.

## Slice 1 — Menus, fonts, commentary

> **Status 2026-10-26: DONE** (awaiting the user's review). P-1 … P-4 are in. Deviations (AS-P1 failed:
> two pixel fonts) and the retro: `state/phase-P1.md`.

Decided by the user:
- free fonts may be downloaded;
- a stylised pixel font for the Pixel edition ("think Minecraft");
- a stylised regular font for the 3D edition ("think RTWC98");
- commentary stays text for now, with many more lines:
  - serious ones: regular football commentary;
  - Chaos ones: over the top and ridiculous, the crowd's behaviour, players' weird behaviour.

| Story | AC |
|---|---|
| **P-1** Fonts | AC1: Pixel uses Pixelify Sans (OFL, `game/fonts/`); Rendered, which stands in for the 3D edition until it exists, uses Exo 2 Italic (OFL). AC2: the font follows the PLAYERS option at once, everywhere (`ThemeDB.fallback_font`, set by `UiText.apply_font`). AC3: each font's OFL licence ships next to it. AC4: no screen's text overflows in either font (screenshots of every screen) |
| **P-2** Menu audit and fixes | AC1: a screenshot of every menu screen in both fonts, with a list of what's wrong (overflow, alignment, inconsistent sizes or colours, missing hints). AC2: those fixed; the list and the before / after go in the phase note |
| **P-3** Commentary, serious | AC1: the main keys (goals, shots, saves, fouls, cards, corners, half and full time) have at least 6 serious lines each. AC2: new "lull" lines in quiet open play (possession, tempo, the shape) |
| **P-4** Commentary, Chaos | AC1: each key can carry a `chaos` pool, used only in Chaos mode on top of the serious lines. AC2: lull lines in Chaos about the crowd and odd player behaviour. AC3: Classic mode never shows a Chaos line (`commentary_test`) |

Order: P-1, P-2 (the audit needs both fonts in), P-3, P-4.

Assumptions:
- AS-P1: Pixelify Sans stays readable down to the smallest text in use (13 px). If not, the
  pixel font is for headings only, and small text keeps a plainer face. Checked in P-1's
  screenshots.
- AS-P2: one weight per font is enough. Pixelify 700 and Exo 2 800 are a start.

## Slice 2 — The match engine for Pixel and 3D

> **Status 2026-10-26: DONE** (awaiting the user's review). S-0 … S-6 are in; S-7 wasn't needed
> (AS-S5 failed, and the sprint pose fixed it). ADR-005 accepted. Measurements, deviations and the
> retro: `state/phase-P2.md`.

Decided by the user:
- the match engine is polished for both editions: Pixel (FIFA 96's sprites, never committed)
  and 3D;
- free public-domain (CC0) models may be used, as they are or to learn movement from;
- there's no Mixamo; CMU mocap is a candidate for locomotion.

Known before planning (verified):
- The hardware is Intel UHD integrated graphics and 15 GB of RAM. The project already uses the
  Compatibility renderer (`renderer/rendering_method="gl_compatibility"`).
- The stadium is already 3D (`stadium.gd`): a Node3D in metres, seen through a side-on TV
  camera. The players, the referee and the ball are 2D sprites drawn on top, placed through
  `Stadium.to_screen()`.
- `Footballer.look()` is `[position, anim, time, loop, facing, chaos_rotation, chaos_lift,
  visible]`; `show_look()` draws one, and so does the live match, through `place()`. The replay
  (ADR-004) goes through the same calls.
- `tools/blender/footballer.py` is our own low-poly footballer: rigid parts parented to empties,
  no armature, with 49 poses written as code (run, jog, stand, kick, the keeper's dives, the
  specials…). It renders the Rendered sprites. The game knows 82 animations of FIFA 96's (and the
  referee's 5); 41 of them are drawn only in FIFA 96's art.
- A "3D edition" doesn't exist yet. The Rendered option stands in for it in the fonts (slice 1).

### ADR-005 The 3D edition's render layer

| | |
|---|---|
| Decision | The simulation stays in 2D pitch pixels, untouched. Each Footballer gets a 3D puppet in the Stadium's world, posed in `place()` and `show_look()` from the same look. The ball gets one in `Ball.place()` / `show_look()`. The model is our Blender footballer, exported to glTF with its 49 animations. The TV camera is the same one as the 2D editions |
| Alternatives | (a) A real 3D simulation (physics in 3D, the camera free): months, and both editions would play differently. (b) A pre-rendered sprite set with more directions: that's the Rendered edition already. (c) A CC0 skinned model: more human, but our 49 poses would have to be redone on its rig, and its kit wouldn't take the kit colours without work |
| Why | The match plays the same in all three editions, so tests, AI and replays stay valid. The puppet only draws |
| Status | **ACCEPTED** 2026-10-26 (S-0): 23 bodies and a shadow cost 2 ms a frame on this machine; at the end of the slice, 3D's median frame is 5.7–8.9 ms against Pixel's 2.5–2.9 (budget 16.7) |

The PLAYERS option becomes PIXEL → RENDERED → 3D. `Match.rendered` stays as it is and is true
in 3D too (the Rendered font, and Rendered art for anything still drawn in 2D). A new
`Match.solid` says the puppets are drawn.

### Assumptions

| # | Assumption | Impact | Check |
|---|---|---|---|
| AS-S1 | 23 puppets (about 40 rigid parts each), the ball and the stadium run at 60 fps at 1280×720 on this Intel UHD, in the Compatibility renderer, with one directional shadow | **High**: no 3D edition without it | S-0 measures it. If not: merge each player's parts into one skinned mesh (one draw call per material) |
| AS-S2 | Blender 4.0's glTF exporter keeps object (empty) animation, so the rigid rig needs no armature | High | S-0 |
| AS-S3 | Our 49 poses cover what play shows most of the time; the other 41 can map to the nearest of them | Med | S-4 counts the time each animation is on screen in an autoplay match |
| AS-S4 | The footage audit (S-1) finds the 2D editions' faults; a fault that can't be seen in 30 fps captures isn't in scope | Med | S-1 |
| AS-S5 | Playback speed scaled to the player's speed is enough to stop the run's foot slide; no mocap is needed | Med | S-5 frame captures. If not, S-7 (CMU) is the fallback |

### Stories

| Story | AC |
|---|---|
| **S-0** ST0 spike (AS-S1, AS-S2) | AC1: `run` and `stand` exported from the Blender footballer to a .glb, imported by Godot. AC2: 23 of them on the pitch under the TV camera, running; frame time measured on this machine and written in the phase note. AC3: ADR-005 accepted, or changed with the reason |
| **S-1** Footage audit, both 2D editions | AC1: a 60 s autoplay match captured in Pixel and in Rendered (Godot's movie mode). AC2: a list of what looks wrong, each with its time code and a still: foot slide, facing jitter, draw order, the ball's shadow and height, scale, the camera. AC3: the list ranked and in the phase note |
| **S-2** 2D fixes | AC1: the top items from S-1 fixed, each with a test where it can be measured (e.g. the run's step rate against speed). AC2: before and after stills in the phase note. AC3: the full suite passes |
| **S-3** The 3D model | AC1: `tools/blender/footballer_gltf.py` exports the footballer with all 49 animations to `game/assets/models/footballer.glb` (ours, no third-party art). AC2: the kit colours on the model: a spatial kit shader per slot, the shirt's stripes as on the sprites, skin and hair from the player. AC3: the keeper's kit and the referee's |
| **S-4** 3D in the match | AC1: PLAYERS cycles PIXEL, RENDERED, 3D in the options and the pause menu. AC2: in 3D every player, the referee and the ball are puppets; the 2D sprites are hidden; the rings, names and markers stay. AC3: facing turns smoothly between the 8 directions. AC4: the 41 animations without a pose map to the nearest one (a table, checked by a test: every name the game plays has a pose). AC5: replays and highlights play in 3D. AC6: the giant players modifier and the Chaos lift and spin show |
| **S-5** 3D movement polish | AC1: the run and jog play at a rate that matches the player's speed (no foot slide in captures). AC2: animations blend into each other (no snapping from run to kick). AC3: the ball's spin and shadow in 3D |
| **S-6** 3D look | AC1: one directional light with shadows, inside AS-S1's budget. AC2: the stadium and players under the same light. AC3: stills of a match in all three editions in the phase note |
| **S-7** (fallback, only if AS-S5 fails) CMU locomotion | AC1: one CMU run cycle retargeted to the rig's joints and compared in captures with ours; the better one stays. CMU's terms (free use, credit asked) in `assets/models/README.md` |

Order: S-0, then S-1 and S-3 (independent), S-2, S-4, S-5, S-6. S-7 only on AS-S5's failure.

Out of scope: a new camera, new animations beyond the 49, the crowd in 3D, and any change to how
the match plays.

