# Phase summary: EPIC A, Cup competition (tracer bullet), 2026-10-26

Branch `feature/A-cup` (from `keyboard-specials`, which isn't merged yet).

## What was built

| Story | Files | Test |
|---|---|---|
| A-1 Result Simulator | `game/scripts/result_sim.gd` (NEW, `ResultSim`) | `result_sim_test` |
| A-2 Cup model | `game/scripts/cup.gd` (NEW, `Cup`) | `cup_test` |
| A-3 Bracket screen and flow | `game/scripts/cup_screen.gd` + `game/scenes/cup.tscn` (NEW, `CupScreen`); `title.gd` (▲/▼ to CUP); `main.gd` (`Match.competition`, `competition_fixture`, `competition_result()`, `_leave_full_time()`, `minute()`); `match_stats.gd` (`scorers`, `cards` with minutes) | `cup_flow_test` |
| A-4 Smoke test | — | `cup_smoke_test` |

PREPARATORY steps, done before the feature work with tests green:
- the full-time exit moved into `Match._leave_full_time()`;
- the match-minute formula moved into `Match.minute()`. It was the third copy (`commentary.gd`,
  `cpu_manager.gd`), so the Rule of Three applied.

## Deviations from the plan

- **A-1 ST0 dropped:** the XI picker was already static (`Lineup.auto_pick`), so it was reused.
- **A-3:** Space on the bracket goes straight to the match, using your saved team sheet
  (`Lineup.load_saved`) and the current match options. The team sheet and options screens are
  skipped for a cup tie, because the options screen could turn knockout off.
- **`Cup.record` refuses a result without a winner.** This came from the flow test: a cup tie
  can't end level.
- Leaving the cup with Esc loses it. Saving is EPIC B. A cup left in the middle of a match (pause
  menu → title) is picked up again by choosing CUP; a one-off match clears it.

## Retro

- **Rework:** two test fixes on my side, not in the code:
  - JSON reads every number back as a float, so the save comparison now round-trips both sides;
  - a test goal was blocked by the keeper, so the test clears the players first, as
    `knockout_test` does.
- **Assumption check:**
  - AS-1 held: the simulator gives plausible results and is fast. It reads `squads.json` once;
    1,000 fixtures take under 1 s.
  - AS-2 held: `overall` by line is enough.
- **Budget:** every task was well under 15k tokens of output.
- **Waste:** none of note. Script errors make a headless test hang rather than fail. Run tests
  with `timeout`.

## TD items

- **TD-1: screens — a `_label()` helper duplicated in 9 scripts** (`grep -l "^func _label("`).
  - Type: code duplication.
  - Principal: S, one PREPARATORY task to extract a shared `UiText.label()`.
  - Interest: every new screen copies it again, and EPICs B, D and N add screens.
  - Servicing decision: a PREP task before EPIC N, or sooner if a style change has to touch all
    of them.
