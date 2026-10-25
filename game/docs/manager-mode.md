# Manager mode: an investigation (2026-10-25)

Status: a proposal, nothing built. The question was: can you manage a side the AI plays,
by tactics and touchline commands, CM3-style? And what's Chaos in a manager mode?

Short answer: yes. Most of the match is already there, because the AI already plays both
sides in autoplay and the CPU side already has a CM3-style manager. What's missing is the
other direction: **tactics the AI players actually follow**. Today a CPU manager's style
only changes the formation.

## What's already there (verified in the code)

| Piece | Where | What it does now |
|---|---|---|
| AI plays both sides | `Match.autoplay` (`main.gd`), the demo reel | every player is AI; the human's prompts and specials HUD hide |
| A CPU manager | `cpu_manager.gd` | at stoppages: CM3's attack-need sum (strength, territory, score, men, clock) gives a style (attack / normal / defend / sit back), a formation for it and for how you attack (wings: 5-3-2, middle: 4-5-1), subs (rating x fit x freshness), a man-marker on your danger man; its decisions go up on a banner |
| Squad and tactics screens | `team_manager.gd`, `lineup.gd` | CM3-like squad list and player card; XI, bench, formation; the sheet is saved per club |
| Set-piece takers, captain | `team.gd`, `Match.captain()` | assigned takers; the Chaos captain |
| Player decisions | `ai.gd` `options()` / `choose()` | each player weighs shot, pass, cross, dribble, through ball and a skill move, more surely the better his `decisions` rating |
| Formation shape | `ai.gd` `hold_spot()`, `PULL` | each line's spot follows the ball by role |
| Man-marking | `Footballer.marking`, `AI._marking()` | a marker sticks to his man in our half |
| Subs in a match | `subs_menu.gd`, pause menu | 3 or 5 subs, not for a sent-off man |
| Match ratings, stats | `match_stats.gd` | CM3-style 6.0 start, events move it; Man of the Match |
| Commentary | `commentary.gd` | CM3's structure (priorities, a shot held for its outcome), our lines |
| Chaos specials, AI use | `chaos_actions.gd` `think_ai()`, `fits()` | the AI already uses the specials, checking the situation first |

What's not there: a way to **simulate** a match without playing it (cups and leagues need
it for the other fixtures), a **speed** control (only the Thunder slow motion touches
`Engine.time_scale`), and any **team instructions** the players read.

The "CM3 research notes" the code comments mention aren't on this machine, only the
L'Entraîneur 3 installer. What I say about CM3 below is from memory of the game (ASSUMED),
not from those notes: ideas only, no CM3 data, text or art, as with the EA assets.

## How it would play

You pick your club and a manager match. Kick-off: you watch both sides play themselves.
You don't control a player. You manage:

1. **Before the match:** the team sheet (exists), and a **tactics page**: the team
   instructions below, and per-player ones.
2. **During the match:** a touchline bar along the bottom (where the control hints are now)
   with **shouts** on the number keys: they take effect at once, like CM3's in-match tactic
   changes but without pausing. Formation and subs at stoppages, as the CPU manager does.
3. **Speed:** x1 / x2 / x4 (`Engine.time_scale`), and "highlights only" later on.
4. **After the match:** the ratings and stats screen (exists).

### Team instructions (new: the core of the work)

Each is a value the AI reads where it already makes that decision. Proposed set, close to CM3's
team-tactics screen (ASSUMED recollection) and FIFA 97/98's named tactics (`IDEAS_TO_IMPLEMENT`
I.4, verified strings like "Offside Trap", "Pass Bias", "Shot Bias"):

| Instruction | Values | Where it plugs in |
|---|---|---|
| Mentality | defensive / balanced / attacking | `hold_spot()`: every spot shifted along the pitch; the CPU manager's style sets it too |
| Passing | short / mixed / direct (long ball) | `options()`: worth of long passes, through balls and crosses vs short ones |
| Tempo | slow / normal / fast | how often a man on the ball reconsiders (`_with_ball` timing) and how long he holds it |
| Pressing | stand off / normal / high | `presser()` distance and whether a second man goes in (`ai.gd:120`) |
| Width | narrow / normal / wide | `hold_spot()` y, scaled by line |
| Defensive line | deep / normal / high, offside trap on/off | the back line's depth; with the trap, it steps up as a pass is played |
| Tackling | careful / normal / hard | `_maybe_slide()` / `_maybe_body_check()` odds; more fouls and cards when hard |
| Shoot on sight | off / on | `shooting_range()` stretched, shot worth up |

Per player: **get forward / stay back** (his spot), **man-mark X** (exists), **free role**
(his spot follows the ball more), set-piece duties (exist).

A useful side effect: the CPU manager can use the same instructions instead of only
formations, so Classic and Chaos matches against the AI get better too (ROADMAP 2.3, "Team
strategy").

### Shouts (the touchline bar)

Number keys, each a short-lived nudge (60-90 s), with a cooldown so you can't spam them:

1 **Push up**: mentality one step up. 2 **Hold the lead**: one step down, tempo slow.
3 **Get it wide**: width and crosses up. 4 **Through the middle**. 5 **Press them**.
6 **Calm down**: tackling careful (when the referee is fuming).

The players carry them out the way they carry out everything: their ratings already in
the data (`decisions` and the rest) decide how well. We never invent ratings.

## Chaos in manager mode

The Chaos layer is about moments, and a manager doesn't press buttons in the moment. So the
manager **calls** them, and the players **pull them off**, or don't.

### 1. Called specials ("Unleash it!")

The energy bar stays, filled the same way (passes, tackles, saves). In manager mode you
spend it on **calls**: "Next chance, Fireball!", "Grapple their number 9!", "Wall at the
back!". A call waits (say 20 s) until the situation fits: the same `ChaosActions.fits()`
checks the specials use today. Then the AI player does it. Most of this is already built:
`think_ai()` picks and starts specials for the AI; a call only narrows its list to what
you've asked for, and lets it spend your bar.

Who's on the ball decides how well: a striker with great finishing turns your Fireball
call into a goal, a clumsy one blazes it over.

### 2. Dirty-tricks cards

Every 15 match minutes you're dealt a card; you hold up to three, and the CPU manager gets
them too. Playing a card costs energy segments. Most already exist as modifiers or referee
moves, so they're cheap to add:

| Card | Effect | Exists as |
|---|---|---|
| Brown envelope | the Bribe | `chaos_actions` bribe |
| Theatre school | your players dive in the box for 5 minutes | Dive, AI dive odds |
| Captain's armband | the captain calms the referee | Captain |
| Giant | one player twice the size for 3 minutes | the Giant players modifier |
| Hot potato / crazy ball | for 2 minutes | modifiers |
| Super goalie | your keeper for 5 minutes | modifier |
| Sprinklers | the pitch is soaked: the ball skids (needs I.5's wet pitch) | new |
| Floodlight failure | 30 s of darkness | new |

The referee notices dirty cards like he notices fouls: his mood, the linesman seeing the
envelope, and so on. That's the existing Chaos referee, so a card can backfire.

### 3. The manager on the touchline

Your own discipline meter, like the players' (`Footballer.discipline`): **argue with the
ref** (a shout) can win the next 50-50 call, or get you **sent to the stands**, which
locks your shouts for the rest of the half. The CPU manager can lose his head too.

### 4. A dressing-room moment at half-time

Three choices: a calm talk (stamina back a little), a rant (more aggression: more
pressing and fouls), or "do it for the fans" (energy bar +1 segment). CM3 had no team
talks (later CMs did; ASSUMED). This one is ours.

## How I'd build it (each step playable on its own)

| Step | What | Size | Notes |
|---|---|---|---|
| M.1 | Team instructions read by the AI (the table above), set by the CPU manager too | M | Biggest step, and it improves every mode. Needs tests per instruction: e.g. "attacking: average spot 8 m further up" |
| M.2 | Manager match: your side on autoplay, the shout bar, x1/x2/x4, the tactics page before kick-off | M | Reuses autoplay, the team sheet, the subs screen and the stats screen |
| M.3 | Called specials | S-M | `think_ai()` with your call as a filter; the HUD shows the pending call |
| M.4 | Cards, touchline discipline, half-time talk | M | Mostly existing effects behind a card hand |
| M.5 | A quick result simulator (no rendering, many ticks a frame, or a CM3-like stats roll) | M-L | Needed for the season (ROADMAP 3.2) and for cups with other fixtures |

Start with M.1 and M.2 together, the smallest step where you can feel manager mode.
M.3 is where Chaos comes in.

## Questions for you

1. **Watch or skip:** do you want to watch every match (x1-x4), or also a CM3-style
   text/radar view? The radar is cheap (the debug overlay already draws positions).
2. **One match or a career:** a manager match first, or straight into a season with
   transfers? Transfers need real data we don't have (fees, wages); we don't invent them.
3. **Chaos dose:** called specials only, or the cards and the touchline too?
