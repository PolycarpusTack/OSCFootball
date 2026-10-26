# Phase summary: EPIC D, League season, 2026-10-26

Branch `feature/A-cup`, on top of EPICs A to C. Nothing has been committed yet.

## What was built

| Task | Files | Test |
|---|---|---|
| D-0 PREP: `Competition` base | `competition.gd` (NEW). `cup.gd` extends it. `save_game.gd`, `main.gd` and `title.gd` take a `Competition`. `Match.enter_competition`, `play_fixture` and `leave_competition` replace the cup screen's knockout bookkeeping. `CupScreen.finish_tie` is replaced by `Competition.finish` | `cup_test`, `cup_flow_test`, `cup_smoke_test`, `save_test`: green before and after |
| D-1, D-2, D-4, D-5 Season model | `season.gd` (NEW): circle-method double round robin, `table()`, `scorers()`, `cards()`, `ratings()`, bans; `result_sim.gd` (`out`: suspended players); `main.gd` (the squad without them, `own_goal` and `ratings` in the result) | `season_test` |
| D-3 Season screen | `season_screen.gd` + `scenes/season.tscn` (NEW); SEASON on the title; CONTINUE opens a saved season | `season_smoke_test`, screenshots |
| D-6 Other scores | `Season.simulate_others()` before your match; `Match._latest_scores()` flashes "LATEST" at their minutes | `season_smoke_test` |
| D-7 Smoke | — | `season_smoke_test` |

## Deviations from the plan (for your review)

- **D-4 best rated covers only the matches played on the pitch.** A simulated result has no
  match ratings. The table is headed "BEST RATED (YOUR MATCHES)".
- **D-5-AC3: the suspended players are named on the season screen ("SUSPENDED: …").** They are
  not greyed on the team sheet. The competition flow skips the team management screen, as the
  cup already does. They're left out of the XI on the pitch and in simulations.
- **D-5-AC2: 5 yellows = 1 match is an assumed rule** (`Season.YELLOW_BAN`). It isn't a match
  option yet.
- **Clubs that are 4–18 and even only.** An odd number would need a bye, and no story asks for
  one.
- **The season name is "JUPILER PRO LEAGUE"**, the default in `Season.create`. That is the name
  in `league.json` (verified).

## Retro

- **Rework:**
  - My fixture generator appended to the array it was looping over. It looped forever and the
    test process was killed for memory; caught on the first run.
  - The smoke test read `m.home` before the match's first frame.
  - A garbled `... if false else ...` line in the setup heading. That's the third such slip in
    two EPICs, so I now grep for `if false` before every run.
- **Assumption check:**
  - AS-1 held: the simulated season looks plausible (e.g. 180 goals in 60 fixtures, about 3 a
    match).
  - AS-3 held: a match left halfway is lost; the save is from the screen before it.
- **Design:** the table, scorers and cards are always recomputed from the results, so nothing
  can drift. `season_test` still recomputes the table independently, as D-2 asks.

## TD items

- **TD-1 grows:** `_label()` is now in 10 scripts (`season_screen.gd` too). Servicing is overdue.
  I recommend the PREP task before EPIC E's or F's screens, rather than waiting for N.
- **TD-2 stands:** the instruction-level check is in two places.
- **TD-3 (new, S):** `CupScreen.slot` and `SeasonScreen.slot`, with the same "first empty slot"
  code, are written twice. Extract them on a third competition kind (e.g. two-legged ties are
  still a Cup, so probably never).
