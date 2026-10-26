# Phase summary: polish slice 2 (the match engine for Pixel and 3D), 2026-10-26

Branch `feature/A-cup`, on top of slice 1 (`c1d6861`). Nothing has been committed yet.

## What was built

| Story | Files | Test |
|---|---|---|
| S-0 Spike | (throwaway) 23 glTF bodies over a live match | frame times below |
| S-1 Footage audit | (throwaway) `tests/zz_audit.gd`: 60 s of autoplay in Pixel and in Rendered, captured with Godot's movie mode; per player and frame: speed, animation, facing | the numbers below |
| S-2 2D fixes | `footballer.gd`: `GAITS`, `GAIT_FLOORS`, `GAIT_BAND`, `GAIT_MIN`, `GAIT_PACE`, `GAIT_RATE`; `_locomotion_anim()` holds a gait past its floor and for at least 0.3 s; `_play()` keeps the cycle's place from one gait to another; `_pace()`. `anim_library.gd`: `facing_from(v, held)`, `FACING_HOLD` | `gait_test` (NEW) |
| S-3 The 3D model | `tools/blender/footballer_gltf.py` (NEW) → `game/assets/models/footballer.glb`: the 49 poses and a 3D-only `sprint`. `footballer.py`: `main()` behind `__main__` so it can be imported (renders unchanged: 30 of 30 frames identical, pixel for pixel). `scripts/kit3d.gdshader` (NEW) | `solid_test` (NEW) |
| S-4 3D in the match | `puppet.gd` (NEW, `Puppet`): posed from `Footballer.look()`, its kit from the kit material, `NEAREST` for the 41 FIFA 96 animations without a pose. `main.gd`: `solid`, `PLAYER_ART`, `player_art()`, `set_player_art()`, `_make_puppets()`. `footballer.gd`: `puppet`, `make_puppet()`, `drop_puppet()`, `pose_puppet()`. `ball.gd`: a 3D ball (`ball3d.gdshader`, NEW) that rolls. The options and the pause menu cycle PIXEL, RENDERED, 3D | `solid_test` |
| S-5 3D movement | `puppet.gd`: `GAITS`, `STRIDE`: the run and jog go on by the ground covered; `BLEND` between animations | `solid_test` |
| S-6 3D look | `stadium.gd` `light_bodies()`: a light from the sprites' light direction, and a sheet over the grass (`shadow_sheet.gdshader`, NEW) that darkens it in the bodies' shadows; the 2D blob shadows give way in 3D | stills |

## S-0 spike: AS-S1 and AS-S2 hold, ADR-005 accepted

Measured on this machine (Intel UHD, CML GT2, Mesa 25.2, Compatibility renderer), 1280×720,
vsync off, 4 s each:

| What | Frame time |
|---|---|
| The match as it is | 3.25 ms (308 fps) |
| + 23 glTF bodies, animated | 4.80 ms (208 fps) |
| + a directional light with shadows | 5.30 ms (189 fps) |

The budget is 16.7 ms. The worst single frames (22–26 ms) are there without the bodies too.

**At the end of the slice** the full 3D edition (posing, blending, the light, the shadow sheet)
costs more than the spike's bodies did. The machine was short of memory by then (swap full),
so means swung from 11 to 18 ms for the same setting; medians of 6 s, Pixel and 3D alternating:

| | Median frame | 95th percentile |
|---|---|---|
| Pixel | 2.5–2.9 ms | 5.5–12.6 ms |
| 3D | 5.7–8.9 ms | 11.6–21.7 ms |

Posing the 23 bodies is about 1.5 ms of that (CPU). AS-S1 still holds at the median, with less
room than the spike showed; one 3D run's 95th percentile went over 16.7 ms on the loaded machine.
Worth measuring again on a quiet machine.

- AS-S2: Blender 4.0's exporter keeps object animation: no armature needed. It drops a joint
  that doesn't move in an animation, even with optimisation off, so `Puppet` keys those joints
  at rest when it loads (else a joint keeps the last animation's angle).
- The glb is 21 meshes a player, not ~40 parts as assumed.

## S-1 audit: what was wrong

The stills (positions, draw order, shadows, ball, scale) showed nothing wrong. The faults are in
the motion, and they're measured:

| Fault | Pixel | Rendered | After S-2 (Pixel) |
|---|---|---|---|
| A gait switched and back within 0.2 s (run, jog, walk, stand), the cycle starting over each time | 37.9 a player-minute | 27.5 | **0** |
| Facing switched and back within 0.2 s | 10.5 a player-minute | 8.6 | **4.1** |
| Run, jog and walk at one pace (1.07 s a cycle) for every speed: run 120–191 px/s, jog 50–120, walk 5–50 | | | the pace follows the speed, 0.6× to 1.6× of the typical speed |

Most of the gait flicker was jog ↔ walk around 50 px/s: dips in speed on a turn. A speed band
alone cut it to 21.5 a player-minute; a minimum of 0.3 s in a gait took it to 0.

## Deviations from the plan (for your review)

- **AS-S5 failed for the run, as the plan feared.** The model's run moves its planted foot back at
  2.4 m/s; players run at about 9 m/s. Played faster to match, the legs would go 7 steps a second.
  So the 3D model has its own **sprint** (longer swing, off the ground between steps; in
  `footballer_gltf.py` only, the sprites keep theirs), and its cycle goes on by **distance**, not
  time: 3.5 steps a second at full speed. S-7 (CMU mocap) isn't needed for this.
- **The 2D pace is relative, not foot-exact.** FIFA 96's run is drawn for its own pace; at the
  typical speed in play it plays as drawn (rate 1), slower and faster around it. Foot-exact in 2D
  would make the Pixel run look unlike FIFA 96's.
- **The model has 49 poses, not 50** (my count included a line of code); 50 with the sprint.
- **The shadows in 3D** fall on a sheet over the grass, since the stadium is unshaded (it would
  look different in the other editions if it were lit). `shadow_to_opacity`, Godot's own way to
  do that, showed nothing in the Compatibility renderer; the sheet multiplies by its own light
  pass instead. The 2D blob shadows are off in 3D.
- **The light is fixed** (direction from the sprites' light), not a time of day.
- **S-7 (CMU mocap) wasn't needed**, so not done; the sprint is our own pose.
- **41 FIFA 96 animations have no pose** (keeper holds and get-ups, injuries, trophy, the
  referee's): each shows its nearest pose (`Puppet.NEAREST`). New poses are out of scope.
- **A player subbed off has no body**; a replay from before the sub draws his sprite.
- **The Rendered sprites aren't re-rendered.** Nothing in `footballer.py`'s poses changed.

## Stills

`docs` has no image store; stills of all three editions were taken (Pixel and Rendered from
the audit captures, 3D lit and unlit) and checked by eye: the bodies in their kits (Brugge's
stripes), the referee in black, the ball's patches, the sprint's stride, the shadows to the
right and away from the camera.

## Retro

- **Full suite: 45 of 45 pass** (a clean run after the last change). New: `gait_test`, `solid_test`.
- **Rework:**
  - My spike script named `Footballer`, `Pitch` and `Anims`, so it hung at parse time, with no
    output: Godot loses its output when `timeout` kills it. `stdbuf -o0` shows it. Then a
    headless `save_png` hung it too (no texture under the dummy renderer).
  - The exporter drops joints that don't move in an animation, whatever the options; the
    puppet keys them at rest.
  - A speed band alone left 21.5 gait flickers a player-minute; jog ↔ walk dips on turns need
    the 0.3 s minimum.
  - `referee_art_test` set four speeds with no time between them; the minimum gait time held
    the first. It now starts each speed fresh. `rendered_test` pressed PLAYERS expecting a two-way
    toggle; it goes through 3D now.
  - I edited code while the suite ran, twice, so those runs mixed old and new code. Rerun in full.
  - `pkill -f` and `pgrep -f` match their own command line, as before.
- **TD:**
  - TD-S1: the 2D facing still flickers 4.1 times a player-minute (from the `wish` path and
    kicks, which set it directly). A wider `FACING_HOLD` would cut it further.
  - TD-S2: `Puppet.NEAREST` shows a keeper holding the ball as `gmdctch`, a get-up as standing,
    and the referee's gestures as standing. New poses would fix it; out of scope.

## After your playtest, 2026-10-26

| You reported | Cause | Fix | Test |
|---|---|---|---|
| The ball sometimes glued to the keeper's feet: no pass or shot, run the length of the pitch, walk it in | `Match.keeper_may_release()` held any keeper with the ball until opponents were 9.15 m away or 6 s had passed, but the 6 s count reset to 0 every frame out of his box; and nobody could tackle a keeper, anywhere | `Match.keeper_holds()`: the hold, the 6 s and the no-challenge rule apply only with the ball in his hands in his own box. Out of it, it's at his feet as anyone's | `rules_test`: out of his box, opponent alongside: he passes at once (0.17 s) and is tackled (0.2 s); in it, as before (6.2 s) |
| 3D players very pale | The ambient light was the sky-blue background's, on top of the sun: colours came out about 1.4× (the sprites about 1.2×), and light skin clipped to white | Ambient set neutral (`Stadium.AMBIENT` 0.25), sun 0.6 (`SUN_ENERGY`), the kit shader matte | stills: the away shirt shows at its own colour; skin keeps its hue |
| Indoors looks like a pitch | Only the size, the board distance and the camera changed | Indoors: an even turf carpet with no stripes, concrete outside the walls (`Pitch.CARPET`, `CONCRETE`); perspex in a frame above the boards; a low hall stand in front of the hall's dark walls, a lamp gantry over it (`Stadium._build_roof`); a dark hall where outdoors there's sky | stills, Pixel and 3D |

- The roof itself never shows: the TV camera looks down from below it. The lamps hang lower, over
  the stands, where it does see.
- Noted, not changed: the 3D players are smaller on screen than the sprites (FIFA 96's sprites
  are larger than life) and have no outline.
- Suite after these fixes: 44 of 45 in the paired run. `chaos_actions_test` failed once on "AI
  dives near goal" (a random 50-try check of a move the AI takes only sometimes; the diver is an
  outfield player, untouched by the keeper fix) and passed three times alone. TD-S3: worth seeding.
