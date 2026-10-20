# Status — ratings work (2026-10-21)

## Where things stand

- **`main` = `origin/main` = `2000973`** (pushed). Holds all the ratings work below, fifa-96-b5's
  match engine (`a6e55c1`) and origin's control hints. Nothing pending from either session.
- **All 23 tests pass** (`game/tests/*_test.gd`; run at most 2 Godot instances at a time).

## What was built (branch `vision-curve`, all in `main`)

EA ratings that were only on the team sheet now drive play (see `game/README.md`, "Ratings in play"):

| Rating | Effect |
|---|---|
| vision | pass range 400-560 px, pass-button cone 45-75°, blocked-lane penalty, lead on runners, through-ball option |
| curve | long shots / free kicks / crosses / corners bend in on target (keeper misreads); curlers aim far corner |
| weak_foot, preferred_foot | x1.0-1.6 error kicking across the body |
| skill_moves | nutmeg/backheel need 2★, rainbow 3★; AI tries them x stars/3 |
| gkHandling | poor keepers spill hard shots (40% at 40, none from 67.5) |
| gkPositioning | AI keeper 8-28 px off his line, comes for loose balls 120-200 px |
| positioning | attackers wait 0.9-0.1 m **behind** the offside line (fixed: they used to stand 0.5 m past it) |
| pace / reactions | chaser, AI presser and receiver = quickest to the ball (`Footballer.time_to`), not nearest |
| ballControl / reactions | heavy first touch on fast balls |
| defensiveAwareness | marking tightness and reading the run |
| interceptions | off-ball defenders step toward the passing lane (max 4 m) |
| dribbling | AI dribbler swerves round a man in the way |

Merged with fifa-96-b5's engine: its weighed `choose()/options()` stays; through ball and skill stars
are options in it; its `shooting_range` (longShots) is the only shot range. Through-ball worth tuned to
vision 20-55: at 45-85 it crowded out long shots (probe: max shot 19 m → 24 m; before the merge 27 m).

Tests: `game/tests/ratings_test.gd` (extended), `game/tests/movement_test.gd` (new).
Probe: `godot --headless --path game -s res://tests/engine_probe.gd -- matches=2 seed=1`
(last: ~57-64% AI passes found, 4-5 shots/match, max shot 24 m; fifa-96-b5's reference: 55-60%, ~6).

## Open / next

1. **Play a few matches and tune by feel**: lane-stepping defenders, heavy-touch frequency, through
   balls vs long shots. Each effect is one `skill(...)` range in `ai.gd` / `main.gd` / `footballer.gd`.
2. The probe's `DECISIONS` list lacks `"through ball"`, so through balls don't show in its decision rows.
3. Not built yet (ideas): strength shielding; aggression+stamina second presser; fatigue hurting
   reactions/accuracy; finishing vs shotPower shot choice; best header attacks the near post;
   gkKicking long vs short distribution; positioning-timed runs in behind; pass-marker through-ball
   hint. The squad data has no height/weight/work rate.
4. Clean-up when happy: worktree `.claude/worktrees/vision-curve` (branch `vision-curve`), backup ref
   `refs/backup/main-wip-2026-10-20`, folder `~/Claude/Fifa 96 backups/2026-10-20/`.

## Pick-up prompt

Paste this into a new session in `~/Claude/Fifa 96`:

```
Read STATUS.md in the repo root and pick up where the ratings work left off.
1. Check git: main should be at 2000973 or later, level with origin/main.
2. If other Claude sessions are running (ListAgents), coordinate before touching main's
   working tree; do new work on a branch in a worktree. Don't push main without my say-so.
3. Then ask me which "Open / next" item to do: tuning by feel, the probe's DECISIONS list,
   one of the not-built ideas, or the clean-up.
Run Godot tests at most 2 at a time.
```
