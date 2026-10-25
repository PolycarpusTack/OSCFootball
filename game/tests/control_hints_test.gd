extends SceneTree
## The prompts along the bottom of a match (ControlHints): what they offer in each situation,
## in whose buttons, the input trail, "need" notices, the specials line and the bar's segments.
## godot --headless --path game -s res://tests/control_hints_test.gd
var m: Node
var hints: Node
var failed := 0


func check(value: bool, message: String) -> void:
	if not value:
		failed += 1
		push_error(message)


func texts(h) -> Array:
	return hints.prompts(h).map(func(p): return p.text)


func by_role(t, role: String):
	return t.players.filter(func(q): return q.role == role)[0]


func control(h, p) -> void:
	if h.controlled:
		h.controlled.controlled = false
	h.controlled = p
	p.controlled = true


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	m.get_script().chaos = true
	m.get_script().players = 2
	root.add_child(m)
	await create_timer(2.5).timeout
	m.set_physics_process(false)
	for t in [m.home, m.away]:
		for p in t.players:
			p.set_physics_process(false)
	m.ball.set_physics_process(false)
	m.chaos_actions.ai_enabled = false
	m.state = 1
	hints = m.control_hints
	var h = m.humans[0]
	var mid: Vector2 = (m.home.goal_attacked() + m.away.goal_attacked()) / 2.0

	# with the ball: shoot, pass, dodge, the line move with its cost
	var mf = by_role(m.home, "M")
	control(h, mf)
	mf.position = mid
	m.ball.stop_at(mf.feet_front())
	m.ball.take(mf)
	m.home.energy = 20.0
	var t: Array = texts(h)
	check(t.has("Shoot (hold: power)") and t.has("Dodge / skill move") and t.has("LASER PASS"), "With the ball: %s" % [t])
	check(not t.has("THUNDER STRIKE"), "No Thunder prompt without a full bar")
	var line: String = hints.line_text(h)
	check(line.contains(" Space ") and line.contains(" X ") and line.contains(" E [/bgcolor] + ") and line.contains("#ff8a6b]50"), "Player 1's keys, the cost short of the bar: %s" % line)
	m.home.energy = 100.0
	check(texts(h).has("THUNDER STRIKE") and hints.line_text(h).contains("#8fd8ff]50"), "Full bar: Thunder offered, the cost affordable")

	# without the ball: slide, switch, body check
	m.ball.stop_at(mid + Vector2(300, 0))
	t = texts(h)
	check(t.has("Slide tackle") and t.has("Switch player") and t.has("Body check") and not t.has("LASER PASS"), "Without the ball: %s" % [t])

	# a keeper holding it, opponents still in the box
	var k = m.home.keeper()
	control(h, k)
	k.position = m.home.goal_defended() + Vector2(m.home.side * 90.0, 0)
	m.ball.stop_at(k.feet_front())
	m.ball.take(k)
	var o = by_role(m.away, "F")
	o.position = k.position + Vector2(m.home.side * 40.0, 0)
	m._keeper_held = 0.0
	t = texts(h)
	check(t.size() == 2 and t[0].begins_with("Holding it"), "Keeper must wait: %s" % [t])
	o.position = mid
	t = texts(h)
	check(t.has("Throw to a teammate") and t.has("CANNON PUNT"), "Keeper free to release: %s" % [t])

	# player 2 sees his own keys; a gamepad turns them into its buttons
	var h2 = m.humans[1]
	control(h2, by_role(m.away, "D"))
	m.ball.stop_at(mid + Vector2(0, 300))
	check(hints.line_text(h2).contains(" Enter ") and hints.line_text(h2).contains(" Right Ctrl "), "Player 2's keys: %s" % hints.line_text(h2))
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_B
	e.device = 0
	e.pressed = true
	if h2.owns(e):  # with one gamepad connected it's player 2's; none in a headless run
		hints._input(e)
		check(hints.line_text(h2).contains(" B "), "Gamepad buttons after a pad press")

	# the input trail, and F2 hides it
	control(h, mf)
	m.ball.stop_at(mf.feet_front())
	m.ball.take(mf)
	for d in [2, 3, 6]:
		h.combo.feed(d, m.clock)
	check(hints.line_text(h).begins_with("[b][color=#9fe8ff]↓ ↘ →"), "Trail shows the motion just entered")
	hints.show_trail = false
	check(not hints.line_text(h).contains("↓ ↘ →[/color][/b]"), "F2 hides the trail")
	hints.show_trail = true

	# a combo short of energy says what it needs
	m.home.energy = 10.0
	hints.combo_short(h, mf, "fireball")
	check(hints.line_text(h).contains("LASER PASS: NEED 50"), "Short combo: %s" % hints.line_text(h))
	hints._process(2.0)
	check(not hints.line_text(h).contains("NEED"), "The notice goes")
	m.home.energy = 80.0
	hints.combo_short(h, mf, "banana")
	check(not hints.line_text(h).contains("NEED"), "No notice when it was affordable")

	# the specials line: what E + each button does now, ready ones bright; the bar in segments
	var supers = load("res://scripts/supers.gd")  # loaded, not named: the autoloads aren't up when a test compiles
	var line_moves = load("res://scripts/line_moves.gd")
	m.home.energy = supers.SEGMENT
	m.chaos_actions.update_labels()
	var specials: String = m.chaos_actions.labels[0].text
	check(specials.contains("LASER PASS [color=#ff8a6b]50") and specials.contains(" E [/bgcolor] + [bgcolor=#ffffff38] Space "), "Special + shoot: the line move, short: %s" % specials)
	var dribble: String = m.chaos_actions.pick(h, "switch")
	check(dribble == "whirlwind" and specials.contains("WHIRLWIND TURN"), "Special + switch for a midfielder: %s" % dribble)
	m.home.energy = 100.0
	m.chaos_actions.update_labels()
	check(m.chaos_actions.labels[0].text.contains("[b][color=#ffe34d]"), "Affordable specials light up")
	for id in m.chaos_actions.MOVES:
		check(fmod(m.chaos_actions.MOVES[id].cost, supers.SEGMENT) == 0.0, "%s costs whole segments" % id)
	for l in line_moves.LIST:
		check(fmod(line_moves.LIST[l].cost, supers.SEGMENT) == 0.0, "%s costs whole segments" % l)
	for kind in supers.LIST:
		check(fmod(supers.cost(kind), supers.SEGMENT) == 0.0, "%s costs whole segments" % kind)
	check(fmod(m.BODY_CHECK_COST, supers.SEGMENT) == 0.0, "Body check costs whole segments")
	m._update_energy_hud()
	check(m._energy_labels[m.home].text.ends_with("MAX!"), "Full bar: MAX!")
	m.home.energy = 60.0
	m._update_energy_hud()
	check(m._energy_labels[m.home].text.ends_with("LV 2"), "60: two segments: %s" % m._energy_labels[m.home].text)

	m.state = 2  # a goal: nothing to prompt
	check(texts(h).is_empty(), "No prompts outside play")

	print("CONTROL HINTS TEST %s" % ("PASSED" if failed == 0 else "FAILED (%d)" % failed))
	quit(0 if failed == 0 else 1)
