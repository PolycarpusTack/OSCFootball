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
	ok = ok and events == ["yellow card:AND", "red card:AND"] and anim == "ref_card" and hacker.sent_off \
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

	# a shot back off the post to a teammate who was offside when it was struck: offside too
	await _play()
	var shooter2 = bru.players[10]
	var lurker = bru.players[9]
	_park_except([shooter2, lurker, m.away.keeper(), m.away.players[2]])
	m.away.keeper().position = goal + Vector2(-bru.side * Pitch.m(1.0), Pitch.m(6.0))  # beaten, at the far post
	m.away.players[2].position = goal - Vector2(bru.side * Pitch.m(16.0), Pitch.m(12.0))
	shooter2.position = goal - Vector2(bru.side * Pitch.m(18.0), 0.0)
	lurker.position = goal - Vector2(bru.side * Pitch.m(6.0), Pitch.m(4.5))
	m.ball.stop_at(shooter2.position + Vector2(bru.side * 12.0, 0.0))
	m.ball.last_touch = shooter2
	m.ball.kick(Vector2.ZERO, 0.0)  # the shot (the kick notes who's offside) ...
	m.ball.kick_kind = "shot"
	m.ball.stop_at(lurker.position + Vector2(bru.side * 30.0, 0.0))  # ... back off the post, rolling to him
	m.ball.velocity = Vector2(-bru.side * 120.0, 0.0)
	events.clear()
	var waited2 := 0.0
	while waited2 < 1.5 and not events.has("offside:BRU") and m.ball.holder != lurker:
		await physics_frame
		waited2 += 1.0 / 60.0
	print("rebound off the post to a teammate offside at the shot: %s" % [events])
	ok = ok and events.has("offside:BRU")

	# the AI's attackers wait level with the offside line, not beyond it
	var ai_script: GDScript = load("res://scripts/ai.gd")
	var beyond: Vector2 = goal - Vector2(bru.side * Pitch.m(3.0), 0.0)
	var held: Vector2 = ai_script._onside(lurker, m, beyond)
	var depth: float = absf(goal.x - held.x)
	print("AI attacker sent 3 m from goal waits %.1f m out; onside line %.1f m" % [depth / Pitch.PX_PER_M, m.onside_depth(bru) / Pitch.PX_PER_M])
	ok = ok and depth >= m.onside_depth(bru) - Pitch.m(0.6) and depth > Pitch.m(3.0)

	# a keeper holding it, an opponent right beside him: he waits (the human too) until he's
	# clear of him, or six seconds
	await _play()
	var k = m.home.keeper()
	var pest = m.away.players[9]
	_park_except([k, pest])
	k.position = m.home.goal_defended() + Vector2(bru.side * 40.0, 0.0)
	m.ball.stop_at(k.feet_front())
	m.ball.take(k)
	pest.position = k.position + Vector2(bru.side * 20.0, 0.0)
	pest.stats = {"sprintSpeed": 1, "acceleration": 1}
	await physics_frame
	var held_near: bool = not m.keeper_may_release(k)
	pest._play_action("fall")  # flat out: he can't clear the box
	pest._action_left = 10.0
	m.autoplay = false
	var hk = m.humans[0]
	if hk.controlled:
		hk.controlled.controlled = false
	hk.controlled = k
	k.controlled = true
	hk.switch_lock = 10.0
	var t2 := 0.0
	var released_at := -1.0
	while t2 < 8.0 and released_at < 0.0:
		Input.action_press("pass")
		await physics_frame
		Input.action_release("pass")
		await physics_frame
		t2 += 2.0 / 60.0
		if m.ball.holder != k:
			released_at = t2
	print("keeper, opponent alongside: may release %s; human pressing pass from the start released at %.1f s" % [not held_near, released_at])
	ok = ok and held_near and released_at >= 5.5 and released_at < 7.0
	m.autoplay = true
	k.controlled = false
	hk.controlled = null
	pest._action_left = 0.0

	# ... but out of his box it's at his feet, as anyone's: with an opponent beside him he plays it
	# at once, and the opponent can take it off him (the bug: the ball glued to his feet)
	await _play()
	_park_except([k, pest])
	pest._action_left = 0.0
	k.position = m.home.goal_defended() + Vector2(bru.side * Pitch.m(30.0), 0.0)
	m.ball.stop_at(k.feet_front())
	m.ball.take(k)
	pest.position = k.position + Vector2(bru.side * 20.0, 0.0)
	pest._play_action("fall")  # beside him, but no tackle yet
	pest._action_left = 10.0
	await physics_frame
	var may_outside: bool = m.keeper_may_release(k)
	m.autoplay = false
	hk.controlled = k
	k.controlled = true
	hk.switch_lock = 10.0
	var played_at := -1.0
	t2 = 0.0
	while t2 < 2.0 and played_at < 0.0:
		Input.action_press("pass")
		await physics_frame
		Input.action_release("pass")
		await physics_frame
		t2 += 2.0 / 60.0
		if m.ball.holder != k:
			played_at = t2
	print("keeper out of his box, opponent alongside: may release %s; human's pass played at %.2f s" % [may_outside, played_at])
	ok = ok and may_outside and played_at >= 0.0 and played_at < 0.5
	# and standing still with the ball out there, an opponent tackles him
	await _play()
	_park_except([k, pest])
	k.position = m.home.goal_defended() + Vector2(bru.side * Pitch.m(30.0), 0.0)
	k.velocity = Vector2.ZERO
	m.ball.stop_at(k.feet_front())
	m.ball.take(k)
	pest._action_left = 0.0
	pest.stats = {}
	pest.position = m.ball.position + Vector2(bru.side * 6.0, 0.0)
	var lost_at := -1.0
	t2 = 0.0
	while t2 < 6.0 and lost_at < 0.0:
		pest.wish = (m.ball.position - pest.position).normalized()
		await physics_frame
		t2 += 1.0 / 60.0
		if m.ball.holder != k:
			lost_at = t2
	print("keeper out of his box, standing with it: lost it at %.1f s" % lost_at)
	ok = ok and lost_at >= 0.0
	m.autoplay = true
	k.controlled = false
	hk.controlled = null

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
