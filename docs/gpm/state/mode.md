# GPM mode (2026-10-26)

| Part | Mode | Why |
|---|---|---|
| Player side (`docs/gpm/backlog-player.md`) | **DELIVERY**, scaled down per Core §5.1 (solo developer, hobby game, easy to undo) | The engine is validated: 31 headless tests, match, AI, Chaos and referee all in place. New features land on known seams |
| Manager side (`docs/gpm/backlog-manager.md`) | **PROTOTYPE** | The domain isn't settled: the three questions in `game/docs/manager-mode.md` are unanswered |

## What "scaled down" means here

| Core rule | For OSCF |
|---|---|
| TDD | Mandatory. A failing headless test (`game/tests/<x>_test.gd`, extends SceneTree) before the code |
| Two Hats | Mandatory per task: FEATURE / REFACTORING / PREPARATORY |
| Feature flag | A match option or a `static var` toggle on `Match`, default as stated per task. A new mode is a new title-screen entry, which is its own flag |
| SLO | One for the whole game: **Match – frame time < 16.7 ms (60 fps) p95 over a 3-minute half**, on this machine. Checked by hand (the debug overlay) when a task touches the per-frame path |
| Observability, runbook | N/A: an offline single-player game. Each EPIC's "runbook" is how to reproduce and roll back: the test to run, the option to turn off |
| Idempotency | Save files: write to `<name>.tmp`, then rename. Loading twice gives the same state |
| Data governance | No PII. **Compliance flags:** never commit EA assets; never invent rosters, ratings, fees or wages; no Capcom move or character names; inspiration-game material is ideas only |
| Tests | Max 2 Godot processes at once (OOM) |
| Coverage | No % threshold: every Gherkin AC has a test, cited per task (`Satisfies AC`) |

## Working rules

- Read this file first. Commit only your own files: another session may share the tree.
- Push only when the user says so.
- Contract Snapshots (`docs/gpm/state/snapshots/`) are written after each accepted EPIC. There are none yet.

Reasoning-tier model: Opus-class (`claude-opus-5-5`).
