# OSCF backlog, part 1: the player side (and what both sides need)

Backlog Builder v5.1 + v5.2 extensions, mode **DELIVERY (scaled down)**: see `state/mode.md`.
Source: `INSPIRATION_FEATURES.md` (features found in 11 games, ranked by how many have them) and
the design reviews in `inspiration games/analysis/design-*.md`. Part 2, the manager side, is
`backlog-manager.md`. It starts when this part's shared EPICs (marked **[shared]**) are done.

Repo claims are marked (verified) when checked in the code on 2026-10-26, (NEW) for what a task
creates, and (ASSUMED) for the rest.

---

## Readiness decision

**PROCEED** for EPICs A and B; they are fully decomposed. EPICs C–O are decomposed to stories
with acceptance criteria. Per BB §3.4 and §10, their tasks are written after the retro of the
EPIC before them, because each one builds on what the last one proves.

Design health (BB §5): Clarity 3, Feasibility 3, Completeness 2 = **8/9**.
- Completeness loses a point because the content EPICs (H crowd chants, L commentary voice)
  need our own recordings, which don't exist yet. Those two are **HOLD**.
- No High risk without mitigation.

The solution design is the existing code plus `INSPIRATION_FEATURES.md`; there's no separate
design document. For the Architecture Overview, see `game/README.md` and `REVERSE_ENGINEERING.md`.

## Critical gaps

1. **Own audio** for crowd chants (H) and commentary voice (L): to be recorded or commissioned.
   They block H and L only.
2. **Competition rules for the Belgian cup.** The real Croky Cup format isn't in our data. The
   cup in A is a generic knockout of N clubs; we don't claim it's the real one.
3. **A second division** for promotion and relegation isn't in our data (one league, 18 clubs:
   `league.json`, verified). The season in D has no promotion or relegation.

## Domain glossary (enforced in code names from here on)

| Term | Meaning | In code |
|---|---|---|
| **Match** | One game on the pitch | `Match` (`main.gd`, verified) |
| **Club** | A league club from `league.json` / `squads.json` | `Match.home_club` strings (verified) |
| **Team** | A club's eleven on the pitch in a match | `Team` (verified) |
| **Competition** | A cup or a season: clubs, fixtures, results | `Competition` (NEW) |
| **Cup** | A knockout Competition in **Rounds** | `Cup` (NEW) |
| **Season** | A round-robin Competition with a **Table** | `Season` (NEW) |
| **Fixture** | Two clubs, a round, home/away, and later a **Result** | `Fixture` (NEW, a Dictionary) |
| **Tie** | A cup pairing over one or two legs | in `Cup` (NEW) |
| **Result** | Goals, scorers, cards, injuries of one fixture | `Result` (NEW, a Dictionary) |
| **Result Simulator** | Plays a fixture without the pitch, from ratings | `ResultSim` (NEW) |
| **Save** | One saved Competition in `user://saves/` | `SaveGame` (NEW) |
| **Team Instructions** | Mentality, passing, tempo, pressing, width, line, tackling, shooting | `Team.instructions` (NEW) |
| **Tactic Slot** | One of 4 stored Team Instructions + formation, switched in a match | `Team.slots` (NEW) |
| **Injury** | A footballer hurt: in the match (limping) and for N fixtures | `Footballer.injury` (NEW) |
| **Suspension** | Fixtures a footballer must miss | in `Competition` (NEW) |
| **Replay Buffer** | The last N seconds of positions and animation frames | `ReplayBuffer` (NEW) |
| **Weather** | Clear / rain / snow / wind for a match | `Match.weather` (NEW) |
| **Difficulty** | How sharp the AI plays; never changes ratings | `Match.difficulty` (NEW) |
| Energy, Segment, Special, Modifier, Strictness | As today | `Team.energy`, `Supers.SEGMENT`, `ChaosActions`, `Match.MODIFIERS`, `Match.STRICTNESS` (verified) |

## Assumptions ledger

| # | Assumption | Impact | Check |
|---|---|---|---|
| AS-1 | Results of matches nobody plays come from a rating-based random model, not a headless run of the real match | **High**: every competition depends on it | ADR-001; EPIC A's tracer bullet tests it on 1,000 runs |
| AS-2 | `squads.json` ratings (`overall`, `stats`) are enough to rate a side's attack, midfield, defence and keeper | High | A-1-T1 test: the stronger club wins more often than the weaker |
| AS-3 | Saving a JSON Competition plus team sheets is enough; a match is never saved halfway | Med | B: "quit during a match = that match is lost" is a stated rule |
| AS-4 | Team Instructions can be expressed as offsets on existing AI numbers (`hold_spot`, `presser`, `options` weights) without restructuring `ai.gd` | Med | C-1-T1 ST0 spike |
| AS-5 | A replay buffer of positions plus animation frames at 30 Hz for 10 s fits in memory and draws through the existing `stadium.to_screen()` path | Med | F-1-T1 ST0 spike |
| AS-6 | Inspiration games give ideas only; no data, text, art or sound is taken | High (legal) | A compliance flag on every story |

## ADR register (Core P6)

| ADR | Decision (proposed) | Alternatives | Status |
|---|---|---|---|
| ADR-001 Result Simulator | Goals per side ~ Poisson(λ), λ = 1.3 × (attack / (0.7 defence + 0.3 keeper))³ + 0.15 at home; line-weighted `overall`s of the default XI. Scorers by finishing × position; cards by aggression | (a) a headless real match at high speed: true to the engine, but slow for 8 fixtures a round; (b) a CM3-style minute-by-minute event roll: richer, M–L | **ACCEPTED** 2026-10-26 (A-1). Measured: Brugge (76) beats Lommel (66) about 66 % and loses 15 %; 3.0–3.1 goals a match in that pairing; equal sides: home 830 v away 640 wins in 2,000. Review when the league season (D) shows the season's goal totals |
| ADR-002 Save format | JSON in `user://saves/<slot>.json`, a `version` field, write tmp then rename; one slot per Competition, 3 slots | ConfigFile (fine for keys, clumsy for nested data); binary | **ACCEPTED** 2026-10-26 (B-1): `{version, saved, competition}`, `slot_N.json`; a .tmp then a rename. A bad file or another version reads as null, and the slot list says CAN'T READ THIS SAVE |
| ADR-003 Team Instructions | A small Dictionary of named levels per Team, read by `AI` where each decision already is | A strategy class per mentality (overengineering for 8 values) | **ACCEPTED** 2026-10-26 (C-1): `Team.INSTRUCTIONS` (levels, low to high) and `Team.instruction(key)` (steps from normal); `AI` holds one constant per hook. Golden values in `instructions_test` keep "normal" as it was |
| ADR-004 Replay | Record, don't re-simulate: a ring buffer of drawn state | Deterministic re-simulation (needs a seeded, frame-locked engine; too big a change) | **ACCEPTED** 2026-10-26 (F-1): `Replay`, a ring of 300 looks (10 s at 30 Hz); `Footballer.look()` / `show_look()` and `Ball.look()` / `show_look()` draw them through `stadium.to_screen()`. AS-5 held: 125–261 µs a kept frame (SLO 1 ms) |

---

## EPIC order (by how many games have it, then by dependency)

| EPIC | Feature | Games | Shared? | Size | Depends on |
|---|---|---|---|---|---|
| **A** | **Cup competition**, tracer bullet: bracket, simulated ties, a winner | 10/11 | [shared] | M | — |
| **B** | **Save / load** | 10/11 | [shared] | M | A |
| **C** | **Team Instructions the AI follows** | 10/11 | [shared] | M | — |
| **D** | **League season**: fixtures, table, scorers and cards tables, suspensions | 10/11, 10/11, 9/11 | [shared] | L | A, B |
| **E** | **Injuries** in the match and across fixtures | 9/11 | [shared] | S–M | — (D for across fixtures) |
| **F** | **Replays and highlights** | 8/11 | [shared] | M | — |
| **G** | **Tactic Slots in the match** | 8/11 | [shared] | S | C |
| **H** | Crowd chants | 8/11 | play | S–M | **HOLD**: own recordings |
| **I** | **Two-legged ties** | 8/11 | [shared] | S | A |
| **J** | **Weather and pitch condition** | 7/11 | [shared] | M | — |
| **K** | **Difficulty levels** | 6/11 | play | S | — |
| **L** | Commentary voice | 6/11 | play | L | **HOLD**: own recordings |
| **M** | **Cheap extras**: radar, game speed, other scores, sub alert, forfeit at 5, silver goal, practice scenarios and challenges, restart formations, set-piece jobs, context intros | 2–5/11 | play / shared | S each | per story |
| **N** | **Presentation from the FIFA design reviews**: rematch, half-time panel, strength bars, shoot-out tally, set-piece aid, quick match, banners and 7 more | 1–2 reviews | play | S each | per story |
| **O** | **Chaos extras**: big ball, invisible walls outdoors, laser ball, Chaos cards party mode | FIFA 96/97/RTWC 98, FIFA 06 | play | S each | — |

A, B, C, D, E, F, G, I, J are **[shared]**: the manager side needs them too, so they're
built here, before part 2.

---

## EPIC A — Cup competition (tracer bullet)

> **Status 2026-10-26: DONE.** A-1 … A-4 accepted; `result_sim_test`, `cup_test`, `cup_flow_test`,
> `cup_smoke_test` pass, and the existing suite stays green. Phase summary and retro:
> `state/phase-A.md`.

- **Objective:** play a cup from the title screen: draw, bracket, your ties on the pitch, the
  other ties simulated, a winner.
- **Tracer bullet?** YES: it cuts through every new layer (Competition model, Result Simulator,
  a bracket screen, the title-to-match-and-back flow) as thinly as possible.
- **Mode:** DELIVERY (scaled).
- **Definition of Done:**
  1. A 4-club cup is played from the title screen to a winner screen, with your ties played and
     the others simulated.
  2. `cup_test` and `result_sim_test` pass.
  3. The existing 31 tests stay green.
- **Business value:** the most common feature in the inspiration games (10/11), and the first
  thing that gives a match a reason. Metric: a cup can be finished in one sitting (4 clubs:
  2 matches).
- **Risks:**
  - The simulator gives silly scores (Med). Mitigation: A-1 tests the score distribution over
    1,000 runs against bounds.
  - The flow from the match back to the bracket breaks the title flow (Med). Mitigation: A-3
    uses the scene change the game already makes at full time.
- **SLO:** N/A (no per-frame code). The bracket screen opens < 0.5 s.
- **ADRs:** ADR-001.
- **Smoke test story:** A-4.
- **Runbook:** `godot --headless --path game -s res://tests/cup_test.gd`. Rollback: the title
  entry is the flag; remove it and the rest is dormant code.
- **Compliance:** no real cup branding or format claimed; generic "OSCF CUP".

### A-1 Result Simulator

As a **player in a cup**, I want the ties I don't play to have believable results, so that the
bracket feels real. Value 3, priority 5, size M.

- **A-1-AC1:** Given two clubs from `squads.json`, when one fixture is simulated, then the
  Result has goals ≥ 0 for each side and a scorer, from that club's XI, for every goal.
- **A-1-AC2:** Given a club whose XI is clearly stronger (average `overall` +8), when 1,000
  fixtures are simulated, then it wins more than it loses, and the average total goals is
  between 2.0 and 3.5.
- **A-1-AC3:** Given a knockout fixture level after 90 minutes, when simulated, then the Result
  has extra time and, if still level, a shoot-out winner (never a draw).
- **A-1-AC4 (error):** Given a club name not in `squads.json`, when simulated, then it fails
  loudly (`push_error`) and returns an empty Result; no crash.
- **A-1-AC5:** Given the same seed, when simulated twice, then the Results are identical
  (needed by B for the save).
- INVEST ✓✓✓✓✓✓ · DoR **READY** · test data: the real `squads.json` (verified), read only.

**A-1-T1** — Build `ResultSim.play(home, away, knockout, rng) -> Result`

| Field | |
|---|---|
| Hat | FEATURE |
| Satisfies AC | A-1-AC1 … AC5 |
| Required interfaces | `squads.json` per club: a list of `{name, position, overall, stats{finishing, aggression, gk*…}}` (verified). Out: `Result = {home_goals, away_goals, scorers: [[side, name, minute]], cards: [[side, name, colour]], et: bool, pens: [h, a] or []}` (NEW) |
| Abstraction check | The XI: reuse `Lineup.squads()` and the static `Lineup.auto_pick(squad, formation)` (verified, `lineup.gd:23`, `:43`), and `Lineup.checked()` for a saved sheet. No second picker |
| Sub-tasks | **ST0**: none required (the picker is already static). **ST1 FEATURE**: `result_sim_test.gd` (AC1–5), red. **ST2 FEATURE**: `scripts/result_sim.gd`: λ = base 1.3 × (attack / opposing defence)^k + home 0.15 (ADR-001), Poisson draw with `rng`, scorers weighted finishing × (FW 3, MF 1.5, DF 0.5), cards by aggression. **ST3 REFACTORING**: cleanup: none expected (one new file); justify or tidy |
| Quality gates | AC2's bounds pass on 3 different seeds |
| Feature flag | None needed: nothing calls it until A-3 |
| Rollback | Delete `result_sim.gd` |
| Hand-off | `ResultSim.play` contract → snapshot after EPIC A |
| Pull gate | `squads.json` still has `overall` and `stats.finishing` per player |
| Unblocks | A-2-T1 |
| Confidence | Med (2): the k exponent is tuned by AC2 |
| Execution | SEQUENTIAL |

### A-2 Cup model and draw

As a **player**, I want to pick how many clubs (4, 8 or 16) and my club, and get a random draw,
so that each cup is different. Value 3, priority 4, size S.

- **A-2-AC1:** Given 8 clubs and a seed, when the cup is drawn, then there are 4 ties in round 1,
  each club exactly once, and my club in one of them.
- **A-2-AC2:** Given all round-1 Results, when the round is closed, then round 2 has the winners
  paired in bracket order (winner of tie 1 vs tie 2, …).
- **A-2-AC3:** Given the final's Result, when closed, then `Cup.winner` is set and `Cup.done` is
  true.
- **A-2-AC4 (alt):** Given 2 players, when drawn, then both human clubs are flagged and are never
  simulated.
- **A-2-AC5 (error):** Given a size that's not 4, 8 or 16, then `Cup.new` refuses (push_error,
  returns null).
- DoR **READY**.

**A-2-T1** — `Cup` (`scripts/cup.gd`, NEW): `draw(clubs, humans, rng)`, `next_fixture()`,
`record(fixture, result)`, `close_round()`, `winner`, `to_dict()` / `from_dict()` (for B).

- Hat: FEATURE. Satisfies AC: A-2-AC1 … AC5.
- Sub-tasks: ST0: none required. ST1: `cup_test.gd` (AC1–5) red. ST2: the implementation; the
  simulator is called for non-human fixtures in `close_round()`. ST3 REFACTORING: cleanup.
- Pull gate: A-1's `Result` contract unchanged.
- Unblocks: A-3-T1. Confidence High (3). SEQUENTIAL.

### A-3 Bracket screen and the flow

As a **player**, I want to see the bracket, then play my tie, then come back to the bracket with
everything updated, so that I follow my way to the final. Value 3, priority 4, size M.

- **A-3-AC1:** Given the title screen, when I choose CUP, then a setup screen asks for size and
  club, and then the bracket shows round 1.
- **A-3-AC2:** Given my next fixture, when I press Enter on the bracket, then the match starts with
  `Match.knockout = true` and the two clubs (`Match.home_club` / `away_club`, verified).
- **A-3-AC3:** Given full time of a cup match, when the stats screen is closed, then the game
  returns to the bracket, the Result is recorded from `MatchStats` (scorers, cards), the other ties
  are simulated, and the next round shows.
- **A-3-AC4 (alt):** Given I'm knocked out, then the bracket says so and offers "simulate to the
  end" or "back to title".
- **A-3-AC5:** Given the cup is done, then a winner screen shows the winner and the path (each
  round's result).
- DoR **READY**. External dependency: none. Compliance: generic cup name and our own art only.

**A-3-T1** — `scripts/cup_screen.gd` (NEW) + the title entry + the full-time return.

- Hat: FEATURE. Satisfies AC: A-3-AC1 … AC5.
- Required interfaces:
  - `title.gd` `_show_mode()` (verified) adds CUP.
  - The full-time path in `main.gd` (State.FULL_TIME, verified) learns a static
    `Match.competition` (NEW): when set, closing the stats screen hands the Result back.
  - `MatchStats` events (verified: `_on_event`) give scorers and cards.
- Sub-tasks:
  - ST0 PREPARATORY: extract "what happens after the full-time screen" in `main.gd` into one
    function, with no change in behaviour; `knockout_test` and `stats_test` stay green.
  - ST1: `cup_test` flow cases (AC2, AC3 with a forced result), red.
  - ST2: the screen and the wiring.
  - ST3 REFACTORING: cleanup.
- Feature flag: the CUP entry on the title screen (default ON once A-4 passes; OFF before).
- Rollback: remove the entry.
- Pull gate: `Cup` API from A-2; the full-time flow still ends in the stats screen.
- Unblocks: A-4-T1. Confidence Med (2): the scene flow. SEQUENTIAL.

### A-4 Smoke test: a whole cup

As the **developer**, I want one test that plays a 4-club cup end to end (my two matches in
autoplay at high speed, the rest simulated), so that the flow can't silently break. Value 2,
size S.

- **A-4-AC1:** Given a 4-club cup with the human on autoplay, when run headless, then a winner is
  set within the test's time limit and no errors are logged.

**A-4-T1** — `tests/cup_smoke_test.gd`, using `Match.autoplay` (verified) and `half_minutes = 2`.
Hat: FEATURE (test only). Satisfies AC: A-4-AC1. Unblocks: END OF STORY SEQUENCE; EPIC A retro.

---

## EPIC B — Save / load [shared]

> **Status 2026-10-26: DONE.** B-1 accepted; `save_test`, plus `cup_smoke_test` (the bracket saves).
> Summary and retro: `state/phase-B.md`.

- **Objective:** a cup (and later a season) survives quitting the game.
- **Tracer bullet?** NO. **Mode:** DELIVERY (scaled).
- **Definition of Done:**
  1. A cup saved after round 1 loads to the same bracket, the same next fixture and the same
     random draws to come.
  2. A corrupt or old save is refused with a message, never a crash.
  3. `save_test` passes.
- **Value:** 10/11 games; it makes D (a season) possible.
- **Risks:** losing a save on a crash during the write (Med). Mitigation: tmp file + rename
  (ADR-002).
- **ADR:** ADR-002. **Runbook:** `save_test`; saves live in `user://saves/`, and deleting a file
  is the reset.

### B-1 Save and load a Competition

As a **player**, I want to save my cup and carry on later, so that I don't need to finish it in one
sitting. Value 3, priority 5, size M.

- **B-1-AC1:** Given a cup after round 1, when saved to slot 1 and loaded, then
  `Cup.to_dict()` before equals after, including the RNG state.
- **B-1-AC2:** Given a save is being written, when the write fails halfway (simulated), then the
  previous save in that slot is untouched.
- **B-1-AC3 (error):** Given a file with a bad `version` or invalid JSON, when loaded, then the
  load menu shows "Can't read this save" and the game carries on.
- **B-1-AC4:** Given the bracket screen, when I quit to the title, then it autosaves to the cup's
  slot.
- **B-1-AC5 (alt):** Given a match in progress, when I quit, then that match is lost (stated in
  the pause menu) and the save is of the round before it (AS-3).
- **B-1-AC6:** Given the title screen, when I choose CONTINUE, then a list of the 3 slots shows
  the competition, my club, the round and the date.
- DoR **READY**. Idempotency: the save key is the slot; saving twice gives the same file.

**B-1-T1** — `SaveGame` (`scripts/save_game.gd`, NEW): `save(slot, competition)`,
`load(slot) -> Competition or null`, `list() -> Array`.

- Hat: FEATURE. Satisfies AC: B-1-AC1, AC2, AC3.
- Abstraction check: `Human._save()` and `Lineup` write `user://` already (verified). This is the
  second and third writer. Rule of three: extract a tiny `write_atomic(path, text)` helper in ST3
  if all three now repeat it.
- Sub-tasks: ST0: none required. ST1: `save_test.gd` red (it uses `user://saves_test/` and deletes
  it, like `controls_menu_test`). ST2: the implementation. ST3 REFACTORING: the helper extraction
  above, if it qualifies.
- Pull gate: `Cup.to_dict()` / `from_dict()` exist (A-2).
- Unblocks: B-1-T2. Confidence High.

**B-1-T2** — The title CONTINUE entry, the slot list, autosave on leaving the bracket.

- Hat: FEATURE. Satisfies AC: B-1-AC4, AC5, AC6.
- Feature flag: CONTINUE shows only when a save exists.
- Unblocks: END OF STORY SEQUENCE; EPIC B retro.

---

## EPIC C — Team Instructions the AI follows [shared]

> **Status 2026-10-26: DONE** (awaiting the user's review). C-1 … C-6 are in; `instructions_test`,
> `cpu_manager_test` and `lineup_test` are extended. Deviations and retro: `state/phase-C.md`.

- **Objective:** a side's mentality, passing, tempo, pressing, width, defensive line (with
  offside trap), tackling and shooting change how its AI players play, measurably.
- **Mode:** DELIVERY. **ADR:** ADR-003.
- **Definition of Done:**
  1. Each instruction has a test that measures its effect (e.g. "attacking: average spot 8 m
     further up").
  2. The CPU manager sets instructions, not only formations.
  3. The default instructions leave today's play unchanged (all existing tests green).
- **Value:** 10/11 games. It improves every match against the AI, and it's step M.1 of the
  manager mode.
- **Risks:** balance drift: the AI gets worse with defaults (Med). Mitigation: DoD 3, plus
  `engine_test` must stay green.
- **SLO:** per-frame AI path: no measurable frame-time change (debug overlay).

| Story | Gherkin AC (summary) | Hook (verified) |
|---|---|---|
| **C-1** Instructions model + defaults (ST0 spike: AS-4) | AC1: a Team has `instructions` with 8 keys at "normal" by default. AC2: defaults give the same `hold_spot` as today (golden values) | `team.gd` |
| **C-2** Mentality + width + defensive line | AC1: attacking moves each line's average spot ≥ 8 m up, defensive ≥ 8 m back. AC2: wide/narrow change y spread ≥ 15 %. AC3: a high line holds the back four ≥ 10 m higher. AC4 (alt): offside trap on: the back line steps up as a through ball is played | `AI.hold_spot()`, `AI._zone_cost()`, `AI.defend_spot()` |
| **C-3** Passing + tempo + shoot on sight | AC1: direct gives long passes/crosses ≥ 1.5× the short ones, short the reverse. AC2: fast tempo cuts the time on the ball before a decision. AC3: shoot on sight stretches `shooting_range()` | `AI.options()`, `AI.choose()`, `AI._with_ball()`, `AI.shooting_range()` |
| **C-4** Pressing + tackling | AC1: high press sends a second presser within N m. AC2: stand off: no presser beyond our half. AC3: hard tackling raises slide/body-check odds and fouls (counted over 20 runs) | `AI.presser()`, `AI._maybe_slide()`, `AI._maybe_body_check()` |
| **C-5** CPU manager uses instructions | AC1: its "attack" style sets mentality attacking + tempo fast; "sit back" sets defensive + line deep. AC2: its decisions banner names the change | `cpu_manager.gd` `_choose_style()` (verified) |
| **C-6** Pre-match tactics page for the human | AC1: the team management screen gets a TACTICS tab with the 8 instructions. AC2: saved per club like the sheet (`user://`, as `Lineup` does). AC3: in a Competition, saved with it (B) | `team_manager.gd`, `lineup.gd` |

C-2…C-4 all write `ai.gd`, so they're **SEQUENTIAL**. One task per story, each ≤ 15k tokens.

**ST0 spike result (AS-4): HOLDS** (2026-10-26, from reading `ai.gd`). Every instruction is an
offset or a factor on a number that's already there:

| Instruction | Hook | Kind |
|---|---|---|
| mentality | `hold_spot()`: `base.x` | offset |
| width | `hold_spot()`: `spot.y` around 0.5 | scale |
| line, offside trap | `hold_spot()` for D, `defend_spot()` | offset; trap = step up on a through ball (new, small) |
| passing | `options()`: pass vs through-ball and cross worths | weights |
| tempo | `_with_ball()`: `think_timer` | factor |
| shooting | `shooting_range()` | factor |
| pressing | `presser()` / `think()` | second chaser; stand off: no chase beyond our half |
| tackling | `_maybe_slide()`, `_maybe_body_check()` | odds factor |

**C-1-T1** — `Team.INSTRUCTIONS` (key → its levels, low to high, "normal" in the middle; `line`
has a fourth level, "offside trap"), `Team.instructions` (all "normal" from `_init`),
`Team.instruction(key) -> int` (steps from normal: −1, 0, +1, and +2 for the trap).
- Hat: FEATURE. Satisfies AC: C-1-AC1, AC2.
- ST0: the spike above. ST1: `instructions_test.gd` red, with golden `hold_spot` and
  `shooting_range` values taken from today's code before any `ai.gd` change. ST2: the
  implementation. ST3: none.
- Pull gate: EPIC B done. Unblocks: C-2-T1. Confidence High.

**C-2-T1** — `hold_spot()` reads mentality, width and line; `defend_spot()` steps the back line
up on a through ball with the trap on. Hat: FEATURE. AC: C-2-AC1…AC4. ST1: extend
`instructions_test` (average spots per line, y spread). Golden values stay equal at "normal".
Unblocks: C-3-T1. Confidence Med (the trap's timing).

**C-3-T1** — `options()` weights from passing; `_with_ball()` think time from tempo;
`shooting_range()` from shooting. Hat: FEATURE. AC: C-3-AC1…AC3. ST1: counted over seeded
decisions (`choose()` on a set position). Unblocks: C-4-T1. Confidence High.

**C-4-T1** — Pressing in `presser()` / `think()`; tackling odds in `_maybe_slide()` and
`_maybe_body_check()`. Hat: FEATURE. AC: C-4-AC1…AC3. ST1: AC3 counted over 20 seeded runs.
Unblocks: C-5-T1. Confidence Med (fouls are noisy).

**C-5-T1** — `cpu_manager.gd`: each style sets instructions when it's chosen (`_choose_style`),
and the banner line names them. Hat: FEATURE. AC: C-5-AC1, AC2. ST1: extend
`cpu_manager_test`. Unblocks: C-6-T1. Confidence High.

**C-6-T1** — A TACTICS page on the team management screen: the 8 instructions, ◀▶ per row,
saved per club next to the team sheet (`Lineup`), and with the cup in B's save. Hat: FEATURE.
AC: C-6-AC1…AC3. ST0: read `team_manager.gd`'s page handling. Unblocks: END OF EPIC; C retro.
Confidence Med (screen layout).

---

## EPIC D — League season [shared]

> **Status 2026-10-26: DONE** (awaiting the user's review). D-0 … D-7 are in; `season_test` and
> `season_smoke_test` are new. Deviations and retro: `state/phase-D.md`.

- **Objective:** a Jupiler Pro League season of 34 rounds: your matches on the pitch, the others
  simulated, a live table, scorers and cards, suspensions.
- **Definition of Done:**
  1. A season can be played, saved and loaded to the end, with a champion.
  2. The table and the stats tables match the Results (a test recomputes them).
  3. Suspensions are served.
- **Risks:** a long season is tedious (Med). Mitigation: half length per season, and "simulate
  my match" per fixture (watch-or-skip, the manager side's question 1, is a stated later
  extension).
- **Compliance:** the 18 real clubs are in our data (verified `league.json`). There's no
  promotion or relegation (Critical gap 3).

| Story | Gherkin AC (summary) |
|---|---|
| **D-1** `Season` model: double round robin, 34 rounds | AC1: each club plays each other twice, home and away. AC2: no club plays twice in a round. AC3: `to_dict`/`from_dict` round-trips |
| **D-2** Table | AC1: 3/1/0 points; ordered by points, goal difference, goals scored. AC2: recomputed from Results equals the live table |
| **D-3** Season screen: table, fixtures and results, next match | AC1: shows the round, your next fixture, the table. AC2 (alt): "simulate my match" plays it through `ResultSim` |
| **D-4** Top scorers, cards, and the best-rated table | AC1: from Results and `MatchStats.rating()` (verified). AC2: ties are sorted by name |
| **D-5** Suspensions | AC1: a red card means the next fixture is missed. AC2: 5 yellows means 1 fixture (ASSUMED rule, an option). AC3: a suspended player isn't in the default XI and is greyed on the team sheet |
| **D-6** Other scores during your match | AC1: at goals in simulated fixtures of the same round, a banner "Latest: X 1-0 Y" (FIFA 99 / CM, B-list). Uses `Match.flash()` (verified) |
| **D-7** Season smoke test | AC1: a 4-club mini season in autoplay to a champion |

Tasks (written 2026-10-26, after C's retro). One file per model and screen, so they're
**SEQUENTIAL**.

**D-0-T1 PREPARATORY** — `Competition` (`scripts/competition.gd`, NEW), the base class of `Cup` and
`Season`.
- Shared fields: `name`, `clubs`, `humans`, `done`, `winner`, `rng`.
- `finish(f, result)`: record, then close the round. This replaces `CupScreen.finish_tie`.
- `status()` gives the round line for the slot list.
- `Competition.from_dict(d)` picks the class by `kind`.
- `Match.competition`, `SaveGame.save` and `load_slot` take a `Competition`.
- Hat: REFACTORING (no behaviour change). Justified now: the second kind of competition is this
  EPIC's. Gate: `cup_test`, `cup_flow_test`, `cup_smoke_test` and `save_test` green before and
  after.

**D-1-T1** — `Season` (`scripts/season.gd`, NEW): `create(clubs, humans, seed)` (an even number,
4–18, distinct clubs), and a circle-method double round robin with the second half mirrored.
- `next_fixture()`, `record()` (a draw is a result), `close_round()` (the others simulated, the
  cards booked, on to the next round, the champion after the last), `to_dict` / `from_dict`.
- Hat: FEATURE. AC: D-1-AC1…3. ST1: `season_test.gd` red. Unblocks D-2.

**D-2-T1** — `Season.table()`, recomputed from the Results every time, so there's no live copy to
drift. It ranks 3/1/0, then goal difference, then goals scored, then name. Hat: FEATURE. AC: D-2.
The test recomputes the table its own way.

**D-4-T1** — `Season.scorers()` and `Season.cards()`.
- Sorted by count, then name.
- Best rated: averages of `MatchStats.rating()`, for matches played on the pitch only. A
  simulated result has no ratings, so this is ASSUMED to be enough.
- Hat: FEATURE. AC: D-4.

**D-5-T1** — Suspensions.
- A red card means the next fixture is missed. 5 yellows mean 1 fixture missed (`YELLOW_BAN`, a
  const).
- `Season.unavailable(club)` gives the suspended names.
- `ResultSim.play` and the match pick their XI without them (`Match.unavailable`).
- The season screen lists your suspended players. The cup flow already skips the team
  management screen, so the "greyed on the team sheet" part shows on the season screen
  instead.
- Hat: FEATURE. AC: D-5.

**D-3-T1** — `SeasonScreen` (`scripts/season_screen.gd`, `scenes/season.tscn`, NEW).
- Setup: your club, the save slot.
- The table, the round's fixtures and results, and your next match.
- SPACE plays it, S simulates it; TAB shows the stats (D-4).
- SEASON on the title's ▲/▼. CONTINUE opens the right screen for a save.
- Hat: FEATURE. AC: D-3.

**D-6-T1** — When your match starts, the round's other fixtures are simulated, and their goals
flash in your match ("LATEST: X 1-0 Y", `Match.flash`) at their minutes. Hat: FEATURE. AC: D-6.

**D-7-T1** — `season_smoke_test`: a 4-club mini season on autoplay, to a champion, saved by the
screen. Unblocks: END OF EPIC; D retro.

---

## EPIC E — Injuries [shared]

> **Status 2026-10-26: DONE** (awaiting the user's review). E-1 … E-4 are in; `injury_test` is new.
> Deviations and retro: `state/phase-E.md`.

- **Objective:** a hard foul or a heavy collision can injure a player: he limps (slower, lower
  skill) or must go off; in a competition he misses N fixtures.
- **Definition of Done:**
  1. Injury odds follow the foul's severity and the Chaos referee's state.
  2. The AI subs an injured man.
  3. The injury is carried in a Competition.
- **Compliance:** our own art (a limp from existing frames first: `stumble` / `fall`, verified
  in ROADMAP A).

| Story | Gherkin AC (summary) |
|---|---|
| **E-1** In-match injury | AC1: a foul from behind has odds X, a normal one Y (counted over many). AC2: injured gives `top_speed()` × 0.8 and `skill()` × 0.85 (verified functions). AC3: Classic and Chaos both; off with the option |
| **E-2** Must go off | AC1: a severe injury: the ball goes out, a sub is forced (human: the subs screen opens; AI: `_pick_subs`). AC2 (alt): no subs left: plays on limping |
| **E-3** Across fixtures | AC1: Result carries injuries; `Competition` counts down per fixture. AC2: the team sheet shows "out: 2" |
| **E-4** Sub alert | AC1: "X may need substituting" banner when tired or injured (FIFA 99, B-list) |

Tasks (written 2026-10-26, after D's retro). `main.gd` throughout, so they're **SEQUENTIAL**.

**E-1-T1** — `Footballer.injury` (0 fit, 1 a knock: limps, 2 severe: must go off).
- Injured: `top_speed()` × 0.8. `skill()` reads the rating × 0.85 *before* mapping it, so stats
  where lower is better (e.g. reactions → think time) get worse too, not better.
- `Match.injure_odds(by, victim, from_behind, unseen)`:
  - base odds `INJURY` {behind 0.12, front 0.04, body check 0.03} × the fouler's aggression;
  - × 1.5 when the Chaos referee didn't see it (the referee's state);
  - 1 in 4 injuries is severe.
- The INJURIES match option (on by default).
- Hat: FEATURE. AC: E-1. ST1: `injury_test.gd` red.

**E-2-T1** — At a stoppage, a severely injured man goes off.
- For a side no human controls, the best bench player for his slot (`CpuManager._value`) is
  queued before the subs are made.
- For a human side, the substitutions screen opens (`PauseMenu.open_subs()`), once per injury.
- With no subs left, he plays on limping.
- Hat: FEATURE. AC: E-2.

**E-3-T1** — The result carries `injuries` [{side, name, fixtures}] (a knock: 0, severe: 1–3).
- `ResultSim` injures too: at most one man a side, 6 % a match.
- `Competition` keeps `injuries` {club: {name: fixtures}}, counted down per fixture in both
  Cup and Season, and `unavailable()` includes them.
- The season screen shows "INJURED: X (2)".
- Hat: FEATURE. AC: E-3.

**E-4-T1** — "X MAY NEED SUBSTITUTING" on the banner when one of a human's players is injured,
or worn out (`condition` < 0.25), once per player. Hat: FEATURE. AC: E-4.

---

## EPIC F — Replays and highlights [shared]

> **Status 2026-10-26: DONE** (awaiting the user's review). F-1 … F-4 are in; `replay_test` is new.
> F-5 stays HOLD (your call). Deviations, the AS-5 verdict and the retro: `state/phase-F.md`.

- **Objective:** an instant replay after goals (and on demand from the pause menu), goals saved
  as highlights, and a highlights package after the match.
- **ADR:** ADR-004. **Spike:** AS-5 (memory and drawing path) as F-1's ST0.
- **SLO:** recording adds < 1 ms per frame.

| Story | Gherkin AC (summary) |
|---|---|
| **F-1** Replay Buffer (ST0 spike: AS-5) | AC1: the last 10 s of positions, facings, animation frames, ball xyz kept at 30 Hz. AC2: memory bounded |
| **F-2** Instant replay after a goal | AC1: after GOAL, the replay plays at 0.5×, skippable with any key. AC2: an "R" mark on screen. AC3: Thunder Strike slow-mo still works |
| **F-3** Replay from the pause menu | AC1: rewind, play, slow, step |
| **F-4** Highlights after the match | AC1: each goal and big save kept (6 s each); a "HIGHLIGHTS" entry on the full-time screen plays them in order. Needed by the manager side's "highlights only" |
| **F-5** Save a goal | AC1: name a goal; kept in `user://highlights/`; a "Goal of the season" list in a Competition (PM99, CM) |

Tasks (written 2026-10-26, after E's retro and the TD-1 servicing). They're **SEQUENTIAL**.

**F-1-T1** (ST0 spike AS-5, then the feature) — `Replay` (`scripts/replay.gd`, NEW), a Match child.
- `record()` runs every other physics frame (30 Hz). It keeps a ring of 300 frames:
  [camera focus, `Ball.look()`, [[actor, `Footballer.look()`]…]].
- A look is drawing *inputs* (position, anim, anim time, loop, facing, Chaos rotation and lift,
  visible), not textures. That makes it small and serialisable for F-5.
- `Footballer.show_look()` and `Ball.show_look()` draw a recorded look without touching the
  simulation.
- Hat: FEATURE. AC: F-1. ST1: `replay_test.gd` red. The spike measures memory and the
  recording time per frame against the SLO (< 1 ms).

**F-2-T1** — When GOAL's pause runs out, an instant replay of the last 6 s at 0.5× plays (the tree
is paused, "R" on screen, any key skips), then the kick-off.
- `Match.replays_on`: the REPLAYS option. No instant replay on autoplay (tests, attract mode).
- Hat: FEATURE. AC: F-2.

**F-3-T1** — REPLAY in the pause menu.
- Space plays or pauses; ←/→ steps a frame (holding it moves on).
- S cycles 0.25, 0.5 and 1×; Esc goes back to the menu.
- Hat: FEATURE. AC: F-3.

**F-4-T1** — Highlights: at each goal, and at each save from a shot, the last 6 s are copied
into `Replay.highlights` (a goal's copy is taken when the replay would start, so the
celebration isn't in it).
- H on the full-time screen plays them in order.
- Hat: FEATURE. AC: F-4.

**F-5** — Saving a goal to disk needs the kits and the players' art put back together outside
the match. It's an L on its own and needs a decision on scope, so it's **HOLD** until F-1…F-4
are reviewed.

---

## EPIC G — Tactic Slots in the match [shared]

> **Status 2026-10-26: DONE** (awaiting the user's review). G-0 … G-3 are in; `tactics_test` is new.
> Deviations and retro: `state/phase-G.md`. **Feature work pauses here** (the user's decision): next
> come the polish slices (menus, fonts, commentary; then the match engine for Pixel and 3D).

- **Objective:** 4 stored Tactic Slots per side (formation + Team Instructions), switched during
  play on keys 1–4 (pad: d-pad up + direction) with a short banner, like FIFA 99's IGM and
  PM99's four tactics. This is the base of the manager side's shouts.
- **Depends on:** C.

| Story | Gherkin AC (summary) |
|---|---|
| **G-1** Slots on the tactics page | AC1: 4 named slots (default: Balanced, Attack, Defend, All out); edit each |
| **G-2** Switch in play | AC1: key 1–4 switches at once; banner "TACTIC: ATTACK". AC2: 5 s cooldown. AC3: formation changes wait for the next stoppage, instructions apply at once. AC4: rebindable in Controls (`Human.rebind`, verified) |
| **G-3** HUD | AC1: the current slot is shown small by the score |

Tasks (written 2026-10-26, after F's retro). They're **SEQUENTIAL**.

**G-0** (PREPARATORY, Rule of Three) — `Team.checked_instructions(levels)`: every instruction, the
valid levels kept, the rest "normal". The check is in `Team.instruct` and the team management
screen (TD-2), and the slots would be the third copy.
- Hat: REFACTORING. Guard: `instructions_test`, `lineup_test` green before and after.

**G-1-T1** — `Team.TACTICS` (BALANCED, ATTACK, DEFEND, ALL OUT); `Lineup.tactics(sheet, formation)`:
the sheet's 4 slots, checked, with defaults. Slot 1 is the sheet's own formation and
instructions; ALL OUT defaults to 4-3-3 outdoors. Saved in `lineups.json` with the sheet.
- The TACTICS page gets a SLOT row (←/→); the formation and instruction rows edit that slot.
- Hat: FEATURE. AC: G-1. ST1: `tactics_test.gd` red.

**G-2-T1** — `Match.switch_tactic(t, i)`: the slot's instructions at once, its formation at the
next stoppage (after the substitutions, so a pending sub's slot still means the same man),
TACTIC_COOLDOWN 5 s, banner "TACTIC: ATTACK".
- `Human.ACTIONS` gets `tactic_1` … `tactic_4`: keys 1–4 (player 2: keypad 1–4), rebindable on the
  Controls screen (rows tightened to fit 13).
- Hat: FEATURE. AC: G-2.

**G-3-T1** — The slot's name, small, after the clock in the score panel (each human side's).
- Hat: FEATURE. AC: G-3.

---

## EPIC H — Crowd chants (HOLD)

- **HOLD** until we have our own recordings (Critical gap 1). Design is ready: a pool of chants
  rotated, swelling near goal, a roar on goals, home/away by club, crowd mood (boos when losing,
  CM4) feeding the Chaos energy at home. ROADMAP 4.2.

## EPIC I — Two-legged ties [shared]

| Story | Gherkin AC (summary) |
|---|---|
| **I-1** Two legs in `Cup` | AC1: a two-leg option per round; leg 2 starts with the aggregate on screen. AC2: aggregate, then away goals (option), then extra time and penalties in leg 2. AC3: the simulator plays both legs |

## EPIC J — Weather and pitch condition [shared]

- **Objective:** clear, rain, snow and wind, plus dry, damp and muddy pitches, change how the ball
  and the players move. CM4's weather events (floodlight failure, abandoned matches) arrive as
  Chaos modifiers.
- **SLO:** particles and tint stay within the 60 fps budget.

| Story | Gherkin AC (summary) |
|---|---|
| **J-1** Weather option + visuals | AC1: match options WEATHER: clear / rain / snow / random. AC2: tint and particles in our own art; an orange ball in snow |
| **J-2** Ball physics | AC1: wet means rolling friction −25 % and a skid on the first bounce; mud means friction +30 % (`ball.gd`). AC2: wind adds a small drift to lofted balls only |
| **J-3** Footing | AC1: rain or snow adds turn slips: stumble odds on sharp turns at speed. AC2: tests compare against clear weather |
| **J-4** Chaos weather events | AC1: Chaos only: floodlight failure (30 s dark vignette), a sudden downpour mid-match. AC2: a modifier toggle |
| **J-5** In the simulator | AC1: heavy weather lowers λ a little for both sides |

## EPIC K — Difficulty levels

| Story | Gherkin AC (summary) |
|---|---|
| **K-1** Option: EASY / NORMAL / HARD / CHAOTIC | AC1: scales the AI's reaction delay, `AI.decisions()` (verified), shot accuracy and keeper reach, **never** the ratings. AC2: NORMAL equals today. AC3: a measured win rate against autoplay (easy > normal > hard) |
| **K-2** Action / simulation switch (FIFA 96) | AC1: one setting for game feel: ball speed, player acceleration, assist strength. Default as today |

## EPIC L — Commentary voice (HOLD)

- **HOLD**: own recordings. The design is ready: the text ticker (`commentary.gd`, verified)
  already chooses the lines. Voice adds a clip per line, with club names recorded separately and
  joined (RTWC 98 idea). Context intros by table position (FIFA 96) are M-12, text first.

## EPIC M — Cheap extras (S each)

Each is one story. Order by value and effort:

| Story | Feature (seen in) | Gherkin AC (summary) |
|---|---|---|
| **M-1** | **Game speed** Normal / Fast / Fastest (FIFA 99, FIFA 06) | AC1: an option scaling `Engine.time_scale` (1.0 / 1.25 / 1.5) without changing the clock's match minutes; Thunder slow-mo still relative |
| **M-2** | **Radar** (RTWC 98, FIFA 99, FIFA 06) | AC1: a small pitch overlay in a corner, dots in kit colours, toggle key; uses the debug overlay's drawing (verified `debug_overlay.gd`) |
| **M-3** | **Forfeit at 5 sent off** (FIFA 99) | AC1: when a side has 6 players left, the match ends, awarded 2-0 or the actual score if wider; banner + commentary |
| **M-4** | **Silver goal** (CM 03/04) | AC1: the knockout option EXTRA TIME: golden / silver / full |
| **M-5** | **Practice scenarios with best times** (5/11) | AC1: a PRACTICE menu with corners, free kicks, penalties, and Chaos drills (land a Fireball, Laser Pass to a runner); best times in `user://` (ROADMAP 5.2) |
| **M-6** | **Scenario challenges** (FIFA 06) | AC1: "they lead 2-0 at 70', win"; a list of 10, built from match settings only; stars for done |
| **M-7** | **Restart formations** (FIFA 96) | AC1: the attacking side moves 2 men into the box at corners, the defence marks zones; different layouts for kick-off, corner, free kick |
| **M-8** | **Set-piece jobs** (CM4, PM99) | AC1: corners have roles: near-post runner, far post, edge of the box, keeper blocker; set on the tactics page |
| **M-9** | **Ambient animations** (PM99) | AC1: at stoppages, idle players do small animations (tie a boot, hands on hips, wave for the ball) in our own art; art first |
| **M-10** | **Pre-match intro line by context** (FIFA 96) | AC1: the ticker's first line depends on mode and table (leader, derby, cup final) |
| **M-11** | **"Latest scores"** | see D-6 |

## EPIC N — Presentation from the FIFA design review

From the two design reviews: `inspiration games/analysis/design-fifa96-98.md` and
`design-fifa99-06.md`. Their two top-10 lists are merged, and duplicates are counted.

**"In our style"** for every story means:
- our own art;
- the Chaos HUD look (bold `#ffe34d` with a black outline, segments, "LV / MAX!");
- FIFA 96's top-down pixel feel;
- no EA layouts copied, only the idea.

Ideas that are already a story elsewhere:
- goal replay → F-2;
- substitution prompts → E-4;
- tactic slots with an icon → G-1 / G-3;
- radar → M-2 (optional; the 96–98 review advises against it as a default);
- the loser picks a card → O-4.

| Story | Idea (reviews) | Gherkin AC (summary) | Size |
|---|---|---|---|
| **N-1** | **Rematch / swap sides** after full time (both) | AC1: the stats screen offers REMATCH, SWAP SIDES, NEW TEAMS, TITLE. Today it goes straight back to the title (verified, `main.gd:2470`) | S |
| **N-2** | **Half-time panel** (both) | AC1: at HALF_TIME, a recap panel: score, scorers, shots, possession, cards, from `MatchStats` (verified) | S |
| **N-3** | **Strength bars on team select** (both) | AC1: ATT / MID / DEF bars from the XI's ratings (the same numbers as `ResultSim`, A-1). Bars, not stars: none of the 96–98 games used stars | S |
| **N-4** | **Shoot-out tally** (96–98) | AC1: 2 × 5 boxes, ✓ / ✗, next kicker highlighted, from `Match.shootout` (verified); sudden death adds boxes | S |
| **N-5** | **Card chip by the name** (96–98) | AC1: a yellow/red chip beside the player name label while he's on the ball, and in the sub screen | S |
| **N-6** | **Set-piece aid** (both: landing target, "24 m" tag) | AC1: at free kicks, a distance tag to goal in metres; at corners and free kicks, a faint landing ring for the aim (Classic: an option) | S |
| **N-7** | **Quick match + random clubs** (99/06) | AC1: QUICK MATCH on the title: last-used clubs and options, one press. AC2: R on team select picks random clubs | S |
| **N-8** | **More caption banners** (99/06; event captions are in 6/11) | AC1: banners for hat-trick, equaliser, winner in the 90th, scorcher (shot speed), time wasting, clean sheet; via `Match.flash()` (verified) | S |
| **N-9** | **Off-screen arrow** (99/06) | AC1: when your controlled player is off screen, an arrow at the edge in your colour | S |
| **N-10** | **Ticker icons** (96–98) | AC1: a small icon before each commentary line (ball, card, whistle, gloves, lightning for specials) | S |
| **N-11** | **Pre-match versus card** (96–98) | AC1: crests (when present), club names, "LIVE FROM <stadium>", and the referee with his mood face (the Chaos referee's temperament): 3 s, skippable | S–M |
| **N-12** | **Hotkeys + control legend** (96–98) | AC1: every menu shows its keys at the bottom; in the pause menu, keys jump straight to a page (subs, move list, tactics) | S |
| **N-13** | **Context celebrations and referee beats** (99/06) | AC1: the celebration depends on context (a late winner, a hat-trick, a Thunder goal); after a red card, the referee's short scripted beat; a toggle to skip these moments | M |
| **N-14** | **Shielding** (FIFA 06 controls) | AC1: a key held with the ball: the player turns his back to the nearest opponent; tackles from behind are fouls more often; he dribbles slower. **Open:** which key. With the ball, Q is already the skill move, so an ST0 decides the key with you | S–M |

Order: N-1, N-2, N-7, N-4, N-8 first (all S, seen every match), then the rest.

## EPIC O — Chaos extras

| Story | Feature (seen in) | Gherkin AC (summary) |
|---|---|---|
| **O-1** | **Big ball** (FIFA 96 Enhanced Play Modes) | AC1: a modifier: ball drawn ×2, radius ×1.5 for contact |
| **O-2** | **Invisible walls outdoors** (FIFA 96, RTWC 98) | AC1: a modifier: the indoor boards' rebound (verified, I.1 done) on an outdoor pitch, no throw-ins |
| **O-3** | **Laser ball** (FIFA 97) | AC1: a modifier: the super trail always on |
| **O-4** | **Chaos cards party mode** (FIFA 06 Cheap Shots) | AC1: in 2-player Chaos matches, every 15 match minutes the side behind is dealt a card (send the rival's best man off for 2 minutes, tire their side, freeze their keeper 5 s); played with a key, costs energy segments; the referee may notice (existing mood). The same cards become the manager side's dirty-tricks hand |
| **O-5** | **Forfeit, fights, dives in commentary** (CM4) | AC1: new ticker lines for Chaos events (dives seen or missed, a bust-up after a Grapple) |

---

## Validator summary (BB §9 + E5)

- **Structure:** a DAG. EPIC A is the tracer bullet. Every task in A and B has Unblocks and a Pull
  Gate. All tasks are ≤ 15k tokens.
- **Quality:**
  - Every story in A and B is READY. H and L are HOLD, with the reason given.
  - Every FEATURE task cites its AC IDs.
  - Every task has an ST0 (or "none required") and a REFACTORING tail.
  - The rule of three is cited, not "second".
  - Glossary terms are used throughout.
- **Testing:** one new headless test per story group. Smoke tests: A-4 for EPIC A, D-7 for
  EPIC D; the other EPICs add theirs when their tasks are written.
- **Risk & debt:** Medium risks have a mitigation. No TD items yet. The assumptions ledger is
  present, and High assumptions have checks.
- **Operations:** the SLO, runbook and flags follow the scaled rules in `state/mode.md`. There are
  no write paths besides saves (idempotent by slot).
- **Economics:** C–O are kept at story level until the retro (BB §3.4). No task spec is longer
  than its code.
