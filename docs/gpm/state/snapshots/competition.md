# Contract snapshot: Competition (after EPIC D, 2026-10-26)

## Result: a Dictionary, made by `ResultSim.play` and `Match.competition_result`

```
{home: String, away: String, home_goals: int, away_goals: int,
 scorers: [{side: "home"|"away", name: String, minute: int}],   # sorted by minute (ResultSim)
 cards:   [{side, name, colour: "yellow"|"red", minute}],
 extra_time: bool, pens: [] | [home: int, away: int], winner: String,   # "" = a draw
 ratings?: [{side, name, rating}],   # only from a match played on the pitch
 injuries?: [{side, name, fixtures}]}   # fixtures >= 1: out that many; ResultSim and the pitch both give it
```

Scorers from the pitch carry `own_goal: bool`, credited to the side that gained the goal; own
goals don't count in a scorers table.

## Competition (`scripts/competition.gd`), the base of Cup and Season

- Fields: `name`, `clubs`, `humans`, `winner`, `done`, `rng`.
- `is_human(f)`, `current()`, `next_fixture()`, `record(f, result) -> bool`, `close_round() -> bool`.
- `finish(f, result)`: record, then close the round.
- `unavailable(club) -> Array`: the names of the injured, plus the suspended in a Season.
- `injuries` {club: {name: fixtures}}, counted down by `_book_injuries(fixtures)` per round
  (Cup and Season).
- `_counts(saved)` turns JSON floats back into ints.
- `status() -> String` (for the slot list), `to_dict()`.
- `Competition.from_dict(d)` gives a Cup or a Season, by `kind`.

After a JSON save, the numbers come back as floats. Compare after a round trip.

## ResultSim (`scripts/result_sim.gd`, static)

- `play(home, away, knockout: bool, rng: RandomNumberGenerator, sheets := {}, out := {}) -> Dictionary`
  - `out`: club → the names of players who can't play.
  - Returns `{}` (with `push_error`) for an unknown club.
  - The same rng state gives the same Result.
  - In a knockout, the winner is never "".
- `eleven(squad, sheet) -> Array` (squad entries), `goals_expected(xi, other) -> float`, `poisson(mean, rng) -> int`.

## Cup (`scripts/cup.gd`)

- `Cup.create(clubs: Array, humans: Array, seed: int) -> Cup`: null unless there are 4, 8 or 16
  distinct clubs.
- Fields: `name`, `clubs`, `humans`, `rounds: Array[Array[fixture]]`, `winner`, `done`, `rng`.
  A fixture is `{home, away, result: {}}`.
- `current()`, `round_name()`, `is_human(f)`, `next_fixture() -> {}` when none.
- `record(f, result) -> bool`: false without a winner.
- `knocked_out() -> bool`.
- `close_round() -> bool`: false while a human tie is unplayed. It simulates the other ties, then
  draws the next round or sets the winner.
- `to_dict()` / `Cup.from_dict(d)`: `version` 1, `kind` "cup"; the rng seed and state are kept as
  strings.

## Season (`scripts/season.gd`, extends Competition)

- `Season.create(clubs, humans, seed, league := "JUPILER PRO LEAGUE")`: null unless there's an
  even number (4–18) of distinct clubs. It builds a double round robin: the circle method, then
  the second half mirrored.
- Fields: `rounds` (every round, drawn at the start), `round` (index), `bans`
  {club: {name: fixtures}}, `yellows` {club: {name: count}}.
- `simulate_others()`, `simulate(f)`, and `close_round()` (which books cards and serves bans).
- `table()`: [{club, played, won, drawn, lost, gf, ga, gd, points}].
- `scorers()`, `cards()`, `ratings()`: sorted by count, then by name.
- `YELLOW_BAN` = 5.
- `to_dict()` / `from_dict()`: `version` 1, `kind` "season".

## SeasonScreen (`scripts/season_screen.gd`, `scenes/season.tscn`)

- `SCENE`, `slot`.
- `play_mine(season)`: simulates the others, then `Match.play_fixture(season, f, false)`.
- `simulate_mine(season)`.

## CupScreen (`scripts/cup_screen.gd`, `scenes/cup.tscn`)

- `SCENE`.
- `start_tie(cup)`: calls `Match.play_fixture(cup, next, true)`.
- `leave_cup()`: calls `Match.leave_competition()`.
- `finish_tie` is gone: use `Competition.finish`.

## Match additions (`scripts/main.gd`)

- `static var competition: Competition`, `static var competition_fixture: Dictionary`.
- `enter_competition(c)` keeps the knockout option to put back later.
- `play_fixture(c, f, ko)`: the human's club at home, with his saved sheet.
- `leave_competition()`.
- The squad is picked without `competition.unavailable(club)`.
- `_latest_scores()` flashes the round's other goals during the match.
- `competition_result(f) -> Dictionary`: the match as the Result of fixture `f`, the right way
  round.
- `minute() -> float`: match minutes.
- `MatchStats.scorers: [[Footballer, minute, own_goal]]`, `MatchStats.cards: [[Footballer, colour, minute]]`.
