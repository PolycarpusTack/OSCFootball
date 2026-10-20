extends SceneTree
## Deterministic scenarios: real Match/Footballer/Ball nodes, manually stepped special windows.
var m: Node
var actions: Node
var failed := 0

func check(value: bool, message: String) -> void:
	if not value:
		failed += 1
		push_error(message)

func reset() -> void:
	actions.clear()
	m.state = 1
	m._offside.clear()
	for t in [m.home, m.away]:
		t.energy = 100.0
		for i in t.players.size():
			var p = t.players[i]
			p.position = Vector2(800 + i * 40, 700 if t == m.home else 900)
			p._action_left = 0.0
			p.chaos_lock = false
			p.dizzy_left = 0.0
			p.touch_cooldown = 0.0
			p.sent_off = false
			p.velocity = Vector2.ZERO
	m.ball.stop_at(Vector2(500, 500))
	m.ball.prev_position = m.ball.position
	m.ball.prev_z = 0.0
	m.ball.last_touch = null
	m.home.players[6].position = Vector2(500, 500)

func contact(id: String) -> void:
	actions.tick(float(actions.MOVES[id].wind) + 0.01)

func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	m.get_script().chaos = true
	m.get_script().players = 2
	root.add_child(m)
	await process_frame
	m.set_physics_process(false)
	for t in [m.home, m.away]:
		for p in t.players: p.set_physics_process(false)
	m.ball.set_physics_process(false)
	actions = m.chaos_actions
	actions.ai_enabled = false
	var p = m.home.players[6]
	var o = m.away.players[6]
	var b = m.ball

	reset()
	m.get_script().chaos = false
	b.take(p)
	check(not actions.start(p, "ghost", Vector2.RIGHT), "Classic must reject specials")
	check(m.home.energy == 100, "Classic must not spend energy")
	m.get_script().chaos = true
	m.home.energy = 0
	check(not actions.start(p, "ghost", Vector2.RIGHT), "Insufficient energy")

	reset()
	b.take(p)
	check(actions.start(p, "ghost", Vector2.RIGHT), "Ghost activation")
	check(m.home.energy == 80, "Ghost energy charged once")
	check(not actions.start(p, "ghost", Vector2.RIGHT), "Cannot stack activations")
	contact("ghost")
	check(b.holder == null and b.velocity.x > 200 and p.position.x > 500, "Ghost exposes ball and moves player")
	actions.tick(1.0)
	check(not p.chaos_lock, "Recovery releases movement")

	reset()
	b.position = p.position + Vector2(22, 0)
	b.velocity = Vector2(300, 0)
	check(not actions.start(p, "magnet", Vector2.RIGHT), "Magnet cannot pull fast shots")
	b.velocity = Vector2.ZERO
	check(actions.start(p, "magnet", Vector2.RIGHT), "Magnet activation")
	contact("magnet")
	check(b.velocity.x < 0, "Magnet attracts low loose ball")
	b.position = p.feet_front()
	actions.tick(0.01)
	check(b.holder == p, "Magnet collects nearby ball")

	reset()
	b.take(p)
	actions.start(p, "pinball", Vector2.RIGHT)
	contact("pinball")
	check(not actions.flight.is_empty() and b.velocity.x > 500, "Pinball launched")
	o.position = Vector2(550, 500)
	b.prev_position = Vector2(530, 500)
	b.position = Vector2(555, 500)
	actions.update_flight(0.01)
	check(actions.flight.is_empty() and b.velocity.x < 0 and b.last_touch == o, "Pinball rebounds once, credits defender touch")
	check(not o.chaos_lock, "Pinball does not stun")

	reset()
	o.position = p.position + Vector2(22, 0)
	b.take(o)
	actions.start(p, "stego", Vector2.RIGHT)
	contact("stego")
	check(b.holder == null and o.chaos_lock, "Sweep knocks ball loose and briefly stuns carrier")
	check(not actions.stun(o, 0.4), "Stun immunity prevents chaining")
	actions.tick(0.5)
	check(not o.chaos_lock, "Stun expires")

	reset()
	o.position = p.position + Vector2(22, 0)
	b.take(o)
	actions.start(p, "stego", Vector2.RIGHT)
	o.position += Vector2(100, 0)
	b.position = o.position
	contact("stego")
	check(b.holder == o and not o.chaos_lock, "Sweep misses carrier who escapes wind-up")

	reset()
	for i in 3:
		m.away.players[i + 4].position = p.position + Vector2(10, (i - 1) * 10)
	actions.start(p, "bass", Vector2.RIGHT)
	contact("bass")
	check(actions.stuns.size() == 2, "Bass affects at most two ball-contesting opponents")

	reset()
	o.position = p.position + Vector2(22, 0)
	b.take(o)
	actions.start(p, "bass", Vector2.RIGHT)
	actions.start(o, "ghost", Vector2.LEFT)
	contact("bass")
	check(o.chaos_lock and actions.stuns.has(o), "Cancelling another active move preserves its new stun lock")

	reset()
	var q = m.home.players[7]
	q.position = p.position + Vector2(0, 32)
	check(actions.start(p, "wall", Vector2.RIGHT), "Wall recruits nearby teammate")
	b.position = p.position + Vector2(0, 16)
	b.prev_position = b.position + Vector2(20, 0)
	b.velocity = Vector2(-450, 0)
	b.z = 40
	contact("wall")
	check(b.velocity.x < 0, "Lofted ball clears wall")
	b.z = 0
	actions.tick(0.01)
	check(b.velocity.x > 0 and q.chaos_lock, "Low ball rebounds off short wall")
	actions.clear()
	check(not p.chaos_lock and not q.chaos_lock, "Wall cleanup unlocks both players")

	for id in ["spring", "cyclone"]:
		reset()
		b.z = 64
		b.position = p.position
		b.prev_position = b.position
		check(actions.start(p, id, Vector2.RIGHT), id + " activation")
		contact(id)
		check(b.last_touch == p and b.velocity.x > 500, id + " aerial strike")
		if id == "cyclone":
			check(p.chaos_rotation == PI and p.chaos_lift > 0, "Cyclone has inverted airborne pose")
		actions.tick(1.0)
		check(p.chaos_rotation == 0 and p.chaos_lift == 0, id + " restores visual pose")

	reset()
	b.take(p)
	actions.start(p, "boomerang", Vector2(0.7, 0.7))
	contact("boomerang")
	b.position += Vector2(200, 200)
	actions.update_flight(0.7)
	check(b.velocity.y < 0, "Boomerang curves back toward original wing")
	b.take(o)
	actions.update_flight(0.01)
	check(actions.flight.is_empty(), "Any catch cancels cross curve")

	reset()
	var k = m.home.keeper()
	k.position = m.home.goal_defended() + Vector2(35, 0)
	b.take(k)
	check(actions.start(k, "rocket", Vector2.RIGHT), "Rocket keeper activation")
	contact("rocket")
	check(b.holder == null and b.velocity.x == 720 and b.z == 36, "Rocket releases long aerial throw")

	reset()
	k.position = m.home.goal_defended() + Vector2(35, 0)
	b.position = k.position + Vector2(20, 0)
	b.prev_position = b.position + Vector2(15, 0)
	b.velocity = Vector2(-600, 0)
	b.z = 30
	check(actions.start(k, "palm", Vector2.RIGHT), "Palm activation")
	contact("palm")
	check(b.velocity.x > 0 and b.last_touch == k and b.holder == null, "Palm parries instead of catches")
	b.velocity = Vector2(-600, 0)
	b.power = "thunder"
	actions.tick(0.01)
	check(b.power == "thunder" and b.velocity.x < 0, "Thunder beats barrage")

	reset()
	b.take(p)
	actions.start(p, "pinball", Vector2.RIGHT)
	b.take(o)
	contact("pinball")
	check(b.holder == o and actions.flight.is_empty(), "Dispossessed wind-up cannot fire")
	m.state = 2
	actions.tick(0.01)
	check(actions.active.is_empty() and not p.chaos_lock, "Whistle cancels all active moves")

	reset()
	b.take(p)
	actions.start(p, "ghost", Vector2.RIGHT)
	p.perform("fall")
	contact("ghost")
	check(b.holder == p and actions.active.is_empty(), "Interrupted animation cancels action")

	check(InputMap.has_action("special") and InputMap.has_action("p2_cycle_special"), "Both players have special controls")
	m.humans[0].controlled = p
	check(actions.actor(m.humans[0], "palm") == k, "Outfield control routes keeper action to keeper")

	# Exercise input routing rather than calling start(): both keyboards and role routing.
	reset()
	var h = m.humans[0]
	h.controlled = p
	h.special_index = actions.MOVES.keys().find("ghost")
	b.take(p)
	Input.action_press("special")
	m._human_input(h, p)
	Input.action_release("special")
	check(actions.active.size() == 1 and m.home.energy == 80, "P1 E starts selected move")
	await process_frame
	reset()
	h = m.humans[1]
	h.controlled = o
	h.special_index = actions.MOVES.keys().find("pinball")
	b.take(o)
	Input.action_press("p2_special")
	m._human_input(h, o)
	Input.action_release("p2_special")
	check(actions.active.size() == 1 and m.away.energy == 60, "P2 comma starts own selected move")
	await process_frame
	reset()
	m.humans[0].special_index = actions.MOVES.keys().find("rocket")
	b.take(k)
	Input.action_press("special")
	m._human_input(m.humans[0], p)
	Input.action_release("special")
	check(actions.active.size() == 1 and actions.active[0].p == k, "Keeper action routes through field player's input")
	contact("rocket")
	check(b.last_touch == k and b.holder == null, "Routed throw releases keeper's ball")

	# a keeper with the ball in his hands in his own box can't be challenged, by specials either
	reset()
	k.position = m.home.goal_defended() + Vector2(m.home.side * Pitch.m(5.0), 0.0)
	o.position = k.position + Vector2(m.home.side * 20.0, 0.0)
	b.take(k)
	check(actions.unavailable(o, "stego") != "" and actions.unavailable(o, "bass") != "", "No sweep or bass drop on a keeper holding the ball")
	k.position = Pitch.field_rect().get_center()
	o.position = k.position + Vector2(m.home.side * 20.0, 0.0)
	b.stop_at(k.feet_front())  # the ball goes with him (physics is off here)
	b.take(k)
	check(actions.unavailable(o, "stego") == "", "Outside his box he's fair game")

	# AI uses the same validation and cannot spend a human side's energy.
	reset()
	b.take(k)
	m.autoplay = false
	actions.think_ai()
	check(actions.active.is_empty(), "AI does not activate specials for either human team")
	m.autoplay = true
	m.away.energy = 0.0
	actions.think_ai()
	check(actions.active.size() == 1 and actions.active[0].id == "rocket", "AI selects a valid keeper throw")
	var thrown_at: Vector2 = actions.active[0].aim if actions.active.size() == 1 else Vector2.ZERO
	var to_mate: bool = m.home.players.slice(1).any(func(q): return thrown_at.dot((q.position - k.position).normalized()) > 0.999)
	check(to_mate, "AI keeper throw is aimed at a teammate")
	m.get_script().chaos = false
	actions.tick(0.01)
	check(actions.active.is_empty() and not k.chaos_lock, "Disabling Chaos clears live actions")
	m.get_script().chaos = true
	reset()
	m.away.energy = 0.0
	b.take(k)
	for far in m.home.players.slice(1):  # nobody in passing range: no throw into space
		far.position = k.position + Vector2(0.0, 2000.0)
	actions.think_ai()
	check(actions.active.is_empty(), "AI keeper doesn't throw it when no teammate is free")
	reset()
	m.away.energy = 0.0
	b.take(k)
	var mate = m.home.players[9]
	for far in m.home.players.slice(1):  # one teammate in range, with an opponent in his lane
		far.position = k.position + Vector2(0.0, 2000.0)
	mate.position = k.position + Vector2(450.0, 0.0)
	o.position = k.position + Vector2(225.0, 0.0)  # past the 9.15 m the keeper waits for
	actions.think_ai()
	check(actions.active.is_empty(), "AI keeper doesn't throw it through an opponent")
	print("CHAOS ACTIONS TEST ", "PASSED" if failed == 0 else "FAILED (%d)" % failed)
	m.queue_free()
	await create_timer(0.1).timeout
	quit(0 if failed == 0 else 1)
