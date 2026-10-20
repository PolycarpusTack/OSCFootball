extends SceneTree
## EA ratings change how players move and decide: who goes for the ball, the first touch,
## markers and defenders off the ball, dribbling round a man. Elite against poor.
## godot --headless --path game -s res://tests/movement_test.gd

var m: Node


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	await create_timer(0.5).timeout
	m.state = 5  # HALF_TIME with a long pause: nobody's AI moves them, no rules apply
	m._state_left = 1e9
	var ai = load("res://scripts/ai.gd")
	var ok := true
	for t in [m.home, m.away]:
		for p in t.players:
			p.velocity = Vector2.ZERO
			p.wish = Vector2.ZERO
			p.fatigue = 0.0
			p.position = Vector2(100, 100) if t == m.home else Vector2(60, 1100)  # out of it

	# the chaser: the quick man 200 px away beats the slow one 170 px away; swap them, he doesn't
	var quick = m.home.players[2]
	var slow = m.home.players[3]
	m.ball.stop_at(Vector2(900, 600))
	quick.position = m.ball.position + Vector2(200, 0)
	slow.position = m.ball.position - Vector2(170, 0)
	quick.stats = {"sprintSpeed": 95, "acceleration": 95, "reactions": 95}
	slow.stats = {"sprintSpeed": 40, "acceleration": 40, "reactions": 40}
	var quick_goes: bool = m.chaser(m.home) == quick
	quick.stats = {"sprintSpeed": 40, "acceleration": 40, "reactions": 40}
	slow.stats = {"sprintSpeed": 95, "acceleration": 95, "reactions": 95}
	var slow_goes: bool = m.chaser(m.home) == slow
	quick.stats = {}
	slow.stats = {}
	var nearest_goes: bool = m.chaser(m.home) == slow
	print("chaser: quick man further away %s; the near one when he's quick %s; equals, the nearer %s" % [quick_goes, slow_goes, nearest_goes])
	ok = ok and quick_goes and slow_goes and nearest_goes

	# first touch: a 480 px/s pass, 40 times each
	var receiver = m.home.players[6]
	receiver.position = Vector2(700, 300)
	var heavy := []
	for control in [40, 95]:
		receiver.stats = {"ballControl": control}
		var count := 0
		for i in 40:
			receiver.touch_cooldown = 0.0
			m.ball.stop_at(receiver.feet_front())
			m.ball.velocity = Vector2(480, 0)
			m.ball.last_touch = m.home.players[7]
			m.ball.kick_kind = "pass"
			m._take(receiver)
			if m.ball.holder != receiver:
				count += 1
		heavy.append(count)
	m.ball.stop_at(Vector2(900, 600))
	var slow_pass: float = m.heavy_touch_odds(receiver, 200.0)
	print("heavy first touch on a 480 px/s pass, of 40: ballControl 40 %d, 95 %d; a 200 px/s pass %.0f%%" % [heavy[0], heavy[1], slow_pass * 100.0])
	ok = ok and heavy[0] >= 6 and heavy[0] <= 26 and heavy[1] == 0 and slow_pass == 0.0

	# marking: tighter and reading the run
	var marker = m.away.players[3]
	var man = m.home.players[9]
	man.position = Vector2(900, 400)
	man.velocity = Vector2(0, 150)  # running across
	marker.marking = man
	var marks := []
	for rating in [95, 40]:
		marker.stats = {"defensiveAwareness": rating}
		var spot: Vector2 = ai.mark_spot(marker)
		marks.append([spot.distance_to(man.position), spot.y - man.position.y])
	man.velocity = Vector2.ZERO
	marker.marking = null
	print("marking a man running across: awareness 95 %.0f px off him, %+.0f px along his run; 40 %.0f px, %+.0f px" % [marks[0][0], marks[0][1], marks[1][0], marks[1][1]])
	ok = ok and marks[0][0] < marks[1][0] and marks[0][1] > 20.0 and marks[1][1] < -20.0

	# off the ball: a defender steps toward the lane between the man on the ball and the
	# attacker nearest his spot
	var defender = m.away.players[4]
	var holder = m.home.players[7]
	var lanes := []
	for rating in [95, 40]:
		defender.stats = {"interceptions": rating}
		holder.position = Vector2(950, 450)
		m.ball.stop_at(holder.position)
		m.ball.take(holder)
		var spot: Vector2 = ai.hold_spot(defender, m, false)  # it follows the ball
		man.position = spot + (holder.position - spot).normalized().rotated(1.2) * 100.0
		var stepped: Vector2 = ai.defend_spot(defender, m)
		lanes.append(stepped.distance_to(spot))
		m.ball.stop_at(Vector2(900, 600))
	print("defender off the ball steps toward the passing lane: interceptions 95 %.0f px, 40 %.0f px" % lanes)
	ok = ok and lanes[0] > 40.0 and lanes[1] < 1.0

	# dribbling: a man 50 px ahead, a little to one side: the good dribbler goes round wider
	var dribbler = m.home.players[8]
	var blocker = m.away.players[5]
	dribbler.position = Vector2(600, 800)
	var ahead := Vector2(m.home.side, 0)
	blocker.position = dribbler.position + ahead * 50.0 + Vector2(0, 8)
	var swerves := []
	for rating in [95, 40]:
		dribbler.stats = {"dribbling": rating}
		var dir: Vector2 = ai.swerve(dribbler, m, ahead)
		swerves.append([rad_to_deg(ahead.angle_to(dir)), dir.y])
	blocker.position = Vector2(60, 1100)
	var clear: Vector2 = ai.swerve(dribbler, m, ahead)
	print("dribbling at a man just off line: 95 turns %.0f deg, 40 %.0f deg (away from him: %s); nobody there %s" % [swerves[0][0], swerves[1][0], swerves[0][1] < 0.0, clear == ahead])
	ok = ok and absf(swerves[0][0]) > absf(swerves[1][0]) * 2.0 and swerves[0][1] < 0.0 and swerves[1][1] < 0.0 and clear == ahead

	print("MOVEMENT TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)
