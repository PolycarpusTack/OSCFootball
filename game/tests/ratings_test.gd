extends SceneTree
## EA ratings change play: an elite player against a poor one, same situation.
## godot --headless --path game -s res://tests/ratings_test.gd

var m: Node


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	await create_timer(0.5).timeout
	m.state = 5  # HALF_TIME with a long pause: nobody's AI moves them, no rules apply
	m._state_left = 1e9
	var ok := true
	var fast = m.home.players[2]
	var slow = m.home.players[3]

	# pace: 3 s flat out from standing
	fast.stats = {"sprintSpeed": 92, "acceleration": 92}
	slow.stats = {"sprintSpeed": 45, "acceleration": 45}
	var start := Vector2(300, 300)
	for p in [fast, slow]:
		p.position = start + Vector2(0, 0 if p == fast else 80)
		p.velocity = Vector2.ZERO
		p.wish = Vector2.RIGHT
	await create_timer(3.0).timeout
	var run_fast: float = (fast.position.x - start.x) / Pitch.PX_PER_M
	var run_slow: float = (slow.position.x - start.x) / Pitch.PX_PER_M
	for p in [fast, slow]:
		p.wish = Vector2.ZERO
	print("pace 92 ran %.1f m, pace 45 ran %.1f m" % [run_fast, run_slow])
	ok = ok and run_fast > run_slow * 1.2

	# finishing: 20 shots each from 14 m, average distance from the aimed point at the goal line
	var shooter = m.home.players[9]
	var errors := []
	for finishing in [95, 40]:
		shooter.stats = {"finishing": finishing, "shotPower": 70}
		var total := 0.0
		for i in 20:
			total += await _shot_error(shooter)
		errors.append(total / 20.0)
	print("finishing 95: %.1f px off on average, finishing 40: %.1f px off" % errors)
	ok = ok and errors[0] < errors[1] * 0.5

	# keepers and tackling (the numbers the match uses)
	var k = m.away.keeper()
	k.stats = {"gkReflexes": 90}
	var good: float = m.keeper_reach(k)
	k.stats = {"gkReflexes": 45}
	var poor: float = m.keeper_reach(k)
	var holder = m.away.players[9]
	var tackler = m.home.players[2]
	tackler.stats = {"standingTackle": 90}
	holder.stats = {"ballControl": 50}
	var easy: float = m.steal_rate(tackler, holder)
	tackler.stats = {"standingTackle": 50}
	holder.stats = {"ballControl": 90}
	var hard: float = m.steal_rate(tackler, holder)
	print("keeper reach %.1f vs %.1f px; steal rate %.2f/s (good tackler, poor dribbler) vs %.2f/s" % [good, poor, easy, hard])
	ok = ok and good > poor * 1.25 and easy > hard * 3.0

	# composure: how much an opponent half a metre away spoils the aim
	var shooter2 = m.home.players[9]
	var marker = m.away.players[3]
	shooter2.position = Vector2(800, 300)
	marker.position = shooter2.position + Vector2(9, 0)
	shooter2.stats = {"composure": 95}
	var calm: float = shooter2.pressure_factor()
	shooter2.stats = {"composure": 40}
	var rattled: float = shooter2.pressure_factor()
	marker.position = Vector2(60, 60)
	var free: float = shooter2.pressure_factor()
	print("pressed aim error: composure 95 x%.2f, composure 40 x%.2f, unpressed x%.2f" % [calm, rattled, free])
	ok = ok and rattled > calm * 1.4 and free == 1.0

	# reactions: how long the safe part of a dodge lasts
	var dodger = m.home.players[6]
	dodger.stats = {"reactions": 95}
	dodger.dodge()
	var window_good := 0.0
	while dodger.dodging():
		await physics_frame
		window_good += 1.0 / 60.0
	await create_timer(1.2).timeout
	dodger.stats = {"reactions": 40}
	dodger.dodge()
	var window_poor := 0.0
	while dodger.dodging():
		await physics_frame
		window_poor += 1.0 / 60.0
	print("dodge window: reactions 95 %.2f s, reactions 40 %.2f s" % [window_good, window_poor])
	ok = ok and window_good > window_poor * 1.4

	# interceptions: an Anderlecht pass goes by 16 px from the feet of a Brugge defender who
	# can't move (he turns to face it: his feet are 10 px in front of him)
	var results := []
	await create_timer(1.0).timeout
	for rating in [95, 40]:
		for t in [m.home, m.away]:
			for p in t.players:
				p.speed_factor = 0.0
				p.position = Vector2(60, 60) if t == m.away else Vector2(60, 1100)
		var d = m.home.players[2]
		d.stats = {"interceptions": rating}
		d.position = Pitch.field_rect().get_center()
		d.touch_cooldown = 0.0
		m.ball.stop_at(d.position + Vector2(-200, -26))
		m.ball.last_touch = m.away.players[6]
		m.ball.kick_kind = "pass"
		m.ball.kick(Vector2(400, 0), 0.0)
		m.state = 1
		await create_timer(1.0).timeout
		results.append(m.ball.holder == d)
		m.state = 5
		m.ball.stop_at(Vector2(300, 300))
	for t in [m.home, m.away]:
		for p in t.players:
			p.speed_factor = 1.0
	print("pass 16 px from a defender's feet: cut out with interceptions 95 %s, with 40 %s" % results)
	ok = ok and results[0] and not results[1]

	# dribbling: how far ahead the ball runs and how much it slows him, 1.5 s with the ball
	var gaps := []
	m.state = 5
	for rating in [95, 40]:
		var dr = m.home.players[7]
		dr.stats = {"dribbling": rating}
		dr.position = Vector2(400, 900)
		dr.velocity = Vector2.ZERO
		m.ball.stop_at(dr.position)
		m.ball.take(dr)
		dr.wish = Vector2.RIGHT
		await create_timer(1.5).timeout
		gaps.append([m.ball.position.distance_to(dr.position), (dr.position.x - 400.0) / Pitch.PX_PER_M])
		dr.wish = Vector2.ZERO
		m.ball.stop_at(Vector2(300, 300))
	print("dribbling 95: ball %.1f px ahead, %.1f m run; dribbling 40: %.1f px, %.1f m" % [gaps[0][0], gaps[0][1], gaps[1][0], gaps[1][1]])
	ok = ok and gaps[0][0] < gaps[1][0] - 4.0 and gaps[0][1] > gaps[1][1]

	# strength: shoulder to shoulder, and the body check
	var big = m.home.players[2]
	var small = m.away.players[9]
	big.stats = {"strength": 95}
	small.stats = {"strength": 40}
	var steal_big: float = m.steal_rate(big, small)
	var odds_big: float = m.body_check_odds(big, small)
	big.stats = {"strength": 40}
	small.stats = {"strength": 95}
	var steal_small: float = m.steal_rate(big, small)
	var odds_small: float = m.body_check_odds(big, small)
	print("strong vs weak: steal rate %.2f/s vs %.2f/s; body check wins %.0f%% vs %.0f%%" % [steal_big, steal_small, odds_big * 100.0, odds_small * 100.0])
	ok = ok and steal_big > steal_small * 1.8 and odds_big > 0.75 and odds_small < 0.3

	print("RATINGS TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)


## One shot at the middle of the goal; how far from it (px) the ball crosses the goal line.
func _shot_error(p) -> float:
	var goal: Vector2 = p.team.goal_attacked()
	p.position = goal - Vector2(p.team.side * Pitch.m(14.0), 0)
	p.velocity = Vector2.ZERO
	p.facing = 2 if p.team.side > 0 else 6
	m.ball.stop_at(p.feet_front())
	m.ball.take(p)
	while p.busy():  # still finishing the last kick
		await physics_frame
	p.shoot(goal)
	while m.ball.holder == p or m.ball.velocity.length() < 100.0:
		await physics_frame
	var v: Vector2 = m.ball.velocity
	var y_at_line: float = m.ball.position.y + v.y * (goal.x - m.ball.position.x) / v.x
	await create_timer(0.3).timeout
	return absf(y_at_line - goal.y)
