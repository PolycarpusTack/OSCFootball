extends SceneTree
## The CPU manager: two down late on it goes 4-3-3 and attacks; two up it sits back, with
## wing-backs when the human plays down the flanks, and packs the middle when they come
## through it; after the hour it brings on fresh legs for tired men; with its keeper sent off
## an outfield player makes way for the bench keeper; the human's danger man gets a marker.
## godot --headless --path game -s res://tests/cpu_manager_test.gd

var m: Node


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await create_timer(1.6).timeout
	m.state = 5  # HALF_TIME with a long pause: freeze the play
	m._state_left = 1e9
	var cpu = m.cpu
	var t = m.away
	var ok: bool = cpu != null and cpu.team == t

	# two down at 70 minutes
	_at(70.0)
	m.home.score = 2
	var lines: Array = cpu.at_stoppage()
	var roles := _roles(t)
	print("0-2 at 70': style %s, %s, lines up %s" % [cpu.style, t.formation, roles])
	ok = ok and cpu.style == "attack" and t.formation == "4-3-3" and roles == {"G": 1, "D": 4, "M": 3, "F": 3} \
		and t.players[0].role == "G" and lines.size() >= 1
	t.pending.clear()

	# two up at 75, the human coming down the wings
	_fresh(cpu)
	_at(75.0)
	m.home.score = 0
	t.score = 2
	cpu.lanes = [30.0, 5.0, 25.0]
	cpu.at_stoppage()
	print("2-0 at 75', human down the wings: style %s, %s" % [cpu.style, t.formation])
	ok = ok and cpu.style == "sit back" and t.formation == "5-3-2"
	t.pending.clear()

	# level at 30, the human through the middle
	_fresh(cpu)
	_at(30.0)
	t.score = 0
	cpu.lanes = [5.0, 40.0, 5.0]
	cpu.thirds = [10.0, 10.0, 10.0]
	cpu._choose_style(30.0)  # at 30' a look is only a chance: ask directly
	m.change_formation(t, cpu._formation()[0])
	print("0-0 at 30', human through the middle: style %s, %s" % [cpu.style, t.formation])
	ok = ok and cpu.style == "normal" and t.formation == "4-5-1"
	t.pending.clear()

	# after the hour, tired legs come off (the most tired first)
	_fresh(cpu)
	_at(68.0)
	for p in t.players:
		p.condition = 1.0
	t.players[3].condition = 0.15
	t.players[7].condition = 0.2
	cpu.at_stoppage()
	var off: Array = t.pending.map(func(s): return s[0])
	print("68', two men spent: subs asked for slots %s" % [off])
	ok = ok and 3 in off and t.pending.size() <= 2
	m._award_restart("throw-in", t, Vector2(400, 0))
	ok = ok and t.subs_left <= 2 and t.players[3].condition == 1.0
	print("made at the throw-in: %d subs left, slot 3 fresh %s" % [t.subs_left, t.players[3].condition == 1.0])

	# keeper sent off: the bench keeper comes on for an outfield player
	_fresh(cpu)
	var bench_keeper = null
	for e in t.bench:
		if e.position == "GK":
			bench_keeper = e
	m.book(t.players[0], true)
	_at(80.0)
	cpu.at_stoppage()
	m._award_restart("throw-in", t, Vector2(400, 0))
	var new_keeper: bool = bench_keeper != null and t.players[0].display_name == bench_keeper.name \
		and t.players[0].role == "G" and not t.players[0].sent_off
	print("keeper sent off: %s in goal %s" % [t.players[0].display_name, new_keeper])
	ok = ok and new_keeper

	# the human's danger man gets marked
	var danger = m.home.players[9]
	cpu.threat = {danger: 10.0}
	_fresh(cpu)
	_at(82.0)
	var said: Array = cpu.at_stoppage()
	var marker = null
	for p in t.players:
		if p.marking == danger:
			marker = p
	print("danger man %s marked by %s; %s" % [danger.display_name, marker.display_name if marker else "nobody", said])
	ok = ok and marker != null and marker.role in ["D", "M"]
	if marker:  # he goes goal-side of him in our half
		m.state = 1
		m.ball.holder = null
		danger.position = t.goal_defended() + Vector2(t.side * 300.0, 60.0)
		m.ball.position = danger.position + Vector2(0, 200)
		load("res://scripts/ai.gd").think(marker, m, 0.016)
		print("marker's state: %s" % marker.ai_state)
		ok = ok and (marker.ai_state == "mark" or marker.ai_state == "chase")
		m.state = 5

	print("decisions: %s" % [cpu.decisions])
	print("CPU MANAGER TEST PASSED" if ok else "CPU MANAGER TEST FAILED")
	quit(0 if ok else 1)


func _at(minute: float) -> void:
	m.clock = m.half_seconds * minute / 45.0


## A new look is due, its style forgotten.
func _fresh(cpu) -> void:
	cpu._last_look = -INF
	cpu._need = -1.0


func _roles(t) -> Dictionary:
	var roles := {}
	for p in t.players:
		roles[p.role] = roles.get(p.role, 0) + 1
	return roles
