extends SceneTree
## Chaos referee: the view cone (unseen fouls go unpunished) and the discipline meter
## (seen fouls and body checks fill it; full is a booking).
## godot --headless --path game -s res://tests/referee_test.gd

var m: Node
var events := []


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	m.event.connect(func(kind, t): events.append("%s:%s" % [kind, t.short]))
	await create_timer(1.6).timeout
	var ok := true
	var c: Vector2 = Pitch.field_rect().get_center()
	var hacker = m.away.players[6]
	var victim = m.home.players[6]

	# his gaze turns to the ball
	await _play()
	m.referee_gaze = (m.referee.position - m.ball.position).normalized()  # looking away from it
	await create_timer(1.5).timeout
	var off := rad_to_deg(absf(m.referee_gaze.angle_to(m.ball.position - m.referee.position)))
	print("looking away from the ball, 1.5 s later his gaze is %.0f° off it" % off)
	ok = ok and off < 20.0

	# a foul he sees: a free kick, and 30 on the meter for a foul from the front
	await _play()
	_look_at(c)
	victim.position = c
	events.clear()
	m._foul(hacker, victim, false)
	print("seen foul from the front: events %s, discipline %.0f" % [events, hacker.discipline])
	ok = ok and events.has("foul:AND") and events.has("free kick:BRU") and is_equal_approx(hacker.discipline, 30.0)

	# a foul behind his back, 20 m away: play on, nothing on the meter
	await _play()
	var before: float = hacker.discipline
	m.referee.position = c + Vector2(Pitch.m(20.0), 0.0)
	m.referee_gaze = Vector2.RIGHT  # away from the centre spot
	victim.position = c
	events.clear()
	m._foul(hacker, victim, false)
	print("foul behind his back: events %s, state %d (1 = play on), discipline %.0f -> %.0f" % [events, m.state, before, hacker.discipline])
	ok = ok and events == ["unseen foul:AND"] and m.state == 1 and is_equal_approx(hacker.discipline, before)

	# ... but right next to him he sees it whichever way he looks
	m.referee.position = c + Vector2(Pitch.m(4.0), 0.0)
	m.referee_gaze = Vector2.RIGHT
	print("4 m from him, looking away: sees it %s" % m.referee_sees(c))
	ok = ok and m.referee_sees(c)

	# a seen body check fills it too
	await _play()
	_look_at(c)
	var barger = m.away.players[7]
	var holder = m.home.players[9]
	holder.position = c
	m.ball.stop_at(holder.feet_front())
	m.ball.take(holder)
	m._body_check_hits(barger, holder)
	print("seen body check: discipline %.0f" % barger.discipline)
	ok = ok and is_equal_approx(barger.discipline, 20.0)

	# the meter full: a yellow, and it starts again; full again: the second yellow, off
	await _play()
	_look_at(c)
	victim.position = c
	hacker.discipline = 80.0
	events.clear()
	m._foul(hacker, victim, false)
	var first := events.filter(func(e): return "card" in e)
	var after_first: float = hacker.discipline
	await _play()
	_look_at(c)
	victim.position = c
	hacker.discipline = 80.0
	events.clear()
	m._foul(hacker, victim, false)
	var second := events.filter(func(e): return "card" in e)
	print("meter full: %s, then at %.0f; full again: %s, sent off %s" % [first, after_first, second, hacker.sent_off])
	ok = ok and first == ["yellow card:AND"] and after_first == 0.0 and second == ["red card:AND"] and hacker.sent_off

	# it cools down in play
	var cooler = m.away.players[8]
	cooler.discipline = 50.0
	await _play()
	await create_timer(2.0).timeout
	print("cooling: 50 -> %.1f after 2 s of play" % cooler.discipline)
	ok = ok and cooler.discipline < 48.5 and cooler.discipline > 45.0

	print("REFEREE TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)


## The referee 10 m from `pos`, looking straight at it.
func _look_at(pos: Vector2) -> void:
	m.referee.position = pos + Vector2(0.0, -Pitch.m(10.0))
	m.referee_gaze = Vector2.DOWN


## Wait for open play.
func _play() -> void:
	while m.state != 1:
		await physics_frame
	await physics_frame
