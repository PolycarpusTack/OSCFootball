# Phase summary: EPIC C, Team Instructions, 2026-10-26

Branch `feature/A-cup`, on top of EPICs A and B. Nothing has been committed yet.

## What was built

| Story | Files | Test |
|---|---|---|
| C-1 Model and defaults | `team.gd`: `INSTRUCTIONS`, `instructions`, `instruction(key)`, `instruct(levels)` | `instructions_test` (AC1; AC2 against golden values taken before any `ai.gd` change) |
| C-2 Mentality, width, line, trap | `ai.gd` `hold_spot()`: MENTALITY, WIDTH, LINE, TRAP | `instructions_test` |
| C-3 Passing, tempo, shooting | `ai.gd`: `options()`, `pass_option(..., direct)`, `think_time()` (NEW), `shooting_range()` | `instructions_test` |
| C-4 Pressing, tackling | `ai.gd`: `_standing_off()`, `second_presser()` (NEW), `slide_chance()`, `body_check_chance()` (NEW) | `instructions_test` |
| C-5 CPU manager | `cpu_manager.gd`: `STYLE_INSTRUCTIONS`, `_instruct()`, a banner line | `cpu_manager_test` |
| C-6 TACTICS page | `team_manager.gd`: 8 rows under the formations, ←/→ set them; `lineup.gd`: saved with the sheet, `Lineup.path` (tests point it elsewhere); `main.gd`: the match applies them | `lineup_test` |

Measured (Brugge, from `instructions_test`):

| Instruction | Effect |
|---|---|
| attacking | every line +9.4 m |
| defensive | −8.7 m to −9.5 m |
| width (narrow / normal / wide) | spread 34 / 45 / 54 m |
| back four without the ball (deep / normal / high) | 10.0 / 14.2 / 25.7 m from their own goal line |
| offside trap | +6.3 m more while their pass is on its way |
| average pass (short / normal / direct) | 13.6 / 19.9 / 24.7 m |
| time on the ball (slow / normal / fast) | 0.24 / 0.19 / 0.13 s |
| shooting range (patient / normal / on sight) | 16.6 / 20.8 / 25.0 m |
| tackling: slide and barge odds | ×0.4 easy, ×1.6 hard |

## Deviations from the plan (for your review)

- **C-2-AC3: the deep line is only about 4 m deeper.** The normal line without the ball is
  already 14 m from goal; 10 m deeper would put the back four in their own six-yard box.
- **C-2-AC4: the trap fires on any pass of theirs on its way,** not only a through ball. The
  ball doesn't record which kind of pass it is.
- **C-3-AC1 is measured as the average pass length, not "1.5× as many long balls".** In open
  play 63 % of passes already go over 20 m, so a 1.5× share can't be reached. Direct also
  looks for team-mates further away and short nearer (`pass_option`'s sight ±40 %): without
  that, no weight changes the length, because sight capped it. The human's passes are
  unchanged (`direct` = 0).
- **C-4-AC3: the odds are measured, not fouls over 20 runs.** Fouls follow from the slides and
  barges. 20 match runs would be slow and noisy, and the memory limit on parallel tests applies.
- **C-5: only mentality, tempo and line follow the CPU's style,** as the AC lists.
  - attack: attacking + fast;
  - defend: defensive;
  - sit back: defensive + deep.
  Pressing and the rest stay normal for the CPU.
- **C-6-AC3: no copy of the instructions in the cup save.** A cup tie reads the club's sheet
  (`Lineup.load_saved`), so the instructions already carry over. Indoors the sheet isn't used,
  so instructions are normal there.
- **The pitch drawing on the TACTICS page doesn't show the instructions' effect on the shape.**
  This could be a small follow-up.

## Retro

- **Rework:**
  - Golden values first came out different on each run, because of `_onside` and players
    moving. They are now taken with offside off.
  - Passing first worked the wrong way round: the length bonus changed whether to pass, not
    to whom.
  - In the kick-off shape, no level changes anything; the test now measures 6 moments of
    open play.
  - Two garbled test lines of mine (`... if false else ...`) were caught and fixed.
- **Full suite: 38 of 38 pass.**
  - The run first failed `cup_smoke_test`. The CPU's new instructions changed a result, and that
    exposed a timing bug in my EPIC A test: the bracket arrives on the second frame. Fixed.
- **Assumption check:** AS-4 held. Every instruction is a constant on an existing hook;
  `ai.gd` wasn't restructured.
- **Balance:** DoD 3 held. All the existing AI tests stay green, and "normal" equals the golden
  values. Real play with the instructions hasn't been playtested yet.

## TD items

- **TD-1:** `_label()` is still in 9 scripts.
- **TD-2 (new, S):** the instruction-level check is written twice: `Team.instruct` and
  `TeamManager._open`.
  - Extract it on a third copy (Rule of Three), e.g. in D's season save.
