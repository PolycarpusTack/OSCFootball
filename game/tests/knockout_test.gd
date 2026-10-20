extends SceneTree
## Knockout matches: level at full time goes to extra time, where a goal wins it (golden
## goal); still level, a penalty shoot-out until there's a winner. A friendly can end level.
## godot --headless --path game -s res://tests/knockout_test.gd

var m: Node
var events := []


func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	match_script.half_minutes = 2
	var ok := true

	# a friendly, level at full time: over, nobody wins
	match_script.knockout = false
	await _new_match()
	await _to_end_of_half(2)
	print("friendly, level after 90: state %d (6 = full time), winner %s" % [m.state, m.match_winner()])
	ok = ok and m.state == 6 and m.match_winner() == null and m.half == 2

	# knockout, level: extra time; a goal in it ends the match at once
	match_script.knockout = true
	await _new_match()
	await _to_end_of_half(2)
	var to_extra_time: bool = events.has("extra time:BRU")
	await _play()
	print("knockout, level after 90: extra time %s, half %d, it ends at %.0f s" % [to_extra_time, m.half, m.half_end()])
	ok = ok and to_extra_time and m.half == 3 and is_equal_approx(m.half_end(), 280.0)
	var bru = m.home
	var own = m.away.players[2]
	_park_except([])
	m.ball.stop_at(m.away.goal_defended() + Vector2(m.away.side * Pitch.m(3.0), 0.0))
	m.ball.last_touch = own
	m.ball.kick(Vector2(-m.away.side * 500.0, 0.0), 0.0)
	var waited := 0.0
	while m.state != 6 and waited < 8.0:
		await physics_frame
		waited += 1.0 / 60.0
	print("golden goal: state %d, score %d - %d, winner %s" % [m.state, bru.score, m.away.score, m.match_winner().short if m.match_winner() else "-"])
	ok = ok and m.state == 6 and m.match_winner() == bru

	# knockout, still level after extra time: penalties until there's a winner
	await _new_match()
	await _to_end_of_half(4)
	var shootout_state: int = m.state
	waited = 0.0
	while m.state != 6 and waited < 240.0:
		await create_timer(0.5).timeout
		waited += 0.5
	var h_kicks: Array = m.shootout.get(m.home, [])
	var a_kicks: Array = m.shootout.get(m.away, [])
	var winner = m.match_winner()
	print("level after 120: state %d (7 = shoot-out); after it: state %d, BRU %s, AND %s, winner %s, score %d - %d" % [
		shootout_state, m.state, h_kicks, a_kicks, winner.short if winner else "-", m.home.score, m.away.score])
	ok = ok and shootout_state == 7 and m.state == 6 and winner != null and m.home.score == m.away.score \
		and h_kicks.size() >= 3 and abs(h_kicks.size() - a_kicks.size()) <= 1

	print("KNOCKOUT TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)


func _new_match() -> void:
	if m:
		m.queue_free()
		await process_frame
	events.clear()
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	m.event.connect(func(kind, t): events.append("%s:%s" % [kind, t.short]))
	await _play()


## Play on (level, the clock jumped to the end of each half) until half `h` has ended.
func _to_end_of_half(h: int) -> void:
	while true:
		await _play()
		var this_half: int = m.half
		m.home.score = 0
		m.away.score = 0
		m.clock = m.half_end() - 0.1
		while m.state == 1 or m.state == 0:
			await physics_frame
		await physics_frame
		if this_half >= h:
			return


## Wait for open play.
func _play() -> void:
	while m.state != 1:
		await physics_frame
	await physics_frame


## Everyone except `keep` to the far touchline at halfway, still.
func _park_except(keep: Array) -> void:
	var c: Vector2 = Pitch.field_rect().get_center()
	for t in [m.home, m.away]:
		for p in t.players:
			if not p in keep and not p.sent_off:
				p.position = c + Vector2(-Pitch.m(3.0) * t.side, -Pitch.m(30.0))
				p.velocity = Vector2.ZERO
