extends SceneTree
## Two players: each controls their own team with their own keys, and player 2 can
## score. Then, alone, a gamepad's stick moves player 1.
## godot --headless --path game -s res://tests/two_player_test.gd

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var m: Node = scene.instantiate()
	m.get_script().players = 2  # Match.players; the class can't be named here before the Anims autoload exists
	root.add_child(m)
	await create_timer(1.5).timeout  # kick-off pause
	var ok := true

	var p1 = m.humans[0].controlled
	var p2 = m.humans[1].controlled
	print("controlled: P1 %s, P2 %s" % [p1.name if p1 else "-", p2.name if p2 else "-"])
	ok = ok and p1 and p2 and p1.team == m.home and p2.team == m.away and p1.marker != p2.marker

	# player 2's keys move only player 2's footballer
	Input.action_press("p2_move_up")
	await create_timer(0.3).timeout
	p1 = m.humans[0].controlled
	p2 = m.humans[1].controlled
	print("p2_move_up held: P2 wish %s, P1 wish %s" % [p2.wish, p1.wish])
	ok = ok and p2.wish == Vector2(0, -1) and p1.wish == Vector2.ZERO
	Input.action_release("p2_move_up")

	# player 2 (Anderlecht, attacking the left goal) shoots and scores
	p2.position = Vector2(250.0, Pitch.field_rect().size.y / 2.0)
	m.ball.stop_at(p2.feet_front())
	m.ball.take(p2)
	m.home.keeper().position.y -= 200.0
	for o in m.home.players.slice(1):
		o.position.x = Pitch.field_rect().size.x * 0.6
	await physics_frame
	Input.action_press("p2_move_left")
	await create_timer(0.3).timeout
	Input.action_press("p2_shoot")
	await physics_frame
	Input.action_release("p2_shoot")
	Input.action_release("p2_move_left")
	await create_timer(2.0).timeout
	print("P2 shot: score %d - %d" % [m.home.score, m.away.score])
	ok = ok and m.away.score == 1
	m.queue_free()
	await process_frame

	# alone, any gamepad's left stick moves player 1
	m = scene.instantiate()
	m.get_script().players = 1
	root.add_child(m)
	await create_timer(1.5).timeout
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	await create_timer(0.2).timeout
	var wish: Vector2 = m.humans[0].controlled.wish
	print("1 player, pad stick right: wish %s" % wish)
	ok = ok and wish.x > 0.9
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	print("TWO PLAYER TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)
