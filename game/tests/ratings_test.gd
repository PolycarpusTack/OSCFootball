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
