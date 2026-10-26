extends SceneTree
## The pause menu: Esc stops the clock, the AI and the ball; Esc or "Resume" goes on.
## "Substitutions" opens its screen and Esc comes back from it, and the move list still opens
## after it.
## godot --headless --path game -s res://tests/pause_test.gd

var m: Node


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	await create_timer(2.5).timeout  # kicked off, in play
	var ok := true

	_press(KEY_ESCAPE)
	await physics_frame
	var clock: float = m.clock
	var positions := _positions()
	await create_timer(1.0).timeout  # test timers run on while the tree is paused
	var moved := _positions() != positions
	print("Esc: paused %s, clock %.2f -> %.2f, anything moved %s" % [paused, clock, m.clock, moved])
	ok = ok and paused and m.clock == clock and not moved

	_press(KEY_ESCAPE)
	await create_timer(0.5).timeout
	print("Esc again: paused %s, clock ran on %s" % [paused, m.clock > clock])
	ok = ok and not paused and m.clock > clock

	_press(KEY_ESCAPE)  # pause, then choose RESUME, the first item
	await physics_frame
	var was_paused := paused
	_press(KEY_ENTER)
	await physics_frame
	print("Esc, Enter on Resume: paused then %s, now %s" % [was_paused, paused])
	ok = ok and was_paused and not paused

	# down three times (past MOVES, REPLAY) to SUBSTITUTIONS: its screen, still paused; Esc back to the menu; up twice to MOVES
	_press(KEY_ESCAPE)
	await physics_frame
	_press(KEY_DOWN)
	_press(KEY_DOWN)
	_press(KEY_DOWN)
	_press(KEY_ENTER)
	await process_frame
	var subs := _subs_menu()
	print("Substitutions: its screen open %s, paused %s" % [subs != null, paused])
	ok = ok and subs != null and paused
	_press(KEY_ESCAPE)
	await process_frame
	var menu = m.get_children().filter(func(c): return _is(c, "pause_menu.gd"))[0]
	print("Esc: screen closed %s, menu back %s, paused %s" % [_subs_menu() == null, menu._box.visible, paused])
	ok = ok and _subs_menu() == null and menu._box.visible and paused
	_press(KEY_UP)
	_press(KEY_UP)
	_press(KEY_ENTER)
	await process_frame
	print("then MOVES: the move list opens %s" % menu._moves.visible)
	ok = ok and menu._moves.visible
	_press(KEY_ESCAPE)
	_press(KEY_ESCAPE)
	await physics_frame
	ok = ok and not paused

	print("PAUSE TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)


func _press(key: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = key
		e.keycode = key
		e.pressed = down
		Input.parse_input_event(e)
	Input.flush_buffered_events()


func _subs_menu() -> Node:
	for c in m.get_children():
		if _is(c, "subs_menu.gd") and not c.is_queued_for_deletion():
			return c
	return null


func _is(node: Node, script_file: String) -> bool:  # the classes can't be named here (see formations_test)
	return node.get_script() != null and node.get_script().resource_path.ends_with(script_file)


func _positions() -> Array:
	var out := [m.ball.position]
	for t in [m.home, m.away]:
		for p in t.players:
			out.append(p.position)
	return out
