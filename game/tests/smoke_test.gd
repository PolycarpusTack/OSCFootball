extends SceneTree
## Headless smoke test of the match: kick-off, dribbling, a shot, and the AI
## moving the ball about. godot --headless --path game -s res://tests/smoke_test.gd

func _initialize() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await create_timer(1.5).timeout  # kick-off pause
	var ok := true

	# Anderlecht kicks off; after a few seconds of AI play the ball must have moved
	var start: Vector2 = m.ball.position
	await create_timer(4.0).timeout
	var moved: float = m.ball.position.distance_to(start)
	print("ball moved %.0f px in 4 s of play, holder: %s" % [moved, m.ball.holder.name if m.ball.holder else "none"])
	ok = ok and moved > 50.0

	# give Brugge the ball near the Anderlecht box and shoot
	var p = m.home.players[9]  # untyped: -s scripts cannot see the Anims autoload at compile time
	p.position = Vector2(Pitch.field_rect().size.x - 250.0, Pitch.field_rect().size.y / 2.0)
	m.ball.stop_at(p.feet_front())
	m.ball.take(p)
	m.away.keeper().position.y -= 200.0  # out of the way, so the shot must count
	await physics_frame
	Input.action_press("move_right")
	await create_timer(0.3).timeout
	Input.action_press("shoot")
	await physics_frame
	Input.action_release("shoot")
	Input.action_release("move_right")
	await create_timer(2.0).timeout
	print("score %s %d - %d %s, state %d" % [m.home.short, m.home.score, m.away.score, m.away.short, m.state])
	ok = ok and m.home.score == 1

	# combos: down, down-forward, forward + shoot = fireball (costs 50); hold shoot with a
	# full bar = thunder strike (costs 100)
	var supers := []
	m.event.connect(func(kind, _t): supers.append(kind))
	for test in [["fireball", 100.0, 50.0], ["thunder", 100.0, 0.0]]:
		while m.state != 1:  # wait for the kick-off after a goal
			await physics_frame
		p.position = Vector2(Pitch.field_rect().size.x * 0.62, Pitch.field_rect().size.y * 0.3)  # away from the kick-off crowd
		m.ball.stop_at(p.feet_front())
		m.ball.take(p)
		m.home.energy = test[1]
		for o in m.away.players.slice(1):  # nobody close enough to rob the charging striker
			o.position.x = Pitch.field_rect().size.x * 0.25
		await physics_frame
		if test[0] == "fireball":
			for keys in [["move_down"], ["move_down", "move_right"], ["move_right"]]:
				for k in keys:
					Input.action_press(k)
				await create_timer(0.1).timeout
				for k in keys:
					Input.action_release(k)
			Input.action_press("move_right")
		Input.action_press("shoot")
		await create_timer(0.05 if test[0] == "fireball" else 1.0).timeout
		Input.action_release("shoot")
		Input.action_release("move_right")
		await create_timer(0.6).timeout
		print("%s: holder %s, events %s, ball power '%s', energy %.0f" % [test[0], m.ball.holder.name if m.ball.holder else "-", supers, m.ball.power, m.home.energy])
		ok = ok and supers.has(test[0]) and absf(m.home.energy - test[2]) < 3.0  # dribbling refills a little
		await create_timer(1.5).timeout
	# out of play: Brugge knocks it over the top touchline -> Anderlecht throw-in, then play resumes
	while m.state != 1:
		await physics_frame
	var events := []
	m.event.connect(func(kind, t): events.append("%s:%s" % [kind, t.short]))
	p.position = Vector2(Pitch.field_rect().size.x * 0.4, 40.0)
	m.ball.stop_at(p.position + Vector2(0, -10))
	m.ball.last_touch = p
	p.touch_cooldown = 1.0  # so it doesn't just collect it again
	m.ball.kick(Vector2(0, -300), 0.0)
	await create_timer(0.5).timeout
	var restarted: bool = m.state == 4  # RESTART
	await create_timer(2.5).timeout
	print("out of play: events %s, restart seen %s, state now %d" % [events, restarted, m.state])
	ok = ok and events.has("throw-in:AND") and restarted and m.state == 1
	# goal kick: a Brugge striker loitering by the Anderlecht keeper must be kept out of
	# the box until the kick, and mustn't be the one who gets the ball
	m._award_restart("goal kick", m.away, m.away.goal_defended() + Vector2(m.away.side * Pitch.m(5.5), 0.0))
	var lurker = m.home.players[9]
	lurker.position = m.ball.position + Vector2(m.away.side * 15.0, 5.0)
	await physics_frame  # the match pushes him back on its next frame
	await physics_frame
	var closest := INF
	while m.state == 4:
		await physics_frame
		closest = minf(closest, lurker.position.distance_to(m.ball.position))
	await create_timer(1.0).timeout
	var last_team: String = m.ball.last_touch.team.short if m.ball.last_touch else "-"
	print("goal kick: lurker came within %.1f m, last touch after the kick %s" % [closest / Pitch.PX_PER_M, last_team])
	ok = ok and closest >= Pitch.m(9.15) - 1.0 and last_team == "AND"
	# keeper with the ball in his hands, an opposing striker right next to him: the striker
	# must leave the box, and the keeper's pass (yours: X) must not go to him
	for side in ["BRU", "AND"]:
		while m.state != 1:
			await physics_frame
		var keeping = m.home if side == "BRU" else m.away
		var k = keeping.keeper()
		var striker = (m.away if side == "BRU" else m.home).players[9]
		k.position = keeping.goal_defended() + Vector2(keeping.side * 40.0, 0)
		m.ball.stop_at(k.feet_front())
		m.ball.take(k)
		striker.position = k.position + Vector2(keeping.side * 30.0, 10.0)
		var waited := 0.0
		while m.ball.holder == k and waited < 6.0:
			if side == "BRU" and waited > 1.5:
				Input.action_press("pass")
				await physics_frame
				Input.action_release("pass")
			await physics_frame
			waited += 1.0 / 60.0
		var gap: float = striker.position.distance_to(k.position) / Pitch.PX_PER_M
		var first := ""
		while first == "" and waited < 9.0:
			await physics_frame
			waited += 1.0 / 60.0
			if m.ball.last_touch != k and m.ball.last_touch:
				first = m.ball.last_touch.team.short
		print("%s keeper holding, striker alongside: %.1f m away when he played it, first touch %s" % [side, gap, first])
		ok = ok and gap >= 9.0 and first != ("AND" if side == "BRU" else "BRU")

	# a slide from behind outside the box: one foul, not one per frame of the slide
	while m.state != 1:
		await physics_frame
	var fouls := events.count("foul:AND")
	var victim = m.home.players[6]
	victim.position = Pitch.field_rect().get_center()
	victim.facing = 2
	m.ball.stop_at(victim.feet_front())
	m.ball.take(victim)
	var slider = m.away.players[6]
	slider.position = victim.position - Vector2(16, 0)
	slider.facing = 2
	slider.slide()
	await create_timer(1.0).timeout
	print("slide from behind: %d foul(s)" % (events.count("foul:AND") - fouls))
	ok = ok and events.count("foul:AND") - fouls == 1

	# half time: ends change, Brugge kick off; full time stops the match
	m.clock = m.HALF_SECONDS - 0.2
	var side_before: int = m.home.side
	await create_timer(5.5).timeout
	print("half time: half %d, Brugge side %d -> %d, state %d" % [m.half, side_before, m.home.side, m.state])
	ok = ok and m.half == 2 and m.home.side == -side_before and m.state == 1
	m.clock = m.HALF_SECONDS * 2.0 - 0.2
	await create_timer(0.5).timeout
	print("full time: state %d, events %s" % [m.state, events.slice(-2)])
	ok = ok and m.state == 6 and events.has("full time:BRU")
	print("SMOKE TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)
