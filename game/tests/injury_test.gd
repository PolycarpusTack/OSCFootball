extends SceneTree
## Injuries (EPIC E): a foul from behind hurts more often than one from the front, and more again
## when the Chaos referee didn't see it; an injured man is slower and plays worse; none with the
## option off. Badly hurt, he goes off at the next stoppage (the AI picks his sub; a human gets
## the substitutions screen; with no subs left he plays on). A human is told "may need
## substituting". In a competition he misses fixtures, counted down; simulated results injure too.
## godot --headless --path game -s res://tests/injury_test.gd

func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	var ok := true
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await create_timer(1.6).timeout
	m.state = 5  # HALF_TIME with a long pause: freeze the play
	m._state_left = 1e9
	var by = m.away.players[6]
	var victim = m.home.players[7]

	# E-1-AC1: counted over 4,000 slides each: from behind hurts more than from the front
	seed(5)
	var hurt := {}
	for kind in ["behind", "front"]:
		hurt[kind] = 0
		for i in 4000:
			victim.injury = 0
			m._maybe_injure(by, victim, kind)
			hurt[kind] += int(victim.injury > 0)
	victim.injury = 0
	var unseen: float = m.injure_odds(by, "behind", true) / m.injure_odds(by, "behind", false)
	print("injured in 4,000: from behind %d, from the front %d; unseen by the referee x%.1f" % [hurt.behind, hurt.front, unseen])
	ok = ok and hurt.behind > 2.0 * hurt.front and hurt.front > 0 and unseen > 1.0

	# E-1-AC2: injured, he's 0.8 as fast and plays as if rated 0.85 as high
	var speed: float = victim.top_speed()
	var dribbling: float = victim.skill("dribbling", 0.0, 1.0)
	var rated: float = victim.stats.get("dribbling", 67.5) * 0.85
	victim.injury = 1
	var slower: float = victim.top_speed() / speed
	var worse: float = victim.skill("dribbling", 0.0, 1.0)
	print("injured: speed x%.2f, dribbling %.2f -> %.2f (as if rated %.0f)" % [slower, dribbling, worse, rated])
	ok = ok and absf(slower - 0.8) < 0.001 and absf(worse - clampf((rated - 40.0) / 55.0, 0.0, 1.0)) < 0.001
	victim.injury = 0

	# E-1-AC3: with the option off, nobody is hurt
	match_script.injuries_on = false
	for i in 500:
		m._maybe_injure(by, victim, "behind")
	print("option off: injured %s" % (victim.injury > 0))
	ok = ok and victim.injury == 0
	match_script.injuries_on = true

	# E-4-AC1: a human's injured man: "may need substituting" on the banner, once
	victim.injury = 1
	m._banner_left = 0.0
	m._sub_alerts()
	var alert: String = m._banner.text
	m._banner_left = 0.0
	m._banner.text = ""
	m._sub_alerts()
	print("banner: %s; not again: %s" % [alert.replace("\n", " "), m._banner.text == ""])
	ok = ok and alert.contains("MAY NEED SUBSTITUTING") and alert.contains(victim.display_name) and m._banner.text == ""
	victim.injury = 0

	# E-2-AC1: badly hurt on the AI's side, he goes off at the stoppage for a bench man
	var hurt_ai = m.away.players[4]
	hurt_ai.injury = 2
	var subs: int = m.away.subs_left
	m._stoppage_news()
	print("AI side: %s off %s, subs left %d" % [hurt_ai.display_name, not hurt_ai in m.away.players, m.away.subs_left])
	ok = ok and not hurt_ai in m.away.players and m.away.subs_left == subs - 1
	# ... and on the human's side the substitutions screen opens
	victim.injury = 2
	m._stoppage_news()
	var opened: bool = m._pause._subs_open and paused
	print("human side: substitutions screen open %s" % opened)
	ok = ok and opened
	paused = false
	# E-2-AC2: no subs left: he plays on, limping
	var stays = m.away.players[3]
	stays.injury = 2
	m.away.subs_left = 0
	m._stoppage_news()
	print("no subs left: still on %s" % (stays in m.away.players))
	ok = ok and stays in m.away.players

	# E-3-AC1: the result carries the injuries; a season keeps him out, counting down
	var f := {"home": m.home.name, "away": m.away.name, "result": {}}
	var r: Dictionary = m.competition_result(f)
	var listed: Array = r.injuries.filter(func(i): return i.name == victim.display_name and i.side == "home")
	print("result injuries: %s" % [r.injuries])
	ok = ok and listed.size() == 1 and int(listed[0].fixtures) >= 1
	var season = load("res://scripts/season.gd").create(["Club Brugge", "Anderlecht", "KRC Genk", "Union"], ["Club Brugge"], 2)
	var g: Dictionary = season.next_fixture()
	var side := "home" if g.home == "Club Brugge" else "away"
	season.finish(g, {"home": g.home, "away": g.away, "home_goals": 0, "away_goals": 0, "scorers": [], "cards": [],
		"extra_time": false, "pens": [], "winner": "", "injuries": [{"side": side, "name": "Hurt Man", "fixtures": 2}]})
	var out := []
	for i in 3:
		out.append("Hurt Man" in season.unavailable("Club Brugge"))
		g = season.next_fixture()
		season.finish(g, {"home": g.home, "away": g.away, "home_goals": 0, "away_goals": 0, "scorers": [], "cards": [],
			"extra_time": false, "pens": [], "winner": ""})
	print("out for 2 fixtures: rounds 2-4 %s" % [out])
	ok = ok and out == [true, true, false]
	var loaded = load("res://scripts/competition.gd").from_dict(JSON.parse_string(JSON.stringify(season.to_dict())))
	ok = ok and loaded.injuries == season.injuries
	# ... and simulated results injure too, now and then
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var injured := 0
	for i in 1000:
		injured += load("res://scripts/result_sim.gd").play("Club Brugge", "Anderlecht", false, rng).injuries.size()
	print("simulated: %d injuries in 1,000 matches" % injured)
	ok = ok and injured > 60 and injured < 200

	print("INJURY TEST PASSED" if ok else "INJURY TEST FAILED")
	quit(0 if ok else 1)
