# Phase summary: EPIC E, Injuries, 2026-10-26

Branch `feature/A-cup`, on top of EPICs A to D. Nothing has been committed yet.

## What was built

| Story | Files | Test |
|---|---|---|
| E-1 In-match injury | `footballer.gd`: `injury` (0, 1 knock, 2 severe); `skill()` reads the rating × 0.85; `top_speed()` × 0.8. `main.gd`: `INJURY` odds, `injure_odds()`, `_maybe_injure()` at the two slide-foul call sites and the body check. The INJURIES option (`match_options.gd`) | `injury_test` |
| E-2 Must go off | `main.gd` `_injury_subs()` at a stoppage, before the subs are made; `pause_menu.gd` `open_subs()` | `injury_test` |
| E-3 Across fixtures | `competition.gd`: `injuries`, `_book_injuries()`, `_counts()`, `unavailable()`. `cup.gd` and `season.gd` count them down and save them. `result_sim.gd` `INJURY` = 6 % a side. The result's `injuries`. The season screen's INJURED line | `injury_test` |
| E-4 Sub alert | `main.gd` `_sub_alerts()` | `injury_test` |

Measured (`injury_test`):

| What | Result |
|---|---|
| Injured in 4,000 fouls from behind / from the front | 803 / 265 |
| Unseen by the Chaos referee | × 1.5 |
| Simulated matches | 143 injuries in 1,000 |
| Injured player | speed × 0.80; dribbling 0.65 → 0.45 |

## Deviations from the plan (for your review)

- **No new limp animation.** An injured man is visibly slower; there's no limp frame yet. That
  would be art work, and AC2 only asks for the numbers.
- **A dive bought from the referee never injures anyone.** The check sits at the real slide
  fouls, not inside `_foul()`.
- **The human's forced sub comes on at the following stoppage.** The substitutions screen opens
  at the stoppage where the injury is dealt with. Subs chosen there come on at the next one, as
  they always do. The AI's sub comes on at once.
- **E-3-AC2 "out: 2" shows on the season screen** ("INJURED: X (2)"), not on a team sheet, for the
  same reason as the suspensions in D. A cup has no screen for it.
- **A knock is over by the next fixture.** Only bad injuries carry over (1–3 fixtures).
- **The options screen rows are tighter** (31 px rows, size 24) so all 15 Chaos rows fit;
  CATCH-UP was cut off with the new row. `modifiers_test` now expects 10 / 15 rows.

## Needs a playtest

- About 20 % of fouls from behind injure in the test, with the referee's view as it was in a
  frozen match. That may be too many in real play. The constants are `Match.INJURY`, `SEVERE`
  and `INJURY_UNSEEN`.

## Retro

- **Full suite: 41 of 41 pass** (`injury_test` is the new one).

- **Rework:**
  - `top_speed()` would have cut the speed twice, via the lower sprint rating and the 0.8. Fixed
    with `Footballer._rated()`.
  - A no-op pair in one of my edit scripts made it fail before writing one file. Caught and
    rerun.
- **TD:**
  - TD-1 (`_label` in 10 scripts) is unchanged; E added no screen.
  - **TD-1 serviced after E** (a PREPARATORY refactor): `UiText.label()` (`scripts/ui_text.gd`, NEW)
    makes the outlined Label.
    - The 8 screens' `_label()` keep only their layout (position, width, alignment, parent).
    - `debug_overlay` and `oscf_special_preview` have a `_label` that isn't a copy, and stay as
      they are.
    - The screen tests are green after it.
    - Found on the way: `lineup_test` read the player's real `user://lineups.json`. It now uses
      its own file.
  - The `{club: {name: count}}` parsing was written twice (bans/yellows, injuries) and is now
    `Competition._counts()`, at its third use.
