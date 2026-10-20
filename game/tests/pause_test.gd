extends SceneTree
## The pause menu: Esc stops the clock, the AI and the ball; Esc or "Resume" goes on.
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


func _positions() -> Array:
	var out := [m.ball.position]
	for t in [m.home, m.away]:
		for p in t.players:
			out.append(p.position)
	return out
