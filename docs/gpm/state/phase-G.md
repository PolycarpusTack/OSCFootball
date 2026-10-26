# Phase summary: EPIC G, Tactic Slots in the match, 2026-10-26

Branch `feature/A-cup`, on top of EPICs A to F. Nothing has been committed yet.

## What was built

| Task | Files | Test |
|---|---|---|
| G-0 PREP: `Team.checked_instructions()` | `team.gd`; the team management screen uses it (TD-2's second copy, and the slots would have been the third) | `lineup_test`, `instructions_test`: green before and after |
| G-1 Slots on the tactics page | `team.gd` `TACTICS`, `tactics`, `tactic`; `lineup.gd` `TACTIC_DEFAULTS`, `tactics()`, saved with the sheet; `team_manager.gd`: keys 1–4 pick the slot to edit, a strip of the 4 above the pitch, the pitch shows the XI in that slot's formation | `tactics_test` |
| G-2 Switch in play | `main.gd` `switch_tactic()`, `_tactic_keys()`, `TACTIC_COOLDOWN`; the formation is taken up in `_stoppage_news()` after the subs. `human.gd` `tactic_1` … `tactic_4` (1–4, keypad 1–4); `controls_menu.gd` rows for them (30 px rows) | `tactics_test` |
| G-3 HUD | `main.gd` `_tactic_label`, after the clock | `tactics_test` |

## Deviations from the plan (for your review)

- **The slot names are fixed** (BALANCED, ATTACK, DEFEND, ALL OUT). G-1 says "named"; renaming
  would need text entry, which no screen has yet. What's in each slot is yours to edit.
- **No gamepad switching.** The objective mentions "d-pad up + direction", but the d-pad moves
  the player. The keys are keyboard only, and the Controls screen says so. A pad chord would
  need its own decision (e.g. hold LB + a face button).
- **The slot to edit is picked with keys 1–4**, not with a row on the page. That keeps the page's
  rows as they were and uses the same keys as the match.
- **Slot 1 is the team sheet itself.** Its formation decides how the XI is lined up. Another
  slot's formation re-places the same eleven (best fit), as the CPU manager's formation changes
  do.
- **A switch back to a slot with the formation already on the pitch** waits for nothing; one with
  another formation waits for the stoppage, and "BRU: 5-3-2" shows on the banner then.
- **The AI sides don't switch slots.** The CPU manager keeps its own style logic (EPIC C).

## Retro

- **Full suite: 42 of 43 in the run; `air_test` then passed twice alone:**
  - `tactics_test` is the new test.
  - `air_test` failed once in the paired run ("winger out wide: crossed false"; the striker's
    states show the play went on past the cross) and passed on two reruns alone. Its waits are in
    real time, so a loaded machine can change who reaches the ball first.
  - Not caused by G as far as I can tell (no AI path reads the slots), but I haven't proven
    that. If it recurs, it's worth a seeded rewrite.
- **Rework:**
  - The test's tempo step: ATTACK starts at "fast", so one step down was "normal", the same as
    BALANCED. Two steps.
  - A multi-line lambda in the HUD code became a plain loop before the first run.
  - My background wait loop matched its own command line with `pgrep -f "godot --headless"`, so
    it never ended. Stopped it; I wait on the suite's own notification now.
- **TD:**
  - TD-2: the instruction check is now in `Team.checked_instructions()` and `Team.instruct()`.
    The latter keeps unlisted keys as they are (a partial update), which `lineup_test` checks,
    so they stay two.
  - The Controls screen has 13 rows at 30 px; the last ends at y ≈ 540, above the gamepad note.
