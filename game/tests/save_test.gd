extends SceneTree
## Saving a cup (SaveGame): three slots in user://, loaded back the same (random draws to come
## included), a failed write leaves the old save, a bad file is refused, the slot list.
## Uses user://saves_test/ and deletes it. godot --headless --path game -s res://tests/save_test.gd

const DIR := "user://saves_test"


func _initialize() -> void:
	var Save: GDScript = load("res://scripts/save_game.gd")
	var CupScript: GDScript = load("res://scripts/cup.gd")
	Save.dir = DIR
	var ok := true
	var clubs := ["Club Brugge", "Anderlecht", "KAA Gent", "Union", "KRC Genk", "Standard", "Antwerp", "Charleroi"]

	# B-1-AC1: a cup after round 1, saved to slot 1 and loaded, is the same cup
	var cup = CupScript.create(clubs, ["Club Brugge"], 5)
	var f: Dictionary = cup.next_fixture()
	cup.record(f, {"home": f.home, "away": f.away, "home_goals": 1, "away_goals": 0, "scorers": [], "cards": [],
		"extra_time": false, "pens": [], "winner": f.home})
	cup.close_round()
	ok = ok and Save.save(1, cup)
	var loaded = Save.load_slot(1)
	var same: bool = loaded != null and JSON.stringify(JSON.parse_string(JSON.stringify(loaded.to_dict()))) \
		== JSON.stringify(JSON.parse_string(JSON.stringify(cup.to_dict())))
	print("saved and loaded: same %s, round %s" % [same, loaded.round_name() if loaded else "-"])
	ok = ok and same
	# ... and draws the same results from here on
	if loaded:
		loaded.humans = []
		cup.humans = []
		while not cup.done:
			cup.close_round()
			loaded.close_round()
		print("winners: saved cup %s, loaded cup %s" % [cup.winner, loaded.winner])
		ok = ok and cup.winner == loaded.winner

	# B-1-AC2: a write that fails halfway leaves the old save in the slot
	var before := FileAccess.get_file_as_string(Save.path(1))
	Save.fail_writes = true
	ok = ok and not Save.save(1, CupScript.create(clubs.slice(0, 4), [], 9))
	Save.fail_writes = false
	print("a failed write: old save kept %s" % (FileAccess.get_file_as_string(Save.path(1)) == before))
	ok = ok and FileAccess.get_file_as_string(Save.path(1)) == before

	# B-1-AC3: a bad file is refused, no crash
	var bad := FileAccess.open(Save.path(2), FileAccess.WRITE)
	bad.store_string("{not json")
	bad.close()
	var old := FileAccess.open(Save.path(3), FileAccess.WRITE)
	old.store_string(JSON.stringify({"kind": "cup", "version": 99}))
	old.close()
	print("bad file: %s, old version: %s" % [Save.load_slot(2), Save.load_slot(3)])
	ok = ok and Save.load_slot(2) == null and Save.load_slot(3) == null

	# B-1-AC6: the slot list: competition, club, round, date; unreadable slots say so, empty ones are empty
	var slots: Array = Save.list()
	print("slots: %s" % [slots])
	ok = ok and slots.size() == Save.SLOTS and slots[0].get("club") == "Club Brugge" and slots[0].get("round") == "SEMI-FINALS" \
		and slots[0].get("name") == "OSCF CUP" and slots[0].get("date", "") != "" and slots[1].get("unreadable", false)

	# saving twice gives the same save (idempotent by slot; only the date may move on)
	Save.save(1, cup)
	var once = JSON.parse_string(FileAccess.get_file_as_string(Save.path(1))).competition
	Save.save(1, cup)
	ok = ok and JSON.parse_string(FileAccess.get_file_as_string(Save.path(1))).competition == once

	# delete: the slot is empty again
	Save.delete(1)
	ok = ok and Save.load_slot(1) == null and Save.list()[0].is_empty()

	# B-1-AC4: the bracket saves the cup to its slot every time it shows; CONTINUE needs a save
	var screen_script: GDScript = load("res://scripts/cup_screen.gd")
	var match_script: GDScript = load("res://scripts/main.gd")
	ok = ok and not screen_script.any_saved()
	screen_script.slot = 2
	match_script.competition = cup
	var screen: Node = load("res://scenes/cup.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var autosaved = Save.load_slot(2)
	print("bracket shown: saved to slot 2 %s; CONTINUE offered %s; slot 2 reads \"%s\"" % [autosaved != null,
		screen_script.any_saved(), screen_script.describe(Save.list()[1])])
	ok = ok and autosaved != null and autosaved.winner == cup.winner and screen_script.any_saved() \
		and screen_script.describe(Save.list()[1]).contains("WON BY " + cup.winner.to_upper())  # (humans cleared above)
	screen.queue_free()
	screen_script.leave_cup()

	for i in range(1, Save.SLOTS + 1):
		Save.delete(i)
	DirAccess.remove_absolute(DIR)
	print("SAVE TEST PASSED" if ok else "SAVE TEST FAILED")
	quit(0 if ok else 1)
