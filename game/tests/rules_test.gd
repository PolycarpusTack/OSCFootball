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
		passer.position = goal - Vector2(Pitch.m(30.0), 0.0)
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
