extends SceneTree
## Fouls, cards, free kicks and offside.
## godot --headless --path game -s res://tests/rules_test.gd

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
	var bru = m.home  # attacks the right-hand goal in the first half
	var goal: Vector2 = bru.goal_attacked()

	# two yellows for the same Anderlecht player: the second is a red, and he's gone
	var hacker = m.away.players[7]
	await _play()
	m.book(hacker, false)
	var anim: String = m.referee._anim
	m.book(hacker, false)
	await create_timer(0.5).timeout
	print("booked twice: events %s, referee %s, sent off %s, visible %s, at %s" % [events, anim, hacker.sent_off, hacker.visible, hacker.position])
	ok = ok and events == ["yellow card:AND", "red card:AND"] and anim == "rcard" and hacker.sent_off \
		and not hacker.visible and not Pitch.field_rect().has_point(hacker.position)
	m.kickoff(m.away)
	await physics_frame
	print("at the kick-off he stays off: %s" % [not Pitch.field_rect().has_point(hacker.position)])
	ok = ok and not Pitch.field_rect().has_point(hacker.position)

	# offside: a striker beyond the last two Anderlecht players when the pass is played
	for onside in [false, true]:
		await _play()
		var passer = bru.players[6]
		var striker = bru.players[9]
		var last_two := [m.away.keeper(), m.away.players[2]]
		_park_except([passer, striker] + last_two)
		passer.position = goal - Vector2(Pitch.m(24.0), 0.0)  # a ground pass: a lofted one, the keeper may claim
		last_two[1].position = goal - Vector2(Pitch.m(16.0), Pitch.m(12.0))
		striker.position = goal - Vector2(Pitch.m(18.0 if onside else 12.0), -Pitch.m(5.0))
		m.ball.stop_at(passer.feet_front())
		m.ball.take(passer)
		events.clear()
		passer.pass_to(striker)
		var waited := 0.0
		while waited < 2.5 and m.ball.holder != striker and not events.has("offside:BRU"):
			await physics_frame
			waited += 1.0 / 60.0
		print("pass to a striker %s: %s, holder %s" % ["level-ish, onside" if onside else "past the last defender", events, m.ball.holder.name if m.ball.holder else "-"])
		if onside:
			ok = ok and not events.has("offside:BRU") and m.ball.holder == striker
		else:
			ok = ok and events.has("offside:BRU") and events.has("free kick:AND")

	# a free kick 22 m out: the AI shoots, a curler at goal
	await _play()
	var fouled = bru.players[9]
	fouled.position = goal - Vector2(Pitch.m(22.0), Pitch.m(6.0))
	events.clear()
	m._award_restart("free kick", bru, fouled.position)
	var kind := ""
	var waited := 0.0
	while waited < 4.0 and kind == "":
		await physics_frame
		waited += 1.0 / 60.0
		if m.ball.holder == null and m.ball.kick_kind != "":
			kind = m.ball.kick_kind
	print("free kick 22 m out: %s, ball heading %s" % [kind, "at goal" if m.ball.velocity.x > 0.0 else "away"])
	ok = ok and kind == "shot" and m.ball.velocity.x > 0.0

	# a slide that wins the ball: the tackler's touch (a throw-in off it goes to the other side)
	await _play()
	var dribbler = m.away.players[9]
	var tackler = bru.players[4]
	_park_except([dribbler, tackler, m.home.keeper(), m.away.keeper()])
	tackler.stats = {"slidingTackle": 95}
	var t := 0.0
	for attempt in 4:  # the dribbler may hop one (a dodge)
		await _play()
		dribbler.position = c
		dribbler.facing = 6
		dribbler.think_timer = 3.0
		dribbler._action_left = 0.0
		m.ball.stop_at(dribbler.feet_front())
		m.ball.take(dribbler)
		tackler.position = c - Vector2(30.0, 0.0)
		tackler.facing = 2  # head on: a fair tackle
		tackler.touch_cooldown = 0.0
		tackler._action_left = 0.0
		tackler.slide()
		t = 0.0
		while t < 1.0 and m.ball.holder == dribbler:
			await physics_frame
			t += 1.0 / 60.0
		if m.ball.holder != dribbler:
			break
	var toucher: String = m.ball.last_touch.name if m.ball.last_touch else "-"
	print("slide wins it: holder %s, last touch %s" % [m.ball.holder.name if m.ball.holder else "-", toucher])
	ok = ok and m.ball.holder != dribbler and m.ball.last_touch != dribbler

	# shooting, and knocked over before the foot meets the ball: no shot
	await _play()
	var shooter = bru.players[9]
	_park_except([shooter, m.away.keeper()])
	shooter.position = goal - Vector2(Pitch.m(20.0), 0.0)
	shooter._action_left = 0.0
	m.ball.stop_at(shooter.feet_front())
	m.ball.take(shooter)
	m.ball.kick_kind = ""
	shooter.shoot(goal)
	m.knock_down(shooter, "fall")
	await create_timer(0.4).timeout
	print("knocked over in the wind-up: ball kicked as %s, speed %.0f" % [m.ball.kick_kind if m.ball.kick_kind else "nothing", m.ball.velocity.length()])
	ok = ok and m.ball.kick_kind != "shot" and m.ball.velocity.length() < 300.0

	# an own goal: Brugge put it in their own net, so Brugge kick off
	await _play()
	var own = bru.players[2]
	var own_goal: Vector2 = bru.goal_defended()
	_park_except([own])
	m.home.keeper().position = c
	var conceded: int = bru.score
	m.ball.stop_at(own_goal + Vector2(bru.side * Pitch.m(3.0), 0.0))
	m.ball.last_touch = own
	m.ball.kick(Vector2(-bru.side * 500.0, 0.0), 0.0)
	var scored := false
	t = 0.0
	while t < 7.0 and not (scored and m.state == 0):
		await physics_frame
		t += 1.0 / 60.0
		scored = scored or m.away.score > 0
	print("own goal: Anderlecht %d, kick-off by %s" % [m.away.score, m.ball.holder.team.short if m.ball.holder else "-"])
	ok = ok and scored and m.state == 0 and m.ball.holder and m.ball.holder.team == bru and bru.score == conceded

	print("RULES TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)


## Wait for open play.
func _play() -> void:
	while m.state != 1:
		await physics_frame
	await physics_frame


## Everyone except `keep` (and the sent off) to the far touchline at halfway, still.
func _park_except(keep: Array) -> void:
	var c: Vector2 = Pitch.field_rect().get_center()
	for t in [m.home, m.away]:
		for p in t.players:
			if not p in keep and not p.sent_off:
				p.position = c + Vector2(-Pitch.m(3.0) * t.side, -Pitch.m(30.0))
				p.velocity = Vector2.ZERO
