extends SceneTree
## Indoor, five a side: the arena is smaller with the boards on the lines; the ball comes back
## off them (no throw-in, corner or goal kick) but goes into a goal; there's no offside; the
## players can't leave the arena; the CPU manager keeps its indoor shape; the substitutions
## screen lists five.
## godot --headless --path game -s res://tests/indoor_test.gd

var m: Node
var events := []


func _initialize() -> void:
	Pitch.indoor = true
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	m.event.connect(func(kind, t): events.append("%s:%s" % [kind, t.short]))
	await create_timer(1.6).timeout
	m.chaos_actions.ai_enabled = false
	var f: Rect2 = Pitch.field_rect()
	var c: Vector2 = f.get_center()
	var ok := true

	# five a side, a smaller arena
	var size := Vector2(f.size.x, f.size.y) / Pitch.PX_PER_M
	print("indoor: %d and %d players (%s), arena %.0f x %.0f m" % [m.home.players.size(), m.away.players.size(),
		m.home.formation, size.x, size.y])
	ok = ok and m.home.players.size() == 5 and m.away.players.size() == 5 and m.home.formation == "1-2-1" \
		and size == Pitch.INDOOR_M and m.home.taker() != null and m.home.taker().role != "G"

	# off the side boards: still in play, coming back
	await _play()
	_clear_ball_area(c)
	events.clear()
	_kick(c + Vector2(0, -Pitch.m(4.0)), Vector2(0, -500))
	await create_timer(1.0).timeout
	var back_in: bool = m.state == 1 and m.ball.position.y > 0.0 and not events.any(func(e): return e.begins_with("throw-in"))
	print("off the side boards: state %d, ball %.0f m in, events %s" % [m.state, m.ball.position.y / Pitch.PX_PER_M, events])
	ok = ok and back_in

	# over the goal line wide of the goal: off the end boards, no corner or goal kick
	await _play()
	_clear_ball_area(c)
	events.clear()
	var wide := Vector2(f.size.x - Pitch.m(3.0), c.y + Pitch.m(8.0))
	_kick(wide, Vector2(600, 0))
	await create_timer(1.0).timeout
	var no_restart: bool = m.state == 1 and m.ball.position.x <= f.size.x \
		and not events.any(func(e): return e.begins_with("corner") or e.begins_with("goal kick"))
	print("wide of the goal: state %d, events %s" % [m.state, events])
	ok = ok and no_restart

	# into the goal
	await _play()
	_clear_ball_area(c)
	events.clear()
	var goal_line_x: float = f.size.x
	for p in m.home.players + m.away.players:
		if p.role == "G":
			p.position = Vector2(-5000, -5000)  # nobody in goal
	_kick(Vector2(goal_line_x - Pitch.m(3.0), c.y), Vector2(600, 0))
	await create_timer(1.0).timeout
	var scored: bool = events.any(func(e): return e.begins_with("goal:"))
	print("into the goal: %s" % [events])
	ok = ok and scored

	# no offside indoors, whatever the option says
	m.offside_on = true
	print("offside indoors with the option on: %s" % m.offside_rule())
	ok = ok and not m.offside_rule()

	# nobody leaves the arena
	await _play()
	var runner = m.home.players[2]
	runner.position = Vector2(-Pitch.m(5.0), -Pitch.m(5.0))
	await physics_frame
	await physics_frame
	print("a player put outside: back at %s, inside %s" % [runner.position, f.has_point(runner.position) or runner.position == f.position])
	ok = ok and runner.position.x >= 0.0 and runner.position.y >= 0.0

	# the CPU manager keeps the indoor shape when it chases the game
	m.state = 5
	m._state_left = 1e9
	m.clock = m.half_seconds * 70.0 / 45.0
	m.home.score = 2
	m.away.score = 0
	m.cpu._last_look = -INF
	m.cpu.thirds = [10.0, 10.0, 10.0]  # even territory: two down, it wants to attack (4-3-3 outdoors)
	m.cpu.at_stoppage()
	print("CPU two down at 70': style %s, formation %s, %d players" % [m.cpu.style, m.away.formation, m.away.players.size()])
	ok = ok and m.cpu.style == "attack" and m.away.formation == "1-2-1" and m.away.players.size() == 5

	# the substitutions screen: five on the pitch, then the bench
	var menu = load("res://scripts/subs_menu.gd").new(m, [m.home])
	root.add_child(menu)
	await process_frame
	print("subs screen: %d players, %d rows" % [menu._xi(), menu._rows()])
	ok = ok and menu._xi() == 5 and menu._rows() == 5 + m.home.bench.size()
	menu._close()

	Pitch.indoor = false
	print("outdoor again: %.0f x %.0f m" % [Pitch.field_rect().size.x / Pitch.PX_PER_M, Pitch.field_rect().size.y / Pitch.PX_PER_M])
	ok = ok and Pitch.field_rect().size == Vector2(Pitch.m(105.0), Pitch.m(68.0))
	print("INDOOR TEST PASSED" if ok else "INDOOR TEST FAILED")
	quit(0 if ok else 1)


## The ball loose at `at`, rolling at `v`, last touched by the home side.
func _kick(at: Vector2, v: Vector2) -> void:
	m.ball.stop_at(at)
	m.ball.velocity = v
	m.ball.last_touch = m.home.players[4]


## Everyone a long way from `centre` and slow to react, so the ball runs free.
func _clear_ball_area(centre: Vector2) -> void:
	for p in m.home.players + m.away.players:
		p.position = centre + Vector2(0, Pitch.m(12.0))
		p.touch_cooldown = 2.0


func _play() -> void:
	while m.state != 1:
		await physics_frame
	await physics_frame
