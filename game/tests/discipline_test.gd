extends SceneTree
## The referee's judgement on fouls: advantage (the fouled side keeps the ball: play on, the
## card at the next stoppage; the offenders win it: back for the free kick), the late whistle
## (a man fouled behind his back still down when he looks), the warning before the card,
## repeat offenders dealt with harder, and the last man's straight red.
## godot --headless --path game -s res://tests/discipline_test.gd

const AWAY := Vector2(-5000, -5000)

var m: Node
var events := []


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	m.event.connect(func(kind, t): events.append("%s:%s" % [kind, t.short]))
	await create_timer(1.6).timeout
	m.chaos_actions.ai_enabled = false  # no specials knocking things about
	var ok: bool = m.chaos
	var c: Vector2 = Pitch.field_rect().get_center()
	var hacker = m.away.players[6]
	var victim = m.home.players[6]
	var mate = m.home.players[7]

	# advantage played: the ball runs on to a teammate, play goes on; the card at the stoppage
	await _play()
	_clear()
	_set_up_foul(hacker, victim, mate, c)
	m._foul(hacker, victim, false)
	hacker.position = AWAY  # out of it: nobody to win it back
	var adv: bool = events.has("advantage:BRU") and m.state == 1
	var meter_in_play: float = hacker.discipline
	await create_timer(m.ADVANTAGE_TIME + 0.3).timeout
	var played: bool = events.has("advantage played:BRU")
	m._award_restart("throw-in", m.home, Vector2(400, 0))
	print("advantage: %s, then %s; meter in play %.0f, after the throw-in %.0f" % [adv, played, meter_in_play, hacker.discipline])
	ok = ok and adv and played and meter_in_play == 0.0 and hacker.discipline > 0.0

	# advantage lost: the offenders win the ball, and he brings it back for the free kick
	await _play()
	_clear()
	_set_up_foul(hacker, victim, mate, c)
	m._foul(hacker, victim, false)
	var thief = m.away.players[7]
	thief.position = m.ball.position
	m.ball.take(thief)
	await physics_frame
	await physics_frame
	var back: bool = events.has("brought back:BRU") and events.has("free kick:BRU") and m.state != 1 \
		and m._restart_taker.team == m.home
	print("advantage lost: %s (%s)" % [back, events])
	ok = ok and back

	# a foul behind his back: he turns, the man is still down: a late whistle
	await _play()
	_clear()
	m.ball.release()
	m.referee.position = c + Vector2(Pitch.m(20.0), 0.0)
	m.referee_gaze = Vector2.RIGHT  # away from the centre spot
	victim.position = c
	m._foul(hacker, victim, false)
	var unseen: bool = events == ["unseen foul:AND"]
	m.referee_gaze = Vector2.LEFT  # back toward him
	await physics_frame
	await physics_frame
	var late: bool = events.has("late whistle:AND") and events.has("free kick:BRU")
	print("unseen %s, then he looks: late whistle %s (%s)" % [unseen, late, events])
	ok = ok and unseen and late

	# ... but not once the man's up again
	await _play()
	_clear()
	m.ball.release()
	m.referee.position = c + Vector2(Pitch.m(20.0), 0.0)
	m.referee_gaze = Vector2.RIGHT
	victim.position = c
	m._foul(hacker, victim, false)
	m._unseen.left = 0.0
	await physics_frame
	m.referee_gaze = Vector2.LEFT
	await physics_frame
	print("looks too late: %s" % [events])
	ok = ok and not events.has("late whistle:AND")

	# called over before the card: the first time past the warning mark, not again until booked
	await _play()
	_clear()
	var rough = m.away.players[8]
	rough.discipline = 50.0
	_seen_foul(rough, victim, c)
	var warned: bool = events.has("ref warning:AND")
	await _play()
	_clear()
	rough.discipline = 50.0
	rough.fouls = 0
	_seen_foul(rough, victim, c)
	print("warned at %.0f: %s; again before a booking: %s" % [50.0 + 30.0, warned, events.has("ref warning:AND")])
	ok = ok and warned and not events.has("ref warning:AND")

	# repeat offenders: each foul called before counts; a booked man fills slower
	var serial = m.away.players[5]
	var gains := []
	for i in 3:
		await _play()
		serial.discipline = 0.0
		serial.yellow = false
		_seen_foul(serial, victim, c)
		gains.append(serial.discipline)
	await _play()
	serial.discipline = 0.0
	serial.yellow = true
	serial.fouls = 0
	_seen_foul(serial, victim, c)
	print("calm referee, fouls from the front: %s; booked, first foul %.1f" % [gains, serial.discipline])
	ok = ok and gains[0] < gains[1] and gains[1] < gains[2] and serial.discipline < 30.0

	# the last man: through on goal, only the keeper to beat; a straight red often, not always
	var goal: Vector2 = m.away.goal_defended()
	var defender = m.away.players[2]
	var striker = m.home.players[9]
	for p in m.away.players:
		if p.role != "G":
			p.position = AWAY  # all of them upfield
	striker.position = goal + (c - goal).normalized() * Pitch.m(25.0)
	defender.position = striker.position + (c - goal).normalized() * Pitch.m(1.0)
	var through: bool = m.last_man(defender, striker)
	var cover = m.away.players[3]
	cover.position = goal + (c - goal).normalized() * Pitch.m(12.0)
	var covered: bool = m.last_man(defender, striker)
	cover.position = AWAY
	var reds := 0
	for i in 200:
		defender.sent_off = false
		defender.yellow = false
		defender.discipline = 0.0
		defender.position = striker.position + (c - goal).normalized() * Pitch.m(1.0)
		_clear()
		m._punish({"by": defender, "victim": striker, "from_behind": true, "spot": striker.position})
		if events.has("last man:AND"):
			reds += 1
	print("through on goal: last man %s, with a covering defender %s; straight red %d of 200" % [through, covered, reds])
	ok = ok and through and not covered and reds > 90 and reds < 150

	print("DISCIPLINE TEST PASSED" if ok else "DISCIPLINE TEST FAILED")
	quit(0 if ok else 1)


## `victim` on the ball at `at` facing their goal, `mate` 3 m ahead of him, the rest of both
## sides out of the way; the referee next to it, calm.
func _set_up_foul(hacker, victim, mate, at: Vector2) -> void:
	for t in [m.home, m.away]:
		for p in t.players:
			if p.role != "G" and p != hacker and p != victim:
				p.position = AWAY
	victim.position = at
	victim.facing = root.get_node("Anims").facing_from(Vector2(m.home.side, 0.0))
	mate.position = at + Vector2(m.home.side * Pitch.m(3.0), 0.0)
	hacker.position = at - Vector2(m.home.side * Pitch.m(1.0), 0.0)
	hacker.discipline = 0.0
	m.ball.stop_at(victim.feet_front())
	m.ball.take(victim)
	m.referee.position = at + Vector2(0.0, Pitch.m(4.0))
	m.ref_mood.clear()


## A foul the referee sees, with no advantage to play.
func _seen_foul(by, victim, at: Vector2) -> void:
	m.ball.release()
	m.ref_mood.clear()
	m.referee.position = at + Vector2(0.0, Pitch.m(4.0))
	victim.position = at
	m._foul(by, victim, false)


func _clear() -> void:
	events.clear()
	m._late_cards.clear()
	m._advantage = {}
	m._unseen = {}


func _play() -> void:
	while m.state != 1:
		await physics_frame
	await physics_frame
