# FIFA 96 Bananas (Godot 4.7)

A new football game built on the original FIFA 96 assets. Personal project: the art,
audio and data belong to EA, so don't distribute it with them.

Current state: **Club Brugge (you) vs Anderlecht (AI)**, 11 a side, 4-4-2, two halves,
in FIFA 96's 3D "Virtual Stadium" (original crowd, advertising boards, nets) seen from a
side-on TV camera. Boots like the original: intro FMV (any key skips), title screen with
the title music, Space to kick off.

## Run

```
godot --path game              # play (intro, title, match)
godot --path game res://scenes/main.tscn   # straight to the match
godot --editor --path game     # open in the Godot editor
godot --headless --path game -s res://tests/smoke_test.gd                        # match smoke test
godot --path game -s res://tests/demo.gd --write-movie demo.avi --fixed-fps 30 -- seed=2   # record the demo reel
godot --path game -s res://tests/supers_demo.gd --write-movie supers.avi --fixed-fps 30 -- seed=2   # super-shot reel
```

| Key | Action |
|---|---|
| WASD / arrows | move (you control the Brugge player nearest the ball, ringed in yellow) |
| Space | with the ball: shoot on release, hold for power (aims at goal when you face it). Without: slide tackle |
| ↓ ↘ → then Space | **Fireball** (50 energy): flat rocket, bowls over anyone in the way |
| ← → then Space | **Banana Shot** (50): bends hard toward the far post |
| hold Space 0.8 s, full bar | **Thunder Strike** (100): bicycle kick, slow-mo, lightning ball that nobody can hold |
| Up/Down while taking a penalty | choose the corner |
| X or K | pass to the best teammate in the direction you're pushing |
| X / Space at a throw-in, corner or goal kick | take it (aim with the stick) |
| Space at full time | back to the title screen |
| F1 | animation viewer |

## Layout

```
scripts/main.gd           Match: teams, possession, tackles, fouls, penalties, restarts, halves, control switching, goals, kick-offs, sound, HUD
scripts/stadium.gd        3D pitch, boards, stands and goals from the original textures; TV camera; pitch-to-screen projection
scripts/title.gd          boot sequence: intro FMV, title screen, title music
scripts/ai.gd             AI decisions: hold formation (shifts with the ball), chase, dribble, pass, shoot, goalkeeping
scripts/team.gd           Team: name, kits, 4-4-2 formation, pitch-side helpers; Club Brugge / Anderlecht definitions
scripts/footballer.gd     a player's body: movement, animation, carrying the ball, kick/pass/shoot/slide
scripts/ball.gd           ball with height, bounce, friction, holder (dribbler); super-shot flight and trails
scripts/supers.gd         super-shot table (cost, animation, speed, colour) and energy rewards
scripts/combo_input.gd    fighting-game input buffer; directions relative to the goal you attack
scripts/kit.gdshader      recolours kit parts of the original palette-indexed sprites
scripts/anim_library.gd   autoload "Anims": all player animations, frame lookup by facing (8 dirs)
scripts/pitch.gd          grass from the original texture, markings to real dimensions (18 px/m), baked into the 3D pitch's texture
scripts/anim_viewer.gd    browse the 81 animations
data/squads.json          optional real squads (see below)
```

## How it's drawn

The match is simulated in 2D, in pitch pixels (18 px per metre) with a height for the
ball, as before. `Stadium` builds the ground and stadium in 3D (metres) and follows the
ball with a camera placed like FIFA 96's default TV view. Each frame the match projects every
player and the ball through that camera (`Stadium.to_screen`) and draws the original
sprites there, scaled for distance and sorted by depth, the way FIFA 96 put its sprites
into its 3D stadium. Camera height and distance are `CAM_OFFSET` / `CAM_FOV` in `stadium.gd`.

## Kits

Sprites keep FIFA 96's palette indices. `kit.gdshader` recolours five slots (shirt,
shirt second colour, shorts, socks, boots); kit colours are set in `Team.club_brugge()` /
`Team.anderlecht()`. The index-to-slot mapping is in `tools/build_godot_assets.py`
(`KIT_SLOTS`), found by where each index appears on the body.

## Real squads

Create `data/squads.json`; players are assigned in formation order
(GK, RB, CB, CB, LB, RM, CM, CM, LM, ST, ST). Without the file players are numbered.

```json
{
  "Club Brugge": [{"name": "Keeper Name", "number": 1}, ...11 entries],
  "Anderlecht":  [{"name": "...", "number": 1}, ...]
}
```

## Rebuilding the assets

```
tools/.venv/bin/python -I tools/build_godot_assets.py extracted decoded game
```

## Rules as implemented

- Two halves of `HALF_SECONDS` (180 s of play; the clock shows match minutes). Ends change
  at half time; at full time the winners celebrate.
- Ball over a touchline: throw-in to the other side. Over a goal line: corner if the
  defenders touched it last, otherwise a goal kick (taken by the keeper). Opponents stay
  9.15 m back until it's taken, and out of the penalty area at a goal kick; the AI takes
  it after a short pause.
- A slide tackle wins the ball, unless it comes from behind: that's a foul. A foul in the
  box gives a penalty (keeper guesses a side and dives); elsewhere the fouled side keeps the ball.
- Keepers catch shots within reach and dive (original low/high dive animations) for shots
  heading past them.
- `tests/demo.gd` stages three situations (Brugge attack, Anderlecht attack, foul in the box)
  and lets the AI play them out; `seed=2` gives a save, a goal and a scored penalty.

## Energy and super-shots

Each team has a bar (top left, 0-100; the tick marks 50). It fills from completed passes
(+6), tackles (+10), saves (+15), being fouled (+20), conceding (+25) and dribbling
(+2.5/s). Combo directions are relative to the goal you attack, so ↓↘→ works on both
wings; ↑↗→ is accepted too. The AI spends its bar on shots inside shooting range.
`tests/supers_demo.gd` stages one of each (`seed=2`: three goals, `supers_demo.mp4`).

## Known simplifications

- No free kicks, cards or offside; no headers or volleys from crosses (a corner just drops
  into the box).
- No player-vs-player collision; goal posts and net don't stop the ball. Sprites are
  always drawn over the 3D scene, so a post never hides a player.
- Sound effects are matched to their use by their spectra, not by ear (`SFX` in `main.gd`:
  kicks, bounce, whistles, crowd "ooh" and roar). No commentary yet: the speech banks
  are decoded but which phrase is which isn't known.
- Match length, camera framing and the AI's shot accuracy are guesses, not FIFA 96's values.
- Frame timing assumes a 30 ticks/s clock (`TICKS_PER_SECOND` in `anim_library.gd`).
