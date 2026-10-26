extends SceneTree
## A whole cup of 4, end to end: each of the human's ties played on the pitch (on autoplay, each
## half fast-forwarded to its last half second), handed back through the full-time screen
## (Match._leave_full_time) to the bracket, which saves the cup, the other ties simulated, until
## there's a winner.
## godot --headless --path game -s res://tests/cup_smoke_test.gd

func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	var screen: GDScript = load("res://scripts/cup_screen.gd")
	var cup = load("res://scripts/cup.gd").create(["Club Brugge", "Anderlecht", "KRC Genk", "Union"], ["Club Brugge"], 21)
	var save: GDScript = load("res://scripts/save_game.gd")
	save.dir = "user://saves_smoke_test"  # the bracket saves the cup each time it shows: not into the real slots
	match_script.half_minutes = 2
	Engine.time_scale = 4.0  # shoot-outs play out in real time
	var played := 0
	var ok := true
	while not cup.done and played < 3:
		if cup.knocked_out():
			cup.close_round()
			continue
		screen.start_tie(cup)
		var f: Dictionary = match_script.competition_fixture
		var m: Node = load("res://scenes/main.tscn").instantiate()
		m.autoplay = true
		root.add_child(m)
		var waited := 0.0
		while m.state != 6 and waited < 200.0:  # 6: full time
			if m.state == 1:
				m.clock = maxf(m.clock, m.half_end() - 0.5)
			await physics_frame
			waited += 1.0 / 60.0
		print("%s: %s %d - %d %s%s" % [cup.round_name(), m.home.name, m.home.score, m.away.score, m.away.name,
			"  (pens %s)" % [m.competition_result(f).pens] if not m.shootout.is_empty() else ""])
		ok = ok and m.state == 6
		m._leave_full_time()  # the result into the cup, and on to the bracket
		m.queue_free()
		await process_frame
		await process_frame  # the bracket comes in on the second frame (and saves the cup)
		played += 1
		ok = ok and not f.result.is_empty() and f.result.winner != ""
	Engine.time_scale = 1.0
	print("winner %s after %d tie(s) on the pitch; rounds %s" % [cup.winner, played,
		cup.rounds.map(func(r): return r.map(func(t): return "%s %d-%d %s" % [t.home, t.result.home_goals, t.result.away_goals, t.away]))])
	ok = ok and cup.done and cup.winner != "" and played >= 1
	screen.leave_cup()
	ok = ok and save.load_slot(screen.slot) != null  # the bracket saved it
	for i in range(1, save.SLOTS + 1):
		save.delete(i)
	DirAccess.remove_absolute(save.dir)
	ok = ok and match_script.competition == null and not match_script.knockout
	print("CUP SMOKE TEST PASSED" if ok else "CUP SMOKE TEST FAILED")
	quit(0 if ok else 1)
