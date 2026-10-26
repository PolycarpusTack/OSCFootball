# Features from the inspiration games (2026-10-26)

The 12 archives in `inspiration games/` are now **11 games**: the English RTWC 98 re-release
and the French FIFA 98 hold the same game, so it counts once. Each game is unpacked in its own
folder under `inspiration games/unpacked/<game>/`, and each has an analysis in
`inspiration games/analysis/<game>.md`. Those are tables of features, one per tag, with the file
and the string as evidence.

The whole folder is kept out of git by a local exclude (`.git/info/exclude`), not a commit.
**Ideas only:** no data, text, art or sound from these games goes into OSCF (ROADMAP's rule).
Nothing was run; everything was read with `7z`, `strings` and our own `tools/eaformats.py`.

| Game | Year | Kind | Features found | Evidence |
|---|---|---|---|---|
| FIFA 96 | 1995 | action (our base) | 55 | V (files) |
| FIFA 97 | 1996 | action | 62 | V |
| FIFA: Road to World Cup 98 | 1997 | action | 76 | V |
| FIFA 99 | 1998 | action | 73 | V |
| FIFA 06 | 2005 | action + manager mode | 122 | V |
| Football Power (Gaelco) | 1999 | arcade cabinet | 3 | A (ROMs have no text) |
| Club Football: The Manager | 1994 | manager (DOS) | 42 | V |
| Premier Manager 99 | 1999 | manager, 3D match | 94 | V |
| L'Entraîneur 3 (= CM3) | 1999 | manager | 42 | **A only**: Inno Setup installer, `innoextract` not installed |
| Championship Manager 4 | 2003 | manager, 2D match | 105 | V |
| Championship Manager 03/04 | 2003 | manager, 2D match | 120 | V |

**How to read the counts.** "N/11" is how many games have the feature; the raw counts are in
`inspiration games/analysis/_counts.txt`. Three caveats:

- CM4 and CM 03/04 are nearly the same game, so a CM feature counts double.
- L'Entraîneur 3 rests on general knowledge only.
- Different analysts tagged slightly differently, so counts are lower bounds. I merged the
  obvious synonyms by hand below; for example, game speed and match speed are one feature.

**What frequency means.** Frequency tells you what players **expect** of the genre (the
must-haves). It doesn't make our version better by itself. The more versions we have seen, the
better we know what works: the CM games have replays, highlight levels and speeds in the same
match view, for example. What makes OSCF stand out is the rare features (section C).

## A. Missing must-haves, by frequency

A must-have is a feature in **6 or more** of the 11 games that OSCF doesn't have yet. Sizes as in
ROADMAP (S an evening, M a few sessions, L a project). Feasibility is checked against the code
as it is today.

| # | Feature | Games | Side | OSCF today | Feasibility |
|---|---|---|---|---|---|
| 1 | **League season**: fixtures, table, results of the other games | 10/11 | both | none (ROADMAP 3.2) | **L**, but the data is there: `league.json` has 18 real clubs. Needs a **result simulator** (manager-mode M.5) for the matches you don't play |
| 2 | **Cup competition**: a bracket of rounds | 10/11 | both | only one knockout match (extra time, golden goal, penalties: done) | **M**. Bracket screen + simulator; the match itself exists (ROADMAP 3.1) |
| 3 | **Save / load** for cups and seasons | 10/11 | both | only the team sheet and keys are saved | **M**. JSON in `user://`, like `controls.cfg` (ROADMAP 3.3). Needed by 1 and 2 |
| 4 | **Team tactics the AI follows**: mentality, passing, pressing, width, tempo | 10/11 | both | the CPU manager's style only changes the formation | **M**. Manager-mode M.1; every input already has a spot in `ai.gd` |
| 5 | **Tables of top scorers / cards / ratings** | 10/11 | manager | per match only (`match_stats.gd`) | **S** once 1 exists |
| 6 | **Injuries in a match** (and, in a season, weeks out: 8/11) | 9/11 | both | none | **S–M**. A player limps (slower, worse ratings) or must go off; the AI and the subs screen react. In a season he misses N matches. Our own art: a limp, or a stretcher later |
| 7 | **Suspensions** (bans from cards, carried over) | 9/11 | manager | cards per match only | **S** once 1 or 2 exists |
| 8 | **Replays and highlights**: instant replay (7), highlights (8), save a goal (6) | 8/11 | both | none (ROADMAP 5.1) | **M**. A ring buffer of positions and animation frames per tick; replaying it draws the same match. The same buffer gives "goal of the match" and highlight-only manager matches |
| 9 | **Crowd chants** that rotate and react | 8/11 | play | one crowd loop (an EA placeholder) | **S–M**, but needs **our own recordings** (ROADMAP 4.2) |
| 10 | **Tactics during the match**: stored plans or shouts on keys | 8/11 | both | none for the human (subs only) | **S** after 4: 3–4 tactic slots on the number keys (PM99, FIFA 99 "IGM"). This is the manager mode's touchline bar |
| 11 | **Two-legged ties**: aggregate, away goals | 8/11 | manager | none | **S** once 2 exists |
| 12 | **Weather** (7) **and pitch condition** (6), day/night (4) | 7/11 | both | none | **M**. Rain or mud means less ball friction and a skid; snow means an orange ball and slower runs; a tint and particles on top. CM4 also makes weather *events* (an icy slip, a wind-blown lob, floodlight failure), which are Chaos material (ROADMAP 5.3) |
| 13 | **Player instructions** (7) **and a tactics editor** (7): drag positions, zones | 7/11 | both | 4 formations to pick; no per-player orders | **M**. Club Football's "territories" (a zone per man) map straight onto `hold_spot()` |
| 14 | **Watch / skip / play a match** for the manager: text (6), 2D or radar (3), 3D (1), with speed (6) | 9/11 | manager | autoplay only (the demo) | **M**. Manager-mode M.2. Speed via `Engine.time_scale`; "highlights only" needs 8. PM99's "take control" and FIFA 06's "Intervene" (jump in when it goes wrong) are a natural fit for us |
| 15 | **Difficulty levels** (6), plus an action/simulation switch (FIFA 96) | 6/11 | play | none: the AI is always the same | **S**. Scale the AI's reaction time, `decisions` and accuracy; don't touch the ratings |
| 16 | **Board / chairman**: expectations, confidence, the sack | 6/11 | manager | none | **S–M** once 1 exists. A target from the club's ranking in `league.json`, and one confidence meter (FIFA 06's "job security") |
| 17 | **Opposition report** before the match | 6/11 | manager | none | **S**. Their formation, form, danger man (the CPU manager already finds him to man-mark) |
| 18 | **Player form / morale** (6/5) and **team chemistry** (FIFA 06) | 6/11 | manager | none | **S–M**. Form from recent match ratings (`match_stats.gd` already rates every player). Morale as a small modifier, never a change to the real ratings |
| 19 | **Commentary voice** | 6/11 | play | text ticker only (ROADMAP 4.4) | **L**: needs our own recordings |

### Common, but blocked or left out

| Feature | Games | Why not (now) |
|---|---|---|
| Transfers (9), contracts and wages (6), scouting (7), free agents, loans | 5–9 | We have **no** fees or wages, and we **don't invent** real players' data. Possible only as a points economy (FIFA 06 buys its staff this way) or with fictional players. **Your call** |
| Multiple leagues (9), promotion/relegation (7) | 7–9 | Our data is one division (Jupiler Pro League, 18 clubs). A second league needs a data decision first |
| Network play (7) | 7/11 | ROADMAP leaves modem/network out on purpose |
| Camera views (6) | 6/11 | ROADMAP leaves camera views out on purpose; maybe in a 3D view (I.6) |
| Player / team editor (6) | 6/11 | ROADMAP leaves the custom team editor out on purpose |
| Finances, stadium building, sponsors, tickets, youth (5–7) | 5–7 | A full club sim; it belongs to a career mode you haven't chosen yet (manager-mode question 2) |

### Already in OSCF (no work needed)

Friendlies, knockout match (extra time, golden goal, shoot-out), formations, substitutions, fouls
and cards, advantage, offside, free-kick wall, set-piece takers, captain, man-marking (CPU),
stamina, real ratings in play, match stats and Man of the Match, match length, two players on
one keyboard, indoor 5-a-side, referee strictness, catch-up logic, cheats/modifiers, skill moves,
special shots, celebrations, text commentary, event banners, key rebinding.

## B. Fewer games, cheap and good (S each)

| Feature | Seen in | Why |
|---|---|---|
| **Radar** | RTWC 98, FIFA 99, FIFA 06 | Cheap (the debug overlay already draws positions); it's also the manager mode's "2D view" |
| **Game speed** Normal to Fastest | FIFA 99, FIFA 06 (+ CM speeds) | A "Fastest" Chaos match with 3-minute halves |
| **Other grounds' scores** pop-up | FIFA 99, CM4, CM 03/04 | Tension in a cup or season round |
| **Practice scenarios with best times** | FIFA 96, 97, RTWC 98, 99, 06 (5/11) | "Score without the shoot button", "land a Fireball": ROADMAP 5.2 |
| **Scenario challenges**: "they lead 5-0, win" | FIFA 06 | Built from match settings only; unlocks as rewards |
| **Forfeit at 5 sent off** (awarded 2-0) | FIFA 99 | With our Chaos referee: a real, funny end state |
| **"Player may need substituting"** alert | FIFA 99, RTWC 98 | The simplest touchline prompt; we have stamina already |
| **Silver goal** rule | CM 03/04 | One more knockout option next to golden goal |
| **Formation per restart** (kick-off, corner, free-kick layouts) | FIFA 96 | Restarts look planned |
| **Set-piece jobs**: "disrupt the keeper", "near post flick-on" | CM4, CM 03/04, PM99 | Clear orders for manager mode; AI behaviour at corners |
| **Ambient animations**: tie a boot, wave for the ball | PM99 | Personality in a top-down game (own art) |
| **Context intros**: a pre-match line by table position | FIFA 96 | Fits `commentary.gd` straight away |

## C. The ones that fit Chaos (rare, and what makes OSCF stand out)

| Feature | Seen in | For OSCF |
|---|---|---|
| **Cheap Shots**: earned power-ups that red-card the rival's best player, give his side 3 yellows, tire them, block subs, rewind time; the loser earns more | FIFA 06 | The closest thing to Chaos in any of them. As **manager-mode cards** (manager-mode.md §2) or a party mode |
| **Manager dilemmas**: an e-mail with three answers, each moving a gauge (job security, fans, morale, bank) | FIFA 06 | Cheap to write, full of jokes. The Chaos manager's in-between-matches layer |
| **Manager touchline ban** | CM 03/04 | Exactly our "sent to the stands" idea (manager-mode.md §3) |
| **Fights, dives, dissent written into the sim** | CM4, CM 03/04 | The moody referee's material for a simulated match |
| **Weather events**: floodlight failure, a match abandoned | CM4 | Chaos modifiers / manager cards |
| **The board sells your players** when you're in debt | Club Football | A consequence you don't control |
| **Crowd mood**: booing, fans leaving early | CM4, CM 03/04 | Could feed the energy bar (home crowd momentum) |
| **Team chemistry = starting momentum** | FIFA 06 | The energy bar starts part-filled for a settled team |
| **Pick your job**: Arcade / Trainer / Manager / Accountant / Total, plus auto switches | PM99 | The answer to "how light is the manager mode": start with "touchline only" |
| **Watch, then take control** | PM99, FIFA 06 "Intervene" | Our two halves (manager and action) in one match: manage, and grab the pad when it goes wrong |
| **FIFA 96's hidden "Enhanced Play Modes"** (big ball, crazy ball, invisible walls, giant players, joke kits, super goalie) | FIFA 96, 97, RTWC 98 | Our modifiers page is already in the spirit of the original; still to do: big ball, invisible walls (outdoors), laser ball |

## Suggested order

The common thread: **items 1–3 (season, cup, save) and 14 (watch/skip) all need the result
simulator**, and **4, 10, 13 are the manager mode's M.1**. So:

1. **M.1 team tactics + in-match tactic slots (A4, A10)**: improves every match against the AI
   too.
2. **The result simulator (M.5)**, then the **cup** with bracket and save (A2, A3), the smallest
   complete competition.
3. **The league season** (A1, A5, A7, A11), the board (A16).
4. Next to these, the cheap ones: difficulty (A15), radar, game speed, the sub alert, forfeit at 5.
5. Replays (A8) and injuries (A6) when you want more drama in the action game.

**Unverified (found while checking):** `IDEAS_TO_IMPLEMENT.md` I.1 cites an RTWC 98 symbol,
`PLAYER_indoorGoToSideline_`, which appears nowhere in RTWC 98's files (I searched them all).
That row should be marked unverified.
