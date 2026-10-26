extends SceneTree
## A cup tie on the pitch: the bracket starts it (CupScreen.start_tie), the match logs its scorers,
## and at full time its result goes back into the cup, the right way round, and the round closes.
## godot --headless --path game -s res://tests/cup_flow_test.gd

func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	var screen: GDScript = load("res://scripts/cup_screen.gd")
	var cup = load("res://scripts/cup.gd").create(["Club Brugge", "Anderlecht", "KAA Gent", "Union"], ["Club Brugge"], 3)
	var ok := true

	# AC2: the bracket starts my tie: my club at home on the pitch, a knockout match, the fixture kept
	match_script.knockout = false
	screen.start_tie(cup)
	var f: Dictionary = match_script.competition_fixture
	var opponent: String = f.away if f.home == "Club Brugge" else f.home
	print("tie: %s v %s; on the pitch %s v %s, knockout %s" % [f.home, f.away, match_script.home_club,
		match_script.away_club, match_script.knockout])
	ok = ok and match_script.competition == cup and match_script.home_club == "Club Brugge" \
		and match_script.away_club == opponent and match_script.knockout

	# the match logs a goal: who scored it, and when
	match_script.half_minutes = 2
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	while m.state != 1:
		await physics_frame
	await physics_frame
	var striker = m.home.players[9]
	var c: Vector2 = Pitch.field_rect().get_center()
	for t in [m.home, m.away]:  # everyone out of the way, to the far touchline
		for p in t.players:
			p.position = c + Vector2(-Pitch.m(3.0) * t.side, -Pitch.m(30.0))
			p.velocity = Vector2.ZERO
	m.ball.stop_at(m.away.goal_defended() + Vector2(m.away.side * Pitch.m(3.0), 0.0))
	m.ball.last_touch = striker
	m.ball.kick(Vector2(-m.away.side * 500.0, 0.0), 0.0)
	var waited := 0.0
	while m.home.score == 0 and waited < 5.0:
		await physics_frame
		waited += 1.0 / 60.0
	print("goal: %d - %d, logged %s" % [m.home.score, m.away.score, m.stats.scorers.map(func(s): return [s[0].display_name, s[1]])])
	ok = ok and m.home.score == 1 and m.stats.scorers.size() == 1 and m.stats.scorers[0][0] == striker

	# AC3: the result, the right way round: my club is the fixture's away side here
	var away_tie := {"home": opponent, "away": "Club Brugge", "result": {}}
	var r: Dictionary = m.competition_result(away_tie)
	print("as the away side: %s %d - %d %s, scorers %s, winner %s" % [r.home, r.home_goals, r.away_goals, r.away,
		r.scorers, r.winner])
	ok = ok and r.home_goals == 0 and r.away_goals == 1 and r.scorers.size() == 1 and r.scorers[0].side == "away" \
		and r.winner == "Club Brugge" and r.scorers[0].name == striker.display_name

	# a tie without a winner is refused (a knockout match always has one at full time)
	ok = ok and not cup.record(f, {"home": f.home, "away": f.away, "winner": ""}) and f.result.is_empty()

	# ... recorded in the cup: the round closes, the other tie simulated, the final drawn
	var mine: Dictionary = m.competition_result(f)
	cup.finish(f, mine)
	print("after the tie: %s, round %s" % [cup.rounds[0].map(func(t): return "%s %d-%d %s" % [t.home,
		t.result.home_goals, t.result.away_goals, t.away]), cup.round_name()])
	ok = ok and f.result == mine and cup.round_name() == "FINAL" and cup.rounds[0].all(func(t): return not t.result.is_empty())
	ok = ok and (cup.current()[0].home == "Club Brugge" or cup.current()[0].away == "Club Brugge")

	match_script.competition = null
	match_script.competition_fixture = {}
	print("CUP FLOW TEST PASSED" if ok else "CUP FLOW TEST FAILED")
	quit(0 if ok else 1)
