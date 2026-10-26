# Status: the GPM backlog and the polish slices (2026-10-26)

## Where things stand

- **`main` = `origin/main` = `feature/A-cup` = `origin/feature/A-cup` = `b53de87`** (pushed).
  Working tree clean.
- **Feature work is paused** (your decision, 2026-10-26). Done:
  - EPICs A–G of the player backlog (`docs/gpm/backlog-player.md`): cup, saves, Team
    Instructions, league season, injuries, replays, Tactic Slots;
  - polish slice 1, menus, fonts, commentary (`docs/gpm/backlog-polish.md`);
  - polish slice 2, the match engine for Pixel and 3D (`docs/gpm/backlog-polish.md`, ADR-005).
- **Tests:** 45 tests in `game/tests/*_test.gd`. The last full run passed 44 of 45; the failure,
  `chaos_actions_test`, is a random check that passed 3 times alone (TD-S3). Run at most
  2 Godot instances at a time (more has OOM-killed desktop apps).
- **Builds**, both from `b53de87`:
  - `build/OSCF.x86_64` started cleanly;
  - `build/OSCF.exe` is untested (no Windows or Wine here).

  Both hold FIFA 96's assets: keep them private, never upload or share them. `build/` is
  git-ignored.
- **Another worktree** is at `~/Claude/oscf-c9` (branch `c9-balance`). It isn't from this work;
  leave it alone unless you say otherwise.

## Done today (2026-10-26)

| What | Where |
|---|---|
| EPIC F replays, EPIC G Tactic Slots | `docs/gpm/state/phase-F.md`, `phase-G.md` |
| Slice 1: fonts (OSCF Jersey + Pixelify for Pixel, Exo 2 for Rendered/3D), menu audit, about 2× commentary with serious and Chaos pools | `docs/gpm/state/phase-P1.md` |
| Slice 2: run/jog/walk no longer flicker (38 → 0 a player-minute) and pace with speed; facing hold; **3D edition** (PLAYERS: PIXEL / RENDERED / 3D), with our Blender footballer as glTF, posed from the same looks, so the match plays the same; a sprint pose driven by distance; blends; light and shadows | `docs/gpm/state/phase-P2.md` |
| Playtest fixes: the keeper's glued ball (his hold applied outside his box too), pale 3D players (sky-blue ambient), an indoor venue that is now a hall | `phase-P2.md`, "After your playtest" |

## Open / next

1. **Playtest the new build:**
   - the keeper fix (carry it out of the box: you can pass, they can tackle);
   - the 3D colours;
   - the indoor hall;
   - the Windows .exe's first launch;
   - the keyboard specials (hold special + a button), untried since 2026-10-25;
   - injury rates.
2. **Possible slice 3 (3D polish):**
   - 3D players drawn larger, to match the sprites' screen size;
   - an outline;
   - poses for the 41 FIFA 96 animations that show a stand-in (`Puppet.NEAREST`: keeper holding
     the ball, get-ups, injuries, the referee's gestures);
   - frame times measured on a quiet machine. The last 3D median was 5.7–8.9 ms, but the
     machine was swapping.
3. **Technical debt:**
   - TD-S1: the facing still flickers 4.1 a player-minute;
   - TD-S2: `Puppet.NEAREST` stand-ins;
   - TD-S3: seed `chaos_actions_test`.
4. **Your decisions:**
   - the deviations listed in `docs/gpm/state/phase-*.md`, still awaiting your review;
   - manager mode, your answers to its questions (`docs/gpm/backlog-manager.md`);
   - F-5 (save a goal), on hold;
   - N-14 shielding: which key (`docs/gpm/backlog-player.md`);
   - whether features stay paused.
5. **Older, from 2026-10-21 (not rechecked since):**
   - tuning the ratings effects by feel;
   - the probe's `DECISIONS` list lacks "through ball";
   - unbuilt ratings ideas (shielding by strength, gkKicking distribution, …).

## How to work here

- **Branches and pushes:** work on a branch; commit only when asked, staging explicit paths
  (never `git add -A`). Push only when you say so, after checking that nothing from FIFA 96 or
  EA is in the push.
- **Godot:**
  - tests are `godot --headless --path game -s res://tests/<name>.gd`;
  - wrap them as `timeout 300 stdbuf -o0 -e0 godot ...`, or a hang shows no output;
  - after new class_names or assets, run `godot --headless --path game --import`.
- **Blender:**
  - the model: `blender -b -P tools/blender/footballer_gltf.py -- game/assets/models/footballer.glb`;
  - the Rendered sprites: `tools/blender/footballer.py`.
- **Builds:** `godot --headless --path game --export-release "Linux" ../build/OSCF.x86_64`
  (and `"Windows" ../build/OSCF.exe`).

## Pick-up prompt

Paste this into a new session in `~/Claude/Fifa 96`:

```
Read STATUS.md in the repo root and pick up where we left off (2026-10-26: EPICs A–G and
polish slices 1–2 done, playtest fixes in, all pushed at b53de87).
1. Check git: main and feature/A-cup at b53de87 or later, level with origin; tree clean.
2. If other Claude sessions are running (ListAgents), coordinate before touching the working
   tree. Leave ~/Claude/oscf-c9 alone.
3. Ask me what I found playtesting the new build (keeper, 3D colours, indoor hall, Windows
   .exe, keyboard specials), then which "Open / next" item to do: slice 3 (3D polish),
   the TD items, or one of my decisions (manager mode, F-5, N-14).
Run Godot tests at most 2 at a time. Push only when I say so.
```
