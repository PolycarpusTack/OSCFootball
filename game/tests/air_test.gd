extends SceneTree
## Headers, volleys, chest control, crosses and the goal frame.
## godot --headless --path game -s res://tests/air_test.gd

var m: Node
var events := []


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	m.event.connect(func(kind, t): events.append("%s:%s" % [kind, t.short]))
	await create_timer(1.6).timeout
	var ok := true
	var f: Rect2 = Pitch.field_rect()
	var c := f.get_center()
	var bru = m.home  # attacks the right-hand goal in the first half
	var goal: Vector2 = bru.goal_attacked()

	# a cross at head height to a striker 7 m out: a header at goal
	var striker = bru.players[9]
	await _setup({striker: goal - Vector2(Pitch.m(7.0), 0.0)})
	_launch(goal + Vector2(-Pitch.m(16.0), Pitch.m(18.0)), striker.position, 38.0)
	var seen := await _wait_for(["header:BRU", "volley:BRU"], 2.0)
	print("cross at head height to the striker: %s, ball heading %s" % [seen, "at goal" if m.ball.velocity.x > 0.0 else "away"])
	ok = ok and seen == "header:BRU"

	# a lower ball to him: volleyed (or a diving header) at goal
	await _setup({striker: goal - Vector2(Pitch.m(9.0), 0.0)})
	_launch(striker.position + Vector2(-Pitch.m(4.0), Pitch.m(6.0)), striker.position, 20.0, 600.0)  # flat: never head high
	seen = await _wait_for(["volley:BRU", "header:BRU"], 2.0)
	print("a ball at knee-to-chest height: %s" % seen)
	ok = ok and seen != ""

	# an Anderlecht defender in his own box meets it: cleared away from his goal
	var defender = m.away.players[2]
	await _setup({defender: goal - Vector2(Pitch.m(10.0), 0.0)})
	_launch(goal + Vector2(-Pitch.m(25.0), Pitch.m(15.0)), defender.position, 38.0)
	seen = await _wait_for(["clearance:AND", "header:AND", "volley:AND"], 2.0)
	print("cross to a defender in his own box: %s, ball heading %s" % [seen, "upfield" if m.ball.velocity.x < 0.0 else "toward his goal"])
	ok = ok and seen == "clearance:AND" and m.ball.velocity.x < 0.0

	# a slow, low ball to a midfielder in the centre circle: chested down
	var mid = bru.players[6]
	await _setup({mid: c})
	_launch(c + Vector2(-Pitch.m(5.0), 0.0), mid.position, 20.0, 260.0)
	var waited := 0.0
	while m.ball.holder != mid and waited < 2.0:
		await physics_frame
		waited += 1.0 / 60.0
	print("a slow ball at chest height in midfield: holder %s, animation %s" % [m.ball.holder.name if m.ball.holder else "-", mid._anim])
	ok = ok and m.ball.holder == mid and mid._anim == "chest"

	# the human's striker: shoot pressed as the ball comes = a header at goal, not a slide
	m.autoplay = false
	var h = m.humans[0]
	await _setup({striker: goal - Vector2(Pitch.m(8.0), Pitch.m(2.0))})
	h.controlled.controlled = false
	h.controlled = striker
	striker.controlled = true
	h.switch_lock = 5.0
	_launch(goal + Vector2(-Pitch.m(14.0), -Pitch.m(18.0)), striker.position, 38.0)
	await create_timer(0.35).timeout
	Input.action_press("shoot")
	await physics_frame
	await physics_frame
	Input.action_release("shoot")
	seen = await _wait_for(["header:BRU", "volley:BRU"], 2.0)
	print("human presses shoot as the cross comes: %s, slid %s" % [seen, striker._anim == "slide"])
	ok = ok and seen == "header:BRU"
	m.autoplay = true
	striker.controlled = false
	h.controlled = null  # back to the AI

	# the frame: low and just outside the post, then over the top of the bar; no goals
	var score: int = bru.score
	await _setup({})
	m.away.keeper().position = c
	var post_y: float = c.y + m.GOAL_HALF_WIDTH + 1.5
	m.ball.stop_at(Vector2(goal.x - 40.0, post_y))
	m.ball.last_touch = striker
	m.ball.kick(Vector2(600.0, 0.0), 0.0)
	seen = await _wait_for(["woodwork:BRU"], 1.0)
	print("ball at the outside of the post: %s, ball back in play %s" % [seen, f.has_point(m.ball.position)])
	ok = ok and seen != "" and bru.score == score
	await _setup({})
	m.away.keeper().position = c
	m.ball.stop_at(Vector2(goal.x - 20.0, c.y))
	m.ball.z = m.CROSSBAR + 1.0
	m.ball.last_touch = striker
	m.ball.kick(Vector2(600.0, 0.0), 30.0)
	seen = await _wait_for(["woodwork:BRU"], 1.0)
	await create_timer(0.5).timeout
	print("ball at the top of the crossbar: %s, goals %d" % [seen, bru.score - score])
	ok = ok and seen != "" and bru.score == score

	# an AI winger out wide in the last 30 m with the strikers about: crosses, and they attack the box
	var winger = bru.players[8] if bru.players[8].home.y > 0.5 else bru.players[5]
	await _setup({winger: goal + Vector2(-Pitch.m(18.0), Pitch.m(25.0)),
		striker: goal - Vector2(Pitch.m(14.0), 0.0), bru.players[10]: goal - Vector2(Pitch.m(16.0), Pitch.m(5.0))})
	m.ball.stop_at(winger.feet_front())
	m.ball.take(winger)
	var runs := {}
	var crossed := false
	waited = 0.0
	while waited < 3.0 and not crossed:
		await physics_frame
		waited += 1.0 / 60.0
		runs[striker.ai_state] = true
		crossed = m.ball.kick_kind == "cross"
	print("winger out wide: crossed %s; striker states %s" % [crossed, runs.keys()])
	ok = ok and crossed and runs.has("box run")

	print("AIR TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)


## Wait for open play, put everyone else well away (the keeper stays), place `at` players.
func _setup(at: Dictionary) -> void:
	while m.state != 1:
		await physics_frame
	var c: Vector2 = Pitch.field_rect().get_center()
	for t in [m.home, m.away]:
		for p in t.players:
			if p.role != "G":
				p.position = c + Vector2(-Pitch.m(40.0) * t.side, Pitch.m(25.0))  # far from both boxes
				p.velocity = Vector2.ZERO
	for p in at:
		p.position = at[p]
		p.velocity = Vector2.ZERO
		p.touch_cooldown = 0.0
		p._action_left = 0.0  # done celebrating
	events.clear()
	await physics_frame


## Kick the ball from `from` so it arrives over `to` at `height` (pitch pixels).
func _launch(from: Vector2, to: Vector2, height: float, speed := 450.0) -> void:
	m.ball.stop_at(from)
	m.ball.last_touch = null
	var t := from.distance_to(to) / speed
	m.ball.kick((to - from).normalized() * speed, (height + m.ball.GRAVITY * t * t / 2.0) / t)


## The first of `kinds` that happens within `seconds`, or "".
func _wait_for(kinds: Array, seconds: float) -> String:
	var waited := 0.0
	while waited < seconds:
		for e in events:
			if e in kinds:
				return e
		await physics_frame
		waited += 1.0 / 60.0
	return ""
