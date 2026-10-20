extends SceneTree
## Manual switching, the pass-target marker, and passes that avoid blocked lanes.
## godot --headless --path game -s res://tests/controls_test.gd

func _initialize() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await create_timer(1.6).timeout  # kick-off pause; Anderlecht has the ball
	var ok := true

	# switch: control jumps to another Brugge player and stays there for a moment
	var before = m.humans[0].controlled
	Input.action_press("switch")
	await physics_frame
	await physics_frame
	Input.action_release("switch")
	var after = m.humans[0].controlled
	await create_timer(0.5).timeout
	var holder = m.ball.holder  # winning the ball meanwhile rightly takes control to him
	var kept: bool = m.humans[0].controlled == after or (holder and holder.team == m.home and m.humans[0].controlled == holder)
	print("switch: %s -> %s, still %s after 0.5 s" % [before.name, after.name, m.humans[0].controlled.name])
	ok = ok and after != before and after.team == m.home and kept

	# pass lanes: two equal options, an opponent in the line to the first
	m.state = 5  # HALF_TIME with a long pause: freeze the AI
	m._state_left = 1e9
	var p = m.home.players[6]
	var a = m.home.players[9]
	var b = m.home.players[10]
	var c: Vector2 = Pitch.field_rect().get_center()
	p.position = c
	a.position = c + Vector2(250, -120)
	b.position = c + Vector2(250, 120)
	for o in m.away.players:
		o.position = Vector2(60, 60)  # out of the way
	for mate in m.home.players:
		if mate not in [p, a, b]:
			mate.position = c - Vector2(600, 0)
	var ai = load("res://scripts/ai.gd")
	var open_choice = ai.best_pass(p, m, Vector2.ZERO)
	var blocker = m.away.players[5]
	blocker.position = p.position + (open_choice.position - p.position) * 0.5
	var blocked_choice = ai.best_pass(p, m, Vector2.ZERO)
	print("pass lanes: open -> %s, with %s in that lane -> %s" % [open_choice.name, blocker.name, blocked_choice.name])
	ok = ok and blocked_choice != open_choice and blocked_choice in [a, b]

	# pass marker: holding the ball marks the teammate the pass would go to
	m.state = 1
	m.clock = 1.0
	p.facing = 2  # toward the two teammates (with no stick input the pass goes where he faces)
	m.ball.stop_at(p.feet_front())
	m.ball.take(p)
	m.humans[0].switch_lock = 0.0
	await physics_frame
	await physics_frame
	var marked := []
	for mate in m.home.players:
		if mate.pass_marker.a > 0.0:
			marked.append(mate.name)
	print("pass marker on %s (controlled %s)" % [marked, m.humans[0].controlled.name])
	ok = ok and m.humans[0].controlled == p and marked.size() == 1

	# throw-in with the stick held toward the touchline: thrown in from the hands, into
	# the field, not kicked straight out again (which gave throw-in after throw-in)
	var events := []
	m.event.connect(func(kind, t): events.append("%s:%s" % [kind, t.short]))
	var f: Rect2 = Pitch.field_rect()
	m._award_restart("throw-in", m.home, Vector2(f.size.x * 0.5, 0.0))
	var thrower = m._restart_taker
	Input.action_press("move_up")
	var held := true
	var anims := {}
	var t := 0.0
	while t < 5.0:
		if t > 1.5 and t < 1.55:
			Input.action_press("pass")
			await physics_frame
			Input.action_release("pass")
		await physics_frame
		t += 1.0 / 60.0
		anims[thrower._anim] = true
		if m.ball.holder == thrower and not thrower.busy() and t > 0.5:
			held = held and m.ball.in_hands
	Input.action_release("move_up")
	print("throw-in, stick toward the line: anims %s, in hands %s, events %s" % [anims.keys(), held, events])
	ok = ok and anims.has("throwin") and held and events.count("throw-in:AND") == 0

	# aim arrow: with the ball, a short arrow toward the shot; holding shoot makes it longer
	m.state = 1
	var shooter = m.home.players[9]
	shooter.position = Pitch.field_rect().get_center()
	m.ball.stop_at(shooter.feet_front())
	m.ball.take(shooter)
	m.humans[0].switch_lock = 0.0
	await physics_frame
	await physics_frame
	var idle: Dictionary = m.aim_arrow(m.humans[0])
	Input.action_press("shoot")
	await create_timer(0.4).timeout
	var charged: Dictionary = m.aim_arrow(m.humans[0])
	Input.action_release("shoot")
	print("aim arrow: %.0f px idle, %.0f px holding shoot 0.4 s" % [idle.get("length", 0.0), charged.get("length", 0.0)])
	ok = ok and not idle.is_empty() and not charged.is_empty() and charged.length > idle.length + 40.0

	# dodge: with the ball, switch just as a slide comes in: he hops it and keeps the ball
	Input.action_release("shoot")
	await create_timer(1.0).timeout
	var dribbler = m.home.players[9]
	m.ball.stop_at(dribbler.feet_front())
	m.ball.take(dribbler)
	var dodges := []
	m.event.connect(func(kind, t): if kind == "dodge": dodges.append(t.short))
	var slider = m.away.players[4]
	dribbler.facing = 2
	slider.position = dribbler.position + Vector2(70, 0)
	slider.facing = 6  # toward him, head on: a fair tackle unless he dodges
	slider.touch_cooldown = 0.0
	slider.slide()
	Input.action_press("switch")
	await physics_frame
	Input.action_release("switch")
	await create_timer(0.6).timeout
	print("dodge: still has the ball %s, dodges %s" % [m.ball.holder == dribbler, dodges])
	ok = ok and m.ball.holder == dribbler and dodges == ["BRU"]
	print("CONTROLS TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)
