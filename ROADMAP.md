# OSCF roadmap and own-content replacement list

Drafted 2026-10-20 from a gap review of the FIFA 96 extraction against the game at `5e3839d`.
Sizes: S = an evening, M = a few sessions, L = a project of its own.

## Guiding rule: don't deepen the EA dependency

Every FIFA 96 file the game loads is one more thing to replace before the game can be shared
(the README already limits EA-asset builds to personal use). So:

- Build **features** first; they are asset-neutral.
- For atmosphere, prefer **own content** over wiring up more FIFA 96 files. You already have own
  music (`brand/title_music.ogg`, *Stadium Breakbeat*, *Arcade Rumble*, *Halftime Fanfare*), so the
  15 unused `QUE_*` cues are not worth wiring.
- When an EA file is used as a placeholder anyway, add it to the replacement list below in the
  same commit.

## Phase 1: match structure (asset-neutral)

| # | Item | Done when | Size |
|---|---|---|---|
| 1.1 | Pause menu: resume, restart, quit to title | Esc/Start pauses play, clock and AI; F1 still goes back | S |
| 1.2 | Match options screen: half length (2–45 match minutes), offside / fouls / cards toggles, Chaos or Classic | Choices kept between matches like `Match.chaos`; `HALF_SECONDS` read from the setting | S–M |
| 1.3 | Extra time, golden goal, penalty shoot-out | New states after FULL_TIME for knockout matches; shoot-out reuses `_penalty`; friendlies can still end level | M |
| 1.4 | Post-match stats and Man of the Match | Count shots, saves, fouls, cards and possession from the `event` signal; full-time screen | S–M |

## Phase 2: squad depth

| # | Item | Done when | Size |
|---|---|---|---|
| 2.1 | Substitutions (bench from `squads.json`) | Pause-menu sub; AI subs tired players; no subs for a sent-off player; 3 or 5 sub limit | M |
| 2.2 | Formations: 4-4-2, 4-3-3, 4-2-4, 3-5-2, sweeper | `Team.FORMATION` becomes a choice; players looked up by role, not list index (fixes the `players[9]` / `players[0]` debt) | M |
| 2.3 | Team strategy: defensive / balanced / attacking, long ball | Shifts the AI's support lines and pass choice | M |
| 2.4 | Free-kick wall | Defenders form a wall at 9.15 m for free kicks in shooting range | M |

## Phase 3: modes

| # | Item | Done when | Size |
|---|---|---|---|
| 3.1 | Cup (straight knockout, 8 or 16 clubs) | Bracket screen; uses 1.3; the other matches are simulated | M |
| 3.2 | League season (Jupiler Pro League, 18 clubs) | Fixtures, simulated results, table, top scorers, cards carried over; starts from `league.json` | L |
| 3.3 | Save / load for cup and season | One save slot per mode | M |

## Phase 4: atmosphere (own content first, see the replacement list)

| # | Item | Done when | Size |
|---|---|---|---|
| 4.1 | Music in the game: own tracks for team select, half-time, win, lose | Converted to OGG; nothing loads `QUE_*` | S |
| 4.2 | Crowd that reacts: background, chants that rotate, swells near goal, a roar on goals | Own crowd recordings, or FIFA 96 `CHN_*` as listed placeholders | S–M |
| 4.3 | Goal celebrations: fireworks, flag-waving crowd | Own effect art; FIFA 96 `FW*` / `FAnim` only as placeholders | M |
| 4.4 | Commentary | Decide first: own voice recordings, or FIFA 96 phrase clips as a personal-use extra. Start with ~30 generic lines (goal, save, miss, foul, kick-off, full time) | M first step; L in full |

## Phase 5: polish

| # | Item | Size |
|---|---|---|
| 5.1 | Instant replay of goals (a buffer of recent positions, no saving) | M |
| 5.2 | Practice mode: corners, free kicks, penalties, the Chaos moves | M |
| 5.3 | Stadium and pitch variety (own art; FIFA 96 has 4 stadiums and 4 mowing patterns as reference) | S–M |
| 5.4 | Settings: volume sliders, key rebinding, HUD toggles | S |

## Chaos track: the fighting-game layer

Chaos Football's moves, after the Street Fighter idea: motion inputs, an energy bar, specials
with wind-up, active and recovery windows, and counters. Details in `game/docs/chaos-actions.md`.

| # | Item | Status |
|---|---|---|
| C.1 | Combo input, energy bar, super-shots (Fireball, Banana Shot, Thunder Strike) | Done |
| C.2 | Skill moves (nutmeg, rainbow, backheel), Body Check, dodge, Dizzy | Done |
| C.3 | Eleven Chaos actions on E / R (Ghost Step … Cyclone Scissor), with AI use | Done |
| C.4 | Chaos referee, parts 1–4: view cone, discipline, mood, "Sorry, ref!", Dive, Captain, whistle stun, Bribe | Done |
| C.5 | Role moves: ↓↘→ per line (Fireball / Bulldozer Clear / Laser Pass / Cannon Punt) and one signature special per line (Grapple Tackle, Stepover Storm, Whirlwind Turn, Rising Fist), in own art | Done (`role_moves_test`) |
| C.6 | Role-move art in team colours: the line-action sheets are drawn in the OSCF kit; recolour them per team, or redraw them flat for a recolour shader | Open (S–M) |
| C.7 | Effects sheet in play: impact burst, dust puff, spinning cards, whistle ring (`oscf_roles`), in place of the drawn-in-code effects | Open (S) |
| C.8 | Own art for the Chaos actions that borrow FIFA 96 animations (Magnet Sole, Phalanx Wall, Captain and Bribe use `mark`; Bass Drop `gpound`; and the rest) | Open (art first, then M) |
| C.9 | Balance pass: costs, windows and AI frequency, from playtests | Open (M) |
| C.10 | Move list in the pause menu (inputs in the device's buttons, costs, animation preview); special picker filtered by line | Done (`move_list_test`) |
| C.11 | Situation prompts in place of the help line; combo feedback (input trail, "need 30" flash, energy-bar notches); the move list from the title screen | Open (M) |

Left out on purpose: modem/serial play, the custom team editor, the 1995 database, language
select, camera views, the 160×120 FMVs.

## Clean-build track (run alongside the phases)

The milestone "the game runs with `game/assets/` empty except for own art". Order: the items
everyone sees every second first.

1. Locomotion sprites, kit palette, grass, net: the game is unrecognisable without them.
2. The 7 sound effects and the crowd background.
3. Stadium: crowd, stands, roof, the 4 remaining FIFA 96 boards.
4. Ball skills, contact, keeper sprites.
5. Celebrations and referee sprites.
6. The EA SPORTS FC 27 data (see section E): a separate decision.

---

# What to replace with own content

Everything here is loaded from the gitignored `game/assets/` (FIFA 96, built by
`tools/build_godot_assets.py`) or from the EA SPORTS FC 27 download (`tools/build_ea_assets.py`).
Sizes are the current files, so a drop-in replacement matches them or the code changes with it.

## A. Player sprites (FIFA 96 `PLAYART.PVI`): the biggest job

**Format:** one horizontal sheet per animation in `assets/sprites/players/<anim>.png`, frame
rectangles, foot anchors and timings in `animations.json`. **5 drawn directions** (N, NE, E, SE, S;
NW, W, SW are mirrored). Frames are up to **62 px tall**, most about 44 px. The sprites are
**palette-indexed**: `kit.gdshader` recolours 7 slots (kit colours, skin, hair) through
`palette.png`. Own art has to end up in that format, or the shader changes.

**In use: 42 animations, 1,356 frames** (of 81 / 2,465 imported):

| Group | Animations | Own art so far |
|---|---|---|
| Locomotion | `run`, `jog`, `walk`, `xstandd` (stand), `mark`, `stumble`, `fall`, `jump` | `oscf_starter`: idle, run, kick (60 frames, RGBA, **not yet palette-converted**) |
| Ball skills | `kick`, `shoot`, `chest`, `header`, `divehed`, `vollkck`, `bicycle`, `bckheel`, `nutmeg`, `rainbow`, `throwin`, `duckflp` | `oscf_starter` kick |
| Contact | `tackle`, `slide`, `bodychk` | — |
| Keeper | `gdkick`, `gjmctch`, `glwctch`, `glwthrw`, `gmdctch`, `gpound`, `gpunchu`, `ghdsa`, `ghdsb`, `gldsa`, `gldsb` | `oscf_specials`: elastic save (and 3 other special moves) |
| Celebrations | `aeropla`, `celdnc2`, `celdnce`, `celdpnc`, `vctflip`, `victrun` | — |
| Referee | `rcard`, `rpoint` | Done: own referee art (`oscf_roles/referee`) replaces them |

Also own and outside this list: `brand/sprites/line_actions` (bulldozer clear, cannon punt, …).

## B. Kit palette

| File | Size | Note |
|---|---|---|
| `assets/sprites/players/palette.png` | 256 × 2 | FIFA 96 palette the kit shader indexes; replace together with A |

## C. Pitch and stadium (FIFA 96 `GAMEFLD1` / `GAMESTD1`)

| File | Size | Loaded by |
|---|---|---|
| `pitch/grass.png` | 64 × 64 tile | `pitch.gd` |
| `goal/net/004_ball_4.png` | 64 × 64 | `stadium.gd:194` |
| `stadium/crowd.png`, `crowd_stairs.png`, `crowd_tunnel.png` | 128 × 128 each | `stadium.gd:140` |
| `stadium/front.png` | 128 × 16 | `stadium.gd:143` |
| `stadium/roof.png` | 64 × 128 | `stadium.gd:144` |

`stadium/front_corner.png` and `stand_end.png` are imported but never loaded, so they don't
need replacing.
| `stadium/board0, 2, 3, 6.png` | 128 × 16 each | `stadium.gd:110`. Boards 1, 4, 5, 7, 8, 9 are already own (`brand/board_*`) |

## D. Audio (FIFA 96 `SFX_GAME.BNK` / `CHN_GEN1.BNK`)

All 16 kHz, mono. Mapped in `main.gd`'s `SFX` table:

| Sound | File | Length |
|---|---|---|
| kick | `sfx/slot002.wav` | 0.03 s |
| bounce | `sfx/slot001.wav` | 0.03 s |
| pass | `sfx/slot012.wav` | 0.05 s |
| whistle | `sfx/slot030.wav` | 0.17 s |
| long whistle | `sfx/slot029.wav` | 1.0 s |
| ooh | `sfx/slot005.wav` | 2.0 s |
| roar | `sfx/slot021.wav` | 5.2 s |
| crowd background (loop) | `crowd/slot055.wav` | 7.3 s |

Own music already exists; see 4.1.

## E. EA SPORTS FC 27 and real-world data: a separate decision

Not FIFA 96, but still not yours. Whether you can use it depends on how you share the game; that
question is outside this plan.

| What | Where | Count |
|---|---|---|
| Club crests | `assets/clubs/<SHORT>.png` (128 × 128) | 18 |
| Crest boards (generated from the crests) | `assets/clubs/<SHORT>_board.png` (256 × 32) | 18 |
| Player photos, pixelated | `assets/portraits/<id>.png` (40 × 40, 16 colours) | one per player with a photo |
| Ratings and squads | `data/squads.json` | 18 squads |
| Real club and player names | `squads.json`, `league.json` | all |
| League standings (Sporza) | `data/league.json` | 18 clubs |

If you want a fully own game, the usual route is invented clubs, names, crests and ratings,
keeping the Belgian flavour. Your own sprite art doesn't depend on it.

## F. Already own

The ball (`brand/ball`), title screen and music, intro video and end card, OSCF/PTE boards,
`oscf_starter` and `oscf_specials` sprites, `line_actions` sprites, and the four music tracks.
