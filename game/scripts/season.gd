class_name Season
extends Competition
## A league season: every club plays every other twice, home and away (a double round robin by
## the circle method, the second half the first with the ends swapped), one round at a time.
## The humans' fixtures are played on the pitch (or simulated on request), the others simulated
## (ResultSim) when the round closes. The table, scorers and cards are worked out from the
## results whenever asked, so there's nothing kept alongside them to drift. A red card costs
## the next fixture, so does every YELLOW_BAN-th yellow; a suspended player isn't picked
## (unavailable()). Saved through to_dict / from_dict with the random state.

const MIN_CLUBS := 4
const MAX_CLUBS := 18
const YELLOW_BAN := 5  # yellows that cost a fixture (an assumed rule: there's no source for ours)

var rounds: Array = []  # every round's fixtures, drawn at the start
var round := 0  # the round being played (rounds.size() when it's over)
var bans := {}  # club -> {player name: fixtures still to miss}
var yellows := {}  # club -> {player name: yellows so far}


## A season, or null unless `season_clubs` is an even number (4-18) of different clubs.
static func create(season_clubs: Array, human_clubs: Array, seed: int, league := "JUPILER PRO LEAGUE") -> Season:
	var unique := {}
	for c in season_clubs:
		unique[c] = true
	var n := season_clubs.size()
	if n < MIN_CLUBS or n > MAX_CLUBS or n % 2 == 1 or unique.size() != n:
		push_error("Season: needs an even number of %d-%d different clubs, got %d" % [MIN_CLUBS, MAX_CLUBS, n])
		return null
	var s := Season.new()
	s.name = league
	s.clubs = season_clubs.duplicate()
	s.humans = human_clubs.filter(func(c): return c in season_clubs)
	s.rng.seed = seed
	var order := season_clubs.duplicate()
	for i in range(n - 1, 0, -1):  # Fisher-Yates with the season's own rng
		var j := s.rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var first_half: Array = []
	for r in n - 1:
		var fixtures: Array = []
		for i in n / 2:
			var a = order[i]
			var b = order[n - 1 - i]
			var a_home := (r + i) % 2 == 0
			fixtures.append({"home": a if a_home else b, "away": b if a_home else a, "result": {}})
		first_half.append(fixtures)
		order = [order[0], order[-1]] + order.slice(1, n - 1)  # the first stays, the rest turn
	s.rounds = first_half + first_half.map(func(r): return r.map(func(f): return {"home": f.away, "away": f.home, "result": {}}))
	return s


func current() -> Array:
	return rounds[mini(round, rounds.size() - 1)]


func next_fixture() -> Dictionary:
	if done:
		return {}
	for f in current():
		if f.result.is_empty() and is_human(f):
			return f
	return {}


func record(f: Dictionary, result: Dictionary) -> bool:
	if done or not f in current():
		push_error("Season: %s v %s isn't in this round" % [f.home, f.away])
		return false
	f.result = result
	return true


## The round's fixtures nobody plays, simulated now (also before the human's match, so their
## scores can come in during it).
func simulate_others() -> void:
	for f in current():
		if f.result.is_empty() and not is_human(f):
			f.result = _simulate(f)


## The human's fixture simulated instead of played.
func simulate(f: Dictionary) -> void:
	if f.result.is_empty():
		record(f, _simulate(f))


func _simulate(f: Dictionary) -> Dictionary:
	return ResultSim.play(f.home, f.away, false, rng, {}, {f.home: unavailable(f.home), f.away: unavailable(f.away)})


func close_round() -> bool:
	if done or not next_fixture().is_empty():
		return false
	simulate_others()
	_book_round()
	_book_injuries(current())
	round += 1
	if round >= rounds.size():
		done = true
		winner = table()[0].club
	return true


## Bans served by the clubs that played this round, then this round's cards.
func _book_round() -> void:
	for f in current():
		for club in [f.home, f.away]:
			var out: Dictionary = bans.get(club, {})
			for player in out.keys():
				out[player] -= 1
				if out[player] <= 0:
					out.erase(player)
	for f in current():
		for c in f.result.cards:
			var club: String = f.result[c.side]
			var out: Dictionary = bans.get_or_add(club, {})
			if c.colour == "red":
				out[c.name] = out.get(c.name, 0) + 1
			else:
				var booked: Dictionary = yellows.get_or_add(club, {})
				booked[c.name] = booked.get(c.name, 0) + 1
				if booked[c.name] % YELLOW_BAN == 0:
					out[c.name] = out.get(c.name, 0) + 1


## The names of `club`'s players suspended for this round.
func unavailable(club: String) -> Array:
	return bans.get(club, {}).keys() + super(club).filter(func(n): return not n in bans.get(club, {}))


## [{club, played, won, drawn, lost, gf, ga, gd, points}], top first: points, goal difference,
## goals scored, then name.
func table() -> Array:
	var rows := {}
	for c in clubs:
		rows[c] = {"club": c, "played": 0, "won": 0, "drawn": 0, "lost": 0, "gf": 0, "ga": 0, "gd": 0, "points": 0}
	for r in rounds:
		for f in r:
			if f.result.is_empty():
				continue
			var goals := {f.home: int(f.result.home_goals), f.away: int(f.result.away_goals)}
			for club in [f.home, f.away]:
				var other: String = f.away if club == f.home else f.home
				var row: Dictionary = rows[club]
				row.played += 1
				row.gf += goals[club]
				row.ga += goals[other]
				row.gd = row.gf - row.ga
				if goals[club] > goals[other]:
					row.won += 1
					row.points += 3
				elif goals[club] == goals[other]:
					row.drawn += 1
					row.points += 1
				else:
					row.lost += 1
	var out := rows.values()
	out.sort_custom(func(a, b):
		for k in ["points", "gd", "gf"]:
			if a[k] != b[k]:
				return a[k] > b[k]
		return a.club < b.club)
	return out


## [{name, club, goals}], most first, then by name. Own goals don't count.
func scorers() -> Array:
	var by := {}
	for r in rounds:
		for f in r:
			for s in f.result.get("scorers", []):
				if s.get("own_goal", false):
					continue
				var row: Dictionary = by.get_or_add(s.name + "|" + f.result[s.side], {"name": s.name, "club": f.result[s.side], "goals": 0})
				row.goals += 1
	return _sorted(by.values(), ["goals"])


## [{name, club, yellow, red}], the most reds first, then yellows, then by name.
func cards() -> Array:
	var by := {}
	for r in rounds:
		for f in r:
			for c in f.result.get("cards", []):
				var row: Dictionary = by.get_or_add(c.name + "|" + f.result[c.side], {"name": c.name, "club": f.result[c.side], "yellow": 0, "red": 0})
				row[c.colour] += 1
	return _sorted(by.values(), ["red", "yellow"])


## [{name, club, rating, matches}]: the average match rating (MatchStats.rating) from the matches
## played on the pitch (simulated results have none), best first, then by name.
func ratings() -> Array:
	var by := {}
	for r in rounds:
		for f in r:
			for p in f.result.get("ratings", []):
				var row: Dictionary = by.get_or_add(p.name + "|" + f.result[p.side], {"name": p.name, "club": f.result[p.side], "total": 0.0, "matches": 0})
				row.total += float(p.rating)
				row.matches += 1
	var out := by.values().map(func(row): return {"name": row.name, "club": row.club, "matches": row.matches,
		"rating": snappedf(row.total / row.matches, 0.01)})
	return _sorted(out, ["rating"])


static func _sorted(rows: Array, keys: Array) -> Array:
	rows.sort_custom(func(a, b):
		for k in keys:
			if a[k] != b[k]:
				return a[k] > b[k]
		return a.name < b.name)
	return rows


func status() -> String:
	if done:
		return "CHAMPIONS: %s" % winner.to_upper()
	var place: int = table().map(func(row): return row.club).find(humans[0]) + 1 if not humans.is_empty() else 0
	return "ROUND %d%s" % [round + 1, " · %s" % ordinal(place) if place > 0 else ""]


static func ordinal(n: int) -> String:
	var suffix: String = "TH" if n % 100 in [11, 12, 13] else {1: "ST", 2: "ND", 3: "RD"}.get(n % 10, "TH")
	return "%d%s" % [n, suffix]


func to_dict() -> Dictionary:
	return {"version": 1, "kind": "season", "name": name, "clubs": clubs, "humans": humans, "rounds": rounds,
		"round": round, "bans": bans, "yellows": yellows, "injuries": injuries, "winner": winner, "done": done,
		"seed": str(rng.seed), "state": str(rng.state)}


static func from_dict(d: Dictionary) -> Season:
	if d.get("kind") != "season" or int(d.get("version", 0)) != 1:
		return null
	var s := Season.new()
	s.name = d.name
	s.clubs = d.clubs
	s.humans = d.humans
	s.rounds = d.rounds
	s.round = int(d.round)
	s.bans = _counts(d.bans)
	s.yellows = _counts(d.yellows)
	s.injuries = _counts(d.get("injuries", {}))
	s.winner = d.winner
	s.done = d.done
	s.rng.seed = int(d.seed)  # 64-bit, kept as text: JSON numbers are doubles
	s.rng.state = int(d.state)
	return s
