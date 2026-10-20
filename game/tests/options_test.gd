extends SceneTree
## Match options: half length, and the offside / fouls / cards toggles are respected.
## godot --headless --path game -s res://tests/options_test.gd

var m: Node
var events := []


func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	match_script.half_minutes = 2
	match_script.offside_on = false
	match_script.fouls_on = false
	match_script.cards_on = false
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	m.event.connect(func(kind, t): events.append("%s:%s" % [kind, t.short]))
	await create_timer(1.6).timeout
	var ok := true
	var c: Vector2 = Pitch.field_rect().get_center()
	var bru = m.home

	# half length: 2 minutes a half, the half ends there
	await _play()
	m.clock = 119.8
	await create_timer(0.5).timeout
	print("half length 2 min: half_seconds %.0f, state after 120 s %d (5 = half time)" % [m.half_seconds, m.state])
	ok = ok and m.half_seconds == 120.0 and m.state == 5

	# offside off: a striker past the last defender is in an offside position, but not flagged
	await _play()
	var goal: Vector2 = bru.goal_attacked()  # ends changed at half time
	var passer = bru.players[6]
	var striker = bru.players[9]
	_park_except([passer, striker, m.away.keeper()])
	passer.position = goal - Vector2(Pitch.m(24.0), 0.0)
	striker.position = goal - Vector2(Pitch.m(8.0), -Pitch.m(5.0))
	m.ball.stop_at(passer.feet_front())
	m.ball.last_touch = passer
	m._note_offside()
	var positions: int = m.offside_players(passer).size()
	print("offside off: %d in an offside position, %d flagged" % [positions, m._offside.size()])
	ok = ok and positions > 0 and m._offside.is_empty()

	# fouls off: slides from behind (and missed ones) never take the man
	var dribbler = m.away.players[9]
	var tackler = bru.players[4]
	tackler.stats = {"slidingTackle": 40}
	events.clear()
	for attempt in 4:
		await _play()
		_park_except([dribbler, tackler, m.home.keeper(), m.away.keeper()])
		dribbler.position = c
		dribbler.facing = 2
		dribbler.think_timer = 3.0
		dribbler._action_left = 0.0
		m.ball.stop_at(dribbler.feet_front())
		m.ball.take(dribbler)
		tackler.position = c - Vector2(30.0, 0.0)
		tackler.facing = 2  # the same way: from behind
		tackler.touch_cooldown = 0.0
		tackler._action_left = 0.0
		tackler.slide()
		await create_timer(0.8).timeout
	print("fouls off, 4 slides from behind: events %s" % [events])
	ok = ok and not events.has("foul:BRU") and not events.has("free kick:AND") and not events.has("penalty:AND")

	# cards off: fouls (called directly) are never booked
	events.clear()
	for i in 10:
		await _play()
		m._foul(tackler, dribbler, true)
	var cards := events.filter(func(e): return e.begins_with("yellow") or e.begins_with("red"))
	print("cards off, 10 fouls from behind: %d fouls, cards %s" % [events.count("foul:BRU"), cards])
	ok = ok and events.count("foul:BRU") == 10 and cards.is_empty()

	print("OPTIONS TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)


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
