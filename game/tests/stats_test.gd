extends SceneTree
## Post-match stats: shots, saves, fouls, cards and possession are counted from the match's
## events; the full-time screen shows them with the Man of the Match.
## godot --headless --path game -s res://tests/stats_test.gd

var m: Node


func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	match_script.half_minutes = 2
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	await create_timer(1.6).timeout
	var ok := true
	var bru = m.home
	var stats = m.stats

	# a shot from 18 m by the Brugge striker: one shot
	await _play()
	var striker = bru.players[9]
	_park_except([striker, m.away.keeper()])
	striker.position = bru.goal_attacked() - Vector2(bru.side * Pitch.m(18.0), 0.0)
	striker._action_left = 0.0
	m.ball.stop_at(striker.feet_front())
	m.ball.take(striker)
	striker.shoot(bru.goal_attacked())
	await create_timer(0.6).timeout
	print("one shot: BRU shots %d, AND shots %d" % [stats.counts[bru]["shots"], stats.counts[m.away]["shots"]])
	ok = ok and stats.counts[bru]["shots"] == 1 and stats.counts[m.away]["shots"] == 0

	# a pass is not a shot
	await _play()
	var mid = bru.players[6]
	_park_except([mid, bru.players[7]])
	mid.position = Pitch.field_rect().get_center()
	mid._action_left = 0.0
	m.ball.stop_at(mid.feet_front())
	m.ball.take(mid)
	var shots: int = stats.counts[bru]["shots"]
	mid.pass_to(bru.players[7])
	await create_timer(0.6).timeout
	print("a pass: BRU shots still %d" % stats.counts[bru]["shots"])
	ok = ok and stats.counts[bru]["shots"] == shots

	# a foul, a booking: counted for the fouling side
	await _play()
	var fouls: int = stats.counts[m.away]["fouls"]
	m._foul(m.away.players[4], bru.players[9], false)
	var yellows: int = stats.counts[m.away]["yellow cards"]
	m.book(m.away.players[5], false)
	print("a foul and a yellow for AND: fouls +%d, yellows +%d" % [stats.counts[m.away]["fouls"] - fouls, stats.counts[m.away]["yellow cards"] - yellows])
	ok = ok and stats.counts[m.away]["fouls"] == fouls + 1 and stats.counts[m.away]["yellow cards"] == yellows + 1

	# a save: the keeper holding it at the time gets the credit
	m.ball.take(m.away.keeper())
	m.event.emit("save", m.away)
	print("a save: AND saves %d, keeper's points %.0f" % [stats.counts[m.away]["saves"], stats.points.get(m.away.keeper(), 0.0)])
	ok = ok and stats.counts[m.away]["saves"] == 1 and stats.points.get(m.away.keeper(), 0.0) > 0.0

	# possession: a second on the ball for Brugge counts for Brugge
	var before: float = stats.possession[bru]
	m.ball.take(striker)
	stats.tick(1.0)
	print("a second on the ball for BRU: +%.1f s, share %d%%" % [stats.possession[bru] - before, stats.possession_percent(bru)])
	ok = ok and is_equal_approx(stats.possession[bru] - before, 1.0) \
		and stats.possession_percent(bru) + stats.possession_percent(m.away) == 100

	# a goal for the striker: he's the Man of the Match, on the full-time screen
	m.ball.last_touch = striker
	m.event.emit("goal", bru)
	bru.score += 1
	await _play()
	m.half = 2
	m.clock = m.half_end() - 0.1
	while m.state != 6:
		await physics_frame
	await process_frame
	var texts := _texts(m._full_time_panel)
	var motm = stats.man_of_the_match()
	print("full time: Man of the Match %s; screen shows SHOTS %s, POSSESSION %s, his name %s" % [
		motm.display_name if motm else "-", texts.has("SHOTS"), texts.has("POSSESSION"),
		texts.any(func(t): return motm and motm.display_name in t)])
	ok = ok and motm == striker and m._full_time_panel.visible and texts.has("SHOTS") and texts.has("POSSESSION") \
		and texts.any(func(t): return striker.display_name in t)

	print("STATS TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)


func _texts(node: Node) -> Array:
	var out := []
	for c in node.get_children():
		if c is Label:
			out.append(c.text)
		out.append_array(_texts(c))
	return out


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
