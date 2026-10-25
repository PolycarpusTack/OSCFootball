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
	dribbler.velocity = Vector2.ZERO  # standing: a run carried into the hop takes him off the slide's line
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

	# body check (Chaos): double-tap a direction, then shoot, without the ball: costs 20 energy
	await create_timer(1.0).timeout
	while m.state != 1:  # not during a restart: the controls take it then
		await physics_frame
	var victim = m.away.players[9]
	m.ball.stop_at(victim.feet_front())
	m.ball.take(victim)
	await physics_frame
	var barger = m.humans[0].controlled  # after the switch to whoever chases him now
	m.humans[0].switch_lock = 2.0
	barger.position = Pitch.field_rect().get_center()  # well inside the lines: beside him isn't off the pitch
	barger.velocity = Vector2.ZERO
	victim.position = barger.position + Vector2(40, 0)
	barger._action_left = 0.0  # done with whatever he was doing (he may be the dodger above)
	barger.touch_cooldown = 0.45  # walking into him while tapping (0.32 s) isn't a steal: the barge comes after
	victim.think_timer = 3.0  # he keeps it: a pass in the air would make shoot a header
	m.ball.stop_at(victim.feet_front())
	m.ball.take(victim)
	m.home.energy = 100.0
	var checks := []
	m.event.connect(func(kind, t): if kind.begins_with("body check"): checks.append(kind))
	for i in 2:
		Input.action_press("move_right")
		await create_timer(0.08).timeout
		Input.action_release("move_right")
		await create_timer(0.08).timeout
	Input.action_press("shoot")
	await physics_frame
	Input.action_release("shoot")
	await create_timer(0.1).timeout
	print("body check: animation %s, energy %.0f, events %s" % [barger._anim, m.home.energy, checks])
	ok = ok and barger._anim in ["bodychk", "stumble"] and m.home.energy <= 100.0 - m.BODY_CHECK_COST + 1.0 and checks.has("body check")

	# skill moves: with the ball, a motion then switch. Double tap = nutmeg, down up = rainbow,
	# forward back = backheel (Brugge attacks to the right)
	var moves := []  # the human's: the AI makes skill moves too
	var highest := 0.0
	for motion in [["move_right", "move_right"], ["move_down", "move_up"], ["move_right", "move_left"]]:
		await create_timer(1.2).timeout
		while m.state != 1:
			await physics_frame
		var skiller = m.humans[0].controlled
		skiller._action_left = 0.0
		skiller.stats = {"ballControl": 95}  # a rainbow never scuffed
		for o in m.away.players:
			o.touch_cooldown = 2.0  # mapping the inputs here, not who wins it
		m.ball.stop_at(skiller.feet_front())
		m.ball.take(skiller)
		await physics_frame
		for dir in motion:
			Input.action_press(dir)
			await create_timer(0.08).timeout
			Input.action_release(dir)
			await create_timer(0.05).timeout
		Input.action_press("switch")
		await physics_frame
		Input.action_release("switch")
		await physics_frame
		var anim: String = skiller._anim
		moves.append(anim)
		for i in 70:
			await physics_frame
			highest = maxf(highest, m.ball.z) if anim == "rainbow" else highest
	print("skill moves: %s, rainbow up to %.0f px" % [moves, highest])
	ok = ok and moves == ["nutmeg", "rainbow", "bckheel"] and highest > 60.0

	# a nutmeg that gets through: the defender in front is left standing, the dribbler runs onto it
	var through := false
	var regained := false
	for attempt in 4:  # 90% odds: one of these gets through
		await create_timer(1.0).timeout
		var nut = m.humans[0].controlled
		var wall = m.away.players[6]
		nut.stats = {"dribbling": 95, "ballControl": 95}  # no heavy first touch running onto it
		wall.stats = {"defensiveAwareness": 40}
		nut._action_left = 0.0
		nut.facing = 2
		nut.velocity = Vector2(120.0, 0.0)
		wall.position = nut.position + Vector2(30.0, 0.0)
		for o in m.away.players:
			o.touch_cooldown = 0.0 if o == wall else 3.0  # just him and the nutmeg
		m.ball.stop_at(nut.feet_front())
		m.ball.take(nut)
		m.skill_move(nut, "nutmeg")
		if wall.touch_cooldown <= 0.0:
			continue  # he read it
		through = true
		Input.action_press("move_right")  # run on after it
		await create_timer(0.5).timeout  # the touch
		var chase := 0.0
		while chase < 2.0 and m.ball.holder != nut and m.ball.last_touch != wall:
			await physics_frame
			chase += 1.0 / 60.0
		Input.action_release("move_right")
		regained = m.ball.holder == nut
		break
	print("nutmeg through the defender: %s, dribbler collects it %s" % [through, regained])
	ok = ok and through and regained
	print("CONTROLS TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)
