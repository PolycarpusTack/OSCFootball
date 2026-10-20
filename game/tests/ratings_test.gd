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

	# skill moves: a nutmeg is dribbling against the defender's defensiveAwareness
	var trick = m.home.players[2]
	var dfd = m.away.players[9]
	trick.stats = {"dribbling": 95}
	dfd.stats = {"defensiveAwareness": 40}
	var nut_good: float = m.nutmeg_odds(trick, dfd)
	trick.stats = {"dribbling": 40}
	dfd.stats = {"defensiveAwareness": 95}
	var nut_poor: float = m.nutmeg_odds(trick, dfd)
	print("nutmeg gets through: dribbler 95 vs defender 40 %.0f%%, 40 vs 95 %.0f%%" % [nut_good * 100.0, nut_poor * 100.0])
	ok = ok and nut_good > 0.8 and nut_poor < 0.25

	# stamina: 30 s of running about tires the poor one faster; spent, he's slower
	var fit = m.home.players[4]
	var unfit = m.home.players[5]
	fit.stats = {"stamina": 95}
	unfit.stats = {"stamina": 40}
	for p in [fit, unfit]:
		p.position = Vector2(700, 300 if p == fit else 600)
		p.fatigue = 0.0
	var ran := 0.0
	while ran < 30.0:
		for p in [fit, unfit]:
			p.wish = Vector2.RIGHT.rotated(ran * 0.6)  # big circles: always running
		await physics_frame
		ran += 1.0 / 60.0
	var tired_fit: float = fit.fatigue
	var tired_unfit: float = unfit.fatigue
	fit.stats = {}
	unfit.stats = {}
	fit.fatigue = 0.0
	unfit.fatigue = 1.0
	var from := {}
	for p in [fit, unfit]:
		p.velocity = Vector2.ZERO
		p.wish = Vector2.RIGHT
		from[p] = p.position.x
	await create_timer(3.0).timeout
	var fresh_run: float = (fit.position.x - from[fit]) / Pitch.PX_PER_M
	var spent_run: float = (unfit.position.x - from[unfit]) / Pitch.PX_PER_M
	for p in [fit, unfit]:
		p.wish = Vector2.ZERO
	print("stamina 95 vs 40 after 30 s running: fatigue %.2f vs %.2f; 3 s run fresh %.1f m, spent %.1f m" % [tired_fit, tired_unfit, fresh_run, spent_run])
	ok = ok and tired_unfit > tired_fit * 2.0 and tired_unfit > 0.15 and spent_run < fresh_run - 1.0

	# Chaos: knocked down when tired, he gets up dizzy (not when fresh, not in Classic)
	var dizzies := []
	m.event.connect(func(kind, t): if kind == "dizzy": dizzies.append(t.short))
	var floored = m.home.players[6]
	floored.fatigue = 0.0
	m.knock_down(floored, "fall")
	var fresh_dizzy: bool = floored.dizzy_left > 0.0
	floored.fatigue = 0.7
	m.knock_down(floored, "fall")
	var tired_dizzy: bool = floored.dizzy_left > 0.0
	floored.dizzy_left = 0.0
	m.chaos = false
	m.knock_down(floored, "fall")
	var classic_dizzy: bool = floored.dizzy_left > 0.0
	m.chaos = true
	print("knocked down: fresh dizzy %s, tired dizzy %s, tired in Classic dizzy %s, events %s" % [fresh_dizzy, tired_dizzy, classic_dizzy, dizzies])
	ok = ok and not fresh_dizzy and tired_dizzy and not classic_dizzy and dizzies == ["BRU"]

	# vision: a mate 520 px away in the clear is only seen by the far-sighted passer, and
	# a runner gets the ball further ahead of him
	m.state = 5
	var seer = m.home.players[6]
	var far = m.home.players[9]
	for t in [m.home, m.away]:
		for p in t.players:
			p.velocity = Vector2.ZERO
			p.wish = Vector2.ZERO
			p.position = Vector2(500, 300) if t == m.home else Vector2(60, 1100)  # mates too close to count
	seer.position = Vector2(500, 300)
	far.position = seer.position + Vector2(m.home.side * 520.0, 0)
	var ai = load("res://scripts/ai.gd")
	seer.stats = {"vision": 95}
	var seen_far: bool = ai.best_pass(seer, m, Vector2.ZERO) == far
	seer.stats = {"vision": 40}
	var seen_poor: bool = ai.best_pass(seer, m, Vector2.ZERO) == far
	var leads := []
	for rating in [95, 40]:
		seer.stats = {"vision": rating, "shortPassing": 99}
		far.position = seer.position + Vector2(m.home.side * 250.0, 0)
		far.speed_factor = 0.0  # stands still after: only his run at the moment of the pass counts
		m.ball.stop_at(seer.feet_front())
		m.ball.take(seer)
		while seer.busy():
			await physics_frame
		far.velocity = Vector2(0, 200)  # running across, down the pitch
		var was: Vector2 = far.position
		seer.pass_to(far)
		while m.ball.holder == seer or m.ball.velocity.length() < 100.0:
			await physics_frame
		var v: Vector2 = m.ball.velocity
		leads.append(m.ball.position.y + v.y * (was.x - m.ball.position.x) / v.x - was.y)
		await create_timer(0.3).timeout
		m.ball.stop_at(Vector2(300, 300))
	far.speed_factor = 1.0
	print("vision: mate 520 px away seen with 95 %s, with 40 %s; runner led by %.0f px (95) vs %.0f px (40)" % [seen_far, seen_poor, leads[0], leads[1]])
	ok = ok and seen_far and not seen_poor and leads[0] > leads[1] + 60.0

	# curve: 25 m shots bend in, still on target, but a keeper reading the line off the
	# ball 0.55 s out (when he'd dive) reads it wrong
	var curler = m.home.players[9]
	var curls := []
	for rating in [95, 40]:
		curler.stats = {"curve": rating, "longShots": 99, "shotPower": 70}
		var aim_off := 0.0
		var read_off := 0.0
		for i in 8:
			var r: Array = await _curled_shot(curler)
			aim_off += r[0] / 8.0
			read_off += r[1] / 8.0
		curls.append([aim_off, read_off])
	print("curve 95: %.1f px off target, keeper's read %.1f px out; curve 40: %.1f px, %.1f px" % [curls[0][0], curls[0][1], curls[1][0], curls[1][1]])
	ok = ok and curls[0][0] < 12.0 and curls[1][0] < 12.0 and curls[0][1] > 25.0 and curls[1][1] < 1.0

	print("RATINGS TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)


## A 25 m shot at the middle of the goal (nobody in the way): [how far from it the ball
## crosses the goal line, how far from that its straight line 0.55 s out pointed].
func _curled_shot(p) -> Array:
	var goal: Vector2 = p.team.goal_attacked()
	p.position = goal - Vector2(p.team.side * Pitch.m(25.0), 0)
	p.velocity = Vector2.ZERO
	p.facing = 2 if p.team.side > 0 else 6
	m.ball.stop_at(p.feet_front())
	m.ball.take(p)
	while p.busy():
		await physics_frame
	p.shoot(goal, 0.8)
	while m.ball.holder == p or m.ball.velocity.length() < 100.0:
		await physics_frame
	var read := INF
	var frames := 0
	while signf(goal.x - m.ball.position.x) == p.team.side and frames < 300:
		frames += 1
		var v: Vector2 = m.ball.velocity
		var t: float = (goal.x - m.ball.position.x) / v.x
		if read == INF and t <= 0.55:
			read = m.ball.position.y + v.y * t
		await physics_frame
	var crossed: float = m.ball.position.y
	await create_timer(0.3).timeout
	return [absf(crossed - goal.y), absf(read - crossed)]


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
