class_name ResultSim
extends RefCounted
## The result of a fixture nobody plays on the pitch (a cup's or a season's other matches), from
## the two clubs' ratings in data/squads.json (ADR-001, docs/gpm/backlog-player.md). Goals per
## side are a Poisson draw: their eleven's attack against the other side's defence and keeper,
## plus a little home advantage. Scorers by finishing and position; cards by aggression. A
## knockout fixture level at 90 minutes gets extra time, then a shoot-out.
##
## The result: {home, away, home_goals, away_goals, scorers: [{side, name, minute}],
## cards: [{side, name, colour, minute}], extra_time, pens: [] or [home, away], winner}. The
## winner is "" for a draw. `rng` makes it repeatable: the same seed, the same result.

const GOALS := 1.3  # a side's goals a match when its attack equals the other side's defence
const STEEP := 3.0  # how hard a rating gap tells: 10 points of 70 give about 1.5x the goals
const HOME := 0.15  # the home side's extra goals a match
const EXTRA_TIME := 1.0 / 3.0  # 30 minutes of 90
const PENALTY := 0.76  # a penalty scored, for a taker of 70 against a keeper of 70
const YELLOW := 0.08  # a player's chance of a yellow card a match, for aggression 50
const RED := 0.004
const INJURY := 0.06  # a side's chance a match that a man is badly hurt (out for 1-3 fixtures)
## How much each line counts for the attack and for the defence.
const ATTACK := {"FW": 1.0, "MF": 0.6, "DF": 0.2}
const DEFENCE := {"FW": 0.2, "MF": 0.6, "DF": 1.0}
## Who scores: finishing times this.
const SCORER := {"FW": 3.0, "MF": 1.5, "DF": 0.5, "GK": 0.0}
const LINES := {
	"GK": "GK",
	"CB": "DF", "RB": "DF", "LB": "DF", "RWB": "DF", "LWB": "DF",
	"CDM": "MF", "CM": "MF", "CAM": "MF", "RM": "MF", "LM": "MF",
	"ST": "FW", "CF": "FW", "RW": "FW", "LW": "FW",
}

static var _squads := {}  # data/squads.json, read once: a season simulates hundreds of fixtures


## `sheets`: optional team sheets ({"xi": [ids]}) per club, e.g. the human's; otherwise the
## default eleven (Lineup.auto_pick). `out`: per club, the names of players who can't play
## (suspended).
static func play(home: String, away: String, knockout: bool, rng: RandomNumberGenerator, sheets := {}, out := {}) -> Dictionary:
	if _squads.is_empty():
		_squads = Lineup.squads()
	var squads := _squads
	for club in [home, away]:
		if not squads.has(club):
			push_error("ResultSim: no squad for %s" % club)
			return {}
	var fit := func(club: String) -> Array: return squads[club].filter(func(e): return not e.name in out.get(club, []))
	var sides := {"home": eleven(fit.call(home), sheets.get(home, {})), "away": eleven(fit.call(away), sheets.get(away, {}))}
	var r := {"home": home, "away": away, "home_goals": 0, "away_goals": 0, "scorers": [], "cards": [],
		"extra_time": false, "pens": [], "winner": "", "injuries": []}
	var expect := {
		"home": goals_expected(sides.home, sides.away) + HOME,
		"away": goals_expected(sides.away, sides.home),
	}
	_score(r, sides, expect, 1.0, 1, 90, rng)
	_book(r, sides, rng)
	if knockout and r.home_goals == r.away_goals:
		r.extra_time = true
		_score(r, sides, expect, EXTRA_TIME, 91, 120, rng)
		if r.home_goals == r.away_goals:
			r.pens = _shootout(sides, rng)
	if r.home_goals != r.away_goals:
		r.winner = home if r.home_goals > r.away_goals else away
	elif not r.pens.is_empty():
		r.winner = home if r.pens[0] > r.pens[1] else away
	for side in ["home", "away"]:  # drawn last: the score and cards come out as they did before injuries
		if rng.randf() < INJURY:
			r.injuries.append({"side": side, "name": sides[side][rng.randi_range(0, 10)].name, "fixtures": rng.randi_range(1, 3)})
	return r


## A club's eleven as squad entries: the sheet's when it's valid, else the default pick.
static func eleven(squad: Array, sheet: Dictionary) -> Array:
	var picked := Lineup.checked(squad, Team.DEFAULT_FORMATION, sheet) if not sheet.is_empty() \
		else Lineup.auto_pick(squad, Team.DEFAULT_FORMATION)
	return Lineup.entries(squad, picked.xi)


static func line(e: Dictionary) -> String:
	return LINES.get(e.position, "MF")


## A line-weighted average of `overall`.
static func rating(xi: Array, weights: Dictionary) -> float:
	var sum := 0.0
	var weight := 0.0
	for e in xi:
		var w: float = weights.get(line(e), 0.0)
		sum += w * float(e.overall)
		weight += w
	return sum / weight if weight > 0.0 else 50.0


static func keeper(xi: Array) -> float:
	for e in xi:
		if line(e) == "GK":
			return float(e.overall)
	return 40.0


## A side's goals a match against `other`: GOALS when its attack equals their defence (the
## defence counted 70 %, the keeper 30 %).
static func goals_expected(xi: Array, other: Array) -> float:
	var stop := 0.7 * rating(other, DEFENCE) + 0.3 * keeper(other)
	return GOALS * pow(rating(xi, ATTACK) / stop, STEEP)


static func _score(r: Dictionary, sides: Dictionary, expect: Dictionary, share: float, first: int, last: int,
		rng: RandomNumberGenerator) -> void:
	for side in ["home", "away"]:
		var n := poisson(expect[side] * share, rng)
		r[side + "_goals"] += n
		for i in n:
			r.scorers.append({"side": side, "name": _scorer(sides[side], rng).name, "minute": rng.randi_range(first, last)})
	r.scorers.sort_custom(func(a, b): return a.minute < b.minute)


static func _scorer(xi: Array, rng: RandomNumberGenerator) -> Dictionary:
	var weights: Array = xi.map(func(e): return SCORER[line(e)] * float(e.stats.get("finishing", 50)))
	return xi[_pick(weights, rng)]


static func _book(r: Dictionary, sides: Dictionary, rng: RandomNumberGenerator) -> void:
	for side in ["home", "away"]:
		for e in sides[side]:
			var temper := float(e.stats.get("aggression", 50)) / 50.0
			if rng.randf() < RED * temper:
				r.cards.append({"side": side, "name": e.name, "colour": "red", "minute": rng.randi_range(1, 90)})
			elif rng.randf() < YELLOW * temper:
				r.cards.append({"side": side, "name": e.name, "colour": "yellow", "minute": rng.randi_range(1, 90)})
	r.cards.sort_custom(func(a, b): return a.minute < b.minute)


## Five each, then sudden death. Takers by their penalties rating, in order of it.
static func _shootout(sides: Dictionary, rng: RandomNumberGenerator) -> Array:
	var takers := {}
	for side in ["home", "away"]:
		var t: Array = sides[side].duplicate()
		t.sort_custom(func(a, b): return a.stats.get("penalties", 50) > b.stats.get("penalties", 50))
		takers[side] = t
	var keepers := {"home": keeper(sides.away), "away": keeper(sides.home)}  # the keeper each side faces
	var score := [0, 0]
	var kick := 0
	while true:
		for i in 2:
			var side: String = ["home", "away"][i]
			var e: Dictionary = takers[side][kick % 11]
			var chance: float = PENALTY + 0.004 * (float(e.stats.get("penalties", 50)) - 70.0) - 0.003 * (keepers[side] - 70.0)
			score[i] += int(rng.randf() < chance)
		kick += 1
		if kick >= 5 and score[0] != score[1]:
			return score
	return score


static func poisson(mean: float, rng: RandomNumberGenerator) -> int:
	var limit := exp(-mean)
	var n := 0
	var p := rng.randf()
	while p > limit:
		n += 1
		p *= rng.randf()
	return n


static func _pick(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var x := rng.randf() * total
	for i in weights.size():
		x -= weights[i]
		if x <= 0.0:
			return i
	return weights.size() - 1
