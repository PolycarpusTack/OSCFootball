extends SceneTree
## Team sheets: the default pick is the squad file's first eleven plus a bench of seven with a
## keeper; moving to another formation keeps the same eleven, keeper in goal; a stale sheet falls
## back to the default; the team management screen swaps a reserve into the XI and shows every
## page; a sheet handed to the match puts its XI on the pitch. Ratings show out of 50. The
## TACTICS page sets the Team Instructions; they're saved with the sheet and the match plays them
## (EPIC C-6).
## godot --headless --path game -s res://tests/lineup_test.gd

func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	var lineup = load("res://scripts/lineup.gd")
	var manager_script = load("res://scripts/team_manager.gd")
	var ok := true

	var fifty := [manager_script.fifty(99), manager_script.fifty(76), manager_script.fifty(1)]
	print("99, 76 and 1 out of 50: %s" % [fifty])
	ok = ok and fifty == [50, 38, 1]

	var club: String = match_script.home_club
	var squad: Array = lineup.squads()[club]
	var sheet: Dictionary = lineup.auto_pick(squad, "4-4-2")
	var first_eleven := squad.slice(0, 11).map(func(e): return int(e.id))
	var bench_keepers: int = lineup.entries(squad, sheet.bench).filter(func(e): return e.position == "GK").size()
	var overlap: bool = sheet.bench.any(func(id): return id in sheet.xi)
	print("%s: default XI is the file's first eleven %s, bench of %d with %d keeper, overlap %s" % [
		club, sheet.xi == first_eleven, sheet.bench.size(), bench_keepers, overlap])
	ok = ok and sheet.xi == first_eleven and sheet.bench.size() == 7 and bench_keepers == 1 and not overlap

	for f in ["4-3-3", "4-5-1", "5-3-2"]:
		var xi: Array = lineup.refit(squad, sheet.xi, f)
		var same := xi.duplicate()
		same.sort()
		var before: Array = sheet.xi.duplicate()
		before.sort()
		var keeper: bool = lineup.entries(squad, [xi[0]])[0].position == "GK"
		print("%s: same eleven %s, keeper in goal %s" % [f, same == before, keeper])
		ok = ok and same == before and keeper

	var stale: Dictionary = lineup.checked(squad, "4-4-2", {"xi": [1, 2, 3], "bench": []})
	print("a stale sheet falls back to the default %s" % (stale.xi == first_eleven))
	ok = ok and stale.xi == first_eleven

	# the screen: swap the first reserve with the right back, then look at every page and view
	lineup.path = "user://lineups_test.json"  # not the player's own sheets
	DirAccess.remove_absolute(lineup.path)
	var screen: Control = manager_script.new()
	root.add_child(screen)
	await process_frame
	var reserve: int = screen._order[18]
	screen._row = 1
	screen._select()
	screen._row = 18
	screen._select()
	var swapped: bool = screen._sheet().xi[1] == reserve and not screen._order[1] in screen._sheet().bench
	for v in screen.VIEWS.size():
		screen._change_view(1)
	screen._switch_page()
	screen._tactic_row = 1
	screen._select()
	screen._toggle_ball()
	var kept: bool = reserve in screen._sheet().xi and screen._formation == "4-3-3"
	print("screen: reserve swapped into the XI %s, still in it after 4-3-3 %s" % [swapped, kept])
	ok = ok and swapped and kept
	# C-6-AC1: below the formations, the instructions: mentality up one, pressing down one
	var formations: int = load("res://scripts/team.gd").FORMATIONS.size()
	screen._tactic_row = formations  # mentality
	screen._change_view(1)
	screen._tactic_row = formations + 5  # pressing
	screen._change_view(-1)
	screen._change_view(-1)  # already the lowest: stays
	var picked: Dictionary = screen._sheet()
	print("instructions on the sheet: %s" % [picked.get("instructions")])
	ok = ok and picked.get("instructions", {}).get("mentality") == "attacking" \
		and picked.instructions.pressing == "stand off" and picked.instructions.tempo == "normal"
	# C-6-AC2: saved per club with the sheet
	lineup.save("Club Brugge", "4-3-3", picked)
	var saved: Dictionary = lineup.load_saved("Club Brugge")
	DirAccess.remove_absolute(lineup.path)
	lineup.path = lineup.SAVE
	print("saved: %s" % [saved.get("instructions")])
	ok = ok and saved.get("instructions", {}).get("mentality") == "attacking"
	screen.queue_free()

	# the match plays the sheet it is handed
	match_script.home_formation = "4-3-3"
	match_script.home_sheet = picked
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	var reserve_name: String = lineup.entries(squad, [reserve])[0].name
	var on_pitch: bool = m.home.players.any(func(p): return p.display_name == reserve_name)
	print("match: %s plays %s; instructions %s" % [reserve_name, on_pitch, m.home.instructions])
	ok = ok and on_pitch and m.home.instructions.mentality == "attacking" and m.home.instructions.pressing == "stand off"
	# a level that isn't one (a hand-edited file) is ignored
	m.home.instruct({"mentality": "all out", "width": "wide", "nonsense": "high"})
	print("odd levels ignored: %s" % [m.home.instructions])
	ok = ok and m.home.instructions.mentality == "attacking" and m.home.instructions.width == "wide" \
		and not m.home.instructions.has("nonsense")
	match_script.home_formation = "4-4-2"
	match_script.home_sheet = {}

	print("LINEUP TEST PASSED" if ok else "LINEUP TEST FAILED")
	quit(0 if ok else 1)
