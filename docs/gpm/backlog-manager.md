# OSCF backlog, part 2: the manager side

Backlog Builder v5.1 + v5.2 extensions, mode **PROTOTYPE** (`state/mode.md`).

**Starts after** the shared EPICs of part 1 (`backlog-player.md`) are done:
- A Cup, B Save, C Team Instructions, D Season;
- E Injuries, F Replays and highlights, G Tactic Slots;
- I Two-legged ties, J Weather.

Sources: `game/docs/manager-mode.md` (the investigation), `INSPIRATION_FEATURES.md` and the
per-game analyses in `inspiration games/analysis/`.

---

## Readiness decision

**PROCEED with EPICs MA and MB** (the tracer bullet and the shouts): fully decomposed below.
Everything else is at story level.

**HOLD where the three open questions block** (`manager-mode.md` "Questions for you"):

| Question | Blocks |
|---|---|
| Q1 Watch every match, or also a text / radar view? | MA-4 (a text/radar view) |
| Q2 One match, or straight into a career? | EPIC MK (career) entirely, and the board's sacking (MF-3) |
| Q3 Chaos dose: called specials only, or cards and the touchline too? | EPICs MH, MI, MJ |

Design health: Clarity 2, Feasibility 3, Completeness 2 = **7/9**. That passes BB §5; the open
questions are recorded as gaps, not guessed.

## Critical gaps

1. Q1–Q3 above.
2. **No fees, wages or contracts in our data.** Transfers, wages and scouting stay out unless you
   decide on a points economy (FIFA 06 buys its staff this way) or fictional players. We never
   invent real players' values.
3. No second division: no promotion, relegation or job offers from other leagues.

## Domain glossary (adds to part 1's)

| Term | Meaning | In code |
|---|---|---|
| **Manager Match** | A Match where your side is AI-played and you manage | `Match.manager_side` (NEW) |
| **Watch Mode** | Full / highlights / result (later: text, radar) | `Match.watch` (NEW) |
| **Take Control** | Switch from managing to playing your side mid-match | (NEW) |
| **Shout** | A short-lived touchline nudge on a key, with a cooldown | `Shout` (NEW) |
| **Call** | A requested Special, carried out when `ChaosActions.fits()` says the moment is right | `Call` (NEW); `fits` (verified) |
| **Card** | A dirty trick dealt to a manager, played for energy | `Card` (NEW), shared with part 1's O-4 |
| **Board Confidence** | One 0–100 meter driven by results against a target | (NEW) |
| **Form** | A footballer's last 5 match ratings, averaged | (NEW), from `MatchStats.rating()` (verified) |
| **Morale** | A small modifier (−5…+5 % on decisions and stamina) from results and playing time | (NEW) |
| **Manager Discipline** | The manager's own temper meter, like `Footballer.discipline` | (NEW) |
| **Manager Role** | How much you manage: Touchline / Coach / Full (PM99's job levels) | (NEW) |

## Assumptions ledger

| # | Assumption | Impact | Check |
|---|---|---|---|
| AM-1 | Autoplay on one side only (the other side AI, as today) works without the human input paths | High | MA-1-T1 test |
| AM-2 | `Engine.time_scale` 2× / 4× keeps physics and rules stable | High | MA-2 test: same match stats spread at 1× and 4× (over 20 runs) |
| AM-3 | Morale and form as small modifiers never change the real ratings | High (compliance) | a test: ratings unchanged after a season |
| AM-4 | `think_ai()` can be narrowed to one requested Special without restructuring | Med | MC-1 ST0 spike |

## ADR register

| ADR | Decision (proposed) | Status |
|---|---|---|
| ADR-101 Manager Match | Reuse `Match` with one side flagged AI-played (`manager_side`); no second match class | PROPOSED, MA-1 |
| ADR-102 Shouts | Shouts are timed offsets on Team Instructions (part 1 C), not a new AI layer | PROPOSED, MB-1 |
| ADR-103 Morale | Modifiers on decisions/stamina only, capped ±5 %, never on ratings (AM-3) | PROPOSED, ME-1 |

---

## EPIC order (by how many games have it, then dependency; Chaos ones last since they're rare but ours)

| EPIC | Feature | Games | Size | Depends on | Status |
|---|---|---|---|---|---|
| **MA** | **Manager Match, tracer bullet**: your side AI-played, Watch Modes, speed, Take Control | 9/11 | M | C, F, G | READY |
| **MB** | **Shouts / touchline bar** | 8/11 (as tactics in match) | S | MA, G | READY |
| **MC** | **Player instructions + tactics editor** (positions, zones, runs, set-piece jobs) | 7/11 | M | C | READY at story level |
| **MD** | **Opposition report** | 6/11 | S | D | READY at story level |
| **ME** | **Form, morale, team chemistry** | 6/11 | S–M | D | READY at story level |
| **MF** | **Board Confidence** | 6/11 | S–M | D | MF-3 HOLD (Q2) |
| **MG** | **Manager Role** (Touchline / Coach / Full) | PM99 | S | MA | READY at story level |
| **MH** | **Called Specials** (Chaos) | ours | S–M | MA, MB | HOLD (Q3), most likely yes |
| **MI** | **Dirty-tricks Cards** (Chaos) | FIFA 06 Cheap Shots | M | O-4 (part 1) | HOLD (Q3) |
| **MJ** | **Manager Discipline and touchline ban** (Chaos) | CM 03/04 | S | MB | HOLD (Q3) |
| **MK** | **Half-time talk and manager dilemmas** | FIFA 06 | S–M | ME | HOLD (Q3) |
| **ML** | **Career**: seasons in a row, staff (a points economy), youth, awards, history | 5–7/11 | L | D, B | HOLD (Q2 + gap 2) |

---

## EPIC MA — Manager Match (tracer bullet)

- **Objective:** start a match as the manager of one side: it plays itself, you watch at 1×, 2×
  or 4×, change tactics at stoppages, and can Take Control.
- **Tracer bullet?** YES: it cuts through the title entry, a Match with one AI-played side,
  speed, the existing tactics and subs screens, and the stats screen.
- **Definition of Done:**
  1. A manager friendly plays from the title screen to the stats screen with no human input.
  2. 4× gives the same stats spread as 1× (AM-2).
  3. `manager_match_test` passes and the other tests stay green.
- **Risks:**
  - It's boring to watch (Med). Mitigation: speed and highlights-only (MA-3) in the tracer
    already; Shouts next (MB).
  - Physics at 4× (High → mitigated by AM-2's test; fall back to 2× max if it fails).
- **ADR:** ADR-101. **Runbook:** `manager_match_test`; the flag is the title entry.

### MA-1 One side AI-played

As a **manager**, I want my side to play by itself, so that I only manage.

- **MA-1-AC1:** Given `Match.manager_side = home`, when the match runs, then every home player is
  AI-driven, the away side is AI as usual, and no input moves a player.
- **MA-1-AC2:** Given a manager match, then the specials HUD and control prompts are hidden (as in
  `autoplay`, verified) and a manager HUD line shows instead: "TACTIC: BALANCED · SPEED 1×".
- **MA-1-AC3 (alt):** Given 2 players, then manager match isn't offered (one manager vs the CPU
  manager first).

**MA-1-T1** — `Match.manager_side` (NEW) on top of `autoplay` (verified).

- Hat: FEATURE. Satisfies AC: MA-1-AC1, AC2, AC3.
- Sub-tasks:
  - ST0 PREPARATORY: today `autoplay` is all-or-nothing. Split it into a per-team "AI-played"
    check in `_human_input` (verified, `main.gd`) with no change in behaviour; `smoke_test` and
    `two_player_test` stay green.
  - ST1: `manager_match_test` red.
  - ST2: the flag and the HUD line.
  - ST3 REFACTORING: cleanup.
- Pull gate: part 1's C (instructions) and G (Tactic Slots) are accepted.
- Unblocks: MA-2-T1. Confidence High.

### MA-2 Speed

- **MA-2-AC1:** Given a manager match, when I press `+` / `-`, then speed cycles 1× / 2× / 4×
  (`Engine.time_scale`) and the HUD shows it.
- **MA-2-AC2:** Given a stoppage, then the speed drops to 1× for the restart if "slow at
  stoppages" is on (default on).
- **MA-2-AC3:** Given 20 runs at 1× and 20 at 4×, then shots, goals and fouls per match differ by
  less than 20 % (AM-2).

**MA-2-T1** — Speed control.
- Hat: FEATURE. Satisfies AC: MA-2-AC1 … AC3.
- Abstraction check: Thunder slow-mo also sets `time_scale` (verified, ROADMAP). It multiplies,
  it doesn't overwrite: one `Match.speed` × the effect's factor.
- Unblocks: MA-3-T1.

### MA-3 Watch Modes: full / highlights / result

- **MA-3-AC1:** FULL: everything at the chosen speed.
- **MA-3-AC2:** HIGHLIGHTS: the match runs at 8× hidden, and each goal or big chance is shown from
  the Replay Buffer (part 1 F) with the clock and score.
- **MA-3-AC3:** RESULT: `ResultSim` (part 1 A) gives the result; straight to the stats screen.
- **MA-3-AC4:** Watch Mode is chosen per match before kick-off, and in a Competition per fixture.

**MA-3-T1** — Watch Modes. Hat: FEATURE. Satisfies AC: MA-3-AC1 … AC4. Pull gate: F-4
(highlights) accepted. Unblocks: MA-5-T1.

### MA-4 Text / radar view (HOLD: Q1)

- AC (if Q1 says yes): the pitch hidden, a CM-style ticker (`commentary.gd`, verified) plus the
  radar (part 1 M-2).

### MA-5 Take Control (PM99, FIFA 06 "Intervene")

- **MA-5-AC1:** Given a manager match, when I press the special key twice, then my side switches
  to human control from the next stoppage, with a banner.
- **MA-5-AC2:** Given I took control, when I press it again, then it hands back to the AI.
- **MA-5-AC3 (alt):** In a Competition, Take Control is allowed (a setting: "manager purist" turns
  it off).

**MA-5-T1** — Hat: FEATURE. Satisfies AC: MA-5-AC1 … AC3. Unblocks: MA-6-T1.

### MA-6 Smoke test

**MA-6-T1** — A manager friendly at 4×, kick-off to stats screen, no errors. Satisfies: the EPIC's
DoD. Unblocks: END OF STORY SEQUENCE; retro.

---

## EPIC MB — Shouts / touchline bar

- **Objective:** six Shouts on the number keys that nudge the side for 60–90 s, with cooldowns,
  carried out as well as the players' ratings allow.
- **Definition of Done:**
  1. Each Shout measurably changes play while active (tests reuse C's measures).
  2. Each has a cooldown.
  3. The CPU manager uses them too.
- **ADR:** ADR-102.

| Story | Gherkin AC (summary) |
|---|---|
| **MB-1** Shout model | AC1: `Shout {name, changes: {instruction: level}, seconds, cooldown}`. AC2: active Shouts stack at most two; a third replaces the oldest |
| **MB-2** Six Shouts | AC1: 1 Push up (mentality +1), 2 Hold the lead (−1, tempo slow), 3 Get it wide, 4 Through the middle, 5 Press them, 6 Calm down (tackling careful). AC2: each lasts 60–90 s, cooldown 60 s |
| **MB-3** The bar | AC1: along the bottom (where the control hints are), each Shout with its key, a cooldown fill, active ones lit yellow (`#ffe34d`, our HUD style) |
| **MB-4** CPU manager Shouts | AC1: `cpu_manager.gd` (verified) uses "Push up" when behind after 70', "Hold the lead" when ahead after 80' |
| **MB-5** Players obey by rating | AC1: a Shout's offset is scaled by the player's `decisions` (verified `AI.decisions()`): from 50 % for the lowest to 100 % for the highest |

Tasks are written after MA's retro.

---

## EPIC MC — Player instructions and tactics editor (7/11)

| Story | Gherkin AC (summary) |
|---|---|
| **MC-1** Per-player instructions | AC1: get forward / stay back / free role per player, read by `AI.hold_spot()`. AC2: a man-mark target (exists for CPU: `Footballer.marking`, verified) for the human too |
| **MC-2** Positions editor | AC1: drag a player's spot on a pitch picture on the tactics page; saved per club. AC2: reset to the formation |
| **MC-3** Zones ("territories", Club Football) | AC1: per player, a zone he never leaves in defence. Optional, Advanced |
| **MC-4** Set-piece jobs | Shares part 1's M-8 |

## EPIC MD — Opposition report (6/11)

| Story | Gherkin AC (summary) |
|---|---|
| **MD-1** Before kick-off | AC1: their likely formation, last 5 results (from the Competition), danger man (`CpuManager._danger()`, verified), best and worst rated. AC2: past meetings in this save (CM 03/04) |

## EPIC ME — Form, morale and team chemistry (6/11, 5/11)

| Story | Gherkin AC (summary) |
|---|---|
| **ME-1** Form | AC1: the average of the last 5 match ratings, shown as arrows on the team sheet; no effect on ratings (AM-3) |
| **ME-2** Morale | AC1: wins, goals and playing time raise it; dropped players and losses lower it. AC2: ±5 % on decisions and fatigue rate at most (ADR-103) |
| **ME-3** Team chemistry = starting energy (FIFA 06) | AC1: a side that kept its XI for 3+ fixtures starts with 1 energy segment (Chaos only) |

## EPIC MF — Board Confidence (6/11)

| Story | Gherkin AC (summary) |
|---|---|
| **MF-1** Target | AC1: from the club's place in `league.json` standings (verified source): top 4 means "challenge for the title", and so on |
| **MF-2** Meter | AC1: one 0–100 meter, moved by results against the target; shown on the season screen (FIFA 06's single gauge) |
| **MF-3** The sack (HOLD: Q2) | AC1: below 10 at the end of a season → game over or a new club |

## EPIC MG — Manager Role (PM99's job levels)

| Story | Gherkin AC (summary) |
|---|---|
| **MG-1** Choose a role | AC1: TOUCHLINE (shouts and subs only, tactics on auto), COACH (+ tactics and team sheet), FULL (+ everything in ML when built). AC2: what's not yours is done by the CPU manager (verified, `cpu_manager.gd`) |

## EPIC MH — Called Specials (HOLD: Q3)

| Story | Gherkin AC (summary) |
|---|---|
| **MH-1** A Call (ST0 spike: AM-4) | AC1: choose a Special from a menu of those the side can afford; it waits up to 20 s for `ChaosActions.fits()` (verified), then the AI player carries it out via `think_ai()` (verified). AC2: expired: energy back |
| **MH-2** Outcome by rating | AC1: who's on the ball decides how well (the existing Special code already uses ratings) |
| **MH-3** HUD | AC1: the pending Call shown with a countdown |

## EPIC MI — Dirty-tricks Cards (HOLD: Q3)

Built on part 1's O-4. Stories as in `manager-mode.md` §2: a hand of up to 3, dealt every 15 match
minutes. Cards: Brown envelope (Bribe), Theatre school (dives), Captain's armband, Giant, Hot
potato, Super goalie, Sprinklers (needs J), Floodlight failure (J-4). Played for energy segments;
the referee may notice.

## EPIC MJ — Manager Discipline and touchline ban (HOLD: Q3)

| Story | Gherkin AC (summary) |
|---|---|
| **MJ-1** Argue with the ref | AC1: a Shout "Ref!" can win the next 50-50 decision or raise Manager Discipline |
| **MJ-2** Sent to the stands | AC1: full meter → no Shouts for the rest of the half; in a Competition, a touchline ban for the next fixture (CM 03/04) |

## EPIC MK — Half-time talk and manager dilemmas (HOLD: Q3)

| Story | Gherkin AC (summary) |
|---|---|
| **MK-1** Half-time talk | AC1: calm (stamina back), rant (aggression up: more pressing and fouls), "for the fans" (+1 segment) |
| **MK-2** Dilemmas (FIFA 06) | AC1: between fixtures, sometimes a message with 3 answers, each moving morale, Board Confidence or energy. Our own text, written for OSCF's tone |

## EPIC ML — Career (HOLD: Q2 + gap 2)

Stories after Q2: seasons in a row, history and awards (5–7/11), a points economy for staff
(FIFA 06), youth (5/11). Transfers only if gap 2 is resolved.

---

## Validator summary

- **Structure:** a DAG. MA is the tracer bullet. Its tasks have Unblocks and Pull Gates.
- **Quality:**
  - HOLDs give their blocking question.
  - FEATURE tasks cite AC IDs.
  - Each task has an ST0 or "none required", plus a REFACTORING tail.
  - The glossary is consistent with part 1.
- **Risk & debt:** AM-1 and AM-2 (High) are checked by tests in MA. AM-3 is a compliance
  property with its own test (Core P7).
- **Mode:** PROTOTYPE. TDD is required for the core logic (Shouts, morale, Board Confidence) and
  relaxed for screen wiring.
