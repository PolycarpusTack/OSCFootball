extends SceneTree
## The result simulator (ResultSim): fixtures nobody plays on the pitch, from the clubs' ratings.
## godot --headless --path game -s res://tests/result_sim_test.gd

func _initialize() -> void:
	var Sim = load("res://scripts/result_sim.gd")  # loaded at run time: see classic_test.gd
	var ok := true
	var squads: Dictionary = load("res://scripts/lineup.gd").squads()
	var rng := RandomNumberGenerator.new()

	# AC1: goals for each side, and a scorer from that club's eleven for every goal
	rng.seed = 1
	var r: Dictionary = Sim.play("Club Brugge", "Anderlecht", false, rng)
	var named := true
	var goals := {"home": 0, "away": 0}
	for s in r.scorers:
		goals[s.side] += 1
		var club: String = r.home if s.side == "home" else r.away
		named = named and squads[club].any(func(e): return e.name == s.name) and s.minute >= 1 and s.minute <= 90
	print("Brugge %d-%d Anderlecht, scorers %s" % [r.home_goals, r.away_goals, r.scorers.map(func(s): return s.name)])
	ok = ok and r.home_goals >= 0 and r.away_goals >= 0 and named \
		and goals.home == r.home_goals and goals.away == r.away_goals

	# AC2: the stronger club (Brugge, 76 against Lommel's 66) wins more, total goals 2.0 .. 3.5, on 3 seeds
	for seed in [11, 22, 33]:
		rng.seed = seed
		var won := 0
		var lost := 0
		var total := 0
		for i in 1000:
			var home := i % 2 == 0  # half at home, half away
			var res: Dictionary = Sim.play("Club Brugge" if home else "Lommel SK", "Lommel SK" if home else "Club Brugge", false, rng)
			var brugge: int = res.home_goals if home else res.away_goals
			var lommel: int = res.away_goals if home else res.home_goals
			won += int(brugge > lommel)
			lost += int(brugge < lommel)
			total += res.home_goals + res.away_goals
		var mean := total / 1000.0
		print("seed %d: Brugge won %d, lost %d, %.2f goals a match" % [seed, won, lost, mean])
		ok = ok and won > lost * 2 and mean >= 2.0 and mean <= 3.5

	# home advantage: two equal sides, the home side wins more
	rng.seed = 5
	var hw := 0
	var aw := 0
	for i in 2000:
		var res: Dictionary = Sim.play("KV Mechelen", "KV Mechelen", false, rng)
		hw += int(res.home_goals > res.away_goals)
		aw += int(res.home_goals < res.away_goals)
	print("equal sides: home won %d, away won %d" % [hw, aw])
	ok = ok and hw > aw

	# AC3: a knockout fixture never ends level: extra time, then a shoot-out
	rng.seed = 7
	var level_seen := 0
	var never_drawn := true
	for i in 400:
		var res: Dictionary = Sim.play("Charleroi", "Standard", true, rng)
		if res.extra_time:
			level_seen += 1
		never_drawn = never_drawn and res.winner in ["Charleroi", "Standard"]
		if not res.pens.is_empty():
			never_drawn = never_drawn and res.pens[0] != res.pens[1] and res.home_goals == res.away_goals
	print("knockout: %d of 400 went to extra time, always a winner: %s" % [level_seen, never_drawn])
	ok = ok and never_drawn and level_seen > 0

	# AC4: an unknown club fails loudly, with an empty result
	var bad: Dictionary = Sim.play("Nowhere FC", "Anderlecht", false, rng)
	print("unknown club: %s" % bad)
	ok = ok and bad.is_empty()

	# AC5: the same seed gives the same result
	rng.seed = 99
	var a: Dictionary = Sim.play("Union", "KRC Genk", true, rng)
	rng.seed = 99
	var b: Dictionary = Sim.play("Union", "KRC Genk", true, rng)
	print("same seed, same result: %s" % (a == b))
	ok = ok and a == b

	print("RESULT SIM TEST PASSED" if ok else "RESULT SIM TEST FAILED")
	quit(0 if ok else 1)
