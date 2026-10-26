extends SceneTree
## A league season (Season): 18 clubs play each other twice, home and away, never twice in a
## round; the human's fixture waits for him, a draw is a result; the table (3/1/0, then goal
## difference, goals, name) is what the results say (recomputed here our own way); the scorers
## and cards tables; a red card or the fifth yellow costs the next fixture; it saves and loads
## to the same season, drawing the same results; played to the end, the top club is champion.
## godot --headless --path game -s res://tests/season_test.gd

func _initialize() -> void:
	var SeasonScript: GDScript = load("res://scripts/season.gd")
	var CompetitionScript: GDScript = load("res://scripts/competition.gd")
	var clubs: Array = load("res://scripts/team.gd").league().map(func(d): return d.name)
	var ok := true

	# not a season: an odd number, too few, the same club twice
	ok = ok and SeasonScript.create(clubs.slice(0, 5), [], 1) == null and SeasonScript.create(clubs.slice(0, 2), [], 1) == null \
		and SeasonScript.create([clubs[0], clubs[0], clubs[1], clubs[2]], [], 1) == null

	# D-1-AC1, AC2: 34 rounds of 9; each pair twice, once at each end; nobody twice in a round
	var s = SeasonScript.create(clubs, ["Club Brugge"], 3)
	var meetings := {}
	var twice_in_a_round := false
	for r in s.rounds:
		var seen := {}
		for f in r:
			twice_in_a_round = twice_in_a_round or seen.has(f.home) or seen.has(f.away)
			seen[f.home] = true
			seen[f.away] = true
			meetings[f.home + ">" + f.away] = meetings.get(f.home + ">" + f.away, 0) + 1
	var each_once := meetings.size() == 18 * 17 and meetings.values().all(func(n): return n == 1)
	print("%d clubs, %d rounds of %d; every pairing once at each end %s; nobody twice in a round %s" % [
		clubs.size(), s.rounds.size(), s.rounds[0].size(), each_once, not twice_in_a_round])
	ok = ok and clubs.size() == 18 and s.rounds.size() == 34 and s.rounds.all(func(r): return r.size() == 9) \
		and each_once and not twice_in_a_round

	# the human's fixture waits for him; a draw is a result
	var f: Dictionary = s.next_fixture()
	ok = ok and not f.is_empty() and "Club Brugge" in [f.home, f.away] and not s.close_round()
	var draw := {"home": f.home, "away": f.away, "home_goals": 1, "away_goals": 1, "scorers": [
		{"side": "home", "name": "A Home Scorer", "minute": 10}, {"side": "away", "name": "An Away Scorer", "minute": 80}],
		"cards": [], "extra_time": false, "pens": [], "winner": ""}
	ok = ok and s.record(f, draw) and s.close_round() and s.round == 1
	print("round 1: human draw taken, the rest simulated; now round %d" % (s.round + 1))

	# D-1-AC3: saved (through JSON, as on disk) and loaded, it's the same season and plays on the same
	var text := JSON.stringify(s.to_dict())
	var loaded = CompetitionScript.from_dict(JSON.parse_string(text))
	var same: bool = loaded != null and JSON.stringify(JSON.parse_string(JSON.stringify(loaded.to_dict()))) == JSON.stringify(JSON.parse_string(text))
	print("saved and loaded: a %s, the same %s" % [loaded.get_script().resource_path.get_file() if loaded else "-", same])
	ok = ok and same and loaded.get_script() == SeasonScript

	# D-5-AC1: a red card misses the next fixture, and only that one
	var mine: Dictionary = s.next_fixture()
	var side := "home" if mine.home == "Club Brugge" else "away"
	var squad: Array = load("res://scripts/lineup.gd").squads()["Club Brugge"]
	var red: String = squad[3].name
	var booked: String = squad[5].name
	var result := {"home": mine.home, "away": mine.away, "home_goals": 0, "away_goals": 2, "scorers": [
		{"side": "away", "name": "Scorer One", "minute": 5}, {"side": "away", "name": "Scorer One", "minute": 50}],
		"cards": [{"side": side, "name": red, "colour": "red", "minute": 30}], "extra_time": false, "pens": [], "winner": mine.away,
		"ratings": [{"side": side, "name": red, "rating": 4.5}, {"side": side, "name": booked, "rating": 7.5}]}
	s.finish(mine, result)
	var banned_next: bool = red in s.unavailable("Club Brugge")
	print("red card in round 2: out for round 3 %s" % banned_next)
	_play(s, "Club Brugge")  # round 3: he misses it
	var back: bool = not red in s.unavailable("Club Brugge")
	print("... and back for round 4 %s" % back)
	ok = ok and banned_next and back
	# D-5-AC2: the fifth yellow costs one fixture
	var yellows := []
	for i in 5:
		yellows.append(red in s.unavailable("Club Brugge"))
		var g: Dictionary = s.next_fixture()
		var sd := "home" if g.home == "Club Brugge" else "away"
		s.finish(g, {"home": g.home, "away": g.away, "home_goals": 0, "away_goals": 0, "scorers": [],
			"cards": [{"side": sd, "name": booked, "colour": "yellow", "minute": 60}], "extra_time": false, "pens": [], "winner": ""})
	var fifth: bool = booked in s.unavailable("Club Brugge")
	print("five yellows in five rounds: out for the next %s" % fifth)
	ok = ok and fifth

	# D-4: scorers and cards tables, by count then name
	var scorers: Array = s.scorers()
	var top_two: bool = scorers.any(func(r): return r.name == "Scorer One" and r.goals == 2)
	var sorted := true
	for i in range(1, scorers.size()):
		var a: Dictionary = scorers[i - 1]
		var b: Dictionary = scorers[i]
		sorted = sorted and (a.goals > b.goals or (a.goals == b.goals and a.name <= b.name))
	var goals_in_results := 0
	for r in s.rounds:
		for g in r:
			if not g.result.is_empty():
				goals_in_results += int(g.result.home_goals) + int(g.result.away_goals)
	var goals_in_table: int = scorers.reduce(func(n, r): return n + r.goals, 0)
	var cards: Array = s.cards()
	var mine_cards: Dictionary = cards.filter(func(r): return r.name == booked)[0] if cards.any(func(r): return r.name == booked) else {}
	print("scorers: %d, sorted %s, %d goals as in the results (%d); %s: %s" % [scorers.size(), sorted, goals_in_table,
		goals_in_results, booked, mine_cards])
	ok = ok and top_two and sorted and goals_in_table == goals_in_results and mine_cards.get("yellow") == 5
	# ... and the best rated, from the matches played on the pitch
	var rated: Array = s.ratings()
	print("best rated: %s" % [rated])
	ok = ok and rated.size() == 2 and rated[0].name == booked and rated[0].rating == 7.5 and rated[1].matches == 1

	# to the end: no humans left to wait for; the champion tops the table
	s.humans = []
	while not s.done:
		s.close_round()
	var table: Array = s.table()
	var own := _table(s)
	var same_table := table.size() == own.size()
	for i in mini(table.size(), own.size()):
		same_table = same_table and table[i].club == own[i].club and table[i].points == own[i].points \
			and table[i].played == 34
	print("champion %s on %d points; the table as the results say %s; %s" % [s.winner, table[0].points, same_table, s.status()])
	ok = ok and s.done and s.winner == table[0].club and same_table

	print("SEASON TEST PASSED" if ok else "SEASON TEST FAILED")
	quit(0 if ok else 1)


## The human's next fixture played as a goalless draw, the round closed.
func _play(s, club: String) -> void:
	var g: Dictionary = s.next_fixture()
	s.finish(g, {"home": g.home, "away": g.away, "home_goals": 0, "away_goals": 0, "scorers": [], "cards": [],
		"extra_time": false, "pens": [], "winner": ""})


## The table worked out here from the fixtures, not by Season: 3 for a win, 1 a draw; then goal
## difference, goals scored, name.
func _table(s) -> Array:
	var rows := {}
	for c in s.clubs:
		rows[c] = {"club": c, "points": 0, "gd": 0, "gf": 0}
	for r in s.rounds:
		for f in r:
			if f.result.is_empty():
				continue
			var h: int = int(f.result.home_goals)
			var a: int = int(f.result.away_goals)
			rows[f.home].gf += h
			rows[f.away].gf += a
			rows[f.home].gd += h - a
			rows[f.away].gd += a - h
			rows[f.home].points += 3 if h > a else 1 if h == a else 0
			rows[f.away].points += 3 if a > h else 1 if h == a else 0
	var out := rows.values()
	out.sort_custom(func(x, y):
		for k in ["points", "gd", "gf"]:
			if x[k] != y[k]:
				return x[k] > y[k]
		return x.club < y.club)
	return out
