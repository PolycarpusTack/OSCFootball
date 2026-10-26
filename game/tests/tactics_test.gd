extends SceneTree
## Tactic Slots (EPIC G): four per club (BALANCED, ATTACK, DEFEND, ALL OUT), each a formation and
## the Team Instructions, edited on the TACTICS page (keys 1-4 pick the slot) and saved with the
## sheet; a bad file falls back to the defaults. In the match keys 1-4 switch: the instructions at
## once, the formation at the next stoppage, not again for 5 s, with a banner; the slot shows by
## the score. The keys are rebindable.
## godot --headless --path game -s res://tests/tactics_test.gd

func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	var lineup = load("res://scripts/lineup.gd")
	var team = load("res://scripts/team.gd")
	var human = load("res://scripts/human.gd")
	var ok := true

	# G-1-AC1: four named slots with defaults; the first is the sheet's own
	var tactics: Array = lineup.tactics({"instructions": {"width": "wide"}}, "4-4-2")
	print("slots: %s" % [tactics.map(func(t): return "%s %s %s" % [team.TACTICS[tactics.find(t)], t.formation, t.instructions.mentality])])
	ok = ok and team.TACTICS == ["BALANCED", "ATTACK", "DEFEND", "ALL OUT"] and tactics.size() == 4
	ok = ok and tactics[0].formation == "4-4-2" and tactics[0].instructions.width == "wide" and tactics[0].instructions.size() == 8
	ok = ok and tactics[1].instructions.mentality == "attacking" and tactics[2].instructions.mentality == "defensive"
	ok = ok and tactics[3].formation == "4-3-3"
	var indoor: Array = lineup.tactics({}, "1-2-1")
	print("indoors: %s" % [indoor.map(func(t): return t.formation)])
	ok = ok and indoor.all(func(t): return t.formation == "1-2-1")
	var bad: Array = lineup.tactics({"tactics": [{}, {"formation": "9-9-9", "instructions": {"mentality": "crazy"}}, "junk"]}, "4-4-2")
	print("a bad file: %s %s, %s" % [bad[1].formation, bad[1].instructions.mentality, bad[2].instructions.mentality])
	ok = ok and bad[1].formation == "4-4-2" and bad[1].instructions.mentality == "normal" and bad[2].instructions.mentality == "defensive"

	# ... edited on the TACTICS page: 2 picks ATTACK; its formation and an instruction change, the
	# BALANCED slot (the sheet's) stays; saved with the sheet
	lineup.path = "user://lineups_tactics_test.json"  # not the player's own sheets
	DirAccess.remove_absolute(lineup.path)
	var screen: Control = load("res://scripts/team_manager.gd").new()
	root.add_child(screen)
	await process_frame
	screen._switch_page()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_2
	key.pressed = true
	screen._unhandled_input(key)
	screen._tactic_row = 3  # 5-3-2
	screen._select()
	var formations: int = team.FORMATIONS.size()
	screen._tactic_row = formations + 4  # tempo: ATTACK's fast, down to slow
	screen._change_view(-1)
	screen._change_view(-1)
	var sheet: Dictionary = screen._sheet()
	print("edited ATTACK: %s, tempo %s; BALANCED: %s, tempo %s; the XI's formation %s" % [sheet.tactics[1].formation,
		sheet.tactics[1].instructions.tempo, sheet.tactics[0].formation, sheet.tactics[0].instructions.tempo, screen._formation])
	ok = ok and screen._slot == 1 and sheet.tactics[1].formation == "5-3-2" and sheet.tactics[1].instructions.tempo == "slow"
	ok = ok and sheet.tactics[0].formation == "4-4-2" and sheet.tactics[0].instructions.tempo == "normal" and screen._formation == "4-4-2"
	lineup.save(match_script.home_club, screen._formation, sheet)  # what _done() does, without leaving the screen
	match_script.home_sheet = sheet
	var saved: Array = lineup.tactics(lineup.load_saved(match_script.home_club), "4-4-2")
	DirAccess.remove_absolute(lineup.path)
	lineup.path = lineup.SAVE
	print("saved: ATTACK %s, tempo %s" % [saved[1].formation, saved[1].instructions.tempo])
	ok = ok and saved == sheet.tactics
	var handed: Dictionary = match_script.home_sheet
	screen.queue_free()

	# G-2-AC1, AC3: in the match, ATTACK: its instructions at once, its formation at the stoppage
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await create_timer(1.6).timeout
	m.state = 5  # HALF_TIME with a long pause: freeze the play
	m._state_left = 1e9
	var t = m.home
	print("kick-off: tactic %s, tempo %s, %d slots" % [team.TACTICS[t.tactic], t.instructions.tempo, t.tactics.size()])
	ok = ok and t.tactic == 0 and t.instructions.tempo == "normal" and t.tactics == handed.tactics
	var switched: bool = m.switch_tactic(t, 1)
	print("ATTACK: switched %s, mentality %s, tempo %s, formation %s (to come %s); banner '%s'" % [switched,
		t.instructions.mentality, t.instructions.tempo, t.formation, t.pending_formation, m._banner.text])
	ok = ok and switched and t.instructions.mentality == "attacking" and t.instructions.tempo == "slow"
	ok = ok and t.formation == "4-4-2" and m._banner.text.contains("TACTIC: ATTACK")
	m._stoppage_news()
	var lines: Array = t.players.map(func(p): return p.role)
	print("at the stoppage: formation %s, roles %s" % [t.formation, "".join(lines)])
	ok = ok and t.formation == "5-3-2" and "".join(lines) == "GDDDDDMMMFF" and t.pending_formation == ""
	# G-2-AC2: not again for 5 s
	var again: bool = m.switch_tactic(t, 2)
	m._tactic_keys(4.0)
	var still: bool = m.switch_tactic(t, 2)
	m._tactic_keys(1.1)
	print("cooldown: at once %s, after 4 s %s" % [again, still])
	ok = ok and not again and not still and t.tactic == 1
	# ... and key 3 (DEFEND) after it; G-3-AC1 the HUD shows it
	Input.parse_input_event(_key(KEY_3, true))
	await physics_frame
	await physics_frame
	Input.parse_input_event(_key(KEY_3, false))
	await physics_frame
	print("key 3: tactic %s, mentality %s; by the score '%s'" % [team.TACTICS[t.tactic], t.instructions.mentality, m._tactic_label.text])
	ok = ok and t.tactic == 2 and t.instructions.mentality == "defensive" and m._tactic_label.text.contains("DEFEND")

	# G-2-AC4: rebindable on the Controls screen
	ok = ok and human.keys()[0].tactic_1 == [KEY_1] and human.keys()[1].tactic_4 == [KEY_KP_4]
	print("keys: player 1 %s, player 2 %s" % [human.button_name(0, "tactic_1", false), human.button_name(1, "tactic_4", false)])

	match_script.home_sheet = {}
	print("TACTICS TEST PASSED" if ok else "TACTICS TEST FAILED")
	quit(0 if ok else 1)


func _key(code: Key, down: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = down
	return e
