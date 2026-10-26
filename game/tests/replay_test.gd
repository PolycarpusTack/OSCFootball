extends SceneTree
## Replays (EPIC F): the match keeps the last 10 s of what's drawn at 30 Hz, bounded, cheaply;
## a replay draws it without moving anything in the match; after a goal an instant replay plays
## at half speed with an "R", and any key skips it; the pause menu's REPLAY steps through it;
## the goal is kept as a highlight, played from the full-time screen.
## godot --headless --path game -s res://tests/replay_test.gd

func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	var ok := true
	match_script.half_minutes = 2
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)

	# F-1-AC1, AC2: 12 s of play: 300 frames (10 s at 30 Hz) and no more, each with everyone
	await create_timer(12.0).timeout
	var r = m.replay
	var actors: int = r.frames[-1][2].size()
	print("after 12 s: %d frames, %d drawn in each" % [r.frames.size(), actors])
	ok = ok and r.frames.size() == 300 and actors == 23  # 22 players and the referee
	var t0 := Time.get_ticks_usec()
	for i in 300:
		r.record_frame()
	var per_frame := (Time.get_ticks_usec() - t0) / 300.0
	print("recording: %.0f us a frame (SLO 1,000); still %d frames" % [per_frame, r.frames.size()])
	ok = ok and per_frame < 1000.0 and r.frames.size() == 300

	# a replay draws the past and leaves the match as it was
	var before: Array = (m.home.players + m.away.players).map(func(p): return p.position)
	var ball_before: Vector2 = m.ball.position
	r.play(2.0, 1.0, false)
	ok = ok and r.playing and paused
	for i in 10:
		await process_frame
	r.stop()
	var same: bool = (m.home.players + m.away.players).map(func(p): return p.position) == before and m.ball.position == ball_before
	print("replayed 2 s: the match as it was %s, running again %s" % [same, not paused])
	ok = ok and same and not paused and not r.playing

	# F-2-AC1: after a goal (a human's match: autoplay has no instant replays), the replay
	m.autoplay = false
	var striker = m.home.players[9]
	var c: Vector2 = Pitch.field_rect().get_center()
	for t in [m.home, m.away]:  # everyone out of the way, to the far touchline
		for p in t.players:
			p.position = c + Vector2(-Pitch.m(3.0) * t.side, -Pitch.m(30.0))
			p.velocity = Vector2.ZERO
	m.ball.stop_at(m.away.goal_defended() + Vector2(m.away.side * Pitch.m(3.0), 0.0))
	m.ball.last_touch = striker
	m.ball.kick(Vector2(-m.away.side * 500.0, 0.0), 0.0)
	var waited := 0.0
	while m.state != 2 and waited < 5.0:  # 2: GOAL
		await physics_frame
		waited += 1.0 / 60.0
	var time_scale := Engine.time_scale
	m._state_left = 0.0  # the celebration over
	await physics_frame
	await physics_frame
	var started: bool = r.playing and paused and r.speed == 0.5 and r.mark.visible
	print("goal: instant replay at %.1fx, R shown %s, %d frames" % [r.speed, r.mark.visible, r.clip.size()])
	ok = ok and started and r.clip.size() == 180
	# ... any key skips it, and play goes on to the kick-off
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	r._unhandled_input(key)
	await physics_frame
	await physics_frame
	print("skipped: replaying %s, paused %s, state %d (0 kick-off), time scale %s" % [r.playing, paused, m.state, Engine.time_scale])
	ok = ok and not r.playing and not paused and m.state == 0 and Engine.time_scale == time_scale

	# F-4-AC1: the goal is a highlight, cut AFTER (1 s) of play past it
	await create_timer(1.5).timeout
	print("highlights: %d, %s" % [r.highlights.size(), r.highlights.map(func(h): return h.size())])
	ok = ok and r.highlights.size() >= 1 and r.highlights.all(func(h): return h.size() <= 180)

	# F-3-AC1: the pause menu's REPLAY: stepped, slowed, back to the menu
	m._pause.set_paused(true)
	m._pause._pick = m._pause.ITEMS.find("REPLAY")
	m._pause._choose()
	var stepped_from: float = r.at
	var right := InputEventKey.new()
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	r._unhandled_input(right)
	var s := InputEventKey.new()
	s.physical_keycode = KEY_S
	s.pressed = true
	r._unhandled_input(s)
	print("pause replay: running %s, stepped %.0f -> %.0f, speed %.2f" % [r.running, stepped_from, r.at, r.speed])
	ok = ok and r.playing and not r.running and r.at == stepped_from + 1.0 and r.speed != 0.5
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	r._unhandled_input(esc)
	print("Esc: back in the pause menu %s, still paused %s" % [m._pause._box.visible, paused])
	ok = ok and not r.playing and m._pause._box.visible and paused
	m._pause.set_paused(false)

	# F-4: H on the full-time screen plays the highlights
	m._full_time("FULL TIME")
	var h := InputEventKey.new()
	h.physical_keycode = KEY_H
	h.pressed = true
	m._unhandled_input(h)
	print("full time, H: playing the highlights %s (%d frames)" % [r.playing, r.clip.size()])
	ok = ok and r.playing and r.clip.size() == r.highlights.reduce(func(n, x): return n + x.size(), 0) and not m._full_time_panel.visible
	r.stop()
	print("highlights over: the full-time screen back %s" % m._full_time_panel.visible)
	ok = ok and m._full_time_panel.visible

	print("REPLAY TEST PASSED" if ok else "REPLAY TEST FAILED")
	quit(0 if ok else 1)
