extends SceneTree
## The league: 18 clubs that all load, a match between any two of them, and a change
## kit when both wear yellow. godot --headless --path game -s res://tests/teams_test.gd

func _initialize() -> void:
	var TeamScript = load("res://scripts/team.gd")  # loaded at run time: see classic_test.gd
	var ok := true
	var clubs: Array = TeamScript.league()
	var loaded := 0
	for d in clubs:
		var t = TeamScript.from_league(d.name)
		if t and t.short.length() == 3 and t.outfield_material:
			loaded += 1
	print("league: %d clubs, %d load" % [clubs.size(), loaded])
	ok = ok and clubs.size() == 18 and loaded == 18

	var scene: PackedScene = load("res://scenes/main.tscn")
	var m: Node = scene.instantiate()
	print("default: %s vs %s" % [m.get_script().home_club, m.get_script().away_club])
	ok = ok and m.get_script().home_club == "Club Brugge" and m.get_script().away_club == "Anderlecht"

	# Union and Westerlo both play in yellow: the away side changes
	m.get_script().home_club = "Union"
	m.get_script().away_club = "Westerlo"
	root.add_child(m)
	await create_timer(0.5).timeout
	var home_shirt: Color = m.home.colour
	var away_shirt: Color = m.away.colour
	print("Union %s vs Westerlo %s, names %s / %s" % [home_shirt.to_html(false), away_shirt.to_html(false),
		m.home.players[9].name, m.away.players[9].name])
	ok = ok and m.home.name == "Union" and m.away.name == "Westerlo" and not m.away.clashes_with(m.home)
	m.get_script().home_club = "Club Brugge"
	m.get_script().away_club = "Anderlecht"
	print("TEAMS TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)
