# Phase summary: EPIC F, Replays and highlights, 2026-10-26

Branch `feature/A-cup`, on top of EPICs A to E. Nothing has been committed yet.

## What was built

| Story | Files | Test |
|---|---|---|
| F-1 Replay buffer (ST0 spike AS-5) | `replay.gd` (NEW, `Replay`, a Match child): a ring of 300 frames (10 s at 30 Hz) of [camera focus, `Ball.look()`, [[actor, `Footballer.look()`]…]]. `footballer.gd` and `ball.gd`: `look()` and `show_look()`. `main.gd`: `replay.record()` first in `_physics_process`; `camera_focus()` taken out of `_process` | `replay_test` |
| F-2 Instant replay after a goal | `main.gd`: when GOAL's pause runs out, the last goal's highlight (else the last 6 s) plays at 0.5×, "R" on screen, any key skips it; `replays_on`, the REPLAYS option (`match_options.gd`, row 10) | `replay_test` |
| F-3 Replay from the pause menu | `pause_menu.gd`: REPLAY. Space plays or pauses, ←/→ steps a frame, S cycles ¼, ½ and 1×, Esc goes back to the menu | `replay_test` |
| F-4 Highlights | `Replay.highlights`: each goal and save, 6 s. H on the full-time screen plays them in order (the hint shows when there are any); the full-time panel is hidden while they play | `replay_test` |

## AS-5 spike verdict: holds

| What | Result | Bound |
|---|---|---|
| Recording, per kept frame (`record_frame`, 23 actors) | 125–261 µs (two runs) | SLO < 1,000 µs |
| Recording, per physics frame | half that: only every other frame is kept | |
| The full ring of 300 frames | about 3.2 MB in memory (611 KB serialised) | bounded: the ring never grows past 300 |
| Drawing path | `stadium.to_screen()` and `Anims.frame_at()`, as the live match draws | |

ADR-004 is accepted: record what's drawn, don't re-simulate.

## Deviations from the plan (for your review)

- **A goal's highlight runs to 1 s after the goal** (`Replay.AFTER`), not to the moment the instant
  replay starts. The first second of the celebration is in it; the rest isn't. That's one rule
  for goals and saves alike, and it doesn't depend on how long the celebration lasts.
- **The instant replay is the goal's 6 s highlight**, not "the last 6 s" when it starts. The
  celebration would otherwise fill most of it.
- **No instant replay on autoplay** (tests, the attract mode) and none when REPLAYS is off. The
  highlights are kept either way.
- **The replay doesn't play the crowd, the commentary or the sound.** It draws the pitch only.
- **F-3's "rewind"** is ← one frame at a time (held, it runs on), not a reverse playback.
- **The instant replay takes 12 s** (6 s at half speed) on top of the celebration. Any key skips
  it, but if it feels long in play, `Replay.CLIP` or the speed are the knobs.
- **F-5 stays on HOLD:** saving a goal needs the kits and art outside the match. Your call.

## Retro

- **Full suite: 42 of 42 pass** (`replay_test` is the new one), after two test fixes:
  - `pause_test` reached SUBSTITUTIONS by pressing ↓ twice; REPLAY is a new item above it.
  - `smoke_test` waits 15 s for each kick-off, and an instant replay now takes 12 s (6 s at half
    speed) after the 3.5 s celebration. It plays with REPLAYS off, as it isn't a replay test.
- **Rework:**
  - The test read `m.replay` before the match had set itself up. Moved after the first wait.
  - The test checked for the highlight before the 1 s after the goal had been recorded. It now
    waits 1.5 s of play.
  - The highlights would have played under the full-time panel. It's hidden while they play.
- **TD:** no new items. The options screen now has 16 rows in Chaos; the last ends at y ≈ 667 of
  720, so one more row would need the rows tightened again or a second page.
