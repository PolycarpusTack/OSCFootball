extends SceneTree
## The pause menu's move list and the special picker filtered by the controlled player's line.
## godot --headless --path game -s res://tests/move_list_test.gd
var m: Node
var failed := 0


func check(value: bool, message: String) -> void:
	if not value:
		failed += 1
		push_error(message)


func press(key: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = key
	e.pressed = true
	Input.parse_input_event(e)


func pad(button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)


func by_role(t, role: String):
	return t.players.filter(func(q): return q.role == role)[0]


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	m.get_script().chaos = true
	m.get_script().players = 1
	root.add_child(m)
	await create_timer(2.5).timeout
	var actions = m.chaos_actions
	var h = m.humans[0]

	# the picker offers only what the controlled player's line can do (plus keeper and captain moves)
	h.controlled.controlled = false
	h.controlled = by_role(m.home, "D")
	var for_defender: Array = actions.choices(h)
	check(for_defender.has("grapple") and not for_defender.has("whirlwind") and not for_defender.has("stepover"), "Defender: grapple, not the midfield moves: %s" % [for_defender])
	check(for_defender.has("rocket") and for_defender.has("fist") and for_defender.has("captain"), "Keeper and captain moves stay in every list")
	h.special_index = actions.MOVES.keys().find("whirlwind")
	check(actions.chosen(h) != "whirlwind" and actions.suits(h, actions.chosen(h)), "A selection the line can't do moves on to one it can")
	var seen := {}
	for i in actions.MOVES.size():
		actions.cycle(h)
		seen[actions.chosen(h)] = true
	check(seen.keys().all(func(id): return actions.suits(h, id)) and seen.size() == for_defender.size(), "Cycling visits each of the defender's moves: %s" % [seen.keys()])
	h.controlled = by_role(m.home, "M")
	check(actions.choices(h).has("whirlwind") and actions.choices(h).has("stepover") and not actions.choices(h).has("grapple"), "Midfielder's list")
	h.special_index = actions.MOVES.keys().find("whirlwind")
	actions.update_labels()
	var strip: String = actions.labels[0].text
	var count: int = actions.choices(h).size()
	check(strip.contains("WHIRLWIND TURN 30") and not strip.contains("GRAPPLE") and strip.contains("/%d" % count), "The HUD shows the midfielder's moves around the selected one: %s" % strip)
	check(strip.get_slice("\n", 0).count("  ·  ") == actions.PICKER_WINDOW - 1, "Three at a time")

	# the move list: Esc, down to MOVES, Enter
	press(KEY_ESCAPE)
	await process_frame
	press(KEY_DOWN)
	await process_frame
	press(KEY_ENTER)
	await process_frame
	var menu = m.get_children().filter(func(c): return c is CanvasLayer and c.get("_moves") != null)[0]
	var list = menu._moves
	check(paused and list.visible, "MOVES opens the list, still paused")
	check(list.role == "M" and list._shown[0].name == "Move", "Opens on the basics, for the midfielder")
	check(list._rows.get_child_count() == list._shown.size(), "One row per move")
	check(list.input_text(["@shoot"]).contains("Space"), "Keyboard: Space to shoot")
	press(KEY_RIGHT)
	await process_frame
	check(list.pages_shown()[list.page].title == "SHOTS & LINE MOVES", "Right: next page")
	check(list._shown[0].name == "LASER PASS" and list.usable(list._shown[0]), "The midfielder's own line move first: %s" % list._shown[0].name)
	check(not list.usable(list._shown[-1]), "Other lines' moves last, dimmed")
	check(list._shown[0].cost == 30 and list._preview.visible, "Cost from LineMoves; its animation previews")
	press(KEY_RIGHT)
	await process_frame
	var names: Array = list._shown.map(func(r): return r.name)
	check(names.size() == 15 and names.find("WHIRLWIND TURN") < names.find("GRAPPLE TACKLE"), "Chaos specials, midfielder's first: %s" % [names])
	pad(JOY_BUTTON_DPAD_DOWN)
	await process_frame
	check(list.pad and list.pick == 1 and list.input_text(["@special"]).contains("Y"), "Gamepad: its buttons shown")
	press(KEY_ESCAPE)
	await process_frame
	check(paused and not list.visible and menu._box.visible, "Esc goes back to the menu")
	press(KEY_ESCAPE)
	await process_frame
	check(not paused, "Esc again resumes")

	m.get_script().chaos = false  # Classic: no energy moves to list
	check(list.pages_shown().size() == 1, "Classic lists the basics only")
	m.get_script().chaos = true

	print("MOVE LIST TEST %s" % ("PASSED" if failed == 0 else "FAILED (%d)" % failed))
	quit(0 if failed == 0 else 1)
