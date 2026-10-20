# FIFA 96 Bananas (Godot 4.7)

A new football game built on the original FIFA 96 assets. Personal project: the art,
audio and data belong to EA, so don't distribute it with them.

Current state: the 18 clubs of the **Jupiler Pro League** (`data/league.json`): pick player 1's
club and the opponent (AI, or player 2) on the team select screen. 11 a side, 4-4-2, two halves,
in FIFA 96's 3D "Virtual Stadium" (original crowd, advertising boards, nets) seen from a
side-on TV camera. Boots like the original: intro FMV (any key skips), title screen with
the title music, Space to kick off. Left/Right on the title screen picks **Chaos Football**
(energy bars and super-shots, the default) or **Classic Football** (plain FIFA 96 rules:
same players, ball and AI, no energy, combos are just shots). Up/Down picks 1 or 2 players.
Gamepads work on the title screen too (d-pad to choose, A/B/Start to go on). Then team select:
W/S picks player 1's club, ↑/↓ the opponent's, Space kicks off, Esc goes back.

## Run

```
godot --path game              # play (intro, title, match)
godot --path game res://scenes/main.tscn   # straight to the match
godot --editor --path game     # open in the Godot editor
godot --headless --path game -s res://tests/smoke_test.gd                        # match smoke test (Chaos)
godot --headless --path game -s res://tests/classic_test.gd                      # Classic: no energy, no supers
godot --headless --path game -s res://tests/two_player_test.gd                   # 2 players, gamepad stick
godot --headless --path game -s res://tests/teams_test.gd                        # league clubs load, kit clash
godot --path game -s res://tests/demo.gd --write-movie demo.avi --fixed-fps 30 -- seed=2   # record the demo reel
godot --path game -s res://tests/supers_demo.gd --write-movie supers.avi --fixed-fps 30 -- seed=2   # super-shot reel
godot --path game -s res://tests/two_player_demo.gd --write-movie 2p.avi --fixed-fps 30 -- seed=7   # 2-player reel (scripted controls)
```

| Key | Action |
|---|---|
| Left / Right on the title screen | Chaos or Classic Football |
| Up / Down on the title screen | 1 player (vs the AI) or 2 players (Brugge vs Anderlecht) |
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
| **2 players** | P1 (Brugge, yellow ring): WASD, Space shoot, X pass. P2 (Anderlecht, cyan ring): arrows, Enter shoot, Right Shift pass |
| **Gamepad** | left stick or d-pad: move, B: shoot (hold for power) / slide, A: pass. Alone: any pad is player 1's. Two players: one pad goes to player 2 (player 1 keeps the keyboard), two pads are player 1's and player 2's in connection order. Plugging in or out rebinds |
| F3 | debug overlay: each player's AI decision (chase, defend, support, dribble, pass, shoot, keeper states), BUSY while an animation locks them, touch cooldown; ball holder and last touch; frame rate, match state, clock, ball height/speed, energy |

## Layout

```
scripts/main.gd           Match: teams, possession, tackles, fouls, penalties, restarts, halves, control switching, goals, kick-offs, sound, HUD
scripts/stadium.gd        3D pitch, boards, stands and goals from the original textures; TV camera; pitch-to-screen projection
scripts/title.gd          boot sequence: intro FMV, title screen, title music
scripts/team_select.gd    pick both clubs from the league table
scripts/ai.gd             AI decisions: hold formation (shifts with the ball), chase, dribble, pass, shoot, goalkeeping
scripts/team.gd           Team: name, kits, 4-4-2 formation, pitch-side helpers; clubs from data/league.json, change kit on a clash
scripts/footballer.gd     a player's body: movement, animation, carrying the ball, kick/pass/shoot/slide
scripts/ball.gd           ball with height, bounce, friction, holder (dribbler); super-shot flight and trails
scripts/supers.gd         super-shot table (cost, animation, speed, colour) and energy rewards
scripts/combo_input.gd    fighting-game input buffer; directions relative to the goal you attack
scripts/human.gd          one person at the controls: team, controlled player, shot/combo state; keyboard and gamepad bindings
scripts/kit.gdshader      recolours kit parts of the original palette-indexed sprites
scripts/anim_library.gd   autoload "Anims": all player animations, frame lookup by facing (8 dirs)
scripts/pitch.gd          grass from the original texture, markings to real dimensions (18 px/m), baked into the 3D pitch's texture
scripts/anim_viewer.gd    browse the 81 animations
scripts/debug_overlay.gd  F3 overlay: AI decisions (Footballer.ai_state), ball ownership, match state, frame rate
data/league.json          the 18 Jupiler Pro League clubs: name, 3-letter code, standings, kit colours
data/squads.json          squads and EA ratings, built by tools/build_ea_assets.py (see below)
```

## How it's drawn

The match is simulated in 2D, in pitch pixels (18 px per metre) with a height for the
ball, as before. `Stadium` builds the ground and stadium in 3D (metres) and follows the
ball with a camera placed like FIFA 96's default TV view. Each frame the match projects every
player and the ball through that camera (`Stadium.to_screen`) and draws the original
sprites there, scaled for distance and sorted by depth, the way FIFA 96 put its sprites
into its 3D stadium. Camera height and distance are `CAM_OFFSET` / `CAM_FOV` in `stadium.gd`.

## Clubs

`data/league.json` lists the clubs in table order with their points (Sporza standings, fetched
2026-10-20 after 8 matches) and kit colours. The kit colours are from general knowledge of
each club's home kit, not checked against this season's (ASSUMED): edit the hex values to fix
one. When the two shirts look alike, the away side wears a plain white or dark change kit
(not the club's real away kit). Keeper kits are just contrasting colours.

## Kits

Sprites keep FIFA 96's palette indices. `kit.gdshader` recolours five slots (shirt,
shirt second colour, shorts, socks, boots); kit colours are set per club in
`data/league.json`. The index-to-slot mapping is in `tools/build_godot_assets.py`
(`KIT_SLOTS`), found by where each index appears on the body.

## Squads, ratings, crests and portraits

From EA SPORTS FC 27's public ratings site (1A Pro League: 502 players), for personal use
only and kept out of git:

```
tools/.venv/bin/python -I tools/fetch_ea_ratings.py downloads/ea_fc27   # 6 league pages, 18 crests, ~500 photos; slow on purpose
tools/.venv/bin/python -I tools/build_ea_assets.py downloads/ea_fc27 game
```

`build_ea_assets.py` writes `data/squads.json`: per club, the best 4-4-2 picked greedily
by position and overall rating (GK, RB, CB, CB, LB, RM, CM, CM, LM, ST, ST), then the subs,
each with all ~35 EA ratings. Shirt numbers aren't on EA's pages: numbers go by formation
slot. It also writes `assets/clubs/<SHORT>.png` (crest, on the scoreboard and team select),
`<SHORT>_board.png` (a pitch-side board: every third board shows one of the two clubs) and
`assets/portraits/<id>.png` (the photo pixelated to 40x40, 16 colours, shown above the
controlled player's name). EA has no photo for about half the players, mostly squad
players: they get `unknown.png`, a silhouette. The ratings are loaded into
`Footballer.stats` but don't change play yet.

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

## Energy and super-shots (Chaos Football only)

`Match.chaos` (a static var, set by the title screen) switches them off for Classic:
`Team.gain` adds nothing, `Match.try_super` refuses, and the energy bars aren't drawn.
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
