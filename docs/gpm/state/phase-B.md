# Phase summary: EPIC B, Save / load, 2026-10-26

Branch `feature/A-cup`, on top of EPIC A. Nothing has been committed yet.

## What was built

| Task | Files | Test |
|---|---|---|
| B-1-T1 `SaveGame` | `game/scripts/save_game.gd` (NEW, `SaveGame`): `save`, `load_slot`, `list`, `delete`, `path` | `save_test` (AC1–AC3, AC6, idempotent, delete) |
| B-1-T2 CONTINUE, slots, autosave | `cup_screen.gd`: a SAVE IN slot row, the CONTINUE slot list, a save each time the bracket shows, `describe()`, `any_saved()`. `title.gd`: CONTINUE on Up/Down once a save exists. `pause_menu.gd`: "QUIT TO TITLE (THIS TIE IS LOST)" in a cup | `save_test` (AC4), `cup_smoke_test` |

## Deviations from the plan

- **The save happens whenever the bracket shows, not when you leave it (AC4).** This covers the
  same ground and more: a crash, or a quit from the pause menu, still leaves the round before.
- **`load(slot)` is `load_slot(slot)`,** because `load` is a built-in in GDScript.
- **The slot is chosen on the setup screen.** It defaults to the first empty slot. A cup that is
  already running keeps the slot it has.
- **AC3: the message reads "CAN'T READ THIS SAVE"** in the slot list, in the uppercase style of
  the other menus.
- **ST3 (the `write_atomic` helper) was dropped.** `SaveGame` is the only writer that uses a tmp
  file and a rename: `Lineup` writes directly and `Human` uses ConfigFile. With one copy, the
  Rule of Three doesn't apply.

## Retro

- **Rework:**
  - The slot logic first moved a running cup to the first empty slot. It now does that only when
    no cup is running.
  - The smoke test wrote to the real `user://saves`. It now uses its own directory and cleans up.
- **Assumption check:** AS-3 held. The pause menu says the tie is lost.
- **Waste:** a re-import during a full-suite run made two tests fail spuriously
  ("anim_library compilation failed"). Never import while tests are running.

## TD items

- No new items. TD-1 (the `_label()` helper, now in 9 scripts) still stands.
