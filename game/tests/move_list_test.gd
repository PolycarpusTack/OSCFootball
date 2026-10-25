extends SceneTree
## The pause menu's move list, filtered by the controlled player's line, and what special + each button does.
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

	# every special has one button to go with special, and each line gets its own
	var buttons := {}
	for button in actions.BUTTON_MOVES:
		for id in actions.BUTTON_MOVES[button]:
			buttons[id] = buttons.get(id, 0) + 1
	check(actions.MOVES.keys().all(func(id): return buttons.get(id, 0) == 1), "Each special on exactly one button: %s" % [buttons])
	h.controlled.controlled = false
	var d = by_role(m.home, "D")
	var foe = m.away.players[6]
	h.controlled = d
	m.ball.stop_at(d.position + Vector2(20, 0))
	m.ball.take(foe)
	foe.position = d.position + Vector2(20, 0)
	check(actions.pick(h, "shoot") == "grapple", "Defender by the carrier: special + shoot grapples: %s" % actions.pick(h, "shoot"))
	h.controlled = by_role(m.home, "M")
	m.ball.release()
	m.ball.stop_at(h.controlled.feet_front())
	m.ball.take(h.controlled)
	check(actions.pick(h, "switch") in ["whirlwind", "stepover"] and actions.pick(h, "shoot") == "line", "Midfielder with the ball: whirlwind (or stepover) and the Laser Pass")
	actions.update_labels()
	var strip: String = actions.labels[0].text
	check(strip.contains("LASER PASS") and not strip.contains("GRAPPLE"), "The HUD shows what the midfielder's buttons do: %s" % strip)

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
	check(list._shown[0].cost == 50 and list._preview.visible, "Cost from LineMoves; its animation previews")
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
