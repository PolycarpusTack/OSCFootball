extends SceneTree
## Classic Football: no energy, no super-shots, and the fireball combo is just a shot.
## godot --headless --path game -s res://tests/classic_test.gd

func _initialize() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.get_script().chaos = false  # Match.chaos; the class can't be named here before the Anims autoload exists
	m.autoplay = true
	root.add_child(m)
	var supers := []
	m.event.connect(func(kind, _t): if kind in ["fireball", "banana", "thunder"]: supers.append(kind))
	await create_timer(1.5).timeout  # kick-off pause
	var ok := true

	# energy rewards don't accrue, and a full bar (set by hand) still buys nothing
	await create_timer(20.0).timeout
	print("after 20 s of AI play: energy BRU %.0f, AND %.0f" % [m.home.energy, m.away.energy])
	ok = ok and m.home.energy == 0.0 and m.away.energy == 0.0
	m.autoplay = false
	while m.state != 1:
		await physics_frame
	var p = m.home.players[9]
	p.position = Vector2(Pitch.field_rect().size.x * 0.62, Pitch.field_rect().size.y * 0.3)
	m.ball.stop_at(p.feet_front())
	m.ball.take(p)
	m.home.energy = 100.0
	for o in m.away.players.slice(1):
		o.position.x = Pitch.field_rect().size.x * 0.25
	await physics_frame
	for keys in [["move_down"], ["move_down", "move_right"], ["move_right"]]:
		for k in keys:
			Input.action_press(k)
		await create_timer(0.1).timeout
		for k in keys:
			Input.action_release(k)
	Input.action_press("move_right")
	Input.action_press("shoot")
	await create_timer(0.05).timeout
	Input.action_release("shoot")
	Input.action_release("move_right")
	await create_timer(0.6).timeout
	print("fireball combo: supers %s, ball power '%s', ball speed %.0f, energy %.0f" % [supers, m.ball.power, m.ball.velocity.length(), m.home.energy])
	ok = ok and supers.is_empty() and m.ball.power == "" and m.ball.velocity.length() > 100.0 and m.home.energy == 100.0
	print("CLASSIC TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)
