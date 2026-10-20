# Ideas to implement (from FIFA 97 and FIFA: Road to World Cup 98)

The backlog of ideas found in FIFA 97 and RTWC 98, with where each one shows in their data
so it can be looked up again. Collected 2026-10-20 from menu and string tables and file
names; nothing from the games was run. **V** = seen in the data (file and string given),
**A** = assumed (general knowledge or inference).

**Design ideas only.** No EA file, model, sound or text goes into the game (ROADMAP's
guiding rule). The strings below are quoted as evidence, not to be reused.

Sizes as in ROADMAP: S = an evening, M = a few sessions, L = a project of its own.
Start with **I.1 Indoor mode**.

## Getting back to the data

The games sit in the repo root, ignored by git (`.gitignore`: `*.7z`, `jeu-*/`, `FIFA 98/`).
Extract into a new empty directory **outside** the repo; read only, never run anything.

| Game | Where | How |
|---|---|---|
| RTWC 98 | `FIFA 98/FIFAPCCD.iso` (also `jeu-01611-fifa98-pcwin.7z`) | `7z x FIFAPCCD.iso -o<dir>`. Game data in `INGAME/`, `COMMON/`, `FEPACK/`, `AUDIO/` |
| FIFA 97 | `jeu-01898-Fifa_97-pcwin/fifa97.img` (+ `.cue`; also the `.7z`) | Raw CD: track 1 is `MODE1/2352` (V, `fifa97.cue`), then 10 audio tracks. Take the 2048 data bytes at offset 16 of each 2352-byte sector up to track 2 (`36:45:37`, sector 165412) into an `.iso`, then `7z x`. Data in `FEDATA/`, `GAMEART/`, `AUDIO/` |

Most files are EA RefPack-compressed and/or BIGF archives: `tools/eaformats.py` reads them
(`maybe_decompress`, `read_bigf`; `read_shpi` for images). Then `strings -n 4` gives the
text. The two string tables used below:

- **RTWC 98:** `COMMON/FCENG.BIN` (English UI text, about 1,800 strings; plain enough for
  `strings` as is). The exe `FIFARTWC.EXE` holds the cheat names and code symbols (strings
  only; never run it).
- **FIFA 97:** `FEDATA/LANG000.POG` (English UI text, after `maybe_decompress`).

## I.1 Indoor mode (the favourite): ROADMAP 3.4, M

**In the originals:**

| What | Evidence |
|---|---|
| RTWC 98 indoor is 4 outfield players + keeper | V: `FCENG.BIN` "Must use a 4 player formation" (next to "Must use a 10 player formation"), "Indoor", "Indoor Stadium" |
| FIFA 97 indoor is 5 outfield + keeper, own formations | V: `LANG000.POG` "2 * 1 * 2", "1 * 2 * 2", "2 * 0 * 3", "3 * 0 * 2", "2 * 2 * 1"; "Indoor/Outdoor" |
| A walled arena: boards on all four sides | V: `INGAME/STADIUM/INDR_E_D.BIG` (also `_F_`, `_H_`) has wall meshes `board_n/s/e/w.pc` with material "wall"; the outdoor stadiums have none |
| Size: about 0.37 × the outdoor stand ring each way, ~1/7 the area; boards ~558 units high | V (mesh bounds ±3780 × ±4872 vs ±10270 × ±13463). In metres about 33 × 42 (A) |
| Day only, no stadium fly-in video | V: only `INDR_*_D.BIG`, no `STD_*.DCT` for it |
| Surfaces and pitch size | V: `LANG000.POG` "Indoor Surface", "Artificial", "Wood", "Turf", "Pitch Size" |
| Players walk to the side for substitutions | V: `FIFARTWC.EXE` symbol `PLAYER_indoorGoToSideline_` |
| No throw-ins, corners or offside: the ball plays off the boards; fouls and cards stay | A |
| "Invisible Walls" cheat: boards around an outdoor match | V: `FIFARTWC.EXE` "Invisible Walls"; `LANG000.POG` "Invisible wall", "Invisible Walls" |

**For OSCF:**

1. **Option.** "Indoor" on the match options screen (`scripts/match_options.gd`, kept like
   `Match.chaos`).
2. **Arena.** A smaller field (`Pitch.field_rect()` per mode) with boards. The ball rebounds
   off them as it does off the posts and bar (`Match._check_frame`); players are kept inside.
3. **Rules off.** No throw-ins, corners, goal kicks or offside (`Match._check_out`,
   `_award_restart`, `offside_players`); the keeper still restarts after saves. Fouls,
   cards and penalties stay.
4. **Squads.** A 4+1 formation in `Team.FORMATIONS` (fifa-96-b5's formations work), picked
   from the squad; rolling substitutions with 2.1.
5. **Own art.** Boards with our sponsors (we already make boards in `brand/`), a hall floor
   or artificial turf, a low crowd.
6. **Chaos indoors.** Rebounds suit the Pinball Pass and Boomerang Cross; a new "wall pass"
   special could play off the boards on purpose.

**Done when:** an indoor friendly plays start to finish with 5 a side; the ball never leaves
the arena except into a goal; there's no throw-in, corner or offside; there's an
`indoor_test`.

Related, S: **Invisible walls** as a Chaos modifier for outdoor matches (see I.4).

## I.2 Cups and seasons: ROADMAP 3.1 / 3.2

| Idea | Evidence (`FCENG.BIN` unless noted) | OSCF | Size |
|---|---|---|---|
| Two-legged ties: aggregate, away goals | V: "1st leg", "%s has won on Aggregate Goals", "%s has won on Away Goals", "Extra Time-Aggregate score %d" | 3.1 cup option | M |
| Cup creator: groups, games per opponent, who goes through, how ties end | V: "Number of Groups in Tournament Portion", "Number of Matches Versus Fellow Group Members", "Number of Teams that Advance to Playoff from Each Group", "Number of Matches Versus Opponent in Final", "Sudden Death Extra Time then Penalty Kicks", "Extra Time Only", "Sudden Death Only", "Have CPU randomize teams in groups?" | 3.1 + 1.3 | M |
| Qualifying then a finals round | V: "%s have advanced to the Final Round!", "%s have failed to advance to the Final Round." | 3.1 | M |
| Suspensions after 7 / 11 / 15 yellows; injuries carried over | V (earlier survey); "%s is not available due to an injury suffered in Training." | 3.2 season | S |
| Penalty shoot-out as its own mode | V: `FEPACK/PENALTY.ALL` | 1.3 | S |

## I.3 Practice and training: ROADMAP 5.2, M

| Idea | Evidence |
|---|---|
| Attack drill: score before the defence clears it | V: `FCENG.BIN` "Attack-Score before the Defense clears the ball"; `LANG000.POG` "Score before the defence clears the ball" |
| Defence drills: clear it, save it | V: `FCENG.BIN` "Defense-Clear the ball over the half line or any touch line before the opponent shoots", "Defense-Save the ball" |
| Set pieces | V: `FCENG.BIN` "Corners/Free Kicks/Training Match" |
| Timed challenges with best times | V: `LANG000.POG` "Best Times" |

For OSCF: the drills as practice scenarios (5.2), each a small `State` setup reusing the
restart code; best times in `user://`. Add Chaos drills: land a Fireball, a Laser Pass to a
runner, a Grapple Tackle.

## I.4 Options, tactics and Chaos modifiers

| Idea | Evidence (`FCENG.BIN` unless noted) | OSCF | Size |
|---|---|---|---|
| Assists: AI-assisted passes, lobs, headers; automatic crosses; shot aim by stick or CPU | V: "AI Assisted Passing", "AI Assisted Lobs", "AI Assisted Headers", "Automatic Crosses", "Shot Targeting-(D-Button/CPU)" | 5.4 settings | S |
| Catch-up logic, team parity, skill levels | V: "Catch-up Logic", "Team Parity", "Skill Mode" | Chaos: extra energy for the side behind; AI difficulty | S |
| Named tactics | V: "Offside Trap", "Flood Box", "Hold the 18", "Double Team", "Overlap", "Wing Back Charge", "Through Ball Run", "Man Marking", "%s is being Man Marked by %s", "Attack Bias", "Pass Bias", "Shot Bias" | 2.3 strategy presets (with fifa-96-b5's tactics page) | M |
| Referee strictness | V: "Referee Strictness" | C.4: a slider for the Chaos referee's temper (`DISCIPLINE`, `MOOD_GAIN`) | S |
| Exaggerated ball physics | V: "Ball Physics", "Exaggerated" | Chaos modifier | S |
| **Chaos modifiers menu**: each cheat one toggle | V, RTWC 98 (`FIFARTWC.EXE`): "Take a Dive", "Hot Potato", "Big Heads", "Crazy Ball", "Silly Moves", "Invisible Walls". FIFA 97 (`LANG000.POG`): "Giant player", "Metallic men", "Laser ball", "Curve ball", "Radical curve", "Crazy bounce", "Super Goalie", "Hot potato", "Crazy ball" | a new options page; big heads = sprite scale, laser ball = super trails always, super goalie = keeper reach ×2, crazy bounce = restitution up | S each |

## I.5 Presentation: ROADMAP 1.4, 4.x, 5.x

| Idea | Evidence | OSCF | Size |
|---|---|---|---|
| Weather and day/night | V: `FCENG.BIN` "Weather", "Sunny", "Rain", "Snow", "Sleet" | 5.3 | M |
| Pitch condition and wear | V: `LANG000.POG` "Pitch Condition", "Dry", "Damp", "Drenched", "Pitch Damage" | 5.3: a wet pitch slows and skids the ball (A) | M |
| Stadium card before kick-off | V: `FCENG.BIN` "Capacity", "Year Built", "Record Attendance" | 5.3 (our clubs' grounds) | S |
| Event captions | V: `FCENG.BIN` "Hat-Trick", "Equaliser", "Milestone Goal", "Clean Sheet" | 1.4 / 4.4: flash() banners | S |
| Radar, auto replay | V: `FCENG.BIN` "Radar", "Auto Replay" | 5.1 / 5.4 | S |
| A pool of ~40 general chants plus club chants, rotated | V: RTWC 98 `AUDIO/CHNT/CGENER00-40` and per-team `C000xxxx` (names only) | 4.2 with our own recordings | S |
| Commentary: team-name lines apart from event lines | V: RTWC 98 `INTT/D_T*` and `GAMT/J_T*` (387 each) | 4.4: record club names separately, then join | S |

## I.6 A 3D version (OSCF 3D): L

Don't decode EA's models or motion. FIFA 97/98's players are 3D: meshes in FIFA 97
`GAMEART/PLAYER.POG` and RTWC 98 `INGAME/PLAYER/MODELS/*.PAK` (three detail levels,
`lowpoly.pc` / `medpoly.pc` / `hipoly.pc`, named in `FIFARTWC.EXE`), motion in FIFA 97
`GAMEART/MAIN.POG` (`mopc.moi`) and RTWC 98 `COMMON/ANIM.MO` (a BIGF of 467 named clips) (V). They're EA's, and undocumented. The path:

1. **Our own 3D player, made once** (Blender): one stylised low-poly body (about 1-3k
   triangles, the late-90s look), a standard humanoid rig, the kit as flat material slots.
   Keeper and referee from the same body. Animation: hand-keyed in Blender, a free
   library whose terms allow games (check them first), or our own video motion capture.
2. **Pre-rendered sprites for the 2D game first**, as FIFA 96 itself did: a Blender script
   renders every animation in 5 (or 8) directions with flat kit colours, into the sheet
   format `AnimLibrary` reads (`animations.json` + strips), so the kit shader colours them.
   This replaces the 42 FIFA 96 animations (ROADMAP replacement list A) and gives the role
   moves team colours and all directions (C.6).
3. **OSCF 3D as a second view of the same match.** The match runs in pitch coordinates
   plus the ball's height and is drawn through one projection (`stadium.to_screen()`, from
   `Match._process`). A 3D view replaces that drawing layer; rules, AI, Chaos and the
   referee stay. Prototype: a 3D pitch with 22 capsules driven by the existing match, then
   the models, animation blending, and the ball meeting the foot.

Steps 1-2 are L together but pay off in 2D right away; step 3 is L on its own. The Blender
MCP connection in Claude Code can drive steps 1-2.
