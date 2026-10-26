extends SceneTree
## A 4-club season, end to end: the human's first two matches played on the pitch (on autoplay,
## each half fast-forwarded to its last half second), with a suspended player left out and the
## round's other score coming in on the banner, handed back through the full-time screen
## (Match._leave_full_time) to the season screen, which saves it; the rest simulated (S), to a
## champion. godot --headless --path game -s res://tests/season_smoke_test.gd

func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	var screen: GDScript = load("res://scripts/season_screen.gd")
	var save: GDScript = load("res://scripts/save_game.gd")
	save.dir = "user://saves_season_smoke_test"  # the screen saves each time it shows: not into the real slots
	var season = load("res://scripts/season.gd").create(["Club Brugge", "Anderlecht", "KRC Genk", "Union"], ["Club Brugge"], 8)
	match_script.half_minutes = 2
	var ok := true
	var squad: Array = load("res://scripts/lineup.gd").squads()["Club Brugge"]
	var banned: String = squad[0].name  # the first-choice keeper
	season.bans["Club Brugge"] = {banned: 1}
	var latest := []
	for played in 2:
		screen.play_mine(season)
		var f: Dictionary = match_script.competition_fixture
		var m: Node = load("res://scenes/main.tscn").instantiate()
		m.autoplay = true
		root.add_child(m)
		var waited := 0.0
		var left_out = null
		while m.state != 6 and waited < 200.0:  # 6: full time
			if left_out == null and m.home:
				left_out = not m.home.players.any(func(p): return p.display_name == banned)
			if m.state == 1:
				m.clock = maxf(m.clock, m.half_end() - 0.5)
			if m._banner.text.begins_with("LATEST") and not m._banner.text in latest:
				latest.append(m._banner.text)
			await physics_frame
			waited += 1.0 / 60.0
		print("round %d: %s %d - %d %s; the banned keeper left out %s" % [season.round + 1, m.home.name, m.home.score,
			m.away.score, m.away.name, left_out if played == 0 else "-"])
		ok = ok and m.state == 6 and (left_out == true or played > 0)
		m._leave_full_time()  # the result into the season, and on to its screen
		m.queue_free()
		await process_frame
		await process_frame  # the season screen comes in on the second frame (and saves)
		ok = ok and not f.result.is_empty()
	var others_scored: bool = season.rounds.slice(0, 2).any(func(r): return r.any(func(g): return not season.is_human(g) \
		and int(g.result.home_goals) + int(g.result.away_goals) > 0))
	print("the other scores on the banner: %s" % [latest])
	ok = ok and season.round == 2 and (latest.size() > 0 or not others_scored)
	ok = ok and save.load_slot(screen.slot) != null and save.load_slot(screen.slot).round == 2  # the screen saved it
	while not season.done:
		screen.simulate_mine(season)
	var table: Array = season.table()
	print("champion %s; table %s" % [season.winner, table.map(func(r): return "%s %d" % [r.club, r.points])])
	ok = ok and season.done and season.winner == table[0].club and table.all(func(r): return r.played == 6)
	match_script.leave_competition()
	for i in range(1, save.SLOTS + 1):
		save.delete(i)
	DirAccess.remove_absolute(save.dir)
	ok = ok and match_script.competition == null and not match_script.knockout
	print("SEASON SMOKE TEST PASSED" if ok else "SEASON SMOKE TEST FAILED")
	quit(0 if ok else 1)
