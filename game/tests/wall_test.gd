extends SceneTree
## The free-kick wall: within 30 m of goal the defenders nearest the ball line up 9.15 m from
## it, across the line to the goal (four men from 18 m, two from 28 m), and stand there until
## the kick; a low shot into it is blocked; from 40 m there's no wall.
## godot --headless --path game -s res://tests/wall_test.gd

var m: Node


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	await create_timer(1.6).timeout
	m.chaos_actions.ai_enabled = false
	var ok := true
	var goal: Vector2 = m.home.goal_attacked()
	var centre: Vector2 = Pitch.field_rect().get_center()
	var out: Vector2 = (centre - goal).normalized()

	# 18 m out, central: four men, 9.15 m off, across the line to goal
	await _play()
	var spot := goal + out * Pitch.m(18.0)
	m._award_restart("free kick", m.home, spot)
	var wall: Array = m._wall.duplicate()
	var ball_at: Vector2 = m.ball.position
	var lined := wall.size() == 4
	for p in wall:
		var along: float = (p.position - ball_at).dot(-out) / Pitch.PX_PER_M
		lined = lined and p.team == m.away and p.role != "G" and absf(along - 9.15) < 0.6 \
			and absf((p.position - ball_at).dot(out.orthogonal())) < Pitch.m(2.0)
	print("18 m: %d in the wall (%s), %s" % [wall.size(), wall.map(func(p): return "%.1f m" % (p.position.distance_to(ball_at) / Pitch.PX_PER_M)), lined])
	ok = ok and lined

	# ... they stand there until the kick
	var spots: Array = wall.map(func(p): return p.position)
	await create_timer(0.6).timeout
	var still := true
	for i in wall.size():
		still = still and wall[i].position.distance_to(spots[i]) < 1.0
	print("0.6 s later the wall hasn't moved: %s" % still)
	ok = ok and still

	# a low shot straight at it is blocked
	var taker = m._restart_taker
	m._state_left = 1e9  # the AI won't take it: we do
	var target: Vector2 = (wall[1].position + wall[2].position) / 2.0
	for p in wall:
		p.touch_cooldown = 0.0
	taker.kick_to(target + (target - ball_at), 700.0, 0.0, "kick", "shot")
	m._restart_taken = true  # as _restart does once it's kicked: play on when the ball's gone
	var blocked := false
	for i in 90:
		await physics_frame
		if m.ball.last_touch in wall:
			blocked = true
			break
	print("low shot into the wall: blocked %s, wall released %s" % [blocked, m._wall.is_empty()])
	ok = ok and blocked and m._wall.is_empty()

	# 28 m: two; 40 m: none
	await _play()
	m._award_restart("free kick", m.home, goal + out * Pitch.m(28.0))
	var two: int = m._wall.size()
	await _play()
	m._award_restart("free kick", m.home, goal + out * Pitch.m(40.0))
	var none: int = m._wall.size()
	print("28 m: %d in the wall; 40 m: %d" % [two, none])
	ok = ok and two == 2 and none == 0

	print("WALL TEST PASSED" if ok else "WALL TEST FAILED")
	quit(0 if ok else 1)


func _play() -> void:
	m._wall.clear()
	m.state = 1
	await physics_frame
