extends SceneTree
## The match engine's decisions (scripts/ai.gd): a striker with good long shots shoots from
## range where a poor one won't, and nobody shoots from his own half; better decisions take the
## best option more surely; the nearest teammate (not the passer) goes to meet a pass; a pass
## played under pressure sometimes gets past the man on top of the passer, never past one
## further off; the presser comes from the line whose zone the ball is in; a defender steps up
## goal-side of the man on the ball in our half.
## godot --headless --path game -s res://tests/engine_test.gd

const AI_SCRIPT := "res://scripts/ai.gd"
const AWAY := Vector2(-5000, -5000)  # parked, out of everything

var m: Node
var ai


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await create_timer(1.6).timeout
	m.state = 5  # HALF_TIME with a long pause: freeze the play
	m._state_left = 1e9
	ai = load(AI_SCRIPT)
	seed(7)
	var ok := true
	var striker = _first(m.home, "F")
	var goal: Vector2 = m.home.goal_attacked()
	var centre: Vector2 = Pitch.field_rect().get_center()
	var out: Vector2 = (centre - goal).normalized()

	# range: 24 m out, open goal ahead
	_park()
	striker.position = goal + out * Pitch.m(24.0)
	m.ball.take(striker)
	striker.stats = {"longShots": 95}
	var far_good := _has(ai.options(striker, m), "shoot")
	striker.stats = {"longShots": 40}
	var far_poor := _has(ai.options(striker, m), "shoot")
	print("24 m out: shoots with long shots 95 %s, with 40 %s" % [far_good, far_poor])
	ok = ok and far_good and not far_poor

	# nobody shoots from his own half
	striker.stats = {"longShots": 99}
	striker.position = centre + (m.home.goal_defended() - centre) * 0.1
	m.ball.take(striker)
	var own_half := _has(ai.options(striker, m), "shoot")
	print("own half, long shots 99: shoots %s" % own_half)
	ok = ok and not own_half

	# decisions: 18 m out, dribbling the best option by a little; how often each takes it
	striker.position = goal + out * Pitch.m(18.0)
	m.ball.take(striker)
	var sure := []
	for level in [95, 40]:
		striker.stats = {"vision": level, "composure": level, "reactions": level}
		var opts: Array = ai.options(striker, m)
		opts.sort_custom(func(a, b): return a[1] > b[1])
		var hits := 0
		for i in 400:
			if ai.choose(striker, m)[0] == opts[0][0]:
				hits += 1
		sure.append(hits / 400.0)
		print("decisions %d: best option %s (%.0f, next %s %.0f) taken %.0f%%" % [
			level, opts[0][0], opts[0][1], opts[1][0], opts[1][1], 100.0 * hits / 400.0])
	ok = ok and sure[0] >= 0.95 and sure[1] < sure[0] - 0.05

	# a pass on its way: the nearest teammate goes to meet it, not the passer; the other side defends
	_park()
	var passer = _first(m.home, "M")
	var mate = _first(m.home, "F")
	passer.position = centre
	m.ball.take(passer)
	m.ball.release()
	m.ball.kick_kind = "pass"
	m.ball.position = centre + Vector2(Pitch.m(3.0), 0)
	m.ball.velocity = Vector2.ZERO
	mate.position = centre + Vector2(Pitch.m(8.0), 0)
	_clear_caches()
	ai.think(mate, m, 0.016)
	var ours: bool = ai.in_possession(m.home, m) and not ai.in_possession(m.away, m)
	print("pass in flight: receiver %s (%s), home on the ball %s" % [
		ai.receiver(m.home, m).display_name, mate.ai_state, ours])
	ok = ok and ai.receiver(m.home, m) == mate and mate.ai_state == "receive" and ours

	# past the press: right on top of the passer only sometimes blocks it, 5 m off never
	_park()
	passer.position = centre
	var close = _first(m.away, "D")
	var off = _first(m.away, "M")
	close.position = centre + Vector2(Pitch.m(1.0), 0)
	off.position = centre + Vector2(Pitch.m(5.0), 0)
	var blocked_out := 0
	var off_touched := false
	for i in 400:
		close.touch_cooldown = 0.0
		off.touch_cooldown = 0.0
		passer._past_the_press()
		if close.touch_cooldown > 0.0:
			blocked_out += 1
		off_touched = off_touched or off.touch_cooldown > 0.0
	var rate := blocked_out / 400.0
	print("past the press: the man on top beaten %.0f%%, the man 5 m off %s" % [100.0 * rate, off_touched])
	ok = ok and rate > 0.4 and rate < 0.95 and not off_touched

	# the presser by zone: ball deep in their half, a defender a bit nearer than a forward: the forward goes
	_park()
	var holder = _first(m.away, "M")
	var their_goal: Vector2 = m.home.goal_attacked()
	holder.position = their_goal + out * Pitch.m(15.0)
	m.ball.take(holder)
	m.ball.position = holder.position
	var d = _first(m.home, "D")
	var f = _first(m.home, "F")
	d.position = holder.position + out * Pitch.m(10.0)
	f.position = holder.position + out * Pitch.m(14.0)
	_clear_caches()
	var deep_presser = ai.presser(m.home, m)
	print("ball deep in their half: %s presses (defender 10 m, forward 14 m)" % deep_presser.role)
	ok = ok and deep_presser == f

	# the cover: their man on the ball in our half; the nearest of us presses, the next defender
	# steps up goal-side of him
	_park()
	var own: Vector2 = m.home.goal_defended()
	var in_out: Vector2 = (centre - own).normalized()
	holder.position = own + in_out * Pitch.m(30.0)
	m.ball.take(holder)
	m.ball.position = holder.position
	var backs: Array = m.home.players.filter(func(p): return p.role == "D")
	backs[0].position = holder.position + Vector2(0, Pitch.m(3.0))
	backs[1].position = holder.position - in_out * Pitch.m(12.0)
	_clear_caches()
	var first = ai.presser(m.home, m)
	var second = ai.cover(m.home, m)
	ai.think(backs[1], m, 0.016)
	print("their man in our half: %s presses, %s covers (%s)" % [
		first.display_name, second.display_name if second else "nobody", backs[1].ai_state])
	ok = ok and first == backs[0] and second == backs[1] and backs[1].ai_state == "cover"
	holder.position = centre + (their_goal - centre) * 0.3  # in their half: no cover
	m.ball.position = holder.position
	_clear_caches()
	var no_cover = ai.cover(m.home, m) == null
	print("their man in his own half: no cover %s" % no_cover)
	ok = ok and no_cover

	print("ENGINE TEST PASSED" if ok else "ENGINE TEST FAILED")
	quit(0 if ok else 1)


## Everyone out of the way, average and fresh, the caches forgotten.
func _park() -> void:
	for t in [m.home, m.away]:
		for p in t.players:
			p.position = AWAY
			p.stats = {}
			p.fatigue = 0.0
	_clear_caches()


func _clear_caches() -> void:
	ai._pressers.clear()
	ai._receivers.clear()


func _first(t, role: String):
	for p in t.players:
		if p.role == role:
			return p
	return null


func _has(opts: Array, what: String) -> bool:
	return opts.any(func(o): return o[0] == what)
